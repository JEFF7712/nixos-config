_final: prev:
let
  gstPath = prev.lib.makeSearchPath "lib/gstreamer-1.0" (
    with prev.gst_all_1;
    [
      gstreamer.out
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
      gst-plugins-ugly
      gst-libav
    ]
  );
in
{
  orca-slicer = prev.symlinkJoin {
    name = "${prev.orca-slicer.pname}-${prev.orca-slicer.version}-gsettings-wrapped";
    paths = [ prev.orca-slicer ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer \
        --prefix XDG_DATA_DIRS : "${prev.gsettings-desktop-schemas}/share/gsettings-schemas/${prev.gsettings-desktop-schemas.name}" \
        --prefix GST_PLUGIN_SYSTEM_PATH : "${gstPath}" \
        --prefix GIO_EXTRA_MODULES : "${prev.glib-networking}/lib/gio/modules"
    '';
  };
}
