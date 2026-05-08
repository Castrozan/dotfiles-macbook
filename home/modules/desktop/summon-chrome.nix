{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "summon-chrome";
      runtimeInputs = [ pkgs.aerospace ];
      text = ''
        exec ${pkgs.bash}/bin/bash ${./summon-browser.sh} "Google Chrome"
      '';
    })
  ];
}
