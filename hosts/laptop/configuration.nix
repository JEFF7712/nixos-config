{
  ...
}:

{
  # Everything except the disk/hardware layer lives in base.nix so that
  # laptop-crypt (the post-LUKS-reinstall variant) can share it while
  # swapping in disko.nix + hardware-crypt.nix.
  imports = [
    ./hardware-configuration.nix
    ./base.nix
  ];
}
