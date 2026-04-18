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

  karabinerRules = import ../karabiner-rules.nix { username = "test"; };
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

  domain-desktop-aerospace-cmd-tab-not-bound =
    mkEvalCheck "domain-desktop-aerospace-cmd-tab-not-bound" (!(aerospaceBindings ? cmd-tab))
      "cmd-tab must not be bound in aerospace (karabiner intercepts it for workspace-switcher daemon)";

  domain-desktop-aerospace-workspace-prev-bound =
    mkEvalCheck "domain-desktop-aerospace-workspace-prev-bound"
      (lib.hasInfix "workspace-navigate prev" aerospaceBindings.cmd-alt-left)
      "workspace prev must be bound to cmd-alt-left via workspace-navigate script";

  domain-desktop-aerospace-workspace-next-bound =
    mkEvalCheck "domain-desktop-aerospace-workspace-next-bound"
      (lib.hasInfix "workspace-navigate next" aerospaceBindings.cmd-alt-right)
      "workspace next must be bound to cmd-alt-right via workspace-navigate script";

  domain-desktop-aerospace-move-workspace-prev-follows =
    mkEvalCheck "domain-desktop-aerospace-move-workspace-prev-follows"
      (lib.hasInfix "workspace-navigate prev --move-window" aerospaceBindings.cmd-alt-shift-left)
      "move-to-prev-and-follow must be bound to cmd-alt-shift-left via workspace-navigate script";

  domain-desktop-aerospace-move-workspace-next-follows =
    mkEvalCheck "domain-desktop-aerospace-move-workspace-next-follows"
      (lib.hasInfix "workspace-navigate next --move-window" aerospaceBindings.cmd-alt-shift-right)
      "move-to-next-and-follow must be bound to cmd-alt-shift-right via workspace-navigate script";

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

  domain-desktop-aerospace-focus-event-uses-compiled-client =
    mkEvalCheck "domain-desktop-aerospace-focus-event-uses-compiled-client"
      (lib.any (cmd: lib.hasInfix "workspace-switcher-send" cmd) aerospaceSettings.on-focus-changed)
      "on-focus-changed must use compiled workspace-switcher-send instead of nc";

  domain-desktop-aerospace-focus-event-does-not-use-netcat =
    mkEvalCheck "domain-desktop-aerospace-focus-event-does-not-use-netcat"
      (!(lib.any (cmd: lib.hasInfix "/usr/bin/nc" cmd) aerospaceSettings.on-focus-changed))
      "on-focus-changed must not use /usr/bin/nc (replaced by compiled client)";

  domain-desktop-aerospace-cmd-w-not-bound =
    mkEvalCheck "domain-desktop-aerospace-cmd-w-not-bound" (!(aerospaceBindings ? cmd-w))
      "cmd-w must not be bound in aerospace (karabiner intercepts it to close window via aerospace CLI)";

  domain-desktop-karabiner-cmd-w-closes-window-via-aerospace =
    mkEvalCheck "domain-desktop-karabiner-cmd-w-closes-window-via-aerospace"
      (lib.any (
        rule:
        lib.any (
          manipulator:
          (manipulator.from.key_code or "") == "w"
          && builtins.elem "command" (manipulator.from.modifiers.mandatory or [ ])
          && lib.any (to: lib.hasInfix "aerospace close" (to.shell_command or "")) (manipulator.to or [ ])
        ) (rule.manipulators or [ ])
      ) karabinerRules)
      "karabiner must intercept cmd-w and close focused window via aerospace close";

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
