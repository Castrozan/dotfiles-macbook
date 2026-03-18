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

  cfg = helpers.homeManagerTestConfiguration [
    ../fonts.nix
  ];
in
{
  domain-desktop-fontconfig-enabled =
    mkEvalCheck "domain-desktop-fontconfig-enabled" cfg.fonts.fontconfig.enable
      "fontconfig should be enabled";
}
