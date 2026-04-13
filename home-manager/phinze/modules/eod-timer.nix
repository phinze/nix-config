{
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  systemd.user.services.eod-summary = {
    Unit = {
      Description = "Generate end-of-day memex summary via Claude Code";
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "%h/src/github.com/phinze/memex";
      ExecStart = "${pkgs.claude-code}/bin/claude -p /eod --allowedTools '*' --dangerously-skip-permissions";
      Environment = [
        "TMUX_TMPDIR=%t"
        "SHELL=${pkgs.bash}/bin/bash"
      ];
      TimeoutStartSec = "5min";
    };
  };

  systemd.user.timers.eod-summary = {
    Unit = {
      Description = "Run end-of-day memex summary at 7pm";
    };
    Timer = {
      OnCalendar = "*-*-* 19:00:00";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
