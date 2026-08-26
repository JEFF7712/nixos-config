# sharp — monotone: surface text tones + accent hues that remain readable on
# the terminal background. source_color = bright accent, primary = toned
# accent; the rest are on_surface / on_surface_variant / outline. Do not use
# on_primary / on_*_container (those go black in dark / white in light at
# matugenContrast 0.5). No secondary/tertiary/error hues.
set -g fish_color_normal {{colors.on_surface.default.hex}}
set -g fish_color_command {{colors.source_color.default.hex}}
set -g fish_color_keyword {{colors.primary.default.hex}}
set -g fish_color_quote {{colors.on_surface_variant.default.hex}}
set -g fish_color_redirection {{colors.primary.default.hex}}
set -g fish_color_end {{colors.on_surface_variant.default.hex}}
set -g fish_color_error {{colors.source_color.default.hex}}
set -g fish_color_param {{colors.on_surface.default.hex}}
set -g fish_color_comment {{colors.outline.default.hex}}
set -g fish_color_selection --background={{colors.surface_container_highest.default.hex}}
set -g fish_color_search_match --background={{colors.surface_container_highest.default.hex}}
set -g fish_color_operator {{colors.primary.default.hex}}
set -g fish_color_escape {{colors.primary.default.hex}}
set -g fish_color_autosuggestion {{colors.on_surface_variant.default.hex}}
