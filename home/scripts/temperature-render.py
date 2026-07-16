#!/usr/bin/env python3
# temperature-render — the "temperature" colorEngine for apply_wallpaper_theme.
# Unlike iris (k-means extraction) or matugen (full scheme generation), this
# stays deliberately subtle: take the wallpaper's seed hue, apply a small
# saturation, and keep the clean profile's own lightness anchors (bg0..err)
# so every consumer still gets clean's near-monochrome look with just a hint
# of the wallpaper's color temperature — never a saturated accent. Plain
# stdlib only (colorsys), same destinations iris-render writes minus
# zed/obsidian/spicetify (out of scope for this engine).
import argparse
import colorsys
import json
import os
import re
import sys

# Clean profile's dark-mode lightness anchors (modules/home-manager/profiles/
# clean.nix): hex sets the anchor lightness, the float is the small HSL
# saturation the tint is allowed to reach.
ANCHORS = {
    "bg0": ("#141414", 0.07),
    "bg1": ("#202020", 0.07),
    "bg2": ("#323232", 0.06),
    "bg3": ("#5f5f5f", 0.05),
    "fg0": ("#ffffff", 0.04),
    "fg1": ("#f2f2f2", 0.035),
    "fg2": ("#c8c8c8", 0.035),
    "accent": ("#ffffff", 0.04),
    "err": ("#f0dada", 0.08),
}

HEX6_RE = re.compile(r"^#?[0-9a-fA-F]{6}$")


def hex_to_rgb01(hexc):
    hexc = hexc.lstrip("#")
    return tuple(int(hexc[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb01_to_hex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in rgb)


def seed_hue(seed):
    if not HEX6_RE.match(seed):
        raise ValueError(f"bad seed color: {seed!r}")
    r, g, b = hex_to_rgb01(seed)
    h, _l, _s = colorsys.rgb_to_hls(r, g, b)
    return h


def tint(anchor_hex, sat, hue, invert):
    r, g, b = hex_to_rgb01(anchor_hex)
    _h, l, _s = colorsys.rgb_to_hls(r, g, b)
    if invert:
        l = 1.0 - l
    return rgb01_to_hex(colorsys.hls_to_rgb(hue, l, sat))


def build_palette(seed, mode):
    hue = seed_hue(seed)
    invert = mode == "light"
    return {name: tint(hexc, sat, hue, invert) for name, (hexc, sat) in ANCHORS.items()}


def rgb_ints(hexc):
    hexc = hexc.lstrip("#")
    return tuple(int(hexc[i : i + 2], 16) for i in (0, 2, 4))


def rgba(hexc, alpha):
    r, g, b = rgb_ints(hexc)
    return f"rgba({r}, {g}, {b}, {alpha})"


def rgb_paren(hexc):
    r, g, b = rgb_ints(hexc)
    return f"rgb({r}, {g}, {b})"


def hyprlock_rgba(hexc, alpha_suffix):
    return f"rgba({hexc.lstrip('#')}{alpha_suffix})"


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text)


def retint_preserve_alpha(baked_value, new_rgb_hex):
    # Quickshell/QML colors are #AARRGGBB; keep whatever alpha the baked
    # profile theme shipped (e.g. clean's "#66") and only retint the RGB.
    baked = (baked_value or "").lstrip("#")
    new_rgb = new_rgb_hex.lstrip("#")
    alpha = baked[:-6] if len(baked) > 6 else ""
    return f"#{alpha}{new_rgb}"


def quickshell(p, profile_dir, out):
    base = {}
    baked = os.path.join(profile_dir, "quickshell-theme.json")
    try:
        with open(baked) as fh:
            base = json.load(fh)
    except Exception:
        pass
    base.update(
        {
            "fg": p["fg0"],
            "bg": retint_preserve_alpha(base.get("bg"), p["bg0"]),
            "popupBg": retint_preserve_alpha(base.get("popupBg"), p["bg0"]),
            "rawBg": retint_preserve_alpha(base.get("rawBg"), p["bg0"]),
            "accent": p["accent"],
            "second": p["fg2"],
            "warm": p["fg2"],
            "fresh": p["fg2"],
            "dividerColor": p["bg2"],
        }
    )
    w(out, json.dumps(base, indent=2) + "\n")


def kitty(p, out):
    w(
        out,
        f"""# temperature — subtle wallpaper hue tint, clean lightness anchors.
cursor {p["fg1"]}
cursor_text_color {p["bg0"]}
foreground {p["fg1"]}
background {p["bg0"]}
selection_foreground {p["bg0"]}
selection_background {p["bg3"]}
color0  {p["bg1"]}
color8  {p["bg3"]}
color1  {p["err"]}
color9  {p["err"]}
color2  {p["fg2"]}
color10 {p["fg1"]}
color3  {p["fg2"]}
color11 {p["fg1"]}
color4  {p["fg2"]}
color12 {p["fg1"]}
color5  {p["fg2"]}
color13 {p["fg1"]}
color6  {p["fg2"]}
color14 {p["fg1"]}
color7  {p["fg1"]}
color15 {p["fg0"]}
""",
    )


def gtk(p, out):
    css = f"""/* temperature — subtle wallpaper hue tint, clean glass */
@define-color accent_color {p["accent"]};
@define-color accent_bg_color {rgba(p["accent"], "0.24")};
@define-color accent_fg_color {p["bg0"]};
@define-color destructive_bg_color {p["err"]};
@define-color destructive_fg_color {p["fg0"]};
@define-color error_bg_color {p["err"]};
@define-color error_fg_color {p["fg0"]};
@define-color window_bg_color {rgba(p["bg0"], "0.54")};
@define-color window_fg_color {p["fg1"]};
@define-color view_bg_color {rgba(p["bg0"], "0.44")};
@define-color headerbar_bg_color {rgba(p["accent"], "0.08")};
@define-color headerbar_fg_color {p["fg1"]};
@define-color popover_bg_color {rgba(p["bg0"], "0.74")};
@define-color popover_fg_color {p["fg1"]};
@define-color card_bg_color {rgba(p["accent"], "0.08")};
@define-color card_fg_color {p["fg1"]};
@define-color sidebar_bg_color {rgba(p["accent"], "0.06")};
@define-color sidebar_fg_color {p["fg1"]};
@define-color sidebar_border_color {rgba(p["accent"], "0.18")};
"""
    for o in out:
        w(o, css)


def qt(p, out):
    fg1, fg2 = p["fg1"], p["fg2"]
    bg0, bg1, bg2, bg3 = p["bg0"], p["bg1"], p["bg2"], p["bg3"]
    accent = p["accent"]
    light, bright, shadow = "#ffffff", "#ffffff", "#000000"
    active = [
        fg1,
        bg1,
        light,
        bg3,
        bg2,
        bg2,
        fg1,
        bright,
        fg1,
        bg0,
        bg0,
        shadow,
        accent,
        bg2,
        accent,
        fg2,
        bg1,
        bg0,
        bg1,
        fg1,
        fg2,
        accent,
    ]
    disabled = [
        fg2,
        bg1,
        light,
        bg3,
        bg2,
        bg2,
        fg2,
        bright,
        fg2,
        bg0,
        bg0,
        shadow,
        bg3,
        bg2,
        bg3,
        fg2,
        bg1,
        bg0,
        bg1,
        fg2,
        fg2,
        bg3,
    ]
    inactive = [
        fg2,
        bg1,
        light,
        bg3,
        bg2,
        bg2,
        fg2,
        bright,
        fg2,
        bg0,
        bg0,
        shadow,
        accent,
        bg2,
        accent,
        fg2,
        bg1,
        bg0,
        bg1,
        fg2,
        fg2,
        accent,
    ]
    body = "[ColorScheme]\nactive_colors={a}\ndisabled_colors={d}\ninactive_colors={i}\n".format(
        a=", ".join(active), d=", ".join(disabled), i=", ".join(inactive)
    )
    for o in out:
        w(o, body)


def cava(p, out):
    w(
        out,
        f"""[color]
foreground = '{p["fg0"]}'
gradient = 1
gradient_color_1 = '{p["fg2"]}'
gradient_color_2 = '{p["fg1"]}'
gradient_color_3 = '{p["fg0"]}'
""",
    )


def btop(p, out):
    grad = ""
    for grp in [
        "temp",
        "cpu",
        "free",
        "cached",
        "available",
        "used",
        "download",
        "upload",
        "process",
    ]:
        grad += f'theme[{grp}_start]="{p["fg2"]}"\ntheme[{grp}_mid]="{p["fg1"]}"\ntheme[{grp}_end]="{p["fg0"]}"\n'
    w(
        out,
        f"""theme[main_bg]="{p["bg0"]}"
theme[main_fg]="{p["fg1"]}"
theme[title]="{p["fg1"]}"
theme[hi_fg]="{p["accent"]}"
theme[selected_bg]="{p["bg2"]}"
theme[selected_fg]="{p["accent"]}"
theme[inactive_fg]="{p["fg2"]}"
theme[graph_text]="{p["fg1"]}"
theme[meter_bg]="{p["bg2"]}"
theme[proc_misc]="{p["fg2"]}"
theme[cpu_box]="{p["bg2"]}"
theme[mem_box]="{p["bg2"]}"
theme[net_box]="{p["bg2"]}"
theme[proc_box]="{p["bg2"]}"
theme[div_line]="{p["bg2"]}"
{grad}""",
    )


def hyprlock(p, out):
    w(
        out,
        f"""$fg = {rgb_paren(p["fg0"])}
$muted = {rgb_paren(p["fg2"])}
$accent = {rgb_paren(p["accent"])}
$surface = {hyprlock_rgba(p["bg0"], "d9")}
$surface_alt = {hyprlock_rgba(p["bg1"], "c8")}
$border = {hyprlock_rgba(p["accent"], "e6")}
$error = {hyprlock_rgba(p["err"], "e6")}
""",
    )


def tmux(p, out):
    w(
        out,
        f"""set -g status-style "bg={p["bg1"]},fg={p["fg1"]}"
set -g status-left-style "fg={p["fg0"]},bold"
set -g status-right-style "fg={p["fg2"]}"
set -g window-status-current-style "fg={p["fg0"]},bold"
set -g window-status-style "fg={p["fg2"]}"
set -g pane-border-style "fg={p["bg2"]}"
set -g pane-active-border-style "fg={p["fg0"]}"
set -g message-style "bg={p["bg1"]},fg={p["fg0"]}"
set -g mode-style "bg={p["fg0"]},fg={p["bg1"]}"
set -g clock-mode-colour "{p["fg0"]}"
""",
    )


def fish(p, out):
    w(
        out,
        f"""set -g fish_color_normal {p["fg1"]}
set -g fish_color_command {p["fg0"]}
set -g fish_color_keyword {p["fg0"]}
set -g fish_color_quote {p["fg2"]}
set -g fish_color_error {p["fg0"]}
set -g fish_color_param {p["fg1"]}
set -g fish_color_comment {p["fg2"]}
set -g fish_color_selection --background={p["bg2"]}
set -g fish_color_autosuggestion {p["fg2"]}
""",
    )


def starship(p, out):
    w(
        out,
        f"""format = "$all"

[character]
success_symbol = "[❯]({p["fg1"]})"
error_symbol = "[❯]({p["fg0"]})"

[directory]
style = "bold {p["fg0"]}"

[git_branch]
style = "bold {p["fg2"]}"

[cmd_duration]
style = "bold {p["fg2"]}"
""",
    )


def rofi(p, out):
    glass0 = rgba(p["bg0"], "0.42")
    glass1 = rgba(p["accent"], "0.08")
    glass2 = rgba(p["accent"], "0.14")
    glass_border = rgba(p["accent"], "0.34")
    w(
        out,
        f"""* {{
    font:                        "JetBrainsMono Nerd Font 11";
    background-color:            {glass0};
    text-color:                  {p["fg1"]};
    border-color:                {glass_border};
    selected-normal-background:  {glass2};
    selected-normal-foreground:  {p["fg0"]};
    normal-background:           transparent;
    normal-foreground:           {p["fg1"]};
}}

window {{
    width:              900px;
    border:             1px solid;
    border-color:       {glass_border};
    border-radius:      15px;
    padding:            12px;
    background-color:   {glass0};
}}

mainbox {{
    spacing:            0;
    children:           [ inputbar, listview ];
}}

inputbar {{
    padding:            8px 12px;
    margin:             0 0 10px 0;
    background-color:   {glass1};
    border:             1px solid; border-color: {glass_border};
    border-radius:      10px;
    children:           [ prompt, entry ];
}}

prompt {{
    text-color:         {p["fg1"]};
    padding:            0 8px 0 0;
}}

entry {{
    text-color:         {p["fg1"]};
    placeholder:        "Switch profile...";
    placeholder-color:  {p["fg2"]};
}}

listview {{
    columns:            3;
    lines:              2;
    spacing:            10px;
    fixed-height:       false;
    scrollbar:          false;
}}

element {{
    orientation:        vertical;
    padding:            10px;
    spacing:            8px;
    border-radius:      10px;
    background-color:   {glass1};
    border:             1px solid; border-color: {rgba(p["accent"], "0.16")};
    cursor:             pointer;
}}

element selected {{
    background-color:   {glass2};
    border:             1px solid;
    border-color:       {p["accent"]};
}}

element-icon {{
    size:               160px;
    border-radius:      4px;
    horizontal-align:   0.5;
}}

element-text {{
    horizontal-align:   0.5;
    vertical-align:     0.5;
    text-color:         inherit;
    font:               "JetBrainsMono Nerd Font 12";
}}
""",
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", required=True)
    ap.add_argument("--mode", choices=["dark", "light"], default="dark")
    ap.add_argument("--config-home", required=True)
    ap.add_argument("--profiles-dir", required=True)
    ap.add_argument("--profile-dir", required=True)
    args = ap.parse_args()

    try:
        p = build_palette(args.seed, args.mode)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

    c = args.config_home

    quickshell(
        p,
        args.profile_dir,
        os.path.join(args.profiles_dir, "runtime-quickshell-theme.json"),
    )
    kitty(p, os.path.join(c, "kitty/colors.conf"))
    gtk(
        p,
        [
            os.path.join(c, "gtk-3.0/noctalia.css"),
            os.path.join(c, "gtk-4.0/noctalia.css"),
        ],
    )
    qt(
        p,
        [
            os.path.join(c, "qt6ct/colors/noctalia.conf"),
            os.path.join(c, "qt5ct/colors/noctalia.conf"),
        ],
    )
    cava(p, os.path.join(args.profiles_dir, "runtime-cava-colors"))
    btop(p, os.path.join(c, "btop/themes/profile.theme"))
    hyprlock(p, os.path.join(c, "hypr/profile-colors.conf"))
    tmux(p, os.path.join(c, "tmux/profile-colors.conf"))
    fish(p, os.path.join(c, "fish/conf.d/matugen_theme.fish"))
    starship(p, os.path.join(c, "starship_matugen.toml"))
    rofi(p, os.path.join(c, "rofi/profile-switcher.rasi"))

    print(p["accent"])


main()
