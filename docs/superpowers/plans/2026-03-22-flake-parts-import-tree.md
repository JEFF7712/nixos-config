# Flake-Parts + Import-Tree Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the NixOS flake to use flake-parts for outputs and import-tree for automatic module discovery, restructuring non-module files out of the module directory.

**Architecture:** The main `flake.nix` switches from manual outputs to `flake-parts.lib.mkFlake` with `nixosConfigurations` under the `flake` attribute. Both `bundle.nix` files are replaced by `import-tree` auto-importing all `.nix` files in module directories. Non-module files (configs, scripts, assets) move from `modules/home-manager/` to `home/`.

**Tech Stack:** NixOS, flake-parts, import-tree, home-manager

**Spec:** `docs/superpowers/specs/2026-03-22-flake-parts-import-tree-design.md`

---

### Task 1: Move non-module files to `home/`

Move `configs/`, `scripts/`, and `assets/` out of `modules/home-manager/` into `home/` so import-tree won't try to import them.

**Files:**
- Move: `modules/home-manager/configs/` → `home/configs/`
- Move: `modules/home-manager/scripts/` → `home/scripts/`
- Move: `modules/home-manager/assets/` → `home/assets/`

- [ ] **Step 1: Move the three directories**

```bash
cd ~/nixos
git mv modules/home-manager/configs home/configs
git mv modules/home-manager/scripts home/scripts
git mv modules/home-manager/assets home/assets
```

- [ ] **Step 2: Verify the moves**

```bash
ls home/configs home/scripts home/assets
ls modules/home-manager/  # should only contain .nix files and cli/ profiles/ dirs
```

Expected: `configs/`, `scripts/`, `assets/` exist under `home/`. Only `.nix` files and `cli/`/`profiles/` remain under `modules/home-manager/`.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor: move configs, scripts, assets to home/"
```

---

### Task 2: Update all path references in Nix modules

Every module that referenced `modules/home-manager/configs/`, `scripts/`, or `assets/` needs updating.

**Files:**
- Modify: `modules/home-manager/niri.nix:40-46`
- Modify: `modules/home-manager/common-apps.nix:49,95`
- Modify: `modules/home-manager/noctalia.nix:166,258`
- Modify: `modules/home-manager/quickshell-bar.nix:12`
- Modify: `modules/home-manager/terminal.nix:59,65`
- Modify: `modules/home-manager/profiles/noctalia.nix:15`
- Modify: `modules/home-manager/profiles/everforest.nix:104-105`
- Modify: `modules/home-manager/profiles/rosepine.nix:101-102`
- Modify: `modules/home-manager/profiles/catppuccin.nix:98-99`
- Modify: `modules/home-manager/profiles/nord.nix:74`
- Modify: `modules/home-manager/profiles/gruvbox.nix:109-110`

- [ ] **Step 1: Update `niri.nix` — 7 mkOutOfStoreSymlink paths (lines 40-46)**

Change all instances of `modules/home-manager/configs/` to `home/configs/` in the symlink paths:

```nix
# Before (line 40):
xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/niri";
# After:
xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/niri";
```

Apply the same pattern to all 7 lines (niri, kitty, gtk-2.0, gtk-3.0, gtk-4.0, qt5ct, qt6ct).

- [ ] **Step 2: Update `common-apps.nix` — Firefox chrome and VS Code paths**

Line 49 — Firefox chrome symlink:
```nix
# Before:
"${config.home.homeDirectory}/nixos/modules/home-manager/configs/firefox/chrome"
# After:
"${config.home.homeDirectory}/nixos/home/configs/firefox/chrome"
```

Line 95 — VS Code settings symlink:
```nix
# Before:
"${config.home.homeDirectory}/nixos/modules/home-manager/configs/vscode/settings.json"
# After:
"${config.home.homeDirectory}/nixos/home/configs/vscode/settings.json"
```

- [ ] **Step 3: Update `noctalia.nix` — wallpaper dir and avatar image**

Line 166 — wallpaper directory:
```nix
# Before:
directory = "/home/rupan/nixos/modules/home-manager/assets/wallpapers/noctalia";
# After:
directory = "/home/rupan/nixos/home/assets/wallpapers/noctalia";
```

Line 258 — avatar image:
```nix
# Before:
avatarImage = "/home/rupan/nixos/modules/home-manager/assets/Sponge.jpg";
# After:
avatarImage = "/home/rupan/nixos/home/assets/Sponge.jpg";
```

- [ ] **Step 4: Update `quickshell-bar.nix` — quickshell config symlink (line 12)**

```nix
# Before:
"${config.home.homeDirectory}/nixos/modules/home-manager/configs/quickshell"
# After:
"${config.home.homeDirectory}/nixos/home/configs/quickshell"
```

- [ ] **Step 5: Update `terminal.nix` — bashrc readFile and cniri alias**

Line 59 — `builtins.readFile` (Nix eval-time relative path — this is NOT a runtime symlink):
```nix
# Before:
initExtra = builtins.readFile ./configs/bashrc/.bashrc;
# After:
initExtra = builtins.readFile ../../home/configs/bashrc/.bashrc;
```

Line 65 — cniri alias:
```nix
# Before:
cniri="sudo $EDITOR $HOME/nixos/modules/home-manager/configs/niri/config.kdl";
# After:
cniri="sudo $EDITOR $HOME/nixos/home/configs/niri/config.kdl";
```

- [ ] **Step 6: Update all profile wallpaper paths**

For each profile, change `modules/home-manager/assets/` to `home/assets/`:

`profiles/noctalia.nix:15`:
```nix
wallpaperDir = "/home/rupan/nixos/home/assets/wallpapers/noctalia";
```

`profiles/everforest.nix:104-105`:
```nix
wallpaperDir      = "/home/rupan/nixos/home/assets/wallpapers/everforest";
wallpaperDirLight = "/home/rupan/nixos/home/assets/wallpapers/everforest-light";
```

`profiles/rosepine.nix:101-102`:
```nix
wallpaperDir      = "/home/rupan/nixos/home/assets/wallpapers/rosepine";
wallpaperDirLight = "/home/rupan/nixos/home/assets/wallpapers/rosepine-light";
```

`profiles/catppuccin.nix:98-99`:
```nix
wallpaperDir      = "/home/rupan/nixos/home/assets/wallpapers/catppuccin";
wallpaperDirLight = "/home/rupan/nixos/home/assets/wallpapers/catppuccin-light";
```

`profiles/nord.nix:74`:
```nix
wallpaperDir = "/home/rupan/nixos/home/assets/wallpapers/nord";
```

`profiles/gruvbox.nix:109-110`:
```nix
wallpaperDir      = "/home/rupan/nixos/home/assets/wallpapers/gruvbox";
wallpaperDirLight = "/home/rupan/nixos/home/assets/wallpapers/gruvbox-light";
```

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: update all Nix module paths after directory move"
```

---

### Task 3: Update path references in non-Nix files

These are runtime paths inside shell scripts and config files (now under `home/`).

**Files:**
- Modify: `home/configs/bashrc/.bashrc:11`
- Modify: `home/configs/niri/config.kdl:205,217`
- Modify: `home/scripts/rofi-profile:6,8`

- [ ] **Step 1: Update `home/configs/bashrc/.bashrc` line 11**

```bash
# Before:
alias cniri="sudo $EDITOR $HOME/nixos/modules/home-manager/configs/niri/config.kdl"
# After:
alias cniri="sudo $EDITOR $HOME/nixos/home/configs/niri/config.kdl"
```

- [ ] **Step 2: Update `home/configs/niri/config.kdl` line 205**

Change the rofi theme path:
```
# Before:
rofi -show drun -show-icons -theme \"$HOME/nixos/modules/home-manager/configs/rofi/launcher.rasi\"
# After:
rofi -show drun -show-icons -theme \"$HOME/nixos/home/configs/rofi/launcher.rasi\"
```

- [ ] **Step 3: Update `home/configs/niri/config.kdl` line 217**

Change the toggle-variant script path:
```
# Before:
spawn "bash" "/home/rupan/nixos/modules/home-manager/scripts/toggle-variant"
# After:
spawn "bash" "/home/rupan/nixos/home/scripts/toggle-variant"
```

- [ ] **Step 4: Update `home/scripts/rofi-profile` lines 6 and 8**

```bash
# Before (line 6):
PREVIEW_DIR="$HOME/nixos/modules/home-manager/assets/previews"
# After:
PREVIEW_DIR="$HOME/nixos/home/assets/previews"

# Before (line 8):
THEME="$HOME/nixos/modules/home-manager/configs/rofi/profile-switcher.rasi"
# After:
THEME="$HOME/nixos/home/configs/rofi/profile-switcher.rasi"
```

- [ ] **Step 5: Run a final grep sweep to catch any missed references**

```bash
grep -rn "modules/home-manager/configs\|modules/home-manager/scripts\|modules/home-manager/assets" ~/nixos
```

Expected: no matches (only CLAUDE.md and README.md should still have old paths — those are updated in Task 8).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor: update runtime paths in scripts and configs"
```

---

### Task 4: Add quickshell-bar.nix mkEnableOption guard

Since import-tree will auto-import `quickshell-bar.nix` (previously commented out in bundle.nix), it must have a proper enable guard so it does nothing by default. This MUST happen before bundle.nix is removed.

**Files:**
- Modify: `modules/home-manager/quickshell-bar.nix`

- [ ] **Step 1: Rewrite quickshell-bar.nix with enable guard**

Replace the full file with:

```nix
{ config, lib, pkgs, inputs, ... }:

let
  qs = inputs.quickshell.packages.${pkgs.system}.default;
in {
  options.quickshell-bar.enable = lib.mkEnableOption "quickshell bar";

  config = lib.mkIf config.quickshell-bar.enable {
    home.packages = [ qs pkgs.brightnessctl pkgs.playerctl ];

    xdg.configFile."quickshell".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos/home/configs/quickshell";

    systemd.user.services.quickshell-bar = {
      Unit = {
        Description = "Quickshell bar (non-noctalia profiles)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecCondition = "${pkgs.bash}/bin/bash -c '[ \"$(cat %h/.config/desktop-profiles/active 2>/dev/null || echo noctalia)\" != \"noctalia\" ]'";
        ExecStart = "${qs}/bin/quickshell";
        Environment = "NIRI_SOCKET=/run/user/%U/niri.sock";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
```

Note: the quickshell config symlink path already uses the new `home/configs/` location.

- [ ] **Step 2: Commit**

```bash
git add modules/home-manager/quickshell-bar.nix && git commit -m "fix: add enable guard to quickshell-bar.nix for import-tree compatibility"
```

---

### Task 5: Replace bundle.nix with import-tree and migrate extra config

Remove both `bundle.nix` files. Replace imports with import-tree calls. Move the non-import config from home-manager `bundle.nix` into `home/rupan/laptop.nix`, and from NixOS `bundle.nix` into `hosts/laptop/configuration.nix`.

**Files:**
- Delete: `modules/home-manager/bundle.nix`
- Delete: `modules/nixos/bundle.nix`
- Modify: `home/rupan/laptop.nix:4-7`
- Modify: `hosts/laptop/configuration.nix:6`
- Modify: `hosts/iso/configuration.nix:1,6`

- [ ] **Step 1: Update `home/rupan/laptop.nix` — replace bundle.nix import and add migrated config**

Replace the full file contents:

```nix
{ pkgs, inputs, lib, config, ... }:

{
  imports = [
    ./home.nix
    (inputs.import-tree ../../modules/home-manager)
  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    papirus-icon-theme
  ];

  niri.enable = true;
  noctalia.enable = true;
  terminal.enable = true;
  common-apps.enable = true;
  heavy-apps.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;
  ai-tools.enable = true;
  dev.enable = true;
  desktopProfiles.enable = lib.mkDefault true;

  # Scripts — symlink home/scripts/ into ~/.local/bin
  home.file.".local/bin" = {
    source = ../scripts;
    recursive = true;
    executable = true;
  };

  # Rofi configs (out-of-store so they're editable without rebuild)
  xdg.configFile."rofi".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/home/configs/rofi";

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.fish.shellAliases.bnix = "cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push";

  qt.enable = true;
}
```

Key changes from current `laptop.nix`:
- `inputs`, `lib`, `config` added to function args
- Bundle.nix import replaced with import-tree
- `desktopProfiles.enable`, script symlink, rofi config, and sessionPath migrated from old `bundle.nix`
- Script source path is `../scripts` (relative from `home/rupan/` to `home/scripts/`)

- [ ] **Step 2: Update `hosts/laptop/configuration.nix` — replace bundle.nix import and add git.enable**

Line 6 — replace the import:
```nix
# Before:
imports = [
  ./hardware-configuration.nix
  ../../modules/nixos/bundle.nix
];
# After:
imports = [
  ./hardware-configuration.nix
  (inputs.import-tree ../../modules/nixos)
];
```

Add `git.enable` (was the only non-import config in NixOS `bundle.nix`) — add after line 34:
```nix
git.enable = true;
```

- [ ] **Step 3: Update `hosts/iso/configuration.nix` — add `inputs` to args and replace import**

Line 1 — add `inputs` to the function arguments:
```nix
# Before:
{ config, lib, pkgs, modulesPath, self, ... }:
# After:
{ config, lib, pkgs, inputs, modulesPath, self, ... }:
```

Line 6 — replace bundle.nix import:
```nix
# Before:
imports = [
  "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix"
  ../../modules/nixos/bundle.nix
];
# After:
imports = [
  "${modulesPath}/installer/cd-dvd/installation-cd-graphical-base.nix"
  (inputs.import-tree ../../modules/nixos)
];
```

Add `git.enable = true;` somewhere in the config body (preserving the default from old `bundle.nix`).

**Note:** The ISO config uses `self` (line 11: `environment.etc."nixos-config-source".source = self;`). This is a special NixOS module argument that `nixosSystem` provides automatically from the flake — it will continue to work with flake-parts. Verify during the build step.

- [ ] **Step 4: Delete both bundle.nix files**

```bash
rm modules/home-manager/bundle.nix modules/nixos/bundle.nix
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor: replace bundle.nix with import-tree auto-discovery"
```

---

### Task 6: Migrate flake.nix to flake-parts

Add the new inputs and restructure outputs.

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add flake-parts and import-tree inputs, remove flake-utils**

Add to the inputs section:
```nix
flake-parts.url = "github:hercules-ci/flake-parts";
import-tree.url = "github:vic/import-tree";
```

Remove the `flake-utils` input (line 7):
```nix
flake-utils.url = "github:numtide/flake-utils";  # DELETE THIS LINE
```

- [ ] **Step 2: Rewrite the outputs**

Replace the entire `outputs` block with:

```nix
outputs = { self, nixpkgs, nixpkgs-stable, home-manager, nix-vscode-extensions, nixvim, globalprotect-openconnect, ... }@inputs:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];

    flake = let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-37.10.3"
        ];
        overlays = [
          nix-vscode-extensions.overlays.default
          inputs.niri-blur.overlays.default
        ];
      };

      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      mkSystem = host: userModule: nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = { inherit inputs pkgs-stable; };
        modules = [
          ./hosts/${host}/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs pkgs-stable; };
            home-manager.backupFileExtension = "backup";
            home-manager.users.rupan = import userModule;
          }
        ];
      };

    in {
      nixosConfigurations = {
        laptop = mkSystem "laptop" ./home/rupan/laptop.nix;
        iso = mkSystem "iso" ./home/rupan/laptop.nix;
      };
    };
  };
```

- [ ] **Step 3: Commit**

```bash
git add flake.nix && git commit -m "feat: migrate flake.nix to flake-parts with import-tree inputs"
```

---

### Task 7: Update flake.lock and verify build

**Files:**
- Modify: `flake.lock` (auto-updated by nix)

- [ ] **Step 1: Update the flake lock to add new inputs only**

```bash
cd ~/nixos && nix flake lock --update-input flake-parts --update-input import-tree
```

This adds only the new inputs without updating existing ones (avoids unrelated breakage from nixpkgs updates).

- [ ] **Step 2: Do a dry build to verify everything resolves**

```bash
nixos-rebuild build --flake .#laptop
```

Expected: build succeeds with no errors. If there are path errors, they'll show up here as "file not found" during evaluation.

- [ ] **Step 3: If build succeeds, switch to the new config**

```bash
sudo nixos-rebuild switch --flake .#laptop
```

- [ ] **Step 4: Verify runtime — check that symlinks and scripts work**

```bash
# Check symlinks point to correct locations
ls -la ~/.config/niri
ls -la ~/.config/kitty
ls -la ~/.local/bin/switch-profile

# Check a script runs
rofi-profile --help 2>&1 || true
```

- [ ] **Step 5: Commit the lock file**

```bash
git add flake.lock && git commit -m "chore: update flake.lock with flake-parts and import-tree"
```

---

### Task 8: Update documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md:14`

- [ ] **Step 1: Update CLAUDE.md config files section**

Change the section header and description from `modules/home-manager/configs/` to `home/configs/`. Also update the "Important Patterns" section to reflect the new path.

- [ ] **Step 2: Update README.md line 14**

```markdown
# Before:
- `modules/home-manager/configs/` - mutable runtime configs symlinked into `$HOME`
# After:
- `home/configs/` - mutable runtime configs symlinked into `$HOME`
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README.md && git commit -m "docs: update paths after directory restructure"
```
