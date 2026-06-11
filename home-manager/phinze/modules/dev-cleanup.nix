{
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [ pkgs.dev-session-cleanup ];

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
}
