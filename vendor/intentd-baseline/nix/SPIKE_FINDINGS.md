# M4 Task 1 spike findings: intentd package + offline VM smoke check

Status: COMPLETE. `nix build .#checks.x86_64-linux.vm-smoke` is GREEN.
Verdict up front: **in-VM flake evaluation is feasible** (offline eval+build
of the workspace flake takes ~18-20 s inside a 4-core/4096 MiB VM); locked
decision 8's pre-built-closure fallback is NOT needed.

All nixpkgs facts below were verified against this flake's locked rev
`e7a3ca8092b61ff85b6a45bf863ea2b2d6a661b3` (store path
`/nix/store/xqn9dl7vvji4mmp8h57xc39p2dp752vx-source`).

## packages.intentd (GREEN)

- `pkgs.python312Packages.buildPythonApplication { pyproject = true; src = self;
  build-system = [ hatchling ]; dependencies = [ pydantic ];
  pythonImportsCheck = [ "intentd" ]; }` builds clean:
  `nix build .#intentd` -> `/nix/store/wj7xsj276v20xaacmczcwdbqilzlijaw-intentd-0.1.0`.
- Hatchling (src layout) packages `catalog_data/apps.json` and
  `flake_template/{flake.nix,base.nix}` into the wheel with zero pyproject
  changes. Verified in the built output's site-packages.
- **Wrinkle: `buildPythonApplication` results are NOT python modules.** It is
  built with `toPythonModule = x: x` (python-packages-base.nix), so
  `python312.withPackages (ps: [ intentd ])` **silently drops it**
  (`requiredPythonModules` filters on `hasPythonModule`). Fix:
  `python312.withPackages (ps: [ (ps.toPythonModule intentd) ])`. The wrap is
  passthru-only; the store path is unchanged. Verified: the env's python
  imports intentd, `load_catalog()` returns 10 entries, and
  `importlib.resources` sees both flake_template files.
- New files must be `git add -N`ed before `nix build .#...` sees them (dirty
  git flake source = tracked files only).

## nixpkgs pinning / eval coherence (PROVEN, host and in-VM)

Requirement: the in-VM `nix build path:/var/lib/intentd/ws#...toplevel` must
reproduce the exact toplevel pre-seeded via `virtualisation.additionalPaths`,
else the offline build fails.

- **WORKING approach (host-proven drv equality):**
  `--override-input nixpkgs
  'path:<nixpkgs.outPath>?rev=<locked rev>&lastModified=<locked lastModified>'`
  on the in-VM `nix build`, with `<nixpkgs.outPath>` (the flake's own locked
  source store path) pre-seeded through `additionalPaths`. Registry rewriting
  is not needed; `path:` refs never consult the registry.
  `nix.settings.flake-registry = ""` is set anyway so nothing can try to fetch
  the global registry. Rewriting the workspace flake.nix was never attempted
  (it would trip the tamper manifest).
- **The rev+lastModified query params are REQUIRED.** A bare
  `path:/nix/store/...-source` override evaluates to a DIFFERENT toplevel:
  `nixpkgs/lib/flake-version-info.nix` derives `lib.trivial.versionSuffix`
  from `self.lastModifiedDate or "19700101"` and `self.shortRev or "dirty"`,
  and `revisionWithDefault` from `self.rev`. Observed on host:
  - outer github input:      `...-nixos-system-nixos-26.11.20260711.e7a3ca8.drv`
  - bare path override:      `...-nixos-system-nixos-26.11.19700101.dirty.drv`
  - path + rev+lastModified: `...-nixos-system-nixos-26.11.20260711.e7a3ca8.drv`
    (byte-identical drvPath `qw8rffkfv2wpcz7rm84cpznsad75zgli` to the outer
    eval; nix's path fetcher accepts `rev` and `lastModified` query attrs).
- The only other flake-metadata leak into the config is
  `nixpkgs.lib.nixosSystem` injecting `config.nixpkgs.flake.source =
  self.outPath` (nixpkgs flake.nix ~line 89), which is the same store path on
  both sides, so it is coherent by construction.
- Module *paths* (outer: `${self}/src/intentd/flake_template/base.nix` + a
  writeText generated.nix; in-VM: `/var/lib/intentd/ws/{base,generated}.nix`
  copied to the store) do not enter the toplevel drv; only evaluated config
  does. The testScript hard-asserts `built == candidate` as the coherence
  proof.
- `--no-write-lock-file` is passed in-VM. The ws has no flake.lock;
  `flake.lock` is NOT in the workspace manifest (only flake.nix/base.nix/
  generated.nix), so even a written lock would not trip verify_workspace, but
  the executor (Task 3/5) should still standardize on `--no-write-lock-file`
  + `--override-input` for offline builds.
- HOST-SIDE PRE-CHECK (cheap, before burning VM cycles): eval the candidate
  drvPath in the outer construction, then eval the ws flake drvPath with the
  same `--override-input`, compare. This caught the versionSuffix mismatch in
  seconds instead of a failed 10-minute VM run; keep the technique for any
  future coherence change.

### writeText-module trap (fixed)

`(nixpkgs.lib.nixosSystem { modules = [ base generatedDrv ]; })` fails with
the confusing error `In module '<nixpkgs>/flake.nix', you're trying to define
a value of type 'string' ... for the option 'system'`. Cause: a
`pkgs.writeText` DERIVATION passed directly in `modules` is treated as an
inline module attrset, so its `system = "x86_64-linux"` drv attribute becomes
a bogus definition of the NixOS `system` option (and the error is
misattributed to the last `_file`). Fix: pass the coerced string path
`"${generated}"` so the module system imports the file. String paths
(`"${self}/src/intentd/flake_template/base.nix"`) work fine as modules.

## switch-to-configuration inside the harness VM (design; all confirmed in VM runs)

Facts from source (test-instrumentation.nix, switch-to-configuration-ng
src/main.rs):

- The test driver's shell is `backdoor.service` (virtio console hvc0). It has
  **no** `X-StopOnRemoval=false`, and s-t-c stops active units whose unit file
  is gone in the new config (main.rs ~1238, default X-StopOnRemoval=true). The
  pure product candidate (base.nix + generated.nix) has no backdoor, so
  switching to it STOPS the test driver's shell.
- Worse: if s-t-c runs as a child of the backdoor shell, stopping
  backdoor.service kills the whole cgroup including s-t-c mid-activation.
- Consequence for the smoke test (and Tasks 5-6!): the switch must run in its
  own cgroup: `systemd-run --unit=smoke-switch <script>`, with the script
  reporting over `/dev/ttyS0` (serial console markers, readable by the driver
  via `wait_for_console_text` independent of the backdoor), then switching
  BACK to the original test-node toplevel (`nodes.machine.system.build
  .toplevel`, always present in the VM store) to resurrect the backdoor
  (s-t-c starts new wanted units). The full working resurrect sequence is:
  restore s-t-c, then explicitly `systemctl stop serial-getty@{hvc0,ttyS0}`
  and `systemctl restart backdoor.service` (a leftover getty/login from the
  candidate window still reads hvc0 and garbles the driver protocol
  otherwise), then emit the final console marker, and in the testScript
  drain `machine.shell` (see the resync section below) before the next
  command.
- `serial-getty@ttyS0`/`hvc0` are force-disabled by test-instrumentation but
  ENABLED in the plain qemu-vm candidate; during the candidate window a getty
  may grab hvc0 and spew onto the console. Console-marker parsing tolerates
  this; it is a known flakiness source to watch.
- Mount units: s-t-c unmounts filesystems whose fstab entry disappears, but
  special-cases `/` and `/nix` (never unmounted; reload or skip). Candidate
  and test node both derive from qemu-vm.nix defaults (mountHostNixStore ->
  writableStore), so fstabs matched; no mount churn was observed in any run.
- **Exit-code contract of s-t-c-ng (from main.rs):** `0` = clean; `1` = fatal
  error path; `4` = activation proceeded but some unit action failed (reload/
  restart/start failure or pre-switch check failures accumulate exit_code=4);
  `100` = "reboot required" path (not applicable to `test`). OBSERVED IN THE
  VM: **candidate switch rc=0 and restore switch rc=0, consistently across
  runs**, even though the candidate switch stops the backdoor and swaps
  gettys (stopping units is not a failure; only failed reload/restart/start
  jobs set 4). The check asserts `rc in (0, 4)` and prints the observed
  values; the executor (Task 3/5) should treat 0 as success, 4 as
  "activated with degraded units" (surface it; health decides), and anything
  else as failure.

## VM node settings (validated green)

- `virtualisation.memorySize = 4096` was sufficient (no OOM;
  `vm.panic_on_oom=2` from test-instrumentation would have made OOM an
  immediate visible panic), `cores = 4`, `diskSize = 4096`.
- `system.switch.enable = true` on the node (see below; without it the test
  toplevel has no `bin/switch-to-configuration`).
- `virtualisation.writableStore = true` (explicit; in-VM eval writes .drv
  files; rw layer is tmpfs by default so it costs RAM not disk).
- `virtualisation.additionalPaths = [ nixpkgs.outPath candidate switchScript ]`
  (test node toplevel is auto-added by qemu-vm.nix; closureInfo registration
  reaches the VM nix db via the regInfo kernel param mechanism).
- `nix.settings`: `experimental-features = ["nix-command" "flakes"]`,
  `substituters = lib.mkForce []`, `flake-registry = ""`.
- intentd is exposed to root as `python312.withPackages (ps:
  [ (ps.toPythonModule intentd) ])`, invoked BY ABSOLUTE STORE PATH from the
  testScript and seeded via `additionalPaths`, NOT via
  `environment.systemPackages`. **Wrinkle:** putting a python env in
  systemPackages makes NixOS system-path pull python's `doc` output (via
  `meta.outputsToInstall`), and `python3.12-doc` fails to build from source at
  this nixpkgs rev (sphinx enumerator crash under docutils 0.22.4 /
  python3.14). First VM build attempt died on exactly that; absolute-path
  invocation sidesteps the entire problem. Tasks 5-6: keep doing this (or set
  `documentation.*` off and strip outputs) when intentd needs to be on the
  node.

## agetty vhangup vs switch scripts (hit on the first real VM run; CRITICAL for Tasks 5-6)

First real VM run confirmed the predicted backdoor stop
(`stopping the following units: backdoor.service, network-addresses-eth1
.service, systemd-sysctl.service`), and then hung waiting for the console
markers. Cause: the candidate config (plain qemu-vm, no test
instrumentation) ENABLES `serial-getty@ttyS0`; when agetty starts during the
switch it `vhangup()`s the tty, revoking every pre-existing fd on
`/dev/ttyS0`. Consequences observed:

- A switch script doing `exec >/dev/ttyS0` loses its output channel mid-run
  (writes return EIO; echoes silently vanish).
- Much worse: switch-to-configuration-ng is Rust; `println!` to a revoked
  stdout PANICS, so the restore s-t-c invocation died before doing anything
  and the backdoor never came back; the driver then times out.

Fix that works: never hold a long-lived fd to the serial console. The switch
script writes s-t-c output to `/tmp/smoke-switch.log` and emits each marker
with a fresh `echo "..." >/dev/ttyS0` (a new open() after vhangup works
fine). The testScript uses the console only as a synchronization barrier
(`wait_for_console_text("SMOKE-RESTORE-RC=")`) and reads the log FILE as the
authoritative record after resurrecting the backdoor.

Implication for the M4 executor on real hosts: `switch_to()` must not
inherit a tty fd that the target configuration's getty churn can revoke;
capture s-t-c stdout/stderr into a pipe or file (subprocess.run with
capture_output already does this; do NOT pass a pty).

## More VM-run findings (attempt with per-write markers)

- **Coherence + offline build: CONFIRMED IN-VM.** The offline
  `nix build path:/var/lib/intentd/ws#...toplevel` with the rev+lastModified
  path override finished in **20.4 s** inside the VM (4 cores, 4096 MiB) and
  printed exactly the pre-seeded candidate; the equality assert passed and
  `nix-env --set` ran. In-VM flake evaluation is FEASIBLE; locked decision
  8's fallback is NOT needed.
- **`switch-to-configuration test` on the candidate exits 0** even though it
  stops the backdoor and swaps gettys (`SMOKE-SWITCH-RC=0`), and firefox is
  on the new system PATH (`SMOKE-FIREFOX=OK`).
- **Test node toplevels have NO `bin/switch-to-configuration`:**
  nixos-test-base.nix sets `system.switch.enable = mkDefault false` (Hydra
  optimization) unless specialisations/bootloader are in play. The restore
  switch failed with rc 127 until the node config set
  `system.switch.enable = true`. Tasks 5-6 MUST set this on scenario nodes.
- **Profile readlink:** `nix-env --profile /nix/var/nix/profiles/system
  --set <closure>` produces `system -> system-1-link -> <closure>`; use
  `readlink -f` when asserting the profile target.
- Console output during getty churn gets garbled (junk like `78` prefixed to
  marker lines); parse authoritative values from a file on the guest, use the
  console only for wake-up synchronization.

## systemd-run PATH + backdoor resync protocol (last two failures before green)

- **Transient `systemd-run` units on the test VM get NO usable PATH** (they
  do not inherit the calling shell's environment). Symptom: bash builtins
  (`echo`) and absolute paths (the s-t-c invocations) work, while bare
  `readlink`/`sleep` fail SILENTLY under `set +e`; the profile marker came
  out empty two runs in a row before this clicked. Fix: `PATH=${coreutils}/bin`
  at the top of the switch script (or absolute paths everywhere).
- **Backdoor resurrection needs a socket drain, not dummy commands.** The
  driver's shell protocol base64-encodes command output
  (`bash -c ... | (base64 -w 0; echo)` and reads one newline-terminated
  block). After the restore switch starts a fresh backdoor, its banner line
  `Spawning backdoor root shell...` sits in the socket; the next
  `machine.execute()` feeds it to `base64.b64decode` and the DRIVER ITSELF
  crashes (binascii "Incorrect padding"), not just the command. Correct
  resync: `select.select` + `recv` loop on `machine.shell` until quiet, then
  resume normal `succeed()` calls. After the drain, the driver works
  normally against the resurrected backdoor.

## Test-driver wrinkles (hit while iterating)

- The driver TYPE-CHECKS the testScript at build time ("testScriptWithTypes",
  ty-based). Consequences: (a) a testScript variable named `log` collides with
  the driver's global `log: AbstractLogger` and fails the build; (b)
  `re.search(...).group(...)` without a None-guard fails; write
  `m = re.search(...); assert m` first. These failures happen while building
  the DRIVER derivation, before any VM boots, so they are cheap to hit.

## Timings and cost (green run)

- In-VM offline `nix build` of the workspace toplevel (eval + no-op
  realization from the pre-seeded closure): 17.7 s (repeat runs 18-21 s).
- testScript wall time: 56 s (boot to shutdown; includes two
  switch-to-configuration runs and the backdoor resurrection).
- Whole-check `--rebuild` of the test derivation on this machine (20 cores,
  warm store): **61 s wall clock** (measured with time -v; the VM runs under
  the daemon, so client RSS is meaningless; the VM itself is capped by
  `memorySize = 4096` and never OOMed).
- One-time cost the first `nix build .#checks...` pays: building the
  candidate toplevel closure (nixos + firefox, a few GB of downloads) plus
  qemu/test-driver deps.

## Determinism re-run

A second full run of the test derivation (`nix build --rebuild`) passed
identically (same marker values, both s-t-c rcs 0) in 61 s wall clock; the
run is dominated by VM boot + ~20 s in-VM eval.

## Checklist (all done)

- [x] packages.intentd green, catalog + flake_template bundled and readable.
- [x] Host-side drv coherence proof (drvPaths identical with
      rev+lastModified path override).
- [x] `nix build .#checks.x86_64-linux.vm-smoke` GREEN.
- [x] Observed s-t-c exit codes recorded (0/0).
- [x] In-VM eval feasibility verdict: FEASIBLE; no fallback needed.
- [x] Python gate re-run after all changes.

## Cheat sheet for Tasks 5-6 authors

1. Scenario candidates should include test instrumentation via the TEST
   profile base.nix (chaos mechanism), which keeps the backdoor alive across
   switches and avoids the whole resurrect dance the smoke test needed; the
   smoke test deliberately exercises the SHIPPED base.nix instead.
2. Set `system.switch.enable = true` on scenario nodes.
3. Seed: nixpkgs source path, every candidate toplevel built in the outer
   eval, and any script the guest must run, all via
   `virtualisation.additionalPaths`.
4. Build offline in-VM with `--no-write-lock-file --override-input nixpkgs
   'path:<src>?rev=<rev>&lastModified=<seconds>'` and hard-assert the output
   path equals the pre-seeded toplevel.
5. Run any switch that might kill the backdoor via `systemd-run`, log to a
   file, communicate through fresh-open `/dev/ttyS0` writes, pin PATH inside
   the unit, and drain `machine.shell` after resurrecting the backdoor.
6. Never pass a writeText derivation directly as a NixOS module; pass the
   coerced string path (`"${drv}"` inside nix).
7. Do not put python envs in `environment.systemPackages` of test nodes
   (python doc output build breakage); invoke by store path.

## M4 Task 6 findings: vm-scenarios (GREEN)

`nix build .#checks.x86_64-linux.vm-scenarios` is GREEN: all three M2
acceptance scenarios pass against the REAL orchestrator (real
TransactionStore, workspace, render, policy, executor, health) inside one VM.

- **Files:** `nix/vm-scenarios.nix` (check), `nix/scenario_driver.py` (in-VM
  driver), `nix/scenario-base.nix` + `nix/scenario-generated-{firefox,
  firefox-vlc}.nix` (candidate modules; the generated variants are asserted
  byte-identical to `render()` output on the host before use).
- **Driver protocol:** one JSON line per subcommand on stdout
  (`init`, `repair-manifest`, `install <app>`, `revert`, `status`); the
  testScript asserts on parsed JSON (txn id/status/closure_path/apps/detail),
  never on console scraping. Hermetic build composed in the driver via
  `executor.build_toplevel_argv(ws, extra_args=[--no-write-lock-file,
  --override-input, nixpkgs, <pin>])`; `extra_args` is the ONLY src/intentd
  change (additive parameter + unit test). The build's lock pin is the
  override-input string itself, per the Task 5 amendment.

### New wrinkles (beyond the Task 1 cheat sheet)

1. **`/etc/nix/nix.conf` travels with the switched system.** The first VM run
   died on scenario 2: after scenario 1 switched to the firefox candidate,
   the next in-VM `nix build` failed with "experimental Nix feature 'flakes'
   is disabled". The NODE's `nix.settings` only exist in the node's toplevel;
   once a candidate is active its own `/etc/nix/nix.conf` governs. Fix:
   every scenario candidate's base.nix carries
   `nix.settings = { experimental-features = ["nix-command" "flakes"];
   substituters = lib.mkForce []; flake-registry = ""; }`.
2. **Candidates keep `system.switch.enable = true` by default.** The
   `mkDefault false` Hydra optimization lives in nixos-test-base.nix, which
   only test NODES import. Scenario candidates import
   `testing/test-instrumentation.nix` directly, so their
   `bin/switch-to-configuration` exists without extra config (needed by the
   abort path, which runs the blessed closure's own s-t-c).
3. **No resurrect dance needed, confirmed.** With test instrumentation in
   every candidate, the backdoor survived all four switches;
   `machine.succeed()` ran the driver directly throughout (the whole
   systemd-run/ttyS0/drain machinery from the smoke test is unnecessary
   here, exactly as the cheat sheet predicted).
4. **Chaos mechanism (validated):** `intentd-chaos.service`, oneshot, no
   RemainAfterExit, `wantedBy multi-user.target`, fails iff
   `/etc/intentd-chaos` exists. s-t-c unconditionally issues a start job for
   active targets (collect_unit_changes in switch-to-configuration-ng), and
   systemd resolves it against the target's Wants=, starting any
   inactive-or-failed wanted unit, so the flag is re-evaluated on EVERY
   switch with no extra wiring. Observed: chaos failed during the
   vlc-candidate switch (health caught the fresh failure -> txn ABORTED,
   workspace restored to the blessed render, blessed closure reactivated)
   and failed AGAIN during the restore switch (flag still present; the
   abort path tolerates rc 4 by design). In scenario 3 the still-failed
   unit sat in the health BASELINE, recovered during the clean vlc switch,
   and correctly did not count as a regression -> blessed. The
   baseline-relative health rule got exercised for real, both directions.
5. **Workspace base swap (the Task 6 wrinkle), clean solution confirmed:**
   `driver init` (init_workspace copies the SHIPPED template) ->
   `install -m 0644 <scenario base.nix store path> ws/base.nix` ->
   `driver repair-manifest` (workspace.repair_manifest, public from Task 5),
   all BEFORE any transaction. The scenario base becomes the authoritative
   manifest entry; write_generated's tamper check passes for the whole run;
   generated.nix is only ever written by the product.
6. **testScript indentation trap (new flavor):** nix `''` strings strip the
   MINIMUM indentation across lines; a partial re-indent (first line at 6
   spaces, rest at 8) ships the 2-space excess into the python source and
   the driver typecheck fails with "Unexpected indentation". Keep the whole
   testScript body at one uniform indent. Cheap failure (driver derivation,
   pre-VM), as designed.
7. **Host-side drv pre-check reused, twice.** Outer candidate drvPath vs
   ws-flake drvPath (init + base swap + repair on a scratch workspace, same
   override-input): byte-identical for both candidates, before the first VM
   run and again after the nix.conf fix. Both candidate switches in-VM then
   reproduced the pre-seeded toplevels exactly (asserted via
   closure_path == candidate and profile readlink -f).

### Timings (green run)

- `install firefox` (first in-VM eval, build, switch, health, bless): 55.7 s.
- `install vlc` chaos-abort round trip (build, switch, health catch, abort,
  restore-switch): 34.4 s. Clean `install vlc`: 26.9 s. `revert`: 26.2 s.
- testScript total 172 s; node: 4 cores, 6144 MiB memory, 8192 MiB disk.

## M6 Task 4 findings: vm-cli (GREEN)

`nix build .#checks.x86_64-linux.vm-cli` is GREEN, on the FIRST VM run, and
a `--rebuild` rerun passed identically. Unlike vm-scenarios (bespoke in-VM
driver), this check drives the SHIPPED user surface: the `intent` entry
point script through `wiring.production_deps` + `apply_with_reconcile`,
exactly as a user would run it. Flow: stubbed `intent do "install firefox"`
-> blessed + firefox on PATH + `--json history/status` clean; hand-edited
generated.nix -> `intent status` rc 6 with the workspace warning;
`repair_manifest` one-liner -> `intent revert` -> blessed back to empty ->
status clean.

- **Files:** `nix/vm-cli.nix` (check), `nix/scenario-generated-empty.nix`
  (byte-identical to `render(DesiredState(), catalog)`; the revert target).
  Reuses `nix/scenario-base.nix` + `scenario-generated-firefox.nix`, so
  candidateFirefox is the SAME derivation as vm-scenarios' (shared build).
- **Resolver stub seam:** `INTENTD_RESOLVER_STUB=<file>`
  (`cli.resolve_fn_from_env`, TDD'd in test_cli.py) replaces ONLY the
  `run_claude` subprocess with the file's canned reply JSON; prompt build,
  reply schema validation, and catalog-checked `resolve_invocation` stay on
  the production path. The stub file contains the MODEL REPLY shape
  (action/capability/params/reason), not a pre-baked Resolution.

### Planted flake.lock, not --override-input (the Task 4 wrinkle)

`production_deps` builds with a plain `nix build path:<ws>#...` -- no
extra-args seam exists on the production path, by design. Instead of adding
one, the testScript plants `ws/flake.lock` (generated in vm-cli.nix from the
outer flake's own nixpkgs input: rev, narHash, lastModified, github type,
original ref nixos-unstable) before the first `intent do`:

1. **Offline resolution works from the seeded store.** A fully locked github
   input needs no network: nix computes the fixed-output path from the
   lock's narHash and finds it valid (fetchToStore's "substituted/cached
   input" shortcut) because nixpkgs.outPath is in additionalPaths. No
   registry, no ref resolution, no --override-input.
2. **Coherence holds because rev+lastModified live in the lock**, so
   nixpkgs' versionSuffix is derived identically to the outer eval. Host
   pre-check (cheat-sheet technique, reused again): scratch ws (init + base
   swap + repair + planted lock + generated.nix), then
   `nix eval path:<ws>#...toplevel.drvPath` with NO override -- byte-identical
   drvPaths for both candidates (`435xl2kv...` firefox, `p6z7bl6w...`
   empty) before any VM was booted.
3. **No tamper interaction:** flake.lock is not a manifest-tracked file
   (flake.nix/base.nix/generated.nix only), so planting it trips nothing.
4. **wiring's TOCTOU re-verify runs for real:** `_host_build` finds the
   planted lock after `nix build` (which leaves it untouched -- the input
   spec matches the lock's original), pins its sha256, and
   `_verified_activate` re-checks it before switch-to-configuration.

### Other wrinkles

- **`${pythonEnv}/bin/intent` exists:** `python312.withPackages` is a
  buildEnv, and it links the `bin/` of a `toPythonModule`'d
  buildPythonApplication too, so the wrapped console script rides into the
  env. Invoked by absolute store path per the cheat sheet; `textual` (new
  M6 dep) imports fine inside the env.
- **Exit-code-6 assertions need `machine.execute`,** not succeed. Its
  output is stdout only (the CLI's "resolving..." stderr goes to the
  console log); JSON parsing takes the LAST stdout line, same as
  vm-scenarios.
- `intent status` never runs startup_reconcile (deps factory only), so it
  reports the dirty workspace with rc 6 instead of dying on TamperError;
  the repair before `intent revert` is what lets reconcile pass afterwards.
- Setup sequence (before any transaction): init_workspace one-liner ->
  `install` scenario base.nix -> repair_manifest one-liner -> `install`
  the planted flake.lock. Same shape as vm-scenarios plus the lock step.

### Timings (green runs, node 4 cores / 6144 MiB / 8192 MiB disk)

- `intent do 'install firefox'` (resolve-stub, reconcile, render, first
  in-VM eval+build, lock re-verify, s-t-c test, health, bless): 17.1 s --
  the locked-input store lookup makes the first eval much faster than the
  smoke test's ~20 s override-input eval.
- `intent revert` (same pipeline, warm eval cache): 7.2-7.7 s.
- `history`/`status`: ~0.7 s each. testScript total: 42.8 s first run,
  41.5 s `--rebuild` rerun (identical assertions).

## M6 Task 5 findings: vm-baseline-pilot (GREEN)

`nix build .#checks.x86_64-linux.vm-baseline-pilot` is GREEN on the FIRST
VM run (91.6 s testScript). Same harness pattern as vm-cli (Task 4):
`intent` CLI through `wiring.production_deps` + `apply_with_reconcile`,
resolver stubbed, build hermeticized via a planted `flake.lock`. New
wrinkles specific to running the six comparative-baseline-protocol tasks as
one chained session:

1. **Generated-module content that includes an unfree app cannot be a
   checked-in `nix/scenario-generated-*.nix` file the way the free-only
   ones are.** The repo's format-on-save hook runs nixfmt on every
   Edit/Write to a `.nix` file (not on Bash-written files, but Write/Edit
   are the only realistic authoring path). `render()`'s literal output for
   a state with an unfree app --
   `nixpkgs.config.allowUnfreePredicate = pkg:\n    builtins.elem ...` on
   one logical statement -- is valid Nix that nixfmt legitimately
   reformats (`pkg:` alone gets pushed onto its own line), which breaks the
   byte-identity these files exist for (the testScript's `diff -u`
   assertions against the CLI's actual `generated.nix`, and matching the
   in-VM eval to the outer-built candidate). Fix: for the four
   obsidian-containing generated variants
   (firefox+obsidian, obsidian, obsidian+vlc, mpv+obsidian),
   write them INLINE in `nix/vm-baseline-pilot.nix` as
   `pkgs.writeText "generated.nix" ''...''` string literals instead of
   separate committed files. nixfmt reformats Nix *syntax*, never the
   contents of a string literal, so embedding is immune to this class of
   drift regardless of which tool touches the outer file. Verified against
   `intentd.render.render()` directly (built each `writeText` derivation
   host-side via a temporarily-exported `inherit`, diffed byte-for-byte
   against Python's own output for the same `DesiredState`, then removed
   the temporary export) before trusting the embedded copies.
2. **Chaos-recovery task composes cleanly with the rest of the CLI
   pipeline, first try.** Task 6 (recover from a mid-activation failure)
   reuses the M4 chaos mechanism (`intentd-chaos.service` in
   `scenario-base.nix`, already shared with vm-cli's base) with NO new
   wiring: `touch /etc/intentd-chaos`, `intent do "install mpv"` builds
   fine (chaos only fires on activation) and returns rc 5 `aborted` with
   `detail` containing `intentd-chaos.service` (health-check-detected
   failure, not an ExecError -- `classify_switch_rc` accepts s-t-c's rc 4
   as a normal return); system profile is verified back on the pre-failure
   candidate with no shell step; `rm /etc/intentd-chaos`; the SAME `intent
   do "install mpv"` retried succeeds (rc 0, blessed). No new mechanism
   needed beyond what M4/M5 already proved -- confirms the shipped CLI's
   `apply_with_reconcile` (`startup_reconcile` before every apply) composes
   with the abort/restore path exactly like the bespoke driver did in
   vm-scenarios.
3. **`--json` mode has no path to complete a NEEDS_ACK task
   unattended.** `cmd_do` in `--json` mode returns the needs-ack payload
   and rc 4 with no prompt when the policy verdict is NEEDS_ACK (by design:
   a script must not block on a tty that isn't there), and there is no
   `--json`-mode flag to pre-supply an ack. The only way to actually finish
   an unfree-app install through the shipped CLI without a human at the
   keyboard is text mode: `echo y | intent do "..."` (the CLI's `input()`
   confirm reads a piped line fine, no tty required). Task 2 (install an
   unfree app) is the only vm-baseline-pilot task that runs in text mode
   for this reason; its completion is asserted by substring match on the
   final "blessed" / "+obsidian" line rather than by JSON parse. Documented
   in `eval/baseline/PROTOCOL.md` section 2 as a real, shipped CLI shape,
   not papered over.
4. **`os.environ["out"]` inside `testScript` is the standard nixpkgs
   pattern for a check to leave a result file behind** (confirmed against
   `nixos/tests/vlm-screenshot-question.nix` in the pinned nixpkgs source:
   `out = os.environ["out"]`). `nixos/lib/testing/run.nix`'s `buildCommand`
   does `mkdir -p $out` before invoking the driver with `-o $out`, and
   since `testScript` runs as the derivation's own build process (not
   inside the VM), the `out` env var nix sets for every output is already
   in its `os.environ`. Used here to write `$out/intentd_arm.json` with the
   six tasks' metrics; `eval/baseline/intentd_arm.json` is a checked-in
   copy (`cp (nix build ... --print-out-paths --no-link)/intentd_arm.json
   eval/baseline/intentd_arm.json`, documented in PROTOCOL.md section 4).

### Timings (green run, node 4 cores / 6144 MiB / 8192 MiB disk)

- Task 1 (install firefox, first in-VM eval+build): 19.8 s.
- Task 2 (install obsidian, unfree ack, text mode): 9.4 s.
- Task 3 (remove firefox): 10.5 s.
- Task 4 (install vlc by description): 9.5 s.
- Task 5 (revert): 8.1 s.
- Task 6 (chaos abort + restore + clean retry, two `intent do` calls):
  20.1 s.
- testScript total: 91.6 s (five candidate switches plus one abort/restore
  round trip, vs. vm-cli's two-candidate 42.8 s -- scales about as
  expected for three more candidates and the extra abort/retry).
