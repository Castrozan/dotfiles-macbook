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
    mkdir -p "$HOME/.config/karabiner"
    cp -f ${karabinerConfigFile} "$HOME/.config/karabiner/karabiner.json"
    chmod 644 "$HOME/.config/karabiner/karabiner.json"
  '';
}
