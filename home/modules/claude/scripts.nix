{ pkgs, ... }:
let
  processUtilsPath = if pkgs.stdenv.isDarwin then "/usr/bin:/bin:" else "${pkgs.procps}/bin:";
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "claude-exit" ''
      export PATH="${processUtilsPath}$PATH"
      ${builtins.readFile ./scripts/claude-exit}
    '')
    (pkgs.writeShellScriptBin "claude-restart" ''
      export PATH="${processUtilsPath}${pkgs.tmux}/bin:$PATH"
      ${builtins.readFile ./scripts/claude-restart}
    '')
    (pkgs.writeShellScriptBin "claude-update-version" ''
      export PATH="${pkgs.nix}/bin:${pkgs.git}/bin:$PATH"
      exec ${pkgs.python312}/bin/python3 ${./scripts/claude-update-version} "$@"
    '')
  ];
}
