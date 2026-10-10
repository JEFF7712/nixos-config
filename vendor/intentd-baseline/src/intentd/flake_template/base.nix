{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "25.11";
  users.users.wedge = {
    isNormalUser = true;
    initialPassword = "wedge";
  };
}
