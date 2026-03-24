_: {
  home.sessionPath = [
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/bin"
    "/bin"
  ];

  home.sessionVariables = {
    OBSIDIAN_HOME = "$HOME/vault";
    EDITOR = "code";
  };
}
