{ pkgs, config, ... }:
let
  hooksConfig = import ./hook-config.nix;
  pluginsConfig = import ./plugins.nix { inherit pkgs; };

  claudeKeybindings = {
    "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
    "$docs" = "https://code.claude.com/docs/en/keybindings";
    bindings = [
      {
        context = "Chat";
        bindings = {
          "ctrl+e" = "chat:undo";
        };
      }
    ];
  };

  claudeGlobalSettings = {
    model = "opus";
    effortLevel = "max";
    language = "english";
    spinnerTipsEnabled = false;
    dangerouslySkipPermissions = true;
    skipDangerousModePermissionPrompt = true;
    includeCoAuthoredBy = false;
    includeGitInstructions = false;
    showTurnDuration = true;
    teammateMode = "tmux";
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      CLAUDE_ENABLE_STREAM_WATCHDOG = "1";
      PATH = "/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
    };
    permissions = {
      defaultMode = "bypassPermissions";
      allow = [ "*" ];
      deny = [ ];
    };
    terminalShowHoverHint = false;
    statusLine = {
      type = "command";
      command = "bash $HOME/.claude/statusline-command.sh";
    };
    composer = {
      shouldChimeAfterChatFinishes = true;
    };
    fileFiltering = {
      respectGitignore = true;
    };
    hooks = hooksConfig;
  };

  claudeGlobalSettingsJson = builtins.toJSON claudeGlobalSettings;

  coreAgentRawContent = builtins.readFile ../../../agents/core.md;
  coreAgentSplitOnFrontmatterDelimiter = builtins.split "---\n" coreAgentRawContent;
  coreAgentBodyWithoutFrontmatter = builtins.elemAt coreAgentSplitOnFrontmatterDelimiter 4;

  claudeDotfilesRules = ''
    @AGENTS.md

    ## Policies

    ### External repository access

    The repository github.com/castrozan/.dotfiles must never be cloned locally, not to the working directory, /tmp, or any path on this machine. It contains filenames that are prohibited on local disk by infra policy. All access to that repo must go through GitHub API (`gh api`, `gh browse`) or HTTPS raw file fetches. This constraint applies to all agents, subagents, worktrees, and one-shot sessions without exception.

    ### Compositor reload

    System rebuilds must never cause visual disruption to the running compositor. Configuration reloads that do not involve monitor hardware changes must not re-apply monitor rules, as mode negotiation causes DRM mode switches visible as screen blackouts. Compositor autoreload from config management symlink updates must be suppressed because the config directory symlink changes on every rebuild regardless of content. Only monitor hardware events (plug, unplug, manual toggle) justify full compositor reload with monitor re-application.
  '';

  claudeGlobalRules = coreAgentBodyWithoutFrontmatter;
in
{
  home = {
    inherit (pluginsConfig) packages;
    file = {
      ".claude/.keep".text = "";
      ".claude/statusline-command.sh".source = ./scripts/statusline-command.sh;
      ".claude/settings.json.nix-source".text = claudeGlobalSettingsJson;
      ".claude/keybindings.json".text = builtins.toJSON claudeKeybindings;
      ".dotfiles/CLAUDE.md".text = claudeDotfilesRules;
      ".claude/CLAUDE.md".text = claudeGlobalRules;
    };

    sessionVariables = {
      CLAUDE_CODE_SHELL = "${pkgs.bash}/bin/bash";
      CLAUDE_BASH_NO_LOGIN = "1";
      BASH_DEFAULT_TIMEOUT_MS = "120000";
      BASH_MAX_TIMEOUT_MS = "600000";
      CLAUDE_DANGEROUSLY_DISABLE_SANDBOX = "true";
      CLAUDE_SKIP_PERMISSIONS = "true";
      BASH_ENV = "$HOME/.dotfiles/home/modules/terminal/shell/aliases.sh";
      CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "80";
      CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "true";
    };

    activation.seedClaudeSettingsAsMutableFile = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        CLAUDE_SETTINGS="$HOME/.claude/settings.json"
        NIX_SOURCE="$HOME/.claude/settings.json.nix-source"
        if [ -f "$NIX_SOURCE" ]; then
          if [ -f "$CLAUDE_SETTINGS" ]; then
            chmod 600 "$CLAUDE_SETTINGS" 2>/dev/null || true
            MERGED_SETTINGS=$(${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$CLAUDE_SETTINGS" "$NIX_SOURCE")
            CURRENT_SETTINGS=$(cat "$CLAUDE_SETTINGS")
            if [ "$MERGED_SETTINGS" != "$CURRENT_SETTINGS" ]; then
              echo "$MERGED_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
            fi
          else
            cp "$NIX_SOURCE" "$CLAUDE_SETTINGS"
          fi
          chmod 600 "$CLAUDE_SETTINGS"
        fi
      '';
    };

    activation.removeNativeInstallMethodFromClaudeConfigs = {
      after = [
        "writeBoundary"
        "seedClaudeSettingsAsMutableFile"
      ];
      before = [ ];
      data = ''
        for TARGET_FILE in "$HOME/.claude.json" "$HOME/.claude/settings.json"; do
          if [ -f "$TARGET_FILE" ]; then
            if ! ${pkgs.jq}/bin/jq '.' "$TARGET_FILE" >/dev/null 2>&1; then
              echo "WARNING: $TARGET_FILE is corrupt, skipping patch" >&2
            else
              if ${pkgs.jq}/bin/jq -e '.installMethod' "$TARGET_FILE" >/dev/null 2>&1; then
                PATCHED_CONTENT=$(${pkgs.jq}/bin/jq 'del(.installMethod)' "$TARGET_FILE")
                echo "$PATCHED_CONTENT" > "$TARGET_FILE.tmp" && mv "$TARGET_FILE.tmp" "$TARGET_FILE"
              fi
            fi
          fi
        done
      '';
    };
  };
}
