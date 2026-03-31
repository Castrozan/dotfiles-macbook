{ pkgs, lib, ... }:
let
  selectedThemeName = "kanagawa";

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

  vscodeThemeColorCustomizations = {
    "activityBar.background" = themeColorsToml.background;
    "activityBar.foreground" = themeColorsToml.foreground;
    "activityBar.border" = themeColorsToml.color8;
    "activityBarBadge.background" = themeColorsToml.accent;
    "sideBar.background" = themeColorsToml.background;
    "sideBar.foreground" = themeColorsToml.foreground;
    "sideBar.border" = themeColorsToml.color8;
    "sideBarTitle.foreground" = themeColorsToml.foreground;
    "sideBarSectionHeader.background" = themeColorsToml.background;
    "editor.background" = themeColorsToml.background;
    "editor.foreground" = themeColorsToml.foreground;
    "editorGroupHeader.tabsBackground" = themeColorsToml.background;
    "editorGutter.background" = themeColorsToml.background;
    "editorRuler.foreground" = themeColorsToml.color8;
    "tab.activeBackground" = themeColorsToml.background;
    "tab.activeForeground" = themeColorsToml.foreground;
    "tab.inactiveBackground" = themeColorsToml.background;
    "tab.inactiveForeground" = themeColorsToml.color8;
    "tab.border" = themeColorsToml.background;
    "titleBar.activeBackground" = themeColorsToml.background;
    "titleBar.activeForeground" = themeColorsToml.foreground;
    "titleBar.inactiveBackground" = themeColorsToml.background;
    "titleBar.inactiveForeground" = themeColorsToml.color8;
    "titleBar.border" = themeColorsToml.background;
    "statusBar.background" = themeColorsToml.background;
    "statusBar.foreground" = themeColorsToml.foreground;
    "statusBar.border" = themeColorsToml.color8;
    "statusBar.debuggingBackground" = themeColorsToml.color3;
    "statusBar.noFolderBackground" = themeColorsToml.background;
    "panel.background" = themeColorsToml.background;
    "panel.border" = themeColorsToml.color8;
    "panelTitle.activeForeground" = themeColorsToml.foreground;
    "panelTitle.inactiveForeground" = themeColorsToml.color8;
    "terminal.background" = themeColorsToml.background;
    "terminal.foreground" = themeColorsToml.foreground;
    "terminal.ansiBlack" = themeColorsToml.color0;
    "terminal.ansiRed" = themeColorsToml.color1;
    "terminal.ansiGreen" = themeColorsToml.color2;
    "terminal.ansiYellow" = themeColorsToml.color3;
    "terminal.ansiBlue" = themeColorsToml.color4;
    "terminal.ansiMagenta" = themeColorsToml.color5;
    "terminal.ansiCyan" = themeColorsToml.color6;
    "terminal.ansiWhite" = themeColorsToml.color7;
    "terminal.ansiBrightBlack" = themeColorsToml.color8;
    "terminal.ansiBrightRed" = themeColorsToml.color9;
    "terminal.ansiBrightGreen" = themeColorsToml.color10;
    "terminal.ansiBrightYellow" = themeColorsToml.color11;
    "terminal.ansiBrightBlue" = themeColorsToml.color12;
    "terminal.ansiBrightMagenta" = themeColorsToml.color13;
    "terminal.ansiBrightCyan" = themeColorsToml.color14;
    "terminal.ansiBrightWhite" = themeColorsToml.color15;
    "terminalCursor.foreground" = themeColorsToml.cursor;
    "list.activeSelectionBackground" = themeColorsToml.color8;
    "list.activeSelectionForeground" = themeColorsToml.foreground;
    "list.hoverBackground" = themeColorsToml.color8;
    "list.focusBackground" = themeColorsToml.color8;
    "focusBorder" = themeColorsToml.accent;
    "input.background" = themeColorsToml.background;
    "input.foreground" = themeColorsToml.foreground;
    "input.border" = themeColorsToml.color8;
    "dropdown.background" = themeColorsToml.background;
    "dropdown.foreground" = themeColorsToml.foreground;
    "dropdown.border" = themeColorsToml.color8;
    "quickInput.background" = themeColorsToml.background;
    "quickInput.foreground" = themeColorsToml.foreground;
    "badge.background" = themeColorsToml.accent;
    "badge.foreground" = themeColorsToml.foreground;
    "scrollbarSlider.background" = themeColorsToml.color8;
    "scrollbarSlider.hoverBackground" = themeColorsToml.color8;
    "scrollbarSlider.activeBackground" = themeColorsToml.accent;
    "widget.border" = themeColorsToml.color8;
    "widget.shadow" = themeColorsToml.background;
    "breadcrumb.background" = themeColorsToml.background;
    "breadcrumb.foreground" = themeColorsToml.color8;
    "breadcrumb.focusForeground" = themeColorsToml.foreground;
  };

  vscodeColorCustomizationsJsonFile = pkgs.writeText "vscode-theme-color-customizations.json" (
    builtins.toJSON vscodeThemeColorCustomizations
  );

  vscodeSettingsRelativePath =
    if pkgs.stdenv.isDarwin then
      "Library/Application Support/Code/User/settings.json"
    else
      ".config/Code/User/settings.json";

  vscodeThemeInjectionScript = ''
        VSCODE_SETTINGS_FILE="$HOME/${vscodeSettingsRelativePath}"
        if [ -f "$VSCODE_SETTINGS_FILE" ]; then
          ${pkgs.python312}/bin/python3 -c '
    import json, sys
    settings_path = sys.argv[1]
    colors_path = sys.argv[2]
    with open(settings_path) as f:
        settings = json.load(f)
    with open(colors_path) as f:
        colors = json.load(f)
    settings["workbench.colorCustomizations"] = colors
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    ' "$VSCODE_SETTINGS_FILE" "${vscodeColorCustomizationsJsonFile}"
        fi
  '';

  macosAppearanceActivationScript = ''
    CURRENT_DARK_MODE=$(/usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')
    DESIRED_DARK_MODE="${if themeIsLight then "false" else "true"}"
    if [ "$CURRENT_DARK_MODE" != "$DESIRED_DARK_MODE" ]; then
      /usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to '"$DESIRED_DARK_MODE" || true
    fi

    CURRENT_WALLPAPER=$(/usr/bin/osascript -e 'tell application "System Events" to tell desktop 1 to get picture')
    DESIRED_WALLPAPER="${selectedWallpaperPath}"
    if [ "$CURRENT_WALLPAPER" != "$DESIRED_WALLPAPER" ]; then
      /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "'"$DESIRED_WALLPAPER"'"' || true
    fi

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

    CURRENT_ACCENT_COLOR=$(/usr/bin/defaults read -g AppleAccentColor 2>/dev/null || echo "4")
    if [ "$MACOS_ACCENT_COLOR" != "$CURRENT_ACCENT_COLOR" ]; then
      if [ "$MACOS_ACCENT_COLOR" = "4" ]; then
        /usr/bin/defaults delete -g AppleAccentColor 2>/dev/null || true
      else
        /usr/bin/defaults write -g AppleAccentColor -int "$MACOS_ACCENT_COLOR"
      fi
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

  programs.wezterm.extraConfig = lib.mkBefore ''
    local themeTerminalColors = config.colors or {}
    themeTerminalColors.ansi = {
      "${themeColorsToml.color0}",
      "${themeColorsToml.color1}",
      "${themeColorsToml.color2}",
      "${themeColorsToml.color3}",
      "${themeColorsToml.color4}",
      "${themeColorsToml.color5}",
      "${themeColorsToml.color6}",
      "${themeColorsToml.color7}",
    }
    themeTerminalColors.brights = {
      "${themeColorsToml.color8}",
      "${themeColorsToml.color9}",
      "${themeColorsToml.color10}",
      "${themeColorsToml.color11}",
      "${themeColorsToml.color12}",
      "${themeColorsToml.color13}",
      "${themeColorsToml.color14}",
      "${themeColorsToml.color15}",
    }
    themeTerminalColors.cursor_bg = "${themeColorsToml.cursor}"
    themeTerminalColors.cursor_fg = "${themeColorsToml.background}"
    themeTerminalColors.selection_bg = "${themeColorsToml.selection_background}"
    themeTerminalColors.selection_fg = "${themeColorsToml.selection_foreground}"
    config.colors = themeTerminalColors
  '';

  home.activation.injectVscodeThemeColors = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] vscodeThemeInjectionScript;

  home.activation.applyMacosThemeAppearance = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] macosAppearanceActivationScript;
}
