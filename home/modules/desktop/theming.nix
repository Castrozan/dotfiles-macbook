{ pkgs, lib, ... }:
let
  selectedThemeName = "catppuccin";

  themesDirectory = ../../../static/themes;

  themeColorsToml = builtins.fromTOML (
    builtins.readFile (themesDirectory + "/${selectedThemeName}/colors.toml")
  );

  themeIsLight = builtins.pathExists (themesDirectory + "/${selectedThemeName}/light.mode");

  themeBackgroundFileNames = builtins.attrNames (
    builtins.readDir (themesDirectory + "/${selectedThemeName}/backgrounds")
  );

  sortedBackgroundFileNames = builtins.sort (a: b: a < b) themeBackgroundFileNames;

  firstBackgroundFileName = builtins.head sortedBackgroundFileNames;

  selectedWallpaperPath =
    themesDirectory + "/${selectedThemeName}/backgrounds/${firstBackgroundFileName}";

  removeHashFromColor = color: lib.removePrefix "#" color;

  themeAccentColorHex = removeHashFromColor themeColorsToml.accent;

  macosAppearanceActivationScript = ''
    /usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to ${
      if themeIsLight then "false" else "true"
    }' || true

    /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${selectedWallpaperPath}"' || true

    MACOS_ACCENT_COLOR=$(/usr/bin/python3 -c "
    import colorsys
    r, g, b = int('${themeAccentColorHex}'[0:2], 16)/255, int('${themeAccentColorHex}'[2:4], 16)/255, int('${themeAccentColorHex}'[4:6], 16)/255
    h, _, s = colorsys.rgb_to_hsv(r, g, b)
    hue = h * 360
    if s < 0.1: print(-1)
    elif hue < 15 or hue >= 345: print(0)
    elif hue < 45: print(1)
    elif hue < 75: print(2)
    elif hue < 165: print(3)
    elif hue < 255: print(4)
    elif hue < 300: print(5)
    else: print(6)
    ")

    if [ "$MACOS_ACCENT_COLOR" = "4" ]; then
      /usr/bin/defaults delete -g AppleAccentColor 2>/dev/null || true
    else
      /usr/bin/defaults write -g AppleAccentColor -int "$MACOS_ACCENT_COLOR"
    fi
  '';
in
{
  stylix = {
    enable = true;
    autoEnable = false;

    image = selectedWallpaperPath;
    polarity = if themeIsLight then "light" else "dark";

    base16Scheme = {
      base00 = removeHashFromColor themeColorsToml.background;
      base01 = removeHashFromColor themeColorsToml.color0;
      base02 = removeHashFromColor themeColorsToml.selection_background;
      base03 = removeHashFromColor themeColorsToml.color8;
      base04 = removeHashFromColor themeColorsToml.color7;
      base05 = removeHashFromColor themeColorsToml.foreground;
      base06 = removeHashFromColor themeColorsToml.color15;
      base07 = removeHashFromColor themeColorsToml.cursor;
      base08 = removeHashFromColor themeColorsToml.color1;
      base09 = removeHashFromColor themeColorsToml.color9;
      base0A = removeHashFromColor themeColorsToml.color3;
      base0B = removeHashFromColor themeColorsToml.color2;
      base0C = removeHashFromColor themeColorsToml.color6;
      base0D = removeHashFromColor themeColorsToml.color4;
      base0E = removeHashFromColor themeColorsToml.color5;
      base0F = removeHashFromColor themeColorsToml.accent;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        terminal = 16;
        applications = 14;
        desktop = 12;
        popups = 14;
      };
    };

    opacity = {
      terminal = 1.0;
    };

    targets = {
      kitty.enable = true;
      wezterm.enable = true;
      bat.enable = true;
      btop.enable = true;
      yazi.enable = false;
      lazygit.enable = true;

      tmux.enable = false;
      neovim.enable = false;
      vim.enable = false;
      fish.enable = false;
      fzf.enable = false;
    };
  };

  home.activation.applyMacosThemeAppearance = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] macosAppearanceActivationScript;
}
