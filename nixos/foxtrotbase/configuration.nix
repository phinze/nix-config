# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix

    # Import baseline NixOS configuration
    ../../modules/nixos/baseline.nix

    # Shutdown safety for NBD device hangs
    ../../modules/nixos/shutdown-safety.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Load nbd kernel module for Miren development
  boot.kernelModules = ["nbd"];

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # VM-specific packages (baseline provides: gnumake, killall, git, vim, wget, curl, dig)
  environment.systemPackages = with pkgs; [
    docker-compose
    pageres-cli
    syncthing # CLI for debugging syncthing
    synckick # Quick command to trigger syncthing scans
    whoson # Show process info for a port
  ];

  # Fonts for terminal recording tools like agg
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # Docker is a system-level install.
  virtualisation.docker.enable = true;

  # nh helper with automatic cleanup
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--nogcroots --keep 3";
  };

  # Disable the firewall since we're in a VM and we want to make it
  # easy to visit stuff in here. We only use NAT networking anyways.
  networking.firewall.enable = false;

  networking.hostName = "foxtrotbase";

  # Add docker group to user (baseline provides wheel group)
  users.users.phinze.extraGroups = ["docker"];

  # Syncthing service for receiving CleanShot screenshots from Mac
  services.syncthing = {
    enable = true;
    user = "phinze";
    dataDir = "/home/phinze";
    configDir = "/home/phinze/.config/syncthing";
    # Don't override - let Syncthing manage devices/folders in its database
    # This avoids the device ID chicken-and-egg problem
    overrideDevices = false;
    overrideFolders = false;

    settings = {
      # Allow access to web UI from Tailscale network
      gui = {
        address = "0.0.0.0:8384";
      };

      options = {
        # Use local discovery - Tailscale makes all devices appear local!
        localAnnounceEnabled = true;
        # Disable global discovery - we don't need public discovery servers
        # since Tailscale handles device discovery and connectivity
        globalAnnounceEnabled = false;
        # Disable public relays - direct Tailscale connection is faster
        relaysEnabled = false;
        # NAT traversal not needed with Tailscale's mesh network
        natEnabled = false;
        # Optionally reduce announcement interval since Tailscale is reliable
        localAnnounceIntervalS = 21600; # 6 hours instead of default
      };
    };
  };

  # Ensure the target directory exists with proper permissions
  # Using /Users/phinze to match macOS path structure for consistency
  systemd.tmpfiles.rules = [
    "d /Users 0755 root root -"
    "d /Users/phinze 0755 phinze users -"
    "d /Users/phinze/Library 0755 phinze users -"
    "d '/Users/phinze/Library/Application Support' 0755 phinze users -"
    "d '/Users/phinze/Library/Application Support/CleanShot' 0755 phinze users -"
    "d '/Users/phinze/Library/Application Support/CleanShot/media' 0755 phinze users -"
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
