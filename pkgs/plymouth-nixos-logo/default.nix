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
    Description=NixOS logo with graphical disk unlock prompt
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

    auth.prompt_sprite = Sprite();
    auth.bullets_sprite = Sprite();
    auth.message_sprite = Sprite();
    auth.visible = 0;
    auth.message_visible = 0;

    fun layout_auth()
    {
      if (auth.visible)
      {
        auth.prompt_sprite.SetPosition(
          Window.GetX() + Window.GetWidth() / 2 - auth.prompt_image.GetWidth() / 2,
          Window.GetY() + Window.GetHeight() / 2 + logo.image.GetHeight() / 2 + 28,
          1000
        );
        auth.bullets_sprite.SetPosition(
          Window.GetX() + Window.GetWidth() / 2 - auth.bullets_image.GetWidth() / 2,
          Window.GetY() + Window.GetHeight() / 2 + logo.image.GetHeight() / 2 + 58,
          1000
        );
      }

      if (auth.message_visible)
      {
        auth.message_sprite.SetPosition(
          Window.GetX() + Window.GetWidth() / 2 - auth.message_image.GetWidth() / 2,
          Window.GetY() + Window.GetHeight() / 2 + logo.image.GetHeight() / 2 + 88,
          1000
        );
      }
    }

    fun center_logo()
    {
      logo.sprite.SetImage(logo.image);
      logo.sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
      logo.sprite.SetY(Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
      logo.sprite.SetZ(100);
      logo.sprite.SetOpacity(1);
      layout_auth();
    }

    center_logo();
    Plymouth.SetRefreshFunction(center_logo);

    fun display_normal_callback()
    {
      auth.visible = 0;
      auth.prompt_sprite.SetOpacity(0);
      auth.bullets_sprite.SetOpacity(0);
    }

    fun display_password_callback(prompt, bullets)
    {
      auth.bullet_text = "";
      for (index = 0; index < bullets; index++)
      {
        auth.bullet_text += "* ";
      }

      auth.prompt_image = Image.Text(prompt, 1, 1, 1);
      auth.bullets_image = Image.Text(auth.bullet_text, 1, 1, 1);
      auth.prompt_sprite.SetImage(auth.prompt_image);
      auth.bullets_sprite.SetImage(auth.bullets_image);
      auth.prompt_sprite.SetOpacity(1);
      auth.bullets_sprite.SetOpacity(1);
      auth.visible = 1;
      layout_auth();
    }

    Plymouth.SetDisplayNormalFunction(display_normal_callback);
    Plymouth.SetDisplayPasswordFunction(display_password_callback);

    fun display_message_callback(message)
    {
      auth.message_image = Image.Text(message, 1, 0.35, 0.35);
      auth.message_sprite.SetImage(auth.message_image);
      auth.message_sprite.SetOpacity(1);
      auth.message_visible = 1;
      layout_auth();
    }

    fun hide_message_callback(message)
    {
      auth.message_sprite.SetOpacity(0);
      auth.message_visible = 0;
    }

    Plymouth.SetDisplayMessageFunction(display_message_callback);
    Plymouth.SetHideMessageFunction(hide_message_callback);

    fun quit_callback()
    {
      center_logo();
    }

    Plymouth.SetQuitFunction(quit_callback);
    EOF
  '';

  passthru.logo = "${nixos-icons}/share/icons/hicolor/96x96/apps/nix-snowflake.png";
}
