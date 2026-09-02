final: prev: {
  plymouth-nixos-logo = final.callPackage ../pkgs/plymouth-nixos-logo { };
  xhisper-local = final.callPackage ../pkgs/xhisper-local { };
  cursor-agent = final.callPackage ../pkgs/cursor-agent { };
  claude-code-proxy = final.callPackage ../pkgs/claude-code-proxy { };
  muse-code = final.callPackage ../pkgs/muse-code { };
  maple-mono-nf = final.callPackage ../pkgs/maple-mono { };
  iris-python = final.callPackage ../pkgs/iris-python { };
  swayosd = prev.swayosd.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../pkgs/swayosd/osd-fade.patch ];
  });
}
