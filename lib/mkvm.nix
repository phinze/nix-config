# This function creates a NixOS system based on our VM setup for a
# particular architecture.
name: { nixpkgs, nixpkgs-unstable, home-manager, system, user }:

nixpkgs.lib.nixosSystem rec {
  inherit system;

  modules = [
    ../hardware/${name}.nix
    ../machines/${name}.nix
    ../users/${user}/nixos.nix
    home-manager.nixosModules.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import ../users/${user}/home-manager.nix;
    }

    ({ config, pkgs, ... }:
    let
      overlay-unstable = final: prev: {
        unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
      };
    in
      {
        nixpkgs.overlays = [ overlay-unstable ];
        environment.systemPackages = with pkgs; [
          unstable.mosh
        ];
      }
      )

    {
      config._module.args = {
        currentSystem = system;
      };
    }
  ];

}
