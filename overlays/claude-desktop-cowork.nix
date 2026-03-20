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
  resourcesDir = "${app}/lib/claude-desktop/resources";
  smolBinVhdx = "${app}/lib/claude-desktop/resources/smol-bin.x64.vhdx";
  daemonScript = "${app}/lib/claude-desktop/resources/app.asar.unpacked/cowork-vm-service.js";
  electronBin = "${prev.electron}/bin/electron";
  pythonBin = "${final.python3}/bin/python";
in {
  claude-desktop-fhs = final.symlinkJoin {
    name = original.name;
    paths = [ original ];
    postBuild = ''
      rm -f "$out/bin/claude-desktop"
      mkdir -p "$out/libexec"
      cp "${original}/bin/claude-desktop" "$out/libexec/claude-desktop-fhs"
      chmod u+w "$out/libexec/claude-desktop-fhs"
      export CLAUDE_FHS_LAUNCHER="$out/libexec/claude-desktop-fhs"
      export CLAUDE_CUSTOM_ROOTFS="$out/libexec/claude-desktop-fhsenv-rootfs"
      ${pythonBin} - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["CLAUDE_FHS_LAUNCHER"])
custom_rootfs = Path(os.environ["CLAUDE_CUSTOM_ROOTFS"])
text = path.read_text()

prefix = 'for i in '
suffix = '/*; do'
rootfs = None
for line in text.splitlines():
    if line.startswith(prefix) and line.endswith(suffix):
        rootfs = line[len(prefix):-len(suffix)]
        break

if rootfs is None:
    raise SystemExit('Failed to locate original rootfs path')

orig_rootfs = Path(rootfs)
custom_rootfs.mkdir(parents=True, exist_ok=True)

for child in orig_rootfs.iterdir():
    target = custom_rootfs / child.name
    if child.name == 'usr':
        target.mkdir(exist_ok=True)
        for usr_child in child.iterdir():
            usr_target = target / usr_child.name
            if not usr_target.exists():
                usr_target.symlink_to(usr_child)
        (target / 'local').mkdir(exist_ok=True)
        (target / 'local' / 'bin').mkdir(exist_ok=True)
        claude_link = target / 'local' / 'bin' / 'claude'
        if claude_link.exists() or claude_link.is_symlink():
            claude_link.unlink()
        claude_link.symlink_to(Path('${final.claude-code}/bin/claude'))
    elif not target.exists():
        target.symlink_to(child)

path.write_text(text.replace(rootfs, str(custom_rootfs)))
PY
      chmod +x "$out/libexec/claude-desktop-fhs"
      cat > "$out/libexec/claude-cowork-node-shim.js" <<'EOF'
Object.defineProperty(process, 'resourcesPath', {
  value: '${resourcesDir}',
  configurable: true,
  enumerable: true,
  writable: false,
});
EOF
      cat > "$out/bin/claude-desktop" <<'EOF'
#!${final.bash}/bin/bash
set -euo pipefail

export PATH='${runtimePath}':"$PATH"

out_dir="$(dirname "$(dirname "$(readlink -f "$0")")")"

vm_src="$HOME/.config/Claude/vm_bundles/claudevm.bundle"
vm_dst="$HOME/.local/share/claude-desktop/vm"
daemon='${daemonScript}'
electron='${electronBin}'
node_shim="$out_dir/libexec/claude-cowork-node-shim.js"

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

if [ -e '${smolBinVhdx}' ]; then
  ln -sfn '${smolBinVhdx}' "$vm_src/smol-bin.vhdx"
fi

if [ -e "$vm_dst/rootfs.vhdx" ] && [ ! -e "$vm_dst/rootfs.qcow2" ]; then
  tmp_qcow2="$vm_dst/rootfs.qcow2.tmp"
  rm -f "$tmp_qcow2"
  ${final.qemu_kvm}/bin/qemu-img convert -f vhdx -O qcow2 "$vm_dst/rootfs.vhdx" "$tmp_qcow2"
  mv "$tmp_qcow2" "$vm_dst/rootfs.qcow2"
fi

export SOCK="$sock"
export DAEMON="$daemon"
export ELECTRON="$electron"
export NODE_SHIM="$node_shim"

${pythonBin} - <<'PY'
import os
import socket
import subprocess
import time

sock = os.path.expanduser(os.environ['SOCK'])
daemon = os.path.expanduser(os.environ['DAEMON'])
electron = os.path.expanduser(os.environ['ELECTRON'])
node_shim = os.path.expanduser(os.environ['NODE_SHIM'])

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
    env['NODE_OPTIONS'] = f'--require={node_shim}'
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

exec "$out_dir/libexec/claude-desktop-fhs" "$@"
EOF
      chmod +x "$out/bin/claude-desktop"
    '';
  };
}
