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
    base.update(
        {
            "fg": p["fg"],
            "bg": p["bg"],
            "popupBg": p["bg"],
            "rawBg": p["bg"],
            "accent": p["accent"],
            "second": p["dim"],
            "warm": p["yellow"],
            "fresh": p["green"],
            "dividerColor": p["surface"],
        }
    )
    w(out, json.dumps(base, indent=2) + "\n")


def kitty(p, out):
    sk = p.get("syntax_keyword", p["accent"])
    sf = p.get("syntax_func", p["green"])
    w(
        out,
        f"""# tinted (iris) — wallpaper palette, contrast-guaranteed.
cursor {p["accent"]}
cursor_text_color {p["bg"]}
foreground {p["fg"]}
background {p["bg"]}
selection_foreground {p["bg"]}
selection_background {p["accent"]}
color0  {p["surface"]}
color8  {p["dim"]}
color1  {p["red"]}
color9  {p["red"]}
color2  {p["green"]}
color10 {p["green"]}
color3  {p["yellow"]}
color11 {p["yellow"]}
color4  {p["accent"]}
color12 {p["accent"]}
color5  {sk}
color13 {sk}
color6  {sf}
color14 {sf}
color7  {p["fg"]}
color15 {p["fg"]}
""",
    )


def gtk(p, out):
    css = f"""/* tinted (iris) — wallpaper-driven */
@define-color accent_color {p["accent"]};
@define-color accent_bg_color {p["accent"]};
@define-color accent_fg_color {p["bg"]};
@define-color destructive_bg_color {p["red"]};
@define-color destructive_fg_color {p["bg"]};
@define-color error_bg_color {p["red"]};
@define-color error_fg_color {p["bg"]};
@define-color warning_bg_color {p["yellow"]};
@define-color warning_fg_color {p["bg"]};
@define-color success_bg_color {p["green"]};
@define-color success_fg_color {p["bg"]};
@define-color window_bg_color {p["bg"]};
@define-color window_fg_color {p["fg"]};
@define-color view_bg_color {p["surface"]};
@define-color view_fg_color {p["fg"]};
@define-color headerbar_bg_color {p["surface"]};
@define-color headerbar_fg_color {p["fg"]};
@define-color headerbar_backdrop_color {p["bg"]};
@define-color popover_bg_color {p["surface"]};
@define-color popover_fg_color {p["fg"]};
@define-color card_bg_color {p["surface"]};
@define-color card_fg_color {p["fg"]};
@define-color dialog_bg_color {p["surface"]};
@define-color dialog_fg_color {p["fg"]};
@define-color sidebar_bg_color {p["surface"]};
@define-color sidebar_fg_color {p["fg"]};
@define-color sidebar_backdrop_color {p["bg"]};
@define-color sidebar_border_color {p["dim"]};
@define-color secondary_sidebar_bg_color {p["bg"]};
@define-color secondary_sidebar_fg_color {p["dim"]};
"""
    for o in out:
        w(o, css)


def qt(p, out):
    active = [
        p["fg"],
        p["surface"],
        p["surface"],
        p["surface"],
        p["bg"],
        p["dim"],
        p["fg"],
        "#ffffff",
        p["fg"],
        p["bg"],
        p["bg"],
        "#000000",
        p["accent"],
        p["bg"],
        p["accent"],
        p["dim"],
        p["surface"],
        p["surface"],
        p["fg"],
        p["dim"],
        p["dim"],
        p["accent"],
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
    w(
        out,
        f"""[color]
foreground = '{p["accent"]}'
gradient = 1
gradient_color_1 = '{p["dim"]}'
gradient_color_2 = '{p["accent"]}'
gradient_color_3 = '{p["fg"]}'
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
        grad += f'theme[{grp}_start]="{p["dim"]}"\ntheme[{grp}_mid]="{p["accent"]}"\ntheme[{grp}_end]="{p["fg"]}"\n'
    w(
        out,
        f"""theme[main_bg]="{p["bg"]}"
theme[main_fg]="{p["fg"]}"
theme[title]="{p["fg"]}"
theme[hi_fg]="{p["accent"]}"
theme[selected_bg]="{p["surface"]}"
theme[selected_fg]="{p["accent"]}"
theme[inactive_fg]="{p["dim"]}"
theme[graph_text]="{p["dim"]}"
theme[meter_bg]="{p["surface"]}"
theme[proc_misc]="{p["dim"]}"
theme[cpu_box]="{p["surface"]}"
theme[mem_box]="{p["surface"]}"
theme[net_box]="{p["surface"]}"
theme[proc_box]="{p["surface"]}"
theme[div_line]="{p["surface"]}"
{grad}""",
    )


def hyprlock(p, out):
    w(
        out,
        f"""$fg = rgb({hx(p["fg"])})
$muted = rgb({hx(p["dim"])})
$accent = rgb({hx(p["accent"])})
$surface = rgba({hx(p["bg"])}ff)
$surface_alt = rgba({hx(p["surface"])}ff)
$border = rgba({hx(p["accent"])}e6)
$error = rgba({hx(p["red"])}e6)
""",
    )


def tmux(p, out):
    w(
        out,
        f"""set -g status-style "bg={p["surface"]},fg={p["fg"]}"
set -g status-left-style "fg={p["accent"]},bold"
set -g status-right-style "fg={p["dim"]}"
set -g window-status-current-style "fg={p["accent"]},bold"
set -g window-status-style "fg={p["dim"]}"
set -g pane-border-style "fg={p["surface"]}"
set -g pane-active-border-style "fg={p["accent"]}"
set -g message-style "bg={p["surface"]},fg={p["accent"]}"
set -g mode-style "bg={p["accent"]},fg={p["bg"]}"
set -g clock-mode-colour "{p["accent"]}"
""",
    )


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


def fish(p, out):
    sk = p.get("syntax_keyword", p["accent"])
    w(
        out,
        f"""set -g fish_color_normal {p["fg"]}
set -g fish_color_command {p["accent"]}
set -g fish_color_keyword {sk}
set -g fish_color_quote {p["green"]}
set -g fish_color_redirection {p["fg"]}
set -g fish_color_end {p["dim"]}
set -g fish_color_error {p["red"]}
set -g fish_color_param {p["fg"]}
set -g fish_color_comment {p["dim"]}
set -g fish_color_selection --background={p["surface"]}
set -g fish_color_search_match --background={p["surface"]}
set -g fish_color_operator {p["accent"]}
set -g fish_color_escape {p["yellow"]}
set -g fish_color_autosuggestion {p["dim"]}
""",
    )


def starship(p, out):
    w(
        out,
        f"""scan_timeout = 100
format = "$all"

[character]
success_symbol = "[❯]({p["accent"]})"
error_symbol = "[❯]({p["red"]})"

[directory]
style = "bold {p["accent"]}"

[git_branch]
style = "bold {p["green"]}"

[cmd_duration]
style = "bold {p["dim"]}"
""",
    )


def rofi(p, out):
    w(
        out,
        f"""* {{
    font:                        "Maple Mono NF 11";
    background-color:            {p["bg"]};
    text-color:                  {p["fg"]};
    border-color:                {p["surface"]};
    selected-normal-background:  {p["surface"]};
    selected-normal-foreground:  {p["accent"]};
    normal-background:           {p["bg"]};
    normal-foreground:           {p["fg"]};
}}
window {{ width: 900px; border: 0px solid; border-radius: 16px; padding: 12px; background-color: {p["bg"]}; }}
mainbox {{ spacing: 0; children: [ inputbar, listview ]; }}
inputbar {{ padding: 8px 12px; margin: 0 0 10px 0; background-color: {p["surface"]}; border-radius: 12px; children: [ prompt, entry ]; }}
prompt {{ text-color: {p["dim"]}; padding: 0 8px 0 0; }}
entry {{ text-color: {p["fg"]}; placeholder: "Switch profile…"; placeholder-color: {p["dim"]}; }}
listview {{ columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }}
element {{ orientation: vertical; padding: 10px; spacing: 8px; border-radius: 12px; background-color: {p["surface"]}; cursor: pointer; }}
element selected {{ background-color: {p["surface"]}; border: 2px solid; border-color: {p["accent"]}; }}
element-icon {{ size: 160px; border-radius: 10px; horizontal-align: 0.5; }}
element-text {{ horizontal-align: 0.5; vertical-align: 0.5; text-color: inherit; font: "Maple Mono NF 12"; }}
""",
    )


def zed(p, out):
    # Zed loads user themes from ~/.config/zed/themes/ and hot-reloads them on
    # change, so rewriting this recolors the editor live. The name ("Iris Tinted")
    # is pinned in Zed's settings by apply_zed_theme; keep the two in sync.
    fg, bg, sf, dim, ac = p["fg"], p["bg"], p["surface"], p["dim"], p["accent"]
    red, grn, ylw = p["red"], p["green"], p["yellow"]
    kw = p.get("syntax_keyword", ac)
    st = p.get("syntax_string", grn)
    fn = p.get("syntax_func", ac)
    ty = p.get("syntax_type", fg)
    co = p.get("syntax_const", ylw)
    pa = p.get("syntax_param", fg)
    op = p.get("syntax_operator", ac)
    cm = p.get("syntax_comment", dim)

    def a(c, alpha):
        return c + alpha

    style = {
        "border": a(dim, "66"),
        "border.variant": a(dim, "40"),
        "border.focused": a(ac, "cc"),
        "border.selected": a(ac, "cc"),
        "border.transparent": "#00000000",
        "border.disabled": a(dim, "40"),
        "elevated_surface.background": sf,
        "surface.background": sf,
        "background": bg,
        "element.background": a(ac, "14"),
        "element.hover": a(fg, "14"),
        "element.active": a(ac, "2b"),
        "element.selected": a(ac, "33"),
        "element.disabled": a(dim, "1f"),
        "drop_target.background": a(ac, "40"),
        "ghost_element.background": "#00000000",
        "ghost_element.hover": a(fg, "14"),
        "ghost_element.active": a(ac, "2b"),
        "ghost_element.selected": a(ac, "33"),
        "ghost_element.disabled": a(dim, "1f"),
        "text": fg,
        "text.muted": dim,
        "text.placeholder": a(dim, "cc"),
        "text.disabled": a(dim, "99"),
        "text.accent": ac,
        "icon": fg,
        "icon.muted": dim,
        "icon.disabled": a(dim, "99"),
        "icon.placeholder": dim,
        "icon.accent": ac,
        "status_bar.background": sf,
        "title_bar.background": sf,
        "title_bar.inactive_background": sf,
        "toolbar.background": bg,
        "tab_bar.background": sf,
        "tab.inactive_background": sf,
        "tab.active_background": bg,
        "search.match_background": a(ac, "4d"),
        "panel.background": bg,
        "panel.focused_border": a(ac, "cc"),
        "pane.focused_border": a(ac, "cc"),
        "pane_group.border": a(dim, "66"),
        "scrollbar.thumb.background": a(fg, "33"),
        "scrollbar.thumb.hover_background": a(fg, "4d"),
        "scrollbar.thumb.border": "#00000000",
        "scrollbar.track.background": "#00000000",
        "scrollbar.track.border": "#00000000",
        "editor.foreground": fg,
        "editor.background": bg,
        "editor.gutter.background": bg,
        "editor.subheader.background": sf,
        "editor.active_line.background": a(ac, "14"),
        "editor.highlighted_line.background": a(ac, "1f"),
        "editor.line_number": a(dim, "cc"),
        "editor.active_line_number": ac,
        "editor.invisible": a(dim, "80"),
        "editor.wrap_guide": a(dim, "40"),
        "editor.active_wrap_guide": a(dim, "80"),
        "editor.document_highlight.read_background": a(ac, "26"),
        "editor.document_highlight.write_background": a(ac, "33"),
        "terminal.background": bg,
        "terminal.foreground": fg,
        "terminal.bright_foreground": fg,
        "terminal.dim_foreground": dim,
        "terminal.ansi.black": sf,
        "terminal.ansi.bright_black": dim,
        "terminal.ansi.dim_black": sf,
        "terminal.ansi.red": red,
        "terminal.ansi.bright_red": red,
        "terminal.ansi.dim_red": a(red, "99"),
        "terminal.ansi.green": grn,
        "terminal.ansi.bright_green": grn,
        "terminal.ansi.dim_green": a(grn, "99"),
        "terminal.ansi.yellow": ylw,
        "terminal.ansi.bright_yellow": ylw,
        "terminal.ansi.dim_yellow": a(ylw, "99"),
        "terminal.ansi.blue": ac,
        "terminal.ansi.bright_blue": ac,
        "terminal.ansi.dim_blue": a(ac, "99"),
        "terminal.ansi.magenta": kw,
        "terminal.ansi.bright_magenta": kw,
        "terminal.ansi.dim_magenta": a(kw, "99"),
        "terminal.ansi.cyan": fn,
        "terminal.ansi.bright_cyan": fn,
        "terminal.ansi.dim_cyan": a(fn, "99"),
        "terminal.ansi.white": fg,
        "terminal.ansi.bright_white": fg,
        "terminal.ansi.dim_white": dim,
        "link_text.hover": ac,
        "conflict": ylw,
        "conflict.background": a(ylw, "1f"),
        "created": grn,
        "created.background": a(grn, "1f"),
        "deleted": red,
        "deleted.background": a(red, "1f"),
        "error": red,
        "error.background": a(red, "1f"),
        "hidden": dim,
        "hint": a(dim, "cc"),
        "ignored": dim,
        "info": ac,
        "info.background": a(ac, "1f"),
        "modified": ylw,
        "modified.background": a(ylw, "1f"),
        "predictive": a(dim, "cc"),
        "renamed": ac,
        "success": grn,
        "unreachable": dim,
        "warning": ylw,
        "warning.background": a(ylw, "1f"),
        "players": [
            {"cursor": ac, "background": ac, "selection": a(ac, "40")},
            {"cursor": grn, "background": grn, "selection": a(grn, "40")},
            {"cursor": ylw, "background": ylw, "selection": a(ylw, "40")},
        ],
        "syntax": {
            "comment": {"color": cm, "font_style": "italic"},
            "comment.doc": {"color": cm, "font_style": "italic"},
            "keyword": {"color": kw, "font_weight": 700},
            "keyword.import": {"color": kw, "font_weight": 700},
            "operator": {"color": op},
            "punctuation": {"color": a(fg, "cc")},
            "punctuation.bracket": {"color": a(fg, "cc")},
            "punctuation.delimiter": {"color": a(fg, "cc")},
            "punctuation.special": {"color": op},
            "punctuation.list_marker": {"color": op},
            "string": {"color": st},
            "string.escape": {"color": co},
            "string.regex": {"color": co},
            "string.special": {"color": co},
            "string.special.symbol": {"color": co},
            "number": {"color": co},
            "boolean": {"color": co},
            "constant": {"color": co},
            "type": {"color": ty},
            "type.builtin": {"color": ty},
            "function": {"color": fn},
            "function.method": {"color": fn},
            "function.builtin": {"color": fn},
            "constructor": {"color": ty},
            "variable": {"color": fg},
            "variable.special": {"color": pa},
            "variable.member": {"color": pa},
            "property": {"color": pa},
            "attribute": {"color": kw},
            "tag": {"color": kw},
            "label": {"color": op},
            "embedded": {"color": fg},
            "emphasis": {"color": fg, "font_style": "italic"},
            "emphasis.strong": {"color": fg, "font_weight": 700},
            "title": {"color": ac, "font_weight": 700},
            "link_uri": {"color": ac},
            "link_text": {"color": st, "font_style": "italic"},
            "predictive": {"color": a(dim, "cc"), "font_style": "italic"},
            "hint": {"color": a(dim, "cc"), "font_style": "italic"},
            "variant": {"color": co},
            "enum": {"color": ty},
        },
    }
    theme = {
        "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
        "name": "Iris",
        "author": "iris (wallpaper-driven, tinted profile)",
        "themes": [
            {
                "name": "Iris Tinted",
                "appearance": "dark" if p.get("dark", True) else "light",
                "style": style,
            }
        ],
    }
    w(out, json.dumps(theme, indent=2) + "\n")


def spicetify_comfy(p, out):
    body = f"""text               = {hx(p["fg"])}
subtext            = {hx(p["dim"])}
main               = {hx(p["bg"])}
main-elevated      = {hx(p["surface"])}
main-transition    = {hx(p["bg"])}
highlight          = {hx(p["surface"])}
highlight-elevated = {hx(p["surface"])}
sidebar            = {hx(p["bg"])}
player             = {hx(p["bg"])}
card               = {hx(p["surface"])}
shadow             = {hx(p["bg"])}
selected-row       = {hx(p["fg"])}
button             = {hx(p["accent"])}
button-active      = {hx(p["accent"])}
button-disabled    = {hx(p["dim"])}
tab-active         = {hx(p["surface"])}
notification       = {hx(p["accent"])}
notification-error = {hx(p["red"])}
misc               = 000000
play-button        = {hx(p["accent"])}
play-button-active = {hx(p["accent"])}
progress-fg        = {hx(p["accent"])}
progress-bg        = {hx(p["dim"])}
heart              = {hx(p["red"])}
pagelink-active    = {hx(p["surface"])}
radio-btn-active   = {hx(p["accent"])}
"""
    update_ini_section(out, "tinted", body)


def hex_to_hsl(hexc):
    hexc = hexc.lstrip("#")
    r, g, b = (int(hexc[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
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
    # Monotone chrome: collapse the lighter surface tone onto the body bg so the
    # tab strip / sidebars / borders all read as a single flat olive.
    p = {**p, "surface": p["bg"]}
    # Soft hairline for pane/tab dividers: dim blended most of the way toward the
    # bg so the separators read as a faint hairline rather than a hard line.
    soft = f"color-mix(in srgb, {p['dim']} 32%, {p['bg']})"
    h, s, ll = hex_to_hsl(p["accent"])
    css = f""".theme-dark, .theme-light {{
  --background-primary: {p["bg"]};
  --background-primary-alt: {p["surface"]};
  --background-secondary: {p["surface"]};
  --background-secondary-alt: {p["bg"]};
  --background-modifier-border: {p["surface"]};
  --background-modifier-border-hover: {p["dim"]};
  --background-modifier-border-focus: {p["accent"]};
  --text-normal: {p["fg"]};
  --text-muted: {p["dim"]};
  --text-faint: {p["dim"]};
  --icon-color: {p["fg"]};
  --icon-color-hover: {p["accent"]};
  --icon-color-active: {p["accent"]};
  --icon-color-focused: {p["fg"]};
  --icon-opacity: 0.8;
  --icon-opacity-hover: 1;
  --icon-opacity-active: 1;
  --text-accent: {p["accent"]};
  --text-accent-hover: {p["accent"]};
  --text-on-accent: {p["bg"]};
  --interactive-accent: {p["accent"]};
  --interactive-accent-hover: {p["accent"]};
  --interactive-normal: {p["surface"]};
  --interactive-hover: {p["surface"]};
  --titlebar-background: {p["surface"]};
  --titlebar-background-focused: {p["surface"]};
  --titlebar-text-color: {p["dim"]};
  --titlebar-text-color-focused: {p["fg"]};
  --titlebar-text-color-highlighted: {p["fg"]};
  --tab-container-background: {p["surface"]};
  --tab-background-active: {p["bg"]};
  --tab-text-color: color-mix(in srgb, {p["fg"]} 70%, {p["bg"]});
  /* Minimal resolves tab/icon text from its own tokens at a more specific
     scope (.workspace-tabs), so the Obsidian-core vars above never reach the
     tab labels. Override Minimal's tokens too. */
  --minimal-tab-text-color: color-mix(in srgb, {p["fg"]} 70%, {p["bg"]});
  --minimal-tab-text-color-active: {p["fg"]};
  --tab-text-color-active: {p["fg"]};
  --tab-text-color-focused-active: {p["fg"]};
  --tab-text-color-focused-active-current: {p["fg"]};
  --tab-outline-color: {soft};
  --ribbon-background: {p["surface"]};
  --ribbon-background-collapsed: {p["surface"]};
  --background-translucent: {p["surface"]};
  --divider-color: {p["surface"]};
  --accent-h: {h};
  --accent-s: {s}%;
  --accent-l: {ll}%;
  --color-red: {p["red"]};
  --color-green: {p["green"]};
  --color-yellow: {p["yellow"]};
}}
/* Only the window-frame strip (`.titlebar`, a <body> child outside
   .app-container). It is a fixed, full-width overlay (z-index 30) that sits ON
   TOP of the workspace tab bar, so giving it an opaque background hides the
   tabs underneath. Keep it transparent — the tab-header container behind it is
   already `surface` (via --tab-container-background), so the strip still reads
   as surface while the tabs show through. */
.titlebar,
.titlebar-inner {{
  background-color: transparent !important;
}}
/* Minimal leaves the tab-header container transparent and lets the titlebar
   show through as the strip colour. Now that the titlebar is transparent, the
   strip needs its own surface fill (otherwise the area beside the tabs and
   behind the window controls falls through to black). */
.workspace-tab-header-container,
.workspace-split.mod-root > .workspace-tabs.mod-top > .workspace-tab-header-container {{
  background-color: {p["surface"]} !important;
}}
/* Monotone collapses the sidebars into the body; add a divider so they read as
   separate panes (matches the clean profile). */
.workspace-split.mod-left-split {{
  border-right: 0.5px solid {soft} !important;
}}
.workspace-split.mod-right-split {{
  border-left: 0.5px solid {soft} !important;
}}
.titlebar-text {{
  color: {p["dim"]} !important;
}}
.titlebar .titlebar-button {{
  color: {p["fg"]} !important;
}}
/* Minimal fades the header chrome (tab-bar nav arrows, sidebar toggles, the
   per-view action icons top-right) toward the background and only reveals them
   on hover. On the tinted dark palette that leaves them invisible, so force a
   legible color + opacity for the whole top strip. */
.workspace-tab-header-container .clickable-icon,
.workspace-tab-header-spacer ~ .clickable-icon,
.clickable-icon.sidebar-toggle-button,
.sidebar-toggle-button,
.view-header .clickable-icon,
.view-actions .clickable-icon,
.titlebar .clickable-icon {{
  color: {p["fg"]} !important;
  opacity: 0.85 !important;
}}
.workspace-tab-header-container .clickable-icon:hover,
.clickable-icon.sidebar-toggle-button:hover,
.sidebar-toggle-button:hover,
.view-header .clickable-icon:hover,
.view-actions .clickable-icon:hover,
.titlebar .clickable-icon:hover {{
  color: {p["accent"]} !important;
  opacity: 1 !important;
}}
/* Tab labels: Minimal mutes inactive tabs to near-background and only reveals
   text on hover. Force both the title visible and a legible outline so the tab
   shape reads against the bar. */
.workspace-tab-header .workspace-tab-header-inner-title {{
  color: color-mix(in srgb, {p["fg"]} 70%, {p["bg"]}) !important;
}}
.workspace-tab-header.is-active .workspace-tab-header-inner-title,
.workspace-tab-header.mod-active .workspace-tab-header-inner-title {{
  color: {p["fg"]} !important;
}}
.workspace-tab-header.is-active,
.workspace-tab-header.mod-active {{
  outline: 0.5px solid {soft} !important;
  border-radius: 6px;
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
    if "code-blocks" not in snaps:
        snaps.append("code-blocks")
    a["enabledCssSnippets"] = snaps
    a["textFontFamily"] = "Newsreader"
    a["interfaceFontFamily"] = "IBM Plex Sans"
    a["monospaceFontFamily"] = "IBM Plex Mono"
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
    zathura(p, os.path.join(c, "zathura/colors"))
    fish(p, os.path.join(c, "fish/conf.d/matugen_theme.fish"))
    starship(p, os.path.join(c, "starship_matugen.toml"))
    rofi(p, os.path.join(c, "rofi/profile-switcher.rasi"))
    zed(p, os.path.join(c, "zed/themes/iris.json"))
    spicetify_comfy(p, os.path.join(c, "spicetify/Themes/Comfy/color.ini"))
    obsidian(p, args.obsidian_vault)


main()
