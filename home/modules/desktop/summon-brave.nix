{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "summon-brave";
      runtimeInputs = [ pkgs.aerospace ];
      text = ''
        exec ${./summon-browser.sh} "Brave Browser"
      '';
    })
  ];
}
