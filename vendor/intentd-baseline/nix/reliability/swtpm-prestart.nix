# Host-side swtpm prestart for the vm-boot check.
#
# QEMU's tpm-emulator backend performs a synchronous handshake at startup and
# exits when no swtpm is listening, so the daemon must exist before the first
# machine.start. The lanzaboote image-helper starts the machine itself, which
# runs before any inline testScript code, so this snippet is prepended ahead
# of that import in vm-boot.nix. Daemon state persists across the guest
# crash/restart cycles inside one run, matching real TPM semantics.
#
# QEMU's chardev must point at swtpm's --ctrl socket: the --server socket
# serves raw TPM commands (for tpm2-tools), and pointing QEMU at it deadlocks
# the SET_DATAFD handshake. Verified empirically 2026-10-01.
{ pkgs }:
let
  stateDir = "/tmp/intentd-swtpm";
in
''
  swtpm = None


  def ensure_swtpm():
      # swtpm drops its control socket when the QEMU client vanishes (as in
      # the powerloss crash subtest), so a restart is required before the
      # next machine.start. State in ${stateDir} survives the restart.
      # Imports live here because the lanzaboote image-helper later in the
      # script repeats the module-level ones.
      import os
      import subprocess
      import time

      global swtpm
      sock = "${stateDir}/swtpm-sock"
      if swtpm is not None and swtpm.poll() is None and os.path.exists(sock):
          return
      if swtpm is not None and swtpm.poll() is None:
          swtpm.terminate()
          try:
              swtpm.wait(timeout=10)
          except subprocess.TimeoutExpired:
              swtpm.kill()
              swtpm.wait()
      try:
          os.unlink(sock)
      except FileNotFoundError:
          pass
      os.makedirs("${stateDir}", exist_ok=True)
      swtpm_log = open("${stateDir}/swtpm.log", "ab")
      swtpm = subprocess.Popen(
          [
              "${pkgs.swtpm}/bin/swtpm",
              "socket",
              "--tpm2",
              "--tpmstate",
              "dir=${stateDir}",
              "--ctrl",
              "type=unixio,path=${stateDir}/swtpm-sock",
          ],
          stdout=swtpm_log,
          stderr=subprocess.STDOUT,
      )
      deadline = time.time() + 60
      while not os.path.exists(sock):
          assert swtpm.poll() is None, "swtpm exited before creating its control socket"
          assert time.time() < deadline, "swtpm did not create its control socket"
          time.sleep(0.5)


  ensure_swtpm()
''
