# Baseline Privilege Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the baseline VM reproducibly expose pinned nix-agent as its only privileged system-change interface, and prove direct privilege bypasses fail.

**Architecture:** The baseline VM and its seeded guest flake share one evaluation-only NixOS module. That module installs an exact nix-agent revision and exposes a compiled, setuid root MCP launcher with a trusted environment, while the interactive account has no wheel, sudo, root-password, or root-SSH path. A nested NixOS VM check exercises negative bypass cases and a real FastMCP stdio `switch` call.

**Tech Stack:** Nix flakes, NixOS modules, NixOS VM tests, C launcher, FastMCP Python client, pytest, Ruff, Pyright

---

## File map

- Create `eval/baseline/vm/nix-agent-launcher.c`: minimal privileged process boundary. It rejects CLI arguments, normalizes root credentials, clears the caller environment, installs trusted values, and execs the pinned nix-agent binary.
- Create `eval/baseline/vm/agent-harness.nix`: owns the baseline account, root-login policy, trusted runtime path, launcher build, setuid wrapper, pinned package installation, and usage-log directory.
- Create `eval/baseline/vm/privilege-boundary.nix`: boots the baseline modules and proves both denied direct paths and the successful stdio MCP path.
- Modify `eval/baseline/vm/flake.nix`: pin nix-agent, pass it through `specialArgs`, import the shared harness module, and expose the VM check.
- Modify `eval/baseline/vm/seed-flake.nix`: reproduce the same input and module graph inside `/etc/nixos`.
- Modify `eval/baseline/vm/flake.lock`: lock the exact nix-agent revision and its followed nixpkgs input.
- Modify `eval/baseline/vm/seed.nix`: seed `agent-harness.nix` and the launcher source into `/etc/nixos`.
- Modify `eval/baseline/vm/configuration.nix`: remove wheel, sudo, known-root-password, and root-SSH definitions now owned by the harness module.
- Modify `eval/baseline/RUNBOOK.md`: document the preinstalled MCP command, preflight, clean-disk requirement, and invalid-run rule.
- Modify `eval/baseline/PROTOCOL.md`: make the reproducible pin and privilege boundary normative.
- Create `eval/baseline/baseline_arm.json` only after a valid clean run, using the existing template and observed values.
- Modify `eval/baseline/intentd_arm.json` only for the observer-supplied trust score.

### Task 1: Pin the nix-agent dependency

**Files:**
- Modify: `eval/baseline/vm/flake.nix`
- Modify: `eval/baseline/vm/seed-flake.nix`
- Modify: `eval/baseline/vm/flake.lock`

- [ ] **Step 1: Add the exact input to both flakes**

Add this next to `inputs.nixpkgs` in both flake files:

```nix
inputs.nix-agent = {
  url = "github:JEFF7712/nix-agent/317334c76aa07ade539918014b977685501f7aaa";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Change each outputs argument to accept `nix-agent`:

```nix
outputs =
  {
    self,
    nixpkgs,
    nix-agent,
  }:
```

Do not import the input yet. This task establishes dependency identity without changing guest behavior.

- [ ] **Step 2: Regenerate the nested lock file**

Run:

```fish
nix flake lock ./eval/baseline/vm
```

Expected: `eval/baseline/vm/flake.lock` gains a `nix-agent` node locked at revision `317334c76aa07ade539918014b977685501f7aaa`, and its nixpkgs input points to the existing `nixpkgs` node.

- [ ] **Step 3: Verify both flake entry points resolve the pin**

Run:

```fish
nix flake metadata ./eval/baseline/vm --json | jq -e '.locks.nodes["nix-agent"].locked.rev == "317334c76aa07ade539918014b977685501f7aaa"'
nix eval --raw ./eval/baseline/vm#nixosConfigurations.baseline.pkgs.system
```

Expected: jq returns success and the evaluation prints `x86_64-linux`.

- [ ] **Step 4: Commit the dependency pin**

```fish
git add eval/baseline/vm/flake.nix eval/baseline/vm/seed-flake.nix eval/baseline/vm/flake.lock
git commit -m "harness: pin baseline nix-agent"
```

### Task 2: Write the privilege-boundary VM test and observe failure

**Files:**
- Create: `eval/baseline/vm/privilege-boundary.nix`
- Modify: `eval/baseline/vm/flake.nix`

- [ ] **Step 1: Add the test with negative and positive assertions**

Create `eval/baseline/vm/privilege-boundary.nix`:

```nix
{
  nixpkgs,
  nix-agent,
  baselineModules,
}:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  mcpClient = pkgs.writeText "baseline-mcp-client.py" ''
    import asyncio
    import sys
    from pathlib import Path

    from fastmcp import Client

    CONFIG = {
        "mcpServers": {
            "nix-agent": {
                "command": "/run/wrappers/bin/nix-agent-mcp",
                "args": [],
            }
        }
    }

    async def main() -> None:
        async with Client(CONFIG) as client:
            if sys.argv[1] == "hold":
                Path("/tmp/nix-agent-mcp-ready").write_text("ready")
                await asyncio.sleep(20)
                return
            result = await client.call_tool("switch", {})
            if result.is_error:
                raise RuntimeError(str(result))

    asyncio.run(main())
  '';
  editConfig = pkgs.writeText "baseline-edit-config.py" ''
    from pathlib import Path

    path = Path("/etc/nixos/configuration.nix")
    text = path.read_text()
    closing = "\n}\n"
    if not text.endswith(closing):
        raise RuntimeError("configuration.nix has an unexpected ending")
    path.write_text(
        text[: -len(closing)]
        + '\n  environment.etc."baseline-boundary-proof".text = "through-mcp";'
        + closing
    )
  '';
in
nixpkgs.lib.nixos.runTest {
  name = "baseline-privilege-boundary";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = baselineModules;
      _module.args.nix-agent = nix-agent;
      environment.systemPackages = [
        (pkgs.python3.withPackages (ps: [ ps.fastmcp ]))
      ];
      environment.etc."baseline-mcp-client.py".source = mcpClient;
      environment.etc."baseline-edit-config.py".source = editConfig;
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("seed-etc-nixos.service")

    groups = machine.succeed("id -nG wedge").split()
    assert "wheel" not in groups, groups
    machine.fail("runuser -u wedge -- sudo -n true")
    machine.fail("runuser -u wedge -- /run/wrappers/bin/sudo -n true")
    machine.succeed("getent shadow root | cut -d: -f2 | grep -E '^!+$'")
    machine.succeed("sshd -T | grep -Fx 'permitrootlogin no'")
    machine.fail(
        "runuser -u wedge -- nix-env --profile /nix/var/nix/profiles/system "
        "--set /run/current-system"
    )
    machine.fail(
        "runuser -u wedge -- /run/current-system/bin/switch-to-configuration switch"
    )
    machine.fail("runuser -u wedge -- /run/wrappers/bin/nix-agent-mcp usage")

    machine.succeed(
        "runuser -u wedge -- sh -c "
        "'python /etc/baseline-mcp-client.py hold >/tmp/mcp-hold.log 2>&1 &'"
    )
    machine.wait_until_succeeds("test -e /tmp/nix-agent-mcp-ready")
    machine.succeed(
        "pid=$(cat /run/nix-agent-baseline/server.pid); "
        "test \"$(awk '/^Uid:/{print $3}' /proc/$pid/status)\" = 0"
    )

    machine.succeed("runuser -u wedge -- python /etc/baseline-edit-config.py")
    before = int(machine.succeed("nix-env -p /nix/var/nix/profiles/system --list-generations | wc -l"))
    machine.succeed("runuser -u wedge -- python /etc/baseline-mcp-client.py switch", timeout=1800)
    machine.succeed("test \"$(cat /etc/baseline-boundary-proof)\" = through-mcp")
    after = int(machine.succeed("nix-env -p /nix/var/nix/profiles/system --list-generations | wc -l"))
    assert after > before, (before, after)
  '';
}
```

- [ ] **Step 2: Expose the check against the current baseline modules**

In `eval/baseline/vm/flake.nix`, add this output before `packages`:

```nix
checks.x86_64-linux.privilege-boundary = import ./privilege-boundary.nix {
  inherit nixpkgs nix-agent;
  baselineModules = [
    ./configuration.nix
    ./seed.nix
  ];
};
```

- [ ] **Step 3: Run the test and verify the current harness fails**

Run:

```fish
nix build ./eval/baseline/vm#checks.x86_64-linux.privilege-boundary -L --no-link
```

Expected: FAIL at the wheel-membership or direct-sudo assertion. The current configuration intentionally violates the new contract.

Do not commit yet. The failing test and minimal implementation belong to one logical change.

### Task 3: Implement the constrained MCP launcher and shared module

**Files:**
- Create: `eval/baseline/vm/nix-agent-launcher.c`
- Create: `eval/baseline/vm/agent-harness.nix`
- Modify: `eval/baseline/vm/configuration.nix`
- Modify: `eval/baseline/vm/flake.nix`
- Modify: `eval/baseline/vm/seed-flake.nix`
- Modify: `eval/baseline/vm/seed.nix`
- Test: `eval/baseline/vm/privilege-boundary.nix`

- [ ] **Step 1: Create the compiled launcher**

Create `eval/baseline/vm/nix-agent-launcher.c`:

```c
#define _GNU_SOURCE

#include <errno.h>
#include <grp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

static int fail(const char *operation) {
    fprintf(stderr, "nix-agent-mcp: %s: %s\n", operation, strerror(errno));
    return 70;
}

int main(int argc, char **argv) {
    (void)argv;
    if (argc != 1) {
        fputs("nix-agent-mcp: command-line arguments are not allowed\n", stderr);
        return 64;
    }

    if (setgroups(0, NULL) != 0) return fail("setgroups");
    if (setgid(0) != 0) return fail("setgid");
    if (setuid(0) != 0) return fail("setuid");
    umask(0022);

    if (clearenv() != 0) return fail("clearenv");
    if (setenv("HOME", "/root", 1) != 0) return fail("setenv HOME");
    if (setenv("LANG", "C.UTF-8", 1) != 0) return fail("setenv LANG");
    if (setenv("PATH", "@trustedPath@", 1) != 0) return fail("setenv PATH");
    if (setenv("NIX_AGENT_FLAKE", "/etc/nixos#baseline", 1) != 0) {
        return fail("setenv NIX_AGENT_FLAKE");
    }
    if (setenv("NIX_AGENT_USAGE_LOG_PATH", "/var/log/nix-agent-baseline/usage.jsonl", 1) != 0) {
        return fail("setenv NIX_AGENT_USAGE_LOG_PATH");
    }

    FILE *pid_file = fopen("/run/nix-agent-baseline/server.pid", "w");
    if (pid_file == NULL) return fail("open server.pid");
    if (fprintf(pid_file, "%ld\n", (long)getpid()) < 0) return fail("write server.pid");
    if (fclose(pid_file) != 0) return fail("close server.pid");

    char *const child_argv[] = { "nix-agent", NULL };
    execv("@nixAgent@/bin/nix-agent", child_argv);
    return fail("execv");
}
```

The launcher accepts only stdio MCP startup. In particular, callers cannot use the privileged wrapper for nix-agent's `usage` or `inspect-flake` CLI subcommands. Clearing `PATH` prevents a user-owned fake `sudo`, `nix`, or `nixos-rebuild` from executing as root.

- [ ] **Step 2: Create the shared NixOS harness module**

Create `eval/baseline/vm/agent-harness.nix`:

```nix
{
  config,
  lib,
  pkgs,
  nix-agent,
  ...
}:
let
  nixAgentPackage = nix-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  trustedPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.sudo
    pkgs.systemd
  ];
  launcherSource = pkgs.runCommand "nix-agent-launcher.c" { } ''
    substitute ${./nix-agent-launcher.c} "$out" \
      --subst-var-by nixAgent ${nixAgentPackage} \
      --subst-var-by trustedPath ${lib.escapeShellArg trustedPath}
  '';
  launcher = pkgs.runCommandCC "nix-agent-mcp-launcher" { } ''
    $CC -std=c11 -O2 -Wall -Wextra -Werror ${launcherSource} -o "$out"
  '';
in
{
  users.mutableUsers = false;
  users.users.wedge = {
    isNormalUser = true;
    initialPassword = "wedge";
    extraGroups = [ ];
  };
  users.users.root.hashedPassword = "!";

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = true;
  };

  environment.systemPackages = [ nixAgentPackage ];
  systemd.tmpfiles.rules = [
    "d /var/log/nix-agent-baseline 0755 root root -"
    "d /run/nix-agent-baseline 0755 root root -"
  ];

  security.wrappers.nix-agent-mcp = {
    source = launcher;
    owner = "root";
    group = "root";
    setuid = true;
    permissions = "u+rx,g+x,o+x";
  };
}
```

- [ ] **Step 3: Remove the superseded insecure configuration**

In `eval/baseline/vm/configuration.nix`:

- Remove the entire `users.users.wedge` block.
- Remove `users.users.root.initialPassword = "root";`.
- Remove `security.sudo.wheelNeedsPassword = false;` and its explanatory comment.
- Keep `services.openssh.enable = true`, but remove its `settings` block because the shared module now owns those values.

The resulting SSH declaration is:

```nix
services.openssh.enable = true;
```

- [ ] **Step 4: Import the shared module through both flakes**

In both calls to `nixpkgs.lib.nixosSystem`, add:

```nix
specialArgs = { inherit nix-agent; };
```

Add `./agent-harness.nix` immediately after `./configuration.nix` in both module lists. In the outer flake, update the test's module argument to:

```nix
baselineModules = [
  ./configuration.nix
  ./agent-harness.nix
  ./seed.nix
];
```

- [ ] **Step 5: Seed the shared module and C source**

In `eval/baseline/vm/seed.nix`, add both files to `seedDir`:

```nix
cp ${./agent-harness.nix} "$out/agent-harness.nix"
cp ${./nix-agent-launcher.c} "$out/nix-agent-launcher.c"
```

Extend the first-boot copy command so its complete file list is:

```nix
cp ${seedDir}/flake.nix ${seedDir}/flake.lock \
   ${seedDir}/configuration.nix ${seedDir}/agent-harness.nix \
   ${seedDir}/nix-agent-launcher.c ${seedDir}/vm-node.nix /etc/nixos/
```

- [ ] **Step 6: Run the focused test to verify it passes**

Run:

```fish
nix build ./eval/baseline/vm#checks.x86_64-linux.privilege-boundary -L --no-link
```

Expected: PASS. The log shows direct privilege attempts failing and the MCP `switch` creating `/etc/baseline-boundary-proof`.

- [ ] **Step 7: Verify the built configuration preserves the boundary**

Run:

```fish
nix eval --json ./eval/baseline/vm#nixosConfigurations.baseline.config.users.users.wedge.extraGroups | jq -e '. == []'
nix eval --raw ./eval/baseline/vm#nixosConfigurations.baseline.config.services.openssh.settings.PermitRootLogin
nix build ./eval/baseline/vm#nixosConfigurations.baseline.config.system.build.vm --no-link
```

Expected: the group assertion succeeds, SSH prints `no`, and the VM builds.

- [ ] **Step 8: Commit the tested boundary**

```fish
git add eval/baseline/vm/nix-agent-launcher.c eval/baseline/vm/agent-harness.nix eval/baseline/vm/privilege-boundary.nix eval/baseline/vm/configuration.nix eval/baseline/vm/flake.nix eval/baseline/vm/seed-flake.nix eval/baseline/vm/seed.nix
git commit -m "harness: constrain baseline privilege to nix-agent"
```

### Task 4: Align the protocol and runbook

**Files:**
- Modify: `eval/baseline/RUNBOOK.md`
- Modify: `eval/baseline/PROTOCOL.md`

- [ ] **Step 1: Replace the runbook's insecure setup description**

In `eval/baseline/RUNBOOK.md`, replace the passwordless-sudo bullet with:

```markdown
- nix-agent revision `317334c76aa07ade539918014b977685501f7aaa` is pinned by
  the VM flake and installed by the shared harness module. `wedge` is not in
  `wheel`, direct sudo fails, root login is disabled, and privileged system
  changes are available only through `/run/wrappers/bin/nix-agent-mcp`.
```

Replace the manual nix profile installation section with:

```markdown
Inside the VM, configure the coding agent's MCP server with this command and no
arguments:

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

The server is pinned and already installed. Do not install another nix-agent
revision. Before starting the stopwatch, confirm the MCP server initializes and
lists its tools. Also confirm `sudo -n true` fails as `wedge`. If either check
fails, stop: the harness is invalid and no task timing should be recorded.
```

Keep the instruction that the agent receives no other privileged tool. Add that any direct sudo, `su`, root SSH, system-profile mutation, or direct activation observed during a run invalidates the comparison.

- [ ] **Step 2: Make the protocol's setup normative and reproducible**

Replace the illustrative minimal-flake block in `eval/baseline/PROTOCOL.md` section 3.1 with these requirements:

```markdown
The checked-in harness under `eval/baseline/vm` is normative. It pins nix-agent
at revision `317334c76aa07ade539918014b977685501f7aaa`, makes that input follow
the shared nixpkgs pin, and seeds the same module graph into `/etc/nixos`.

The `wedge` account must not belong to `wheel`; direct sudo, root password
login, root SSH, direct system-profile mutation, and direct activation must
fail. The only privileged entry point supplied to the coding agent is the
stdio MCP command `/run/wrappers/bin/nix-agent-mcp`. Unprivileged edits to the
user-owned `/etc/nixos` tree remain allowed.
```

Add this validity rule to section 3.3:

```markdown
- A run is invalid if the agent completes a privileged system change outside
  nix-agent's MCP tools. Reaching the requested application state does not
  override this protocol violation.
```

- [ ] **Step 3: Check documentation consistency**

Run:

```fish
rg -n 'wheelNeedsPassword|passwordless `sudo`|nix profile install github:JEFF7712/nix-agent|PermitRootLogin = "yes"' eval/baseline
rg -n '317334c76aa07ade539918014b977685501f7aaa|nix-agent-mcp' eval/baseline/RUNBOOK.md eval/baseline/PROTOCOL.md
```

Expected: the first search returns no matches. The second returns the pin and wrapper in both documents.

- [ ] **Step 4: Commit the documentation alignment**

```fish
git add eval/baseline/RUNBOOK.md eval/baseline/PROTOCOL.md
git commit -m "docs: define baseline privilege boundary"
```

### Task 5: Run the complete automated verification matrix

**Files:**
- No source changes expected

- [ ] **Step 1: Run Python tests and static analysis**

Run:

```fish
uv run pytest -q
uv run ruff check .
uv run pyright
```

Expected: 281 tests pass with 2 deselected, Ruff reports no errors, and Pyright reports 0 errors.

- [ ] **Step 2: Run the opt-in and live resolver checks**

Run:

```fish
uv run pytest -q -m nix_eval tests/test_flake_eval.py
uv run pytest -q -m claude_live tests/test_resolver.py::test_run_claude_resolves_install_firefox_live
```

Expected: the opt-in Nix evaluation test and the signed-in Claude resolver smoke test each pass.

- [ ] **Step 3: Check the nested baseline flake**

Run:

```fish
nix flake check ./eval/baseline/vm -L
```

Expected: the baseline VM package evaluates and `privilege-boundary` passes.

- [ ] **Step 4: Check the root project flake**

Run:

```fish
nix flake check -L
```

Expected: all four existing root VM checks pass: `vm-smoke`, `vm-cli`, `vm-scenarios`, and `vm-baseline-pilot`.

- [ ] **Step 5: Inspect repository state**

Run:

```fish
git status --short
git log -6 --oneline
```

Expected: no uncommitted source changes and one logical commit for each completed implementation task.

### Task 6: Produce the valid comparative baseline

**Files:**
- Create: `eval/baseline/baseline_arm.json`
- Modify: `eval/baseline/intentd_arm.json`

- [ ] **Step 1: Start from a clean persistent disk**

Inspect any existing `baseline.qcow2` with `ls -lh` before removing it because the directory predates this work. Then remove only that exact disk, build the nested VM, and boot it:

```fish
ls -lh baseline.qcow2
rm baseline.qcow2
set vm (nix build ./eval/baseline/vm --print-out-paths --no-link)
$vm/bin/run-baseline-vm
```

Expected: a new disk is created and the VM reaches the login prompt.

- [ ] **Step 2: Run the preflight before timing**

As `wedge`, verify direct sudo fails and the coding agent initializes `/run/wrappers/bin/nix-agent-mcp`. Record the coding-agent model and exact nix-agent revision. Abort the run if direct privilege succeeds or MCP initialization fails.

- [ ] **Step 3: Execute the six utterances in one session**

Follow `eval/baseline/RUNBOOK.md` exactly. Issue, in order:

```text
install firefox
put obsidian on my machine
remove firefox
i need something to watch videos, get vlc
undo that
install mpv
```

For task 6, inject `eval/baseline/vm/fault.nix` exactly as documented before issuing the utterance. Record objective completion, stopwatch duration, clarification turns, terminal exposure, and recovery success immediately after each task. Invalidate the run if a privileged change bypasses nix-agent.

- [ ] **Step 4: Materialize the observed baseline data**

Copy the template using `cp`, then replace every measurement field with the observed value and add the recorded agent and nix-agent revisions:

```fish
cp eval/baseline/baseline_arm.template.json eval/baseline/baseline_arm.json
```

Run:

```fish
jq -e '.tasks | length == 6' eval/baseline/baseline_arm.json
jq -e '[.tasks[] | .completion, .wall_seconds, .clarification_turns, .terminal_exposure] | all(. != null)' eval/baseline/baseline_arm.json
```

Expected: both jq checks succeed.

- [ ] **Step 5: Obtain the irreducibly human trust scores**

Show the observer the valid task-6 transcript and the intentd task-6 pilot evidence. Ask the observer for one integer from 1 through 5 for each arm under protocol section 5.6. Write those two supplied integers to `baseline_arm.json` and `intentd_arm.json`. Do not infer or fabricate either score.

- [ ] **Step 6: Generate and validate the comparison**

Run:

```fish
uv run python -m eval.baseline.compare
```

Expected: exit code 0, a two-arm comparison table, and no unscored-metric warning.

- [ ] **Step 7: Commit the valid measured results**

```fish
git add eval/baseline/baseline_arm.json eval/baseline/intentd_arm.json
git commit -m "eval: record comparative baseline"
```

Do not commit the invalid `/tmp/intentd-baseline-invalid-*` artifacts or any VM disk, SSH key, credential, transcript containing credentials, or agent cache.
