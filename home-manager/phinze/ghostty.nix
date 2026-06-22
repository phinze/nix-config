# Ghostty terminal configuration for macOS.
#
# This writes ~/.config/ghostty/config, which on macOS is read by *two* apps:
#   - Ghostty itself (the XDG config path takes effect alongside the native
#     Application Support path)
#   - cmux, a Ghostty-based terminal that has no theme system of its own and
#     delegates all terminal coloring to this exact file
#
# So this single file is what keeps cmux's panes and Ghostty looking the same.
#
# The Ghostty *binary* on macOS comes from the Homebrew cask (see
# nix-darwin/common.nix), so package is null here to avoid pulling a
# frequently-broken nixpkgs build just to render a config file. The graphical
# NixOS hosts keep their own programs.ghostty in graphical.nix where the
# nixpkgs package is the real source of the binary.
# Imported unconditionally (gating imports on pkgs causes infinite recursion),
# so the whole module is wrapped in mkIf isDarwin: a no-op on NixOS hosts,
# where graphical.nix owns programs.ghostty instead.
{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  programs.ghostty = {
    enable = true;
    package = null;

    settings = {
      font-family = "Hack";
      macos-option-as-alt = true;

      # Catppuccin Mocha Theme
      background = "1E1E2E";
      foreground = "CDD6F4";
      cursor-color = "F5E0DC";
      selection-background = "F5E0DC";
      selection-foreground = "1E1E2E";

      # Palette colors
      palette = [
        "0=#45475A" # black
        "8=#585B70" # bright black
        "1=#F38BA8" # red
        "9=#F38BA8" # bright red
        "2=#A6E3A1" # green
        "10=#A6E3A1" # bright green
        "3=#F9E2AF" # yellow
        "11=#F9E2AF" # bright yellow
        "4=#89B4FA" # blue
        "12=#89B4FA" # bright blue
        "5=#F5C2E7" # magenta
        "13=#F5C2E7" # bright magenta
        "6=#94E2D5" # cyan
        "14=#94E2D5" # bright cyan
        "7=#BAC2DE" # white
        "15=#A6ADC8" # bright white
      ];

      # Cursor smear shader effect
      custom-shader = "shaders/cursor_smear_fade_tapered.glsl";
      custom-shader-animation = true;

      # Keybind for shift+enter to insert newline (useful in Claude Code and other apps)
      keybind = "shift+enter=text:\\x1b\\r";
    };
  };

  xdg.configFile."ghostty/shaders" = {
    source = ./ghostty-shaders;
    recursive = true;
  };
}
