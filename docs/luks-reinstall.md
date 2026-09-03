# LUKS + btrfs install record

Status: complete and stable. The laptop runs the LUKS2 + btrfs layout
(`hosts/laptop/disko.nix`) with camp-1 impermanence
(`impermanence.enable`, `modules/nixos/impermanence.nix`): `@root` rolls
back to a blank snapshot every boot, `@home`/`@nix` are durable, and
declared system state lives on `@persist`. The rehearsal host
(`laptop-crypt`, `just vm-crypt`) has been removed; the layout lives on
`laptop` itself (sudoers and auto-update are pinned to `#laptop`).

## Current state

- `hosts/laptop/configuration.nix` imports `./disko.nix`, the disko
  module, `./resume-offset.nix` (when present), and sets
  `impermanence.enable`, `btrfs-snapshots.enable`, and
  `secureboot.measuredBoot.enable`.
- `virtualisation.vmVariantWithDisko` lives on the laptop host; `just
  vm-disko` boots the real disko layout in QEMU.
- Scheduled snapshots are handled by `modules/nixos/btrfs-snapshots.nix`
  (btrbk, daily, `@home` and `@persist` into `@snapshots`). They are
  same-disk and are not a backup: an off-machine copy is still missing.

## Testing the disk layout

- `just eval laptop` green.
- `just vm-disko`: runs the actual disko script (partition, LUKS format,
  btrfs subvolumes) inside QEMU and boots the result. Login rupan/rupan.
  Inside the VM check: `lsblk` (cryptroot present), `findmnt -t btrfs`
  (subvol mounts + compress=zstd:1), `swapon --show`.

## Maintenance

- Keep `hosts/laptop/resume-offset.nix`; regenerate it if the swapfile is
  ever recreated (the btrfs swapfile's physical offset only exists once
  the file does):
  ```bash
  offset=$(sudo btrfs inspect-internal map-swapfile -r /.swap/swapfile)
  cat > ~/nixos/hosts/laptop/resume-offset.nix <<EOF
  # Generated after install: physical offset of /.swap/swapfile within
  # /dev/mapper/cryptroot. Regenerate if the swapfile is ever recreated.
  {
    boot.resumeDevice = "/dev/mapper/cryptroot";
    boot.kernelParams = [ "resume_offset=$offset" ];
  }
  EOF
  ```
  It must be committed: an untracked file is invisible to the flake.
- TPM unlock binds to the systemd-pcrlock policy rather than a static PCR
  set (`secureboot.measuredBoot.enable` is on): pcrlock is rewritten on
  every `nixos-rebuild`, so kernel and UKI updates do not invalidate the
  keyslot the way `--tpm2-pcrs=7` does. To re-enroll:
  ```bash
  sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=true \
    --tpm2-pcrlock=/var/lib/systemd/pcrlock.json /dev/nvme0n1p2
  ```
  pcrlock state lives in `/var/lib/pcrlock.d` and
  `/var/lib/systemd/pcrlock.json`; both are preserved under /persist, and
  losing them turns the TPM keyslot into a passphrase prompt. The
  passphrase keyslot always works as fallback;
  `systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2` resets enrollment.
- Health checks: `bootctl status` (Secure Boot enabled, Measured UKI yes),
  `findmnt -t btrfs`, `ls /run/secrets/` (sops decrypted),
  `systemctl list-timers btrbk-local btrfs-scrub-*` (snapshot and scrub
  jobs armed).
- When something resets after reboot (a pairing, a service login, a cert),
  find its state dir, add it to `preservation.preserveAt."/persist"` in
  `modules/nixos/impermanence.nix`. Note: the outgoing root used to be
  parked in `old_roots/` for 14 days after install; that window has long
  passed, so there is no parked copy left to recover from.

## History (how the install was done)

The single NVMe was rebuilt as LUKS2 + btrfs subvolumes, keeping secure
boot, sops secrets, and the SSH host identity intact. `laptop-crypt` was
the rehearsal host; on install day the layout was folded into `laptop`
itself. Non-negotiables before wiping were `/var/lib/sbctl` (secure boot
signing keys) and `/etc/ssh/ssh_host_ed25519_key*` (the sops age identity
and machine SSH identity), both root-owned and copied with sudo from a
real terminal. The external backup was sized at ~593G of root usage:

```bash
# as root, to an external disk mounted at /mnt/backup
rsync -aHAX --info=progress2 /home/rupan/ /mnt/backup/home/
rsync -aHAX /etc/ssh/ /mnt/backup/etc-ssh/
rsync -aHAX /var/lib/sbctl/ /mnt/backup/sbctl/
rsync -aHAX /var/lib/asusd /var/lib/fprintd /mnt/backup/var-lib/ 2>/dev/null || true
```

Install day ran from an ISO USB boot: the flake's own disko built
`destroyFormatMount` for `laptop-crypt`, key material was restored under
both `/mnt/persist/...` and the plain paths (the plain copies evaporated
on the first rollback boot), then `nixos-install --flake ~/nixos#laptop`,
`passwd rupan` via `nixos-enter`, resume-offset generation, TPM
enrollment, and verification. If secure boot had refused the fresh
binaries, the fallback was disabling it in the BIOS (F2), fixing keys via
`sbctl`, and re-enabling.

## Follow-up work

- A pre-switch snapshot hook. Scheduled snapshots exist (above); a hook
  that snapshots before each switch does not.
- An off-machine backup. btrbk snapshots are same-disk; there is still no
  automated off-machine copy.
