{
  config,
  pkgs,
  ...
}:
let
  karabinerRulesList = import ../rules { inherit (config.home) username; };

  karabinerProfileContainingRules = {
    profiles = [
      {
        name = "Default";
        selected = true;
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
        complex_modifications.rules = karabinerRulesList;
      }
    ];
  };

  karabinerJsonInNixStore = pkgs.writeText "karabiner.json" (
    builtins.toJSON karabinerProfileContainingRules
  );
in
{
  home.activation.copyKarabinerRulesJsonToUserConfigDirectory =
    config.lib.dag.entryAfter [ "writeBoundary" ]
      ''
        destinationKarabinerJsonPath="$HOME/.config/karabiner/karabiner.json"
        sourceKarabinerJsonPath=${karabinerJsonInNixStore}
        mkdir -p "$(dirname "$destinationKarabinerJsonPath")"
        if ! /usr/bin/cmp -s "$sourceKarabinerJsonPath" "$destinationKarabinerJsonPath"; then
          cat "$sourceKarabinerJsonPath" > "$destinationKarabinerJsonPath"
          chmod 644 "$destinationKarabinerJsonPath"
        fi
      '';
}
