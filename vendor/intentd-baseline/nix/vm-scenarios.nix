# M4 Task 6: VM scenario checks, driving the REAL orchestrator inside a
# nixosTest VM. Follows the cheat sheet in nix/SPIKE_FINDINGS.md:
#   - scenario candidates include test instrumentation (backdoor.service),
#     so switching between them never kills the driver's shell and the
#     smoke test's systemd-run/resurrect dance is not needed here.
#   - system.switch.enable = true on the node.
#   - every candidate toplevel the scenarios reach, plus the nixpkgs source
#     and the driver script, are pre-seeded via virtualisation.additionalPaths
#     so all in-VM operations run offline.
#   - the in-VM build is hermetic: --no-write-lock-file --override-input
#     nixpkgs 'path:<src>?rev=<rev>&lastModified=<n>', asserted byte-equal to
#     the pre-seeded candidate.
#
# Workspace wrinkle: the shipped flake.nix template only imports ./base.nix
# and ./generated.nix (fixed, product-owned). To get chaos + test
# instrumentation into the workspace's nixosSystem without hand-editing a
# manifest-tracked file out of band, the testScript does:
#   1. driver init            (init_workspace: copies the SHIPPED template)
#   2. overwrite base.nix     (with the scenario base.nix -- same content
#                               used, byte for byte, by the outer-eval
#                               candidates below)
#   3. driver repair-manifest (workspace.repair_manifest, public since Task 5:
#                               re-hashes tracked files under the same lock
#                               write_generated uses, so the new base.nix
#                               becomes the authoritative baseline)
# This runs before any transaction, so write_generated's tamper check never
# sees the swap as an out-of-band edit.
{ self, nixpkgs }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  intentd = self.packages.${system}.intentd;
  pythonEnv = pkgs.python312.withPackages (ps: [ (ps.toPythonModule intentd) ]);
  machineProfile = pkgs.writeText "intentd-vm-machine-profile.json" (
    builtins.toJSON {
      profile_id = "intentd-vm-v1";
      certified = true;
      graphics_backend = "intentd-vm";
      intel_pci = "0000:00:02.0";
      nvidia_pci = "0000:01:00.0";
      critical_units = [ "intentd-display-ready.service" ];
      display_unit = "intentd-display-ready.service";
      root_reserve_bytes = 268435456;
      esp_reserve_bytes = 134217728;
    }
  );

  # Byte-identical to the workspace's post-repair base.nix (see the testScript
  # copy step) and to render() output for each scenario state -- the outer
  # eval and the in-VM eval of the workspace flake must agree exactly, since
  # module *content* (not path identity) decides the toplevel drv.
  scenarioBase = pkgs.writeText "base.nix" (builtins.readFile ./scenario-base.nix);
  generatedFirefox = pkgs.writeText "generated.nix" (
    builtins.readFile ./scenario-generated-firefox.nix
  );
  generatedFirefoxVlc = pkgs.writeText "generated.nix" (
    builtins.readFile ./scenario-generated-firefox-vlc.nix
  );

  mkCandidate =
    generated:
    (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        "${scenarioBase}"
        "${generated}"
      ];
    }).config.system.build.toplevel;

  candidateFirefox = mkCandidate generatedFirefox;
  candidateFirefoxVlc = mkCandidate generatedFirefoxVlc;

  scenarioDriver = pkgs.writeText "scenario_driver.py" (builtins.readFile ./scenario_driver.py);

  # See SPIKE_FINDINGS.md: the rev+lastModified query params are required for
  # coherence (nixpkgs' lib.trivial.versionSuffix derives from the flake's own
  # sourceInfo, so a bare path: override evaluates to a different toplevel).
  nixpkgsOverride = "path:${nixpkgs}?rev=${nixpkgs.rev}&lastModified=${toString nixpkgs.lastModified}";

  chaosScript = ''
    if [ -e /etc/intentd-chaos ]; then
      echo "intentd-chaos: chaos flag present, failing" >&2
      exit 1
    fi
    exit 0
  '';

  test = pkgs.testers.runNixOSTest {
    name = "vm-scenarios";

    nodes.machine =
      { lib, ... }:
      {
        # Test nodes default system.switch.enable = false (Hydra
        # optimization); the driver's activate() needs switch-to-configuration.
        system.switch.enable = true;
        environment.etc."intentd/machine-profile.json".source = machineProfile;

        # Present on the node too (spec: "part of ALL scenario candidates AND
        # the node"), even though the node's own toplevel never gets switched
        # to in these scenarios.
        systemd.services.intentd-chaos = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = chaosScript;
        };

        virtualisation = {
          memorySize = 6144;
          cores = 4;
          diskSize = 8192;
          writableStore = true;
          additionalPaths = [
            nixpkgs.outPath
            candidateFirefox
            candidateFirefoxVlc
            scenarioDriver
            pythonEnv
          ];
        };
        nix.settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = lib.mkForce [ ];
          flake-registry = "";
        };
      };

    testScript = ''
      import json

      machine.start()
      machine.wait_for_unit("multi-user.target")

      driver = "${pythonEnv}/bin/python3 ${scenarioDriver} --nixpkgs-override '${nixpkgsOverride}'"

      def run_driver(*args):
          out = machine.succeed(f"{driver} {' '.join(args)}")
          line = out.strip().splitlines()[-1]
          return json.loads(line)

      # --- workspace setup: init, then make the scenario base.nix (chaos +
      # test instrumentation) the authoritative workspace file before any
      # transaction runs. ---
      machine.succeed(f"{driver} init")
      machine.succeed("install -m 0644 ${scenarioBase} /var/lib/intentd/ws/base.nix")
      machine.succeed(f"{driver} repair-manifest")

      # --- scenario 1: install firefox end to end ---
      result1 = run_driver("install", "firefox")
      txn1 = result1["transaction"]
      assert txn1 is not None, result1
      assert txn1["status"] == "blessed", txn1
      assert txn1["closure_path"] == "${candidateFirefox}", txn1

      machine.succeed("test -x /run/current-system/sw/bin/firefox")
      prof1 = machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()
      assert prof1 == "${candidateFirefox}", prof1

      # --- scenario 2: chaos abort + revert to blessed ---
      machine.succeed("touch /etc/intentd-chaos")
      result2 = run_driver("install", "vlc")
      txn2 = result2["transaction"]
      assert txn2 is not None, result2
      assert txn2["status"] == "aborted", txn2
      assert "intentd-chaos.service" in (txn2["detail"] or ""), txn2

      status2 = run_driver("status")
      blessed2 = status2["blessed"]
      assert blessed2 is not None and blessed2["apps"] == ["firefox"], status2
      assert blessed2["closure_path"] == "${candidateFirefox}", status2

      # generated.nix must be byte-identical to the blessed render, which is
      # byte-identical to the pre-seeded generatedFirefox store file.
      machine.succeed("diff -u ${generatedFirefox} /var/lib/intentd/ws/generated.nix")

      prof2 = machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()
      assert prof2 == "${candidateFirefox}", prof2

      machine.succeed("rm /etc/intentd-chaos")

      # --- scenario 3: clean install then revert ---
      result3 = run_driver("install", "vlc")
      txn3 = result3["transaction"]
      assert txn3 is not None, result3
      assert txn3["status"] == "blessed", txn3
      assert txn3["closure_path"] == "${candidateFirefoxVlc}", txn3

      result4 = run_driver("revert")
      txn4 = result4["transaction"]
      assert txn4 is not None, result4
      assert txn4["status"] == "blessed", txn4
      assert txn4["closure_path"] == "${candidateFirefox}", txn4

      status4 = run_driver("status")
      blessed4 = status4["blessed"]
      assert blessed4 is not None and blessed4["apps"] == ["firefox"], status4

      prof4 = machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()
      assert prof4 == "${candidateFirefox}", prof4
    '';
  };
in
{
  inherit
    test
    candidateFirefox
    candidateFirefoxVlc
    scenarioBase
    scenarioDriver
    pythonEnv
    nixpkgsOverride
    ;
}
