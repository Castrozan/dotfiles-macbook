{ username }:
let
  terminalBundleIdentifiers = [
    "^com\\.github\\.wez\\.wezterm$"
    "^net\\.kovidgoyal\\.kitty$"
    "^com\\.apple\\.Terminal$"
    "^com\\.googlecode\\.iterm2$"
  ];

  excludeTerminalsCondition = [
    {
      type = "frontmost_application_unless";
      bundle_identifiers = terminalBundleIdentifiers;
    }
  ];

  onlyTerminalsCondition = [
    {
      type = "frontmost_application_if";
      bundle_identifiers = terminalBundleIdentifiers;
    }
  ];

  makeControlToCommandManipulator = fromLetter: toLetter: {
    type = "basic";
    from = {
      key_code = fromLetter;
      modifiers = {
        mandatory = [ "control" ];
        optional = [ "any" ];
      };
    };
    to = [
      {
        key_code = toLetter;
        modifiers = [ "command" ];
      }
    ];
    conditions = excludeTerminalsCondition;
  };

  controlToCommandLetters = [
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
    "g"
    "i"
    "j"
    "k"
    "l"
    "n"
    "o"
    "p"
    "q"
    "r"
    "s"
    "t"
    "u"
    "v"
    "x"
    "y"
    "z"
  ];

  userBinPath = "/etc/profiles/per-user/${username}/bin";
in
[
  {
    description = "Cmd+D to Show Desktop (Fn+F11)";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "d";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            key_code = "f11";
            modifiers = [ "fn" ];
          }
        ];
      }
    ];
  }
  {
    description = "Print Screen to screenshot region to clipboard (Cmd+Shift+Ctrl+4)";
    manipulators = [
      {
        type = "basic";
        from.key_code = "print_screen";
        to = [
          {
            key_code = "4";
            modifiers = [
              "command"
              "shift"
              "control"
            ];
          }
        ];
      }
    ];
  }
  {
    description = "Cmd+W closes focused window via AeroSpace";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "w";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            shell_command = "${userBinPath}/aerospace close";
          }
        ];
      }
    ];
  }
  {
    description = "Cmd+Q launches application launcher via AeroSpace";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "q";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            shell_command = "${userBinPath}/application-launcher >/dev/null 2>&1";
          }
        ];
      }
    ];
  }
  {
    description = "Cmd+Tab/Cmd+Shift+Tab workspace window switcher via daemon";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "tab";
          modifiers.mandatory = [
            "command"
            "shift"
          ];
        };
        to = [
          {
            shell_command = "${userBinPath}/workspace-switcher-send prev";
          }
        ];
      }
      {
        type = "basic";
        from = {
          key_code = "tab";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            shell_command = "${userBinPath}/workspace-switcher-send next";
          }
        ];
      }
    ];
  }
  {
    description = "Cmd release commits workspace window switcher";
    manipulators =
      map
        (commandKey: {
          type = "basic";
          from.key_code = commandKey;
          to = [ { key_code = commandKey; } ];
          to_after_key_up = [
            {
              shell_command = "[ -f /tmp/workspace-switcher.active ] && ${userBinPath}/workspace-switcher-send commit";
            }
          ];
        })
        [
          "left_command"
          "right_command"
        ];
  }
  {
    description = "Ctrl+Space to Ctrl+Shift+Backslash in terminals (bypasses macOS input method interception)";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "spacebar";
          modifiers.mandatory = [ "control" ];
        };
        to = [
          {
            key_code = "backslash";
            modifiers = [
              "control"
              "shift"
            ];
          }
        ];
        conditions = onlyTerminalsCondition;
      }
    ];
  }
  {
    description = "Ctrl+Right to Option+Right in terminals (bypasses macOS WezTerm menu interception)";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "right_arrow";
          modifiers = {
            mandatory = [ "control" ];
            optional = [ "shift" ];
          };
        };
        to = [
          {
            key_code = "right_arrow";
            modifiers = [ "option" ];
          }
        ];
        conditions = onlyTerminalsCondition;
      }
    ];
  }
  {
    description = "Ctrl+Arrow to Option+Arrow for word jumping (except in terminals)";
    manipulators =
      map
        (arrowDirection: {
          type = "basic";
          from = {
            key_code = arrowDirection;
            modifiers = {
              mandatory = [ "control" ];
              optional = [ "shift" ];
            };
          };
          to = [
            {
              key_code = arrowDirection;
              modifiers = [ "option" ];
            }
          ];
          conditions = excludeTerminalsCondition;
        })
        [
          "left_arrow"
          "right_arrow"
        ];
  }
  {
    description = "Cmd+B summons Brave Browser";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "b";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            shell_command = "${userBinPath}/summon-brave";
          }
        ];
      }
    ];
  }
  {
    description = "Cmd+F toggles fullscreen on focused window via AeroSpace";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "f";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            shell_command = "${userBinPath}/aerospace fullscreen";
          }
        ];
      }
    ];
  }
  {
    description = "Cmd+C summons Chrome";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "c";
          modifiers.mandatory = [ "command" ];
        };
        to = [
          {
            shell_command = "${userBinPath}/summon-chrome";
          }
        ];
      }
    ];
  }
  {
    description = "Ctrl+Click to Cmd+Click (except in terminals)";
    manipulators = [
      {
        type = "basic";
        from = {
          pointing_button = "button1";
          modifiers = {
            mandatory = [ "control" ];
            optional = [ "any" ];
          };
        };
        to = [
          {
            pointing_button = "button1";
            modifiers = [ "command" ];
          }
        ];
        conditions = excludeTerminalsCondition;
      }
    ];
  }
  {
    description = "Linux-style Ctrl to Cmd shortcuts (except in terminals)";
    manipulators = map (letter: makeControlToCommandManipulator letter letter) controlToCommandLetters;
  }
]
