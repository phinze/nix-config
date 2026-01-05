# Shutdown safety module for VMs with NBD devices
#
# Provides guaranteed reboot within 3 minutes even when processes are stuck
# in uninterruptible sleep (e.g., waiting on disconnected NBD devices).
#
# Features:
# - systemd hardware watchdog: forces reboot after 3 minutes of hang
# - Reduced service stop timeout: 30 seconds instead of 90s default
# - SysRq enabled: emergency keyboard shortcuts for sync/reboot
# - NBD disconnect service: proactively disconnects NBD devices early in shutdown
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Hardware watchdog - forces reboot if system hangs during shutdown
  # This is the ultimate backstop that guarantees reboot within 3 minutes
  systemd.watchdog = {
    # Time before watchdog forces a reboot during shutdown/reboot
    rebootTime = "3min";
    # Runtime watchdog disabled (would reboot on any system hang, not just shutdown)
    # runtimeTime = "0";
  };

  # Reduce default service stop timeout
  # Services get 30 seconds to stop gracefully before SIGKILL
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';

  # Enable SysRq keys for emergency recovery
  # Value 1 = enable all SysRq functions
  # This allows Alt+SysRq+B (reboot), Alt+SysRq+S (sync), etc.
  boot.kernel.sysctl."kernel.sysrq" = 1;

  # NBD disconnect service - runs early during shutdown to cleanly disconnect
  # NBD devices before other services (like Docker) try to unmount them
  systemd.services.nbd-disconnect = {
    description = "Disconnect NBD devices on shutdown";
    documentation = ["man:nbd-client(8)"];

    # Start early, stay resident, run disconnect on stop
    wantedBy = ["multi-user.target"];

    # Run disconnect BEFORE most services stop
    # This ordering ensures NBD devices are disconnected while we still have
    # a functioning system, rather than fighting with hung processes later
    before = [
      "shutdown.target"
      "reboot.target"
      "halt.target"
      "poweroff.target"
      "docker.service"
      "containerd.service"
    ];

    # Don't pull in default dependencies - we want explicit control
    unitConfig = {
      DefaultDependencies = false;
      # Ensure this runs during shutdown
      RefuseManualStop = false;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # Start is a no-op
      ExecStart = "${pkgs.coreutils}/bin/true";

      # Stop disconnects all NBD devices
      # -d flag disconnects, returns 0 even if device wasn't connected
      ExecStop = pkgs.writeShellScript "nbd-disconnect-all" ''
        echo "Disconnecting NBD devices..."
        for dev in /dev/nbd*; do
          if [ -b "$dev" ]; then
            echo "Disconnecting $dev"
            ${pkgs.nbd}/bin/nbd-client -d "$dev" 2>/dev/null || true
          fi
        done
        echo "NBD disconnect complete"
      '';

      # Give it time to disconnect all devices
      TimeoutStopSec = "20s";
    };
  };
}
