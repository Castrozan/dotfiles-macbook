{ ... }:
{
  imports = [
    ./claude.nix
    ./config.nix
    ./skills.nix
    ./hooks.nix
    ./private.nix
    ./workspace-trust.nix
    ./scripts.nix
  ];
}
