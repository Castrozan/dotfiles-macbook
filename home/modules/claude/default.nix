{ ... }:
{
  imports = [
    ./claude.nix
    ./config.nix
    ./mcps.nix
    ./skills.nix
    ./hooks.nix
    ./private.nix
    ./workspace-trust.nix
    ./scripts.nix
  ];
}
