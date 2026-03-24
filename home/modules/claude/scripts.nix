{ pkgs, lib, ... }:
let
  processUtilsPath = lib.optionalString pkgs.stdenv.isLinux "${pkgs.procps}/bin:";
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
  ];
}
