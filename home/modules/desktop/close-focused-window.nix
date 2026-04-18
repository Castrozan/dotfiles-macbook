{ pkgs, config, ... }:
let
  userBinPath = "/etc/profiles/per-user/${config.home.username}/bin";
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "close-focused-window" ''
      focused_application_pid=$(${userBinPath}/aerospace list-windows --focused --format '%{app-pid}')
      [ -z "$focused_application_pid" ] && exit 0
      ${userBinPath}/aerospace close
      kill "$focused_application_pid" 2>/dev/null
      (sleep 1 && kill -0 "$focused_application_pid" 2>/dev/null && kill -9 "$focused_application_pid" 2>/dev/null) &
    '')
  ];
}
