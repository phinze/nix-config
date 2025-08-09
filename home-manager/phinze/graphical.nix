# Graphical-specific home-manager configuration
# Only included on machines with graphical environments
{ config, pkgs, lib, ... }:

{
  # GNOME settings for caps lock to ctrl
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = ["ctrl:nocaps"];
    };
  };
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "Hack";
      macos-option-as-alt = lib.mkIf pkgs.stdenv.isDarwin true;
      
      # Catppuccin Mocha Theme
      background = "1E1E2E";
      foreground = "CDD6F4";
      cursor-color = "F5E0DC";
      selection-background = "F5E0DC";
      selection-foreground = "1E1E2E";
      
      # Palette colors
      palette = [
        "0=#45475A"  # black
        "8=#585B70"  # bright black
        "1=#F38BA8"  # red
        "9=#F38BA8"  # bright red
        "2=#A6E3A1"  # green
        "10=#A6E3A1" # bright green
        "3=#F9E2AF"  # yellow
        "11=#F9E2AF" # bright yellow
        "4=#89B4FA"  # blue
        "12=#89B4FA" # bright blue
        "5=#F5C2E7"  # magenta
        "13=#F5C2E7" # bright magenta
        "6=#94E2D5"  # cyan
        "14=#94E2D5" # bright cyan
        "7=#BAC2DE"  # white
        "15=#A6ADC8" # bright white
      ];
      
      # Cursor smear shader effect
      custom-shader = "shaders/cursor_smear_fade_tapered.glsl";
      custom-shader-animation = true;
    };
  };

  xdg.configFile."ghostty/shaders" = {
    source = ./ghostty-shaders;
    recursive = true;
  };
}