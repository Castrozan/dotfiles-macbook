{
  pkgs,
  lib,
  ...
}:
let
  codexDefaultModel = "gpt-5.4";
  codexDeveloperInstructions = "Operate pragmatically: keep diffs small, verify with fast checks, and prefer repo-local truth (AGENTS.md, bin/, home/modules/).";
  codexHooksConfig = builtins.toJSON {
    SessionStart = [
      {
        command = "cat ~/.dotfiles/.deep-work/*/context.md 2>/dev/null || true";
        timeout = 5000;
      }
    ];
  };

  codexHooksJsonFile = pkgs.writeText "codex-hooks.json" codexHooksConfig;

  codexConfigToml = pkgs.writeText "codex-config.toml" ''
    model = "${codexDefaultModel}"
    developer_instructions = "${codexDeveloperInstructions}"
  '';
in
{
  home.activation.codexBaselineConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.codex"
    if [ ! -f "$HOME/.codex/config.toml" ]; then
      cp ${codexConfigToml} "$HOME/.codex/config.toml"
      chmod 644 "$HOME/.codex/config.toml"
    fi
  '';

  home.activation.codexHooksConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.codex"
    cp ${codexHooksJsonFile} "$HOME/.codex/hooks.json"
    chmod 644 "$HOME/.codex/hooks.json"
  '';
}
