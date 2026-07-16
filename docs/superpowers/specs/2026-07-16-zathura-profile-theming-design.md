# Zathura PDF reader with desktop-profile theming

Date: 2026-07-16  
Status: approved (pending user review of this written spec)

## Goal

Install Zathura as the default PDF reader and theme both its chrome and page recoloring from the desktop-profile system — including wallpaper-driven engines — so it tracks profile and variant like btop/tmux.

## Decisions

| Question | Choice |
| --- | --- |
| Page treatment | Always recolor pages (`recolor true`) using profile light/dark pair |
| MIME | Zathura default for `application/pdf`; keep Firefox associated |
| Wallpaper engines | Full pipeline (matugen, iris, temperature) writes Zathura colors |
| Approach | First-class profile color slot (not HM-only or include-file special case) |

## Out of scope

- Live reload of already-open Zathura windows (next launch is enough, same as btop)
- Theming self-themed `noctalia` via static colors (leave null like other slots)
- Changing non-PDF MIME defaults
- Keybinding redesign beyond a minimal usable base config

## Architecture

1. **Package + MIME** in `modules/home-manager/common-apps.nix`: add `zathura` and a PDF backend (`zathura-pdf-mupdf` preferred; poppler acceptable if mupdf is awkward on this nixpkgs). Set `defaultApplications."application/pdf"` to Zathura’s desktop file; add Firefox under `associations.added` for “Open with”.
2. **Base config** at `home/configs/zathura/zathurarc` (out-of-store symlink): non-color settings only; `include` the live colors file (e.g. `~/.config/zathura/colors`).
3. **Theme builder** `mkZathuraColors` in `lib/desktop-profiles/theme-builders.nix`: emit a Zathura fragment with UI colors plus:
   - `recolor true`
   - `recolor-lightcolor` ← page background role (typically `bg` / `bg0`)
   - `recolor-darkcolor` ← page foreground role (typically `fg` / `fg0`)
   - statusbar / inputbar / notification / highlight colors from surface/fg/accent/error roles
4. **Option + materialization**: `colors.zathura` / `colorsLight.zathura` in `lib/desktop-profiles/options.nix`; write `zathura-colors` / `zathura-colors-light` in `files.nix`; list in `artifact.nix` for the manifest contract.
5. **Static profiles**: wire `mkZathuraColors` in `static-profile.nix` so scheme profiles get it by default. Hand-rolled profiles that set colors explicitly (`clean`, `sharp`, etc.) call the same builder.
6. **Runtime apply**: `apply_zathura_theme` in `home/scripts/profile-common`, invoked from the same apply path as btop and from `profile-transition` post-commit adapters. Pick variant file → `install` to `~/.config/zathura/colors`. Empty/missing source → no-op.
7. **Wallpaper engines**:
   - matugen: add templates under `home/configs/matugen/templates/` and `templates-sharp/`, register in both config tomls with `output_path` = `~/.config/zathura/colors`
   - `iris-render.py` and `temperature-render.py`: emit the same live path (and keep parity with other consumers)

## Color mapping (default)

| Zathura key | Role |
| --- | --- |
| `default-bg` / statusbar/inputbar backgrounds | `bg0` / `bg1` (surface) |
| `default-fg` / statusbar/inputbar foregrounds | `fg1` |
| accents / highlights | `accent` |
| errors | `red` |
| `recolor-lightcolor` | `bg0` (paper side after recolor) |
| `recolor-darkcolor` | `fg0` (ink side after recolor) |

Both dark and light variants keep `recolor true`; the light/dark hex pair comes from that variant’s palette so light profiles recolor toward light paper and dark toward dark paper.

## Data flow

```
switch-profile / toggle-variant
  → apply_zathura_theme(profile_dir, variant)
  → ~/.config/zathura/colors
  → zathurarc include (next Zathura launch)

wallpaper change (wallpaperTheming profile)
  → apply_wallpaper_theme
  → matugen | iris-render | temperature-render
  → ~/.config/zathura/colors
```

## Error handling

- Missing colors file or empty profile slot: apply no-ops; Zathura still opens with base config (may look unthemed until a themed profile is applied).
- Self-themed noctalia: `colors.zathura` stays null; no empty-file assertion failure if the profile checker treats self-themed like today.
- Wallpaper engine soft-fail: same as existing matugen/iris branches — do not fail profile switch.

## Validation

- Add `zathura-colors` / `zathura-colors-light` to `checks/profiles.nix` `colorFiles` (non-self-themed profiles must not render empty).
- Extend temperature-render (and any iris) fixture checks that assert written consumer paths, if present.
- `just check-profiles && just shell-check && just fmt-check`
- After package/MIME change: `just quick` (or `just eval laptop`)

## Success criteria

- Opening a PDF launches Zathura; Firefox remains available via “Open with”.
- Switching profile/variant changes Zathura chrome and page recolor on next launch.
- Wallpaper-driven profiles update `~/.config/zathura/colors` when the wallpaper theme pipeline runs.
- `just check-profiles` passes with the new required color files.
