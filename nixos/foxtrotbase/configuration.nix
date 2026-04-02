# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
{
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
  boot.kernelModules = [ "nbd" ];

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # VM-specific packages (baseline provides: gnumake, killall, git, vim, wget, curl, dig)
  environment.systemPackages = with pkgs; [
    docker-compose
    pageres-cli
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
  users.users.phinze.extraGroups = [ "docker" ];

  # Ensure the parent directory tree exists for the SSHFS mountpoint
  # Using /Users/phinze to match macOS path structure for consistency
  systemd.tmpfiles.rules = [
    "d /Users 0755 root root -"
    "d /Users/phinze 0755 phinze users -"
    "d /Users/phinze/Library 0755 phinze users -"
    "d '/Users/phinze/Library/Application Support' 0755 phinze users -"
    "d '/Users/phinze/Library/Application Support/CleanShot' 0755 phinze users -"
    "d '/Users/phinze/Library/Application Support/CleanShot/media' 0755 phinze users -"
  ];

  # SSHFS mount for on-demand access to CleanShot screenshots from Mac
  # Reads pass through immediately over Tailscale SSH — no sync delay
  programs.fuse.userAllowOther = true;
  systemd.user.services.cleanshot-sshfs = {
    description = "SSHFS mount for CleanShot media from phinze-mrn-mbp";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      Environment = "SSH_AUTH_SOCK=%h/.ssh/agent.sock";
      ExecStart = ''
        ${pkgs.sshfs}/bin/sshfs \
          phinze-mrn-mbp:"Library/Application Support/CleanShot/media" \
          "/Users/phinze/Library/Application Support/CleanShot/media" \
          -f \
          -o reconnect \
          -o ServerAliveInterval=15 \
          -o ServerAliveCountMax=3 \
          -o allow_other \
          -o idmap=user
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -u '/Users/phinze/Library/Application Support/CleanShot/media'";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
