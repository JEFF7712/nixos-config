# Zathura Profile Theming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Zathura as the default PDF reader and theme its chrome plus page recoloring from desktop profiles (including wallpaper engines), matching the btop/tmux pattern.

**Architecture:** Add a `colors.zathura` slot rendered to `zathura-colors` / `zathura-colors-light`, apply into `~/.config/zathura/colors` on profile switch, and teach matugen/iris/temperature to write that same live path. Base `zathurarc` only holds non-color settings and `include colors`.

**Tech Stack:** NixOS/home-manager, desktop-profile helpers (`lib/desktop-profiles/`), bash profile scripts, matugen templates, iris/temperature Python renderers, `just check-profiles` / `just shell-check` / `just temperature-render` checks

**Spec:** `docs/superpowers/specs/2026-07-16-zathura-profile-theming-design.md`

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/desktop-profiles/theme-builders.nix` | `mkZathuraColors` fragment generator |
| `lib/desktop-profiles/options.nix` | `colors.zathura` / light option |
| `lib/desktop-profiles/files.nix` | Materialize `zathura-colors` (+ light) |
| `lib/desktop-profiles/artifact.nix` | Manifest artifact name for dark/light |
| `lib/desktop-profiles/static-profile.nix` | Default role → zathura mapping |
| `modules/home-manager/profiles/{clean,sharp,tinted}.nix` | Hand-rolled `mkColors` slots |
| `checks/profiles.nix` | Require non-empty zathura color files |
| `home/scripts/profile-common` | `apply_zathura_theme` |
| `home/scripts/profile-transition` | Post-commit adapter |
| `home/configs/zathura/zathurarc` | Base config + `include colors` |
| `modules/home-manager/common-apps.nix` | Package, MIME, symlink `zathurarc` |
| `home/configs/matugen/config.toml` + `config-sharp.toml` | Template registration |
| `home/configs/matugen/templates{,-sharp}/zathura-colors` | Matugen templates |
| `home/scripts/{iris,temperature}-render.py` | Wallpaper engine writers |
| `checks/temperature-render.bash` | Assert live colors file is written |

Do **not** set static zathura colors on `noctalia` (self-themed; leave null).

---

### Task 1: Fail `check-profiles` on missing zathura slot, then add the builder + plumbing

**Files:**
- Modify: `checks/profiles.nix`
- Modify: `lib/desktop-profiles/options.nix`
- Modify: `lib/desktop-profiles/theme-builders.nix`
- Modify: `lib/desktop-profiles/files.nix`
- Modify: `lib/desktop-profiles/artifact.nix`
- Modify: `lib/desktop-profiles/static-profile.nix`
- Modify: `modules/home-manager/profiles/clean.nix`
- Modify: `modules/home-manager/profiles/sharp.nix`
- Modify: `modules/home-manager/profiles/tinted.nix`

- [ ] **Step 1: Add required color files to the profile checker (expect failure once files exist empty)**

In `checks/profiles.nix`, add to `colorFiles` (dark list after `cava-colors`, light list after `cava-colors-light`):

```nix
"zathura-colors"
# ...
"zathura-colors-light"
```

- [ ] **Step 2: Add the option**

In `lib/desktop-profiles/options.nix` `colorOptions`, after `cava`:

```nix
zathura = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
};
```

- [ ] **Step 3: Add `mkZathuraColors` at the end of the cava builder section in `theme-builders.nix`**

```nix
  # Zathura colors fragment installed to ~/.config/zathura/colors and
  # included from zathurarc. recolor is always on so page paper/ink track
  # the profile (lightcolor = paper side, darkcolor = ink side).
  mkZathuraColors =
    {
      bg,
      fg,
      surface ? bg,
      muted ? fg,
      accent ? fg,
      error ? "#ff6b6b",
      recolorLight ? bg,
      recolorDark ? fg,
    }:
    ''
      set default-bg "${bg}"
      set default-fg "${fg}"
      set statusbar-bg "${surface}"
      set statusbar-fg "${fg}"
      set inputbar-bg "${surface}"
      set inputbar-fg "${fg}"
      set notification-error-bg "${error}"
      set notification-error-fg "${bg}"
      set notification-warning-bg "${accent}"
      set notification-warning-fg "${bg}"
      set completion-bg "${surface}"
      set completion-fg "${fg}"
      set completion-group-bg "${surface}"
      set completion-group-fg "${muted}"
      set completion-highlight-bg "${accent}"
      set completion-highlight-fg "${bg}"
      set recolor true
      set recolor-keephue true
      set recolor-lightcolor "${recolorLight}"
      set recolor-darkcolor "${recolorDark}"
    '';
```

- [ ] **Step 4: Materialize files**

In `lib/desktop-profiles/files.nix` `base` attrs, after cava:

```nix
".config/desktop-profiles/${name}/zathura-colors".text = orEmpty profile.colors.zathura;
```

In `lightFiles`, after cava-light:

```nix
".config/desktop-profiles/${name}/zathura-colors-light".text = orEmpty profile.colorsLight.zathura;
```

- [ ] **Step 5: Artifact map**

In `lib/desktop-profiles/artifact.nix` `variantArtifacts`:

```nix
zathura = if light then "zathura-colors-light" else "zathura-colors";
```

- [ ] **Step 6: Static-profile default**

In `lib/desktop-profiles/static-profile.nix` inside `mkColorsFor`, after the `cava = ...` assignment:

```nix
zathura = theme.mkZathuraColors (
  {
    bg = r.bg0;
    fg = r.fg1;
    surface = r.bg1;
    muted = r.fg3;
    inherit (r) accent;
    error = r.red;
    recolorLight = r.bg0;
    recolorDark = r.fg0;
  }
  // ov "zathura"
);
```

- [ ] **Step 7: Hand-rolled profiles (`clean`, `sharp`, `tinted`)**

In each profile’s `mkColors` / colors attrset (same place as `btop` / `tmux`), add:

**clean.nix** (uses `bg0`, `fg0`, `fg1`, `fg2`, `accent`, `err`):

```nix
zathura = theme.mkZathuraColors {
  bg = bg0;
  fg = fg1;
  surface = bg1;
  muted = fg2;
  inherit accent;
  error = err;
  recolorLight = bg0;
  recolorDark = fg0;
};
```

**sharp.nix** / **tinted.nix** (inside `mkColors` / `p:` helper — use that helper’s fields; sharp uses `p.err`, tinted uses `p.err` or `p.red` — match the profile’s existing error role name):

```nix
zathura = theme.mkZathuraColors {
  bg = p.bg0;
  fg = p.fg1;
  surface = p.bg1;
  muted = p.fg2;
  inherit (p) accent;
  error = p.err;
  recolorLight = p.bg0;
  recolorDark = p.fg0;
};
```

If tinted names the error role `red` instead of `err`, use `error = p.red`.

- [ ] **Step 8: Verify profiles check**

Run:

```bash
just check-profiles && just fmt-check
```

Expected: PASS (non-self-themed profiles have non-empty `zathura-colors`; noctalia stays empty and is skipped by `!self`).

- [ ] **Step 9: Commit**

```bash
git add checks/profiles.nix \
  lib/desktop-profiles/options.nix \
  lib/desktop-profiles/theme-builders.nix \
  lib/desktop-profiles/files.nix \
  lib/desktop-profiles/artifact.nix \
  lib/desktop-profiles/static-profile.nix \
  modules/home-manager/profiles/clean.nix \
  modules/home-manager/profiles/sharp.nix \
  modules/home-manager/profiles/tinted.nix
git commit -m "$(cat <<'EOF'
Add zathura color slot to desktop profiles.

EOF
)"
```

---

### Task 2: Runtime apply on profile switch

**Files:**
- Modify: `home/scripts/profile-common`
- Modify: `home/scripts/profile-transition`

- [ ] **Step 1: Add `apply_zathura_theme` next to `apply_btop_theme` in `profile-common`**

```bash
# apply_zathura_theme <profile-dir> <variant>
# Installs the variant-resolved colors fragment for zathurarc to include.
# Running zathura instances pick it up on next start.
apply_zathura_theme() {
  local profile_dir="$1" variant="$2"
  local src

  src=$(pick_variant_file "$variant" "$profile_dir/zathura-colors" "$profile_dir/zathura-colors-light")
  [ -s "$src" ] || return 0

  mkdir -p "$CONFIG_HOME/zathura"
  install -m 644 "$src" "$CONFIG_HOME/zathura/colors"
}
```

- [ ] **Step 2: Call it from the static color-apply path**

Where `apply_btop_theme` / `apply_tmux_colors` are invoked together (~line 789), add:

```bash
apply_zathura_theme "$profile_dir" "$variant"
```

- [ ] **Step 3: Wire post-commit adapter in `profile-transition`**

Inside the `else` branch of `TARGET_SELF_THEMED` (with btop/tmux), add:

```bash
run_post_commit_adapter zathura apply_zathura_theme "$TARGET_DIR" "$TARGET_VARIANT"
```

- [ ] **Step 4: Shell-check**

Run:

```bash
just shell-check
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add home/scripts/profile-common home/scripts/profile-transition
git commit -m "$(cat <<'EOF'
Apply zathura colors on profile switch.

EOF
)"
```

---

### Task 3: Package, MIME defaults, base config

**Files:**
- Create: `home/configs/zathura/zathurarc`
- Modify: `modules/home-manager/common-apps.nix`

- [ ] **Step 1: Create base config**

`home/configs/zathura/zathurarc`:

```
# Profile colors are managed by switch-profile / wallpaper theme engines.
include colors

set adjust-open width
set page-padding 4
set selection-clipboard clipboard
```

- [ ] **Step 2: Install package + symlink + MIME in `common-apps.nix`**

Add to `home.packages`:

```nix
zathura
```

(`pkgs.zathura` on this flake already ships the mupdf PDF plugin; do not add a separate `zathura-pdf-*` unless eval shows PDF open fails.)

Add config symlink (near other `xdg.configFile` entries):

```nix
xdg.configFile."zathura/zathurarc".source =
  config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/zathura/zathurarc";
```

Update MIME:

```nix
associations.added = {
  "inode/directory" = [ "thunar.desktop" ];
  "application/x-directory" = [ "thunar.desktop" ];
  "application/pdf" = [
    "org.pwmt.zathura.desktop"
    "firefox.desktop"
  ];
};
defaultApplications = {
  # ... existing entries ...
  "application/pdf" = "org.pwmt.zathura.desktop";
  # ...
};
```

(Remove the old `"application/pdf" = "firefox.desktop"` default line.)

- [ ] **Step 3: Eval**

Run:

```bash
just quick
```

Expected: PASS (laptop eval + whitespace)

- [ ] **Step 4: Commit**

```bash
git add home/configs/zathura/zathurarc modules/home-manager/common-apps.nix
git commit -m "$(cat <<'EOF'
Install Zathura as default PDF reader with themed config.

EOF
)"
```

---

### Task 4: Wallpaper engines (matugen + iris + temperature)

**Files:**
- Create: `home/configs/matugen/templates/zathura-colors`
- Create: `home/configs/matugen/templates-sharp/zathura-colors`
- Modify: `home/configs/matugen/config.toml`
- Modify: `home/configs/matugen/config-sharp.toml`
- Modify: `home/scripts/iris-render.py`
- Modify: `home/scripts/temperature-render.py`
- Modify: `checks/temperature-render.bash`

- [ ] **Step 1: Matugen templates (identical content in both template trees)**

`home/configs/matugen/templates/zathura-colors` and `templates-sharp/zathura-colors`:

```
set default-bg "{{colors.surface.default.hex}}"
set default-fg "{{colors.on_surface.default.hex}}"
set statusbar-bg "{{colors.surface_container.default.hex}}"
set statusbar-fg "{{colors.on_surface.default.hex}}"
set inputbar-bg "{{colors.surface_container.default.hex}}"
set inputbar-fg "{{colors.on_surface.default.hex}}"
set notification-error-bg "{{colors.error.default.hex}}"
set notification-error-fg "{{colors.surface.default.hex}}"
set notification-warning-bg "{{colors.primary.default.hex}}"
set notification-warning-fg "{{colors.surface.default.hex}}"
set completion-bg "{{colors.surface_container.default.hex}}"
set completion-fg "{{colors.on_surface.default.hex}}"
set completion-group-bg "{{colors.surface_container.default.hex}}"
set completion-group-fg "{{colors.on_surface_variant.default.hex}}"
set completion-highlight-bg "{{colors.primary.default.hex}}"
set completion-highlight-fg "{{colors.surface.default.hex}}"
set recolor true
set recolor-keephue true
set recolor-lightcolor "{{colors.surface.default.hex}}"
set recolor-darkcolor "{{colors.on_surface.default.hex}}"
```

- [ ] **Step 2: Register templates**

In both `config.toml` and `config-sharp.toml`, after the tmux template block:

```toml
[templates.zathura]
input_path = "~/.config/matugen/templates/zathura-colors"
output_path = "~/.config/zathura/colors"
```

For sharp, use `templates-sharp/zathura-colors` as `input_path` (same pattern as sharp’s other templates).

- [ ] **Step 3: `iris-render.py` — add writer + call from `main`**

Add next to `tmux`:

```python
def zathura(p, out):
    w(
        out,
        f"""set default-bg "{p["bg"]}"
set default-fg "{p["fg"]}"
set statusbar-bg "{p["surface"]}"
set statusbar-fg "{p["fg"]}"
set inputbar-bg "{p["surface"]}"
set inputbar-fg "{p["fg"]}"
set notification-error-bg "{p["red"]}"
set notification-error-fg "{p["bg"]}"
set notification-warning-bg "{p["accent"]}"
set notification-warning-fg "{p["bg"]}"
set completion-bg "{p["surface"]}"
set completion-fg "{p["fg"]}"
set completion-group-bg "{p["surface"]}"
set completion-group-fg "{p["dim"]}"
set completion-highlight-bg "{p["accent"]}"
set completion-highlight-fg "{p["bg"]}"
set recolor true
set recolor-keephue true
set recolor-lightcolor "{p["bg"]}"
set recolor-darkcolor "{p["fg"]}"
""",
    )
```

In `main()`, after `tmux(...)`:

```python
zathura(p, os.path.join(c, "zathura/colors"))
```

- [ ] **Step 4: `temperature-render.py` — same shape with temperature palette keys**

```python
def zathura(p, out):
    w(
        out,
        f"""set default-bg "{p["bg0"]}"
set default-fg "{p["fg1"]}"
set statusbar-bg "{p["bg1"]}"
set statusbar-fg "{p["fg1"]}"
set inputbar-bg "{p["bg1"]}"
set inputbar-fg "{p["fg1"]}"
set notification-error-bg "{p["err"]}"
set notification-error-fg "{p["bg0"]}"
set notification-warning-bg "{p["accent"]}"
set notification-warning-fg "{p["bg0"]}"
set completion-bg "{p["bg1"]}"
set completion-fg "{p["fg1"]}"
set completion-group-bg "{p["bg1"]}"
set completion-group-fg "{p["fg2"]}"
set completion-highlight-bg "{p["accent"]}"
set completion-highlight-fg "{p["bg0"]}"
set recolor true
set recolor-keephue true
set recolor-lightcolor "{p["bg0"]}"
set recolor-darkcolor "{p["fg0"]}"
""",
    )
```

Call from `main()`:

```python
zathura(p, os.path.join(c, "zathura/colors"))
```

Use whatever error key temperature already uses for other writers (`err` vs `red`) — match `hyprlock`/`btop` in the same file.

- [ ] **Step 5: Extend `checks/temperature-render.bash` destination list**

Add to the `for f in ...` loop:

```bash
"$config_home/zathura/colors" \
```

- [ ] **Step 6: Run checks**

```bash
bash checks/temperature-render.bash
bash checks/iris-render.bash
just shell-check
just check-profiles
just fmt-check
```

Expected: all PASS. Manually confirm temperature output contains `recolor true` and non-empty hex colors:

```bash
# after temperature-render.bash, or run the script into a tempdir and:
grep -E 'recolor-lightcolor|recolor-darkcolor' /tmp/.../zathura/colors
```

- [ ] **Step 7: Commit**

```bash
git add home/configs/matugen \
  home/scripts/iris-render.py \
  home/scripts/temperature-render.py \
  checks/temperature-render.bash
git commit -m "$(cat <<'EOF'
Theme Zathura from wallpaper color engines.

EOF
)"
```

---

### Task 5: Activate and smoke-test

**Files:** none (runtime)

- [ ] **Step 1: Diff / switch**

```bash
just dry
# then, with user approval:
just switch
```

Expected: zathura appears in the closure; home activation links `zathurarc`.

- [ ] **Step 2: Apply current profile colors**

```bash
switch-profile "$(basename "$(readlink -f ~/.config/desktop-profiles/active)")"
# or toggle-variant to force re-apply
test -s ~/.config/zathura/colors
grep -q 'recolor true' ~/.config/zathura/colors
```

- [ ] **Step 3: Manual smoke**

Open a PDF (or `zathura /path/to/some.pdf`). Confirm:

1. Zathura launches (not Firefox) for `application/pdf`
2. Chrome matches the active profile
3. Page is recolored
4. Firefox still listed under “Open with”

No further commit unless smoke-test found fixes.

---

## Spec coverage (self-review)

| Spec requirement | Task |
| --- | --- |
| Package + MIME (Zathura default, Firefox associated) | Task 3 |
| Base zathurarc + include colors | Task 3 |
| `mkZathuraColors` + recolor always on | Task 1 |
| Option + files + artifact | Task 1 |
| static-profile + hand-rolled profiles | Task 1 |
| `apply_zathura_theme` + transition | Task 2 |
| matugen + iris + temperature | Task 4 |
| noctalia colors null | Task 1 (no noctalia edit) |
| `checks/profiles.nix` + temperature fixture | Tasks 1 & 4 |
| Next-launch only (no live reload) | by design in Tasks 2–4 |

No placeholders left. Names are consistent: artifact/file `zathura-colors`, live path `~/.config/zathura/colors`, function `apply_zathura_theme` / `mkZathuraColors`.
