{
  description = "Macbook dotfiles — nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-latest.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv/v1.11.2";
    lazygit.url = "github:Castrozan/lazygit";
    cmatrix.url = "github:castrozan/cmatrix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-latest,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      darwinSystem = "aarch64-darwin";
      home-version = "25.11";
      nixpkgs-version = "25.11";

      darwin = {
        pkgs = import nixpkgs {
          system = darwinSystem;
          config.allowUnfree = true;
        };
        unstable = import nixpkgs-unstable {
          system = darwinSystem;
          config.allowUnfree = true;
        };
        latest = import nixpkgs-latest {
          system = darwinSystem;
          config.allowUnfree = true;
        };
      };
    in
    {
      darwinConfigurations =
        let
          username = "lucas.zanoni";
          specialArgs = {
            inherit
              nixpkgs-version
              home-version
              inputs
              username
              ;
            inherit (darwin) unstable latest;
            isNixOS = false;
          };
        in
        {
          macbook = nix-darwin.lib.darwinSystem {
            inherit specialArgs;
            system = darwinSystem;

            modules = [
              ./hosts/macbook
              home-manager.darwinModules.home-manager
              (import ./users/lucas.zanoni/darwin-home-config.nix)
            ];
          };
        };

      homeManagerModules = {
        claude-code = ./home/modules/claude;
      };

      checks.${darwinSystem} = import ./tests/nix-checks {
        pkgs = darwin.pkgs;
        inherit
          inputs
          self
          nixpkgs-version
          home-version
          ;
        inherit (nixpkgs) lib;
      };
    };
}
