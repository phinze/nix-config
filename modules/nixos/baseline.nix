{
  config,
  pkgs,
  lib,
  outputs,
  inputs,
  ...
}: {
  # Nixpkgs configuration
  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  # Nix configuration
  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
      nix-path = config.nix.nixPath;
      trusted-users = [
        "root"
        "@wheel"
      ];
      download-buffer-size = 268435456; # 256MB (default is 64MB)
    };
    channel.enable = false;
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # Time zone
  time.timeZone = "America/Chicago";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Security
  security.sudo.wheelNeedsPassword = false;
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "65535";
    }
  ];

  # Common system packages
  environment.systemPackages = with pkgs; [
    gnumake
    killall
    git
    vim
    wget
    curl
  ];

  # Enable fish shell
  programs.fish.enable = true;

  # Enable mtr for network diagnostics
  programs.mtr.enable = true;

  # Enable mosh for remote connections
  programs.mosh.enable = true;

  # Tailscale for networking
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";

  # SSH configuration
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

  # User configuration
  users.users.phinze = {
    isNormalUser = true;
    hashedPassword = "$6$Q/O4KQMXp7e9wPEo$XYxU5wFxk8NzqiozL7w0ZYFgXs8/W2FvGm3ovJdH8Mfvq.JEIBagq.DshoFbZP.HCdyaAuBt9CaoT5DUg3VWy.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIzuIlDCddhK8kGCtaytBs1wfzPb976Z8iHAgkB7h2eX phinze@manticore"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC phinze@phinze-mrn-mbp"
    ];
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  # Enable NetworkManager for graphical environments (overridden in server configs)
  networking.networkmanager.enable = true;
}
