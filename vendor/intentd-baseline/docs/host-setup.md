# Host setup

The Stage 1 privilege examples below describe the original live-activation
boundary. Stage 2 ships the root-owned deterministic boot guard through
`nix/reliability/module.nix`. The UX3404VC deployment is configured separately
in `~/nixos/modules/nixos/intentd-host.nix`.

**Physical certification is still open.** Every completed acceptance scenario runs
inside a `nixosTest` VM where intentd runs as root and there is no sudo
boundary to cross. None of the steps below have been exercised against a real
machine. Treat this as a starting point for that work, not a finished,
audited procedure -- review it against your own threat model before applying
it to hardware you care about.

## 1. Sudo wiring for activation

Production `wiring.py` (`_make_build_and_activate` in `src/intentd/wiring.py`)
drives two privileged commands, both already argv-shaped and store-path
validated by `executor.py`:

- `nix-env --profile /nix/var/nix/profiles/system --set <closure>`
  (`executor.set_profile_argv`)
- `<closure>/bin/switch-to-configuration switch` or `... test`
  (`executor.switch_argv`)

Both reject any `closure` that isn't a `/nix/store/...` path
(`executor._require_store_path`), so a NOPASSWD rule scoped to those two
command shapes does not hand out a general root shell.

On a real host you would run the intentd daemon as a dedicated, non-root
user (e.g. `intentd`) and have it invoke these two commands through `sudo`.
**That `sudo` prefix is not present in `executor.py` today** -- adding it is
a deliberate follow-up code change, not something this doc's sudoers rules
alone accomplish. Until that change lands, applying only the sudoers rules
below has no effect.

Following the pattern in `nix-agent`'s
`docs/privileged-automation.md` (resolved-store-path argv matching, narrowly
scoped NOPASSWD rules, no interactive prompts), the equivalent NixOS
configuration is:

```nix
security.sudo.extraRules = [
  {
    users = [ "intentd" ];
    commands = [
      {
        command = "${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set /nix/store/*";
        options = [ "NOPASSWD" ];
      }
      {
        command = "/nix/store/*/bin/switch-to-configuration switch";
        options = [ "NOPASSWD" ];
      }
      {
        command = "/nix/store/*/bin/switch-to-configuration test";
        options = [ "NOPASSWD" ];
      }
    ];
  }
];
```

Notes carried over from the nix-agent precedent, still true here:

- sudo matches the **resolved argv**, including argv[0]. If `executor.py`
  is changed to invoke `sudo nix-env ...` and `sudo <closure>/bin/switch-to-configuration ...`,
  the rules above are the argv sudo actually sees (after the `sudo` prefix
  itself). Keep the rule's command string and the code's actual argv in
  sync by hand; there is no automated check.
- `nix build` (the `_host_build` step) needs no sudo: it writes only to the
  intentd-owned workspace and the Nix store, not to `/nix/var/nix/profiles/system`.
- This is intentionally broader than a per-invocation manual approval flow
  and should only be applied on a host you trust to run the exact NixOS
  configurations intentd's policy layer allows through
  (`app.install` / `app.remove` / `change.revert` against the catalog).

## 2. Authenticated journal credential

intentd requires a 32-byte journal authentication key. Production services
receive it as the systemd credential `intentd-journal-key`; it is not placed in
the model-facing environment or the state directory. Configure the service
with `LoadCredential=journal-key:/run/agenix/intentd-journal-key` or the
equivalent secret-manager path, then name the loaded credential
`intentd-journal-key`.

Local development may set `INTENTD_JOURNAL_KEY_FILE` to a mode-0600 file that
contains exactly 32 bytes. The development override is rejected if group or
world permissions are present. Missing, unreadable, or malformed key material
blocks dependency construction before any state transition.

The authenticated files live beside `txn.db` as `journal.jsonl`,
`journal.checkpoint.json`, and `journal.lock`. SQLite is a disposable query
projection and is reconstructed from the journal. A non-empty Stage 1
`txn.db` has no authenticated provenance and is not silently imported. Use a
fresh Stage 2 state directory rather than treating legacy rows as trusted
history.

The VM harness injects a fixed test key through the development interface. It
does not prove TPM2 sealing or production secret provisioning.

## 3. Non-interactive resolver auth

The resolver (`src/intentd/resolver.py`) shells out to `claude -p`. In an
interactive session that reuses your logged-in Claude Code credentials. A
daemon has no interactive session to inherit credentials from, so it needs a
long-lived, non-interactive credential instead:

1. Run `claude setup-token` once, interactively, as whichever account should
   own the daemon's resolver calls. This mints a long-lived OAuth token
   (distinct from a normal interactive login) meant for exactly this
   non-interactive-service case.
2. Store the resulting token as the `CLAUDE_CODE_OAUTH_TOKEN` environment
   variable in the daemon's environment (e.g. a systemd service's
   `Environment=` / `EnvironmentFile=`, not committed to the repo or the Nix
   store in plaintext -- use `systemd.services.<name>.serviceConfig.LoadCredential`
   or an agenix/sops-nix secret, not a literal string in a `.nix` file).
3. `claude -p` picks up `CLAUDE_CODE_OAUTH_TOKEN` automatically and skips the
   interactive login flow. No other resolver code change is required.

Rotate the token the same way you'd rotate any other long-lived service
credential; `claude setup-token` can be re-run to mint a replacement.

## 4. Boot reliability deployment contract

Import `nixosModules.reliability` and configure the closed
`services.intentd.reliability` option set:

```nix
let
  intentdRecovery = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.intentd.nixosModules.reliabilityRecovery
      { system.stateVersion = "26.11"; }
    ];
  };
in
{
  services.intentd.reliability = {
    enable = true;
    stateDir = "/var/lib/intentd";
    machineProfile = "/etc/intentd/machine-profile.json";
    journalCredential = "/run/agenix/intentd-journal-key";
    recoveryClosure = "${intentdRecovery.config.system.build.toplevel}";
    recoveryEntryId = "intentd-recovery.efi";
  };
}
```

The state directory and its authenticated journal are root-owned and mode
`0700`. The journal source named by `journalCredential` is a root-readable,
mode-`0600` 32-byte secret. systemd loads it into the boot guard as the
`intentd-journal-key` credential. The machine profile is a root-owned,
declarative JSON file at `machineProfile`; it must be certified and must name
the critical units, display unit, graphics backend, PCI identities, and root
and ESP reserve thresholds for that exact host.

The host must use UEFI Secure Boot, systemd-boot, and the flake-pinned
Lanzaboote 1.1.0 module. Enabling reliability disables the systemd-boot
editor, enables Lanzaboote boot counting with one candidate attempt, and
configures a 30-second runtime watchdog. Candidate staging installs the signed
UKI, sets the authenticated prior blessed entry as the persistent default,
and selects the counted candidate as oneshot.

Build the recovery closure independently through
`nixosModules.reliabilityRecovery`, sign and install its UKI, and configure its
exact derived closure and canonical entry ID above. Install the signed UKI as
`/boot/EFI/Linux/intentd-recovery.efi`. The recovery entry is not boot
counted, has no network path, has no interactive root login, and exposes only
the authenticated journal inspector and the constrained recovery console:
`inspect`, `select-blessed`, `reboot`, and `poweroff`, with no model, network,
or shell action. The prior blessed, candidate, and
recovery closures must remain retained through explicit GC roots under
`/var/lib/intentd/gcroots`.

Before a boot-affecting transaction reaches pending, intentd authenticates all
three artifacts and checks both capacity bounds. Root free space must be at
least the certified `root_reserve_bytes`. ESP free space must remain at least
`esp_reserve_bytes` after accounting for the exact candidate UKI byte size.

`intentd-boot-guard.service` is wanted by `multi-user.target`, required by and
ordered before `boot-complete.target`, and starts only after local filesystems.
It has a 60-second total deadline and fails closed with
`FailureAction=reboot-force`. The guard accepts no resolver, model, network,
or free-form command input. A counted candidate can be blessed only after the
authenticated closure, entry ID, UKI bytes, transaction bindings, and health
snapshot all match. Every proposal binds the SHA-256 digest of the catalog
that authorized it, and a stale or rolled-back catalog is rejected once a
blessed transaction has established the floor. Every boot plan binds the
SHA-256 digest of its staged invocation, and the guard refuses to bless a
candidate whose plan does not match its transaction.

TPM2 monotonic rollback binding is implemented and tested against swtpm.
The production guard and recovery console open the store with the hardware
NV counter at `0x01800001`. Real firmware behavior, real GPU behavior,
credential provisioning, and privileged host service operation still require
physical acceptance.

## 5. What's still missing before this can run on real hardware

- `executor.py` does not yet prefix its privileged commands with `sudo`.
- The shipped root boot guard is deterministic; an always-running resolver
  daemon and its OAuth credential are separate work.
- The laptop deployment generates its journal key on first boot, outside the
  Nix store, with root ownership and mode `0600`. Physical provisioning and
  persistence need verification after boot.
- The ASUS Zenbook UX3404VC bill of materials, firmware baseline, signed
  recovery media, and physical fallback run are not certified.
- None of the above has been tested outside the VM harness.

Each is an explicit, reviewable follow-up; this document intentionally does
not paper over that gap.

## 6. UX3404VC deployment configuration (2026-10-07)

The laptop flake pins intentd commit `9ccae846ddecea7861e0eda99a1474ce025b72f0`
through a local Git input, sharing the host's existing nixpkgs and Lanzaboote
pins. The input requires this checkout to remain available for future builds.
The existing host Secure Boot module owns the Lanzaboote import.

`intentd-host` preserves `/var/lib/intentd` under `/persist`, creates the
journal credential through `intentd-state-init.service`, loads it through
systemd credentials, and retains the separately built recovery closure. The
machine profile reserves 10 GiB on root and 128 MiB on the ESP. Display
evidence checks the exact product and PCI device IDs, active greetd, and a
connected, enabled internal eDP connector. It does not prove that the user
can see or interact with the displayed content.

The recovery configuration reuses the actual encrypted disk layout and
binds the persistent journal and signing-key directories. It does not run
the daily driver's root-reset service. Building this closure does not sign
or install the fixed recovery UKI.

The profile's `certified` flag admits this named experimental profile to
policy; physical certification is incomplete until the boot transaction and
recovery round trip pass. On a fresh deployment the boot guard deliberately
skips an absent journal. Do not create an empty journal merely to enable the
guard: it needs a verified blessed anchor first.

The default workspace still uses the VM-oriented product flake, and production
candidate inspection expects an artifact manifest in the built closure. Host
transaction staging must bind the real host configuration and installed UKI
before it can be used on the laptop. The VM seed helper uses synthetic state
and lock evidence and must not be used to bootstrap physical history.
