{
  lib,
  username,
  ...
}:
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "removing orphan nix-darwin karabiner launchd entries..." >&2
    primaryUserId="$(/usr/bin/id -u ${username})"
    primaryUserHomeDirectory="/Users/${username}"
    /bin/sh ${./scripts/remove-orphan-nix-darwin-karabiner-launchd-entries} \
      "$primaryUserId" \
      "$primaryUserHomeDirectory"
  '';
}
