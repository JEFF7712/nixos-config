#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT
mkdir "$tmpdir/bin"
export HOMELAB_NETWORK_STATE_DIR="$tmpdir/state"
export HOMELAB_MANAGEMENT_INTERFACE=fixture-mgmt
export EVENT_LOG="$tmpdir/events"
export FIXTURE_ADDRESS=10.0.10.42

cat > "$tmpdir/bin/ip" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2 $3" = '-4 -j address' ]; then
  [ "${FIXTURE_IP_MISSING:-0}" = 0 ] || exit 1
  printf '[{"addr_info":[{"family":"inet","local":"%s"}]}]\n' "$FIXTURE_ADDRESS"
else
  printf 'ip %s\n' "$*" >> "$EVENT_LOG"
fi
EOF
cat > "$tmpdir/bin/resolvectl" <<'EOF'
#!/usr/bin/env bash
printf 'resolvectl %s\n' "$*" >> "$EVENT_LOG"
EOF
chmod +x "$tmpdir/bin/"*
export PATH="$tmpdir/bin:$PATH"

bash home/scripts/homelab-network-event fixture-mgmt up
grep -Fxq 'resolvectl dns fixture-mgmt 10.0.30.10' "$EVENT_LOG"
grep -Fxq 'ip rule add from 10.0.10.42/32 lookup 1001 priority 100' "$EVENT_LOG"
[ "$(cat "$HOMELAB_NETWORK_STATE_DIR/source")" = 10.0.10.42 ]

: > "$EVENT_LOG"
bash home/scripts/homelab-network-event wlo1 down
[ ! -s "$EVENT_LOG" ]
[ "$(cat "$HOMELAB_NETWORK_STATE_DIR/source")" = 10.0.10.42 ]

FIXTURE_ADDRESS=10.0.10.43 bash home/scripts/homelab-network-event fixture-mgmt dhcp4-change
grep -Fxq 'ip rule del from 10.0.10.42/32 lookup 1001 priority 100' "$EVENT_LOG"
grep -Fxq 'ip rule add from 10.0.10.43/32 lookup 1001 priority 100' "$EVENT_LOG"

: > "$EVENT_LOG"
bash home/scripts/homelab-network-event fixture-mgmt down
grep -Fxq 'ip rule del from 10.0.10.43/32 lookup 1001 priority 100' "$EVENT_LOG"
grep -Fxq 'ip route flush table 1001 dev fixture-mgmt' "$EVENT_LOG"
[ ! -e "$HOMELAB_NETWORK_STATE_DIR/source" ]

: > "$EVENT_LOG"
bash home/scripts/homelab-network-event '' connectivity-change
FIXTURE_IP_MISSING=1 bash home/scripts/homelab-network-event fixture-mgmt up
[ ! -s "$EVENT_LOG" ]

FIXTURE_ADDRESS=146.151.1.2 bash home/scripts/homelab-network-event wlo1 up
[ ! -s "$EVENT_LOG" ]
printf 'network event checks passed\n'

legacy="$tmpdir/management.nmconnection"
printf 'uuid=fixture\n' > "$legacy"
printf 'uuid=fixture\n' > "$legacy.pre-declarative.123456789"
printf 'uuid=other\n' > "$legacy.pre-declarative.other"
bash home/scripts/preserve-management-profile "$legacy" fixture
[ ! -e "$legacy" ]
[ ! -e "$legacy.pre-declarative.123456789" ]
grep -Fxq uuid=fixture "$legacy.pre-declarative.123456789~"
grep -Fxq uuid=other "$legacy.pre-declarative.other"
backups=("$legacy".pre-declarative.*~)
[ "${#backups[@]}" = 2 ]
bash home/scripts/preserve-management-profile "$legacy" fixture
backups=("$legacy".pre-declarative.*~)
[ "${#backups[@]}" = 2 ]
printf 'uuid=other\n' > "$legacy"
bash home/scripts/preserve-management-profile "$legacy" fixture
grep -Fxq uuid=other "$legacy"
printf 'management profile preservation checks passed\n'
