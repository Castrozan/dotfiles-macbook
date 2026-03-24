{ pkgs, ... }:
{
  home.packages = [ pkgs.jira-cli-go ];

  home.file.".config/.jira/.config.yml".source = ./jira-config.yml;
}
