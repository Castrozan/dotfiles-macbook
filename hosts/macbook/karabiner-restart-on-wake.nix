{ pkgs, ... }:
let
  pythonForKarabinerRestartOnWakeDaemon = pkgs.python312.withPackages (packages: [
    packages.pyobjc-core
    packages.pyobjc-framework-Cocoa
  ]);
in
{
  launchd.user.agents.karabiner-restart-on-wake = {
    serviceConfig = {
      Label = "com.dotfiles.karabiner-restart-on-wake";
      ProgramArguments = [
        "${pythonForKarabinerRestartOnWakeDaemon}/bin/python3"
        "${./scripts/karabiner-restart-on-wake-daemon}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/karabiner-restart-on-wake.log";
      StandardErrorPath = "/tmp/karabiner-restart-on-wake.log";
    };
  };
}
