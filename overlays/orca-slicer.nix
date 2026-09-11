_final: prev:
let
  # nixpkgs builds gst-plugins-bad with -Dgtk3=disabled, which drops the
  # gtksink element Orca's native-Wayland liveview needs. Flip just that
  # flag (gtk3 is already a build input via guiSupport).
  bad-gtk = prev.gst_all_1.gst-plugins-bad.overrideAttrs (old: {
    mesonFlags = map (f: if f == "-Dgtk3=disabled" then "-Dgtk3=enabled" else f) old.mesonFlags;
  });
  gstPath = prev.lib.makeSearchPath "lib/gstreamer-1.0" (
    with prev.gst_all_1;
    [
      gstreamer.out
      gst-plugins-base
      gst-plugins-good
      bad-gtk
      gst-plugins-ugly
      gst-libav
    ]
  );
  # Upstream nixpkgs#557126 (unmerged): gcc-unwrapped puts a static
  # libstdc++.a on the link line, so the executable carries its own C++
  # runtime while the dlopen'd Bambu network plugin uses the shared one.
  # Freeing across that boundary SIGABRTs on Print. Use only its lib
  # output until upstream merges.
  orca-fixed =
    (prev.orca-slicer.override {
      gcc-unwrapped = prev.lib.getLib prev.gcc-unwrapped;
    }).overrideAttrs
      (_old: {
        version = "2.4.2";
        src = prev.fetchFromGitHub {
          owner = "OrcaSlicer";
          repo = "OrcaSlicer";
          tag = "v2.4.2";
          sha256 = "1w4b7p4l5s7cglacjixff5chq3xc9v3lj15xfi28hyp48l5hnk41";
        };
      });
in
{
  orca-slicer = prev.symlinkJoin {
    name = "${orca-fixed.pname}-${orca-fixed.version}-gsettings-wrapped";
    paths = [ orca-fixed ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer \
        --prefix XDG_DATA_DIRS : "${prev.gsettings-desktop-schemas}/share/gsettings-schemas/${prev.gsettings-desktop-schemas.name}" \
        --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}" \
        --prefix GST_PLUGIN_SYSTEM_PATH : "${gstPath}" \
        --prefix GIO_EXTRA_MODULES : "${prev.glib-networking}/lib/gio/modules"
    '';
  };
}
