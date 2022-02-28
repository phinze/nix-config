{ config, pkgs, ... }: {
  imports = [
    ./vm-shared.nix
  ];

  networking.hostName = pkgs.lib.mkForce "hc-dev";

  networking.interfaces.ens18.useDHCP = true;
}
