{ username, lib, ... }:
let
  workspaceNumbers = lib.range 1 7;

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

  workspaceNavigationBindings = {
    ctrl-alt-left = "workspace prev";
    ctrl-alt-right = "workspace next";
    ctrl-alt-shift-left = [
      "move-node-to-workspace prev"
      "workspace prev"
    ];
    ctrl-alt-shift-right = [
      "move-node-to-workspace next"
      "workspace next"
    ];
    cmd-alt-left = "workspace prev";
    cmd-alt-right = "workspace next";
    cmd-alt-shift-left = [
      "move-node-to-workspace prev"
      "workspace prev"
    ];
    cmd-alt-shift-right = [
      "move-node-to-workspace next"
      "workspace next"
    ];
  };

  applicationBindings = {
    cmd-q = "exec-and-forget /etc/profiles/per-user/${username}/bin/application-launcher";
    cmd-f = "fullscreen";
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
        ''exec-and-forget echo "focus:$AEROSPACE_WINDOW_ID" | /usr/bin/nc -U /tmp/workspace-switcher.sock''
      ];
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      workspace-to-monitor-force-assignment = {
        "4" = "RG241Y";
      };

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
        workspaceSwitchBindings
        // workspaceMoveBindings
        // focusBindings
        // workspaceNavigationBindings
        // applicationBindings;
    };
  };
}
