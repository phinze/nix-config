{
  description = "Phinze's nix configs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    systems.url = "github:nix-systems/default";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim-config.url = "github:phinze/nixvim-config";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    bankshot.url = "github:phinze/bankshot";
    bankshot.inputs.nixpkgs.follows = "nixpkgs-unstable";
    bankshot.inputs.flake-utils.follows = "flake-utils";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    zen-browser.url = "github:FBIGlowie/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs-unstable";

    claude-desktop.url = "github:phinze/claude-desktop-linux-flake/fix-fhs-desktop-file";
    claude-desktop.inputs.nixpkgs.follows = "nixpkgs-unstable";
    claude-desktop.inputs.flake-utils.follows = "flake-utils";

    double-agent.url = "github:phinze/double-agent";
    double-agent.inputs.nixpkgs.follows = "nixpkgs-unstable";
    double-agent.inputs.flake-utils.follows = "flake-utils";

    sophon.url = "github:phinze/sophon";
    sophon.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sophon.inputs.flake-utils.follows = "flake-utils";

    camlink-fix.url = "github:phinze/camlink-fix";
    camlink-fix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    camlink-fix.inputs.flake-utils.follows = "flake-utils";

    claude-code-nix.url = "github:sadjow/claude-code-nix";
    claude-code-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    claude-plugin-coderabbit = {
      url = "github:coderabbitai/claude-plugin";
      flake = false;
    };

    iso.url = "git+https://github.com/mirendev/iso.git";

    multipass.url = "git+https://github.com/mirendev/multipass.git";
    multipass.inputs.nixpkgs.follows = "nixpkgs-unstable";
    multipass.inputs.flake-utils.follows = "flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      eachSystem = nixpkgs.lib.genAttrs (import inputs.systems);
    in
    {
      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages = eachSystem (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Formatter for your nix files, available through 'nix fmt'
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      # homeManagerModules = import ./modules/home-manager;

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        foxtrotbase = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            # > Our main nixos configuration file <
            ./nixos/foxtrotbase/configuration.nix
            ./nixos/foxtrotbase/home-manager.nix
          ];
        };

        # A VMware Fusion VM for isolation on manticore
        victormike = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            # > Our main nixos configuration file <
            ./nixos/victormike/configuration.nix
            ./nixos/victormike/home-manager.nix
          ];
        };

        # Framework 12" laptop
        xiezhi = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/xiezhi/configuration.nix
            ./nixos/xiezhi/home-manager.nix
          ];
        };

        # Supermicro NAS server with ZFS
        simurgh = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/simurgh/configuration.nix
            ./nixos/simurgh/home-manager.nix
          ];
        };
      };

      # Darwin machines
      # Run with `darwin-rebuild --flake .`
      darwinConfigurations = {
        manticore = nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nix-darwin/manticore/configuration.nix
            ./nix-darwin/manticore/home-manager.nix
          ];
        };
        phinze-mrn-mbp = nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nix-darwin/phinze-mrn-mbp/configuration.nix
            ./nix-darwin/phinze-mrn-mbp/home-manager.nix
          ];
        };
      };
    };
}
