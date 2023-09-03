{
  description = "NixOS systems and tools by phinze";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:nixos/nixpkgs/release-23.05";

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # We have access to unstable nixpkgs if we want specific unstable packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, home-manager, nixpkgs-unstable }: let
    mkVM = import ./lib/mkvm.nix;
  in {
    nixosConfigurations.vm-aarch64 = mkVM "vm-aarch64" {
      inherit nixpkgs nixpkgs-unstable home-manager;
      system = "aarch64-linux";
      user   = "phinze";
    };

    nixosConfigurations.vm-intel = mkVM "vm-intel" {
      inherit nixpkgs nixpkgs-unstable home-manager;
      system = "x86_64-linux";
      user   = "phinze";
    };

    nixosConfigurations.vm-tunnel = mkVM "vm-tunnel" {
      inherit nixpkgs nixpkgs-unstable home-manager;
      system = "x86_64-linux";
      user   = "phinze";
    };

    nixosConfigurations.vm-hc-dev = mkVM "vm-hc-dev" {
      inherit nixpkgs nixpkgs-unstable home-manager;
      system = "x86_64-linux";
      user   = "phinze";
    };

    nixosConfigurations.vm-echobase = mkVM "vm-echobase" {
      inherit nixpkgs nixpkgs-unstable home-manager;
      system = "x86_64-linux";
      user   = "phinze";
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#user@host'
    homeConfigurations = {
      "phinze@pudl-dev" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        # extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          ./users/phinze/home-manager.nix
          ./users/phinze/home-manager-nix-workaround.nix
        ];
      };
      "phinze@phinze-C02ZG0VNLVDL" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-darwin;
        # extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          ./users/phinze/home-manager.nix
          ./users/phinze/home-manager-nix-workaround.nix
        ];
      };
      "phinze@manticore" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        # extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          ./users/phinze/home-manager.nix
          ./users/phinze/home-manager-nix-workaround.nix
        ];
      };
    };
  };
}
