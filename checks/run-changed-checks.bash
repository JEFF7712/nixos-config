#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

declare -A selected=()
declare -A changed=()
full=0
list_only=0

add() {
  selected["$1"]=1
}

classify() {
  local path=$1

  case "$path" in
    flake.nix | flake.lock | */flake.nix | */flake.lock | justfile | treefmt.nix | treefmt.toml | \
      .github/workflows/* | checks/* | hooks/* | .claude/* | .codex/* | .cursor/*)
      full=1
      return
      ;;
    AGENT_MAP.md | AGENTS.md | CLAUDE.md | MODEL-ROUTING.md | RTK.md | \
      docs/agent-self-improvement.md)
      add check-agent-docs
      ;;
    README.md | docs/* | *.md | .gitignore | LICENSE*)
      ;;
    home/configs/quickshell/* | home/configs/quickshell-*/* | *.qml)
      add qml-lint
      add quickshell-test
      add 'eval laptop'
      ;;
    home/scripts/lid-close-action)
      add shell-check
      add lid-close-check
      ;;
    home/scripts/profile-* | home/scripts/switch-profile | home/scripts/toggle-variant | \
      home/scripts/random-wallpaper | home/scripts/waypaper-backend-sync | \
      home/scripts/lock-screen | home/scripts/iris.py | home/scripts/iris-render.py | \
      home/scripts/temperature-render.py | home/scripts/merge-ini-section.py)
      add shell-check
      add wallpaper-script-check
      add check-profiles
      ;;
    home/scripts/*)
      add shell-check
      ;;
    hosts/laptop-crypt/* | home/rupan/laptop-crypt.nix)
      add fmt-check
      add 'eval laptop-crypt'
      ;;
    hosts/laptop/base.nix)
      add fmt-check
      add eval-vm
      add 'eval laptop'
      ;;
    hosts/iso/* | home/rupan/iso.nix)
      add fmt-check
      add build-iso
      add 'eval iso'
      ;;
    hosts/laptop/* | home/rupan/laptop.nix)
      add fmt-check
      add 'eval laptop'
      ;;
    modules/home-manager/profiles/* | modules/home-manager/desktop-profiles.nix | \
      lib/desktop-profiles/* | home/configs/matugen/* | home/configs/obsidian/*.tmpl)
      add fmt-check
      add check-profiles
      add 'eval laptop'
      ;;
    modules/nixos/xhisper-local.nix | pkgs/xhisper-local/* | home/configs/xhisper/*)
      add xhisper-check
      add 'eval laptop'
      ;;
    pkgs/* | overlays/*)
      add fmt-check
      add 'build laptop'
      ;;
    modules/nixos/* | modules/home-manager/*)
      add fmt-check
      add 'eval laptop'
      ;;
    home/rupan/home.nix | *.nix)
      add fmt-check
      add eval-all
      ;;
    *)
      full=1
      ;;
  esac
}

collect_worktree_files() {
  local path

  if [ -n "${CHECK_CHANGED_BASE:-}" ]; then
    if ! git rev-parse --verify --quiet "${CHECK_CHANGED_BASE}^{commit}" >/dev/null \
      || ! git merge-base "${CHECK_CHANGED_BASE}" HEAD >/dev/null; then
      printf 'check-changed: invalid Git base: %s\n' "$CHECK_CHANGED_BASE" >&2
      exit 1
    fi
  fi

  while IFS= read -r -d '' path; do
    changed["$path"]=1
  done < <(
    git diff --no-ext-diff --name-only -z
    git diff --no-ext-diff --cached --name-only -z
    git ls-files --others --exclude-standard -z
    if [ -n "${CHECK_CHANGED_BASE:-}" ]; then
      git diff --no-ext-diff --name-only -z "${CHECK_CHANGED_BASE}...HEAD"
    fi
  )
}

case "${1:-}" in
  --list)
    list_only=1
    shift
    for path in "$@"; do
      changed["$path"]=1
    done
    ;;
  --list-changed)
    list_only=1
    collect_worktree_files
    ;;
  *)
    collect_worktree_files
    ;;
esac

for path in "${!changed[@]}"; do
  classify "$path"
done

if [ "$full" -eq 1 ]; then
  commands=(check)
else
  commands=()
  for command in \
    check-agent-docs \
    check-agent-workflows \
    fmt-check \
    shell-check \
    lid-close-check \
    wallpaper-script-check \
    xhisper-check \
    qml-lint \
    quickshell-test \
    'build laptop' \
    build-iso \
    eval-vm \
    'eval laptop' \
    'eval laptop-crypt' \
    'eval iso' \
    eval-all \
    check-profiles; do
    if [ -n "${selected[$command]:-}" ]; then
      commands+=("$command")
    fi
  done
  commands+=(diff-check)
fi

if [ "$list_only" -eq 1 ]; then
  printf '%s\n' "${commands[@]}"
  exit 0
fi

for command in "${commands[@]}"; do
  printf '\n==> %s\n' "$command"
  case "$command" in
    'build laptop') just build laptop ;;
    build-iso) just build-iso ;;
    eval-vm) just eval-vm ;;
    'eval laptop') just eval laptop ;;
    'eval laptop-crypt') just eval laptop-crypt ;;
    'eval iso') just eval iso ;;
    diff-check) just diff-check "${CHECK_CHANGED_BASE:-}" ;;
    *) just "$command" ;;
  esac
done
