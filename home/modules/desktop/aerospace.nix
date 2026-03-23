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

        cmd-q = "exec-and-forget application-launcher";
        cmd-tab = "exec-and-forget /usr/bin/python3 /Users/${username}/.dotfiles/hosts/macbook/scripts/workspace-window-switcher";

        cmd-f = "fullscreen";

        cmd-left = "focus left";
        cmd-right = "focus right";
        cmd-up = "focus up";
        cmd-down = "focus down";

        cmd-ctrl-left = "workspace prev";
        cmd-ctrl-right = "workspace next";

        cmd-ctrl-shift-left = [
          "move-node-to-workspace prev"
          "workspace prev"
        ];
        cmd-ctrl-shift-right = [
          "move-node-to-workspace next"
          "workspace next"
        ];
      };
    };
  };
}
