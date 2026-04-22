{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "summon-chrome";
      runtimeInputs = [ pkgs.aerospace ];
      text = ''
        exec ${pkgs.python312}/bin/python3 ${./summon-browser.py} "Google Chrome" "$@"
      '';
    })
  ];
}
