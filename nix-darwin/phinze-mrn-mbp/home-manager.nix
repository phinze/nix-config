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
    extraSpecialArgs = {
      inherit inputs outputs;
      nodeConfig = {
        git = {
          signing = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC";
            # TODO: when home-manager gets these first class in the next release, wire them in instead of the extraConfig
            # format = "ssh";
            # signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          };
          extraConfig = {
            gpg.format = "ssh";
            gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          };
        };
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
