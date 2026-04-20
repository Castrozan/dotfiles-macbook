{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "summon-brave" ''
      exec ${pkgs.python312}/bin/python3 ${./summon-browser.py} "Brave Browser" "$@"
    '')
  ];
}
