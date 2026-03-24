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

  acceptCdpConsentDialogScript = pkgs.writeScript "accept-cdp-consent-dialog-macos.py" ''
    #!${pkgs.python312}/bin/python3
    import subprocess
    import sys
    import time

    DELAY_BEFORE_ACCEPTING_SECONDS = 3
    MAX_ATTEMPTS = 5
    INTERVAL_BETWEEN_ATTEMPTS_SECONDS = 2

    ACCEPT_CONSENT_DIALOG_APPLESCRIPT = """
    tell application "Google Chrome" to activate
    delay 0.3
    tell application "System Events"
        tell process "Google Chrome"
            keystroke return
        end tell
    end tell
    """

    def chrome_is_running():
        result = subprocess.run(["pgrep", "-x", "Google Chrome"], capture_output=True)
        return result.returncode == 0

    def accept_consent_dialog_via_applescript():
        result = subprocess.run(
            ["osascript", "-e", ACCEPT_CONSENT_DIALOG_APPLESCRIPT],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0

    def main():
        time.sleep(DELAY_BEFORE_ACCEPTING_SECONDS)

        if not chrome_is_running():
            print("Chrome not running, skipping consent acceptor", file=sys.stderr)
            return

        for attempt in range(MAX_ATTEMPTS):
            if accept_consent_dialog_via_applescript():
                print(
                    f"Consent dialog accepted (attempt {attempt + 1})",
                    file=sys.stderr,
                )
                return
            time.sleep(INTERVAL_BETWEEN_ATTEMPTS_SECONDS)

        print("Failed to accept consent dialog after all attempts", file=sys.stderr)

    if __name__ == "__main__":
        main()
  '';

  chromeDevtoolsMcpAutoconnectWrapper = pkgs.writeShellScriptBin "chrome-devtools-mcp-autoconnect" ''
    set -euo pipefail
    export PATH="${nodejs}/bin:${pkgs.python312}/bin:''${PATH:+:$PATH}"

    readonly MCP_BINARY="${chromeDevtoolsMcpBinary}"
    readonly CONSENT_ACCEPTOR="${acceptCdpConsentDialogScript}"

    if ! "$MCP_BINARY" --version >/dev/null 2>&1; then
      echo "chrome-devtools-mcp not found at $MCP_BINARY" >&2
      exit 1
    fi

    python3 "$CONSENT_ACCEPTOR" &
    disown

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
