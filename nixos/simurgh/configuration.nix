# Simurgh - NAS server (Supermicro 2U with ZFS storage)
#
# Hardware: Supermicro PIO-628U-TR4T+ (X10DRU-i+ motherboard)
# - CPU: Xeon E5-2640 v4, 64GB RAM
# - Boot: 1TB WD_BLACK NVMe via ASUS Hyper M.2 X16 PCIe adapter
# - Storage: 2x 12TB HGST HUH721212ALE600 in ZFS mirror (tank)
#
# BIOS Note: The X10DRU-i+ doesn't have native NVMe boot support.
# We're running a modded BIOS (X10DRU2.427 with NvmExpressDxe driver)
# from: https://winraid.level1techs.com/t/offer-supermicro-x10dru-i-bios-427-mod-for-nvme-boot/98550
# Original BIOS backup recommended before flashing.
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
