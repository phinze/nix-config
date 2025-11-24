{pkgs}: let
  runtimeDeps = with pkgs; [
    curl
    gnugrep
  ];
in
  pkgs.writeShellScriptBin "synckick" ''
    #!/usr/bin/env bash
    set -euo pipefail

    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

    FOLDER="''${1:-uq2jt-jcu6r}"
    APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' ~/.config/syncthing/config.xml)

    curl -s -X POST -H "X-API-Key: $APIKEY" "http://127.0.0.1:8384/rest/db/scan?folder=$FOLDER"
    echo "✓ Syncthing scan triggered for folder: $FOLDER"
  ''
