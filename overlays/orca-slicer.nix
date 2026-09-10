_final: prev: {
  orca-slicer = prev.symlinkJoin {
    name = "${prev.orca-slicer.pname}-${prev.orca-slicer.version}-gsettings-wrapped";
    paths = [ prev.orca-slicer ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer \
        --prefix XDG_DATA_DIRS : "${prev.gsettings-desktop-schemas}/share/gsettings-schemas/${prev.gsettings-desktop-schemas.name}"
    '';
  };
}
