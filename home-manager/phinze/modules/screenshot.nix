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

    # Install the screenshot script
    (pkgs.writeScriptBin "screenshot" (builtins.readFile ./screenshot.sh))
  ];
}
