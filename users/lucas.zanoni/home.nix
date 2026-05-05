{ inputs, ... }:
{
  imports = [
    ./pkgs.nix

    ./home/git.nix
    ./home/ssh.nix
    ./home/session-vars.nix

    ../../home/core.nix

    ../../home/modules/agents

    ../../home/modules/claude
    ../../home/modules/codex

    ../../home/modules/terminal/atuin.nix
    ../../home/modules/terminal/fish.nix
    ../../home/modules/terminal/kitty.nix
    ../../home/modules/terminal/scripts.nix
    ../../home/modules/terminal/tmux.nix
    ../../home/modules/terminal/wezterm.nix
    ../../home/modules/terminal/yazi.nix

    ../../home/modules/editor/neovim.nix
    ../../home/modules/editor/vscode/vscode.nix

    ../../home/modules/desktop/theming.nix
    ../../home/modules/desktop/aerospace.nix
    ../../home/modules/desktop/application-launcher
    ../../home/modules/desktop/workspace-navigator.nix
    ../../home/modules/desktop/workspace-switcher-client.nix
    ../../home/modules/desktop/fonts.nix
    ../../home/modules/desktop/karabiner.nix
    ../../home/modules/desktop/keyboard-layout
    ../../home/modules/desktop/maccy.nix
    ../../home/modules/desktop/spaceman.nix
    ../../home/modules/desktop/summon-brave.nix
    ../../home/modules/desktop/summon-chrome.nix

    ../../home/modules/dev/devenv.nix
    ../../home/modules/dev/git.nix
    ../../home/modules/dev/glab.nix
    ../../home/modules/dev/jira.nix
    ../../home/modules/dev/lazygit.nix
    ../../home/modules/dev/scripts.nix

    ../../home/modules/terminal/bad-apple.nix
    ../../home/modules/terminal/cbonsai.nix
    ../../home/modules/terminal/cmatrix.nix

    ../../home/modules/security/agenix.nix

    ../../home/modules/network/tailscale-daemon.nix

    ../../home/modules/media/obsidian

    "${inputs.private-config}/sb-toolkit"
  ];
}
