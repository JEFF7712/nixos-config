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
  # Merged upstream in nixpkgs#557126, but absent from our pinned nixpkgs:
  # gcc-unwrapped puts a static
  # libstdc++.a on the link line, so the executable carries its own C++
  # runtime while the dlopen'd Bambu network plugin uses the shared one.
  # Freeing across that boundary SIGABRTs on Print. Use only its lib
  # output until the nixpkgs pin contains cb3ee9815692e6f5bb663be24582b022695a490a.
  orca-fixed = prev.orca-slicer.override {
    gcc-unwrapped = prev.lib.getLib prev.gcc-unwrapped;
  };
in
{
  orca-slicer = prev.symlinkJoin {
    name = "${orca-fixed.pname}-${orca-fixed.version}-gsettings-wrapped";
    paths = [ orca-fixed ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      # Force XWayland: native Wayland liveview needs a GStreamer GTK sink,
      # but nixpkgs ships neither gtksink nor gtkwaylandsink (1.26 removed
      # the former; the latter was never packaged). X11 uses wxMediaCtrl.
      # Revert once upstream ships the FFmpeg player rewrite on main.
      wrapProgram $out/bin/orca-slicer \
        --prefix XDG_DATA_DIRS : "${prev.gsettings-desktop-schemas}/share/gsettings-schemas/${prev.gsettings-desktop-schemas.name}" \
        --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}" \
        --prefix GST_PLUGIN_SYSTEM_PATH : "${gstPath}" \
        --prefix GIO_EXTRA_MODULES : "${prev.glib-networking}/lib/gio/modules" \
        --set GDK_BACKEND "x11"
    '';
  };
}
