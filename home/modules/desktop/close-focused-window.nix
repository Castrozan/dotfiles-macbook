{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "close-focused-window" (builtins.readFile ./scripts/close-focused-window))
  ];
}
