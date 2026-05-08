{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "summon-brave";
      runtimeInputs = [ pkgs.aerospace ];
      text = ''
        exec ${pkgs.bash}/bin/bash ${./summon-browser.sh} "Brave Browser"
      '';
    })
  ];
}
