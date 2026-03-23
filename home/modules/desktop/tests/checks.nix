{
  pkgs,
  lib,
  inputs,
  nixpkgs-version,
  home-version,
}:
let
  helpers = import ../../../../tests/nix-checks/helpers.nix {
    inherit
      pkgs
      lib
      inputs
      nixpkgs-version
      home-version
      ;
  };
  inherit (helpers) mkEvalCheck;

  fontsCfg = helpers.homeManagerTestConfiguration [
    ../fonts.nix
  ];

  maccyCfg = helpers.homeManagerTestConfiguration [
    ../maccy.nix
  ];
in
{
  domain-desktop-fontconfig-enabled =
    mkEvalCheck "domain-desktop-fontconfig-enabled" fontsCfg.fonts.fontconfig.enable
      "fontconfig should be enabled";

  domain-desktop-maccy-popup-shortcut-is-cmd-shift-v =
    mkEvalCheck "domain-desktop-maccy-popup-shortcut-is-cmd-shift-v"
      (lib.hasInfix ''carbonModifiers":768'' maccyCfg.home.activation.configureMaccyDefaults.data)
      "Maccy popup should use Cmd+Shift+V (carbonModifiers 768) to avoid conflicting with Ctrl+V paste remap";
}
