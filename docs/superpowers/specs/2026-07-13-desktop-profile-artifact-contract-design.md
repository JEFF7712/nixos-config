# Desktop Profile Artifact Contract Design

## Goal

Compile each desktop profile into one strict, versioned artifact contract that every runtime reader consumes. Eliminate the implicit interface spread across `meta.json`, `runtime.json`, wallpaper path files, generated theme files, and fallback-heavy shell expressions.

## Scope

This change covers the generated profile interface and every in-repository consumer of it:

- Nix profile compilation and evaluation-time validation
- profile and variant transitions
- wallpaper selection and wallpaper-derived theming
- bar selection, lock-screen wallpaper selection, and preview generation
- application theme adapters
- Home Manager activation logic that reads the active profile
- profile, transition, wallpaper, and adapter regression tests

It does not change the profile option interface in `modules/home-manager/profiles/`, the active-state transaction model, or the formats consumed by external applications.

## Contract Boundary

`lib/desktop-profiles/artifact.nix` is the compiler seam. It accepts a profile name and a profile value already checked by the Home Manager option type. It returns the complete `home.file` fragment for that profile, including a `manifest.json` and every referenced generated artifact.

The compiler owns:

- translating Nix profile values into the runtime manifest
- merging adapter defaults with profile-specific adapter configuration
- assigning stable relative paths to generated artifacts
- representing dark and light variants consistently
- evaluation-time contract validation

Theme renderers may remain focused helper modules. They do not define the runtime interface independently.

## Manifest Version

The initial contract version is integer `1` under the required top-level key `schemaVersion`.

Runtime readers support exactly version 1. A missing, non-integer, or unsupported version is an error. There is no versionless interpretation, compatibility mode, or fallback to legacy files.

Future incompatible changes must add a new version and deliberately update both the compiler and runtime interface. Supporting multiple versions is not required until a real compatibility requirement exists.

## Manifest Shape

Every `.config/desktop-profiles/<name>/manifest.json` has this logical structure:

```json
{
  "schemaVersion": 1,
  "name": "sharp",
  "capabilities": {
    "selfThemed": false,
    "wallpaperTheming": true,
    "colorEngine": "matugen",
    "matugenScheme": "scheme-monochrome",
    "wallpaperAccentVivid": true,
    "obsidianWallpaperTheme": false
  },
  "transition": {
    "defaultBar": "quickshell",
    "cursor": { "theme": "Bibata-Modern-Ice", "size": 24 },
    "fonts": {},
    "appearance": {}
  },
  "variants": {
    "dark": {
      "wallpaperDirectory": "/home/rupan/nixos-assets/wallpapers/sharp",
      "adapters": {}
    },
    "light": {
      "wallpaperDirectory": "/home/rupan/nixos-assets/wallpapers/sharp-light",
      "adapters": {}
    }
  },
  "artifacts": {
    "niri": {
      "default": "niri-overrides.kdl",
      "focus": "niri-overrides-focus.kdl"
    },
    "quickshell": {
      "dark": "quickshell-theme.json",
      "light": "quickshell-theme-light.json"
    }
  }
}
```

The concrete compiler may add artifact keys for GTK, Qt, Kitty, Fish, Starship, Rofi, btop, tmux, Hyprlock, Cava, Waybar, Mako, and Vicinae. Every path is relative to the profile directory, contains no parent traversal, and names a generated file in the same compiled artifact.

The `light` variant is absent when a profile has no light variant. Consumers determine support by testing the variant key, not a separate boolean.

Adapter configuration is nested under each variant. This replaces the static data currently named `runtime.json`; it is immutable compiled configuration, not runtime state.

## Mutable Runtime State

Mutable state remains outside profile artifact directories and is not represented as compiled configuration:

- `active` and `active-variant`
- `variant-<profile>` preference files
- `bar-<profile>` overrides
- active Niri links and wallpaper-derived Niri output
- wallpaper-derived Quickshell, Cava, and Spicetify files
- runtime theme ownership tags

This separation prevents Home Manager activation from overwriting live derived state and keeps the manifest immutable.

## Runtime Interface

A focused shell module provides the only supported manifest-reading interface. It exposes operations for:

- locating a profile manifest
- validating schema version, profile identity, variants, required fields, and artifact paths
- reading required scalar values without silent defaults
- reading optional adapter values
- resolving a variant and its artifact path
- listing supported variants

Consumers source or invoke this interface instead of directly querying `manifest.json`. Direct `jq` reads of compiled profile manifests outside the interface are prohibited by a repository check.

Mutable state access remains in the transition or profile-state helpers because it is not part of the compiled artifact contract.

## Transition Behavior

The transition engine resolves the target profile and variant under its existing lock. Before staging files or stopping a bar, it validates:

- the manifest exists and parses
- `schemaVersion` is exactly 1
- `name` matches the containing profile directory
- the requested variant exists
- required transition fields have valid types and values
- every artifact required by the selected bar and variant exists, is a regular non-empty file where appropriate, and resolves inside the profile directory

A validation failure exits before core mutation and reports the profile, manifest field, and reason. Startup mode may fall back from an invalid remembered profile to the configured default only when the default artifact validates successfully.

Post-commit application adapters remain best-effort and never roll back committed core state.

## Adapter Diagnostics

Each post-commit adapter gets a private stderr capture file. On failure, the transition warning includes the adapter name and the first useful error line. If output is longer, the complete diagnostic is retained under `${XDG_STATE_HOME:-$HOME/.local/state}/desktop-profiles/adapter-errors/` and its path is included in the warning. Successful temporary captures are deleted.

Successful adapters produce no warning. A failed adapter does not prevent later adapters from running.

## Evaluation-Time Validation

`checks/profiles.nix` validates the compiled contract rather than a loose selection of generated files. For every profile it checks:

- required manifest keys and exact schema version
- manifest name matches the profile directory
- variant structure and adapter value types
- relative artifact paths are safe and reference emitted files
- required dark artifacts exist
- light artifact references exist only when the light variant exists
- non-self-themed color artifacts are non-empty
- bar-specific required artifacts exist
- existing Niri, Vicinae, and Quickshell behavioral invariants

The check returns the existing summary on success and throws a field-specific error on failure.

## Runtime Tests

Runtime tests use compiled artifacts instead of hand-written partial `meta.json` and `runtime.json` fixtures. A fixture builder evaluates a small Nix profile set through the real compiler and materializes its generated files into the temporary test home.

Coverage includes:

- a valid dark-only profile
- a valid dark/light profile
- each supported bar
- wrong, missing, and non-integer schema versions
- manifest identity mismatch
- missing variant
- missing, empty, absolute, and parent-traversing artifact paths
- transition validation occurring before any core mutation
- wallpaper and application adapters reading the selected variant
- post-commit adapter stderr appearing in the warning
- later adapters still running after one failure

A repository invariant rejects new direct reads of `meta.json`, `runtime.json`, wallpaper path files, or compiled manifest fields outside the manifest interface and tests.

## Migration

The migration is one cutover:

1. Introduce the compiler, manifest interface, and failing contract tests.
2. Generate `manifest.json` alongside existing files temporarily within the implementation branch.
3. Migrate every runtime and activation reader to the manifest interface.
4. Change runtime fixtures to compiled artifacts.
5. Remove generation and consumption of `meta.json`, `runtime.json`, `wallpaper-dir`, and `wallpaper-dir-light` in the same final change set.
6. Add the invariant preventing legacy reads from returning.

The merged configuration never supports two public representations. Home Manager activation removes the obsolete managed files, and all runtime readers require the new manifest immediately after activation.

## Verification

The completed change must pass:

- focused manifest compiler and runtime tests
- `just check-profiles`
- `just wallpaper-script-check`
- `just shell-check`
- `just fmt-check`
- `just check`
- `just build laptop`
- a live profile switch between a dark/light profile and a dark-only profile without contract or adapter warnings

Activation occurs only after the full validation and build gates pass.
