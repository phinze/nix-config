{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Enable NetworkManager for graphical environments
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
    options = "ctrl:nocaps";
  };

  # Also configure for console and GNOME/Wayland
  console.useXkbConfig = true;

  # GNOME-specific keyboard settings
  services.gnome.core-shell.enable = true;

  # Configure keyboard settings via dconf for GNOME/Wayland
  programs.dconf.enable = true;

  # Set caps lock to ctrl for GNOME and improve XWayland scaling
  services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.input-sources]
    xkb-options=['ctrl:nocaps']

    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']

    [org.gnome.shell]
    enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com']
  '';

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable touchpad support
  services.libinput.enable = true;

  # Enable Wayland support for Electron apps
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Qt should try Wayland first, then fall back to X11
  environment.sessionVariables.QT_QPA_PLATFORM = "wayland;xcb";

  # Install firefox
  programs.firefox.enable = true;

  # Additional packages for graphical environment
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager
    dconf-editor # For debugging GNOME settings
    gnomeExtensions.appindicator # System tray support for 1Password and other apps
    inputs.zen-browser.packages.${pkgs.system}.default
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
    slack
    discord
    zoom-us
    google-chrome
  ];

  # Enable 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = ["phinze"];
  };

  # Allow 1Password extension in browsers
  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        .zen-wrapped
      '';
      mode = "0644";
    };
  };

  # Enable automatic login for convenience (optional)
  # services.xserver.displayManager.autoLogin.enable = true;
  # services.xserver.displayManager.autoLogin.user = "phinze";

  # Workaround for GNOME autologin
  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;
}
