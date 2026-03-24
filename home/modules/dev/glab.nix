{ pkgs, config, ... }:
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

  glabConfigSource = yamlFormat.generate "glab-config.yml" glabConfiguration;

  glabConfigDestination = "${config.xdg.configHome}/glab-cli/config.yml";

  deployGlabConfigScript = pkgs.writeShellScript "deploy-glab-config" ''
    set -euo pipefail
    mkdir -p "$(dirname "${glabConfigDestination}")"
    rm -f "${glabConfigDestination}"
    cp "${glabConfigSource}" "${glabConfigDestination}"
    chmod 600 "${glabConfigDestination}"
  '';
in
{
  home.packages = [ pkgs.glab ];

  home.activation.deployGlabConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    run ${deployGlabConfigScript}
  '';
}
