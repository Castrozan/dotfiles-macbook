{ pkgs, config, ... }:
let
  fuzzyPickerSource = ./fuzzy-picker.swift;
  fuzzyPickerBinaryPath = "${config.home.homeDirectory}/.local/bin/fuzzy-picker";
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "fuzzy-picker" ''
      exec "${fuzzyPickerBinaryPath}" "$@"
    '')
    (pkgs.writeShellScriptBin "application-launcher" ''
      exec ${pkgs.python312}/bin/python3 ${./application-launcher.py}
    '')
  ];

  home.activation.compileFuzzyPicker = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$(dirname "${fuzzyPickerBinaryPath}")"
    /usr/bin/swiftc -O -o "${fuzzyPickerBinaryPath}" "${fuzzyPickerSource}"
  '';
}
