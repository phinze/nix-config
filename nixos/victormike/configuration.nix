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
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # VM-specific packages (baseline provides: gnumake, killall, git, vim, wget, curl, dig)
  environment.systemPackages = with pkgs; [
    docker-compose
  ];

  # Docker is a system-level install.
  virtualisation.docker.enable = true;

  # Disable the firewall since we're in a VM and we want to make it
  # easy to visit stuff in here. We only use NAT networking anyways.
  networking.firewall.enable = false;

  networking.hostName = "victormike";

  # Add docker group to user (baseline provides wheel group)
  users.users.phinze.extraGroups = ["docker"];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
