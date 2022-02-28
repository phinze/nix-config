{ config, pkgs, ... }: {
  imports = [
    ./vm-shared.nix
  ];

  networking.hostName = pkgs.lib.mkForce "hc-dev";

  networking.interfaces.ens18.useDHCP = true;

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # Virtualbox for Vagrant dev
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["phinze"];
}
