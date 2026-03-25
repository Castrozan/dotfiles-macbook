{ pkgs, config, ... }:
{
  home.packages = [ pkgs.maccy ];

  home.activation.configureMaccyDefaults = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/defaults write org.p0deje.Maccy KeyboardShortcuts_popup -string '{"carbonKeyCode":9,"carbonModifiers":768}'
    /usr/bin/defaults write org.p0deje.Maccy pasteByDefault -bool true
    /usr/bin/defaults write org.p0deje.Maccy SUEnableAutomaticChecks -bool false
    /usr/bin/defaults write org.p0deje.Maccy loginItemEnabled -bool true
  '';
}
