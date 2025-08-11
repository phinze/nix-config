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
        git = {
          signing = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC";
          };
        };
      };
    };
    users = {
      # Import your home-manager configuration
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}
