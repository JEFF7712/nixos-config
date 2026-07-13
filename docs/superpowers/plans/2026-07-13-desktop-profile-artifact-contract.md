# Desktop Profile Artifact Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the implicit desktop-profile runtime interface with one strictly validated, versioned `manifest.json` consumed through a focused shell interface.

**Architecture:** A new Nix artifact compiler emits each profile manifest and its referenced files. A small shell manifest module validates and reads that contract; all runtime consumers migrate to it in one cutover, while mutable active and wallpaper-derived state remains outside compiled profile directories.

**Tech Stack:** Nix, Home Manager, Bash, jq, Bats-style repository shell fixtures, just

---

## File Structure

- Create `lib/desktop-profiles/artifact.nix`: compile profile metadata, variants, adapters, and artifact references into `manifest.json` plus rendered files.
- Modify `lib/desktop-profiles/files.nix`: retain focused rendering helpers and export the rendered-file set needed by the artifact compiler.
- Modify `modules/home-manager/desktop-profiles.nix`: call the artifact compiler and keep Home Manager activation aligned with the new generated file set.
- Create `home/scripts/profile-manifest`: strict schema validation and typed accessors for runtime scripts.
- Modify `home/scripts/profile-common`: source the interface and make shared adapter helpers consume manifest data.
- Modify runtime readers: `profile-transition`, `switch-profile`, `switch-bar`, `random-wallpaper`, `lock-screen`, `generate-previews`, and `select-quickshell-theme`.
- Modify `modules/home-manager/common-apps.nix`: consume active manifest adapter data during activation.
- Modify `checks/profiles.nix`: validate the complete compiled contract.
- Create `checks/profile-manifest.bash`: exercise strict runtime validation and typed accessors.
- Modify `checks/profile-transition.bash`, `checks/wallpaper-scripts.bash`, and `checks/spicetify-theme.bash`: use compiled-manifest-shaped fixtures and cover failure behavior.
- Modify `checks/agent-invariants.bash`: reject legacy artifact generation and direct manifest reads outside the interface and tests.
- Modify `justfile`: register the focused manifest check.

### Task 1: Compile a Versioned Manifest

**Files:**
- Create: `lib/desktop-profiles/artifact.nix`
- Modify: `lib/desktop-profiles/files.nix`
- Modify: `modules/home-manager/desktop-profiles.nix`
- Test: `checks/profiles.nix`

- [ ] **Step 1: Make the evaluation check require the new contract**

Update `checks/profiles.nix` so each generated profile must have `manifest.json`, `schemaVersion == 1`, a matching `name`, a `dark` variant, and no legacy public files:

```nix
manifestText = pf."manifest.json" or (builtins.throw "profile '${name}': no manifest.json rendered");
manifest = builtins.fromJSON manifestText;
legacy = builtins.filter (file: pf ? ${file}) [
  "meta.json"
  "runtime.json"
  "wallpaper-dir"
  "wallpaper-dir-light"
];
```

Retain the existing Niri, Vicinae, Quickshell, and non-empty color checks, but obtain self-themed and variant information from `manifest`.

- [ ] **Step 2: Run the profile check and verify RED**

Run: `just check-profiles`

Expected: failure containing `no manifest.json rendered`.

- [ ] **Step 3: Export rendered files separately from their contract**

In `lib/desktop-profiles/files.nix`, rename the current generator to `renderProfileFiles` and export it with `hasLight`, `runtimeFor`, and `generateNiriOverrides`. Do not generate `meta.json`, `runtime.json`, or wallpaper path files from this module.

- [ ] **Step 4: Add the artifact compiler**

Create `lib/desktop-profiles/artifact.nix` with this interface:

```nix
{
  lib,
  profileFiles,
}:
let
  adapterValues = runtime: variant:
    lib.filterAttrs (_: value: value != null) (
      lib.mapAttrs (_: values: values.${variant} or values.dark or null) runtime
    );

  variantArtifacts = light: {
    gtk3 = if light then "gtk-3.0-light.css" else "gtk-3.0.css";
    gtk4 = if light then "gtk-4.0-light.css" else "gtk-4.0.css";
    qt6 = if light then "qt6ct-light.conf" else "qt6ct.conf";
    kitty = if light then "kitty-colors-light.conf" else "kitty-colors.conf";
    fish = if light then "fish-theme-light.fish" else "fish-theme.fish";
    starship = if light then "starship-light.toml" else "starship.toml";
    rofi = if light then "rofi-theme-light.rasi" else "rofi-theme.rasi";
    btop = if light then "btop-light.theme" else "btop.theme";
    tmux = if light then "tmux-colors-light.conf" else "tmux-colors.conf";
    hyprlock = if light then "hyprlock-colors-light.conf" else "hyprlock-colors.conf";
    cava = if light then "cava-colors-light" else "cava-colors";
    vicinae = if light then "vicinae-theme-light.toml" else "vicinae-theme-dark.toml";
  };
in
{
  compile = name: profile:
    let
      rendered = profileFiles.renderProfileFiles name profile;
      runtime = profileFiles.runtimeFor name profile;
      dark = {
        wallpaperDirectory = profile.wallpaperDir;
        adapters = adapterValues runtime "dark";
        artifacts = variantArtifacts false;
      };
      light = {
        wallpaperDirectory =
          if profile.wallpaperDirLight != null then profile.wallpaperDirLight else profile.wallpaperDir;
        adapters = adapterValues runtime "light";
        artifacts = variantArtifacts true;
      };
      manifest = {
        schemaVersion = 1;
        inherit name;
        capabilities = {
          inherit (profile)
            selfThemed wallpaperTheming colorEngine matugenScheme
            wallpaperAccentVivid obsidianWallpaperTheme;
        };
        transition = {
          defaultBar = profile.bar;
          cursor = { inherit (profile.cursor) theme size; };
          inherit (profile) fonts appearance;
        };
        variants = { inherit dark; } // lib.optionalAttrs (profileFiles.hasLight profile) { inherit light; };
        artifacts = {
          niri = {
            default = "niri-overrides.kdl";
            focus = "niri-overrides-focus.kdl";
          };
        }
        // lib.optionalAttrs (profile.quickshellTheme != null || profile.quickshellThemeLight != null) {
          quickshell =
            lib.optionalAttrs (profile.quickshellTheme != null) { dark = "quickshell-theme.json"; }
            // lib.optionalAttrs (profile.quickshellThemeLight != null) { light = "quickshell-theme-light.json"; };
        }
        // lib.optionalAttrs (profile.waybar.config != null) {
          waybar = {
            config = "waybar-config.jsonc";
            dark = "waybar-style.css";
          }
          // lib.optionalAttrs (profileFiles.hasLight profile) {
            light = if profile.waybarLight.style != null then "waybar-style-light.css" else "waybar-style.css";
          };
        }
        // lib.optionalAttrs (profile.makoConfig != null || profile.makoConfigLight != null) {
          mako =
            lib.optionalAttrs (profile.makoConfig != null) { dark = "mako-config"; }
            // lib.optionalAttrs (profile.makoConfigLight != null) { light = "mako-config-light"; }
            // lib.optionalAttrs (profileFiles.hasLight profile && profile.makoConfigLight == null && profile.makoConfig != null) {
              light = "mako-config";
            };
        };
      };
    in
    rendered // {
      ".config/desktop-profiles/${name}/manifest.json".text = builtins.toJSON manifest;
    };
}
```

Adapter defaults from `runtimeFor` belong under `variants.<variant>.adapters`. Artifact references must be relative filenames and must cover every rendered file used at runtime.

- [ ] **Step 5: Wire Home Manager to the compiler**

Import `artifact.nix` in `modules/home-manager/desktop-profiles.nix` and replace `profileFiles.generateProfileFiles` with `profileArtifact.compile`.

- [ ] **Step 6: Run the profile check and verify GREEN**

Run: `just check-profiles && just fmt-check`

Expected: nine profiles, `ok = true`, and no formatting changes.

- [ ] **Step 7: Commit**

```bash
git add checks/profiles.nix lib/desktop-profiles/artifact.nix lib/desktop-profiles/files.nix modules/home-manager/desktop-profiles.nix
git commit -m "Compile versioned desktop profile artifacts."
```

### Task 2: Add the Strict Runtime Manifest Interface

**Files:**
- Create: `home/scripts/profile-manifest`
- Create: `checks/profile-manifest.bash`
- Modify: `home/scripts/profile-common`
- Modify: `justfile`

- [ ] **Step 1: Write failing interface tests**

Create fixtures for a valid dark-only manifest and a valid dark/light manifest. Test these commands or sourced functions:

```bash
profile_manifest_validate sharp dark
profile_manifest_has_variant sharp light
profile_manifest_bar sharp
profile_manifest_capability sharp selfThemed
profile_manifest_wallpaper_dir sharp dark
profile_manifest_artifact sharp dark niri.default
profile_manifest_adapter sharp dark spicetify
```

Also assert rejection of missing manifests, invalid JSON, missing/non-integer/unsupported versions, name mismatch, missing variants, absolute artifact paths, `..` traversal, and missing referenced files.

- [ ] **Step 2: Run the focused check and verify RED**

Run: `bash checks/profile-manifest.bash`

Expected: failure because `home/scripts/profile-manifest` does not exist.

- [ ] **Step 3: Implement strict validation and accessors**

Create a sourceable Bash module with:

```bash
PROFILE_MANIFEST_SCHEMA=1
PROFILES_DIR="${PROFILES_DIR:-$HOME/.config/desktop-profiles}"

profile_manifest_path() { printf '%s/%s/manifest.json\n' "$PROFILES_DIR" "$1"; }

_profile_manifest_jq() {
  local profile="$1"
  shift
  jq -er "$@" "$(profile_manifest_path "$profile")"
}

profile_manifest_validate() {
  local profile="$1" variant="${2:-}" manifest profile_dir relative resolved
  manifest=$(profile_manifest_path "$profile")
  profile_dir="$PROFILES_DIR/$profile"
  [ -f "$manifest" ] || { printf 'Error: profile %s has no manifest.json.\n' "$profile" >&2; return 1; }
  jq -e --arg profile "$profile" --argjson schema "$PROFILE_MANIFEST_SCHEMA" '
    .schemaVersion == $schema
    and .name == $profile
    and (.capabilities | type == "object")
    and (.transition | type == "object")
    and (.variants.dark | type == "object")
    and (.artifacts | type == "object")
  ' "$manifest" >/dev/null || {
    printf 'Error: profile %s has an invalid version-1 manifest.\n' "$profile" >&2
    return 1
  }
  if [ -n "$variant" ]; then
    profile_manifest_has_variant "$profile" "$variant" || {
      printf 'Error: profile %s has no %s variant.\n' "$profile" "$variant" >&2
      return 1
    }
  fi
  while IFS= read -r relative; do
    case "$relative" in
      /* | .. | ../* | */../* | */..) return 1 ;;
    esac
    resolved=$(realpath -m -- "$profile_dir/$relative")
    case "$resolved" in "$profile_dir"/*) ;; *) return 1 ;; esac
    [ -f "$resolved" ] || return 1
  done < <(jq -r '[.artifacts, (.variants[] | .artifacts)] | .. | strings' "$manifest")
}

profile_manifest_has_variant() {
  _profile_manifest_jq "$1" --arg variant "$2" '.variants | has($variant)' >/dev/null
}

profile_manifest_bar() {
  _profile_manifest_jq "$1" '.transition.defaultBar'
}

profile_manifest_capability() {
  _profile_manifest_jq "$1" --arg key "$2" '.capabilities[$key]'
}

profile_manifest_transition_json() {
  _profile_manifest_jq "$1" --arg key "$2" '.transition[$key]'
}

profile_manifest_wallpaper_dir() {
  _profile_manifest_jq "$1" --arg variant "$2" '.variants[$variant].wallpaperDirectory'
}

profile_manifest_artifact() {
  local profile="$1" variant="$2" key="$3" relative
  relative=$(_profile_manifest_jq "$profile" --arg variant "$variant" --arg key "$key" '
    (.variants[$variant].artifacts | getpath($key | split(".")))
    // (.artifacts | getpath($key | split(".")))
  ')
  printf '%s/%s/%s\n' "$PROFILES_DIR" "$profile" "$relative"
}

profile_manifest_adapter() {
  _profile_manifest_jq "$1" --arg variant "$2" --arg adapter "$3" \
    '.variants[$variant].adapters[$adapter] // empty'
}

profile_manifest_variants() {
  _profile_manifest_jq "$1" '.variants | keys[]'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  operation="${1:-}"
  shift || true
  case "$operation" in
    validate) profile_manifest_validate "$@" ;;
    has-variant) profile_manifest_has_variant "$@" ;;
    bar) profile_manifest_bar "$@" ;;
    capability) profile_manifest_capability "$@" ;;
    transition) profile_manifest_transition_json "$@" ;;
    wallpaper-dir) profile_manifest_wallpaper_dir "$@" ;;
    artifact) profile_manifest_artifact "$@" ;;
    adapter) profile_manifest_adapter "$@" ;;
    variants) profile_manifest_variants "$@" ;;
    *) printf 'Usage: profile-manifest OPERATION PROFILE [ARGUMENTS...]\n' >&2; exit 2 ;;
  esac
fi
```

Validation must use `jq -e`, emit field-specific errors, confirm the requested variant, canonicalize each referenced artifact against the profile directory, and reject any resolved path outside it. Required referenced files must exist; files expected to carry configuration must be non-empty.

- [ ] **Step 4: Source the interface from `profile-common`**

Resolve it from the same script directory and source it after defining `PROFILES_DIR`. No other runtime script should need to locate the module independently.

- [ ] **Step 5: Register and pass the focused check**

Add `bash checks/profile-manifest.bash` to `wallpaper-script-check`, then run:

`bash checks/profile-manifest.bash && just shell-check`

Expected: `profile manifest checks passed` and ShellCheck exit 0.

- [ ] **Step 6: Commit**

```bash
git add home/scripts/profile-manifest home/scripts/profile-common checks/profile-manifest.bash justfile
git commit -m "Add strict desktop profile manifest interface."
```

### Task 3: Validate Before Profile Mutation

**Files:**
- Modify: `home/scripts/profile-transition`
- Modify: `home/scripts/switch-profile`
- Modify: `checks/profile-transition.bash`

- [ ] **Step 1: Replace hand-written legacy fixtures with manifest fixtures**

Change the fixture builder to write version-1 manifests with actual transition, variant, adapter, and artifact keys. Add cases that record bar/process/file mutation commands and then invoke a transition with an invalid version or missing artifact.

Assert the command fails and the mutation log stays empty.

- [ ] **Step 2: Run transition checks and verify RED**

Run: `bash checks/profile-transition.bash`

Expected: failure because the transition still reads `meta.json`, `runtime.json`, and wallpaper path files.

- [ ] **Step 3: Migrate transition resolution under the lock**

Use the interface to validate the target before creating the transaction directory, staging files, or stopping bars:

```bash
profile_manifest_validate "$TARGET" "$TARGET_VARIANT"
TARGET_SELF_THEMED=$(profile_manifest_capability "$TARGET" selfThemed)
TARGET_WALLPAPER_DIR=$(profile_manifest_wallpaper_dir "$TARGET" "$TARGET_VARIANT")
TARGET_BAR=$(profile_bar "$TARGET")
```

Replace `TARGET_RUNTIME` with the target profile name plus selected variant. Resolve Niri, Waybar, Mako, Quickshell, and core theme files through `profile_manifest_artifact` rather than hard-coded profile filenames.

Startup may replace an invalid remembered target with `noctalia` only after `noctalia` validates. Ordinary switch, variant, and reapply modes fail closed.

- [ ] **Step 4: Migrate status output**

Use manifest accessors for self-themed status, wallpaper directory, bar defaults, and expected Niri artifact paths.

- [ ] **Step 5: Run transition checks and verify GREEN**

Run: `bash checks/profile-transition.bash && just shell-check`

Expected: all transition scenarios pass, including validation-before-mutation.

- [ ] **Step 6: Commit**

```bash
git add home/scripts/profile-transition home/scripts/switch-profile checks/profile-transition.bash
git commit -m "Route profile transitions through manifests."
```

### Task 4: Migrate Wallpaper, Bar, Lock, and Preview Readers

**Files:**
- Modify: `home/scripts/profile-common`
- Modify: `home/scripts/random-wallpaper`
- Modify: `home/scripts/switch-bar`
- Modify: `home/scripts/lock-screen`
- Modify: `home/scripts/generate-previews`
- Modify: `home/scripts/select-quickshell-theme`
- Modify: `checks/wallpaper-scripts.bash`

- [ ] **Step 1: Convert wallpaper fixtures to manifests**

Replace `meta.json`, `runtime.json`, and wallpaper path fixture creation with one valid manifest. Assert wallpaper selection reads the variant directory, bar defaults come from `transition.defaultBar`, and wallpaper theming reads capability and adapter settings from the selected variant.

- [ ] **Step 2: Run wallpaper checks and verify RED**

Run: `bash checks/wallpaper-scripts.bash`

Expected: failure from a remaining legacy reader.

- [ ] **Step 3: Migrate shared and standalone readers**

Replace every compiled-profile `jq` or `cat` read with the typed interface. Specifically migrate:

- `profile_wallpaper_theming`, color engine, Matugen scheme, vivid accent, and Obsidian capability reads
- `profile_bar`
- random-wallpaper and lock-screen variant directory selection
- switch-bar default and artifact availability checks
- generate-previews self-themed selection
- Quickshell static-theme selection through the manifest artifact reference
- application adapter reads currently passed a `runtime.json` path

Keep root-level mutable runtime theme files unchanged.

- [ ] **Step 4: Run focused checks and verify GREEN**

Run: `bash checks/wallpaper-scripts.bash && bash checks/spicetify-theme.bash && just shell-check`

Expected: all focused runtime checks pass.

- [ ] **Step 5: Commit**

```bash
git add home/scripts/profile-common home/scripts/random-wallpaper home/scripts/switch-bar home/scripts/lock-screen home/scripts/generate-previews home/scripts/select-quickshell-theme checks/wallpaper-scripts.bash checks/spicetify-theme.bash
git commit -m "Migrate profile runtime readers to manifests."
```

### Task 5: Migrate Home Manager Activation and Remove Legacy Artifacts

**Files:**
- Modify: `modules/home-manager/common-apps.nix`
- Modify: `modules/home-manager/desktop-profiles.nix`
- Modify: `checks/agent-invariants.bash`
- Modify: `checks/agent-workflows.bash`

- [ ] **Step 1: Add a failing legacy-read invariant**

Extend the invariant checker to reject `meta.json`, `runtime.json`, `wallpaper-dir`, and `wallpaper-dir-light` under profile compiler and runtime-reader paths. Also reject direct `jq` reads of `manifest.json` outside `home/scripts/profile-manifest`, Nix compiler/validation code, and test fixtures.

- [ ] **Step 2: Run the workflow check and verify RED**

Run: `just check-agent-workflows`

Expected: findings list the remaining Home Manager legacy reader or generator.

- [ ] **Step 3: Migrate activation reads**

Update `modules/home-manager/common-apps.nix` activation logic to invoke the installed manifest interface for the active profile and variant. Remove its old string-form runtime compatibility path.

Ensure `initDesktopProfiles` removes obsolete managed legacy files from profile directories during the cutover while preserving root-level mutable state.

- [ ] **Step 4: Pass the invariant and confirm generated output**

Run:

```bash
just check-agent-workflows
just check-profiles
nix eval --json .#nixosConfigurations.laptop.config.home-manager.users.rupan.home.file \
  --apply 'files: builtins.filter (name: builtins.match ".*desktop-profiles/.*/(meta.json|runtime.json|wallpaper-dir|wallpaper-dir-light)" name != null) (builtins.attrNames files)'
```

Expected: workflow check passes, profile check reports nine valid profiles, and the final command returns `[]`.

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/common-apps.nix modules/home-manager/desktop-profiles.nix checks/agent-invariants.bash checks/agent-workflows.bash
git commit -m "Remove legacy desktop profile artifacts."
```

### Task 6: Surface Adapter Failure Diagnostics

**Files:**
- Modify: `home/scripts/profile-transition`
- Modify: `checks/profile-transition.bash`

- [ ] **Step 1: Add diagnostic regression cases**

Make one adapter emit `gsettings: schema unavailable` to stderr and fail. Assert the summary includes both `system-preferences` and that first line, a later adapter still runs, and a detailed log path exists only when output has additional lines.

- [ ] **Step 2: Run the transition check and verify RED**

Run: `bash checks/profile-transition.bash`

Expected: failure because current adapter stderr is not captured or reported.

- [ ] **Step 3: Implement per-adapter capture**

Capture stderr separately for each adapter. Append the adapter and first non-empty diagnostic line to the summary. When more diagnostic lines exist, atomically install the complete capture beneath `${XDG_STATE_HOME:-$HOME/.local/state}/desktop-profiles/adapter-errors/` with mode 600 and include its path. Delete successful and single-line temporary captures.

- [ ] **Step 4: Run transition checks and verify GREEN**

Run: `bash checks/profile-transition.bash && just shell-check`

Expected: diagnostic cases and all existing rollback/adapter isolation cases pass.

- [ ] **Step 5: Commit**

```bash
git add home/scripts/profile-transition checks/profile-transition.bash
git commit -m "Report desktop profile adapter diagnostics."
```

### Task 7: Full Verification and Activation

**Files:**
- Verify all changed files

- [ ] **Step 1: Run the focused gates**

```bash
just check-profiles
just wallpaper-script-check
just shell-check
just fmt-check
```

Expected: every command exits 0.

- [ ] **Step 2: Run the broad gate**

Run: `just check`

Expected: all flake checks, three host evaluations, nine profile validations, and `git diff --check` pass. Existing Xorg rename and ISO ZFS warnings are allowed.

- [ ] **Step 3: Realize the laptop closure**

Run: `just build laptop`

Expected: the laptop toplevel builds successfully.

- [ ] **Step 4: Review the final migration surface**

```bash
rg -n 'meta\.json|runtime\.json|wallpaper-dir-light|wallpaper-dir' \
  home/scripts modules/home-manager lib/desktop-profiles \
  --glob '!profile-manifest'
git diff --check
git status --short
```

Expected: no legacy compiled-profile readers or generators, no whitespace errors, and only intentional changes.

- [ ] **Step 5: Activate once**

Run: `just switch`

Expected: activation succeeds and installs `manifest.json` for every profile while removing the four obsolete files.

- [ ] **Step 6: Verify live transitions**

```bash
switch-profile gruvbox
toggle-variant light
switch-profile sharp
switch-profile --status
```

Expected: all commands exit 0 with no contract or adapter warnings; the final status reports `sharp`, dark variant, valid Niri override, bar, and wallpaper directory.

- [ ] **Step 7: Commit any verification-only corrections separately**

If verification required code changes, repeat the failing focused test first, commit only those corrected files, and rerun Steps 1 through 6. If no corrections were required, do not create an empty commit.
