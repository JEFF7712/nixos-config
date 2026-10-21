{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.cominDeploy;
  stateDirectory = "/var/lib/nixos-deploy";
in
{
  imports = [ inputs.comin.nixosModules.comin ];

  options.cominDeploy = {
    enable = lib.mkEnableOption "comin deployment of the homelab-published deploy/laptop branch, substitute-only";

    user = lib.mkOption {
      type = lib.types.str;
      default = "rupan";
      description = "Desktop user allowed to pause and resume comin.";
    };

    pauseFile = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${stateDirectory}/paused";
      description = "While this file exists comin does not start; see home/scripts/nixos-deploy.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      package = inputs.comin.packages.${pkgs.stdenv.hostPlatform.system}.comin;
      hostname = "laptop";
      desktop.enable = true;
      remotes = [
        {
          name = "origin";
          url = "ssh://forgejo@git.internal:2222/JEFF7712/nixos-config.git";
          auth = {
            username = "forgejo";
            ssh_deploy_key_path = "/etc/ssh/ssh_host_ed25519_key";
          };
          # Only homelab CI may push deploy/*; comin would otherwise test-switch
          # any pushed testing-<host> branch as root.
          branches.main.name = "deploy/laptop";
          branches.testing.name = "deploy/laptop-testing";
          poller.period = 300;
        }
      ];
    };

    # CI publishes the full closure before advancing deploy/laptop. Refuse to
    # build anything here: a missing path fails the deployment and leaves the
    # running system alone instead of compiling CUDA on battery.
    systemd.services.comin = {
      environment.NIX_CONFIG = ''
        max-jobs = 0
        fallback = false
        always-allow-substitutes = true
      '';
      unitConfig.ConditionPathExists = "!${cfg.pauseFile}";
    };

    programs.ssh.knownHosts.forgejo-internal = {
      hostNames = [ "[git.internal]:2222" ];
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDncXBv6ZbH5pJOfaW+KdKG1pBkjwA5UzAKx/k5TwbyVajI5J4dBkp+LnemjIsNgluwrHAZDcZ8LiBazkcAYJyZ8bh3K1YKeKiOaTuCPCk+hPxuw9Q/rwOugecgjyc8fLMDMA+7wEZwSysqpqHp898tu/OXgO2Au2UCWBR9hudFzdtt+N13I5H4or7YTG9kVgoErnxL7lvlhC5unxBD0GvmT2k9dJkx/wYDruyKsSuxOqvbMHdzki/Vozr8s2IQjeLALnb2h8ml3gZ69IUNwg0vx8FSV6WMv1ng4xg5JWsuDWdk2QBPTje+ayCrSnVFWk2uNG33wRlDMo+mikpVTbhaLCcs3swGKYIcFQ1KpN4pVWRHwEF4p7RLx9F3xxIiTX9uJoPJfCYQ1PEkxlpa+ufswDlgzfQ/ScNlinQJE5srtRgqcC8Le5xS6czBsrb1g++hzCGSkSfOaDiYj6G5cdI3iRG28eRmk9x5qSRpVyE9uBbyl1vzTVZAEd/NFi4P/nY1JTqPzjfGmhgqYhztgccz39STcJL3I3Y/eTZyJwoIHcGKVLsfXMJH1NjZnSFrgzl+KGZ/E7T2RycGWVKoTFy42uwqcOLV4k97jEhOX2LEBSqEBQggcbDw5OUuETJHhjaXwiM170+ZOdF2vofI7o/zIX+dKTdJFu80DI3ZRe3zgQ==";
    };

    systemd.tmpfiles.rules = [ "d ${stateDirectory} 0755 ${cfg.user} users -" ];

    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == ${builtins.toJSON cfg.user} &&
            action.lookup("unit") == "comin.service") {
          var verb = action.lookup("verb");
          if (verb == "start" || verb == "stop" || verb == "restart") {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };
}
