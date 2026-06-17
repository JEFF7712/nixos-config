let
  # Per-profile spicetify pick: (current_theme, color_scheme, inject_theme_js).
  # js=1 only for themes that need their own script (e.g. Dribbblish); Comfy
  # uses js=0 since its script overrides the color scheme. Consumed by
  # apply_spicetify_theme in home/scripts/profile-common.
  spice = theme: scheme: js: { inherit theme scheme js; };
in
{
  catppuccin = {
    firefox.dark = {
      main = "30, 30, 46";
      secondary = "24, 24, 37";
      accent = "203, 166, 247";
      text = "205, 214, 244";
      accentHsl = "hsl(267, 84%, 81%)";
    };
    firefox.light = {
      main = "239, 241, 245";
      secondary = "230, 233, 239";
      accent = "136, 57, 239";
      text = "76, 79, 105";
      accentHsl = "hsl(266, 85%, 58%)";
    };
    pywal.dark = "base16-nord";
    zed.dark = {
      theme = "Catppuccin Mocha (Blur)";
      icon = "Catppuccin Mocha";
    };
    zed.light = {
      theme = "Catppuccin Latte (Blur)";
      icon = "Catppuccin Latte";
    };
    vesktop.dark = "catppuccin.theme.css";
    obsidian.dark = "minimal-catppuccin-dark";
    obsidian.light = "minimal-catppuccin-light";
    spicetify.dark = spice "catppuccin" "mocha" 0;
    spicetify.light = spice "catppuccin" "latte" 0;
  };

  nord = {
    firefox.dark = {
      main = "46, 52, 64";
      secondary = "59, 66, 82";
      accent = "136, 192, 208";
      text = "216, 222, 233";
      accentHsl = "hsl(193, 43%, 78%)";
    };
    pywal.dark = "base16-nord";
    zed.dark = {
      theme = "Nord Dark";
      icon = "Zed (Default)";
    };
    vesktop.dark = "nord.theme.css";
    obsidian.dark = "minimal-nord-dark";
    spicetify.dark = spice "Comfy" "Nord" 0;
  };

  noctalia = {
    zed.dark = {
      theme = "Ayu Dark";
      icon = "Material Icon Theme";
    };
    vesktop.dark = "noctalia.theme.css";
    obsidian.dark = "minimal-flexoki-dark";
    spicetify.dark = spice "Comfy" "Comfy" 0;
  };

  gruvbox = {
    firefox.dark = {
      main = "40, 40, 40";
      secondary = "60, 56, 54";
      accent = "250, 189, 47";
      text = "235, 219, 178";
      accentHsl = "hsl(43, 95%, 58%)";
    };
    firefox.light = {
      main = "251, 241, 199";
      secondary = "235, 219, 178";
      accent = "181, 118, 20";
      text = "60, 56, 54";
      accentHsl = "hsl(38, 80%, 39%)";
    };
    pywal.dark = "base16-gruvbox-dark-hard";
    zed.dark = {
      theme = "Gruvbox Dark";
      icon = "Material Icon Theme";
    };
    zed.light = {
      theme = "Gruvbox Light";
      icon = "Material Icon Theme";
    };
    vesktop.dark = "gruvbox.theme.css";
    obsidian.dark = "minimal-gruvbox-dark";
    obsidian.light = "minimal-gruvbox-light";
    spicetify.dark = spice "Dribbblish" "gruvbox-material-dark" 1;
    spicetify.light = spice "Comfy" "Hikari" 0;
  };

  rosepine = {
    firefox.dark = {
      main = "25, 23, 36";
      secondary = "31, 29, 46";
      accent = "196, 167, 231";
      text = "224, 222, 244";
      accentHsl = "hsl(267, 57%, 78%)";
    };
    firefox.light = {
      main = "250, 244, 237";
      secondary = "255, 250, 243";
      accent = "144, 122, 169";
      text = "87, 82, 121";
      accentHsl = "hsl(270, 21%, 57%)";
    };
    pywal.dark = "base16-rose-pine";
    zed.dark = {
      theme = "Rosé Pine";
      icon = "Zed (Default)";
    };
    zed.light = {
      theme = "Rosé Pine Dawn";
      icon = "Zed (Default)";
    };
    vesktop.dark = "rosepine.theme.css";
    obsidian.dark = "minimal-rose-pine-dark";
    obsidian.light = "minimal-rose-pine-light";
    spicetify.dark = spice "Comfy" "rose-pine" 0;
    spicetify.light = spice "Comfy" "rose-pine-dawn" 0;
  };

  everforest = {
    firefox.dark = {
      main = "39, 46, 51";
      secondary = "46, 56, 60";
      accent = "167, 192, 128";
      text = "211, 198, 170";
      accentHsl = "hsl(96, 27%, 63%)";
    };
    firefox.light = {
      main = "255, 249, 232";
      secondary = "244, 240, 217";
      accent = "141, 161, 1";
      text = "92, 106, 114";
      accentHsl = "hsl(75, 99%, 32%)";
    };
    pywal.dark = "base16-everforest";
    zed.dark = {
      theme = "Everforest Dark Hard (blur)";
      icon = "Material Icon Theme";
    };
    zed.light = {
      theme = "Everforest Light Hard (blur)";
      icon = "Material Icon Theme";
    };
    vesktop.dark = "everforest.theme.css";
    obsidian.dark = "minimal-everforest-dark";
    obsidian.light = "minimal-everforest-light";
    spicetify.dark = spice "Comfy" "Everforest" 0;
    spicetify.light = spice "Comfy" "Hikari" 0;
  };

  sharp = {
    firefox.dark = {
      main = "20, 20, 20";
      secondary = "28, 28, 28";
      accent = "224, 224, 224";
      text = "242, 242, 242";
      accentHsl = "hsl(0, 0%, 88%)";
    };
    firefox.light = {
      main = "250, 250, 250";
      secondary = "240, 240, 240";
      accent = "26, 26, 26";
      text = "20, 20, 20";
      accentHsl = "hsl(0, 0%, 10%)";
    };
    pywal.dark = "base16-grayscale";
    zed.dark = {
      theme = "Transparent Prism";
      icon = "Zed (Default)";
    };
    zed.light = {
      theme = "One Light";
      icon = "Zed (Default)";
    };
    vesktop.dark = "sharp.theme.css";
    obsidian.dark = "minimal-flexoki-dark";
    obsidian.light = "minimal-flexoki-light";
    spicetify.dark = spice "Sleek" "VantaBlack" 0;
    spicetify.light = spice "Comfy" "Hikari" 0;
  };

  clean = {
    firefox.dark = {
      main = "16, 16, 16";
      secondary = "23, 23, 23";
      accent = "238, 238, 238";
      text = "216, 216, 216";
      accentHsl = "hsl(0, 0%, 93%)";
    };
    pywal.dark = "base16-grayscale";
    zed.dark = {
      theme = "Transparent Prism";
      icon = "Zed (Default)";
    };
    vesktop.dark = "sharp.theme.css";
    obsidian.dark = "minimal-flexoki-dark";
    spicetify.dark = spice "Comfy" "Mono" 0;
  };

  tinted = {
    spicetify.dark = spice "Comfy" "tinted" 0;
    spicetify.light = spice "Comfy" "tinted" 0;
  };
}
