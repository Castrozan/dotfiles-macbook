{ lib, config, ... }:
let
  workspaceNumbers = lib.range 1 7;

  userBinPath = "/etc/profiles/per-user/${config.home.username}/bin";

  workspaceSwitchBindings = lib.listToAttrs (
    map (n: {
      name = "cmd-${toString n}";
      value = "workspace ${toString n}";
    }) workspaceNumbers
  );

  workspaceMoveBindings = lib.listToAttrs (
    map (n: {
      name = "cmd-shift-${toString n}";
      value = [
        "move-node-to-workspace ${toString n}"
        "workspace ${toString n}"
      ];
    }) workspaceNumbers
  );

  workspaceAccordionStartupCommands =
    lib.concatMap (n: [
      "workspace ${toString n}"
      "layout accordion"
    ]) workspaceNumbers
    ++ [ "workspace 1" ];

  focusBindings = {
    cmd-left = "focus left";
    cmd-right = "focus right";
    cmd-up = "focus up";
    cmd-down = "focus down";
  };

  totalWorkspaces = toString (builtins.length workspaceNumbers);

  workspaceNavigationBindings = {
    ctrl-alt-left = "exec-and-forget ${userBinPath}/workspace-navigate prev ${totalWorkspaces}";
    ctrl-alt-right = "exec-and-forget ${userBinPath}/workspace-navigate next ${totalWorkspaces}";
    ctrl-alt-shift-left = "exec-and-forget ${userBinPath}/workspace-navigate prev ${totalWorkspaces} --move-window";
    ctrl-alt-shift-right = "exec-and-forget ${userBinPath}/workspace-navigate next ${totalWorkspaces} --move-window";
    cmd-alt-left = "exec-and-forget ${userBinPath}/workspace-navigate prev ${totalWorkspaces}";
    cmd-alt-right = "exec-and-forget ${userBinPath}/workspace-navigate next ${totalWorkspaces}";
    cmd-alt-shift-left = "exec-and-forget ${userBinPath}/workspace-navigate prev ${totalWorkspaces} --move-window";
    cmd-alt-shift-right = "exec-and-forget ${userBinPath}/workspace-navigate next ${totalWorkspaces} --move-window";
  };

in
{
  programs.aerospace = {
    enable = true;
    userSettings = {
      start-at-login = true;

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 0;
      default-root-container-layout = "accordion";
      default-root-container-orientation = "auto";

      after-startup-command = workspaceAccordionStartupCommands;

      key-mapping.preset = "qwerty";

      on-focus-changed = [
        "fullscreen on"
        ''exec-and-forget ${userBinPath}/workspace-switcher-send "focus:$AEROSPACE_WINDOW_ID"''
      ];
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      gaps = {
        inner = {
          horizontal = 0;
          vertical = 0;
        };
        outer = {
          left = 0;
          right = 0;
          top = 0;
          bottom = 0;
        };
      };

      mode.main.binding =
        workspaceSwitchBindings // workspaceMoveBindings // focusBindings // workspaceNavigationBindings;
    };
  };
}
