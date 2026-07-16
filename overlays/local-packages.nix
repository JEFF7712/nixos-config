final: _prev: {
  plymouth-nixos-logo = final.callPackage ../pkgs/plymouth-nixos-logo { };
  xhisper-local = final.callPackage ../pkgs/xhisper-local { };
  cursor-agent = final.callPackage ../pkgs/cursor-agent { };
  claude-code-proxy = final.callPackage ../pkgs/claude-code-proxy { };
  maple-mono-nf = final.callPackage ../pkgs/maple-mono { };
  iris-python = final.callPackage ../pkgs/iris-python { };
}
