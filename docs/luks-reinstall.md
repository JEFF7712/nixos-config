# LUKS + btrfs reinstall runbook

Goal: rebuild the laptop's single NVMe as LUKS2 + btrfs subvolumes
(`hosts/laptop/disko.nix`), keeping secure boot, sops secrets, and the SSH
host identity intact. `laptop-crypt` is the rehearsal host; on install day
the layout is folded into `laptop` itself (sudoers and auto-update are
pinned to `#laptop`, so the installed system must be that ref).

The install also enables camp-1 impermanence (`impermanence.enable`,
`modules/nixos/impermanence.nix`): `@root` is rolled back to a blank
snapshot every boot, `@home`/`@nix` are durable, and declared system state
lives on the `@persist` subvolume. Fold `impermanence.enable = true` into
the laptop host together with the disko import. Expect the first weeks to
surface undeclared state; the outgoing root is parked in `old_roots/` for
14 days, so anything missed is recoverable from there before it ages out.

## Non-negotiables before wiping

Root's disk is erased. Two key sets make the difference between a smooth
first boot and an unbootable machine:

- `/var/lib/sbctl` (secure boot signing keys). The firmware db contains
  certs from THESE keys. If they are lost, lanzaboote's autoGenerateKeys
  makes new ones, the firmware rejects the freshly signed binaries, and the
  machine will not boot until secure boot is disabled in the BIOS.
- `/etc/ssh/ssh_host_ed25519_key*`. This is the sops age identity
  (`.sops.yaml` laptop recipient) and the machine's SSH identity. Without
  it, secrets fail to decrypt at activation.

Both are root-owned: copy them with sudo from a real terminal.

## Rehearsal (any time, no downtime)

- `just eval laptop-crypt` green.
- `just vm-crypt`: runs the actual disko script (partition, LUKS format,
  btrfs subvolumes) inside QEMU and boots the result. Login rupan/rupan.
  Inside the VM check: `lsblk` (cryptroot present), `findmnt -t btrfs`
  (subvol mounts + compress=zstd:1), `swapon --show`.

## Backup (day before)

Current usage is ~593G on root; size the external target accordingly.

```bash
# as root, to an external disk mounted at /mnt/backup
rsync -aHAX --info=progress2 /home/rupan/ /mnt/backup/home/
rsync -aHAX /etc/ssh/ /mnt/backup/etc-ssh/
rsync -aHAX /var/lib/sbctl/ /mnt/backup/sbctl/
# anything else stateful you care about:
rsync -aHAX /var/lib/asusd /var/lib/fprintd /mnt/backup/var-lib/ 2>/dev/null || true
```

Verify before proceeding: spot-check a few files (`diff`, `sha256sum`) and
confirm `~/nixos` and `~/nixos-assets` are pushed to their remotes.

## Install day

1. In the repo, fold the crypt layout into the laptop host, commit, push:
   - `hosts/laptop/configuration.nix`: import `./disko.nix` and the disko
     module; replace the `./hardware-configuration.nix` import with the
     laptop-crypt hardware config (copy it over
     `hosts/laptop/hardware-configuration.nix`).
   - Set `impermanence.enable = true` on the laptop host (it currently lives
     only in `hosts/laptop-crypt/configuration.nix`). Skipping this yields
     LUKS+btrfs with no root rollback and no /persist binds.
   - Keep `laptop-crypt` in the flake until cleanup; it does no harm.
2. Boot the ISO USB (`writeUSB`; the ISO auto-clones the repo).
3. Write the LUKS passphrase for disko (used once at format time):
   `echo -n 'THE-REAL-PASSPHRASE' > /tmp/disk.key`
4. Partition + format + mount. Use the flake's own disko (patched master,
   same as `just vm-crypt`), not a version tag: those are stale against
   current nixpkgs. This is destroy+format+mount and will prompt before
   wiping `/dev/nvme0n1`:
   `sudo nix run --no-write-lock-file ~/nixos#nixosConfigurations.laptop-crypt.config.system.build.destroyFormatMount`
5. Restore the key material BEFORE installing. The durable copies live
   under /persist (preservation bind-mounts them at runtime), but
   nixos-install's activation runs without those binds, so ALSO copy them
   to the plain paths; the plain copies evaporate on the first rollback
   boot, which is fine:
   ```bash
   mkdir -p /mnt/persist/var/lib/sbctl /mnt/persist/etc/ssh
   rsync -aHAX /path/to/backup/sbctl/ /mnt/persist/var/lib/sbctl/
   rsync -aHAX /path/to/backup/etc-ssh/ /mnt/persist/etc/ssh/
   mkdir -p /mnt/var/lib/sbctl /mnt/etc/ssh
   cp -a /mnt/persist/var/lib/sbctl/. /mnt/var/lib/sbctl/
   cp -a /mnt/persist/etc/ssh/. /mnt/etc/ssh/
   ```
6. `sudo nixos-install --flake ~/nixos#laptop --no-root-passwd`
   (lanzaboote signs with the restored keys; secure boot stays enforcing.)
7. Set rupan's password with nixos-enter before the first reboot:
   ```bash
   sudo nixos-enter --root /mnt -c "passwd rupan"
   test "$(readlink /mnt/etc/shadow)" = /persist/etc/shadow
   test -s /mnt/persist/etc/shadow
   ```
   Userborn keeps `passwd`, `group`, and `shadow` under `/persist/etc`, so
   `passwd` writes directly to durable state. Do not bind-mount `/etc/shadow`
   as a preservation file: NixOS activation updates it with atomic rename,
   which fails on a file mountpoint.
8. Reboot into the encrypted system, unlock with the passphrase, then
   restore `/home/rupan` from backup.
9. Wire up hibernate. The btrfs swapfile's physical offset only exists once
   the file does, so `hosts/laptop/configuration.nix` imports
   `./resume-offset.nix` if present and skips hibernate if not. Generate and
   commit it now:
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
   git -C ~/nixos add hosts/laptop/resume-offset.nix
   ```
   It must be committed: an untracked file is invisible to the flake. Then
   switch and test with `systemctl hibernate`. The root rollback is ordered
   after `systemd-hibernate-resume.service` so a resume boot never wipes the
   `@root` the restored image is running from; verify a resume actually
   resumes before trusting it.
10. Enroll the TPM so future boots skip the passphrase (passphrase remains as
    fallback). `secureboot.measuredBoot.enable` is on for this host, so bind
    to the systemd-pcrlock policy rather than a static PCR set: pcrlock is
    rewritten on every `nixos-rebuild`, so kernel and UKI updates do not
    invalidate the keyslot the way `--tpm2-pcrs=7` does.
    ```bash
    sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
    sudo systemd-cryptenroll       --tpm2-device=auto       --tpm2-with-pin=true       --tpm2-pcrlock=/var/lib/systemd/pcrlock.json       /dev/nvme0n1p2
    ```
    If `is-supported` says anything but `yes`, or if step 6's activation
    tripped on `systemd-pcrlock make-policy` from the installer, set
    `secureboot.measuredBoot.enable = false`, finish the install, and either
    re-enable it after the first real boot or fall back to the static
    enrollment: `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7
    /dev/nvme0n1p2` (which must be re-run after kernel updates).
    pcrlock state lives in `/var/lib/pcrlock.d` and
    `/var/lib/systemd/pcrlock.json`; both are already preserved under
    /persist, and losing them turns the TPM keyslot into a passphrase prompt.
11. Verify: `bootctl status` (Secure Boot enabled, Measured UKI yes),
    `findmnt -t btrfs`, `ls /run/secrets/` (sops decrypted), reboot once
    more to confirm TPM auto-unlock AND that the root rollback ran
    (`ls /btrfs` gone, `sudo btrfs subvolume list / | grep old_roots`
    shows the parked root; anything you wrote to `/` outside /persist is
    gone). `systemctl list-timers btrbk-local btrfs-scrub-*` should show the
    snapshot and scrub jobs armed.
12. Impermanence shakedown, first weeks: when something resets after
    reboot (a pairing, a service login, a cert), find its state dir,
    add it to `preservation.preserveAt."/persist"` in
    `modules/nixos/impermanence.nix`, and copy the current copy out of
    the newest `old_roots/<timestamp>/` into /persist before it ages out.

## Cleanup (after a few stable days)

- Delete `hosts/laptop-crypt/` and the `laptop-crypt` flake output; move
  `virtualisation.vmVariantWithDisko` into the laptop host if the rehearsal
  recipe should keep working.
- Remove `just vm-crypt` or repoint it at `laptop`.
- Keep `hosts/laptop/resume-offset.nix`; regenerate it if the swapfile is
  recreated.
- Follow-up work: a pre-switch snapshot hook. Scheduled snapshots are already
  handled by `modules/nixos/btrfs-snapshots.nix` (btrbk, daily, `@home` and
  `@persist` into `@snapshots`). They are same-disk and are not a backup:
  an off-machine copy is still missing.

## If it goes wrong

- Machine won't boot with secure boot on: disable secure boot in the BIOS
  (F2 at boot), boot, fix keys (`sbctl` status/enroll), re-enable.
- TPM unlock misbehaves: the passphrase keyslot always works;
  `systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2` resets enrollment.
- Anything else: the ISO USB + the backup disk are the recovery path; the
  old system is gone the moment step 4 runs, so steps 1-3 are the last
  chance to abort cheaply.
