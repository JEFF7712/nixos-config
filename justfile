default:
  @just --list

fmt:
  nix fmt

fmt-check:
  nix fmt -- --fail-on-change --no-cache

shell-check:
  git grep -IlE '^#!.*\b(bash|sh|dash|ksh)\b' -- home/scripts checks hooks | xargs -r shellcheck -S error

lid-close-check:
  bash checks/lid-close-action.bash

wallpaper-script-check:
  bash checks/wallpaper-scripts.bash
  bash checks/iris-render.bash
  bash checks/temperature-render.bash
  bash checks/sharp-matugen.bash
  bash checks/merge-ini-section.bash
  bash checks/spicetify-theme.bash
  bash checks/profile-manifest.bash
  bash checks/lock-screen.bash
  bash checks/profile-transition.bash
  bash checks/profile-gsettings.bash
  bash checks/kitty-agent-colors.bash

check-local-bin:
  bash checks/local-bin-rot.bash

xhisper-check:
  bash checks/xhisper.bash

check-flake-update:
  bash checks/flake-update.bash
  bash checks/nix-pin-nixpkgs.bash

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

flake-check-shells:
  nix flake check --no-write-lock-file ./shells

check-profiles host="laptop" user="rupan":
  nix eval --no-write-lock-file --impure --json \
    ".#nixosConfigurations.{{host}}.config.home-manager.users.{{user}}.home.file" \
    --apply 'import ./checks/profiles.nix'

check-changed base="":
  CHECK_CHANGED_BASE='{{base}}' bash checks/run-changed-checks.bash

check-changed-test:
  bash checks/check-changed.bash

diff-check base="HEAD":
  bash checks/run-whitespace-check.bash '{{base}}'

check:
  just check-agent-docs
  just check-agent-workflows
  just check-laptop-safety
  just check-local-bin
  just check-flake-update
  just fmt-check
  just shell-check
  just lid-close-check
  just wallpaper-script-check
  just xhisper-check
  just qml-lint
  just quickshell-test
  just flake-check
  just flake-check-shells
  just eval-all
  just check-profiles
  just diff-check

quick:
  just eval laptop
  just diff-check

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
  printf '  pre-handoff: just check-changed\n'
  printf '  broad/risky changes: just check\n'
  printf '\n'

  printf 'Self-improvement\n'
  printf '  closeout: agent-self-improve --check\n'
  printf '  edit tooling only when durable friction appears\n'

update:
  nix flake update
  nix flake update --flake ./shells

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
  sudo "$(readlink -f "$(command -v nixos-rebuild)")" dry-activate --flake "{{ justfile_directory() }}#laptop"

# Caps must match hosts/laptop/base.nix sudoers pin. Root ignores user nix.conf.
# flock vs auto-update: two full builds OOM the ~31G box.
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
  # Refuse a toolchain-cascade switch. FORCE=1 to override.
  toplevel=".#nixosConfigurations.laptop.config.system.build.toplevel"
  pin=./home/scripts/nix-pin-nixpkgs-running
  if [ "${FORCE:-0}" != "1" ]; then
    rc=0
    ./home/scripts/nix-cascade-guard "$toplevel" || rc=$?
    if [ "$rc" = "10" ]; then
      echo "cascade: this switch would rebuild the toolchain from source (nixpkgs tip not cached yet)." >&2
      running=$("$pin" --rev)
      locked=$("$pin" --locked-rev)
      if [ "$running" = "$locked" ]; then
        echo "nixpkgs is already the running revision ${running:0:7}; pinning will not help." >&2
        echo "options: wait ~a day for hydra, or override with 'FORCE=1 just switch'." >&2
        exit 1
      fi
      answer=
      if [ -t 0 ]; then
        printf 'Pin nixpkgs back to running revision %s and continue? [y/N] ' "${running:0:7}" >&2
        read -r answer || true
      elif exec 3<>/dev/tty; then
        printf 'Pin nixpkgs back to running revision %s and continue? [y/N] ' "${running:0:7}" >&3
        read -r -t 60 answer <&3 || true
        exec 3>&-
      fi
      case "$answer" in
        y | Y | yes | YES)
          "$pin"
          rc=0
          ./home/scripts/nix-cascade-guard "$toplevel" || rc=$?
          if [ "$rc" = "10" ]; then
            echo "cascade: still above threshold after pinning; wait for hydra or FORCE=1 just switch." >&2
            exit 1
          elif [ "$rc" != "0" ]; then
            echo "cascade-guard error (rc=$rc); proceeding without it." >&2
          fi
          ;;
        *)
          echo "options: wait ~a day for hydra, pin nixpkgs back, or override with 'FORCE=1 just switch'." >&2
          exit 1
          ;;
      esac
    elif [ "$rc" != "0" ]; then
      echo "cascade-guard error (rc=$rc); proceeding without it." >&2
    fi
  fi
  sudo "$(readlink -f "$(command -v nh)")" os switch -R "{{ justfile_directory() }}" -H laptop -- --max-jobs 2 --cores 8

gc:
  nh clean all --keep-since 30d
