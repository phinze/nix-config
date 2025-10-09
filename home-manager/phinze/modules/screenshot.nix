# Screenshot module - Capture website screenshots and share via GitHub gists
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Required packages - only install on Linux since pageres-cli depends on Chromium
  home.packages = with pkgs;
    lib.optionals pkgs.stdenv.isLinux [
      pageres-cli # Capture website screenshots

      # Install the screenshot script
      (pkgs.writeScriptBin "screenshot" (builtins.readFile ./screenshot.sh))
    ];
}
