#!/usr/bin/env bash
# Imperative files (not HM symlinks) that hardcode /nix/store paths: those paths
# are not GC roots, so `nh clean` after an update leaves them dangling.
# ERROR = store path already gone. WARN = live path with no GC root.
set -euo pipefail

BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
DROPIN_DIR="${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}"

errors=0
warnings=0

scan_file() {
  local f=$1
  local require_shebang=$2
  local base roots root

  [ -L "$f" ] && return 0
  [ -f "$f" ] || return 0

  if [ "$require_shebang" = 1 ]; then
    head -c 2 "$f" 2>/dev/null | grep -q '#!' || return 0
  fi

  mapfile -t roots < <(
    grep -oE '/nix/store/[a-z0-9]{32}-[^/[:space:]"'\'':]+' "$f" 2>/dev/null \
      | sed -E 's#(/nix/store/[a-z0-9]{32}-[^/]+).*#\1#' \
      | sort -u
  )
  [ "${#roots[@]}" -eq 0 ] && return 0

  base="$(basename "$f")"
  if [[ "$f" == *.d/* ]]; then
    base="$(basename "$(dirname "$f")")/$(basename "$f")"
  fi

  for root in "${roots[@]}"; do
    if [ ! -e "$root" ]; then
      printf 'ERROR  %-28s -> DEAD store path %s\n' "$base" "$root"
      errors=$((errors + 1))
    else
      printf 'WARN   %-28s -> unrooted store path %s\n' "$base" "$root"
      warnings=$((warnings + 1))
    fi
  done
}

if [ -d "$BIN_DIR" ]; then
  shopt -s nullglob
  for f in "$BIN_DIR"/*; do
    scan_file "$f" 1
  done
  shopt -u nullglob
fi

# User drop-ins override HM units. Scan *.service.d/*.conf only — full
# imperative units (pod-agent etc.) are a different category.
if [ -d "$DROPIN_DIR" ]; then
  shopt -s nullglob
  for d in "$DROPIN_DIR"/*.service.d "$DROPIN_DIR"/*.timer.d "$DROPIN_DIR"/*.slice.d; do
    [ -d "$d" ] || continue
    for f in "$d"/*.conf; do
      scan_file "$f" 0
    done
  done
  shopt -u nullglob
fi

echo
if [ "$errors" -gt 0 ]; then
  echo "local-bin-rot: $errors dead reference(s), $warnings unrooted warning(s)."
  echo "Fix: remove the stale imperative file, or replace it with a home-manager"
  echo "wrapper / unit. Prefer the declarative profile binary over hardcoded store paths."
  exit 1
fi

if [ "$warnings" -gt 0 ]; then
  echo "local-bin-rot: no dead references; $warnings unrooted store reference(s)"
  echo "(will rot on the next package bump + gc). Consider migrating to uv venvs"
  echo "or a home-manager unit."
else
  echo "local-bin-rot: clean."
fi
exit 0
