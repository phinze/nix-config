{
  pkgs,
  lib,
  config,
  nodeConfig ? { },
  ...
}:
let
  memex-autocommit = pkgs.writeShellApplication {
    name = "memex-autocommit";
    runtimeInputs = with pkgs; [
      git
      coreutils
    ];
    text = ''
      cd "${config.home.homeDirectory}/src/github.com/phinze/memex"

      git add -A
      if ! git diff --cached --quiet; then
        git commit --no-gpg-sign -m "Sync: $(TZ=America/Chicago date '+%Y-%m-%d %H:%M')"
      fi
      git pull --rebase
      git push
    '';
  };
in
lib.mkIf (nodeConfig.isMemexHost or false) (lib.mkMerge [
  { home.packages = [ memex-autocommit ]; }

  (lib.mkIf pkgs.stdenv.isLinux {
    systemd.user.services.memex-autocommit = {
      Unit.Description = "Commit and push memex changes";
      Service = {
        Type = "oneshot";
        ExecStart = "${memex-autocommit}/bin/memex-autocommit";
      };
    };
    systemd.user.timers.memex-autocommit = {
      Unit.Description = "Hourly memex auto-commit with jitter";
      Timer = {
        OnCalendar = "hourly";
        RandomizedDelaySec = "15min";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  })

  (lib.mkIf pkgs.stdenv.isDarwin {
    launchd.agents.memex-autocommit = {
      enable = true;
      config = {
        ProgramArguments = [ "${memex-autocommit}/bin/memex-autocommit" ];
        StartCalendarInterval = [ { Minute = 30; } ];
        StandardOutPath = "/tmp/memex-autocommit.out.log";
        StandardErrorPath = "/tmp/memex-autocommit.err.log";
      };
    };
  })
])
