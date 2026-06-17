#!/usr/bin/env python3
# iris-render — map an iris JSON palette onto every consumer the desktop-profile
# system themes. Reads the JSON on stdin, writes the live runtime files (the
# same locations the matugen pipeline targets) so the rest of apply_wallpaper_theme
# (reloads, cava swap, bar restart) is engine-agnostic. Plain stdlib only.
import argparse
import json
import os
import sys


def hx(c):
    return c.lstrip("#")


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text)


def update_ini_section(path, section, body):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    header = f"[{section}]"
    lines = []
    if os.path.exists(path):
        with open(path) as fh:
            lines = fh.read().splitlines()

    out = []
    in_section = False
    for line in lines:
        if line.startswith("[") and line.endswith("]"):
            in_section = line == header
            if in_section:
                continue
        if not in_section:
            out.append(line)

    while out and out[-1] == "":
        out.pop()

    if out:
        out.append("")
    out.extend([header, *body.rstrip().splitlines()])
    w(path, "\n".join(out) + "\n")


def quickshell(p, profile_dir, out):
    # Seed style keys (barFont, barHeight, flatMode, ...) from the baked theme,
    # override only the colors so the profile stays the single source of style.
    base = {}
    baked = os.path.join(profile_dir, "quickshell-theme.json")
    try:
        with open(baked) as fh:
            base = json.load(fh)
    except Exception:
        pass
    base.update({
        "fg": p["fg"],
        "bg": p["bg"],
        "popupBg": p["surface"],
        "rawBg": p["bg"],
        "accent": p["accent"],
        "second": p["dim"],
        "warm": p["yellow"],
        "fresh": p["green"],
        "dividerColor": p["surface"],
    })
    w(out, json.dumps(base, indent=2) + "\n")


def kitty(p, out):
    sk = p.get("syntax_keyword", p["accent"])
    sf = p.get("syntax_func", p["green"])
    w(out, f"""# tinted (iris) — wallpaper palette, contrast-guaranteed.
cursor {p['accent']}
cursor_text_color {p['bg']}
foreground {p['fg']}
background {p['bg']}
selection_foreground {p['bg']}
selection_background {p['accent']}
color0  {p['surface']}
color8  {p['dim']}
color1  {p['red']}
color9  {p['red']}
color2  {p['green']}
color10 {p['green']}
color3  {p['yellow']}
color11 {p['yellow']}
color4  {p['accent']}
color12 {p['accent']}
color5  {sk}
color13 {sk}
color6  {sf}
color14 {sf}
color7  {p['fg']}
color15 {p['fg']}
""")


def gtk(p, out):
    css = f"""/* tinted (iris) — wallpaper-driven */
@define-color accent_color {p['accent']};
@define-color accent_bg_color {p['accent']};
@define-color accent_fg_color {p['bg']};
@define-color destructive_bg_color {p['red']};
@define-color destructive_fg_color {p['bg']};
@define-color error_bg_color {p['red']};
@define-color error_fg_color {p['bg']};
@define-color warning_bg_color {p['yellow']};
@define-color warning_fg_color {p['bg']};
@define-color success_bg_color {p['green']};
@define-color success_fg_color {p['bg']};
@define-color window_bg_color {p['bg']};
@define-color window_fg_color {p['fg']};
@define-color view_bg_color {p['surface']};
@define-color view_fg_color {p['fg']};
@define-color headerbar_bg_color {p['surface']};
@define-color headerbar_fg_color {p['fg']};
@define-color headerbar_backdrop_color {p['bg']};
@define-color popover_bg_color {p['surface']};
@define-color popover_fg_color {p['fg']};
@define-color card_bg_color {p['surface']};
@define-color card_fg_color {p['fg']};
@define-color dialog_bg_color {p['surface']};
@define-color dialog_fg_color {p['fg']};
@define-color sidebar_bg_color {p['surface']};
@define-color sidebar_fg_color {p['fg']};
@define-color sidebar_backdrop_color {p['bg']};
@define-color sidebar_border_color {p['dim']};
@define-color secondary_sidebar_bg_color {p['bg']};
@define-color secondary_sidebar_fg_color {p['dim']};
"""
    for o in out:
        w(o, css)


def qt(p, out):
    active = [
        p["fg"], p["surface"], p["surface"], p["surface"], p["bg"], p["dim"],
        p["fg"], "#ffffff", p["fg"], p["bg"], p["bg"], "#000000",
        p["accent"], p["bg"], p["accent"], p["dim"], p["surface"], p["surface"],
        p["fg"], p["dim"], p["dim"], p["accent"],
    ]
    disabled = list(active)
    disabled[0] = disabled[6] = disabled[8] = disabled[12] = p["dim"]
    disabled[13] = p["bg"]
    inactive = list(active)
    body = "[ColorScheme]\nactive_colors={a}\ndisabled_colors={d}\ninactive_colors={i}\n".format(
        a=", ".join(active), d=", ".join(disabled), i=", ".join(inactive)
    )
    for o in out:
        w(o, body)


def cava(p, out):
    w(out, f"""[color]
foreground = '{p['accent']}'
gradient = 1
gradient_color_1 = '{p['dim']}'
gradient_color_2 = '{p['accent']}'
gradient_color_3 = '{p['fg']}'
""")


def btop(p, out):
    grad = ""
    for grp in ["temp", "cpu", "free", "cached", "available", "used", "download", "upload", "process"]:
        grad += f'theme[{grp}_start]="{p["dim"]}"\ntheme[{grp}_mid]="{p["accent"]}"\ntheme[{grp}_end]="{p["fg"]}"\n'
    w(out, f"""theme[main_bg]="{p['bg']}"
theme[main_fg]="{p['fg']}"
theme[title]="{p['fg']}"
theme[hi_fg]="{p['accent']}"
theme[selected_bg]="{p['surface']}"
theme[selected_fg]="{p['accent']}"
theme[inactive_fg]="{p['dim']}"
theme[graph_text]="{p['dim']}"
theme[meter_bg]="{p['surface']}"
theme[proc_misc]="{p['dim']}"
theme[cpu_box]="{p['surface']}"
theme[mem_box]="{p['surface']}"
theme[net_box]="{p['surface']}"
theme[proc_box]="{p['surface']}"
theme[div_line]="{p['surface']}"
{grad}""")


def hyprlock(p, out):
    w(out, f"""$fg = rgb({hx(p['fg'])})
$muted = rgb({hx(p['dim'])})
$accent = rgb({hx(p['accent'])})
$surface = rgba({hx(p['bg'])}ff)
$surface_alt = rgba({hx(p['surface'])}ff)
$border = rgba({hx(p['accent'])}e6)
$error = rgba({hx(p['red'])}e6)
""")


def tmux(p, out):
    w(out, f"""set -g status-style "bg={p['surface']},fg={p['fg']}"
set -g status-left-style "fg={p['accent']},bold"
set -g status-right-style "fg={p['dim']}"
set -g window-status-current-style "fg={p['accent']},bold"
set -g window-status-style "fg={p['dim']}"
set -g pane-border-style "fg={p['surface']}"
set -g pane-active-border-style "fg={p['accent']}"
set -g message-style "bg={p['surface']},fg={p['accent']}"
set -g mode-style "bg={p['accent']},fg={p['bg']}"
set -g clock-mode-colour "{p['accent']}"
""")


def fish(p, out):
    sk = p.get("syntax_keyword", p["accent"])
    w(out, f"""set -g fish_color_normal {p['fg']}
set -g fish_color_command {p['accent']}
set -g fish_color_keyword {sk}
set -g fish_color_quote {p['green']}
set -g fish_color_redirection {p['fg']}
set -g fish_color_end {p['dim']}
set -g fish_color_error {p['red']}
set -g fish_color_param {p['fg']}
set -g fish_color_comment {p['dim']}
set -g fish_color_selection --background={p['surface']}
set -g fish_color_search_match --background={p['surface']}
set -g fish_color_operator {p['accent']}
set -g fish_color_escape {p['yellow']}
set -g fish_color_autosuggestion {p['dim']}
""")


def starship(p, out):
    w(out, f"""format = "$all"

[character]
success_symbol = "[❯]({p['accent']})"
error_symbol = "[❯]({p['red']})"

[directory]
style = "bold {p['accent']}"

[git_branch]
style = "bold {p['green']}"

[cmd_duration]
style = "bold {p['dim']}"
""")


def rofi(p, out):
    w(out, f"""* {{
    font:                        "Maple Mono NF 11";
    background-color:            {p['bg']};
    text-color:                  {p['fg']};
    border-color:                {p['surface']};
    selected-normal-background:  {p['surface']};
    selected-normal-foreground:  {p['accent']};
    normal-background:           {p['bg']};
    normal-foreground:           {p['fg']};
}}
window {{ width: 900px; border: 0px solid; border-radius: 16px; padding: 12px; background-color: {p['bg']}; }}
mainbox {{ spacing: 0; children: [ inputbar, listview ]; }}
inputbar {{ padding: 8px 12px; margin: 0 0 10px 0; background-color: {p['surface']}; border-radius: 12px; children: [ prompt, entry ]; }}
prompt {{ text-color: {p['dim']}; padding: 0 8px 0 0; }}
entry {{ text-color: {p['fg']}; placeholder: "Switch profile…"; placeholder-color: {p['dim']}; }}
listview {{ columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }}
element {{ orientation: vertical; padding: 10px; spacing: 8px; border-radius: 12px; background-color: {p['surface']}; cursor: pointer; }}
element selected {{ background-color: {p['surface']}; border: 2px solid; border-color: {p['accent']}; }}
element-icon {{ size: 160px; border-radius: 10px; horizontal-align: 0.5; }}
element-text {{ horizontal-align: 0.5; vertical-align: 0.5; text-color: inherit; font: "Maple Mono NF 12"; }}
""")


def spicetify_comfy(p, out):
    body = f"""text               = {hx(p['fg'])}
subtext            = {hx(p['dim'])}
main               = {hx(p['bg'])}
main-elevated      = {hx(p['surface'])}
main-transition    = {hx(p['bg'])}
highlight          = {hx(p['surface'])}
highlight-elevated = {hx(p['surface'])}
sidebar            = {hx(p['bg'])}
player             = {hx(p['bg'])}
card               = {hx(p['surface'])}
shadow             = {hx(p['bg'])}
selected-row       = {hx(p['fg'])}
button             = {hx(p['accent'])}
button-active      = {hx(p['accent'])}
button-disabled    = {hx(p['dim'])}
tab-active         = {hx(p['surface'])}
notification       = {hx(p['accent'])}
notification-error = {hx(p['red'])}
misc               = 000000
play-button        = {hx(p['accent'])}
play-button-active = {hx(p['accent'])}
progress-fg        = {hx(p['accent'])}
progress-bg        = {hx(p['dim'])}
heart              = {hx(p['red'])}
pagelink-active    = {hx(p['surface'])}
radio-btn-active   = {hx(p['accent'])}
"""
    update_ini_section(out, "tinted", body)


def hex_to_hsl(hexc):
    hexc = hexc.lstrip("#")
    r, g, b = (int(hexc[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2.0
    if mx == mn:
        return 0, 0, round(l * 100)
    d = mx - mn
    s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = ((g - b) / d + (6.0 if g < b else 0.0)) / 6.0
    elif mx == g:
        h = ((b - r) / d + 2.0) / 6.0
    else:
        h = ((r - g) / d + 4.0) / 6.0
    return round(h * 360), round(s * 100), round(l * 100)


def obsidian(p, vault):
    # Recolor Obsidian (Minimal theme) via a CSS snippet that overrides the
    # standard Obsidian variables, and sync the native accent + light/dark mode.
    if not vault or not os.path.isdir(vault):
        return
    h, s, ll = hex_to_hsl(p["accent"])
    css = f""".theme-dark, .theme-light {{
  --background-primary: {p['bg']};
  --background-primary-alt: {p['surface']};
  --background-secondary: {p['surface']};
  --background-secondary-alt: {p['bg']};
  --background-modifier-border: {p['surface']};
  --background-modifier-border-hover: {p['dim']};
  --background-modifier-border-focus: {p['accent']};
  --text-normal: {p['fg']};
  --text-muted: {p['dim']};
  --text-faint: {p['dim']};
  --text-accent: {p['accent']};
  --text-accent-hover: {p['accent']};
  --text-on-accent: {p['bg']};
  --interactive-accent: {p['accent']};
  --interactive-accent-hover: {p['accent']};
  --interactive-normal: {p['surface']};
  --interactive-hover: {p['surface']};
  --titlebar-background: {p['surface']};
  --titlebar-background-focused: {p['surface']};
  --titlebar-text-color: {p['dim']};
  --titlebar-text-color-focused: {p['fg']};
  --titlebar-text-color-highlighted: {p['fg']};
  --tab-container-background: {p['surface']};
  --tab-background-active: {p['bg']};
  --tab-text-color: {p['dim']};
  --tab-text-color-active: {p['fg']};
  --tab-text-color-focused-active: {p['fg']};
  --tab-text-color-focused-active-current: {p['fg']};
  --tab-outline-color: {p['surface']};
  --ribbon-background: {p['surface']};
  --ribbon-background-collapsed: {p['surface']};
  --background-translucent: {p['surface']};
  --divider-color: {p['surface']};
  --accent-h: {h};
  --accent-s: {s}%;
  --accent-l: {ll}%;
  --color-red: {p['red']};
  --color-green: {p['green']};
  --color-yellow: {p['yellow']};
}}
/* Only the window-frame strip (`.titlebar`, a <body> child outside
   .app-container) needs forcing — it defaults to black. The workspace tabs are
   left to Minimal so its own tab rendering/settings keep working. */
.titlebar,
.titlebar-inner {{
  background-color: {p['surface']} !important;
}}
.titlebar-text {{
  color: {p['dim']} !important;
}}
.titlebar .titlebar-button {{
  color: {p['fg']} !important;
}}
"""
    snippets = os.path.join(vault, "snippets")
    os.makedirs(snippets, exist_ok=True)
    with open(os.path.join(snippets, "tinted.css"), "w") as fh:
        fh.write(css)

    app = os.path.join(vault, "appearance.json")
    try:
        with open(app) as fh:
            a = json.load(fh)
    except Exception:
        a = {}
    snaps = a.get("enabledCssSnippets", [])
    if "tinted" not in snaps:
        snaps.append("tinted")
    a["enabledCssSnippets"] = snaps
    a["accentColor"] = p["accent"]
    a["theme"] = "obsidian" if p.get("dark", True) else "moonstone"
    tmp = app + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(a, fh, indent=2)
    os.replace(tmp, app)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config-home", required=True)
    ap.add_argument("--profiles-dir", required=True)
    ap.add_argument("--profile-dir", required=True)
    ap.add_argument("--obsidian-vault", default=None)
    args = ap.parse_args()

    p = json.load(sys.stdin)
    c = args.config_home

    quickshell(p, args.profile_dir, os.path.join(args.profiles_dir, "runtime-quickshell-theme.json"))
    kitty(p, os.path.join(c, "kitty/colors.conf"))
    gtk(p, [os.path.join(c, "gtk-3.0/noctalia.css"), os.path.join(c, "gtk-4.0/noctalia.css")])
    qt(p, [os.path.join(c, "qt6ct/colors/noctalia.conf"), os.path.join(c, "qt5ct/colors/noctalia.conf")])
    cava(p, os.path.join(args.profiles_dir, "runtime-cava-colors"))
    btop(p, os.path.join(c, "btop/themes/profile.theme"))
    hyprlock(p, os.path.join(c, "hypr/profile-colors.conf"))
    tmux(p, os.path.join(c, "tmux/profile-colors.conf"))
    fish(p, os.path.join(c, "fish/conf.d/matugen_theme.fish"))
    starship(p, os.path.join(c, "starship_matugen.toml"))
    rofi(p, os.path.join(c, "rofi/profile-switcher.rasi"))
    spicetify_comfy(p, os.path.join(c, "spicetify/Themes/Comfy/color.ini"))
    obsidian(p, args.obsidian_vault)


main()
