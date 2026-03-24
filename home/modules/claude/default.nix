{ ... }:
{
  imports = [
    ./claude.nix
    ./config.nix
    ./mcps
    ./skills.nix
    ./hooks.nix
    ./private.nix
    ./workspace-trust.nix
    ./scripts.nix
  ];
}
