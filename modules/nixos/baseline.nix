{
  config,
  options,
  pkgs,
  lib,
  outputs,
  inputs,
  ...
}: {
  imports = [
    inputs.bankshot.nixosModules.default
  ];
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
      download-buffer-size = 1073741824; # 1GB (default is 64MB)
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

  # Raise inotify instance limit — default 128 is too low when running
  # many fish shells, Claude Code workers, and editor instances.
  boot.kernel.sysctl."fs.inotify.max_user_instances" = 512;

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
    bind.dnsutils # provides dig for DNS lookups
  ];

  # Environment variables
  environment.variables = {
    EDITOR = "vim";
  };

  # Enable fish shell
  programs.fish.enable = true;

  # Enable mtr for network diagnostics
  programs.mtr.enable = true;

  # Enable mosh for remote connections
  programs.mosh.enable = true;

  # Bankshot port monitoring, as a system service running as phinze.
  #
  # It has to be a system service: the monitor needs CAP_BPF and CAP_PERFMON
  # for eBPF, systemd can only grant capabilities to a system unit, and a
  # user unit's only way to get them is to exec a setcap copy out of
  # /run/wrappers. That route leaves a capability-carrying bankshot any local
  # user can exec, and it decouples the unit from the binary it runs, so the
  # monitor silently drifts a build behind on every rebuild. Ambient
  # capabilities scope the grant to this one process and let ExecStart name
  # the store path.
  #
  # Pointing configFile at the file home-manager already renders keeps one
  # source of truth for the settings, and means a config change changes the
  # unit and restarts the monitor onto it.
  services.bankshot.monitor = lib.mkIf (options ? home-manager) {
    enable = true;
    user = "phinze";
    configFile = config.home-manager.users.phinze.programs.bankshot.generatedConfig;
  };

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

    # Drop the default %h/.ssh/authorized_keys so the keys below are the only
    # ones that work; a stray ssh-copy-id here is a no-op by design.
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
  };

  # User configuration
  users.users.phinze = {
    isNormalUser = true;
    hashedPassword = inputs.nix-private.data.hashedPassword;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC phinze@phinze-mrn-mbp"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKri4aveRRo7osskk6Wg8urqRm1RuAZK0bksJvKiHcKUk55kQoES/aPIr+vC5tVETE+2AHrFmIuZfGf2PHeruwM= phinze@delevingne"
    ];
    extraGroups = ["wheel"];
    shell = pkgs.fish;
  };
}
