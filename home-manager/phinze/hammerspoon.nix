{
  pkgs,
  lib,
  ...
}: {
  # Hammerspoon configuration (macOS only)
  # Provides:
  # - Caps Lock (remapped to Control via System Preferences) tap → Escape
  # - Cmd+Tab → Hyper+W (for Raycast Switch Windows)
  #
  # Note: After first install, grant Hammerspoon accessibility permissions
  # in System Preferences > Privacy & Security > Accessibility

  home.file = lib.mkIf pkgs.stdenv.isDarwin {
    ".hammerspoon" = {
      source = ./hammerspoon;
      recursive = true;
    };
  };
}
