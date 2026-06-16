# sharp — monotone: neutral grays + accent hues only. source_color = bright
# accent, primary = toned accent, on_primary_container = light accent; the rest
# are neutral grays. No secondary/tertiary/error hues.
set -g fish_color_normal {{colors.on_surface.default.hex}}
set -g fish_color_command {{colors.source_color.default.hex}}
set -g fish_color_keyword {{colors.primary.default.hex}}
set -g fish_color_quote {{colors.on_surface_variant.default.hex}}
set -g fish_color_redirection {{colors.on_primary_container.default.hex}}
set -g fish_color_end {{colors.on_surface_variant.default.hex}}
set -g fish_color_error {{colors.source_color.default.hex}}
set -g fish_color_param {{colors.on_surface.default.hex}}
set -g fish_color_comment {{colors.outline.default.hex}}
set -g fish_color_selection --background={{colors.surface_container_highest.default.hex}}
set -g fish_color_search_match --background={{colors.surface_container_highest.default.hex}}
set -g fish_color_operator {{colors.primary.default.hex}}
set -g fish_color_escape {{colors.on_primary_container.default.hex}}
set -g fish_color_autosuggestion {{colors.on_surface_variant.default.hex}}
