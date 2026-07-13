#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
profiles="$home/.config/desktop-profiles"
bin_dir="$tmpdir/bin"
log="$tmpdir/commands.log"
real_jq="$(command -v jq)"

assert_eq() {
  local expected="$1" actual="$2" label="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_log_contains() {
  local pattern="$1" label="$2"

  if ! grep -Fq -- "$pattern" "$log"; then
    printf 'FAIL: %s\nmissing log entry: %s\n' "$label" "$pattern" >&2
    exit 1
  fi
}

check_public_delegation() {
  local adapter_dir="$tmpdir/public-adapters"
  local mapping public_invocation engine_invocation public_command

  mkdir -p "$adapter_dir"
  cp "$REPO_ROOT/home/scripts/switch-profile" "$adapter_dir/switch-profile"
  cp "$REPO_ROOT/home/scripts/toggle-variant" "$adapter_dir/toggle-variant"
  : > "$adapter_dir/profile-common"
  cat > "$adapter_dir/profile-transition" <<'EOF'
#!/usr/bin/env bash
printf 'profile-transition %s\n' "$*" >> "$COMMAND_LOG"
EOF
  chmod +x "$adapter_dir/profile-transition"

  for mapping in "${COMPATIBILITY_MAPPINGS[@]}"; do
    IFS='|' read -r public_invocation engine_invocation <<< "$mapping"
    read -r -a public_command <<< "$public_invocation"
    : > "$log"
    HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" \
      "$adapter_dir/${public_command[0]}" "${public_command[@]:1}" >/dev/null 2>&1 || true
    assert_eq "$engine_invocation" "$(cat "$log")" \
      "$public_invocation delegates its mutation to the transition engine"
  done
}

mkdir -p "$profiles" "$bin_dir" "$home/.config/waybar"

for profile in old new; do
  profile_dir="$profiles/$profile"
  wallpaper_dir="$profile_dir/wallpapers"
  mkdir -p "$wallpaper_dir"
  printf '{"bar":"waybar","selfThemed":false,"hasLightVariant":true,"cursor":"default","cursorSize":24}\n' \
    > "$profile_dir/meta.json"
  printf '{}\n' > "$profile_dir/runtime.json"
  printf 'old-or-new-dark\n' > "$profile_dir/kitty-colors.conf"
  printf 'old-or-new-light\n' > "$profile_dir/kitty-colors-light.conf"
  printf 'layout { gaps 8; }\n' > "$profile_dir/niri-overrides.kdl"
  printf '{}\n' > "$profile_dir/waybar-config.jsonc"
  printf '* { color: #ffffff; }\n' > "$profile_dir/waybar-style.css"
  printf '* { color: #000000; }\n' > "$profile_dir/waybar-style-light.css"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir-light"
  touch "$wallpaper_dir/wallpaper.png"
done

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-old"
printf 'light\n' > "$profiles/variant-new"
ln -s "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"

for command in systemctl niri pkill quickshell waybar gsettings notify-send busctl; do
  cat > "$bin_dir/$command" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$COMMAND_LOG"
case "$(basename "$0") $*" in
  "systemctl --user is-active"*) printf 'active\n' ;;
esac
EOF
done

cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf 'pgrep %s active=%s\n' "$*" "$active" >> "$COMMAND_LOG"
exit 0
EOF

cat > "$bin_dir/jq" <<'EOF'
#!/usr/bin/env bash
printf 'jq %s\n' "$*" >> "$COMMAND_LOG"
exec "$REAL_JQ" "$@"
EOF

chmod +x "$bin_dir"/*
: > "$log"

# Public mutation interfaces that later compatibility tests must enforce.
COMPATIBILITY_MAPPINGS=(
  'switch-profile new|profile-transition switch new'
  'switch-profile --reapply|profile-transition reapply'
  'switch-profile --startup|profile-transition startup'
  'toggle-variant light|profile-transition variant light'
  'toggle-variant|profile-transition variant toggle'
)
readonly -a COMPATIBILITY_MAPPINGS

HOME="$home" \
XDG_CONFIG_HOME="$home/.config" \
PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" \
COMMAND_LOG="$log" \
REAL_JQ="$real_jq" \
PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/profile-transition" switch new

assert_eq "new" "$(cat "$profiles/active")" "target profile is committed"
assert_eq "light" "$(cat "$profiles/active-variant")" "stored target variant is restored"
assert_eq "light" "$(cat "$profiles/variant-new")" "target variant preference is persisted"
assert_eq "$profiles/new/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "Niri override points to the target profile"
assert_log_contains "pgrep -f waybar active=old" "target bar is verified before active profile commit"
check_public_delegation
