{
  inputs,
  outputs,
  ...
}:
{
  imports = [
    # Import home-manager's Darwin module
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs;
      nodeConfig = {
        # Host-specific packages for phinze-mrn-mbp
        extraPackages = [ ];
        # Host-specific homebrew casks for phinze-mrn-mbp
        extraCasks = [
          "gather"
          "linear-linear"
        ];
        isMemexHost = true;
      };
    };
    useUserPackages = true;
    backupFileExtension = "nix-backup";

    users = {
      # Import your home-manager configuration
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}
