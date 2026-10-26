# Rupan's development VM

`nixosConfigurations.agent-rupan` is the headless NixOS guest on `homelab-04`.
The hypervisor definition and isolated network belong to the homelab repository.
Sam's `agent-sam` guest and Akshath's `omarchy-akshath` guest are separate owners
and must not be redefined, restarted, or have their disks touched by this workflow.

The guest keeps the existing `developer` SSH username, MAC `02:00:00:10:00:02`,
address `172.31.10.2/30`, and gateway `172.31.10.1`. It has 2 virtual CPUs, 8 GiB
RAM, the existing 100 percent whole-domain CPU limit, and a fresh 96 GiB disk.
Use the existing host-enforced network isolation; this guest is not a cluster
node and receives no infrastructure credentials or host filesystem shares.

## Shared environment

`home/rupan/agent-vm.nix` imports the same `ai-tools.nix` module as the laptop.
Codex, Claude Code, OpenCode and Pi therefore use the same flake input pins.
`ai-tools.desktop = false` omits graphical Antigravity; the CLI remains installed.
The VM adds fish, tmux, Git, Node, Python/uv, build tools, and Nix development
shell support. Project-specific dependencies still belong in each project's
development shell. Updates happen by rebuilding this host from the same lock,
not by independently updating globally installed CLI binaries.

Provider logins, MCP credentials, and mutable conversation state are runtime
data. They are not embedded in the image and are not copied from the laptop by
building this configuration.

The VM preconfigures the signed homelab binary cache and accepts flake settings,
as the laptop does. This avoids an interactive Nix configuration prompt inside
direnv, which has no terminal input. Signature verification remains enabled;
the developer user is not added to `trusted-users`. The hypervisor must grant
this guest TCP access to the NAS cache at `10.0.30.20:8080`.

## Build and access

Build the installed BIOS qcow2 image with:

```sh
nix build .#nixosConfigurations.agent-rupan.config.system.build.qcow2
```

This produces `result/nixos.qcow2`. Building is safe; installing that image over
an existing VM disk is destructive and requires explicit replacement authorization.
Use the homelab workspace runbook and its Rupan-specific domain XML for installation.
Do not use the Ubuntu cloud-image workspace provisioner for this guest.

The installation artifact is 8 GiB. Expand its installed copy to 96 GiB with
`qemu-img resize` before boot; the guest grows its partition and ext4 filesystem
on first boot. Building a compact artifact also avoids the pinned LKL builder's
[large-volume hang](https://github.com/lkl/linux/issues/466), caused by its small
internal kernel memory allocation. Increasing `memSize` only changes the later
bootloader-installation VM and does not increase the filesystem copier's memory.

Connect through the actual hypervisor:

```sh
ssh -J rupan@10.0.30.14 developer@172.31.10.2
```

Run agents inside tmux. User linger and `KillUserProcesses = false` keep the
terminal and its processes alive after an SSH disconnect. Reattach after
reconnecting. A guest reboot terminates running processes; saved conversations
can be resumed, but tmux does not preserve a live process across reboot.

For subsequent updates, copy or clone this configuration onto the guest, retain
the lock file, and build/switch the `agent-rupan` target inside the guest.
The guest's developer account has administrative access within this VM only.
No unattended update service or laptop deployment branch controls this host.
