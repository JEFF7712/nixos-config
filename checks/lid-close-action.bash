#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_skip() {
  local expected="$1" info="$2" label="$3"
  local actual=0

  if lid_close_should_skip_suspend "$info"; then
    actual=1
  fi
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: %s\nexpected skip=%s actual skip=%s\ninfo:\n%s\n' \
      "$label" "$expected" "$actual" "$info" >&2
    exit 1
  fi
}

LID_CLOSE_ACTION_LIB=1
# shellcheck disable=SC1091
. "$REPO_ROOT/home/scripts/lid-close-action"

twitter_firefox='Manual Pause: no
D-Bus Inhibiting: yes
Apps Inhibiting: 0
Media Players Playing: 1
Apps Blocking Suspend: 0
Media Players Blocking Suspend: 0'

idle='Manual Pause: no
D-Bus Inhibiting: no
Apps Inhibiting: 0
Media Players Playing: 0
Apps Blocking Suspend: 0
Media Players Blocking Suspend: 0'

caffeine='Manual Pause: yes
D-Bus Inhibiting: no
Apps Inhibiting: 0
Media Players Playing: 0
Apps Blocking Suspend: 0
Media Players Blocking Suspend: 0'

mpv_idle_only='Manual Pause: no
D-Bus Inhibiting: no
Apps Inhibiting: 1
Media Players Playing: 1
Apps Blocking Suspend: 0
Media Players Blocking Suspend: 0'

suspend_media='Manual Pause: no
D-Bus Inhibiting: no
Apps Inhibiting: 0
Media Players Playing: 1
Apps Blocking Suspend: 0
Media Players Blocking Suspend: 1'

suspend_app='Manual Pause: no
D-Bus Inhibiting: no
Apps Inhibiting: 1
Media Players Playing: 0
Apps Blocking Suspend: 1
Media Players Blocking Suspend: 0'

assert_skip 0 "$idle" "idle session suspends"
assert_skip 0 "$twitter_firefox" "Firefox/Twitter idle inhibit still suspends"
assert_skip 0 "$mpv_idle_only" "idle-only app/media still suspends"
assert_skip 1 "$caffeine" "manual pause / caffeine stays awake"
assert_skip 1 "$suspend_media" "suspend_inhibit_media match stays awake"
assert_skip 1 "$suspend_app" "suspend_inhibit_apps match stays awake"

test_sleep_failure() (
  local scenario="$1" powered_off=false closed=true polls=0
  lid_is_closed() { [[ "$closed" == true ]]; }
  sleep() {
    polls=$((polls + 1))
    if [[ "$scenario" == reopen && "$polls" == 3 ]]; then
      closed=false
    fi
  }
  timeout() { shift; "$@"; }
  systemctl() {
    case "$1" in
      suspend) [[ "$scenario" != rejected ]] ;;
      show)
        if [[ "$*" == *--value* ]]; then
          printf '100\n'
        elif [[ "$scenario" == stale || "$scenario" == timeout ]]; then
          printf 'StateChangeTimestampMonotonic=100\nActiveState=failed\nResult=exit-code\n'
        elif [[ "$scenario" == success ]]; then
          printf 'StateChangeTimestampMonotonic=200\nActiveState=inactive\nResult=success\n'
        else
          printf 'StateChangeTimestampMonotonic=200\nActiveState=failed\nResult=exit-code\n'
        fi
        ;;
      --check-inhibitors=no)
        [[ "$2" == poweroff ]] || exit 1
        powered_off=true
        ;;
      *) exit 1 ;;
    esac
  }
  lid_close_suspend
  case "$scenario" in
    success|reopen) [[ "$powered_off" == false ]] ;;
    *) [[ "$powered_off" == true ]] ;;
  esac || { printf 'FAIL: sleep fallback %s\n' "$scenario" >&2; exit 1; }
)

for scenario in failed rejected reopen success stale timeout; do
  test_sleep_failure "$scenario"
done
