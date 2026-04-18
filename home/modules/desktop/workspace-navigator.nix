{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "workspace-navigate" ''
      exec ${pkgs.python312}/bin/python3 ${./workspace-navigator.py} "$@"
    '')
  ];
}
