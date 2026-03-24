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

  chromeDevtoolsMcpWrapper = pkgs.writeShellScriptBin "chrome-devtools-mcp-wrapper" ''
    set -euo pipefail
    export PATH="${nodejs}/bin:''${PATH:+:$PATH}"
    exec "${chromeDevtoolsMcpBinary}" \
      --usageStatistics false \
      "$@"
  '';

  mcpServersToInject = builtins.toJSON {
    chrome-devtools = {
      command = "${chromeDevtoolsMcpWrapper}/bin/chrome-devtools-mcp-wrapper";
      args = [ ];
    };
  };

  injectChromeDevtoolsMcpIntoClaudeConfig = pkgs.writeShellScript "inject-chrome-devtools-mcp" ''
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

    injectChromeDevtoolsMcpIntoClaudeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${injectChromeDevtoolsMcpIntoClaudeConfig}
    '';
  };
}
