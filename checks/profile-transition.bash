#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"

home="$tmpdir/home"
profiles="$home/.config/desktop-profiles"
bin_dir="$tmpdir/bin"
log="$tmpdir/commands.log"
real_jq="$(command -v jq)"
bar_state="$tmpdir/bar.state"
notification_state="$tmpdir/notification.state"
persistent_pid_dir="$tmpdir/persistent-pids"
export PROFILE_THEME_SELECTOR="$REPO_ROOT/home/scripts/select-quickshell-theme"
export NOTIFICATION_STATE="$notification_state"
export PERSISTENT_PID_DIR="$persistent_pid_dir"

for part in "$REPO_ROOT/checks/profile-transition"/*.bash; do
  # shellcheck source=/dev/null
  source "$part"
done
