# Common config for all darwin hosts
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ../modules/darwin/colima.nix
  ];
  environment.systemPackages = [
    pkgs.mosh
  ];

  # Add Homebrew to PATH
  environment.systemPath = ["/opt/homebrew/bin"];

  # Trying out Determinate Nix which means we have to turn off nix-darwin's nix mgmt.
  nix.enable = false;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # This will be the main user shell
  programs.fish.enable = true;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "unknown-rev";

  # Tell nix-darwin about primaryUser for root migration circa 25.05
  system.primaryUser = "phinze";

  # Get dock out of the way
  system.defaults.dock.autohide = true;

  # Clear all hotcorner behaviors
  system.defaults.dock.wvous-bl-corner = 1;
  system.defaults.dock.wvous-br-corner = 1;
  system.defaults.dock.wvous-tl-corner = 1;
  system.defaults.dock.wvous-tr-corner = 1;

  # Clear all persistent apps from Dock
  # TODO: empty set here doesn't actively clear; maybe add this feature upstream?
  system.defaults.dock.persistent-apps = [];

  # Pin downloads folder to the dock
  # NOTE: static-only HAS to be false, or else no folder pinning works
  system.defaults.dock.static-only = false;

  # Pin downloads folder to the dock
  system.activationScripts.configureDock.text = let
    dock = import ../modules/darwin/dock.nix {
      dockItems = [
        {
          tile-data = {
            file-data = {
              _CFURLString = "file://${config.users.users.phinze.home}/Downloads";
              _CFURLStringType = 15;
            };
            showas = 1; # view content as fan
            arrangement = 2; # sort by date added
            displayas = 0; # display as stack
          };
          tile-type = "directory-tile";
        }
      ];
      inherit lib config;
    };
  in ''
    sudo -u ${config.system.primaryUser} ${dock}
    sudo -u ${config.system.primaryUser} killall Dock
  '';

  # I'll use iStat Menus for clock
  system.defaults.menuExtraClock.IsAnalog = true;

  # No natural scrolling
  system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;

  # Capslock -> Control on internal keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

  # System prompt for sudo operations, preserved within tmux with pam_reattach
  # TODO: This can be reverted to home-manager options once
  #       https://github.com/LnL7/nix-darwin/pull/1020/ is merged in some form
  # security.pam.enableSudoTouchIdAuth = true;
  environment.etc."pam.d/sudo_local" = {
    enable = true;
    text = ''
      auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so
      auth       sufficient     pam_tid.so
    '';
  };

  users.users.phinze = {
    name = "phinze";
    home = "/Users/phinze";

    # NOTE: this does not actually set shell to fish, see https://github.com/LnL7/nix-darwin/issues/779
    # To workaround on system bootstrap, need to manually:
    #   - Add /etc/profiles/per-user/phinze/bin/fish to /etc/shells
    #   - chsh -s /etc/profiles/per-user/phinze/bin/fish
    shell = pkgs.fish;
  };

  homebrew.enable = true;

  # Remove homebrew things unmanaged by nix
  homebrew.onActivation.cleanup = "uninstall";

  # Autoupdate everything homebrew
  homebrew.global.autoUpdate = true;

  homebrew.taps = [
    "phinze/bankshot"
  ];

  homebrew.brews = [
    {
      name = "phinze/bankshot/bankshot";
      start_service = true;
    }
  ];

  homebrew.casks = [
    "1password"
    "1password-cli"
    "balenaetcher"
    "bartender"
    "blackhole-2ch"
    "claude"
    "cleanshot"
    "discord"
    "elgato-control-center"
    "finicky"
    "firefox"
    "ghostty@tip"
    "google-chrome"
    "istat-menus"
    "karabiner-elements"
    "keepingyouawake"
    "keymapp"
    "libreoffice"
    "meetingbar"
    "obs"
    "obsidian"
    "raycast"
    "rectangle"
    "rocket"
    "slack"
    "tailscale"
    "vmware-fusion"
    "zed"
    "zen"
    "zoom"
  ];

  homebrew.masApps = {
    "Numbers" = 409203825;
    "Xcode" = 497799835;
    "Flighty" = 1358823008;
  };

  # Colima for Docker on macOS
  services.colima = {
    enable = true;
    docker = true;
    cpus = 4;
    memory = 8;
    disk = 100;
    vmType = "vz"; # Using vz for better performance on newer Macs
    arch = "aarch64"; # ARM64 for Apple Silicon
  };
}
