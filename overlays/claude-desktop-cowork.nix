final: prev:

let
  original = prev.claude-desktop-fhs;
  app = prev.claude-desktop;
  runtimePath = final.lib.makeBinPath [
    final.bubblewrap
    final.qemu_kvm
    final.virtiofsd
    final.socat
  ];
  daemonScript = "${app}/lib/claude-desktop/resources/app.asar.unpacked/cowork-vm-service.js";
  electronBin = "${prev.electron}/bin/electron";
  pythonBin = "${final.python3}/bin/python";
in {
  claude-desktop-fhs = final.symlinkJoin {
    name = original.name;
    paths = [ original ];
    postBuild = ''
      rm -f "$out/bin/claude-desktop"
      cat > "$out/bin/claude-desktop" <<'EOF'
#!${final.bash}/bin/bash
set -euo pipefail

export PATH='${runtimePath}':"$PATH"

vm_src="$HOME/.config/Claude/vm_bundles/claudevm.bundle"
vm_dst="$HOME/.local/share/claude-desktop/vm"
daemon='${daemonScript}'
electron='${electronBin}'

if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
  sock="$XDG_RUNTIME_DIR/cowork-vm-service.sock"
else
  sock="/run/user/$(id -u)/cowork-vm-service.sock"
fi

mkdir -p "$vm_dst"

for name in rootfs.vhdx vmlinuz initrd rootfs.vhdx.zst vmlinuz.zst initrd.zst; do
  if [ -e "$vm_src/$name" ]; then
    ln -sfn "$vm_src/$name" "$vm_dst/$name"
  fi
done

if [ -e "$vm_dst/rootfs.vhdx" ] && [ ! -e "$vm_dst/rootfs.qcow2" ]; then
  tmp_qcow2="$vm_dst/rootfs.qcow2.tmp"
  rm -f "$tmp_qcow2"
  ${final.qemu_kvm}/bin/qemu-img convert -f vhdx -O qcow2 "$vm_dst/rootfs.vhdx" "$tmp_qcow2"
  mv "$tmp_qcow2" "$vm_dst/rootfs.qcow2"
fi

export SOCK="$sock"
export DAEMON="$daemon"
export ELECTRON="$electron"

${pythonBin} - <<'PY'
import os
import socket
import subprocess
import time

sock = os.path.expanduser(os.environ['SOCK'])
daemon = os.path.expanduser(os.environ['DAEMON'])
electron = os.path.expanduser(os.environ['ELECTRON'])

def healthy(path):
    if not os.path.exists(path):
        return False
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.3)
    try:
        s.connect(path)
        return True
    except OSError:
        return False
    finally:
        s.close()

if not healthy(sock):
    try:
        if os.path.exists(sock):
            os.unlink(sock)
    except OSError:
        pass

    env = os.environ.copy()
    env['ELECTRON_RUN_AS_NODE'] = '1'
    subprocess.Popen(
        [electron, daemon],
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

    for _ in range(20):
        if healthy(sock):
            break
        time.sleep(0.2)
PY

exec '${original}/bin/claude-desktop' "$@"
EOF
      chmod +x "$out/bin/claude-desktop"
    '';
  };
}
