{
  lib,
  pkgs,
  nix-agent,
  ...
}:
let
  nixAgentPackage = nix-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  preflightPython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.fastmcp ]);
  mcpPreflight = pkgs.writeShellScriptBin "baseline-mcp-preflight" ''
    exec ${preflightPython}/bin/python ${./mcp-preflight.py} "$@"
  '';
  cursorMcpTimeoutPatch = pkgs.writeShellScriptBin "baseline-patch-cursor-mcp-timeout" ''
    exec ${pkgs.python3}/bin/python ${./cursor-mcp-timeout-patch.py} "$@"
  '';
  cursorAgentRunner = pkgs.writeShellScriptBin "baseline-cursor-agent" ''
    set -euo pipefail
    if [ "$#" -lt 2 ]; then
      echo "usage: baseline-cursor-agent NODE BUNDLE [ARG ...]" >&2
      exit 64
    fi
    node_path=$1
    bundle_path=$2
    shift 2
    expected_root=/nix/store/1my44nnw4m6w9g5ja5wdqm8x89m36zc2-cursor-agent-2026.08.11-e8db854
    if [ "$node_path" != "$expected_root/node" ] || \
       [ "$bundle_path" != "$expected_root/index.js" ] || \
       [ -L "$node_path" ] || [ -L "$bundle_path" ] || \
       [ ! -f "$node_path" ] || [ ! -x "$node_path" ] || [ ! -f "$bundle_path" ]; then
      echo "baseline-cursor-agent: expected verified regular Node and bundle siblings" >&2
      exit 65
    fi
    if [ "$(${pkgs.coreutils}/bin/realpath -e "$node_path")" != "$node_path" ] || \
       [ "$(${pkgs.coreutils}/bin/realpath -e "$bundle_path")" != "$bundle_path" ]; then
      echo "baseline-cursor-agent: task-facing paths must be canonical" >&2
      exit 65
    fi
    node_sha=$(${pkgs.coreutils}/bin/sha256sum "$node_path" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)
    bundle_sha=$(${pkgs.coreutils}/bin/sha256sum "$bundle_path" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)
    if [ "$node_sha" != e0e46d3a1c0667117303412647cafcbcefb1be7612493015ec8fd6b7440162a4 ] || \
       [ "$bundle_sha" != 7ffab05b9b62b90d3abe22d02a1fbcabe16b01897853aa810ce2694425d1aa3a ]; then
      echo "baseline-cursor-agent: task-facing artifact verification failed" >&2
      exit 66
    fi
    export PATH=/run/wrappers/bin:/run/current-system/sw/bin
    exec ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
      --library-path ${
        lib.makeLibraryPath [
          pkgs.glibc
          pkgs.stdenv.cc.cc.lib
          pkgs.zlib
        ]
      } \
      "$node_path" --use-system-ca "$bundle_path" --disable-auto-update "$@"
  '';
  trustedPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.sudo
    pkgs.systemd
  ];
  launcherSource = builtins.toFile "nix-agent-launcher.c" (builtins.readFile ./nix-agent-launcher.c);
  launcher = pkgs.runCommandCC "nix-agent-mcp-launcher" { } ''
    substitute ${launcherSource} launcher.c \
      --replace-fail '@NIX_AGENT_EXEC@' '${nixAgentPackage}/bin/nix-agent' \
      --replace-fail '@TRUSTED_PATH@' '${trustedPath}'
    mkdir -p $out/bin
    $CC -std=c11 -O2 -Wall -Wextra -Werror launcher.c -o $out/bin/nix-agent-mcp
  '';
in
{
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;
  users.users = {
    wedge = {
      isNormalUser = true;
      initialPassword = "wedge";
      extraGroups = [ ];
    };
    root.hashedPassword = "!";
  };

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = true;
  };

  environment.systemPackages = [
    nixAgentPackage
    mcpPreflight
    cursorMcpTimeoutPatch
    cursorAgentRunner
  ];

  systemd.tmpfiles.rules = [
    "d /var/log/nix-agent-baseline 0755 root root -"
    "d /run/nix-agent-baseline 0755 root root -"
  ];

  security.wrappers.nix-agent-mcp = {
    source = "${launcher}/bin/nix-agent-mcp";
    owner = "root";
    group = "root";
    permissions = "u+rx,g+rx,o+rx";
    setuid = true;
  };
}
