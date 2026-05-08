{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "summon-chrome";
      runtimeInputs = [ pkgs.aerospace ];
      text = ''
        exec ${./summon-browser.sh} "Google Chrome"
      '';
    })
  ];
}
