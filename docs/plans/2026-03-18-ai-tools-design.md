# AI Tools Module Design

## Goal

Add a dedicated Home Manager module for AI tools, move existing AI-specific packages out of the general dev module, and add `deepagents` from `github:langchain-ai/deepagents` without moving editor extensions.

## Chosen approach

Create `modules/home-manager/ai-tools.nix` with an `ai-tools.enable` option. Move `claude-code`, `claude-desktop-fhs`, `opencode`, and `codex` from `modules/home-manager/dev.nix` into that module, and add `deepagents` there as a packaged Python application sourced from a new flake input.

## Why this location

These tools are user-scoped CLIs and desktop apps, so Home Manager is the right layer. A separate `ai-tools` module matches the existing module pattern in `modules/home-manager/`, keeps `dev.nix` focused on general development utilities, and avoids scattering AI configuration across the repo.

## Flake changes

Keep the minimum shared flake plumbing in `flake.nix`: add a `deepagents` input and retain the `claude-desktop` input and overlay there because overlays are resolved during package set construction. The new module will consume those packages through `pkgs` and `inputs` rather than duplicating flake wiring elsewhere.

## Behavior

`ai-tools.enable = true` will install the AI CLIs and desktop app together. `github.copilot` and the rest of the VS Code extensions stay in `modules/home-manager/common-apps.nix`.

## Verification

Evaluate the Home Manager configs for `laptop` and `workmachine` to confirm the new module is imported, enabled, and contributes the expected packages, including `deepagents`.
