# M6 Task 4: end-to-end VM scenario for the `intent` CLI. Unlike
# nix/vm-scenarios.nix (which drives the orchestrator through a bespoke
# in-VM driver), this check exercises the SHIPPED user surface: the `intent`
# entry point script, wired through wiring.production_deps and
# apply_with_reconcile, exactly as a user would run it.
#
# Two seams make that possible offline:
#
#   1. Resolver: `intent do` shells out to `claude -p`, impossible in the
#      hermetic VM. INTENTD_RESOLVER_STUB=<file> (cli.resolve_fn_from_env)
#      substitutes only the model subprocess with a canned reply; reply
#      validation and catalog-checked invocation resolution stay on the
#      production path. The live model path is proven by the M5 claude_live
#      suite and the eval runner.
#   2. Build: production_deps builds with a plain `nix build path:<ws>#...`
#      (no --override-input parameter exists on that path, by design). The
#      testScript plants a flake.lock in the workspace whose nixpkgs node
#      mirrors this flake's own lock (same rev/narHash/lastModified). A fully
#      locked github input resolves offline straight from the pre-seeded
#      store path (fetchToStore's substituted/cached-input shortcut), and
#      rev+lastModified in the lock reproduce nixpkgs' versionSuffix, so the
#      in-VM build is byte-identical to the outer candidates below (proven
#      host-side: drvPaths match with no override). flake.lock is not a
#      manifest-tracked workspace file, so planting it trips no tamper check,
#      and wiring's lock-pin/re-verify (build pins the hash, activation
#      re-checks it) runs for real against the planted file.
#
# Everything else follows the cheat sheet in nix/SPIKE_FINDINGS.md: scenario
# candidates carry test instrumentation (backdoor survives switches),
# system.switch.enable on the node, everything pre-seeded via
# additionalPaths, python env invoked by absolute store path.
{ self, nixpkgs }:
let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  intentd = self.packages.${system}.intentd;
  pythonEnv = pkgs.python312.withPackages (ps: [ (ps.toPythonModule intentd) ]);
  journalKey = pkgs.writeText "intentd-journal-key" "0123456789abcdef0123456789abcdef";
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

  # Same base as vm-scenarios (so candidateFirefox is the same derivation);
  # the generated variants are byte-identical to render() output for each
  # desired state.
  scenarioBase = pkgs.writeText "base.nix" (builtins.readFile ./scenario-base.nix);
  generatedFirefox = pkgs.writeText "generated.nix" (
    builtins.readFile ./scenario-generated-firefox.nix
  );
  generatedEmpty = pkgs.writeText "generated.nix" (builtins.readFile ./scenario-generated-empty.nix);

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
  candidateEmpty = mkCandidate generatedEmpty;

  # The workspace lock planted before the first `intent do`; must stay in
  # sync with this flake's own nixpkgs pin (it is generated from the same
  # input, so it cannot drift).
  workspaceLock = pkgs.writeText "flake.lock" (
    builtins.toJSON {
      nodes = {
        nixpkgs = {
          locked = {
            inherit (nixpkgs) lastModified narHash rev;
            owner = "NixOS";
            repo = "nixpkgs";
            type = "github";
          };
          original = {
            owner = "NixOS";
            ref = "nixos-unstable";
            repo = "nixpkgs";
            type = "github";
          };
        };
        root = {
          inputs.nixpkgs = "nixpkgs";
        };
      };
      root = "root";
      version = 7;
    }
  );

  # Canned model reply for "install firefox" (the reply JSON run_claude would
  # return, not a pre-baked Resolution: the stub still goes through reply
  # schema validation and resolve_invocation).
  resolverStub = pkgs.writeText "resolver-stub.json" (
    builtins.toJSON {
      action = "invoke";
      capability = "app.install";
      params.app = "firefox";
      reason = "canned reply for the offline vm-cli scenario";
    }
  );

  test = pkgs.testers.runNixOSTest {
    name = "vm-cli";

    nodes.machine =
      { lib, ... }:
      {
        system.switch.enable = true;
        environment.etc."intentd/machine-profile.json".source = machineProfile;

        virtualisation = {
          memorySize = 6144;
          cores = 4;
          diskSize = 8192;
          writableStore = true;
          additionalPaths = [
            nixpkgs.outPath
            candidateFirefox
            candidateEmpty
            pythonEnv
            scenarioBase
            generatedFirefox
            generatedEmpty
            workspaceLock
            resolverStub
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

      python = "${pythonEnv}/bin/python3"
      machine.succeed("install -m 0600 ${journalKey} /run/intentd-journal-key")
      intent = (
          "INTENTD_JOURNAL_KEY_FILE=/run/intentd-journal-key "
          "INTENTD_RESOLVER_STUB=${resolverStub} "
          "${pythonEnv}/bin/intent --state-dir /var/lib/intentd --activate-mode test"
      )
      ws_py = "from pathlib import Path; import intentd.workspace as w; "

      def intent_json(args):
          out = machine.succeed(f"{intent} --json {args}")
          return json.loads(out.strip().splitlines()[-1])

      # --- workspace setup: init the shipped template, swap in the scenario
      # base.nix (test instrumentation + chaos unit), re-baseline the
      # manifest, then plant the lock that makes the production build path
      # hermetic. All of this runs before any transaction. ---
      machine.succeed(f"{python} -c '{ws_py}w.init_workspace(Path(\"/var/lib/intentd/ws\"))'")
      machine.succeed("install -m 0644 ${scenarioBase} /var/lib/intentd/ws/base.nix")
      machine.succeed(f"{python} -c '{ws_py}w.repair_manifest(Path(\"/var/lib/intentd/ws\"))'")
      machine.succeed("install -m 0644 ${workspaceLock} /var/lib/intentd/ws/flake.lock")

      # --- intent do "install firefox" via the stubbed resolver ---
      do1 = intent_json("do 'install firefox'")
      assert do1["outcome"] == "blessed", do1
      assert do1["added"] == ["firefox"] and do1["removed"] == [], do1

      hist = intent_json("history 1")
      assert len(hist) == 1, hist
      assert hist[0]["id"] == do1["txn"], hist
      assert hist[0]["status"] == "blessed", hist
      assert hist[0]["capability"] == "app.install", hist
      assert hist[0]["params"] == {"app": "firefox"}, hist

      machine.succeed("test -x /run/current-system/sw/bin/firefox")
      prof1 = machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()
      assert prof1 == "${candidateFirefox}", prof1
      machine.succeed("diff -u ${generatedFirefox} /var/lib/intentd/ws/generated.nix")

      st1 = intent_json("status")
      assert st1["warnings"] == [], st1
      assert st1["apps"] == ["firefox"], st1

      # --- dirty state: hand-edit generated.nix, status must exit 6 with the
      # workspace warning ---
      machine.succeed("echo '# out-of-band edit' >> /var/lib/intentd/ws/generated.nix")
      rc, out = machine.execute(f"{intent} status")
      assert rc == 6, (rc, out)
      assert "workspace differs from blessed state" in out, out

      # --- repair the manifest baseline, then revert back to empty ---
      machine.succeed(f"{python} -c '{ws_py}w.repair_manifest(Path(\"/var/lib/intentd/ws\"))'")
      rev = intent_json("revert")
      assert rev["outcome"] == "blessed", rev
      assert rev["removed"] == ["firefox"] and rev["added"] == [], rev

      machine.succeed("test ! -e /run/current-system/sw/bin/firefox")
      prof2 = machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()
      assert prof2 == "${candidateEmpty}", prof2
      machine.succeed("diff -u ${generatedEmpty} /var/lib/intentd/ws/generated.nix")

      st2 = intent_json("status")
      assert st2["warnings"] == [], st2
      assert st2["apps"] == [], st2
      assert st2["blessed_txn"] == rev["txn"], st2
    '';
  };
in
{
  inherit
    test
    candidateFirefox
    candidateEmpty
    pythonEnv
    workspaceLock
    resolverStub
    ;
}
