{
  description = "NixOS systems and tools by phinze";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:nixos/nixpkgs/release-22.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-22.05";

      # We want home-manager to use the same set of nixpkgs as our system.
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
  };
}
