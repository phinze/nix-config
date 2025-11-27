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
      nodeConfig = {
        git = {
          signing = {
            # Simurgh signing key - update after generating key on machine
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC";
          };
        };
      };
    };
    users = {
      phinze = import ../../home-manager/phinze/home.nix;
    };
  };
}
