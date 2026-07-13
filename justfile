default:
  @just --list

fmt:
  nix fmt

fmt-check:
  nix fmt -- --fail-on-change --no-cache

shell-check:
  git grep -IlE '^#!.*\b(bash|sh|dash|ksh)\b' -- home/scripts checks | xargs -r shellcheck -S error

wallpaper-script-check:
  bash checks/wallpaper-scripts.bash
  bash checks/iris-render.bash
  bash checks/merge-ini-section.bash
  bash checks/spicetify-theme.bash
  bash checks/profile-manifest.bash
  bash checks/profile-transition.bash
  bash checks/profile-gsettings.bash

check-local-bin:
  bash checks/local-bin-rot.bash

check-flake-update:
  bash checks/flake-update.bash

check-agent-docs:
  bash checks/agent-docs.bash

check-agent-workflows:
  bash checks/agent-workflows.bash

check-laptop-safety:
  nix eval --impure --no-write-lock-file --expr 'let config = (builtins.getFlake (toString ./.)).nixosConfigurations.laptop.config; in import ./checks/laptop-safety.nix { inherit config; }'

qml-lint:
  nix shell nixpkgs#qt6.qtdeclarative -c qmllint \
    --import disable \
    --unqualified disable \
    --unresolved-type disable \
    --missing-property disable \
    --missing-type disable \
    --unresolved-alias disable \
    --max-warnings 0 \
    $(git ls-files '*.qml')

quickshell-test:
  QT_QPA_PLATFORM=offscreen nix shell nixpkgs#qt6.qtdeclarative -c bash checks/quickshell-services.bash

eval target="laptop":
  nix eval --no-write-lock-file ".#nixosConfigurations.{{target}}.config.system.build.toplevel.drvPath"

eval-all:
  just eval laptop
  just eval laptop-crypt
  just eval iso

# The vmVariant is a separate eval; `just eval` won't catch breakage in it.
eval-vm target="laptop":
  nix eval --no-write-lock-file ".#nixosConfigurations.{{target}}.config.system.build.vm.drvPath"

flake-check:
  nix flake check

check-profiles host="laptop" user="rupan":
  nix eval --no-write-lock-file --impure --json \
    ".#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.file" \
    --apply 'import ./checks/profiles.nix'

check:
  just check-agent-docs
  just check-agent-workflows
  just check-laptop-safety
  just check-local-bin
  just check-flake-update
  just fmt-check
  just shell-check
  just wallpaper-script-check
  just qml-lint
  just quickshell-test
  just flake-check
  just eval-all
  just check-profiles
  git diff --check

quick:
  just eval laptop
  git diff --check

agent-context:
  #!/usr/bin/env bash
  set -euo pipefail

  repo=$(pwd)
  active_profile="unknown"
  active_variant="unknown"
  profile_dir="${HOME}/.config/desktop-profiles"

  if [ -r "${profile_dir}/active" ]; then
    active_profile=$(cat "${profile_dir}/active")
  fi

  if [ -r "${profile_dir}/active-variant" ]; then
    active_variant=$(cat "${profile_dir}/active-variant")
  fi

  printf 'Repo\n'
  printf '  path: %s\n' "$repo"
  printf '  branch: %s\n' "$(git branch --show-current 2>/dev/null || printf 'unknown')"
  printf '\n'

  printf 'Git\n'
  if git diff --quiet -- . && git diff --cached --quiet -- .; then
    printf '  working tree: clean\n'
  else
    git status --short | sed 's/^/  /'
  fi
  printf '\n'

  printf 'Hosts\n'
  find hosts -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort
  printf '\n'

  printf 'Active desktop profile\n'
  printf '  profile: %s\n' "$active_profile"
  printf '  variant: %s\n' "$active_variant"
  printf '\n'

  printf 'Suggested validation\n'
  printf '  low-risk Nix edit: just quick\n'
  printf '  profile/theme edit: just check-profiles && just fmt-check\n'
  printf '  shell script edit: just shell-check\n'
  printf '  Quickshell edit: just qml-lint && just eval laptop\n'
  printf '  package/overlay edit: just build laptop\n'
  printf '  pre-handoff: just check\n'
  printf '\n'

  printf 'Self-improvement\n'
  printf '  closeout: agent-self-improve --check\n'
  printf '  edit tooling only when durable friction appears\n'

update:
  nix flake update

build target="laptop":
  nix build --no-write-lock-file ".#nixosConfigurations.{{target}}.config.system.build.toplevel"

build-iso:
  nix build .#nixosConfigurations.iso.config.system.build.isoImage

# Boot the host config in a throwaway QEMU VM (login rupan/rupan, see
# virtualisation.vmVariant in the host config). Disk image lives in /tmp so
# state never accumulates in the repo.
vm target="laptop":
  nix build --no-write-lock-file --out-link result-vm ".#nixosConfigurations.{{target}}.config.system.build.vm"
  NIX_DISK_IMAGE=/tmp/nixos-vm-{{target}}.qcow2 ./result-vm/bin/run-*-vm

vm-iso: build-iso
  qemu-system-x86_64 -enable-kvm -m 8192 -smp 4 -boot d -cdrom result/iso/*.iso

# Rehearse the LUKS reinstall: runs the real disko partitioning (GPT + LUKS2
# + btrfs subvolumes) inside QEMU and boots from it. docs/luks-reinstall.md.
vm-crypt:
  nix run --no-write-lock-file -L ".#nixosConfigurations.laptop-crypt.config.system.build.vmWithDisko"

dry:
  sudo "$(readlink -f "$(command -v nixos-rebuild)")" dry-activate --flake .#laptop

# Caps must match hosts/laptop/base.nix sudoers pin (and nix.settings).
# Root builds ignore ~/.config/nix/nix.conf — pass flags explicitly.
# flock guards against the auto-update rebuild (shared /run lock): two full
# builds at once OOM the ~31G box. Bails early if auto-update holds it.
switch:
  #!/usr/bin/env bash
  set -euo pipefail
  lock=/run/nixos-auto-update.lock
  [ -w "$lock" ] || lock="${TMPDIR:-/tmp}/nixos-switch.lock"
  exec {fd}>>"$lock"
  if ! flock -n "$fd"; then
    echo "auto-update is rebuilding (holds /run/nixos-auto-update.lock)." >&2
    echo "stop it:  sudo systemctl stop nixos-ai-tools-auto-update.service nixos-auto-update.service" >&2
    echo "then rerun 'just switch', or wait for it to finish." >&2
    exit 1
  fi
  # Refuse a toolchain-cascade switch (uncached nixpkgs tip → thousands of
  # from-source builds, hours on this box). FORCE=1 to override.
  if [ "${FORCE:-0}" != "1" ]; then
    rc=0
    ./home/scripts/nix-cascade-guard ".#nixosConfigurations.laptop.config.system.build.toplevel" || rc=$?
    if [ "$rc" = "10" ]; then
      echo "cascade: this switch would rebuild the toolchain from source (nixpkgs tip not cached yet)." >&2
      echo "options: wait ~a day for hydra, pin nixpkgs back, or override with 'FORCE=1 just switch'." >&2
      exit 1
    elif [ "$rc" != "0" ]; then
      echo "cascade-guard error (rc=$rc); proceeding without it." >&2
    fi
  fi
  sudo "$(readlink -f "$(command -v nh)")" os switch -R . -H laptop -- --max-jobs 2 --cores 8

gc:
  nh clean all --keep-since 30d
