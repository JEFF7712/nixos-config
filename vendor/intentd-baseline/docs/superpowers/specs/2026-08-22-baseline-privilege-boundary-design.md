# Baseline privilege boundary design

Date: 2026-08-22

## Context

The baseline arm is meant to measure a competent coding agent using nix-agent
on plain NixOS. Its VM currently makes the `wedge` account a member of `wheel`
and grants passwordless sudo to that group. In the first real baseline run, the
agent used that unrestricted privilege to bypass nix-agent after task 1. The
applications reached their requested states, but the run did not test the
declared baseline and is invalid.

The harness also asks the operator to install the latest nix-agent manually.
That makes the agent toolchain drift independently of the pinned NixOS system
and prevents exact reproduction of a run.

## Goals

- Pin nix-agent revision
  `317334c76aa07ade539918014b977685501f7aaa` in the harness.
- Permit system activation through nix-agent's MCP tools.
- Deny `wedge` a general root shell and arbitrary privileged commands.
- Remove the known root password and deny direct root login.
- Prove the privilege boundary and the supported activation path in an
  automated NixOS VM check.
- Keep the baseline free of intentd, its catalog, and task-specific priming.
- Make privilege setup failures occur before measured tasks begin.

## Non-goals

- Sandboxing the coding agent's unprivileged file access or network access.
- Changing nix-agent itself.
- Automating the human transcript and trust scoring required by the protocol.
- Making a malicious NixOS configuration safe to activate. Activation is the
  explicitly authorized privileged operation in this evaluation.

## Flake inputs and module ownership

Both `eval/baseline/vm/flake.nix` and the guest's
`eval/baseline/vm/seed-flake.nix` will declare the same nix-agent input at the
approved revision. Its `nixpkgs` input will follow the harness's existing
pinned nixpkgs input so nix-agent does not introduce a second package universe.

A new shared module, `eval/baseline/vm/agent-harness.nix`, will own the
evaluation-only account and privilege configuration. Both the outer VM and the
seeded guest configuration will import it. Keeping the module in both module
graphs ensures an agent-triggered switch preserves the boundary rather than
silently restoring the old wheel membership.

`configuration.nix` will retain the plain system and application list. It will
no longer define `wedge`'s wheel membership or passwordless sudo. The new
module will define `wedge` as a normal user without `wheel` and install the
pinned nix-agent package.

The current harness also sets a known root password and permits root SSH. Both
paths bypass the MCP boundary. The shared harness module will keep the root
account locked, and SSH will set `PermitRootLogin = "no"` while retaining
password authentication for `wedge`.

## Privileged MCP entry point

NixOS `security.wrappers` will expose one root-owned setuid entry point at
`/run/wrappers/bin/nix-agent-mcp`. Its source will be an immutable launcher in
the Nix store that sets `NIX_AGENT_FLAKE=/etc/nixos#baseline` and then executes
the pinned package's `bin/nix-agent` executable by absolute store path.

The coding agent's MCP configuration will invoke this wrapper directly. The
server process therefore has the privilege required for its internal
`sudo -n nixos-rebuild` calls, while the interactive `wedge` shell has no
matching sudo authorization. Running `sudo` as effective UID 0 is harmless and
preserves nix-agent's existing command construction without modifying its
source.

This boundary grants privilege to nix-agent's MCP surface, not to an arbitrary
command chosen by the coding agent. nix-agent does not edit files. The coding
agent edits the user-owned `/etc/nixos` tree as `wedge`, then requests build,
switch, rollback, and inspection operations through MCP. A configuration switch
can execute root-level NixOS activation logic, which is the intentional power
being measured.

`NIX_AGENT_FLAKE` supplies the normal target but is not an authorization
boundary: nix-agent tools can accept an explicit flake URI. The relevant
boundary is that privileged execution remains constrained to nix-agent's MCP
operations. Any flake activated through those operations can contain privileged
NixOS activation logic, which is inherent in authorizing configuration changes.

The design does not grant passwordless sudo to `wedge`, add it to `wheel`, or
expose a general-purpose privileged shell wrapper.

## Seeded configuration and operator workflow

The seeding service will copy `agent-harness.nix` into `/etc/nixos` alongside
the existing flake and modules. The guest flake will pass its pinned nix-agent
input to that module. The initial boot and every later switch will consequently
resolve the same package revision and privilege policy.

The runbook will remove the manual `nix profile install` step. It will instead
instruct the operator to configure the coding agent's MCP server command as
`/run/wrappers/bin/nix-agent-mcp`. Before the stopwatch starts, the operator
will run the automated health check or equivalent MCP initialization check.
Failure to start the pinned server is a harness failure, not a measured task
failure.

The protocol and runbook will state the boundary consistently: unprivileged
editing is allowed, privileged system changes must use nix-agent, and direct
sudo is unavailable.

## Automated verification

The baseline VM flake will expose a NixOS VM check dedicated to the privilege
boundary. The check will boot a clean guest and verify all of the following as
`wedge`:

1. Group membership does not include `wheel`.
2. `sudo -n true` fails.
3. `/run/wrappers/bin/sudo -n true` fails, so an absolute wrapper path does not
   bypass the policy.
4. Root password authentication and root SSH login are unavailable.
5. Direct system profile mutation and direct activation fail without root.
6. `/run/wrappers/bin/nix-agent-mcp` starts the pinned MCP server with effective
   UID 0 and `/etc/nixos#baseline` as its default target.
7. A real stdio MCP client can call nix-agent's `switch` tool successfully and
   the guest reports the expected current system generation afterward.

The positive test must use the MCP protocol rather than invoking
`nixos-rebuild` through the wrapper or calling nix-agent's Python functions
directly. This proves the same entry point the coding agent will receive.

The negative activation check will target the resolved
`switch-to-configuration` program directly as `wedge`. It must fail before the
positive MCP switch is attempted. The test will also assert that the wrapper's
launcher references the nix-agent package from the pinned flake input by
absolute store path, preventing a PATH-provided replacement from satisfying the
check.

## Documentation and result handling

`eval/baseline/RUNBOOK.md` and `eval/baseline/PROTOCOL.md` will be updated in
the same logical change as the harness. They will record the exact nix-agent
revision and explain that the previous passwordless-wheel arrangement is not
part of a valid run.

The invalid first-run artifacts remain labeled invalid and are not promoted to
baseline results. After the implementation passes the project test matrix and
the new VM check, the baseline will be rerun from a clean disk. Human-only
metrics will be scored from that new transcript, then the two-arm comparison
will be regenerated.

## Verification sequence

Implementation acceptance requires:

1. Focused tests for the new module and privilege-boundary VM check.
2. Existing Python unit tests, Ruff, and Pyright.
3. Existing opt-in Nix evaluation and live resolver tests.
4. `nix flake check -L`, including all existing VM checks and the new boundary
   check.
5. A clean-disk baseline run using the pinned MCP entry point.

Passing automated checks establishes harness correctness. It does not replace
the human baseline run or its subjective scoring.
