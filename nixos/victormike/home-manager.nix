{
  inputs,
  outputs,
  ...
}: {
  imports = [
    # Import home-manager's NixOS module
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs;
      nodeConfig = {
        # Default empty config for NixOS hosts
      };
    };
    users = {
      # Import your home-manager configuration
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}
