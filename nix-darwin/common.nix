# Common config for all darwin hosts
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    pkgs.mosh
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "unknown-rev";

  # Get dock out of the way
  system.defaults.dock.autohide = true;
  system.defaults.dock.static-only = true;

  # Clear all hotcorner behaviors
  system.defaults.dock.wvous-bl-corner = 1;
  system.defaults.dock.wvous-br-corner = 1;
  system.defaults.dock.wvous-tl-corner = 1;
  system.defaults.dock.wvous-tr-corner = 1;

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
    "homebrew/services"
    "superbrothers/opener"
  ];

  homebrew.brews = [
    {
      name = "superbrothers/opener/opener";
      start_service = true;
    }
  ];

  homebrew.casks = [
    "1password"
    "bartender"
    "cleanshot"
    "discord"
    "elgato-control-center"
    "firefox"
    "google-chrome"
    "istat-menus"
    "keepingyouawake"
    "keymapp"
    "meetingbar"
    "obsidian"
    "notion"
    "raycast"
    "rectangle"
    "rocket"
    "slack"
    "vmware-fusion"
    "zoom"
  ];
}
