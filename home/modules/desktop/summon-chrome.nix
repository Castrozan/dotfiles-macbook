{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "summon-chrome" ''
      exec ${pkgs.python312}/bin/python3 ${./summon-browser.py} "Google Chrome" "$@"
    '')
  ];
}
