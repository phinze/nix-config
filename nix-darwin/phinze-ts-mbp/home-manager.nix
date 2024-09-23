{
  inputs,
  outputs,
  ...
}: {
  imports = [
    # Import home-manager's Darwin module
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useUserPackages = true;
    backupFileExtension = "nix-backup";

    users = {
      # Import your home-manager configuration
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}
