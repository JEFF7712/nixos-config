# qemu sizing and host access for the baseline VM.
#
# Seeded into the VM alongside configuration.nix so that the flake at
# /etc/nixos builds the same module set the VM is already running: without
# qemu-vm.nix in the seeded config, an in-VM `nixos-rebuild switch` would
# build a system with different fileSystems than the one it is switching from.
#
# Sizing matches the intentd arm's nixosTest nodes (nix/SPIKE_FINDINGS.md,
# "M6 Task 5 findings") so neither arm gets more machine than the other.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  virtualisation = {
    memorySize = 6144;
    cores = 4;
    diskSize = 16384;
    writableStoreUseTmpfs = false;
    graphics = false;
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };
}
