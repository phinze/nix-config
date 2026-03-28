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
      ExecStart = "${pkgs.dev-session-cleanup}/bin/dev-session-cleanup";
      # tmux needs TMUX_TMPDIR to find the user's server socket,
      # otherwise window_activity checks fail and all sessions look idle
      Environment = "TMUX_TMPDIR=%t";
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
