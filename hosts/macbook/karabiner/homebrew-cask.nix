{ lib, ... }:
let
  karabinerMinimumVersionRequiredForSendUserCommand = "16.0.0";
in
{
  homebrew.casks = [ "karabiner-elements" ];

  system.activationScripts.postActivation.text = lib.mkAfter ''
    karabinerInfoPlistPath="/Applications/Karabiner-Elements.app/Contents/Info.plist"
    if [[ -f "$karabinerInfoPlistPath" ]]; then
      installedKarabinerVersion=$(/usr/bin/defaults read "$karabinerInfoPlistPath" CFBundleShortVersionString 2>/dev/null || echo "0")
      requiredKarabinerVersion="${karabinerMinimumVersionRequiredForSendUserCommand}"
      installedMajorVersion="''${installedKarabinerVersion%%.*}"
      requiredMajorVersion="''${requiredKarabinerVersion%%.*}"
      if [[ "$installedMajorVersion" -lt "$requiredMajorVersion" ]]; then
        echo "ERROR: karabiner-elements $installedKarabinerVersion is too old; need >= $requiredKarabinerVersion for to.send_user_command support" >&2
        echo "       upgrade with: brew upgrade --cask karabiner-elements" >&2
        exit 1
      fi
    fi
  '';
}
