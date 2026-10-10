{
  nixpkgs,
  lanzaboote,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};
  test = pkgs.testers.runNixOSTest {
    name = "intentd-boot-counting";
    globalTimeout = 5 * 60;
    extraBaseModules = {
      imports = [ lanzaboote.nixosModules.lanzaboote ];
    };
    nodes.machine = {
      imports = [ "${lanzaboote}/nix/tests/lanzaboote/common/lanzaboote.nix" ];

      boot.lanzaboote.bootCounting.initialTries = 1;
      systemd.targets.boot-complete.after = [ "multi-user.target" ];

      specialisation.bad.configuration = {
        boot.lanzaboote.sortKey = nixpkgs.lib.mkForce "intentd-candidate";
        systemd.services.intentd-failing-health = {
          requiredBy = [ "boot-complete.target" ];
          before = [ "boot-complete.target" ];
          serviceConfig.Type = "oneshot";
          script = "exit 1";
        };
      };
    };
    testScript =
      { nodes, ... }:
      let
        original = nodes.machine.system.build.toplevel;
        bad = nodes.machine.specialisation.bad.configuration.system.build.toplevel;
      in
      (import "${lanzaboote}/nix/tests/lanzaboote/common/image-helper.nix" {
        inherit (nodes) machine;
      })
      + ''
        machine.start()
        machine.wait_for_unit("multi-user.target")
        assert machine.succeed("readlink -f /run/current-system").strip() == "${bad}"
        machine.shutdown()

        machine.start()
        machine.wait_for_unit("multi-user.target")
        assert machine.succeed("readlink -f /run/current-system").strip() == "${original}"
        machine.wait_for_unit("systemd-bless-boot.service")
        machine.shutdown()
      '';
  };
in
{
  inherit test;
}
