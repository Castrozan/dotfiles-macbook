{
  pkgs,
  lib,
  inputs,
  self,
  nixpkgs-version,
  home-version,
}:
let
  domainArgs = {
    inherit
      pkgs
      lib
      inputs
      nixpkgs-version
      home-version
      ;
  };

  moduleArgs = domainArgs // {
    inherit self;
  };

  darwinExcludedCheckNames = [
    "domain-desktop-fontconfig-enabled"
    "domain-terminal-fish-conf-d-deployed"
  ];

  excludeDarwinIncompatibleChecks =
    checks: lib.filterAttrs (name: _: !builtins.elem name darwinExcludedCheckNames) checks;

  claudeChecks = import ../../home/modules/claude/tests/checks.nix moduleArgs;
  terminalChecks = import ../../home/modules/terminal/tests/checks.nix domainArgs;
  editorChecks = import ../../home/modules/editor/tests/checks.nix domainArgs;
  desktopChecks = import ../../home/modules/desktop/tests/checks.nix domainArgs;
  devChecks = import ../../home/modules/dev/tests/checks.nix domainArgs;
  macbookChecks = import ../../hosts/macbook/tests/checks.nix domainArgs;
in
excludeDarwinIncompatibleChecks (
  macbookChecks // claudeChecks // terminalChecks // editorChecks // desktopChecks // devChecks
)
