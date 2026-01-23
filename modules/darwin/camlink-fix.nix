# Cam Link 4K auto-fix module for nix-darwin
#
# Automatically resets the Elgato Cam Link 4K when it becomes unresponsive
# after sleep/wake cycles by power-cycling its USB port.
#
# Requirements:
# - Cam Link must be connected through a uhubctl-compatible USB hub
#   (e.g., VIA Labs 2109:0813 chipset - common in Anker, Plugable, Amazon Basics hubs)
# - The hub location and port must be configured correctly
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.camlink-fix;

  # Script that checks camera health and resets if needed
  camlinkFixScript = pkgs.writeShellScript "camlink-fix" ''
    set -uo pipefail

    DEVICE_NAME="${cfg.deviceName}"
    HUB_LOCATION="${cfg.usbHub}"
    PORT="${toString cfg.usbPort}"
    TIMEOUT_SECS=3

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
      logger -t camlink-fix "$*"
    }

    notify() {
      osascript -e "display notification \"$1\" with title \"Cam Link Fix\""
    }

    check_camera() {
      # Check if device is in the camera list
      if ! system_profiler SPCameraDataType 2>/dev/null | grep -q "$DEVICE_NAME"; then
        return 1
      fi

      # Try to grab a frame with timeout
      ${pkgs.ffmpeg}/bin/ffmpeg -f avfoundation -video_size 1920x1080 -framerate 59.94 -i "$DEVICE_NAME" -frames:v 1 -f null - >/dev/null 2>&1 &
      local pid=$!

      for i in $(seq 1 $TIMEOUT_SECS); do
        if ! kill -0 "$pid" 2>/dev/null; then
          wait "$pid"
          return $?
        fi
        sleep 1
      done

      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null || true
      return 1
    }

    reset_camera() {
      log "Power cycling USB port $HUB_LOCATION:$PORT..."
      ${pkgs.uhubctl}/bin/uhubctl -l "$HUB_LOCATION" -p "$PORT" -a cycle >/dev/null 2>&1
      sleep 3
    }

    # Main
    log "Checking $DEVICE_NAME..."

    if check_camera; then
      log "OK: Camera is working"
      exit 0
    fi

    log "Camera not responding, attempting reset..."
    ${if cfg.notify then ''notify "Camera not responding, resetting..."'' else ""}
    reset_camera

    if check_camera; then
      log "OK: Camera recovered after reset"
      ${if cfg.notify then ''notify "Camera recovered successfully"'' else ""}
      exit 0
    else
      log "FAIL: Camera still not working after reset"
      ${if cfg.notify then ''notify "Camera reset failed - manual intervention needed"'' else ""}
      exit 1
    fi
  '';

  # Wakeup script called by sleepwatcher
  wakeupScript = pkgs.writeShellScript "camlink-wakeup" ''
    # Give the system a moment to stabilize after wake
    sleep ${toString cfg.wakeDelay}
    ${camlinkFixScript}
  '';
in {
  options.services.camlink-fix = {
    enable = mkEnableOption "Cam Link 4K auto-fix on wake";

    deviceName = mkOption {
      type = types.str;
      default = "Cam Link 4K";
      description = "Name of the camera device as it appears in system_profiler.";
    };

    usbHub = mkOption {
      type = types.str;
      example = "0-2.1.4";
      description = ''
        USB hub location for uhubctl. Find this by running:
        sudo uhubctl | grep -B5 "Cam Link"
      '';
    };

    usbPort = mkOption {
      type = types.int;
      example = 4;
      description = "USB port number on the hub where the Cam Link is connected.";
    };

    user = mkOption {
      type = types.str;
      default = "phinze";
      description = "User account that will run the fix script.";
    };

    notify = mkOption {
      type = types.bool;
      default = true;
      description = "Show macOS notifications when fixing the camera.";
    };

    wakeDelay = mkOption {
      type = types.int;
      default = 5;
      description = "Seconds to wait after wake before checking the camera.";
    };
  };

  config = mkIf cfg.enable {
    # Required packages + manual fix command
    environment.systemPackages = [
      pkgs.ffmpeg
      pkgs.uhubctl
      (pkgs.writeShellScriptBin "camlink-fix" ''
        exec ${camlinkFixScript}
      '')
    ];

    # Sleepwatcher via homebrew (better macOS integration than nixpkgs version)
    homebrew.brews = [
      {
        name = "sleepwatcher";
        start_service = false; # We'll manage our own launchd agent
      }
    ];

    # Sudoers rule for passwordless uhubctl
    security.sudo.extraConfig = ''
      ${cfg.user} ALL=(ALL) NOPASSWD: ${pkgs.uhubctl}/bin/uhubctl
    '';

    # Launchd agent for sleepwatcher
    launchd.user.agents.camlink-sleepwatcher = {
      path = ["/usr/bin" "/bin" "/usr/sbin" "/sbin" "/opt/homebrew/bin"];
      serviceConfig = {
        ProgramArguments = [
          "/opt/homebrew/bin/sleepwatcher"
          "-V"
          "-w"
          "${wakeupScript}"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/camlink-sleepwatcher.out.log";
        StandardErrorPath = "/tmp/camlink-sleepwatcher.err.log";
      };
    };
  };
}
