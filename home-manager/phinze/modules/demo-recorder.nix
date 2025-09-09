# Demo recorder module - Record terminal demos and share as GIFs via GitHub gists
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Required packages
  home.packages = with pkgs; [
    asciinema # Record terminal sessions
    asciinema-agg # Convert asciinema recordings to GIF
    
    # Install the demo script
    (pkgs.writeScriptBin "demo" (builtins.readFile ./demo.sh))
  ];
}
