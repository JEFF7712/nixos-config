# Claude Cowork VM Startup Design

## Goal

Make Claude Desktop cowork work reliably on this NixOS setup by fixing the VM service startup path rather than disabling the feature.

## Chosen approach

Treat the failure as a packaging and runtime environment problem around `claude-desktop-fhs`, not as a missing host virtualization feature. The host already exposes KVM and the user already has access, so the work should focus on finding the exact cowork VM launcher failure and then patching the Claude Desktop package or wrapper to provide the binaries, libraries, and environment it expects.

## Why this location

The current Claude Desktop install is provided by the `aaddrick/claude-desktop-debian` overlay and consumed through `modules/home-manager/ai-tools.nix`. A repo-managed fix in Nix keeps the behavior reproducible across rebuilds and avoids fragile manual environment tweaks in the user session.

## Constraints and assumptions

- `claude-desktop-fhs` is the installed package path for Claude Desktop.
- `kvm-intel` is enabled and `/dev/kvm` is available.
- The user is already in the `kvm` group.
- Cowork success requires the local VM service to start, not just the app UI to launch.

## Data flow to debug

1. Claude Desktop requests cowork VM startup.
2. The app downloads and validates the VM bundle into `~/.config/Claude/vm_bundles/claudevm.bundle`.
3. Claude Desktop launches its local VM service subprocess.
4. The subprocess fails before reporting ready.
5. Follow-on app calls like `isGuestConnected` fail with `VM service not running`.

## Planned fix shape

Inspect the installed application bundle, wrapper, and logs to find the actual launcher binary or script and the missing runtime dependency. Then patch the Nix-managed package setup so the launcher sees the required tools and libraries, ideally as a clean package override or small local overlay referenced from the flake. If the upstream overlay is fundamentally broken, replace only that package source with a working variant while keeping the rest of the repo structure unchanged.

## Verification

Verify in increasing order:

1. the package or wrapper evaluates and builds cleanly,
2. the expected launcher binary resolves its dynamic dependencies,
3. Claude Desktop starts without new wrapper errors,
4. cowork no longer logs `VM service not running`,
5. the cowork VM reaches a connected or ready state.

## Notes

This design intentionally avoids host-level guesswork like adding random virtualization packages first, because the host prerequisites already look present. The first useful evidence should come from the cowork VM service launch path itself.
