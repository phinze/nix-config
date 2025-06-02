{config, lib, ...}: {
  imports = [
    ../common.nix
  ];

  # Add host-specific homebrew casks
  homebrew.casks = lib.mkAfter (config.home-manager.extraSpecialArgs.nodeConfig.extraCasks or []);
}
