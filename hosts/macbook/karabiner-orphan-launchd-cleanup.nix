{
  lib,
  username,
  ...
}:
{
  system.activationScripts.removeOrphanNixDarwinKarabinerLaunchdEntries.text = lib.mkAfter ''
    primaryUserId="$(/usr/bin/id -u ${username})"
    primaryUserHomeDirectory="/Users/${username}"
    /bin/sh ${./scripts/remove-orphan-nix-darwin-karabiner-launchd-entries} \
      "$primaryUserId" \
      "$primaryUserHomeDirectory"
  '';
}
