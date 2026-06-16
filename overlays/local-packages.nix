final: _prev: {
  plymouth-nixos-logo = final.callPackage ../pkgs/plymouth-nixos-logo { };
  xhisper-local = final.callPackage ../pkgs/xhisper-local { };
  maple-mono-nf = final.callPackage ../pkgs/maple-mono { };
  iris-python = final.callPackage ../pkgs/iris-python { };
}
