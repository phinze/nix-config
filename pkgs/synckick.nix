{pkgs}: let
  runtimeDeps = with pkgs; [
    curl
    jq
    gnugrep
    openssh
  ];
in
  pkgs.writeShellScriptBin "synckick" ''
    #!/usr/bin/env bash
    set -euo pipefail

    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

    FOLDER="''${1:-uq2jt-jcu6r}"
    APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' ~/.config/syncthing/config.xml)
    API="http://127.0.0.1:8384"

    # Check if any devices are disconnected
    disconnected=$(curl -s -H "X-API-Key: $APIKEY" "$API/rest/system/connections" | \
      jq '[.connections | to_entries[] | select(.value.connected == false)] | length')

    if [ "$disconnected" -gt 0 ]; then
      echo "⚠ Found $disconnected disconnected device(s), restarting syncthing..."
      curl -s -X POST -H "X-API-Key: $APIKEY" "$API/rest/system/restart" > /dev/null

      # Wait for syncthing to come back up
      echo -n "  Waiting for syncthing"
      for i in {1..30}; do
        sleep 1
        echo -n "."
        # Re-read API key in case it changed after restart
        if [ -f ~/.config/syncthing/config.xml ]; then
          NEW_APIKEY=$(grep -oP '(?<=<apikey>)[^<]+' ~/.config/syncthing/config.xml 2>/dev/null || echo "")
          if [ -n "$NEW_APIKEY" ]; then
            APIKEY="$NEW_APIKEY"
          fi
        fi
        if curl -s -H "X-API-Key: $APIKEY" "$API/rest/system/status" > /dev/null 2>&1; then
          echo " up!"
          break
        fi
      done

      # Wait a bit more for connections to establish
      echo -n "  Waiting for connections"
      for i in {1..10}; do
        sleep 1
        echo -n "."
        connected=$(curl -s -H "X-API-Key: $APIKEY" "$API/rest/system/connections" 2>/dev/null | \
          jq '[.connections | to_entries[] | select(.value.connected == true)] | length' 2>/dev/null || echo "0")
        if [ "$connected" -gt 0 ]; then
          echo " connected!"
          break
        fi
      done
    fi

    # Capture local file count before we start
    initial_status=$(curl -s -H "X-API-Key: $APIKEY" "$API/rest/db/status?folder=$FOLDER")
    initial_local=$(echo "$initial_status" | jq -r '.localFiles')

    # Trigger scan on remote Mac first (so it advertises new files)
    echo -n "Kicking remote (phinze-mrn-mbp)..."
    REMOTE_APIKEY=$(ssh -o ConnectTimeout=5 phinze-mrn-mbp \
      "grep -oP '(?<=<apikey>)[^<]+' ~/Library/Application\ Support/Syncthing/config.xml" 2>/dev/null || echo "")
    if [ -n "$REMOTE_APIKEY" ]; then
      ssh phinze-mrn-mbp \
        "curl -s -X POST -H 'X-API-Key: $REMOTE_APIKEY' 'http://127.0.0.1:8384/rest/db/scan?folder=$FOLDER'" 2>/dev/null || true
      echo " done"
      # Give it a moment to scan and advertise
      sleep 2
    else
      echo " failed (couldn't get API key)"
    fi

    # Trigger the local scan
    echo -n "Kicking local..."
    curl -s -X POST -H "X-API-Key: $APIKEY" "$API/rest/db/scan?folder=$FOLDER"
    echo " done"

    # Wait a moment for sync to start
    sleep 1

    # Show current status
    status=$(curl -s -H "X-API-Key: $APIKEY" "$API/rest/db/status?folder=$FOLDER")
    state=$(echo "$status" | jq -r '.state')
    need=$(echo "$status" | jq -r '.needFiles')
    local_files=$(echo "$status" | jq -r '.localFiles')
    global_files=$(echo "$status" | jq -r '.globalFiles')

    echo "Status: $state | Local: $local_files | Global: $global_files | Need: $need"

    # If there are files needed, wait and show progress
    if [ "$need" -gt 0 ]; then
      echo -n "Syncing"
      for i in {1..30}; do
        sleep 1
        echo -n "."
        status=$(curl -s -H "X-API-Key: $APIKEY" "$API/rest/db/status?folder=$FOLDER")
        need=$(echo "$status" | jq -r '.needFiles')
        if [ "$need" -eq 0 ]; then
          echo " done!"
          local_files=$(echo "$status" | jq -r '.localFiles')
          new_files=$((local_files - initial_local))
          if [ "$new_files" -gt 0 ]; then
            echo "✓ Synced $new_files new file(s)! Total: $local_files"
          else
            echo "✓ Synced! Local files: $local_files"
          fi
          break
        fi
      done
      if [ "$need" -gt 0 ]; then
        echo " still syncing ($need files remaining)"
      fi
    else
      # Check if files were added (sync completed before we checked)
      new_files=$((local_files - initial_local))
      if [ "$new_files" -gt 0 ]; then
        echo "✓ Synced $new_files new file(s)! Total: $local_files"
      else
        echo "✓ Already in sync!"
      fi
    fi
  ''
