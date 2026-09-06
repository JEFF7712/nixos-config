#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/home/scripts/prune-old-roots"
module="$repo_root/modules/nixos/impermanence.nix"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'impermanence check failed: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$tmp/bin" "$tmp/root/old_roots/expired" "$tmp/root/old_roots/fresh"
touch -d '16 days ago' "$tmp/root/old_roots/expired"
touch -d '2 days ago' "$tmp/root/old_roots/fresh"

cat >"$tmp/bin/btrfs" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2 $3" = 'subvolume list -o' ]; then
  printf 'ID 300 gen 1 top level 5 path old_roots/expired/child\n'
  printf 'ID 301 gen 1 top level 5 path old_roots/expired/child/grandchild\n'
elif [ "$1 $2" = 'subvolume delete' ]; then
  printf '%s\n' "$3" >>"$BTRFS_LOG"
else
  exit 2
fi
EOF
chmod +x "$tmp/bin/btrfs"

PATH="$tmp/bin:$PATH" \
  BTRFS_LOG="$tmp/deleted" \
  PRUNE_OLD_ROOTS_SKIP_MOUNT=1 \
  PRUNE_OLD_ROOTS_MOUNT="$tmp/root" \
  PRUNE_OLD_ROOTS_LOCK="$tmp/lock" \
  "$script"

expected="$tmp/root/old_roots/expired/child/grandchild
$tmp/root/old_roots/expired/child
$tmp/root/old_roots/expired"
[ "$(cat "$tmp/deleted")" = "$expected" ] || fail 'nested subvolumes were not deleted deepest first'
! rg -q 'fresh' "$tmp/deleted" || fail 'fresh root was pruned'

exec 8>"$tmp/held-lock"
flock -n 8
: >"$tmp/locked-log"
PATH="$tmp/bin:$PATH" \
  BTRFS_LOG="$tmp/locked-log" \
  PRUNE_OLD_ROOTS_SKIP_MOUNT=1 \
  PRUNE_OLD_ROOTS_MOUNT="$tmp/root" \
  PRUNE_OLD_ROOTS_LOCK="$tmp/held-lock" \
  "$script"
[ ! -s "$tmp/locked-log" ] || fail 'pruner ran while its lock was held'

initrd_script=$(awk '/boot\.initrd\.systemd\.services\.rollback-root = \{/{seen=1} seen{print} seen && /^    \};$/{exit}' "$module")
! rg -q 'subvolume delete|find .*old_roots' <<<"$initrd_script" || fail 'initrd rollback still prunes old roots'
rg -q 'systemd\.timers\.prune-old-roots' "$module" || fail 'post-boot prune timer is missing'

printf 'impermanence: all tests passed\n'
