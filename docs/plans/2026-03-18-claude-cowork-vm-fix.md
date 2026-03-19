# Claude Cowork VM Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Claude Desktop cowork start its local VM service successfully on this NixOS system.

**Architecture:** First prove the current failure point by tracing the installed `claude-desktop-fhs` launcher, cowork logs, and the VM service subprocess path. Then patch the Nix-managed package setup so the launcher has the exact binaries, libraries, and environment it needs. Keep the fix local to the repo through a module or overlay override so rebuilds remain reproducible.

**Tech Stack:** Nix flakes, NixOS, Home Manager, Electron app packaging, FHS wrappers, KVM/QEMU runtime

---

### Task 1: Capture the exact cowork VM launch failure

**Files:**
- Verify: `modules/home-manager/ai-tools.nix`
- Verify: `flake.nix`
- Create: `docs/plans/2026-03-18-claude-cowork-debug-notes.md`

**Step 1: Write the failing check**

Confirm the current observed failure is still `VM service not running` after the VM bundle has already downloaded successfully.

**Step 2: Run check to verify the gap**

Run: `grep -R "VM service not running\|COWORK_VM\|claudevm.bundle" ~/.config/Claude ~/.config/claude-desktop 2>/dev/null`
Expected: matches showing the cowork bundle is ready and the VM service still fails to start.

**Step 3: Write minimal implementation**

Create `docs/plans/2026-03-18-claude-cowork-debug-notes.md` and record:

- the failing log lines,
- the location of the installed Claude Desktop wrapper,
- the location of the extracted cowork VM bundle,
- any service or subprocess path mentioned by the logs.

Use this template:

```md
# Claude Cowork Debug Notes

## Current failure
- `VM service not running`

## Known-good prerequisites
- `/dev/kvm` exists
- user is in `kvm`
- VM bundle downloaded and checksum validated

## Next artifact to inspect
- launcher path: ...
- subprocess path: ...
```

**Step 4: Run check to verify it passes**

Run: `test -f docs/plans/2026-03-18-claude-cowork-debug-notes.md`
Expected: zero exit status.

### Task 2: Identify the actual VM service launcher path

**Files:**
- Verify: `modules/home-manager/ai-tools.nix`
- Verify: `flake.nix`
- Update: `docs/plans/2026-03-18-claude-cowork-debug-notes.md`

**Step 1: Write the failing check**

Confirm the launcher path is not yet documented.

**Step 2: Run check to verify the gap**

Run: `which claude-desktop || which claude-desktop-fhs || true`
Expected: wrapper path or no direct binary alias, requiring inspection through the Nix store package.

**Step 3: Write minimal implementation**

Inspect the installed package and wrapper to find the cowork-related executable path.

Run these commands one at a time and record findings in the debug notes:

```bash
readlink -f ~/.nix-profile/bin/claude-desktop
readlink -f ~/.nix-profile/bin/claude-desktop-fhs
ls -R ~/.nix-profile | grep claude
```

Then inspect the resolved wrapper or package for cowork strings:

```bash
strings <resolved-wrapper-or-binary> | grep -i "cowork\|claudevm\|qemu\|virtiofs\|initrd"
```

Document the launcher path and any referenced helper binary or script.

**Step 4: Run check to verify it passes**

Run: `grep -n "launcher path\|subprocess path" docs/plans/2026-03-18-claude-cowork-debug-notes.md`
Expected: at least one documented path.

### Task 3: Prove the missing runtime dependency

**Files:**
- Update: `docs/plans/2026-03-18-claude-cowork-debug-notes.md`

**Step 1: Write the failing check**

Assume the cowork launcher still fails outside the app because one or more runtime dependencies are unavailable.

**Step 2: Run check to verify the gap**

Run the smallest safe inspection commands against the discovered launcher or helper:

```bash
ldd <launcher-or-helper-path>
file <launcher-or-helper-path>
```

If it is a shell script, inspect its interpreter and invoked commands:

```bash
sed -n '1,200p' <launcher-or-helper-path>
```

Expected: one of these reveals a missing library, missing interpreter, missing command, or an invalid hard-coded path.

**Step 3: Write minimal implementation**

Record the exact missing dependency in the debug notes using this format:

```md
## Root cause hypothesis
- launcher: ...
- failure: ...
- missing dependency: ...
- why this matches the app log: ...
```

**Step 4: Run check to verify it passes**

Run: `grep -n "Root cause hypothesis\|missing dependency" docs/plans/2026-03-18-claude-cowork-debug-notes.md`
Expected: documented hypothesis tied to concrete evidence.

### Task 4: Add a Nix-managed package override for Claude Desktop

**Files:**
- Create: `overlays/claude-desktop-cowork.nix`
- Modify: `flake.nix`
- Modify: `modules/home-manager/ai-tools.nix`

**Step 1: Write the failing check**

Confirm there is no local cowork-specific Claude Desktop override yet.

**Step 2: Run check to verify the gap**

Run: `test -f overlays/claude-desktop-cowork.nix`
Expected: non-zero exit status.

**Step 3: Write minimal implementation**

Create `overlays/claude-desktop-cowork.nix` with the smallest override that matches the proven root cause. The exact shape depends on Task 3, but it should follow one of these patterns:

```nix
final: prev: {
  claude-desktop-fhs = prev.claude-desktop-fhs.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [ final.stdenv.cc.cc ];
    runtimeDependencies = (old.runtimeDependencies or []) ++ [ final.qemu_kvm final.virtiofsd ];
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/claude-desktop \
        --prefix PATH : ${final.lib.makeBinPath [ final.qemu_kvm final.virtiofsd final.bash ]} \
        --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.stdenv.cc.cc final.zlib final.glib ]}
    '';
  });
}
```

If the upstream package name or wrapper entrypoint differs, adapt the override to the discovered package shape rather than forcing this example literally.

Wire the overlay into `flake.nix` after the upstream Claude Desktop overlay so the local override wins.

If `modules/home-manager/ai-tools.nix` references a package name that changes due to the override, update it there.

**Step 4: Run check to verify it passes**

Run: `nix eval .#nixosConfigurations.laptop.config.home-manager.users.rupan.home.packages --apply builtins.length`
Expected: evaluation succeeds.

### Task 5: Build and inspect the patched package

**Files:**
- Verify: `overlays/claude-desktop-cowork.nix`
- Verify: `flake.nix`
- Verify: `modules/home-manager/ai-tools.nix`

**Step 1: Build the package**

Run: `nix build .#nixosConfigurations.laptop.config.home-manager.users.rupan.home.packages`
Expected: evaluation/build completes far enough to prove the override is valid, or fails with a concrete Nix packaging error to fix.

**Step 2: Verify wrapper content**

Locate the built Claude Desktop binary and confirm the expected PATH and library injection are present.

Run: `readlink -f result && ls result`
Expected: a build output path containing the patched package or package set.

**Step 3: Verify dependency visibility**

Run these checks against the patched launcher or helper path:

```bash
ldd <patched-launcher-or-helper-path>
strings <patched-launcher-or-helper-path> | grep -i "qemu\|virtiofs\|claudevm"
```

Expected: no missing library lines for the proven root cause dependency.

### Task 6: Rebuild and verify cowork end-to-end

**Files:**
- Verify: `hosts/laptop/configuration.nix`
- Verify: `modules/home-manager/ai-tools.nix`
- Verify: `overlays/claude-desktop-cowork.nix`
- Verify: `docs/plans/2026-03-18-claude-cowork-debug-notes.md`

**Step 1: Apply the config**

Run: `home-manager switch --flake .#rupan@laptop` or, if this repo expects full system application for package visibility, `sudo nixos-rebuild switch --flake .#laptop`
Expected: the patched Claude Desktop package is installed into the active profile.

**Step 2: Launch Claude Desktop from a terminal**

Run: `claude-desktop 2>&1 | tee /tmp/claude-desktop-cowork.log`
Expected: the app launches and cowork no longer logs `VM service not running` when triggered.

**Step 3: Trigger cowork and capture result**

Use Claude Desktop to start cowork, then inspect logs:

Run: `grep -E "VM service not running|COWORK_VM|guest connected|ready|listening" /tmp/claude-desktop-cowork.log ~/.config/Claude/* 2>/dev/null`
Expected: either a ready/connected signal or a new narrower error instead of the original startup failure.

**Step 4: Update notes**

Record the final root cause and fix in `docs/plans/2026-03-18-claude-cowork-debug-notes.md`.

### Task 7: Commit when explicitly requested

**Files:**
- Add: `docs/plans/2026-03-18-claude-cowork-design.md`
- Add: `docs/plans/2026-03-18-claude-cowork-vm-fix.md`
- Add: `docs/plans/2026-03-18-claude-cowork-debug-notes.md`
- Add: `overlays/claude-desktop-cowork.nix`
- Modify: `flake.nix`
- Modify: `modules/home-manager/ai-tools.nix`

**Step 1: Prepare staged files**

```bash
git add docs/plans/2026-03-18-claude-cowork-design.md docs/plans/2026-03-18-claude-cowork-vm-fix.md docs/plans/2026-03-18-claude-cowork-debug-notes.md overlays/claude-desktop-cowork.nix flake.nix modules/home-manager/ai-tools.nix
```

**Step 2: Commit only if explicitly requested**

```bash
git commit -m "fix: make claude cowork VM start on nixos"
```

Only do this if a commit is explicitly requested.
