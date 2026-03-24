{
  pkgs,
  config,
  ...
}:
let
  nodejs = pkgs.nodejs_22;
  homeDir = config.home.homeDirectory;

  chromeDevtoolsMcpVersion = "0.20.3";
  chromeDevtoolsMcpNpmPrefix = "${homeDir}/.local/share/chrome-devtools-mcp-npm";
  chromeDevtoolsMcpBinary = "${chromeDevtoolsMcpNpmPrefix}/bin/chrome-devtools-mcp";
  chromeLocalStatePath = "${homeDir}/Library/Application Support/Google/Chrome/Local State";

  installChromeDevtoolsMcpViaNpm = pkgs.writeShellScript "install-chrome-devtools-mcp" ''
    set -euo pipefail
    export PATH="${nodejs}/bin:''${PATH:+:$PATH}"
    export NPM_CONFIG_PREFIX="${chromeDevtoolsMcpNpmPrefix}"

    PACKAGE_JSON="${chromeDevtoolsMcpNpmPrefix}/lib/node_modules/chrome-devtools-mcp/package.json"

    if [ -f "$PACKAGE_JSON" ] && grep -q '"version": "${chromeDevtoolsMcpVersion}"' "$PACKAGE_JSON"; then
      exit 0
    fi

    _install_npm_package() {
      ${nodejs}/bin/npm install -g "chrome-devtools-mcp@${chromeDevtoolsMcpVersion}" \
        --prefix "${chromeDevtoolsMcpNpmPrefix}" \
        --registry "https://registry.npmjs.org/" \
        --prefer-offline \
        --no-audit \
        --no-fund \
        2>&1
    }

    if ! OUTPUT=$(_install_npm_package); then
      echo "npm install chrome-devtools-mcp@${chromeDevtoolsMcpVersion} failed (attempt 1), retrying..." >&2
      sleep 2
      if ! OUTPUT=$(_install_npm_package); then
        echo "npm install chrome-devtools-mcp@${chromeDevtoolsMcpVersion} failed after retry: $OUTPUT" >&2
        exit 1
      fi
    fi
  '';

  chromeDevtoolsMcpAutoconnectWrapper = pkgs.writeShellScriptBin "chrome-devtools-mcp-autoconnect" ''
    set -euo pipefail
    export PATH="${nodejs}/bin:''${PATH:+:$PATH}"

    readonly MCP_BINARY="${chromeDevtoolsMcpBinary}"

    if ! "$MCP_BINARY" --version >/dev/null 2>&1; then
      echo "chrome-devtools-mcp not found at $MCP_BINARY" >&2
      exit 1
    fi

    exec "$MCP_BINARY" \
      --autoConnect \
      --usageStatistics false \
      "$@"
  '';

  enableChromeRemoteDebuggingServer = pkgs.writeShellScript "enable-chrome-remote-debugging-server" ''
    set -euo pipefail
    LOCAL_STATE="${chromeLocalStatePath}"

    if [ ! -f "$LOCAL_STATE" ]; then
      exit 0
    fi

    CURRENT_VALUE=$(${pkgs.jq}/bin/jq -r '.devtools."remote_debugging"."user-enabled" // false' "$LOCAL_STATE")

    if [ "$CURRENT_VALUE" = "true" ]; then
      exit 0
    fi

    ${pkgs.jq}/bin/jq '.devtools = (.devtools // {}) * {"remote_debugging": {"user-enabled": true}}' \
      "$LOCAL_STATE" > "$LOCAL_STATE.tmp" \
      && mv "$LOCAL_STATE.tmp" "$LOCAL_STATE"
  '';

  mcpServersToInject = builtins.toJSON {
    chrome-devtools = {
      command = "${chromeDevtoolsMcpAutoconnectWrapper}/bin/chrome-devtools-mcp-autoconnect";
      args = [ ];
    };
  };

  injectMcpServersIntoClaudeConfig = pkgs.writeShellScript "inject-mcp-servers-into-claude-config" ''
    set -euo pipefail
    CLAUDE_CONFIG="${homeDir}/.claude.json"
    SERVERS='${mcpServersToInject}'

    if [ ! -f "$CLAUDE_CONFIG" ]; then
      echo '{"mcpServers":{}}' > "$CLAUDE_CONFIG"
    fi

    ${pkgs.jq}/bin/jq --argjson servers "$SERVERS" \
      '.mcpServers = (.mcpServers // {}) * $servers' \
      "$CLAUDE_CONFIG" > "$CLAUDE_CONFIG.tmp" \
      && mv "$CLAUDE_CONFIG.tmp" "$CLAUDE_CONFIG"
  '';
in
{
  home.activation = {
    installChromeDevtoolsMcp = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${installChromeDevtoolsMcpViaNpm}
    '';

    enableChromeRemoteDebuggingServer = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${enableChromeRemoteDebuggingServer}
    '';

    injectMcpServersIntoClaudeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${injectMcpServersIntoClaudeConfig}
    '';
  };
}
