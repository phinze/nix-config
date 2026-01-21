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

    # Stay resident, run disconnect on stop
    wantedBy = ["multi-user.target"];

    # ORDERING FOR STOP (which is what matters here):
    # systemd stops services in REVERSE start order.
    # We want NBD disconnect to happen BEFORE docker/containerd stop.
    # Therefore we must START this service AFTER docker/containerd.
    after = [
      "docker.service"
      "containerd.service"
    ];

    # Stop this service when shutdown begins, before shutdown.target completes
    conflicts = ["shutdown.target"];
    before = ["shutdown.target"];

    unitConfig = {
      DefaultDependencies = false;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # Start is a no-op
      ExecStart = "${pkgs.coreutils}/bin/true";

      # Stop unmounts NBD filesystems and disconnects NBD devices
      ExecStop = pkgs.writeShellScript "nbd-disconnect-all" ''
        set +e  # Don't exit on errors

        echo "=== NBD Shutdown Cleanup ==="

        # Step 1: Find and kill processes using NBD mounts
        echo "Killing processes using NBD devices..."
        for dev in /dev/nbd*; do
          if [ -b "$dev" ]; then
            # Kill any processes using this device or its partitions
            ${pkgs.util-linux}/bin/fuser -km "$dev" 2>/dev/null || true
            for part in "$dev"p*; do
              [ -b "$part" ] && ${pkgs.util-linux}/bin/fuser -km "$part" 2>/dev/null || true
            done
          fi
        done

        # Step 2: Unmount NBD-backed filesystems
        echo "Unmounting NBD filesystems..."
        for dev in /dev/nbd*; do
          if [ -b "$dev" ]; then
            # Check for mounts on the device or its partitions
            for mnt in $(${pkgs.util-linux}/bin/findmnt -rno TARGET -S "$dev" 2>/dev/null); do
              echo "Unmounting $mnt (lazy)..."
              ${pkgs.util-linux}/bin/umount -l "$mnt" 2>/dev/null || true
            done
            for part in "$dev"p*; do
              if [ -b "$part" ]; then
                for mnt in $(${pkgs.util-linux}/bin/findmnt -rno TARGET -S "$part" 2>/dev/null); do
                  echo "Unmounting $mnt (lazy)..."
                  ${pkgs.util-linux}/bin/umount -l "$mnt" 2>/dev/null || true
                done
              fi
            done
          fi
        done

        # Brief pause for unmounts to process
        sleep 1

        # Step 3: Disconnect NBD devices
        echo "Disconnecting NBD devices..."
        for dev in /dev/nbd*; do
          if [ -b "$dev" ]; then
            echo "Disconnecting $dev"
            ${pkgs.nbd}/bin/nbd-client -d "$dev" 2>/dev/null || true
          fi
        done

        echo "=== NBD Shutdown Cleanup Complete ==="
      '';

      # Give it time for kill, unmount, and disconnect
      TimeoutStopSec = "30s";
    };
  };
}
