{
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs;
      nodeConfig = { };
    };
    users = {
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}
