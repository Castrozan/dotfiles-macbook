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

  aerospaceCfg = helpers.homeManagerTestConfiguration [
    ../aerospace.nix
  ];

  aerospaceBindings = aerospaceCfg.programs.aerospace.userSettings.mode.main.binding;
  aerospaceSettings = aerospaceCfg.programs.aerospace.userSettings;
in
{
  domain-desktop-fontconfig-enabled =
    mkEvalCheck "domain-desktop-fontconfig-enabled" fontsCfg.fonts.fontconfig.enable
      "fontconfig should be enabled";

  domain-desktop-maccy-popup-shortcut-is-cmd-shift-v =
    mkEvalCheck "domain-desktop-maccy-popup-shortcut-is-cmd-shift-v"
      (lib.hasInfix ''carbonModifiers":768'' maccyCfg.home.activation.configureMaccyDefaults.data)
      "Maccy popup should use Cmd+Shift+V (carbonModifiers 768) to avoid conflicting with Ctrl+V paste remap";

  domain-desktop-aerospace-enabled =
    mkEvalCheck "domain-desktop-aerospace-enabled" aerospaceCfg.programs.aerospace.enable
      "aerospace should be enabled";

  domain-desktop-aerospace-default-layout-is-accordion =
    mkEvalCheck "domain-desktop-aerospace-default-layout-is-accordion"
      (aerospaceSettings.default-root-container-layout == "accordion")
      "default root container layout should be accordion";

  domain-desktop-aerospace-workspace-prev-is-cmd-alt-left =
    mkEvalCheck "domain-desktop-aerospace-workspace-prev-is-cmd-alt-left"
      (aerospaceBindings.cmd-alt-left == "workspace prev")
      "workspace prev should be bound to cmd-alt-left (not ctrl-alt-left)";

  domain-desktop-aerospace-workspace-next-is-cmd-alt-right =
    mkEvalCheck "domain-desktop-aerospace-workspace-next-is-cmd-alt-right"
      (aerospaceBindings.cmd-alt-right == "workspace next")
      "workspace next should be bound to cmd-alt-right (not ctrl-alt-right)";

  domain-desktop-aerospace-move-workspace-prev-follows =
    mkEvalCheck "domain-desktop-aerospace-move-workspace-prev-follows"
      (
        aerospaceBindings.cmd-alt-shift-left == [
          "move-node-to-workspace prev"
          "workspace prev"
        ]
      )
      "cmd-alt-shift-left should move node to prev workspace and follow";

  domain-desktop-aerospace-move-workspace-next-follows =
    mkEvalCheck "domain-desktop-aerospace-move-workspace-next-follows"
      (
        aerospaceBindings.cmd-alt-shift-right == [
          "move-node-to-workspace next"
          "workspace next"
        ]
      )
      "cmd-alt-shift-right should move node to next workspace and follow";

  domain-desktop-aerospace-all-workspaces-have-switch-binding =
    mkEvalCheck "domain-desktop-aerospace-all-workspaces-have-switch-binding"
      (lib.all (n: aerospaceBindings."cmd-${toString n}" == "workspace ${toString n}") (lib.range 1 7))
      "all workspaces 1-7 should have cmd-N switch bindings";

  domain-desktop-aerospace-all-workspaces-have-move-binding =
    mkEvalCheck "domain-desktop-aerospace-all-workspaces-have-move-binding"
      (lib.all (
        n:
        aerospaceBindings."cmd-shift-${toString n}" == [
          "move-node-to-workspace ${toString n}"
          "workspace ${toString n}"
        ]
      ) (lib.range 1 7))
      "all workspaces 1-7 should have cmd-shift-N move-and-follow bindings";

  domain-desktop-aerospace-startup-enforces-accordion-on-all-workspaces =
    let
      expectedStartupCommands =
        lib.concatMap (n: [
          "workspace ${toString n}"
          "layout accordion"
        ]) (lib.range 1 7)
        ++ [ "workspace 1" ];
    in
    mkEvalCheck "domain-desktop-aerospace-startup-enforces-accordion-on-all-workspaces"
      (aerospaceSettings.after-startup-command == expectedStartupCommands)
      "after-startup-command should set accordion layout on every workspace 1-7 and return to workspace 1";
}
