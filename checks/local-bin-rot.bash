#!/usr/bin/env bash
# Detects rot in ~/.local/bin: imperative (non-symlink) scripts that hardcode a
# /nix/store path which has been (or will be) garbage-collected. This is the
# failure mode that broke the old `codex` bridge — a hand-written wrapper that
# `exec`'d a store path never registered as a GC root, so an ai-tools bump +
# `nh clean` left it dangling. Since ~/.local/bin shadows the home-manager
# profile in PATH, such rot is invisible until the command is run.
#
# HM-managed symlinks (into the current generation's store output) are skipped:
# they are rooted by the live generation and regenerate on every switch.
#
# ERROR  = referenced store path is already gone (broken right now).
# WARN   = imperative file shebangs/execs a live store path with no GC root,
#          so it will break on the next relevant package bump + GC.
set -euo pipefail

BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"

if [ ! -d "$BIN_DIR" ]; then
  echo "local-bin-rot: $BIN_DIR does not exist, nothing to check."
  exit 0
fi

errors=0
warnings=0

for f in "$BIN_DIR"/*; do
  # Only imperative regular files. Symlinks are HM out-of-store or profile-rooted.
  [ -L "$f" ] && continue
  [ -f "$f" ] || continue

  # Text files only (skip binaries dropped here by installers).
  head -c 2 "$f" 2>/dev/null | grep -q '#!' || continue

  # Collect store roots referenced anywhere in the file (shebang + exec lines).
  mapfile -t roots < <(
    grep -oE '/nix/store/[a-z0-9]{32}-[^/[:space:]"'\'':]+' "$f" 2>/dev/null \
      | sed -E 's#(/nix/store/[a-z0-9]{32}-[^/]+).*#\1#' \
      | sort -u
  )
  [ "${#roots[@]}" -eq 0 ] && continue

  base="$(basename "$f")"
  for root in "${roots[@]}"; do
    if [ ! -e "$root" ]; then
      printf 'ERROR  %-22s -> DEAD store path %s\n' "$base" "$root"
      errors=$((errors + 1))
    else
      printf 'WARN   %-22s -> unrooted store path %s\n' "$base" "$root"
      warnings=$((warnings + 1))
    fi
  done
done

echo
if [ "$errors" -gt 0 ]; then
  echo "local-bin-rot: $errors dead reference(s), $warnings unrooted warning(s)."
  echo "Fix: remove the stale imperative script, or replace it with a home-manager"
  echo "wrapper / uv venv. Prefer the declarative profile binary over ~/.local/bin."
  exit 1
fi

if [ "$warnings" -gt 0 ]; then
  echo "local-bin-rot: no dead references; $warnings unrooted store reference(s)"
  echo "(will rot on the next package bump + gc). Consider migrating to uv venvs."
else
  echo "local-bin-rot: clean."
fi
exit 0
