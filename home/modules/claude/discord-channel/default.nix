{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.claude.discordChannel;
  homeDir = config.home.homeDirectory;
  inherit (config.home) username;
  secretsDirectory = "${homeDir}/.secrets";
  claudeBinary = "/etc/profiles/per-user/${username}/bin/claude";
  tmuxSessionName = "claude-discord";
  agentWorkspacesBaseDirectory = "${homeDir}/.claude-discord-agents";
  hasAgents = cfg.agents != { };
  agentNames = builtins.attrNames cfg.agents;

  darwinSystemPaths = lib.concatStringsSep ":" [
    "${pkgs.tmux}/bin"
    "${pkgs.python312}/bin"
    "${pkgs.git}/bin"
    "/etc/profiles/per-user/${username}/bin"
    "/run/current-system/sw/bin"
    "/usr/local/bin"
    "/opt/homebrew/bin"
    "/usr/bin"
    "/bin"
  ];

  sharedAutonomyInstructions = ''
    <autonomy>
    You are an autonomous agent. Act decisively and take initiative.

    Try first, ask last. Before asking Lucas anything:
    1. Check your available skills - run skill discovery
    2. Search the codebase with grep/glob
    3. Read --help on any CLI tool
    4. Try the most likely approach
    Only after 2+ genuine attempts, ask for help. Report what you tried, not just "I'm stuck."

    When given a task, do the work. Don't describe what you would do - do it. Don't ask for permission to proceed unless the action is destructive or irreversible. Bias toward action.

    If something fails, note what failed and try an alternative. Iterate until you succeed or exhaust reasonable approaches.
    </autonomy>
  '';

  sharedMemoryInstructions = ''
    <memory>
    You have persistent memory that survives across sessions. Use it aggressively.

    Save to memory when you learn:
    - User preferences, communication style, recurring requests
    - Project context that isn't obvious from code (why decisions were made, constraints)
    - Solutions to problems you solved (so you don't re-discover them)
    - Feedback corrections (so you don't repeat mistakes)

    Read your memory at session start. Your memories are your accumulated wisdom - they make you more effective over time. A well-maintained memory transforms you from a stateless tool into a knowledgeable collaborator.
    </memory>
  '';

  sharedSessionResilienceInstructions = ''
    <session-resilience>
    Sessions can restart at any time. Your conversation history may be lost. Multi-step work survives only if persisted to disk.

    For quick tasks: write current objective and next steps to HEARTBEAT.md in your workspace.
    For big tasks (>5 steps): create a .deep-work/ workspace with plan, progress journal, and context.
    On session start: check HEARTBEAT.md and .deep-work/ - resume from disk without asking the user to re-explain.
    </session-resilience>
  '';

  sharedCommunicationInstructions = ''
    <communication>
    You are talking to users via Discord. Lucas is a senior software engineer. Other users in the guild are his friends or colleagues.
    Be direct and technical. Concise answers. Use markdown for formatting.
    If someone is wrong, tell them. If something fails, fix it - don't just report.
    Respond in the same language the user writes in their message.
    </communication>

    <discord-channel-behavior>
    CRITICAL: When a Discord message arrives, ALWAYS respond immediately using the reply tool. Never ask the operator for permission to respond. Never present interactive choices about whether to reply. You are a Discord bot - every message directed at you gets a response. This is non-negotiable.

    Use the reply MCP tool to send your response back to Discord. The user cannot see your terminal output - only messages sent via the reply tool reach them.
    </discord-channel-behavior>
  '';

  buildAgentClaudeMarkdownContent = name: agent: ''
    ${agent.personality}

    ${sharedAutonomyInstructions}

    ${sharedMemoryInstructions}

    ${sharedSessionResilienceInstructions}

    ${sharedCommunicationInstructions}
  '';

  bootstrapHeartbeatScript = ./scripts/bootstrap-discord-agent-heartbeat;
  discordAgentWrapperScript = ./scripts/discord-agent-wrapper;
  claudeDiscordAgentsServiceScript = ./scripts/claude-discord-agents-service;

  agentWorkspaceDirectory = name: "${agentWorkspacesBaseDirectory}/${name}";

  buildAgentLaunchCommand =
    name: agent:
    let
      workspace = agentWorkspaceDirectory name;
      tokenFile = "${secretsDirectory}/${agent.botTokenSecretName}";
      channelFlag = "--channels plugin:discord@claude-plugins-official";
      modelFlag = "--model ${agent.model}";
      nameFlag = "--name ${name}";
      permissionModeFlag = "--permission-mode ${agent.permissionMode}";
      skillDirFlags = lib.concatMapStringsSep " " (dir: "--add-dir ${dir}") agent.skillDirectories;
    in
    "cd ${workspace} && DISCORD_BOT_TOKEN=$(cat ${tokenFile}) ${claudeBinary} ${channelFlag} ${modelFlag} ${nameFlag} ${permissionModeFlag} ${skillDirFlags}";

  buildAgentWindowCommand =
    name: agent:
    let
      heartbeatBootstrapArgvFlag =
        if agent.heartbeatInterval != null then
          "--heartbeat-bootstrap-argv ${lib.escapeShellArg (builtins.toJSON (buildHeartbeatBootstrapArgv name agent))}"
        else
          "";
      activeHoursFlags =
        if agent.activeHoursStart != null then
          "--active-hours-start ${toString agent.activeHoursStart} --active-hours-end ${toString agent.activeHoursEnd}"
        else
          "";
      dailySessionRotationFlag = if agent.dailySessionRotation then "--daily-session-rotation" else "";
    in
    pkgs.writeShellScript "discord-agent-${name}" ''
      exec ${pkgs.python312}/bin/python3 ${discordAgentWrapperScript} \
        --agent-name ${lib.escapeShellArg name} \
        --launch-command ${lib.escapeShellArg (buildAgentLaunchCommand name agent)} \
        ${heartbeatBootstrapArgvFlag} \
        ${activeHoursFlags} \
        ${dailySessionRotationFlag}
    '';

  buildHeartbeatBootstrapArgv = name: agent: [
    "${pkgs.python312}/bin/python3"
    "${bootstrapHeartbeatScript}"
    "--session"
    tmuxSessionName
    "--window"
    name
    "--interval"
    agent.heartbeatInterval
    "--prompt"
    agent.heartbeatPrompt
  ];

  buildAgentSpecification = name: agent: {
    inherit name;
    wrapper_command = "${buildAgentWindowCommand name agent}";
  };

  claudeDiscordAgentsServiceSpecificationFile =
    pkgs.writeText "claude-discord-agents-service-specification.json"
      (
        builtins.toJSON {
          session_name = tmuxSessionName;
          agents = map (name: buildAgentSpecification name cfg.agents.${name}) agentNames;
        }
      );

  launchdServiceLabel = "com.dotfiles.claude-discord-channel";

  claudeDiscordSessionStarter = pkgs.writeShellScriptBin "claude-discord-channel" ''
    set -euo pipefail

    if ${pkgs.tmux}/bin/tmux has-session -t "${tmuxSessionName}" 2>/dev/null; then
      echo "Session ${tmuxSessionName} already running. Attach with: tmux attach -t ${tmuxSessionName}" >&2
      exit 0
    fi

    /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/${launchdServiceLabel}"
  '';

  injectAllDiscordBotTokens = pkgs.writeShellScript "inject-claude-discord-bot-tokens" (
    lib.concatMapStringsSep "\n" (
      name:
      let
        agent = cfg.agents.${name};
        tokenFile = "${secretsDirectory}/${agent.botTokenSecretName}";
        envDir = "${homeDir}/.claude/channels/discord/${name}";
        envFile = "${envDir}/.env";
      in
      ''
        if [ -f "${tokenFile}" ]; then
          TOKEN="$(cat "${tokenFile}")"
          if [ -n "$TOKEN" ]; then
            mkdir -p "${envDir}"
            printf 'DISCORD_BOT_TOKEN=%s\n' "$TOKEN" > "${envFile}"
            chmod 600 "${envFile}"
          fi
        fi
      ''
    ) agentNames
  );

  seedAgentWorkspaces = pkgs.writeShellScript "seed-discord-agent-workspaces" (
    lib.concatMapStringsSep "\n" (
      name:
      let
        workspace = agentWorkspaceDirectory name;
      in
      ''
        mkdir -p "${workspace}"
        if [ ! -f "${workspace}/HEARTBEAT.md" ]; then
          printf '# Heartbeat\n\nNo active work.\n' > "${workspace}/HEARTBEAT.md"
        fi
        CLAUDE_VERSION="$(${claudeBinary} --version 2>/dev/null | head -1 | grep -oE '[0-9.]+' | head -1 || echo '2.1.100')"
        if [ ! -f "${workspace}/.claude.json" ]; then
          printf '{"hasCompletedOnboarding":true,"numStartups":1,"installMethod":"native","lastOnboardingVersion":"%s"}\n' "$CLAUDE_VERSION" > "${workspace}/.claude.json"
        fi
      ''
    ) agentNames
  );

  updateClaudePluginsMarketplace = pkgs.writeShellScript "update-claude-plugins-marketplace" ''
    set -euo pipefail
    MARKETPLACE_DIR="${homeDir}/.claude/plugins/marketplaces/claude-plugins-official"

    if [ ! -d "$MARKETPLACE_DIR/.git" ]; then
      exit 0
    fi

    cd "$MARKETPLACE_DIR"
    ${pkgs.git}/bin/git pull --ff-only origin main 2>/dev/null || true
  '';

  agentClaudeMarkdownFiles = lib.listToAttrs (
    map (name: {
      name = ".claude-discord-agents/${name}/CLAUDE.md";
      value = {
        text = buildAgentClaudeMarkdownContent name cfg.agents.${name};
      };
    }) agentNames
  );

  agentsWithDenyToolPatterns = builtins.filter (
    name: cfg.agents.${name}.denyToolPatterns != [ ]
  ) agentNames;

  agentWorkspaceSettingsFiles = lib.listToAttrs (
    map (name: {
      name = ".claude-discord-agents/${name}/.claude/settings.json";
      value = {
        text = builtins.toJSON {
          permissions = {
            deny = cfg.agents.${name}.denyToolPatterns;
          };
        };
      };
    }) agentsWithDenyToolPatterns
  );
in
{
  options.claude.discordChannel.agents = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          botTokenSecretName = lib.mkOption {
            type = lib.types.str;
            description = "Name of the decrypted secret file in ~/.secrets/";
          };
          role = lib.mkOption {
            type = lib.types.str;
            description = "Agent role description";
          };
          model = lib.mkOption {
            type = lib.types.str;
            default = "sonnet";
            description = "Claude model alias (opus, sonnet, haiku)";
          };
          skillDirectories = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Absolute paths to skill directories passed as --add-dir to this agent";
          };
          personality = lib.mkOption {
            type = lib.types.lines;
            description = "Rich personality and instructions for this agent's CLAUDE.md";
          };
          heartbeatInterval = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Cron expression for heartbeat interval. When set, agent becomes autonomous with a polling loop.";
          };
          heartbeatPrompt = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Prompt sent on each heartbeat tick. Required when heartbeatInterval is set.";
          };
          permissionMode = lib.mkOption {
            type = lib.types.enum [
              "default"
              "acceptEdits"
              "plan"
              "bypassPermissions"
            ];
            default = "default";
            description = "Claude Code permission mode. Use 'bypassPermissions' for fully autonomous agents.";
          };
          activeHoursStart = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Hour (0-23) when agent should start running. When null, agent runs 24/7.";
          };
          activeHoursEnd = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Hour (0-23) when agent should stop running.";
          };
          dailySessionRotation = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Kill and restart the Claude process once per day to prevent context accumulation.";
          };
          denyToolPatterns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Tool patterns written into the agent workspace .claude/settings.json under permissions.deny.";
          };
        };
      }
    );
    default = { };
    description = "Discord channel agents - each becomes a tmux window in the claude-discord session";
  };

  config = lib.mkMerge [
    {
      home.activation.updateClaudePluginsMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${updateClaudePluginsMarketplace}
      '';
    }

    (lib.mkIf hasAgents {
      assertions = map (
        name:
        let
          agent = cfg.agents.${name};
        in
        {
          assertion = (agent.activeHoursStart == null) == (agent.activeHoursEnd == null);
          message = "Agent ${name}: activeHoursStart and activeHoursEnd must both be set or both be null";
        }
      ) agentNames;

      home = {
        packages = [ claudeDiscordSessionStarter ];

        file = agentClaudeMarkdownFiles // agentWorkspaceSettingsFiles;

        activation.seedDiscordAgentWorkspaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${seedAgentWorkspaces}
        '';

        activation.injectDiscordBotTokens = lib.hm.dag.entryAfter [ "agenix" ] ''
          run ${injectAllDiscordBotTokens}
        '';
      };

      launchd.agents.claude-discord-channel = {
        enable = true;
        config = {
          Label = launchdServiceLabel;
          ProgramArguments = [
            "${pkgs.python312}/bin/python3"
            "${claudeDiscordAgentsServiceScript}"
            "--specification-file"
            "${claudeDiscordAgentsServiceSpecificationFile}"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          EnvironmentVariables = {
            PATH = darwinSystemPaths;
            HOME = homeDir;
          };
          StandardOutPath = "/tmp/claude-discord-channel.log";
          StandardErrorPath = "/tmp/claude-discord-channel.err.log";
        };
      };
    })
  ];
}
