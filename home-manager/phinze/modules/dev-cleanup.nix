{
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [
    pkgs.dev-host-cleanup
    pkgs.dev-session-cleanup
  ];

  # Fast repair loop for the failure mode that filled foxtrotbase: tmux can
  # drop a session while one of its systemd pane scopes keeps a daemon alive.
  # Rig owns the RIG_ID accounting and its durable teardown jobs; this timer
  # retries those jobs and stops scopes whose manifest is already gone.
  systemd.user.services.rig-runtime-cleanup = {
    Unit.Description = "Retry Rig cleanup and stop escaped pane scopes";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.rig} reap --runtime-only";
      Environment = [
        "TMUX_TMPDIR=%t"
        "PATH=%h/bin:/etc/profiles/per-user/%u/bin:%h/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
    };
  };

  systemd.user.timers.rig-runtime-cleanup = {
    Unit.Description = "Repair escaped Rig runtime resources hourly";
    Timer = {
      OnBootSec = "10m";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.dev-session-cleanup = {
    Unit = {
      Description = "Cleanup stale dev sessions and merged git branches";
    };
    Service = {
      Type = "oneshot";
      # rig reap handles the new-style workspaces: every rig has a
      # manifest and a single teardown path, so cleanup there is
      # enumeration plus policy. The legacy script then sweeps what rig
      # doesn't own — git worktrees, old-layout jj workspaces (ages out
      # with those sessions), and stale claude processes.
      ExecStart = [
        "${lib.getExe pkgs.rig} reap"
        "${pkgs.dev-session-cleanup}/bin/dev-session-cleanup"
      ];
      Environment = [
        # tmux needs TMUX_TMPDIR to find the user's server socket,
        # otherwise session checks fail and all sessions look absent
        "TMUX_TMPDIR=%t"
        # rig shells out to jj, tmux, and iso. Resolving them through the
        # user profile (plus ~/bin, where iso lives) keeps the service on
        # the exact tool versions interactive sessions use, instead of
        # bundling pinned copies the way the legacy script does for jj.
        "PATH=%h/bin:/etc/profiles/per-user/%u/bin:%h/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
    };
  };

  systemd.user.timers.dev-session-cleanup = {
    Unit = {
      Description = "Run dev session cleanup nightly";
    };
    Timer = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.dev-host-cleanup = {
    Unit.Description = "Prune seven-day-old unused Docker resources";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.dev-host-cleanup}";
    };
  };

  systemd.user.timers.dev-host-cleanup = {
    Unit.Description = "Run host development storage cleanup daily";
    Timer = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # The daily sweep keeps normal churn bounded. This second trigger is the
  # seatbelt: once / reaches 80%, run the same conservative seven-day policy
  # within an hour instead of waiting for the next night.
  systemd.user.services.dev-disk-pressure-cleanup = {
    Unit.Description = "Prune old development storage under disk pressure";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.dev-host-cleanup} --if-used-pct 80";
    };
  };

  systemd.user.timers.dev-disk-pressure-cleanup = {
    Unit.Description = "Check development disk pressure hourly";
    Timer = {
      OnBootSec = "10m";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
