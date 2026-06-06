{ nixos-icons, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nixos-logo-plymouth-theme";
  version = "1";
  dontUnpack = true;

  installPhase = ''
    theme_dir="$out/share/plymouth/themes/nixos-logo"
    mkdir -p "$theme_dir"

    cat > "$theme_dir/nixos-logo.plymouth" <<EOF
    [Plymouth Theme]
    Name=NixOS Logo
    Description=Minimal Plymouth theme that shows only the NixOS logo
    ModuleName=script

    [script]
    ImageDir=$theme_dir
    ScriptFile=$theme_dir/nixos-logo.script
    EOF

    cat > "$theme_dir/nixos-logo.script" <<'EOF'
    Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
    Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

    logo.image = Image("special://logo");
    logo.sprite = Sprite();

    fun center_logo()
    {
      logo.sprite.SetImage(logo.image);
      logo.sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
      logo.sprite.SetY(Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
      logo.sprite.SetZ(100);
      logo.sprite.SetOpacity(1);
    }

    center_logo();
    Plymouth.SetRefreshFunction(center_logo);

    fun quit_callback()
    {
      center_logo();
    }

    Plymouth.SetQuitFunction(quit_callback);
    EOF
  '';

  passthru.logo = "${nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake.png";
}
