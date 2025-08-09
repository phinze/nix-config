{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/baseline.nix
    ../../modules/nixos/graphical.nix
    inputs.nixos-hardware.nixosModules.framework-12-13th-gen-intel
  ];

  # Hostname
  networking.hostName = "xiezhi";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use kernel 6.15.5
  # Needed for Ghostty performance regression on 6.15.4
  # See https://github.com/ghostty-org/ghostty/discussions/7720
  boot.kernelPackages = pkgs.linuxPackages_6_15;

  # Framework laptop specific kernel parameters
  boot.kernelParams = [
    "mem_sleep_default=deep"
    "nvme.noacpi=1"
  ];

  # Enable firmware updates
  services.fwupd.enable = true;

  # Power management for laptop
  services.power-profiles-daemon.enable = false; # Disable to avoid conflict with TLP
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
    # Ghostty moved to home-manager module
  ];

  # System version
  system.stateVersion = "25.05";
}

