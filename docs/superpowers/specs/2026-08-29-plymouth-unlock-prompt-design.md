# Plymouth Unlock Prompt Design

## Goal

Show the encrypted-disk PIN or passphrase prompt in Plymouth without requiring
Escape, while retaining the centered NixOS logo.

## Root Cause

The custom `nixos-logo` script theme draws the logo but does not register
Plymouth display-password or display-normal callbacks. Plymouth therefore has
no graphical authentication UI. Pressing Escape exposes the text-mode prompt.

## Design

Extend the existing script theme with a small authentication view below the
logo. The password callback renders Plymouth's prompt text and one bullet for
each entered character. It places both above the logo in sprite depth so they
cannot be obscured. The normal callback hides the authentication sprites after
successful unlock and restores the logo-only splash.

The implementation remains in `pkgs/plymouth-nixos-logo/default.nix`. It uses
Plymouth script primitives only, with no new package or image dependencies.

## Error and Message Handling

Register Plymouth message callbacks and render messages below the password
entry. This preserves visible feedback for a rejected PIN or passphrase. Hiding
a message clears the corresponding sprite.

## Verification

Add a source-level regression check that requires the custom theme to register
password, normal, message, and hide-message callbacks. Run the check once before
implementation to confirm it fails, then after implementation to confirm it
passes. Build and activate the `laptop` configuration. The final acceptance test
is a cold boot where the user can see the prompt and entry bullets and unlock
the disk without pressing Escape.

## Scope

This change does not alter LUKS, TPM enrollment, crypttab, initrd unlock policy,
or the logo asset. It only adds the missing graphical authentication behavior.
