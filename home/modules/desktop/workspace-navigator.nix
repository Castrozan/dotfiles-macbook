{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "workspace-navigate" ''
      export PATH="${pkgs.aerospace}/bin:$PATH"
      exec ${pkgs.python312}/bin/python3 ${./workspace-navigator.py} "$@"
    '')
  ];
}
