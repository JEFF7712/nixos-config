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
   - Keep `laptop-crypt` in the flake until cleanup; it does no harm.
2. Boot the ISO USB (`writeUSB`; the ISO auto-clones the repo).
3. Write the LUKS passphrase for disko (used once at format time):
   `echo -n 'THE-REAL-PASSPHRASE' > /tmp/disk.key`
4. Partition + format + mount:
   `sudo nix run github:nix-community/disko/v1.13.0 -- --mode destroy,format,mount --flake ~/nixos#laptop`
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
7. Reboot into the encrypted system, unlock with the passphrase.
8. `passwd` for rupan, then restore `/home/rupan` from backup.
9. Enroll the TPM so future boots skip the passphrase (PCR 7 = secure boot
   state; passphrase remains as fallback):
   `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2`
10. Verify: `bootctl status` (Secure Boot enabled, Measured UKI yes),
    `findmnt -t btrfs`, `ls /run/secrets/` (sops decrypted), reboot once
    more to confirm TPM auto-unlock AND that the root rollback ran
    (`ls /btrfs` gone, `sudo btrfs subvolume list / | grep old_roots`
    shows the parked root; anything you wrote to `/` outside /persist is
    gone).
11. Impermanence shakedown, first weeks: when something resets after
    reboot (a pairing, a service login, a cert), find its state dir,
    add it to `preservation.preserveAt."/persist"` in
    `modules/nixos/impermanence.nix`, and copy the current copy out of
    the newest `old_roots/<timestamp>/` into /persist before it ages out.

## Cleanup (after a few stable days)

- Delete `hosts/laptop-crypt/` and the `laptop-crypt` flake output; move
  `virtualisation.vmVariantWithDisko` into the laptop host if the rehearsal
  recipe should keep working.
- Remove `just vm-crypt` or repoint it at `laptop`.
- Follow-up work: snapshot automation for `@home`/`@root` (snapper or
  btrbk), and a pre-switch snapshot hook.

## If it goes wrong

- Machine won't boot with secure boot on: disable secure boot in the BIOS
  (F2 at boot), boot, fix keys (`sbctl` status/enroll), re-enable.
- TPM unlock misbehaves: the passphrase keyslot always works;
  `systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2` resets enrollment.
- Anything else: the ISO USB + the backup disk are the recovery path; the
  old system is gone the moment step 4 runs, so steps 1-3 are the last
  chance to abort cheaply.
