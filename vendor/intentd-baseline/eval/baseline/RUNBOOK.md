# Baseline arm runbook

Operational companion to `PROTOCOL.md`. The protocol defines *what* to measure
and why; this file is *how to actually run it*, given the VM harness in
`vm/`. Everything here is the part of section 3 that could be mechanized;
what is left for you is the part the protocol says is irreducibly human
(section 3, opening line: "This arm needs a human").

Budget roughly an afternoon. Nothing in this runbook touches your host
system's configuration: the VM is booted from a build product and all
activation happens inside it.

## 0. Why you and not an agent

Three of the five metrics are human measurements by construction, and one is a
conflict of interest:

- `wall_seconds`: a stopwatch (PROTOCOL section 5.2). The intentd arm's numbers
  come from `time.time()` inside a nixosTest driver, which is why section 5.2
  warns they are internally consistent but not directly comparable in absolute
  magnitude to yours. Record yours anyway; the *shape* across the six tasks is
  the signal.
- `clarification_turns` and `terminal_exposure`: read the agent's transcript and
  count (PROTOCOL sections 5.3, 5.4). No tool-call log self-labels a question as
  clarifying.
- `post_failure_trust`: a 1-5 subjective score for both arms (PROTOCOL section
  5.6), asked after task 6.

And the conflict: the thing under test is "a competent coding agent." An agent
cannot both be the subject and score its own transcript for how many questions
it asked and how much terminal it exposed. You are the observer.

## 1. Start from a clean disk, build, and boot the VM

For a new measured run, inspect and remove the exact persistent disk before
building or booting. An existing `baseline.qcow2` preserves `/etc/nixos`; after
a switch it can restore an old, invalid privilege boundary even when the current
build product is correct.

```fish
cd ~/projects/intentd
if test -e baseline.qcow2
  ls -lh -- baseline.qcow2
  rm -- baseline.qcow2
end
```

The conditional tolerates an absent disk, inspects the only target before
removal, and never removes any other path. Do this once before the six-task
session. Do not remove or restart the disk between tasks.

Before booting the measured guest, run the automated privilege-boundary check:

```fish
nix build ./eval/baseline/vm#checks.x86_64-linux.privilege-boundary -L --no-link
```

It must pass. This check uses a disposable test VM to prove the positive MCP
switch, target, and activation path without mutating the measured guest. It
does not import or test `fault.nix`. If this host-side check fails, record the
harness as invalid and record no task timings.

```fish
nix build ./eval/baseline/vm --print-out-paths --no-link
```

That prints a store path. Boot it:

```fish
set vm (nix build ./eval/baseline/vm --print-out-paths --no-link)
$vm/bin/run-baseline-vm
```

The VM boots headless (`virtualisation.graphics = false`) with a console on
your terminal, and forwards guest port 22 to host port 2222. Log in on the
console as `wedge` / `wedge`, or from another terminal:

```fish
ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null wedge@localhost
```

Password auth, no key: the VM ships no `authorizedKeys` because baking a
developer's public key into a committed file would make the harness personal to
one machine. `wedge` is not in `wheel`, direct `sudo` fails, and root login is
disabled. The only route for privileged system changes is
`/run/wrappers/bin/nix-agent-mcp`.

The disk image is created in your current working directory as
`baseline.qcow2` and **persists between boots**. That is deliberate: PROTOCOL
section 3.3 forbids restarting between tasks, and a persistent disk means an
accidental host-side interruption does not silently reset the session.

### What is already set up for you

- Same nixpkgs pin as the intentd arm, `e7a3ca8092b61ff85b6a45bf863ea2b2d6a661b3`,
  written literally into `vm/flake.nix` and `vm/seed-flake.nix` and verified
  identical to the repo root's `flake.lock` (PROTOCOL section 3.1 step 1: the
  comparison is invalid if the arms resolve different nixpkgs).
- `/etc/nixos` seeded on first boot with a writable flake owned by `wedge`
  (`flake.nix`, `flake.lock`, `configuration.nix`, `agent-harness.nix`,
  `cursor-mcp-timeout-patch.py`, `mcp-preflight.py`,
  `nix-agent-launcher.c`, `vm-node.nix`), because `nixos-rebuild build-vm`
  does not populate it and nix-agent resolves `/etc/nixos` by default.
- nix-agent is preinstalled at
  `317334c76aa07ade539918014b977685501f7aaa`; it follows this VM's shared
  nixpkgs input. Do not install another nix-agent revision.
- `wedge` is not in `wheel`; direct `sudo`, root login, system-profile
  mutation, and direct activation are unavailable. The setuid
  `/run/wrappers/bin/nix-agent-mcp` wrapper is the sole privileged entry point.
  It writes nix-agent MCP tool events to
  `/var/log/nix-agent-baseline/usage.jsonl` for audit.
- None of the four apps the tasks ask for is preinstalled, and none is *named*
  anywhere in the seeded config either: the agent reads `configuration.nix`
  before editing it, and a comment listing the apps the session is about to
  request would prime it in a way the intentd arm's resolver is not primed.
- The pristine booted system is registered as **system generation 1** before
  you start. A VM booted straight from the store has an empty system profile,
  so without this the agent's own first `switch` would be generation 1, leaving
  task 5 nothing underneath to roll back to and making
  `nixos-rebuild list-generations` show only the agent's changes.
- No intentd, no product-owned flake template, no catalog (PROTOCOL section 3.1
  step 1).

### Harness checks from fixture validation

The automated privilege-boundary test was verified on 2026-08-22. It
establishes the intended boundary, but does not replace the per-run operational
preflight in section 2:

- `/etc/nixos` is seeded, writable by `wedge`, and its `flake.lock` pins
  `e7a3ca8092b61ff85b6a45bf863ea2b2d6a661b3`.
- In its disposable test VM, the pinned MCP wrapper completes a privileged
  switch against its target and activation path. The expected no-bootloader
  warning remains harmless (`vm/configuration.nix`).
- The guest MCP preflight completes both task-neutral calls without changing
  `/etc/nixos`, the system generation, or the current system closure.
- Direct `sudo -n true` fails for `wedge`; root login is disabled; system
  profile mutation and direct activation fail. These denials are part of the
  comparison boundary, not harness defects.

This automated boundary test does not import `fault.nix` or test task 6. The
separate manual task-6 procedure below has previously shown that an imported
fault returns **rc 4** and leaves `baseline-chaos.service` `failed`, the same
shape `executor.classify_switch_rc` classifies on the intentd side.

If a rebuild ever hangs with no output and no download, check IPv6 first.
qemu's slirp stack completes an IPv6 handshake to cache.nixos.org and then
moves no data, so `nix` sits in `poll()` indefinitely while `curl` still
succeeds via happy-eyeballs fallback: the VM looks online and every nix fetch
stalls. `networking.enableIPv6 = false` in `vm/configuration.nix` is what
prevents it, and it is seeded so the agent's own rebuilds inherit it. Left
unfixed this is the worst possible harness bug for this protocol, because the
stall lands in the agent's `wall_seconds` and can read as an abandoned task.

## 2. Set up the coding agent and MCP server

nix-agent has no remote mode: its tools shell out to a **local**
`sudo nixos-rebuild` (`src/nix_agent/target.py` resolves `$NIX_AGENT_FLAKE`
then `/etc/nixos`; there is no `--target-host` path). So the agent session runs
*inside* the VM, not on your host pointed at it. Pointing a host-side nix-agent
at the VM's flake would switch **your laptop**, not the guest.

Inside the clean guest, install Cursor Agent CLI unprivileged as `wedge` from
the pinned official archive below. Do not use the mutable installer or its
auto-updating launcher. This protocol pins the official CLI to
`2026.08.11-e8db854`; an installer that resolves any other version is a setup
failure. The reviewed Linux x64 archive is:

```text
https://downloads.cursor.com/lab/2026.08.11-e8db854/linux/x64/agent-cli-package.tar.gz
SHA-256 bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a
```

Before authentication or MCP configuration, download that exact archive to a
credential-free temporary path and apply the transport-compatibility patch:

```bash
cursor_archive=/tmp/cursor-agent-cli-2026.08.11-e8db854.tar.gz
cursor_stage=/home/wedge/.local/share/intentd-baseline/cursor-agent/2026.08.11-e8db854
curl --fail --location --output "$cursor_archive" \
  https://downloads.cursor.com/lab/2026.08.11-e8db854/linux/x64/agent-cli-package.tar.gz
printf '%s  %s\n' \
  bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a \
  "$cursor_archive" \
  | sha256sum --check --strict
mkdir -p "$cursor_stage"
tar --extract --gzip --file "$cursor_archive" --directory "$cursor_stage" \
  --strip-components 1
baseline-patch-cursor-mcp-timeout \
  --archive "$cursor_archive" \
  --node "$cursor_stage/node" \
  --bundle "$cursor_stage/index.js" \
  | tee /tmp/cursor-mcp-timeout-patch.json
baseline-patch-cursor-mcp-timeout \
  --archive "$cursor_archive" \
  --node "$cursor_stage/node" \
  --bundle "$cursor_stage/index.js" \
  | tee /tmp/cursor-mcp-timeout-idempotence.json
cursor_root=$(nix store add-path \
  --name cursor-agent-2026.08.11-e8db854 "$cursor_stage")
test "$cursor_root" = \
  /nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854
cursor_node="$cursor_root/node"
cursor_bundle="$cursor_root/index.js"
```

Verify the first patch invocation and its no-write idempotence check exactly:

```bash
jq -e '
  .success == true and
  .status == "patched" and
  .cursor_cli_version == "2026.08.11-e8db854" and
  .official_archive_sha256 == "bfff4bf6f4e9dd30c1d0ef0a70b6077b074015dd2948e4c50685d53afdcfce5a" and
  .official_bundle_sha256 == "f6fd4e6bf3d6ecbf66cc2dcabcf708b8a7c37b400d10c82a58658b5e331c36d0" and
  .task_facing_node_sha256 == "e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4" and
  .patched_bundle_sha256 == "7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a" and
  .mcp_timeout_ms == 300000 and
  .replacement_count == 1
' /tmp/cursor-mcp-timeout-patch.json
jq -e '
  .success == true and
  .status == "already_patched" and
  .patched_bundle_sha256 == "7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a" and
  .mcp_timeout_ms == 300000 and
  .replacement_count == 1
' /tmp/cursor-mcp-timeout-idempotence.json
```

Keep both JSON objects with the run metadata. On this minimal NixOS guest, use
the harness runner, which verifies the absolute Node and patched bundle hashes
on every invocation, supplies the pinned guest runtime libraries, and forces
`--disable-auto-update`:

```bash
baseline-cursor-agent "$cursor_node" "$cursor_bundle" --version \
  | tee /tmp/cursor-version-pre-chat.txt
```

The reported version must be exactly `2026.08.11-e8db854`. Use that same runner
with the same absolute Node and bundle for authentication, MCP setup, and the
one measured chat. Do not invoke `agent`, `cursor-agent`, the bundled Node
directly, a symlink, or another bundle.
Immediately before the measured chat, run the version command above. Immediately
after the measured chat, run it again and save
`/tmp/cursor-version-post-chat.txt`. Both outputs must be exactly
`2026.08.11-e8db854`. Keep the two patcher JSON objects and both version outputs
with the run metadata. Any mismatch invalidates setup or the arm.

The patcher verifies the official archive, task-facing bundled Node, and
`index.js`; requires Node and bundle to be regular siblings in the pinned
version directory; accepts only the pristine official bundle or the one exact
derived patched bundle; and replaces one equal-length contextual byte pattern
from the SDK default of 60000 ms to 300000 ms. `nix store add-path` then freezes
the complete verified client directory at the exact content-addressed store path
required by the runner. It changes no prompt, tool, schema, model, or MCP server
behavior and never reads or writes authentication state. Any unexpected
version, archive, member, Node, installed content, replacement count, or output
hash is a setup failure, with no timing.

This compatibility treatment is an arm invariant. If Cursor is used as the
task-facing client in either comparative arm, apply this exact version and patch
in both arms; a patched Cursor arm cannot be compared with an unpatched Cursor
arm. The checked-in scripted intentd pilot does not launch Cursor, so the field
is not applicable there rather than a different transport timeout.

Only after patch verification, authenticate as `wedge`, record the CLI version,
model, authentication mode, and patch metadata in the results, and verify that
the CLI runs unprivileged before configuring its MCP server. The harness
intentionally does not bake in this external CLI or any credentials.

Then register the already installed, pinned server with that CLI. Its MCP
configuration is:

```json
{
  "mcpServers": {
    "nix-agent": {
      "command": "/run/wrappers/bin/nix-agent-mcp",
      "args": []
    }
  }
}
```

Do not use `nix profile install` or otherwise install a second nix-agent
revision. The harness provides the exact pinned revision independently of the
system configuration the agent will change.

After the clean boot and before starting the measured coding-agent chat or any
task stopwatch, run this exact command as `wedge`:

```bash
baseline-mcp-preflight
```

It makes a cold `locate_option` call for `environment.systemPackages`, followed
by an `eval_config` call for `networking.hostName`, with a 300-second timeout per
call. This validates guest source resolution, evaluation, and cache
initialization, then warms only task-neutral Nix metadata. It does not name a
requested app, edit the configuration, or activate a system generation. A
successful run prints one JSON object with `success: true` and two tool entries
whose `status` is `"ok"`.

Also verify that the coding agent's MCP client initializes and lists the
nix-agent tools, then run `sudo -n true` as `wedge` and verify that it fails.
The host-side boundary test in section 1, `baseline-mcp-preflight`, and both
in-guest client/privilege checks must pass. If any check fails, stop: record the
harness as invalid and record no task timings. Record the tested agent and
pinned nix-agent revision in the results file (PROTOCOL section 3.3): the
baseline arm is not deterministic the way the intentd arm is, and the run is
only reproducible in spirit.

Give the agent no other privileged tool. Editing the user-owned `/etc/nixos`
is permitted, but every privileged system change must pass through the MCP
wrapper. Any direct `sudo`, `su`, root SSH, system-profile mutation, or direct
activation invalidates the comparison, even if the requested app state is
eventually reached.

## 3. Run the six tasks

One continuous session, in order, no restarts between tasks (PROTOCOL sections
1 and 3.3). For each task:

1. Start the stopwatch.
2. Paste the utterance from PROTOCOL section 1 **verbatim**. No scaffolding, no
   pre-answering questions the agent has not asked.
3. Let it run to completion, a question, or a stall, without steering.
4. Stop the stopwatch when the response and any synchronous MCP call it started
   finish, or when you abandon the task. Normal waits for the MCP result and
   activation are part of `wall_seconds`; do not subtract them. The compatibility
   patch prevents the client's old 60-second cancellation but does not
   acknowledge a tool early. A timeout is `completion: false`, not a missing row.
5. Verify objectively, not by the agent's self-report:

   | Task | Check inside the VM |
   |---|---|
   | 1 install firefox | `which firefox` |
   | 2 put obsidian on my machine | `which obsidian` |
   | 3 remove firefox | `which firefox` now fails |
   | 4 watch videos, get vlc | `which vlc` |
   | 5 undo that | `nixos-rebuild list-generations`, and vlc gone again |
   | 6 install mpv | `which mpv`, `systemctl is-failed baseline-chaos` |

6. Do the section 5.3 / 5.4 transcript review now, while it is fresh: count the
   questions the agent asked, and count every distinct shell command it ran or
   asked you to approve. The coding-agent transcript and tool-call log are the
   source of truth for `terminal_exposure`, not the agent's prose summary.
   Reconcile them with the nix-agent audit log to identify MCP operations and
   possible bypasses.

At each task boundary, note the line count of
`/var/log/nix-agent-baseline/usage.jsonl`, or copy/slice the corresponding
lines for later review. The root-owned JSONL records only nix-agent MCP tool
events, not arbitrary coding-agent shell commands. It is a cross-check for
privileged operations, not the terminal-exposure source of truth. Do not clear,
truncate, or otherwise modify it. The two successful preflight events,
`locate_option` then `eval_config`, are setup evidence outside every measured
task. Record task 1's starting line boundary after those two events and do not
attribute them to task 1.

### Task 6 fault injection

Before issuing `install mpv`, inject the activation fault. `vm/fault.nix` is a
systemd unit that fails during `switch-to-configuration`, deliberately the same
*shape* of fault as the intentd arm's `intentd-chaos.service` and at the same
point in the pipeline, so `recovery_success` is comparable. From the host:

```fish
scp -P 2222 eval/baseline/vm/fault.nix wedge@localhost:/etc/nixos/fault.nix
```

then add `./fault.nix` to the module list in `/etc/nixos/flake.nix` (below
`./vm-node.nix`), and hand the agent the task. Do not tell it what you did.

With this exact fault imported, activation fails with `returned non-zero exit
status 4` and leaves `baseline-chaos.service` `failed`. Both are visible to an
agent that looks; whether it looks is the measurement. Let the agent complete
its first response to that injected failure without steering.

What you are scoring (PROTOCOL section 5.5): did it notice the failure at all,
did it leave the system runnable, and did it either complete `install mpv` or
clearly report that it could not.

If the agent removes the `fault.nix` import itself, record
`fault_variant: "agent_cleared"`. Otherwise, only after its first attempt has
concluded, the observer removes the import, re-issues `install mpv`, and
records `fault_variant: "human_cleared"`. This mirrors the intentd harness
clearing `/etc/intentd-chaos`; it is an observed recovery outcome, not an
operator choice. Do not steer the agent before its first response concludes.

## 4. Record the results

Copy the template and fill it in:

```fish
cp eval/baseline/baseline_arm.template.json eval/baseline/baseline_arm.json
```

Every field is documented inline. Copy the two patcher statuses, exact immutable
store path, and pre/post-chat version outputs into the transport metadata fields
without interpretation. `completion`, `wall_seconds`,
`clarification_turns`, and `terminal_exposure` are per task;
`post_failure_trust` is one score for the arm, and you also need to score the
**intentd** arm's trust (rerun or rewatch `vm-baseline-pilot` if you want it
fresh) and write it into `intentd_arm.json`, which currently has `null` there.

Then:

```fish
uv run python -m eval.baseline.compare
```

prints the side-by-side table and flags any metric that is still unscored. It
refuses to declare a winner on a metric where either arm has a `null`.

## 5. What "done" looks like

- `eval/baseline/baseline_arm.json` exists with six rows.
- Its Cursor transport metadata passes the exact invariant checks in
  `eval/baseline/compare.py`.
- `post_failure_trust` is non-null in **both** arm files.
- `uv run python -m eval.baseline.compare` runs clean with no unscored warnings.

At that point the wedge closeout's honest gap 3 ("the baseline comparative arm
is unrun; the wedge cannot yet claim it beats the assistant baseline, only that
the measurement harness exists") can be rewritten with a real result, whichever
way it goes.
