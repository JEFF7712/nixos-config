# Claude Cowork Debug Notes

## Current failure
- `VM service not running. The service failed to start.` appears in Claude Desktop logs after cowork setup work begins.
- The UI-side failure also surfaces through plugin and guest-state calls that assume the VM service is already available.

## Known-good prerequisites
- `/dev/kvm` exists.
- user `rupan` is in `kvm`.
- VM bundle now downloads successfully and reaches `All files ready in /home/rupan/.config/Claude/vm_bundles/claudevm.bundle`.

## Relevant evidence
- `~/.config/Claude/logs/cowork_vm_node.log` shows earlier failures on 2026-03-08:
  - `EXDEV: cross-device link not permitted, rename '/tmp/wvm-.../rootfs.vhdx' -> '/home/rupan/.config/Claude/vm_bundles/claudevm.bundle/rootfs.vhdx'`
- `~/.config/Claude/logs/cowork_vm_node.log` shows newer success on 2026-03-18:
  - `rootfs.vhdx.zst checksum validated`
  - `vmlinuz.zst checksum validated`
  - `initrd.zst checksum validated`
  - `All files ready in /home/rupan/.config/Claude/vm_bundles/claudevm.bundle`
- `~/.config/Claude/logs/unknown-window.log` and `~/.config/Claude/logs/claude.ai-web.log` show:
  - `QueryClient error: ... Error: VM service not running. The service failed to start.`

## Current interpretation
- Initial cowork failures were caused by a cross-device rename bug while moving large VM artifacts from `/tmp` into the Claude bundle directory.
- That specific download issue no longer blocks the current run.
- The active failure is now later in the flow: the VM bundle exists, but the local VM service does not come up.

## Next artifact to inspect
- launcher path: `/etc/profiles/per-user/rupan/bin/claude-desktop` -> `/nix/store/vcxw7p00ab87q1ygdhljx1d0i52j1q06-claude-desktop-bwrap`
- subprocess path: `process.resourcesPath/app.asar.unpacked/cowork-vm-service.js`
- installed Claude Desktop init path: `/nix/store/6x1iiqvs9zvqzw179kcnvbpvhw1wg4fb-claude-desktop-init`

## Launcher details
- The profile `claude-desktop` command is a bubblewrap launcher.
- That launcher sources `/etc/profile` inside the FHS environment and then execs `/nix/store/05xdmv6f56d03jbnz1mbr6ly4l0bg29s-claude-desktop-1.1.7203/bin/claude-desktop`.
- The desktop app autolaunches the Linux cowork daemon by forking `process.resourcesPath/app.asar.unpacked/cowork-vm-service.js` with `ELECTRON_RUN_AS_NODE=1`.
- Manual daemon launch using that same Electron binary exits immediately with status `1` and does not create `~/.config/Claude/logs/cowork_vm_daemon.log`.

## Early runtime clues
- The unpacked daemon code requires several host commands for its backends: `qemu-system-x86_64`, `qemu-img`, `virtiofsd`, `socat`, and `bwrap`.
- In the current launcher environment, `qemu-system-x86_64`, `qemu-img`, and `virtiofsd` resolve from `/run/current-system/sw/bin`.
- `socat` and `bwrap` do not resolve on `PATH` there.
- `/dev/vhost-vsock` exists.
- `rootfs.qcow2` does not yet exist in `~/.config/Claude/vm_bundles/claudevm.bundle`; only `rootfs.vhdx` plus kernel/initrd are present.

## Root cause hypothesis
- launcher: Linux cowork daemon at `${process.resourcesPath}/app.asar.unpacked/cowork-vm-service.js`
- failure: the daemon expects its VM assets in `~/.local/share/claude-desktop/vm`, but Claude Desktop downloads them into `~/.config/Claude/vm_bundles/claudevm.bundle`
- missing dependency: the daemon also expects `socat` and `bwrap` on `PATH`, and KVM auto-detection requires `rootfs.qcow2` to exist before backend selection
- why this matches the app log: without the expected VM path and backend tools, the service falls back poorly or never reaches the ready state the UI expects, producing `VM service not running`

## Confirmed behavior outside the app
- Launching the daemon directly under Electron run-as-node works and creates `/run/user/1000/cowork-vm-service.sock`.
- With the original environment, that daemon reports:
  - `KVM not available: ... access '/home/rupan/.local/share/claude-desktop/vm/rootfs.qcow2'`
  - `bwrap not available: Command failed: which bwrap`
  - `Backend: host (no isolation)`
- A local package wrapper that prepares `~/.local/share/claude-desktop/vm`, converts `rootfs.vhdx` to `rootfs.qcow2`, and injects `bubblewrap`, `socat`, `qemu`, and `virtiofsd` builds successfully and starts the cowork service socket before Claude Desktop launches.
