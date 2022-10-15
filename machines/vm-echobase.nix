{ config, pkgs, ... }: {
  imports = [
    ./vm-shared.nix
  ];

  networking.hostName = pkgs.lib.mkForce "echobase";
  networking.interfaces.ens18.useDHCP = true;

  # Enable qemu guest agent
  services.qemuGuest.enable = true;
}
