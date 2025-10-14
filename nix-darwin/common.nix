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

  # Explicitly disable zsh management to avoid /etc/zshrc and /etc/zprofile conflicts
  programs.zsh.enable = false;

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

  # Hide the native menubar since we're using SketchyBar
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;
  
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
    # "istat-menus" # replaced by SketchyBar
    "karabiner-elements"
    "keepingyouawake"
    "keymapp"
    "libreoffice"
    # "meetingbar" # replaced by SketchyBar calendar
    "obs"
    "obsidian"
    "raycast"
    "rectangle"
    "rocket"
    "screenflow"
    "sf-symbols"
    "slack"
    "tailscale-app"
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

  # SketchyBar for custom menubar
  services.sketchybar = {
    enable = true;
    package = pkgs.sketchybar;
    extraPackages = with pkgs; [
      jq
      coreutils
    ];
    config = ''
      #!/usr/bin/env bash

      # Color palette
      WHITE=0xffc5c9c5
      GREEN=0xff96dcb8
      BLUE=0xff8da1ea
      ORANGE=0xfff7b87f
      BG0=0xdd0e1620
      BG1=0x60232434

      # General bar settings
      sketchybar --bar position=top \
                      height=40 \
                      blur_radius=30 \
                      color=$BG0 \
                      padding_left=10 \
                      padding_right=10

      # Default values for items
      sketchybar --default icon.font="SF Pro:Semibold:14.0" \
                          icon.color=$WHITE \
                          icon.padding_right=4 \
                          label.font="SF Pro:Regular:14.0" \
                          label.color=$WHITE \
                          padding_left=5 \
                          padding_right=5

      # Clock with popup for system stats
      sketchybar --add item clock right \
                 --set clock update_freq=10 \
                            icon=􀐬 \
                            script='sketchybar --set clock label="$(date +"%a %d %b %H:%M")"' \
                            click_script='sketchybar --set clock popup.drawing=toggle' \
                 --add item clock.cpu popup.clock \
                 --set clock.cpu icon=􀧓 \
                                icon.color=$ORANGE \
                                label="CPU: Loading..." \
                                background.color=$BG1 \
                                background.corner_radius=5 \
                                background.padding_left=5 \
                                background.padding_right=5 \
                 --add item clock.memory popup.clock \
                 --set clock.memory icon=􀫦 \
                                   icon.color=$BLUE \
                                   label="Memory: Loading..." \
                                   background.color=$BG1 \
                                   background.corner_radius=5 \
                                   background.padding_left=5 \
                                   background.padding_right=5 \
                 --add item clock.network popup.clock \
                 --set clock.network icon=􀤆 \
                                    icon.color=$GREEN \
                                    label="Network: Loading..." \
                                    background.color=$BG1 \
                                    background.corner_radius=5 \
                                    background.padding_left=5 \
                                    background.padding_right=5 \
                 --add item clock.disk popup.clock \
                 --set clock.disk icon=􀨭 \
                                 icon.color=$WHITE \
                                 label="Disk: Loading..." \
                                 background.color=$BG1 \
                                 background.corner_radius=5 \
                                 background.padding_left=5 \
                                 background.padding_right=5

      # Calendar
      sketchybar --add item calendar right \
                 --set calendar icon=􀉉 \
                               icon.color=$BLUE \
                               label="Calendar" \
                               click_script="open -a Calendar"

      # Spaces for AeroSpace (1-5)
      for i in 1 2 3 4 5; do
        sketchybar --add space space.$i left \
                   --set space.$i space=$i \
                                  icon="$i" \
                                  icon.padding_left=7 \
                                  icon.padding_right=7 \
                                  background.color=$BG1 \
                                  background.corner_radius=5 \
                                  background.height=25 \
                                  label.drawing=off \
                                  click_script="aerospace workspace $i"
      done

      # Space separator
      sketchybar --add item space_separator left \
                 --set space_separator icon="│" \
                                      icon.padding_left=10 \
                                      label.drawing=off

      # Front app
      sketchybar --add item front_app left \
                 --set front_app icon.drawing=off \
                                label.color=$WHITE \
                                label.font="SF Pro:Bold:14.0" \
                                script='sketchybar --set front_app label="$INFO"' \
                 --subscribe front_app front_app_switched

      # System stats updater (runs in background)
      (
        while true; do
          # CPU Usage
          CPU_USAGE=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.1f%%", s}')

          # Memory Usage
          MEM_PRESSURE=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print $5}' | tr -d '%')
          MEM_USED=$((100 - MEM_PRESSURE))

          # Disk Usage
          DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')

          # Network (simple check if connected)
          NETWORK_STATUS=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep -o "SSID: .*" | sed 's/^SSID: //' || echo "Disconnected")
          if [ "$NETWORK_STATUS" = "Disconnected" ] || [ -z "$NETWORK_STATUS" ]; then
            NETWORK_LABEL="Not Connected"
          else
            NETWORK_LABEL="$NETWORK_STATUS"
          fi

          # Update popup items
          sketchybar --set clock.cpu label="CPU: $CPU_USAGE" \
                     --set clock.memory label="Memory: ''${MEM_USED}%" \
                     --set clock.network label="WiFi: $NETWORK_LABEL" \
                     --set clock.disk label="Disk: $DISK_USAGE used"

          sleep 5
        done
      ) &

      # Initialize
      sketchybar --update
    '';
  };
}
