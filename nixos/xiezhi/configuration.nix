{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/baseline.nix
    ../../modules/nixos/graphical.nix
  ];

  # Hostname
  networking.hostName = "xiezhi";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel for Framework laptop
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Framework laptop specific kernel parameters
  boot.kernelParams = [
    "mem_sleep_default=deep"
    "nvme.noacpi=1"
  ];

  # Enable firmware updates
  services.fwupd.enable = true;

  # Power management for laptop
  services.power-profiles-daemon.enable = false;  # Disable to avoid conflict with TLP
  services.thermald.enable = true;

  # Battery management
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Framework laptop fingerprint reader (if you have one)
  # services.fprintd.enable = true;

  # Additional packages for this machine
  environment.systemPackages = with pkgs; [
    # Ghostty terminal from unstable
    unstable.ghostty
  ];

  # System version
  system.stateVersion = "25.05";
}