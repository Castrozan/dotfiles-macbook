{
  config,
  pkgs,
  ...
}:
let
  karabinerRules = import ./karabiner-rules.nix { inherit (config.home) username; };

  karabinerConfig = {
    profiles = [
      {
        name = "Default";
        selected = true;
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
        complex_modifications.rules = karabinerRules;
      }
    ];
  };

  karabinerConfigFile = pkgs.writeText "karabiner.json" (builtins.toJSON karabinerConfig);
in
{
  home.activation.copyKarabinerConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    destination="$HOME/.config/karabiner/karabiner.json"
    source=${karabinerConfigFile}
    mkdir -p "$(dirname "$destination")"
    if ! /usr/bin/cmp -s "$source" "$destination"; then
      cat "$source" > "$destination"
      chmod 644 "$destination"
      /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/org.pqrs.service.agent.karabiner_console_user_server" || true
    fi
  '';
}
