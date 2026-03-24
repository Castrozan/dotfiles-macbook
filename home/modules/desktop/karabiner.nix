{
  config,
  pkgs,
  ...
}:
let
  corneKeyboardIdentifiers = [
    {
      vendor_id = 21972;
      product_id = 1121;
    }
  ];

  terminalBundleIdentifiers = [
    "^com\\.github\\.wez\\.wezterm$"
    "^net\\.kovidgoyal\\.kitty$"
    "^com\\.apple\\.Terminal$"
    "^com\\.googlecode\\.iterm2$"
  ];

  corneOnlyCondition = [
    {
      type = "device_if";
      identifiers = corneKeyboardIdentifiers;
    }
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
    "g"
    "i"
    "j"
    "k"
    "l"
    "n"
    "o"
    "p"
    "r"
    "s"
    "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    "z"
  ];

  karabinerConfig = {
    profiles = [
      {
        name = "Default";
        selected = true;
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
        complex_modifications.rules = [
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
                  { shell_command = "echo prev | /usr/bin/nc -w 1 -U /tmp/workspace-switcher.sock"; }
                ];
              }
              {
                type = "basic";
                from = {
                  key_code = "tab";
                  modifiers.mandatory = [ "command" ];
                };
                to = [
                  { shell_command = "echo next | /usr/bin/nc -w 1 -U /tmp/workspace-switcher.sock"; }
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
                      shell_command = "[ -f /tmp/workspace-switcher.active ] && echo commit | /usr/bin/nc -w 1 -U /tmp/workspace-switcher.sock";
                    }
                  ];
                })
                [
                  "left_command"
                  "right_command"
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
            manipulators = map (
              letter: makeControlToCommandManipulator letter (if letter == "w" then "q" else letter)
            ) controlToCommandLetters;
          }
        ];
      }
    ];
  };

  karabinerConfigFile = pkgs.writeText "karabiner.json" (builtins.toJSON karabinerConfig);
in
{
  home.activation.copyKarabinerConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/karabiner"
    cp -f ${karabinerConfigFile} "$HOME/.config/karabiner/karabiner.json"
    chmod 644 "$HOME/.config/karabiner/karabiner.json"
  '';
}
