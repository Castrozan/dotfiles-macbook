{ ... }:
{
  imports = [
    ./claude.nix
    ./config.nix
    ./discord-channel
    ./external-skill-sets.nix
    ./hooks.nix
    ./mcps
    ./private.nix
    ./scripts.nix
    ./skills.nix
    ./workspace-trust.nix
  ];
}
