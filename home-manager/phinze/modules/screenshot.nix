# Screenshot module - Capture website screenshots and share via GitHub gists
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Required packages
  home.packages = with pkgs; [
    pageres-cli # Capture website screenshots
  ];

  # Fish function for the screenshot command
  xdg.configFile."fish/functions/screenshot.fish".source = ./screenshot.fish;
}