{
  pkgs,
  lib,
  inputs,
  nixpkgs-version,
  home-version,
}:
let
  helpers = import ../../../../tests/nix-checks/helpers.nix {
    inherit
      pkgs
      lib
      inputs
      nixpkgs-version
      home-version
      ;
  };
  inherit (helpers) mkEvalCheck;

  cfg = helpers.homeManagerTestConfiguration [
    ../fish.nix
    ../kitty.nix
    ../tmux.nix
    ../wezterm.nix
    ../atuin.nix
    ../yazi.nix
  ];

  fishConfDFiles = [
    "fish/conf.d/shell-env.fish"
    "fish/conf.d/tmux.fish"
    "fish/conf.d/fish-aliases.fish"
    "fish/conf.d/fzf.fish"
    "fish/conf.d/default-directories.fish"
    "fish/conf.d/key-bindings.fish"
    "fish/conf.d/private-aliases.fish"
    "fish/conf.d/hyprland-env.fish"
    "fish/conf.d/secrets.fish"
  ];

  fishFunctionFiles = [
    "fish/functions/fish_prompt.fish"
    "fish/functions/cursor.fish"
    "fish/functions/nix.fish"
  ];

  allFishConfDFilesDeployed = builtins.all (f: cfg.xdg.configFile ? "${f}") fishConfDFiles;

  allFishFunctionFilesDeployed = builtins.all (f: cfg.xdg.configFile ? "${f}") fishFunctionFiles;

  fishShellInitHasNoHardcodedSources =
    !(lib.hasInfix "source ~/.dotfiles/" cfg.programs.fish.interactiveShellInit);

  bashrcContent = builtins.readFile ../shell/.bashrc;
  bashrcHasNoHardcodedSources = !(lib.hasInfix ". $HOME/.dotfiles/" bashrcContent);

  weztermLuaContent = builtins.readFile ../../../../.config/wezterm/wezterm.lua;

  weztermHasCsiUKeyEncoding = lib.hasInfix "enable_csi_u_key_encoding = true" weztermLuaContent;

  weztermShiftEnterNotOverridden = !(lib.hasInfix "key = 'Enter', mods = 'SHIFT'" weztermLuaContent);

  screensaverContent = builtins.readFile ../shell/screensaver.sh;
  tmuxMainContent = builtins.readFile ../shell/tmux_main.sh;
  bashrcWithDependenciesFirst = builtins.concatStringsSep "\n" [
    screensaverContent
    tmuxMainContent
    bashrcContent
  ];
  startTmuxCallPosition = builtins.stringLength (
    builtins.head (lib.splitString "_start_tmux\n" bashrcWithDependenciesFirst)
  );
  screensaverFunctionPosition = builtins.stringLength (
    builtins.head (lib.splitString "_start_screensaver_tmux_session" screensaverContent)
  );
  tmuxFunctionsDefinedBeforeCall = startTmuxCallPosition > screensaverFunctionPosition;
in
{
  domain-terminal-fish-enabled =
    mkEvalCheck "domain-terminal-fish-enabled"
      (cfg.programs.fish.enable && builtins.length cfg.programs.fish.plugins >= 3)
      "fish should be enabled with >= 3 plugins, got ${toString (builtins.length cfg.programs.fish.plugins)}";

  domain-terminal-carapace-enabled =
    mkEvalCheck "domain-terminal-carapace-enabled" cfg.programs.carapace.enable
      "carapace completion should be enabled";

  domain-terminal-fish-conf-d-deployed =
    mkEvalCheck "domain-terminal-fish-conf-d-deployed" allFishConfDFilesDeployed
      "all fish conf.d files should be deployed via xdg.configFile";

  domain-terminal-fish-functions-deployed =
    mkEvalCheck "domain-terminal-fish-functions-deployed" allFishFunctionFilesDeployed
      "all fish function files should be deployed via xdg.configFile";

  domain-terminal-fish-no-hardcoded-sources =
    mkEvalCheck "domain-terminal-fish-no-hardcoded-sources" fishShellInitHasNoHardcodedSources
      "fish interactiveShellInit should not contain hardcoded source ~/.dotfiles/ paths";

  domain-terminal-bash-no-hardcoded-sources =
    mkEvalCheck "domain-terminal-bash-no-hardcoded-sources" bashrcHasNoHardcodedSources
      ".bashrc should not contain hardcoded . $HOME/.dotfiles/ source lines";

  domain-terminal-bash-tmux-functions-before-call =
    mkEvalCheck "domain-terminal-bash-tmux-functions-before-call" tmuxFunctionsDefinedBeforeCall
      "screensaver/tmux functions must be defined before _start_tmux call in concatenated bashrc";

  domain-terminal-kitty-enabled =
    mkEvalCheck "domain-terminal-kitty-enabled" cfg.programs.kitty.enable
      "kitty should be enabled";

  domain-terminal-tmux-config = mkEvalCheck "domain-terminal-tmux-config" (
    cfg.programs.tmux.enable && cfg.programs.tmux.baseIndex == 1
  ) "tmux should be enabled with baseIndex 1";

  domain-terminal-wezterm-enabled =
    mkEvalCheck "domain-terminal-wezterm-enabled" cfg.programs.wezterm.enable
      "wezterm should be enabled";

  domain-terminal-atuin-enabled = mkEvalCheck "domain-terminal-atuin-enabled" (
    cfg.programs.atuin.enable && cfg.programs.atuin.enableBashIntegration
  ) "atuin should be enabled with bash integration";

  domain-terminal-yazi-enabled =
    mkEvalCheck "domain-terminal-yazi-enabled" cfg.programs.yazi.enable
      "yazi file manager should be enabled";

  domain-terminal-wezterm-csi-u-enabled =
    mkEvalCheck "domain-terminal-wezterm-csi-u-enabled" weztermHasCsiUKeyEncoding
      "wezterm must have enable_csi_u_key_encoding = true for proper modifier key sequences";

  domain-terminal-wezterm-shift-enter-not-overridden =
    mkEvalCheck "domain-terminal-wezterm-shift-enter-not-overridden" weztermShiftEnterNotOverridden
      "wezterm must not override Shift+Enter; CSI-u encoding handles it for Claude Code newlines";
}
