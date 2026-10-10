# Stage 2 reliability prototype design

Date: 2026-08-23

## Context

Stage 1 proves the intent-to-transaction wedge for three closure-reversible
capabilities. It stores distinct active and blessed pointers, restores the
blessed closure after detected activation failures, and verifies the pipeline
in NixOS VMs. It does not enforce those pointers through boot, authenticate its
journal, survive hard power loss, or certify a physical machine.

Stage 2 adds the deterministic reliability core required by the architecture
contract. It does not expand into session actions, general privileged agency,
third-party capabilities, or the Stage 3 release update channel.

The named physical profile is the ASUS Zenbook UX3404VC. The observed target
has Intel Iris Xe graphics at PCI `0000:00:02.0`, an NVIDIA GeForce RTX 3050
Laptop GPU at PCI `0000:01:00.0`, UEFI firmware, Secure Boot, TPM2, systemd-boot
260.2, and Lanzaboote 1.1.0. These observations guide the prototype but do not
constitute certification. Certification requires the acceptance evidence in
this document.

## Goals

- Make the authenticated event journal authoritative for transaction history.
- Enforce distinct active and blessed transaction pointers across reboot.
- Keep a bootable prior blessed generation and a fixed recovery image.
- Recover from an unhealthy boot-affecting candidate within two boot attempts.
- Compare deterministic health with the machine's pre-change baseline.
- Add one closed boot-affecting capability, `hardware.graphics.profile`.
- Cover the complete Stage 2 injected-failure matrix in persistent-disk VMs.
- Recover without a model, network connection, general shell, or terminal
  commands.
- Certify exactly one physical profile only after the VM contract passes.

## Non-goals

- A general system update or signed release-manifest channel.
- Persistent application-data mutation or snapshot recovery.
- Session actions, open-ended privileged agency, or third-party capabilities.
- General hardware detection or support outside the certified UX3404VC profile.
- Proving user intent from machine health. Authorization and health remain
  separate gates.
- Protecting journal authenticity after total compromise of the root account,
  firmware, or TPM. The journal protects the deterministic core from
  unauthorized writers in the Stage 2 authority model and detects corruption,
  truncation, reordering, and rollback.

## Selected boot architecture

The prototype uses systemd-boot Automatic Boot Assessment through the boot
counting already supported by NixOS and Lanzaboote. The target laptop already
uses signed Lanzaboote UKIs, and the pinned Lanzaboote release has an upstream
VM test for boot-counted fallback.

Each boot-affecting candidate is installed as a signed UKI with one permitted
attempt. The candidate becomes the preferred entry for the next boot. Its prior
blessed UKI remains installed, is protected by an explicit garbage-collection
root, and has no exhausted boot counter. A candidate that reaches the intentd
health gate is blessed. A candidate that crashes, loses power, or fails health
does not reach `boot-complete.target`, so systemd does not mark its UKI good.
The next boot skips the exhausted candidate and selects the prior blessed
entry. The failed candidate therefore consumes boot attempt one and the prior
blessed generation is selected on boot attempt two.

This delegates entry selection and attempt decrementing to the bootloader
instead of reproducing them in privileged Python. intentd owns the transaction
state, expected boot identities, health decision, and recovery reconciliation.

The rejected alternatives are a custom intentd boot-entry manager, which
duplicates bootloader behavior and expands the trusted surface, and a
userspace-only watchdog, which cannot recover from failures before userspace.

## Boot artifacts and identities

Every boot-affecting transaction pins all of the following before activation:

- Candidate Nix store closure.
- Candidate UKI content hash and systemd-boot entry identifier.
- Prior blessed transaction, closure, UKI hash, and entry identifier.
- Fixed recovery UKI hash and entry identifier.
- Pre-change health baseline.
- Capability version, catalog epoch, instantiated manifest hash, rendered
  source hash, flake lock hash, and policy decision.

The booted system reports its closure through `/run/current-system` and its
loader entry through systemd's boot-loader interface. The boot guard requires
both identities to match the authenticated pending or blessed record. A closure
that boots under an unexpected entry, or an entry that names an unexpected
closure, fails closed.

The blessed and recovery UKIs are availability prerequisites. A transaction
cannot enter pending if either artifact is absent, unverifiable, unsigned,
unselectable, or lacks its required garbage-collection root. ESP free space and
reserved root-filesystem capacity are checked before installing a candidate.

## Graphics capability

`hardware.graphics.profile` is a boot-affecting capability with one closed
parameter:

```text
profile: integrated | hybrid-nvidia
```

`integrated` selects the certified Intel graphics path and disables the
discrete NVIDIA configuration. `hybrid-nvidia` selects the certified Intel plus
NVIDIA PRIME offload path. The renderer owns a closed set of Nix declarations
for driver selection, modesetting, PRIME bus identifiers, and the services
required by the certified profile. Capability input cannot inject Nix source,
package names, PCI identifiers, kernel parameters, or executor commands.

The machine profile supplies the fixed PCI identifiers and supported driver
facts. Policy rejects the capability on any machine whose authenticated
hardware facts do not match the certified profile. The VM uses a certified test
profile with simulated health evidence, while the physical acceptance run uses
the UX3404VC facts.

Changing graphics profile always builds and installs a boot candidate. It
cannot become blessed from a live `switch-to-configuration test` activation.

## Authenticated journal

The event journal is an append-only sequence of canonical records. Each record
contains:

- Format version and key identifier.
- Monotonic sequence number.
- Transaction identifier and event type.
- Canonical event payload.
- Previous record MAC.
- HMAC-SHA256 over the canonical record body.

The first record binds an explicit journal identifier and zero predecessor.
Verification rejects an unsupported format, invalid MAC, missing or duplicate
sequence, broken predecessor, malformed payload, unknown event, transaction
invariant violation, or valid prefix that is older than the sealed checkpoint.
The checkpoint prevents replacement of the journal by a previously valid
prefix.

Production loads the journal key from a root-only, TPM2-bound systemd
credential. VM tests inject a fixed test key through the same credential
interface. The key is never stored in the journal or SQLite database and is
not available to the model-facing process. Missing or unreadable credentials
make the control plane read-only and block activation.

Appending a transition writes the complete record, flushes it with `fsync`, and
flushes the containing directory before updating derived state. Journal append
failure leaves the prior state authoritative and stops the transaction.

SQLite remains a query projection for the CLI and control plane. Each projected
transition records the source journal sequence and MAC. Startup verifies the
complete journal, verifies the sealed checkpoint, discards projection state
that cannot be justified by the journal, and replays any authenticated tail.
SQLite can lag the journal after a crash, but it cannot authoritatively lead it.

## Health model

The pre-change baseline records machine conditions immediately before the
candidate becomes pending. Health evaluation compares the candidate with that
baseline so an already absent condition, such as network connectivity when no
network is available, is not misattributed to the change.

The boot health gate checks:

- Booted closure and boot-entry identity.
- Authenticated journal and pointer consistency.
- Root filesystem availability and reserved free space.
- All profile-defined critical systemd services.
- A usable display session, or the constrained recovery console when display
  is unavailable.
- Policy, capability, manifest, and catalog-epoch bindings.
- Availability and integrity of the prior blessed and recovery artifacts.

Network and model availability are observations, not boot-health requirements.
Their loss cannot prevent blessing or recovery unless the capability declared
a separately authorized outcome that requires them. The graphics capability
does not.

Machine health does not establish correct user intent. A healthy candidate is
eligible for blessing only when its typed invocation, signed capability,
manifest, catalog epoch, and policy authorization match the pending journal
record.

## Boot guard and watchdog

An early intentd boot-guard service verifies journal integrity and boot identity
before normal reconciliation. An intentd health service is required by and
ordered before `boot-complete.target`. systemd-bless-boot therefore cannot mark
the UKI good until the deterministic health gate succeeds.

For a matching pending candidate:

1. Verify the authenticated record and pinned boot artifacts.
2. Evaluate the health contract within fixed per-check and total deadlines.
3. Append the authenticated blessed transition.
4. Atomically advance active and blessed projections.
5. Release `boot-complete.target` so systemd marks the UKI good.

Failure never invokes the model. The health service records a bounded local
failure report when the journal remains writable, does not release
`boot-complete.target`, and allows the watchdog to reboot. A hard hang is
handled by the external VM or hardware watchdog. The exhausted candidate is
skipped on the next boot.

When the prior blessed entry boots after a failed candidate, the boot guard
appends an aborted transition with recovery evidence, restores the active
projection to blessed, and quarantines the candidate. An aborted or quarantined
transaction can never become active through reconciliation. Reapplying the same
desired state requires a new transaction and fresh authorization.

## Recovery image and console

The recovery artifact is a fixed, signed UKI built independently of candidate
state and retained as a permanent boot entry. It contains only the storage and
display or basic-console support required by the certified profile, journal
verification, boot-artifact inspection, and a constrained recovery application.
It does not contain a model client, network dependency, general shell action,
or arbitrary command runner.

The recovery application exposes exactly these actions:

1. Inspect authenticated journal and boot status.
2. Select a verified blessed generation.
3. Reboot.
4. Power off.

If graphical display is unavailable, the same bounded application is available
on the basic local console. This satisfies terminal-free recovery because the
user selects typed actions rather than entering shell commands. The recovery
image is selected only when the candidate and prior blessed paths are both
unusable, or explicitly from the boot menu.

## Transaction lifecycle

1. Resolve the request to `hardware.graphics.profile` and validate its closed
   parameter.
2. Instantiate the manifest, evaluate policy, render, and build without
   changing runtime or boot state.
3. Capture the prior health baseline and verify blessed and recovery artifacts.
4. Append authenticated validated and built evidence.
5. Install and verify the signed, boot-counted candidate UKI.
6. Append pending state before changing boot preference.
7. Make the candidate preferred for the next boot and reboot.
8. Let the boot guard and health gate bless or reject the candidate without a
   model or network.
9. On failure, boot the prior blessed entry by attempt two, append abort and
   recovery evidence, restore active to blessed, and quarantine the candidate.

Build, policy, catalog, journal, signing, ESP-capacity, and boot-entry failures
stop before reboot. A pending record without a changed boot preference is safe
and is reconciled as aborted. A changed preference without a pending record is
rejected by the next boot guard and cannot be blessed. Recovery behavior is
derived from authenticated state and observed boot identity, not from the
assistant's description.

## Failure matrix

The Stage 2 VM matrix has explicit expected outcomes:

| Injection | Required outcome |
| --- | --- |
| Failed build | Reject before pending; boot state unchanged. |
| Failed activation or UKI installation | Abort or reject before reboot; prior blessed remains selected. |
| Hard power loss during activation | Replay authenticated state; prior blessed selected by boot attempt two. |
| Disk pressure | Reject before candidate installation unless reserved recovery capacity remains. |
| Broken display | Candidate not blessed; prior blessed or recovery console selected. |
| Critical-service failure | Candidate not blessed; prior blessed selected by boot attempt two. |
| Network and model unavailable | Deterministic blessing or recovery completes unchanged. |
| Wrong intent but healthy system | Authorization binding fails; candidate is never blessed. |
| Audit persistence failure | Stop before authoritative transition; no unjournaled activation. |
| Stale or rolled-back catalog | Policy rejects before pending. |
| Stale-state reapplication | Quarantined transaction remains inactive; a new transaction is required. |

## Verification strategy

Unit tests cover canonical journal encoding, MAC chains, checkpoint rollback
detection, replay, pointer invariants, boot-attempt accounting, health-baseline
comparison, and graphics rendering. Integration tests cover torn journal tails,
lost SQLite projections, invalid MACs, unavailable credentials, projection
conflicts, stale catalogs, mismatched manifests, and quarantined reapplication.

The boot suite uses a persistent-disk UEFI NixOS VM that boots through
systemd-boot and Lanzaboote rather than direct kernel boot. Candidate, blessed,
and recovery UKIs persist across VM process restarts. Power-loss tests terminate
the VM without guest shutdown at multiple boundaries, then restart the same
disk image. Tests inspect the booted closure, loader entry, pointers, journal,
candidate quarantine, and model and shell independence.

The VM gate requires all of the following:

- No unhealthy, unauthorized, unauthenticated, or stale candidate is blessed.
- Every boot-affecting failure selects the prior blessed generation no later
  than boot attempt two.
- Every reversible non-boot failure recovers automatically or through the
  constrained recovery console.
- Journal corruption is detected before activation.
- Valid journal state reconstructs the SQLite projection exactly.
- Both graphics profiles bless successfully across a real VM reboot.
- The complete matrix passes with network and model access disabled.

## Delivery decomposition

Stage 2 is delivered as four sequential implementation milestones:

1. **Authenticated transaction substrate:** MAC-chained journal, credential
   loading, sealed checkpoint, SQLite projection replay, and audit-failure
   tests. VM development uses the injected credential; TPM2 binding is closed
   during physical certification.
2. **Boot reliability core:** boot-affecting transaction metadata, boot-counted
   UKIs, boot guard, baseline health gate, blessed artifact retention, recovery
   image, graphics capability, and persistent-disk VM reboot and power-loss
   proof.
3. **Failure-matrix closure:** every remaining injection, constrained recovery
   console, deterministic offline proof, and stale-state quarantine coverage.
4. **Physical certification:** immutable UX3404VC bill of materials and firmware
   baseline, both graphics profiles, Secure Boot and TPM evidence, real-host
   privilege path, and observed recovery run.

Each milestone must leave a working, testable system. Physical-host mutation is
not authorized by passing source tests alone and occurs only after the complete
VM gate passes.

## Stage 2 acceptance

Stage 2 is complete only when the repository contains reproducible evidence for
the full VM matrix and the named physical profile. Passing unit tests or a
successful normal reboot is insufficient. The evidence must identify the
candidate and recovered closures, both boot attempts, authenticated journal
events, active and blessed pointers, fault injected, health decision, and
absence of model or shell recovery dependencies.

The Stage 1 authority boundary remains unchanged: models may propose typed
capability invocations, while deterministic policy, constrained executor
primitives, boot selection, health checking, blessing, and recovery decide and
act.
