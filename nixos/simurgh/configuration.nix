# Simurgh - NAS server (Supermicro 2U with ZFS storage)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/baseline.nix
  ];

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS support
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.extraPools = ["tank"];
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # Required for ZFS - must be unique per machine
  # Generated with: head -c 8 /etc/machine-id
  networking.hostId = "0c6452ff";

  networking.hostName = "simurgh";

  # Open firewall for NFS and SMB
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      2049 # NFS
      445 # SMB
      139 # SMB
    ];
    allowedUDPPorts = [
      137 # SMB
      138 # SMB
    ];
  };

  # NAS-specific packages
  environment.systemPackages = with pkgs; [
    htop
    iotop
    smartmontools # disk health monitoring
    zfs # ZFS utilities
  ];

  # Docker for running services
  virtualisation.docker.enable = true;
  users.users.phinze.extraGroups = ["docker"];

  # nh helper with automatic cleanup
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--nogcroots --keep 3";
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
