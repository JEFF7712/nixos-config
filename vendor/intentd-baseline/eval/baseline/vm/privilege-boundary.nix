{
  nixpkgs,
  nix-agent,
  baselineModules,
}:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  testPython = pkgs.python3.withPackages (ps: [ ps.fastmcp ]);
  fixtureSource = pkgs.writeText "nix-agent-helper-fixture.c" ''
    #define _GNU_SOURCE

    #include <errno.h>
    #include <fcntl.h>
    #include <signal.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <unistd.h>

    static _Noreturn void fail(const char *operation) {
      fprintf(stderr, "nix-agent-helper-fixture: %s: %s\n", operation,
              strerror(errno));
      exit(70);
    }

    int main(void) {
      int ready[2];
      if (pipe2(ready, O_CLOEXEC) != 0) {
        fail("open readiness pipe");
      }

      pid_t helper_pid = fork();
      if (helper_pid < 0) {
        fail("fork helper");
      }
      if (helper_pid == 0) {
        if (close(ready[0]) != 0) {
          fail("close helper readiness reader");
        }
        struct sigaction action = {.sa_handler = SIG_IGN, .sa_flags = 0};
        if (sigemptyset(&action.sa_mask) != 0 ||
            sigaction(SIGTERM, &action, NULL) != 0) {
          fail("ignore SIGTERM");
        }
        if (setsid() < 0) {
          fail("escape worker session");
        }

        int pid_fd = open("/run/nix-agent-baseline/fixture-helper.pid",
                          O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC | O_NOFOLLOW,
                          0644);
        if (pid_fd < 0) {
          fail("open helper pid file");
        }
        if (dprintf(pid_fd, "%ld\n", (long)getpid()) < 0 || close(pid_fd) != 0) {
          fail("write helper pid file");
        }

        int null_fd = open("/dev/null", O_RDWR | O_CLOEXEC);
        if (null_fd < 0) {
          fail("open null device");
        }
        for (int fd = STDIN_FILENO; fd <= STDERR_FILENO; ++fd) {
          if (dup2(null_fd, fd) < 0) {
            fail("detach helper stdio");
          }
        }
        if (null_fd > STDERR_FILENO && close(null_fd) != 0) {
          fail("close null device");
        }
        if (write(ready[1], "1", 1) != 1) {
          _exit(70);
        }
        if (close(ready[1]) != 0) {
          _exit(70);
        }
        for (;;) {
          pause();
        }
      }

      if (close(ready[1]) != 0) {
        fail("close fixture readiness writer");
      }
      char marker;
      ssize_t read_result;
      do {
        read_result = read(ready[0], &marker, 1);
      } while (read_result < 0 && errno == EINTR);
      if (read_result != 1) {
        fail("read helper readiness");
      }
      if (close(ready[0]) != 0) {
        fail("close fixture readiness reader");
      }
      return 0;
    }
  '';
  fixtureAgent = pkgs.runCommandCC "nix-agent-helper-fixture" { } ''
    mkdir -p $out/bin
    $CC -std=c11 -O2 -Wall -Wextra -Werror \
      ${fixtureSource} -o $out/bin/nix-agent-helper-fixture
  '';
  fixtureTrustedPath = nixpkgs.lib.makeBinPath [
    pkgs.coreutils
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.sudo
    pkgs.systemd
  ];
  fixtureLauncher = pkgs.runCommandCC "nix-agent-mcp-fixture-launcher" { } ''
    mkdir -p $out/bin
    substitute ${./nix-agent-launcher.c} launcher.c \
      --replace-fail '@NIX_AGENT_EXEC@' '${fixtureAgent}/bin/nix-agent-helper-fixture' \
      --replace-fail '@TRUSTED_PATH@' '${fixtureTrustedPath}'
    $CC -std=c11 -O2 -Wall -Wextra -Werror \
      launcher.c -o $out/bin/nix-agent-mcp-fixture
  '';
  mcpClient = pkgs.writeText "baseline-mcp-client.py" ''
    import asyncio
    import os
    import signal
    import sys
    from pathlib import Path

    from fastmcp import Client

    CONFIG = {
        "mcpServers": {
            "nix-agent": {
                "command": "/run/wrappers/bin/nix-agent-mcp",
                "args": [],
            }
        }
    }

    async def main() -> None:
        if sys.argv[1] == "hostile-signal":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            signal.signal(signal.SIGCHLD, signal.SIG_IGN)
            signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM})
        async with Client(CONFIG) as client:
            if sys.argv[1] == "hostile-signal":
                Path("/tmp/nix-agent-mcp-hostile-signal-client.pid").write_text(
                    str(os.getpid())
                )
                Path("/tmp/nix-agent-mcp-hostile-signal-ready").write_text("ready")
                await asyncio.sleep(60)
                return
            if sys.argv[1] == "hold":
                Path("/tmp/nix-agent-mcp-ready").write_text("ready")
                await asyncio.sleep(20)
                return
            if sys.argv[1] == "probe":
                result = await client.call_tool(
                    "eval_config", {"attr": "networking.hostName"}
                )
                if result.is_error:
                    raise RuntimeError(str(result))
                payload = result.structured_content
                if not isinstance(payload, dict):
                    raise RuntimeError(str(result))
                if payload.get("status") != "ok" or payload.get("value") != "baseline":
                    raise RuntimeError(str(result))
                return
            result = await client.call_tool("switch", {})
            if result.is_error:
                raise RuntimeError(str(result))

    asyncio.run(main())
  '';
  editConfig = pkgs.writeText "baseline-edit-config.py" ''
    from pathlib import Path

    path = Path("/etc/nixos/configuration.nix")
    text = path.read_text()
    closing = "\n}\n"
    if not text.endswith(closing):
        raise RuntimeError("configuration.nix has an unexpected ending")
    path.write_text(
        text[: -len(closing)]
        + '\n  environment.etc."baseline-boundary-proof".text = "through-mcp";'
        + closing
    )

    flake_path = Path("/etc/nixos/flake.nix")
    flake_text = flake_path.read_text()
    needle = "          ./vm-node.nix\n"
    if flake_text.count(needle) != 1:
        raise RuntimeError("flake.nix has an unexpected module list")
    flake_path.write_text(
        flake_text.replace(
            needle,
            needle
            + '          (nixpkgs.outPath + "/nixos/modules/testing/test-instrumentation.nix")\n'
            + "          ({ lib, ... }: {\n"
            + "            testing.backdoor = true;\n"
            + "            users.users.root.hashedPasswordFile = lib.mkForce null;\n"
            + "          })\n",
        )
    )
  '';
  switchedSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit nix-agent; };
    modules = [
      ./configuration.nix
      ./agent-harness.nix
      ./vm-node.nix
      (nixpkgs.outPath + "/nixos/modules/testing/test-instrumentation.nix")
      ({ lib, ... }: {
        testing.backdoor = true;
        users.users.root.hashedPasswordFile = lib.mkForce null;
        environment.etc."baseline-boundary-proof".text = "through-mcp";
      })
    ];
  };
in
nixpkgs.lib.nixos.runTest {
  name = "baseline-privilege-boundary";
  hostPkgs = pkgs;

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = baselineModules;
      _module.args.nix-agent = nix-agent;
      users.users.root.hashedPasswordFile = lib.mkForce null;
      virtualisation = {
        memorySize = 6144;
        cores = 4;
        diskSize = 16384;
        writableStoreUseTmpfs = false;
        additionalPaths = [
          nixpkgs.outPath
          nix-agent.outPath
          nix-agent.inputs.flake-utils.outPath
          nix-agent.inputs.flake-utils.inputs.systems.outPath
          switchedSystem.config.system.build.toplevel
        ];
      };
      environment.systemPackages = [
        testPython
      ];
      environment.etc."nix-agent-package-path".text = "${nix-agent.packages.${system}.default}";
      security.wrappers.nix-agent-mcp-fixture = {
        source = "${fixtureLauncher}/bin/nix-agent-mcp-fixture";
        owner = "root";
        group = "root";
        permissions = "u+rx,g+x,o+x";
        setuid = true;
      };
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("seed-etc-nixos.service")

    groups = machine.succeed("id -nG wedge").split()
    assert "wheel" not in groups, groups
    machine.fail("runuser -u wedge -- sudo -n true")
    machine.fail("runuser -u wedge -- /run/wrappers/bin/sudo -n true")
    machine.succeed("getent shadow root | cut -d: -f2 | grep -E '^!+$'")
    machine.succeed("sshd -T | grep -Fx 'permitrootlogin no'")
    machine.fail(
        "runuser -u wedge -- nix-env --profile /nix/var/nix/profiles/system "
        "--set /run/current-system"
    )
    machine.fail(
        "runuser -u wedge -- /run/current-system/bin/switch-to-configuration switch"
    )
    machine.fail("runuser -u wedge -- /run/wrappers/bin/nix-agent-mcp usage")
    machine.succeed("test -f /etc/nixos/cursor-mcp-timeout-patch.py")
    machine.succeed("runuser -u wedge -- baseline-patch-cursor-mcp-timeout --help")
    machine.succeed("runuser -u wedge -- sh -c 'command -v baseline-cursor-agent'")
    machine.fail("runuser -u wedge -- baseline-cursor-agent --version")
    machine.succeed(
        "mkdir -p /tmp/cursor-runner-attacker /tmp/wrong-cursor-root; "
        "printf '#!/bin/sh\\ntouch /tmp/cursor-runner-hostile-path\\nprintf %s /nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854\\n' "
        "> /tmp/cursor-runner-attacker/dirname; "
        "cp /tmp/cursor-runner-attacker/dirname /tmp/cursor-runner-attacker/basename; "
        "chmod +x /tmp/cursor-runner-attacker/dirname /tmp/cursor-runner-attacker/basename; "
        "touch /tmp/wrong-cursor-root/node /tmp/wrong-cursor-root/index.js; "
        "chmod +x /tmp/wrong-cursor-root/node"
    )
    machine.fail(
        "runuser -u wedge -- env PATH=/tmp/cursor-runner-attacker "
        "/run/current-system/sw/bin/baseline-cursor-agent "
        "/tmp/wrong-cursor-root/node /tmp/wrong-cursor-root/index.js --version"
    )
    machine.fail("test -e /tmp/cursor-runner-hostile-path")

    preflight_config_hash = machine.succeed(
        "find /etc/nixos -maxdepth 1 -type f -exec sha256sum {} + | sort"
    )
    preflight_generation_count = machine.succeed(
        "nix-env --profile /nix/var/nix/profiles/system --list-generations | wc -l"
    ).strip()
    preflight_current_closure = machine.succeed("readlink -f /run/current-system").strip()
    machine.succeed(
        "runuser -u wedge -- baseline-mcp-preflight > /tmp/baseline-mcp-preflight.json",
        timeout=900,
    )
    machine.succeed("test -f /etc/nixos/mcp-preflight.py")
    machine.succeed(
        "jq -e '.success == true "
        "and (.elapsed_seconds | type == \"number\") "
        "and [.tools[].name] == [\"locate_option\", \"eval_config\"] "
        "and all(.tools[]; .status == \"ok\" "
        "and (.elapsed_seconds | type == \"number\"))' "
        "/tmp/baseline-mcp-preflight.json >/dev/null"
    )
    assert machine.succeed(
        "find /etc/nixos -maxdepth 1 -type f -exec sha256sum {} + | sort"
    ) == preflight_config_hash
    assert machine.succeed(
        "nix-env --profile /nix/var/nix/profiles/system --list-generations | wc -l"
    ).strip() == preflight_generation_count
    assert (
        machine.succeed("readlink -f /run/current-system").strip()
        == preflight_current_closure
    )
    machine.fail("runuser -u wedge -- sudo -n true")
    machine.fail(
        "runuser -u wedge -- nix-env --profile /nix/var/nix/profiles/system "
        "--set /run/current-system"
    )
    machine.fail(
        "runuser -u wedge -- /run/current-system/bin/switch-to-configuration switch"
    )
    preflight_usage_count = int(
        machine.succeed("wc -l < /var/log/nix-agent-baseline/usage.jsonl")
    )
    assert preflight_usage_count == 2, preflight_usage_count
    machine.succeed(
        "jq -e -s '.[0].tool == \"locate_option\" and .[0].status == \"ok\" "
        "and .[1].tool == \"eval_config\" and .[1].status == \"ok\"' "
        "/var/log/nix-agent-baseline/usage.jsonl >/dev/null"
    )

    machine.succeed(
        "runuser -u wedge -- /run/wrappers/bin/nix-agent-mcp-fixture", timeout=15
    )
    fixture_helper_pid = machine.succeed(
        "cat /run/nix-agent-baseline/fixture-helper.pid"
    ).strip()
    fixture_worker_pid = machine.succeed(
        "cat /run/nix-agent-baseline/server.pid"
    ).strip()
    fixture_supervisor_pid = machine.succeed(
        "cat /run/nix-agent-baseline/supervisor.pid"
    ).strip()
    machine.wait_until_succeeds(f"! kill -0 {fixture_supervisor_pid}", timeout=30)
    machine.wait_until_succeeds(f"! kill -0 {fixture_worker_pid}", timeout=30)
    machine.wait_until_succeeds(f"! kill -0 {fixture_helper_pid}", timeout=30)
    machine.wait_until_succeeds(
        f"! /run/current-system/sw/bin/kill -0 -- -{fixture_worker_pid}", timeout=30
    )

    machine.succeed(
        "systemd-run --unit=mcp-signal-adversary --property=User=wedge "
        "${testPython}/bin/python ${mcpClient} hostile-signal"
    )
    machine.wait_until_succeeds("test -e /tmp/nix-agent-mcp-hostile-signal-ready")
    signal_child_pid = machine.succeed("cat /run/nix-agent-baseline/server.pid").strip()
    signal_monitor_pid = machine.succeed(
        f"awk '/^PPid:/{{print $2}}' /proc/{signal_child_pid}/status"
    ).strip()
    signal_supervisor_pid = machine.succeed(
        "cat /run/nix-agent-baseline/supervisor.pid"
    ).strip()
    signal_attacker_pid = machine.succeed(
        "cat /tmp/nix-agent-mcp-hostile-signal-client.pid"
    ).strip()
    signal_group_pids = machine.succeed(
        f"ps -eo pid=,pgid= | awk '$2 == {signal_child_pid} {{print $1}}'"
    ).split()
    assert signal_child_pid in signal_group_pids, signal_group_pids
    machine.succeed(
        f"test \"$(systemctl show -p MainPID --value mcp-signal-adversary.service)\" "
        f"= {signal_attacker_pid}; "
        f"test \"$(awk '/^PPid:/{{print $2}}' /proc/{signal_monitor_pid}/status)\" "
        f"= {signal_supervisor_pid}"
    )
    machine.succeed(f"runuser -u wedge -- kill -TERM {signal_supervisor_pid}")
    machine.wait_until_succeeds(f"! kill -0 {signal_supervisor_pid}", timeout=30)
    machine.wait_until_succeeds(f"! kill -0 {signal_monitor_pid}", timeout=30)
    machine.wait_until_succeeds(f"! kill -0 {signal_child_pid}", timeout=30)
    machine.wait_until_succeeds(
        f"! /run/current-system/sw/bin/kill -0 -- -{signal_child_pid}", timeout=30
    )
    for signal_group_pid in signal_group_pids:
        machine.wait_until_succeeds(f"! kill -0 {signal_group_pid}", timeout=30)
    machine.succeed(
        "systemctl kill --kill-whom=all --signal=SIGKILL "
        "mcp-signal-adversary.service || true"
    )
    machine.wait_until_succeeds(f"! kill -0 {signal_attacker_pid}", timeout=30)
    machine.wait_until_succeeds(
        "test \"$(systemctl show -p MainPID --value mcp-signal-adversary.service)\" = 0",
        timeout=30,
    )
    machine.succeed("systemctl reset-failed mcp-signal-adversary.service")

    machine.succeed("mkdir -p /tmp/nix-agent-attacker")
    machine.succeed(
        "printf '#!/bin/sh\\ntouch /tmp/nix-agent-hostile-path\\n' "
        "> /tmp/nix-agent-attacker/sudo"
    )
    machine.succeed(
        "cp /tmp/nix-agent-attacker/sudo /tmp/nix-agent-attacker/nixos-rebuild; "
        "chmod +x /tmp/nix-agent-attacker/sudo /tmp/nix-agent-attacker/nixos-rebuild"
    )

    machine.succeed(
        "runuser -u wedge -- env PATH=/tmp/nix-agent-attacker:/run/current-system/sw/bin "
        "${testPython}/bin/python ${mcpClient} hold >/tmp/mcp-hold.log 2>&1 &"
    )
    machine.wait_until_succeeds("test -e /tmp/nix-agent-mcp-ready")
    held_pid = machine.succeed("cat /run/nix-agent-baseline/server.pid").strip()
    machine.succeed(
        "pid=$(cat /run/nix-agent-baseline/server.pid); "
        "expected=$(cat /etc/nix-agent-package-path); "
        "tr '\\0' '\\n' </proc/$pid/cmdline | grep -F -- \"$expected\"; "
        "monitor=$(awk '/^PPid:/{print $2}' /proc/$pid/status); "
        "supervisor=$(cat /run/nix-agent-baseline/supervisor.pid); "
        "uid=$(id -u wedge); gid=$(id -g wedge); "
        "test \"$(awk '/^Uid:/{print $2, $3, $4, $5}' /proc/$pid/status)\" = \"0 0 0 0\"; "
        "test \"$(awk '/^Gid:/{print $2, $3, $4, $5}' /proc/$pid/status)\" = \"0 0 0 0\"; "
        "test \"$(awk '/^Uid:/{print $2, $3, $4, $5}' /proc/$monitor/status)\" = \"0 0 0 0\"; "
        "test \"$(awk '/^Gid:/{print $2, $3, $4, $5}' /proc/$monitor/status)\" = \"0 0 0 0\"; "
        "test \"$(awk '/^PPid:/{print $2}' /proc/$monitor/status)\" = \"$supervisor\"; "
        "test \"$(awk '/^Uid:/{print $2, $3, $4, $5}' /proc/$supervisor/status)\" = \"$uid $uid $uid $uid\"; "
        "test \"$(awk '/^Gid:/{print $2, $3, $4, $5}' /proc/$supervisor/status)\" = \"$gid $gid $gid $gid\""
    )

    machine.succeed("runuser -u wedge -- ${testPython}/bin/python ${editConfig}")
    before = int(machine.succeed("nix-env -p /nix/var/nix/profiles/system --list-generations | wc -l"))
    machine.succeed(
        "runuser -u wedge -- env PATH=/tmp/nix-agent-attacker:/run/current-system/sw/bin "
        "${testPython}/bin/python ${mcpClient} switch >/tmp/mcp-switch.log 2>&1",
        timeout=1800,
    )
    switch_pid = machine.succeed("cat /run/nix-agent-baseline/server.pid").strip()
    machine.wait_until_succeeds(f"! kill -0 {switch_pid}", timeout=30)
    machine.fail("grep -F 'PermissionError:' /tmp/mcp-switch.log")
    machine.wait_until_succeeds(f"! kill -0 {held_pid}", timeout=30)
    machine.fail("grep -F 'PermissionError:' /tmp/mcp-hold.log")
    machine.fail("test -e /tmp/nix-agent-hostile-path")
    machine.succeed("test \"$(cat /etc/baseline-boundary-proof)\" = through-mcp")
    after = int(machine.succeed("nix-env -p /nix/var/nix/profiles/system --list-generations | wc -l"))
    assert after > before, (before, after)
    machine.succeed(
        "jq -e -s 'length > 0 and all(.[]; type == \"object\" and (.tool | type == \"string\"))' "
        "/var/log/nix-agent-baseline/usage.jsonl >/dev/null"
    )
    usage_before = int(machine.succeed("wc -l < /var/log/nix-agent-baseline/usage.jsonl"))

    groups = machine.succeed("id -nG wedge").split()
    assert "wheel" not in groups, groups
    machine.fail("runuser -u wedge -- sudo -n true")
    machine.fail("runuser -u wedge -- /run/wrappers/bin/sudo -n true")
    machine.succeed("getent shadow root | cut -d: -f2 | grep -E '^!+$'")
    machine.succeed("sshd -T | grep -Fx 'permitrootlogin no'")
    machine.fail(
        "runuser -u wedge -- nix-env --profile /nix/var/nix/profiles/system "
        "--set /run/current-system"
    )
    machine.fail(
        "runuser -u wedge -- /run/current-system/bin/switch-to-configuration switch"
    )
    machine.succeed("test -x /run/wrappers/bin/nix-agent-mcp")
    machine.succeed(
        "runuser -u wedge -- env PATH=/tmp/nix-agent-attacker:/run/current-system/sw/bin "
        "${testPython}/bin/python ${mcpClient} probe >/tmp/mcp-probe.log 2>&1"
    )
    probe_pid = machine.succeed("cat /run/nix-agent-baseline/server.pid").strip()
    machine.wait_until_succeeds(f"! kill -0 {probe_pid}", timeout=30)
    machine.fail("grep -F 'PermissionError:' /tmp/mcp-probe.log")
    usage_after = int(machine.succeed("wc -l < /var/log/nix-agent-baseline/usage.jsonl"))
    assert usage_after > usage_before, (usage_before, usage_after)
    machine.succeed(
        "tail -n 1 /var/log/nix-agent-baseline/usage.jsonl | "
        "jq -e '.tool == \"eval_config\" and .status == \"ok\" "
        "and .attr == \"networking.hostName\"'"
    )
    machine.fail("test -e /tmp/nix-agent-hostile-path")
  '';
}
