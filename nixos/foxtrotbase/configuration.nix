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

    # Rex login server, reached from the Mac over Tailscale Serve
    ../../modules/nixos/rex.nix
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

  # Keep logs from becoming a second disk incident while preserving enough
  # history for ordinary debugging. The user-level cleanup timers handle
  # Docker and Rig scratch separately.
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemKeepFree=5G
    MaxRetentionSec=7day
  '';

  # Memory pressure handling. The usual threat is Claude sessions that each
  # grow to several GB; the claude wrapper (home-manager/phinze/claude-code.nix)
  # puts every session in its own scope so the pieces below can evict one
  # session instead of all of them.
  #   - zram gives us compressed-RAM swap, so reclaim is fast and the box
  #     stays responsive under pressure instead of thrashing on disk swap.
  #   - systemd-oomd kills the worst cgroup under user.slice after sustained
  #     memory pressure, and anywhere once swap passes SwapUsedLimit. The swap
  #     rule matters because zram can hold pressure under the PSI limit while
  #     swap fills: on 2026-10-30 both swaps sat full, the PSI rule never
  #     fired, and the box wedged for six hours.
  #   - The floors keep oomd, sshd, tailscaled and journald resident while
  #     agents thrash. That same morning oomd's own pages were evicted, its
  #     watchdog killed it, and every restart timed out paging back in. The
  #     cgroup2 mount has no memory_recursiveprot, so a floor only counts if
  #     system.slice carries one too.
  # No per-session memory cap: a single session can grow as needed; only
  # under genuine system-wide pressure does anyone get evicted.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  systemd.oomd = {
    enableUserSlices = true;
    settings.OOM.SwapUsedLimit = "75%";
  };
  systemd.slices."-".sliceConfig.ManagedOOMSwap = "kill";
  systemd.slices.system.sliceConfig.MemoryMin = "1G";
  systemd.services.systemd-oomd.serviceConfig.MemoryMin = "64M";
  systemd.services.sshd.serviceConfig.MemoryMin = "64M";
  systemd.services.tailscaled.serviceConfig.MemoryMin = "128M";
  systemd.services.systemd-journald.serviceConfig.MemoryMin = "128M";

  # Disable the firewall since we're in a VM and we want to make it
  # easy to visit stuff in here. We only use NAT networking anyways.
  networking.firewall.enable = false;

  networking.hostName = "foxtrotbase";

  # Add docker group to user (baseline provides wheel group)
  users.users.phinze.extraGroups = [ "docker" ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
