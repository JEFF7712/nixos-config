# Rupan's development VM

`nixosConfigurations.vm` is the headless NixOS guest on `homelab-04`.
The hypervisor definition and isolated network belong to the homelab repository.
Sam's `agent-sam` guest and Akshath's `omarchy-akshath` guest are separate owners
and must not be redefined, restarted, or have their disks touched by this workflow.

The guest keeps the existing `developer` SSH username, MAC `02:00:00:10:00:02`,
address `172.31.10.2/30`, and gateway `172.31.10.1`. It has 2 virtual CPUs, 8 GiB
RAM, the existing 100 percent whole-domain CPU limit, and a fresh 96 GiB disk.
It is not a cluster node and has no host filesystem shares. Since 2026-10-26 it
is a full operator workstation equivalent to the laptop: the homelab runbook
`docs/runbooks/agent-workspaces.md` lists the credentials it holds, its
host-enforced egress grants, and how to revoke them. The image itself carries
no credentials; they live in the developer home directory.

`networking.hosts` maps `git.internal`, `s3.internal`, `ci.internal` and
`OPNsense.internal` (`192.168.1.1`, matching homelab's DNS inventory), since
the guest uses public DNS. `earlyoom` kills the largest build or evaluation
process before memory pressure starves `sshd`. Pull updates over
`git-agent:JEFF7712/nixos-config.git`; `git.rupan.dev` sits behind Cloudflare
Access and rejects the guest.

OPNsense diagnostics also require the homelab hypervisor's Rupan-only TCP 443
egress grant. This hostname mapping alone does not grant network access. Use
the scoped read-only API credentials and retain CA and hostname verification.

## Shared environment

`home/rupan/vm.nix` imports the same `ai-tools.nix` module as the laptop.
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

## Browser and screenshots

The VM enables `agent-browser` in `home/rupan/vm.nix`. The Nix lock pins
Playwright MCP, its matching Chromium binaries, and the `playwright` CLI.
The module excludes Firefox and WebKit from the upstream browser bundle.
`agent-browser-mcp` starts Chromium headlessly on demand over stdio, with a
fresh isolated profile for each client and no listening port. DejaVu and emoji
fonts support screenshots without a desktop session.

Home Manager activation merges a `playwright` server into the developer's
Codex, Claude Code and OpenCode settings. It retains other settings and servers;
provider credentials remain runtime data. Restart existing agent sessions to
load the new tools. Other clients can use `agent-browser-mcp` as a stdio MCP
server, or run the `playwright` CLI from the shell.

Screenshots default to private session directories under
`~/.local/state/agent-browser/`. Agents should use page snapshots for interaction,
capture desktop and mobile screenshots for visual checks, inspect the resulting
images, and call `browser_close` when finished to release memory. The pinned MCP
version has no idle-timeout flag. Closing the client also closes its browser.
Profiles are disposable; authenticated testing can pass a dedicated
`--storage-state` file rather than sharing a personal browser profile.

Verify navigation, a JavaScript button click, and both screenshot sizes with:

```sh
agent-browser-check --output-dir ~/.local/state/agent-browser/acceptance --url https://example.com
```

The check uses a loopback HTTP fixture, verifies the resulting PNG dimensions,
retains `desktop.png` and `mobile.png`, and closes the browser. Omit `--url` for
an offline check. Inspect both images separately to verify visual rendering.
Registration preservation and failure cases are tested by
`lib/agent-browser/test_register.py` with the activation interpreter (Python
plus `tomlkit`).

To remove the integration, disable `agent-browser.enable`, rebuild the VM,
and remove only the `playwright` server from `.codex/config.toml`,
`.claude.json`, and `.config/opencode/opencode.json`. These mutable entries
survive a system-generation rollback; they refer to the user's current profile.

## Build and access

Build the installed BIOS qcow2 image with:

```sh
nix build .#nixosConfigurations.vm.config.system.build.qcow2
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
the lock file, and build/switch the `vm` target inside the guest.
After landing the source with `just ship`, run `just switch vm` from the clean
main checkout. This retains the activation lock and cascade guard and uses the
guest's one-build/two-core limits. It does not restart the guest.
The guest's developer account has administrative access within this VM only.
No unattended update service or laptop deployment branch controls this host.
