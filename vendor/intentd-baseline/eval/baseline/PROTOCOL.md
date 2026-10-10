# Comparative baseline protocol

M6 Task 5 / locked decision 6. This is the Stage 1 wedge's comparative test:
intentd must beat "a competent coding agent using nix-agent on plain NixOS"
on completion, clarification burden, terminal exposure, recovery success,
and post-failure trust (stage1_wedge_implementation_plan.md, Stage 1
section). Two arms, six tasks, same nixpkgs pin, same words.

**Where the numbers come from, plainly stated up front:**

- The **intentd arm**'s numbers come entirely from the scripted pilot:
  `nix build .#checks.x86_64-linux.vm-baseline-pilot` (`nix/vm-baseline-pilot.nix`),
  copied into `eval/baseline/intentd_arm.json` (copy step: section 4). Deterministic,
  reproducible, no human in the loop.
- The **baseline arm** has no scripted pilot. It needs a human running a
  real coding agent session against a real VM, task by task, per section 3 below.
  There is no offline stub for "a competent coding agent" the way
  `INTENTD_RESOLVER_STUB` stubs intentd's own resolver -- the whole point of
  this arm is to observe what an actual agent actually does.
- **post_failure_trust** (both arms) is a 1-5 human score. No script
  produces it, and none should: it is asking the human "would you let this
  run unsupervised again," not a property of the transcript.
- **clarification turns and terminal exposure on the baseline arm** are
  human judgment calls made by reading the agent's own transcript (section 5.3,
  section 5.4) -- an agent's tool-call log doesn't self-label "this was a
  clarifying question" or "this command was shown to the user."

## 1. The six tasks

Run in this exact order in both arms (the intentd arm's scripted pilot
chains them as one session -- each task builds on the previous task's
system state -- and the baseline arm should do the same, for a fair
comparison of a normal multi-request session, not six independent resets).

| # | Task | Utterance issued verbatim to both arms |
|---|------|------------------------------------------|
| 1 | Install a named free app | `install firefox` |
| 2 | Install an unfree app (license acceptance required) | `put obsidian on my machine` |
| 3 | Remove an app | `remove firefox` |
| 4 | Install by description (no app name given) | `i need something to watch videos, get vlc` |
| 5 | Revert the last change | `undo that` (baseline arm) / `intent revert` (intentd arm -- see section 2, task 5) |
| 6 | Recover from a mid-activation failure | `install mpv`, issued while activation is rigged to fail (section 2 task 6, section 3 task 6) |

Tasks 1-4's utterances are not invented for this document: they are copied
verbatim from `eval/resolver_suite/cases.jsonl`, the corpus M5's live eval
(`eval/resolver_suite/report.json`) proved the real intentd resolver maps to
the expected `{capability, params}` at 105/105 in-scope exact-match
accuracy. Using the SAME utterance in both arms is what makes the
comparison fair; using an utterance the resolver has already been proven
correct on (rather than a hand-picked easy case) is what makes the intentd
arm's numbers honest.

Task 5's utterance differs by arm on purpose: intentd ships `intent revert`
as a dedicated, resolver-free verb (M6 locked decision 3) -- a user who
wants to undo the last change never has to phrase it as natural language at
all, and the pilot exercises that real, shipped path rather than manufacturing
a sentence for the resolver to parse. The baseline arm has no equivalent
verb -- a coding agent only has the words the user gives it -- so it gets
the natural-language phrasing `undo that` (also drawn from
`eval/resolver_suite/cases.jsonl`, same 105/105-proof standard as tasks
1-4, though of course that suite only bears on intentd's own resolver, not
on how a coding agent will interpret the same sentence).

## 2. Intentd arm: exact scripts

The intentd arm is entirely mechanical and entirely reproduced by
`nix/vm-baseline-pilot.nix`. This section documents what the pilot actually
runs, so a human reading it can audit or manually replay any step.

Setup (once, before task 1): a NixOS VM built from this repo's own
`nixpkgs` pin (`flake.lock`: rev `e7a3ca8092b61ff85b6a45bf863ea2b2d6a661b3`),
the shipped `intent` CLI installed from `packages.x86_64-linux.intentd`,
state dir `/var/lib/intentd`, `intent --state-dir /var/lib/intentd
--activate-mode test` for every invocation (`test` rather than `switch`
because Stage 1 is VM-certified only; see `docs/host-setup.md`).

Every task below is either one or two `intent` invocations. No task
requires the user to type, read, or approve a raw shell command --
`terminal_exposure_zero_construction` is 0 for all six by construction of
the CLI (locked decision 3: `do` / `revert` / `status` / `history` /
`explain` / `apps` are the only surface). `intent_invocations` -- the count
of CLI calls needed to complete the task -- is reported alongside that 0 as
the closest intentd-arm analogue of the baseline arm's raw command count
(section 5.4); do not read the "0" as "intentd required no user action," read the
pair together.

1. **Install a named free app.**
   `intent do "install firefox"`. Resolver replies `{action: invoke,
   capability: app.install, params: {app: firefox}}` (the M5-proven reply
   for this utterance). Auto-applies (firefox is free, on the allowlist).
   1 invocation, 0 clarification turns.

2. **Install an unfree app.**
   `intent do "put obsidian on my machine"`. Resolver replies `{action:
   invoke, capability: app.install, params: {app: obsidian}}`. Policy
   returns `needs-ack` (obsidian is unfree). This is the one place the
   shipped CLI's `--json` mode cannot complete a task unattended: in `--json`
   mode `do` returns the needs-ack payload and rc 4 with **no prompt**, by
   design (a script must not be blocked on a tty that isn't there); there is
   no `--json`-mode flag to pre-supply an ack. The only way to actually
   finish this task through the shipped CLI is its other mode: **text mode**,
   where `do` prints `<reason> Proceed? [y/N]` and reads an answer from
   stdin. The pilot answers it non-interactively (`echo y | intent do
   "put obsidian on my machine"`) -- this is not a workaround invented to
   dodge a CLI gap, it is the one real, shipped path for completing this
   task without a human sitting at the keyboard, and it is documented here
   exactly as the pilot exercises it. 1 invocation, **1 clarification turn**
   (the license ack is the license-acceptance question the product
   intentionally surfaces inline, per Stage 1 acceptance criterion 3).

3. **Remove an app.**
   `intent do "remove firefox"`. Resolver replies `{action: invoke,
   capability: app.remove, params: {app: firefox}}`. Auto-applies. 1
   invocation, 0 clarification turns.

4. **Install by description.**
   `intent do "i need something to watch videos, get vlc"`. Resolver
   replies `{action: invoke, capability: app.install, params: {app: vlc}}`
   -- the utterance never names "vlc" as an app id in isolation, the
   resolver has to connect "watch videos" to the catalog entry, which is
   the point of this task. Auto-applies. 1 invocation, 0 clarification
   turns.

5. **Revert the last change.**
   `intent revert`. No utterance, no resolver call -- policy recomputes the
   prior blessed state and auto-applies back to it. 1 invocation, 0
   clarification turns, by construction (there is nothing to clarify: the
   verb takes no argument).

6. **Recover from a mid-activation failure.**
   The pilot injects a real activation failure using the M4 chaos mechanism
   already built into the VM harness (`nix/scenario-base.nix`:
   `intentd-chaos.service`, fails iff `/etc/intentd-chaos` exists;
   `switch-to-configuration` unconditionally re-checks it on every switch,
   so no extra wiring is needed to "arm" it mid-session):
   - `touch /etc/intentd-chaos` (fault injection, not something a live
     failure would need -- see the note below).
   - `intent do "install mpv"` (same resolver-proven shape as tasks 1-4).
     Build succeeds (chaos only fires on activation); activation returns rc
     4 (units failed, s-t-c itself still "succeeds" per
     `executor.classify_switch_rc`); the health check sees the freshly
     failed `intentd-chaos.service` and the orchestrator **aborts the
     transaction and auto-restores the prior blessed closure**, with no
     shell step for a user to run. Outcome: `aborted`, rc 5.
   - `rm /etc/intentd-chaos` (clears the injected fault; on real hardware
     this step is "whatever actually caused the activation failure gets
     fixed" -- a flaky mirror, a disk-space issue, a broken derivation --
     not something intentd or the user manufactures).
   - `intent do "install mpv"` again, same utterance. Succeeds this time.
   Outcome: `blessed`. 2 invocations total, 0 clarification turns (the
   system never asked a question; it failed, restored itself, and the same
   request succeeded on retry), **recovery_success: true** (auto-restore
   verified with no manual intervention beyond clearing the fault; the
   retry reached the intended end state).

   Caveat for anyone re-running this task **outside** the scripted pilot,
   by hand, on a real host: there is no product-level "inject a mid-activation
   failure" affordance (nor should there be) -- `touch /etc/intentd-chaos`
   only exists inside the VM harness's own test instrumentation
   (`nix/scenario-base.nix`, carried over from the M4 chaos mechanism). A
   manual run would need some other real fault (e.g. temporarily blocking
   the substituter, or a deliberately broken catalog entry) that fails
   activation and lets the health check catch it the same way; the pilot's
   numbers stand in for that manual run, not as a substitute for having one
   available, but because engineering an equally reliable, equally
   reproducible manual fault is strictly harder than the mechanism the VM
   harness already has proven (nix/SPIKE_FINDINGS.md, M4 Task 6 chaos
   mechanism).

## 3. Baseline arm: exact setup and scripts

This arm needs a human. What follows is precise enough to run in an
afternoon.

### 3.1 VM setup (normative harness, same nixpkgs pin, no intentd)

1. Use the checked-in `eval/baseline/vm` harness. It is the normative baseline
   VM, not an illustrative minimal flake. It pins nixpkgs to this repository's
   `flake.lock` revision,
   `github:NixOS/nixpkgs/e7a3ca8092b61ff85b6a45bf863ea2b2d6a661b3`
   (narHash `sha256-UgCQzxeWI75XM8G+hPrPh+MKzEPjG3SpAj7dtqSbksA=`). The
   comparison is invalid if the two arms resolve different nixpkgs.

2. The harness pins nix-agent to
   `317334c76aa07ade539918014b977685501f7aaa` and declares its nixpkgs input
   to follow the shared harness nixpkgs. On first boot it seeds `/etc/nixos`
   with the same agent-operable baseline module graph: `configuration.nix`,
   `agent-harness.nix`, `cursor-mcp-timeout-patch.py`, `mcp-preflight.py`, and
   `vm-node.nix` (the one-time seeding module is intentionally absent from the
   seeded copy). Do not install or substitute a different nix-agent revision.
   The VM must not ship with intentd, a product-owned flake template, a catalog,
   or task-specific configuration.

3. `wedge` must not be in `wheel`. The root password and root SSH login are
   disabled; direct `sudo`, system-profile mutation, and direct activation
   must fail. Unprivileged edits to the user-owned `/etc/nixos` are allowed.
   The only privileged coding-agent entry point is the stdio MCP wrapper,
   `/run/wrappers/bin/nix-agent-mcp` with no arguments. Give the agent no
   additional privileged tools.

4. Begin each measured run from a newly inspected and removed
   `baseline.qcow2`, as specified by RUNBOOK section 1. A prior disk preserves
   `/etc/nixos` and can restore an old privilege boundary after a switch.

5. Before booting the measured guest, the host must pass:

   ```fish
   nix build ./eval/baseline/vm#checks.x86_64-linux.privilege-boundary -L --no-link
   ```

   This runs the positive MCP switch, target, and activation check in a
   disposable test VM, so it must not be substituted with a preflight switch in
   the measured guest. The check does not import or test `fault.nix`.

6. Extract the official Cursor Agent CLI archive as `wedge`, pinned to version
   `2026.08.11-e8db854`. Before authentication or MCP configuration, download
   the official Linux x64 archive from
   `https://downloads.cursor.com/lab/2026.08.11-e8db854/linux/x64/agent-cli-package.tar.gz`
   and run `baseline-patch-cursor-mcp-timeout` exactly as specified in RUNBOOK
   section 2. The patcher must verify archive SHA-256
   `bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a`,
   official bundle SHA-256
   `f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0`,
   task-facing bundled Node SHA-256
   `e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4`,
   patched bundle SHA-256
   `7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a`,
   exactly one equal-length SDK default-timeout replacement, and a 300000 ms
   result. A second identical invocation must report `already_patched` and make
   no write. Freeze the patched client directory with `nix store add-path`; its
   output must be exactly
   `/nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854`.
   Invoke its Node and bundle only through `baseline-cursor-agent`; the runner
   requires that immutable root, hash-checks both files on every invocation,
   normalizes `PATH`, uses the pinned guest runtime, and forces
   `--disable-auto-update`. Do not invoke a mutable installer symlink or the
   bundled Node directly. The runner must report version `2026.08.11-e8db854`
   immediately before and after the single measured chat. Any version,
   artifact, target, content, replacement-count, store-path, or verification
   mismatch invalidates setup or the arm.

   This patch changes only the bundled MCP SDK request-timeout default from
   60000 ms to 300000 ms. It changes no prompt, tool, schema, model, server,
   approval, or authentication behavior. It must be applied identically whenever
   Cursor is the task-facing client in either comparative arm. Comparing a
   patched Cursor arm with an unpatched Cursor arm is invalid. The checked-in
   scripted intentd pilot has no Cursor or MCP-client transport, so this metadata
   is not applicable there rather than a different timeout.

7. After the clean boot and before the measured coding-agent chat or first
   stopwatch starts, run this exact command as `wedge`:

   ```bash
   baseline-mcp-preflight
   ```

   It must report success for sequential `locate_option` on
   `environment.systemPackages` and `eval_config` on `networking.hostName`.
   Each call has a 300-second timeout so cold guest source, evaluation, and
   cache initialization can complete. These attributes warm only task-neutral
   Nix metadata: the preflight names no requested app, edits no configuration,
   and performs no activation.

8. Before the first stopwatch starts, initialize the coding agent's MCP client
   and list its nix-agent tools, then confirm `sudo -n true` fails as `wedge`.
   The host-side boundary check, guest preflight, MCP readiness check, and sudo
   denial must all pass. If any check fails, stop and record the harness as
   invalid, with no task timings.

### 3.2 Per-task script (baseline arm)

For each of the six tasks, in order, in **one continuous agent session**
(matching the intentd arm's single-session chaining, section 1):

1. Start a stopwatch.
2. Paste the task's utterance (section 1 table) to the agent verbatim, as a user
   message. Do not add scaffolding, do not clarify ahead of time, do not
   pre-answer questions the agent hasn't asked yet -- the point is to see
   what the agent actually does with the same words the resolver got.
3. Let the agent run to completion (it declares done, or it asks a
   question, or it stalls) without steering it, exactly as a real user
   would.
4. Stop the stopwatch when the response and any synchronous MCP call it started
   finish, or when the task is abandoned. Record `wall_seconds` either way; a
   task that times out or gets abandoned is `completion: false`, not a missing
   row. Normal synchronous MCP evaluation, build, and activation waits remain
   inside the timing. Do not subtract them because the compatibility patch
   increased the client timeout.
5. Verify completion **objectively**, not by taking the agent's word for
   it: e.g. `which firefox` / `test -x` the relevant binary on the VM,
   `nixos-rebuild list-generations` for the revert task, `journalctl -u
   <unit>` for the failure task. Record completion: true/false.
6. Record wall_seconds, and immediately do the section 5.3/section 5.4 transcript review
   for this task while it's fresh.

Task 6 (recover from a mid-activation failure) uses the checked-in,
deterministic `eval/baseline/vm/fault.nix` activation-time unit failure.
Before issuing `install mpv`, copy that file into `/etc/nixos/fault.nix` and
import `./fault.nix` below `./vm-node.nix` in `/etc/nixos/flake.nix`. The fault
makes `switch-to-configuration` fail with rc 4 and leaves
`baseline-chaos.service` `failed`. Hand the agent the utterance without telling
it about the injection, then let it complete its first response without
steering.

If the agent removes the fault import itself, record `fault_variant:
"agent_cleared"`. Otherwise, only after its first attempt concludes, the
observer removes the import, re-issues `install mpv`, and records
`fault_variant: "human_cleared"`. This mirrors the intentd harness clearing its
fault and makes the clearing variant an observed recovery outcome rather than
an operator choice. Watch whether the agent notices the failure, diagnoses it,
and recovers the system to a working state (with or without completing the
original request); that observation is what recovery_success (section 5.5) is
scored on.

### 3.3 What NOT to do

- Do not restart the baseline VM between tasks (breaks the single-session
  comparison with the intentd arm, which chains all six).
  Do not manually fix things the agent gets wrong before scoring the task --
  score what actually happened.
- Any privileged system change outside the nix-agent MCP wrapper invalidates
  the run. This includes direct `sudo`, `su`, root SSH, system-profile
  mutation, and direct activation. Reaching the requested application end
  state does not override that invalidity.
- Do not substitute a different coding agent than intended for "record
   which agent + which nix-agent version" -- the model routing default for
   this kind of peer/baseline work is documented in `~/.claude/MODEL-ROUTING.md`;
  whichever agent is used, write it down in the results file (section 6), along
  with the official Cursor version/archive hash, patched bundle hash, 300000 ms
  compatibility timeout, and both patch application statuses. This makes the
  run reproducible in spirit even though the transcript itself will not be
  byte-identical on a rerun (unlike the intentd arm, which is deterministic).

## 4. Reproducing the intentd arm's numbers

```fish
nix build .#checks.x86_64-linux.vm-baseline-pilot --print-out-paths --no-link
```

prints a store path (the check's `$out`); copy its `intentd_arm.json` into
the repo:

```fish
cp (nix build .#checks.x86_64-linux.vm-baseline-pilot --print-out-paths --no-link)/intentd_arm.json eval/baseline/intentd_arm.json
```

This is the whole reproduction procedure. `vm-baseline-pilot` runs a
nixosTest VM offline (resolver stubbed per section 2, build hermeticized via a
planted `flake.lock` mirroring this flake's own nixpkgs pin -- same
technique proven in `nix/vm-cli.nix`, see `nix/SPIKE_FINDINGS.md`), writes
`$out/intentd_arm.json` from inside `testScript` (`out =
os.environ["out"]`, the standard nixpkgs pattern for a check to leave a
result file, e.g. `nixos/tests/vlm-screenshot-question.nix`), and the copy
step above is the only manual action -- rerunning the `nix build` and copy
should reproduce the file exactly (same commit, same nixpkgs pin, same
stubbed replies -> same sequence of transactions -> same JSON modulo
wall_seconds, which will vary run to run with host/VM performance).

`completion: true` for every task in a committed `intentd_arm.json` is the
expected, intentional state: the pilot's `testScript` asserts each task's
end state as it goes (profile readlink, binary presence, `generated.nix`
byte-diff against the catalog-rendered target) -- if any assertion fails,
`nix build` fails and **no file is produced at all** for that run, rather
than a false completion:true landing in the JSON. The intentd arm is a
scripted, deterministic pipeline, not a stochastic agent; "the check is
green" and "every task in the JSON completed" are the same fact stated
twice, by design.

## 5. Metric definitions

### 5.1 completion (yes/no)

Did the task's intended end state actually hold, verified objectively (not
by the agent's or the CLI's own self-report)? Intentd arm: the pilot's own
in-VM assertions (readlink on `/nix/var/nix/profiles/system`, `test -x` on
the installed binary, byte-diff of `generated.nix` against the
catalog-rendered target for the intended state). Baseline arm: the same
category of check, run by the human against the baseline VM (section 3.2 step 5).

### 5.2 wall_seconds

Wall-clock time from issuing the request to completion (or to abandonment,
for a failed task). Intentd arm: `time.time()` deltas inside
`testScript`, wrapped tightly around the `intent` invocation(s) for that
task only (setup, and harness verification calls like `status`/`diff`, are
excluded -- see the testScript comments in `nix/vm-baseline-pilot.nix` for
exactly what's inside vs. outside each window). This measures VM-automation
wall time (console round trips through the nixosTest driver), not a human
with a stopwatch on real hardware; treat it as internally consistent across
the six intentd-arm tasks, not as directly comparable in absolute magnitude
to a baseline-arm number obtained by a human's stopwatch on different
hardware. Baseline arm: a human stopwatch, section 3.2 steps 1 and 4.
The baseline timer includes all normal synchronous MCP evaluation, build, and
activation waits. The 300000 ms compatibility timeout prevents premature client
cancellation; it does not turn a synchronous tool into an early acknowledgement,
and no portion of that wait may be subtracted from `wall_seconds`.

### 5.3 clarification_turns

Number of questions the **system** asked the user before completing the
task (not counting the license-acceptance prompt as anything other than
exactly what it is -- see task 2, section 2). Intentd arm: 0 for every task except
task 2 (`= 1`), by construction of the CLI -- there is no other place in
the shipped verb set where the system can ask a mid-task question at all.
Baseline arm: **human judgment**, read the agent's transcript for the task
and count every distinct question the agent asked before taking the
requested action (a request for confirmation before running a command
counts; a purely informational status update the agent prints without
waiting for a reply does not).

### 5.4 terminal_exposure

Count of shell commands the user must see or type. Intentd arm: reported as
**two numbers**, not one -- `terminal_exposure_zero_construction` (always
`0`: the user issues one natural-language request or the dedicated
`revert` verb and never sees a raw `nix build` / `systemctl` /
`journalctl` invocation) and `intent_invocations` (the count of `intent`
CLI calls needed to complete the task -- 1 for every task except task 6's
recovery, which needs 2: the failing attempt and the successful retry).
Report both; `0` alone overstates the comparison and `intent_invocations`
alone understates it. Baseline arm: **human judgment**, count every
distinct shell/tool-call command the agent ran or asked the user to
run/approve for that task, by reading the coding-agent transcript and
tool-call log, not its prose summary. Reconcile those records with
`/var/log/nix-agent-baseline/usage.jsonl`: that root-owned JSONL records
only nix-agent MCP tool events, so it cross-checks privileged operations
and potential bypasses but cannot enumerate arbitrary shell commands. Note
line-count boundaries per task, or copy/slice lines for review; never clear
or modify the audit log. Its initial successful `locate_option` and
`eval_config` events come from the required guest preflight and are outside
all task boundaries. Start task 1's audit slice after those two events.

### 5.5 recovery_success (yes/no/not applicable)

Only meaningfully scored on task 6. `null`/N/A for tasks 1-5 (nothing to
recover from). Definition: after the injected failure, did the system (a)
return to a working, non-broken state without silent data loss, without
manual recovery steps beyond clearing the injected fault, and (b) reach
the originally intended end state on retry? Intentd arm: `true` by
construction of the orchestrator's abort path (section 2 task 6) -- both
sub-conditions are asserted directly in `testScript`. Baseline arm: human
judgment reading the transcript plus the objective VM state -- did the
agent notice the failure at all, did it leave the system runnable, did it
either fix the original request or clearly report that it couldn't.

### 5.6 post_failure_trust (1-5, human-scored, both arms)

Asked once per arm, after task 6, of the human running the protocol:
"Having watched this arm handle (or fail to handle) the injected failure,
how much would you trust it to run again unsupervised?" 1 = would not run
it again unsupervised; 5 = fully trust it. This is explicitly subjective
and explicitly not automatable -- no field for it exists in
`intentd_arm.json` beyond a `null` placeholder plus a pointer back to this
section.

## 6. Results

`eval/baseline/intentd_arm.json` (section 4) is the intentd arm's committed
result. There is no `eval/baseline/baseline_arm.json` yet -- that file, and
the two arms' `post_failure_trust` scores, are produced by a human running
section 3 and recording the six rows plus both trust scores; this document is
what they need to do it, nothing else is required to reproduce the intentd
side of the comparison.
