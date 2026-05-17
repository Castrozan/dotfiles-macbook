{
  lib,
  username,
  ...
}:
let
  swiftDaemonSourcesDirectory = ./scripts/workspace-window-switcher-daemon-swift-sources;
  swiftDaemonBinaryPath = "/usr/local/bin/workspace-window-switcher-daemon";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "compiling workspace-window-switcher-daemon swift binary..." >&2
    mkdir -p "$(dirname "${swiftDaemonBinaryPath}")"
    swiftSourceFiles=()
    while IFS= read -r -d "" swiftSourceFile; do
      swiftSourceFiles+=("$swiftSourceFile")
    done < <(/usr/bin/find "${swiftDaemonSourcesDirectory}" -name '*.swift' -print0)
    /usr/bin/swiftc -O -o "${swiftDaemonBinaryPath}" "''${swiftSourceFiles[@]}"
    chmod 0755 "${swiftDaemonBinaryPath}"
    workspaceWindowSwitcherUserId=$(/usr/bin/id -u ${username})
    /bin/launchctl kickstart -k "gui/$workspaceWindowSwitcherUserId/com.dotfiles.workspace-window-switcher" 2>/dev/null || true
  '';

  launchd.user.agents.workspace-window-switcher = {
    serviceConfig = {
      Label = "com.dotfiles.workspace-window-switcher";
      ProgramArguments = [ swiftDaemonBinaryPath ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/workspace-switcher.log";
      StandardErrorPath = "/tmp/workspace-switcher.log";
    };
  };
}
