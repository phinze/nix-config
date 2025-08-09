{ inputs, outputs, config, pkgs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs outputs;
      nodeConfig = {
        isGraphical = true;
        git = {
          signing = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDHP/N4P043PsjSR8rsvpBDAwOy7PEZCMVM1+gs32Nn";
            format = "ssh";
          };
        };
      };
    };
    users = {
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}