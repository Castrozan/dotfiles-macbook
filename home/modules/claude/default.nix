{ ... }:
{
  imports = [
    ./claude.nix
    ./config.nix
    ./external-skill-sets.nix
    ./hooks.nix
    ./mcps
    ./private.nix
    ./scripts.nix
    ./skills.nix
    ./workspace-trust.nix
  ];
}
