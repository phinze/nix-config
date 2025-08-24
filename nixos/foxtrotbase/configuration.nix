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
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
      # Let anybody with sudo be a trusted-user; helps prevent permissions
      # errors when building from remote host
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # Midwest ho!
  time.timeZone = "America/Chicago";

  # But let's be reasonable about the locale.
  i18n.defaultLocale = "en_US.UTF-8";

  # Don't require password for sudo
  security.sudo.wheelNeedsPassword = false;

  # Raise ulimits because we love to open files
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "65535";
    }
  ];

  # Packages we want in system profile.
  environment.systemPackages = with pkgs; [
    gnumake
    killall
    docker-compose
  ];

  # Fonts for terminal recording tools like agg
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # Docker is a system-level install.
  virtualisation.docker.enable = true;

  # MTR is SUID wrapped so easier to have it around at the system level than
  # mess with sudo when we need it.
  programs.mtr.enable = true;

  # Mosh is good on dicey connections
  programs.mosh.enable = true;

  # Our primary method of accessing stuff
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";

  # Disable the firewall since we're in a VM and we want to make it
  # easy to visit stuff in here. We only use NAT networking anyways.
  networking.firewall.enable = false;

  networking.hostName = "foxtrotbase";

  programs.fish.enable = true;

  users.users = {
    phinze = {
      isNormalUser = true;
      hashedPassword = "$6$Q/O4KQMXp7e9wPEo$XYxU5wFxk8NzqiozL7w0ZYFgXs8/W2FvGm3ovJdH8Mfvq.JEIBagq.DshoFbZP.HCdyaAuBt9CaoT5DUg3VWy.";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIzuIlDCddhK8kGCtaytBs1wfzPb976Z8iHAgkB7h2eX phinze@manticore"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC phinze@phinze-mrn-mbp"
      ];

      extraGroups = ["docker" "wheel"];

      shell = pkgs.fish;
    };
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    extraConfig = ''
      # For opener
      StreamLocalBindUnlink yes
    '';
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
