#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/signalfd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define NIX_AGENT_EXEC "@NIX_AGENT_EXEC@"
#define TRUSTED_PATH "@TRUSTED_PATH@"
#define CLEANUP_POLL_MS 100
#define KILL_GRACE_MS 2000
#define TERM_GRACE_MS 2000

static _Noreturn void fail(const char *operation) {
  fprintf(stderr, "nix-agent-mcp: %s: %s\n", operation, strerror(errno));
  exit(70);
}

static void set_environment(void) {
  if (clearenv() != 0) {
    fail("clear environment");
  }

  if (setenv("HOME", "/root", 1) != 0 || setenv("LANG", "C.UTF-8", 1) != 0 ||
      setenv("PATH", TRUSTED_PATH, 1) != 0 ||
      setenv("NIX_AGENT_FLAKE", "/etc/nixos#baseline", 1) != 0 ||
      setenv("NIX_AGENT_USAGE_LOG", "1", 1) != 0 ||
      setenv("NIX_AGENT_USAGE_LOG_PATH",
             "/var/log/nix-agent-baseline/usage.jsonl", 1) != 0) {
    fail("set environment");
  }
}

static void write_pid(const char *path, pid_t pid) {
  int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC | O_NOFOLLOW,
                0644);
  if (fd < 0) {
    fail("open pid file");
  }

  if (dprintf(fd, "%ld\n", (long)pid) < 0) {
    int saved_errno = errno;
    close(fd);
    errno = saved_errno;
    fail("write pid file");
  }

  if (close(fd) != 0) {
    fail("close pid file");
  }
}

static void arm_parent_death(pid_t supervisor_pid) {
  if (prctl(PR_SET_PDEATHSIG, SIGTERM) != 0) {
    fail("set parent death signal");
  }
  if (getppid() != supervisor_pid) {
    errno = ECHILD;
    fail("verify supervisor");
  }
}

static void normalize_root(void) {
  if (setgroups(0, NULL) != 0) {
    fail("clear supplementary groups");
  }
  if (setgid(0) != 0) {
    fail("set group identity");
  }
  if (setuid(0) != 0) {
    fail("set user identity");
  }
}

static void drop_to_caller(uid_t caller_uid, gid_t caller_gid) {
  if (setgroups(0, NULL) != 0) {
    fail("clear supervisor supplementary groups");
  }
  if (setresgid(caller_gid, caller_gid, caller_gid) != 0) {
    fail("drop supervisor group identity");
  }
  if (setresuid(caller_uid, caller_uid, caller_uid) != 0) {
    fail("drop supervisor user identity");
  }
}

static void normalize_inherited_signals(void) {
  struct sigaction action = {.sa_handler = SIG_DFL, .sa_flags = 0};
  sigset_t mask;

  if (sigemptyset(&action.sa_mask) != 0) {
    fail("initialize signal action");
  }
  if (sigaction(SIGTERM, &action, NULL) != 0) {
    fail("reset SIGTERM action");
  }
  if (sigaction(SIGCHLD, &action, NULL) != 0) {
    fail("reset SIGCHLD action");
  }
  if (sigemptyset(&mask) != 0 || sigaddset(&mask, SIGTERM) != 0) {
    fail("initialize SIGTERM mask");
  }
  if (sigprocmask(SIG_UNBLOCK, &mask, NULL) != 0) {
    fail("unblock SIGTERM");
  }
}

static int monitor_signal_fd(void) {
  sigset_t mask;

  if (sigemptyset(&mask) != 0 || sigaddset(&mask, SIGTERM) != 0) {
    fail("initialize monitor signal mask");
  }
  if (sigprocmask(SIG_BLOCK, &mask, NULL) != 0) {
    fail("block monitor SIGTERM");
  }

  int fd = signalfd(-1, &mask, SFD_CLOEXEC);
  if (fd < 0) {
    fail("open monitor signal fd");
  }
  return fd;
}

static int child_status(int status) {
  if (WIFEXITED(status)) {
    return WEXITSTATUS(status);
  }
  if (WIFSIGNALED(status)) {
    int signal_number = WTERMSIG(status);
    struct sigaction action = {.sa_handler = SIG_DFL, .sa_flags = 0};
    sigset_t mask;

    if (sigemptyset(&action.sa_mask) != 0) {
      fail("reset child signal");
    }
    if (signal_number != SIGKILL && signal_number != SIGSTOP &&
        sigaction(signal_number, &action, NULL) != 0) {
      fail("reset child signal");
    }
    if (sigemptyset(&mask) != 0 || sigaddset(&mask, signal_number) != 0 ||
        sigprocmask(SIG_UNBLOCK, &mask, NULL) != 0) {
      fail("unblock child signal");
    }
    if (raise(signal_number) != 0) {
      fail("propagate child signal");
    }
    return 128 + signal_number;
  }

  errno = ECHILD;
  fail("read child status");
}

static int wait_for_child(pid_t child_pid) {
  int status;
  pid_t waited;

  do {
    waited = waitpid(child_pid, &status, 0);
  } while (waited < 0 && errno == EINTR);

  if (waited < 0) {
    fail("wait for nix-agent");
  }
  return child_status(status);
}

static void detach_monitor_stdio(void) {
  int null_fd = open("/dev/null", O_RDWR | O_CLOEXEC);
  if (null_fd < 0) {
    fail("open monitor null device");
  }
  for (int fd = STDIN_FILENO; fd <= STDERR_FILENO; ++fd) {
    if (dup2(null_fd, fd) < 0) {
      fail("detach monitor stdio");
    }
  }
  if (null_fd > STDERR_FILENO && close(null_fd) != 0) {
    fail("close monitor null device");
  }
}

struct child_state {
  int worker_status;
  int worker_reaped;
};

struct child_snapshot {
  size_t count;
  int worker_present;
};

static int64_t monotonic_milliseconds(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    fail("read monotonic clock");
  }
  return (int64_t)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static int64_t cleanup_deadline(int64_t duration_ms) {
  return monotonic_milliseconds() + duration_ms;
}

static void wait_for_cleanup_tick(int64_t deadline) {
  int64_t now = monotonic_milliseconds();
  if (now >= deadline) {
    return;
  }

  int64_t wake = now + CLEANUP_POLL_MS;
  if (wake > deadline) {
    wake = deadline;
  }
  struct timespec target = {
      .tv_sec = (time_t)(wake / 1000),
      .tv_nsec = (long)(wake % 1000) * 1000000,
  };
  int result;
  do {
    result = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &target, NULL);
  } while (result == EINTR);
  if (result != 0) {
    errno = result;
    fail("wait for nix-agent cleanup");
  }
}

static FILE *open_children_file(void) {
  char path[64];
  int length = snprintf(path, sizeof(path), "/proc/self/task/%ld/children",
                        (long)getpid());
  if (length < 0 || (size_t)length >= sizeof(path)) {
    errno = ENAMETOOLONG;
    fail("format monitor children path");
  }

  FILE *children = fopen(path, "r");
  if (children == NULL) {
    fail("open monitor children");
  }
  return children;
}

static int read_child_pid(FILE *children, pid_t *child_pid) {
  long value;
  int result = fscanf(children, "%ld", &value);
  if (result == EOF) {
    if (ferror(children)) {
      fail("read monitor children");
    }
    return 0;
  }
  if (result != 1 || value <= 0 || value > INT_MAX || value == (long)getpid()) {
    errno = EINVAL;
    fail("parse monitor child pid");
  }
  *child_pid = (pid_t)value;
  return 1;
}

static void close_children_file(FILE *children) {
  if (fclose(children) != 0) {
    fail("close monitor children");
  }
}

static struct child_snapshot signal_direct_children(pid_t worker_pid,
                                                    int signal_number) {
  struct child_snapshot snapshot = {.count = 0, .worker_present = 0};
  FILE *children = open_children_file();
  pid_t child_pid;

  while (read_child_pid(children, &child_pid)) {
    snapshot.count++;
    if (child_pid == worker_pid) {
      snapshot.worker_present = 1;
    }
    if (signal_number != 0 && kill(child_pid, signal_number) != 0 &&
        errno != ESRCH) {
      close_children_file(children);
      fail("signal adopted nix-agent child");
    }
  }
  close_children_file(children);
  return snapshot;
}

static void reap_adopted_children(pid_t worker_pid) {
  FILE *children = open_children_file();
  pid_t child_pid;

  while (read_child_pid(children, &child_pid)) {
    if (child_pid == worker_pid) {
      continue;
    }
    int status;
    pid_t waited;
    do {
      waited = waitpid(child_pid, &status, WNOHANG);
    } while (waited < 0 && errno == EINTR);
    if (waited < 0 && errno != ECHILD) {
      close_children_file(children);
      fail("reap adopted nix-agent child");
    }
  }
  close_children_file(children);
}

static int reap_children(pid_t worker_pid, struct child_state *state,
                         int64_t deadline) {
  for (;;) {
    int status;
    pid_t waited = waitpid(-1, &status, WNOHANG);
    if (waited > 0) {
      if (waited == worker_pid) {
        state->worker_status = status;
        state->worker_reaped = 1;
      }
      if (monotonic_milliseconds() >= deadline) {
        return -1;
      }
      continue;
    }
    if (waited == 0) {
      return 0;
    }
    if (errno == EINTR) {
      continue;
    }
    if (errno == ECHILD) {
      if (!state->worker_reaped) {
        fail("reap nix-agent worker");
      }
      return 1;
    }
    fail("reap nix-agent process group");
  }
}

static void signal_worker_group(pid_t worker_pid, int signal_number,
                                const char *operation) {
  if (kill(-worker_pid, signal_number) != 0 && errno != ESRCH) {
    fail(operation);
  }
}

static int reap_worker(pid_t worker_pid, struct child_state *state) {
  int status;
  pid_t waited;
  do {
    waited = waitpid(worker_pid, &status, WNOHANG);
  } while (waited < 0 && errno == EINTR);
  if (waited == 0) {
    return 0;
  }
  if (waited < 0) {
    fail("reap nix-agent worker");
  }
  state->worker_status = status;
  state->worker_reaped = 1;
  return 1;
}

static int worker_exited(pid_t worker_pid);

static int cleanup_worker_group(pid_t worker_pid) {
  struct child_state state = {.worker_status = 0, .worker_reaped = 0};

  signal_worker_group(worker_pid, SIGTERM,
                      "terminate nix-agent process group");
  int64_t term_deadline = cleanup_deadline(TERM_GRACE_MS);

  for (;;) {
    signal_direct_children(worker_pid, SIGTERM);
    reap_adopted_children(worker_pid);
    int exited = worker_exited(worker_pid);
    struct child_snapshot snapshot = signal_direct_children(worker_pid, 0);
    if (!snapshot.worker_present) {
      errno = ECHILD;
      fail("track nix-agent worker");
    }
    if (exited && snapshot.count == 1 && reap_worker(worker_pid, &state)) {
      return child_status(state.worker_status);
    }
    if (monotonic_milliseconds() >= term_deadline) {
      break;
    }
    wait_for_cleanup_tick(term_deadline);
  }

  signal_worker_group(worker_pid, SIGKILL, "kill nix-agent process group");
  int64_t kill_deadline = cleanup_deadline(KILL_GRACE_MS);
  for (;;) {
    signal_direct_children(worker_pid, SIGKILL);
    int reap_result = reap_children(worker_pid, &state, kill_deadline);
    if (reap_result > 0) {
      return child_status(state.worker_status);
    }
    if (reap_result < 0 || monotonic_milliseconds() >= kill_deadline) {
      errno = ETIMEDOUT;
      fail("clean nix-agent descendants");
    }
    wait_for_cleanup_tick(kill_deadline);
  }
}

static int worker_exited(pid_t worker_pid) {
  siginfo_t info = {0};

  if (waitid(P_PID, (id_t)worker_pid, &info, WEXITED | WNOHANG | WNOWAIT) !=
      0) {
    fail("inspect nix-agent worker");
  }
  return info.si_pid == worker_pid;
}

static int monitor_worker(pid_t worker_pid, int watchdog_fd, int signal_fd) {
  struct pollfd fds[] = {
      {.fd = watchdog_fd, .events = POLLIN | POLLHUP},
      {.fd = signal_fd, .events = POLLIN},
  };

  for (;;) {
    if (worker_exited(worker_pid)) {
      int result = cleanup_worker_group(worker_pid);
      close(watchdog_fd);
      close(signal_fd);
      return result;
    }

    int ready = poll(fds, 2, CLEANUP_POLL_MS);
    if (ready < 0) {
      if (errno == EINTR) {
        continue;
      }
      fail("poll nix-agent watchdog");
    }
    if (ready > 0 &&
        ((fds[0].revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL)) != 0 ||
         (fds[1].revents & (POLLIN | POLLERR | POLLNVAL)) != 0)) {
      int result = cleanup_worker_group(worker_pid);
      close(watchdog_fd);
      close(signal_fd);
      return result;
    }
  }
}

int main(int argc, char **argv) {
  uid_t caller_uid = getuid();
  gid_t caller_gid = getgid();
  (void)argv;

  if (argc != 1) {
    fprintf(stderr, "nix-agent-mcp: arguments are not permitted\n");
    return 64;
  }

  if (geteuid() != 0) {
    errno = EPERM;
    fail("require effective root identity");
  }

  normalize_inherited_signals();
  pid_t supervisor_pid = getpid();
  int watchdog_pipe[2];
  if (pipe2(watchdog_pipe, O_CLOEXEC) != 0) {
    fail("open nix-agent watchdog");
  }
  write_pid("/run/nix-agent-baseline/supervisor.pid", supervisor_pid);

  pid_t monitor_pid = fork();
  if (monitor_pid < 0) {
    fail("fork nix-agent monitor");
  }
  if (monitor_pid == 0) {
    if (close(watchdog_pipe[1]) != 0) {
      fail("close monitor watchdog writer");
    }
    arm_parent_death(supervisor_pid);
    normalize_root();
    arm_parent_death(supervisor_pid);
    if (prctl(PR_SET_CHILD_SUBREAPER, 1) != 0) {
      fail("make nix-agent monitor a child subreaper");
    }
    int signal_fd = monitor_signal_fd();
    pid_t privileged_monitor_pid = getpid();

    pid_t worker_pid = fork();
    if (worker_pid < 0) {
      fail("fork nix-agent worker");
    }
    if (worker_pid == 0) {
      if (close(watchdog_pipe[0]) != 0 || close(signal_fd) != 0) {
        fail("close worker watchdog descriptors");
      }
      if (setpgid(0, 0) != 0) {
        fail("create nix-agent process group");
      }
      normalize_inherited_signals();
      arm_parent_death(privileged_monitor_pid);
      normalize_root();
      // Credential changes clear PR_SET_PDEATHSIG, so arm it again.
      arm_parent_death(privileged_monitor_pid);
      umask(0022);
      set_environment();
      write_pid("/run/nix-agent-baseline/server.pid", getpid());

      char program_name[] = "nix-agent";
      char *const child_argv[] = {program_name, NULL};
      execv(NIX_AGENT_EXEC, child_argv);
      fail("exec nix-agent");
    }

    if (setpgid(worker_pid, worker_pid) != 0 && errno != EACCES &&
        errno != ESRCH) {
      kill(worker_pid, SIGKILL);
      waitpid(worker_pid, NULL, 0);
      fail("set nix-agent process group");
    }
    detach_monitor_stdio();
    return monitor_worker(worker_pid, watchdog_pipe[0], signal_fd);
  }

  if (close(watchdog_pipe[0]) != 0) {
    fail("close supervisor watchdog reader");
  }
  drop_to_caller(caller_uid, caller_gid);
  int result = wait_for_child(monitor_pid);
  if (close(watchdog_pipe[1]) != 0) {
    fail("close supervisor watchdog writer");
  }
  return result;
}
