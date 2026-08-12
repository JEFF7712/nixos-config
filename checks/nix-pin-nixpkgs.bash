#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

pin=home/scripts/nix-pin-nixpkgs-running
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

chmod +x "$pin"

if ! rg -q 'Pin nixpkgs back to running revision' justfile; then
  fail 'just switch must offer to pin nixpkgs back on cascade'
fi
if ! rg -q 'nix-pin-nixpkgs-running' justfile; then
  fail 'just switch must call nix-pin-nixpkgs-running'
fi

bin=$tmpdir/bin
flake=$tmpdir/flake
mkdir -p "$bin" "$flake"
cat >"$flake/flake.lock" <<'EOF'
{
  "nodes": {
    "nixpkgs": {
      "locked": { "rev": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
    },
    "nixpkgs_4": {
      "locked": { "rev": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
    },
    "root": {
      "inputs": { "nixpkgs": "nixpkgs_4" }
    }
  },
  "root": "root"
}
EOF

cat >"$bin/nixos-version" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"nixosVersion":"26.11.test","nixpkgsRevision":"cccccccccccccccccccccccccccccccccccccccc"}'
EOF
chmod +x "$bin/nixos-version"

cat >"$bin/nix" <<'EOF'
#!/usr/bin/env bash
printf 'nix' >> "$COMMAND_LOG"
printf ' %q' "$@" >> "$COMMAND_LOG"
printf '\n' >> "$COMMAND_LOG"
EOF
chmod +x "$bin/nix"

export PATH="$bin:$PATH"
export NIXOS_VERSION="$bin/nixos-version"
export NIX="$bin/nix"
export COMMAND_LOG="$tmpdir/commands.log"
: >"$COMMAND_LOG"

rev=$("$pin" --rev)
[ "$rev" = cccccccccccccccccccccccccccccccccccccccc ] || fail "--rev printed $rev"

locked=$("$pin" --locked-rev "$flake")
[ "$locked" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ] || fail "--locked-rev printed $locked"

"$pin" "$flake"
grep -F 'nix flake lock --override-input nixpkgs github:nixos/nixpkgs/cccccccccccccccccccccccccccccccccccccccc '"$flake" \
  "$COMMAND_LOG" >/dev/null \
  || fail "pin did not invoke nix flake lock --override-input with the running rev"

cat >"$bin/nixos-version" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"nixosVersion":"26.11.test"}'
EOF
if "$pin" --rev >/dev/null 2>"$tmpdir/err"; then
  fail '--rev must fail when nixpkgsRevision is missing'
fi

echo 'nix-pin-nixpkgs: ok'
