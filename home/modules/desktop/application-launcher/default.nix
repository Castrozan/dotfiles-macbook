{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "application-launcher" ''
      exec ${pkgs.python312}/bin/python3 ${./application-launcher.py}
    '')
  ];
}
