{ pkgs, ... }:
let
  workspaceSwitcherClientSource = pkgs.writeText "workspace-switcher-send.c" ''
    #include <sys/socket.h>
    #include <sys/un.h>
    #include <string.h>
    #include <unistd.h>

    int main(int argc, char *argv[]) {
      if (argc < 2) return 1;
      int fd = socket(AF_UNIX, SOCK_STREAM, 0);
      if (fd < 0) return 1;
      struct sockaddr_un addr;
      memset(&addr, 0, sizeof(addr));
      addr.sun_family = AF_UNIX;
      strncpy(addr.sun_path, "/tmp/workspace-switcher.sock", sizeof(addr.sun_path) - 1);
      if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return 1;
      }
      write(fd, argv[1], strlen(argv[1]));
      close(fd);
      return 0;
    }
  '';
in
{
  home.packages = [
    (pkgs.stdenv.mkDerivation {
      name = "workspace-switcher-send";
      src = workspaceSwitcherClientSource;
      unpackPhase = "true";
      buildPhase = "$CC -O2 -o workspace-switcher-send $src";
      installPhase = "mkdir -p $out/bin && cp workspace-switcher-send $out/bin/";
    })
  ];
}
