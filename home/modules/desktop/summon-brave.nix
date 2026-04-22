{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "summon-brave";
      runtimeInputs = [ pkgs.aerospace ];
      text = ''
        exec ${pkgs.python312}/bin/python3 ${./summon-browser.py} "Brave Browser" "$@"
      '';
    })
  ];
}
