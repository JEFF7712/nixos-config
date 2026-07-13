# Flake Update Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated systemd update bodies with one packaged, fixture-tested `nixos-flake-update` script while preserving weekly and hourly policy.

**Architecture:** A standalone Bash module owns update, validation, restoration, commit, and rebuild sequencing. The NixOS module packages it with explicit runtime dependencies and supplies only job metadata and input names.

**Tech Stack:** Bash, systemd, NixOS modules, temporary Git repositories, `just`, ShellCheck

---

## File Structure

- Create `home/scripts/nixos-flake-update`: executable update transaction with environment-overridable command adapters for tests.
- Create `checks/flake-update.bash`: fixture tests for every pipeline outcome.
- Modify `modules/nixos/auto-update.nix`: package the script and configure the two jobs.
- Modify `justfile`: add the focused check to `shell-check` and `check`.

### Task 1: Build the update-pipeline fixture

**Files:**
- Create: `checks/flake-update.bash`
- Modify: `justfile:12-16,61-72`

- [ ] **Step 1: Write a failing unchanged-lock test**

Create a harness that makes a temporary repository, writes executable adapters named `runuser`, `nix`, `git`, `getent`, `flock`, `nix-cascade-guard`, and `nixos-rebuild` into `$tmpdir/bin`, records calls in `$COMMAND_LOG`, and invokes:

```bash
env \
  PATH="$bin_dir:$PATH" \
  COMMAND_LOG="$log" \
  UPDATE_LOCK="$tmpdir/update.lock" \
  DNS_RETRIES=1 \
  DNS_RETRY_DELAY=0 \
  CASCADE_GUARD="$bin_dir/nix-cascade-guard" \
  NIXOS_REBUILD="$bin_dir/nixos-rebuild" \
  home/scripts/nixos-flake-update \
    --label weekly \
    --repo "$repo" \
    --target "path:$repo#laptop" \
    --commit-message "flake.lock: weekly auto-update"
```

Assert exit zero, one `nix flake update --flake path:$repo` call, and no cascade, commit, or rebuild call when the Git adapter reports no diff.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash checks/flake-update.bash`

Expected: FAIL because `home/scripts/nixos-flake-update` does not exist.

- [ ] **Step 3: Register the focused check**

Add this recipe and call it from `check` before formatting:

```make
check-flake-update:
  bash checks/flake-update.bash
```

- [ ] **Step 4: Commit the failing fixture**

```bash
git add checks/flake-update.bash justfile
git commit -m "test(auto-update): cover unchanged update pipeline"
```

### Task 2: Implement the minimal standalone pipeline

**Files:**
- Create: `home/scripts/nixos-flake-update`
- Test: `checks/flake-update.bash`

- [ ] **Step 1: Implement argument parsing and adapters**

Use this public interface and defaults:

```bash
#!/usr/bin/env bash
set -euo pipefail

label=""
repo=""
target=""
commit_message=""
inputs=()
update_lock="${UPDATE_LOCK:-/run/nixos-auto-update.lock}"
dns_retries="${DNS_RETRIES:-60}"
dns_retry_delay="${DNS_RETRY_DELAY:-5}"
cascade_guard="${CASCADE_GUARD:-}"
nixos_rebuild="${NIXOS_REBUILD:-nixos-rebuild}"

while (($#)); do
  case "$1" in
    --label) label=$2; shift 2 ;;
    --repo) repo=$2; shift 2 ;;
    --target) target=$2; shift 2 ;;
    --commit-message) commit_message=$2; shift 2 ;;
    --input) inputs+=("$2"); shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

for value in label repo target commit_message; do
  [ -n "${!value}" ] || { printf 'missing --%s\n' "${value//_/-}" >&2; exit 2; }
done
```

Implement `restore_lock`, acquire the lock with `exec {lock_fd}>"$update_lock"` and `flock -n "$lock_fd"`, retry `getent hosts api.github.com`, run the update through `runuser -u rupan -- nix flake update --flake "path:$repo" "${inputs[@]}"`, evaluate, check `git diff --quiet -- flake.lock`, run the cascade guard, commit only `flake.lock`, then rebuild with `--option max-jobs 2 --option cores 8`.

- [ ] **Step 2: Preserve each defined exit outcome**

Use these outcomes:

```text
lock busy                 exit 0, no mutation
DNS unavailable           exit 1, no update
update/eval failure       restore flake.lock, exit 1
lock unchanged            exit 0, no rebuild
cascade exit 10           restore flake.lock, exit 0
other cascade failure     restore flake.lock, exit 1
rebuild failure           keep committed lock, exit nonzero
```

- [ ] **Step 3: Run the focused test**

Run: `bash checks/flake-update.bash`

Expected: PASS with `flake update pipeline checks passed`.

- [ ] **Step 4: Run ShellCheck**

Run: `just shell-check`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add home/scripts/nixos-flake-update checks/flake-update.bash
git commit -m "feat(auto-update): add standalone update pipeline"
```

### Task 3: Complete failure-path coverage

**Files:**
- Modify: `checks/flake-update.bash`
- Modify: `home/scripts/nixos-flake-update`

- [ ] **Step 1: Add table-driven fixture cases**

Add `run_case name expected_status` and cover these adapter behaviors:

```text
full update:              no --input arguments reach nix
AI update:                three --input values reach nix in order
lock contention:          update is never called
DNS timeout:              update is never called
eval failure:             git checkout -- flake.lock is called
cascade deferral:         checkout is called, commit is not
cascade error:            checkout is called, exit is nonzero
success:                  commit precedes rebuild
rebuild failure:          commit remains and exit is nonzero
```

For each case, use exact `grep -F` assertions against `$COMMAND_LOG` and assert call ordering with line numbers from `grep -n`.

- [ ] **Step 2: Run tests to expose missing behavior**

Run: `bash checks/flake-update.bash`

Expected: at least one new case fails before implementation adjustment.

- [ ] **Step 3: Make the smallest pipeline corrections**

Correct only behavior exposed by the cases. Keep policy messages parameterized by `label`, and keep restoration in one `restore_lock` function:

```bash
restore_lock() {
  runuser -u rupan -- git -C "$repo" checkout -- flake.lock
}
```

- [ ] **Step 4: Verify and commit**

Run: `bash checks/flake-update.bash && just shell-check`

Expected: both PASS.

```bash
git add checks/flake-update.bash home/scripts/nixos-flake-update
git commit -m "test(auto-update): cover pipeline failure outcomes"
```

### Task 4: Wire both systemd jobs to the pipeline

**Files:**
- Modify: `modules/nixos/auto-update.nix:1-168`
- Test: `checks/agent-invariants.bash`

- [ ] **Step 1: Add a failing structural assertion**

Require `modules/nixos/auto-update.nix` to reference `nixos-flake-update` twice and require the standalone script to contain the eval, cascade, commit, and rebuild operations. Remove invariants that require those operations to remain inline in the Nix file.

- [ ] **Step 2: Run the invariant check**

Run: `bash checks/agent-invariants.bash`

Expected: FAIL because both services still embed their pipelines.

- [ ] **Step 3: Package the script once**

In the module `let`, define:

```nix
updatePipeline = pkgs.writeShellApplication {
  name = "nixos-flake-update";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    getent
    git
    nix
    nixos-rebuild
    util-linux
  ];
  text = builtins.readFile ../../home/scripts/nixos-flake-update;
};
```

Create one `mkUpdateService` constructor containing the shared unit metadata and resource controls. Its arguments are `description`, `label`, `commitMessage`, and `inputs`. Build repeated `--input` arguments with `lib.escapeShellArgs`.

- [ ] **Step 4: Instantiate the two policies**

Keep the current timer declarations unchanged. Instantiate:

```nix
nixos-auto-update = mkUpdateService {
  description = "Update flake inputs, commit lock file, and rebuild";
  label = "weekly";
  commitMessage = "flake.lock: weekly auto-update";
  inputs = [ ];
};

nixos-ai-tools-auto-update = mkUpdateService {
  description = "Update AI tool flake inputs, commit lock file, and rebuild";
  label = "AI tools";
  commitMessage = "flake.lock: ai tools auto-update";
  inputs = [ "claude-code-nix" "codex-cli-nix" "code-cursor-nix" ];
};
```

- [ ] **Step 5: Verify focused and declarative checks**

Run:

```bash
just check-flake-update
just check-agent-workflows
just fmt-check
just eval laptop
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add modules/nixos/auto-update.nix checks/agent-invariants.bash
git commit -m "refactor(auto-update): share update job pipeline"
```

### Task 5: Final update-pipeline verification

**Files:**
- Modify only if a verification failure proves it necessary.

- [ ] **Step 1: Run the complete relevant gate**

Run:

```bash
just check-flake-update
just shell-check
just check-agent-workflows
just fmt-check
just eval laptop
git diff --check
```

Expected: all PASS and no uncommitted changes.

- [ ] **Step 2: Inspect the evaluated units**

Run:

```bash
nix eval --raw .#nixosConfigurations.laptop.config.systemd.services.nixos-auto-update.script
nix eval --raw .#nixosConfigurations.laptop.config.systemd.services.nixos-ai-tools-auto-update.script
```

Expected: both call `nixos-flake-update`; only the AI job includes the three named inputs.
