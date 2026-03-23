{ ... }:
{
  imports = [ ../../../home/modules/dev/git.nix ];

  programs.git.settings.user = {
    name = "Lucas Zanoni";
    email = "lucas.zanoni@coatesgroup.com";
  };
}
