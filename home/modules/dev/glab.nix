{ pkgs, ... }:
let
  yamlFormat = pkgs.formats.yaml { };

  glabConfiguration = {
    git_protocol = "ssh";
    glamour_style = "dark";
    check_update = false;
    display_hyperlinks = false;
    host = "git.coates.io";
    no_prompt = false;
    telemetry = false;
    hosts = {
      "git.coates.io" = {
        api_host = "git.coates.io";
        git_protocol = "ssh";
        api_protocol = "https";
        user = "Lucas.Zanoni";
      };
    };
  };
in
{
  home.packages = [ pkgs.glab ];

  xdg.configFile."glab-cli/config.yml".source =
    yamlFormat.generate "glab-config.yml" glabConfiguration;
}
