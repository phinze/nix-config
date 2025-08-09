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
      };
    };
    users = {
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}