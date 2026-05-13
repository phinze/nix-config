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
      gnugrep
      gh # git credential helper shells out to `gh auth git-credential`
    ];
    text = ''
      cd "${config.home.homeDirectory}/src/github.com/phinze/memex"

      # Bail if a prior tick left git in a paused state. Continuing on top of
      # a stuck rebase/merge is exactly how sync commits used to bake conflict
      # markers into their content and propagate the failure indefinitely.
      if [[ -d .git/rebase-merge || -d .git/rebase-apply || -e .git/MERGE_HEAD ]]; then
        echo "memex-autocommit: rebase or merge in progress, skipping" >&2
        exit 1
      fi

      # Bail if the working tree contains stale conflict markers, for the
      # same reason. A manual sweep is required to recover.
      if grep -rln '^<<<<<<< HEAD' --include='*.md' . >/dev/null 2>&1; then
        echo "memex-autocommit: conflict markers in working tree, skipping" >&2
        exit 1
      fi

      # Reconcile with remote BEFORE committing so local sync commits never
      # stack up against a stale base. --autostash handles dirty working tree.
      # Tolerate fetch failure (offline is OK; we'll still try to rebase
      # against the locally-known origin/main).
      git fetch --quiet || true
      if ! git rebase --autostash origin/main; then
        echo "memex-autocommit: rebase failed, aborting" >&2
        git rebase --abort
        exit 1
      fi

      git add -A
      if ! git diff --cached --quiet; then
        git commit --no-gpg-sign -m "Sync: $(TZ=America/Chicago date '+%Y-%m-%d %H:%M')"
      fi

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
