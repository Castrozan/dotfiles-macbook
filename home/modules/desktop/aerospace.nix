{ username, ... }:
{
  programs.aerospace = {
    enable = true;
    userSettings = {
      start-at-login = true;

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 30;

      default-root-container-layout = "accordion";
      default-root-container-orientation = "auto";

      key-mapping.preset = "qwerty";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      workspace-to-monitor-force-assignment = {
        "4" = "RG241Y";
      };

      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };
        outer = {
          left = 10;
          right = 10;
          top = 10;
          bottom = 10;
        };
      };

      mode.main.binding = {
        cmd-1 = "workspace 1";
        cmd-2 = "workspace 2";
        cmd-3 = "workspace 3";
        cmd-4 = "workspace 4";
        cmd-5 = "workspace 5";
        cmd-6 = "workspace 6";
        cmd-7 = "workspace 7";

        cmd-shift-1 = [
          "move-node-to-workspace 1"
          "workspace 1"
        ];
        cmd-shift-2 = [
          "move-node-to-workspace 2"
          "workspace 2"
        ];
        cmd-shift-3 = [
          "move-node-to-workspace 3"
          "workspace 3"
        ];
        cmd-shift-4 = [
          "move-node-to-workspace 4"
          "workspace 4"
        ];
        cmd-shift-5 = [
          "move-node-to-workspace 5"
          "workspace 5"
        ];
        cmd-shift-6 = [
          "move-node-to-workspace 6"
          "workspace 6"
        ];
        cmd-shift-7 = [
          "move-node-to-workspace 7"
          "workspace 7"
        ];

        cmd-tab = "exec-and-forget /usr/bin/python3 /Users/${username}/.dotfiles/hosts/macbook/scripts/workspace-window-switcher";

        cmd-f = "fullscreen";

        cmd-left = "focus left";
        cmd-right = "focus right";
        cmd-up = "focus up";
        cmd-down = "focus down";

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
      };
    };
  };
}
