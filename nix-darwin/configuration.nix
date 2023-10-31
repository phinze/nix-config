{ inputs, pkgs, home-manager, ... }: {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
  [ pkgs.vim
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "unknown-rev";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.phinze = {
    name = "phinze";
    home = "/Users/phinze";

    # NOTE: this does not actually set shell to fish, see https://github.com/LnL7/nix-darwin/issues/779
    # To workaround on system bootstrap, need to manually:
    #   - Add /etc/profiles/per-user/phinze/bin/fish to /etc/shells
    #   - chsh -s /etc/profiles/per-user/phinze/bin/fish
    # shell = pkgs.fish;
  };

  homebrew.enable = true;


  homebrew.brews = [
    {
      name = "superbrothers/opener/opener";
      start_service = true;
    }
  ];

  homebrew.casks = [
    "bartender"
    "cleanshot"
    "discord"
    "fantastical"
    "firefox"
    "google-chrome"
    "raycast"
    "rectangle"
    "rocket"
    "slack"
    "teamviewer"
    "zoom"
  ];

  homebrew.masApps = {
    "Bear Notes" = 1091189122;
    "Tailscale" = 1475387142;
  };
}
