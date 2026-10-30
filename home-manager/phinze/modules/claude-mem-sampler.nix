{
  pkgs,
  lib,
  ...
}:
let
  # One TSV row per live claude process every five minutes, plus a "host" row
  # with available memory and swap, so a session's growth curve and the box's
  # headroom can be read back after the fact. Built after foxtrotbase wedged on
  # 2026-10-30 with sessions at 7-9G each and nothing recorded about how fast
  # they got there.
  claude-mem-sample = pkgs.writeShellApplication {
    name = "claude-mem-sample";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.procps
    ];
    text = ''
      dir="''${XDG_STATE_HOME:-$HOME/.local/state}/claude-mem"
      out="$dir/samples.tsv"
      mkdir -p "$dir"
      if [ -f "$out" ] && [ "$(stat -c %s "$out")" -gt 50000000 ]; then
        mv "$out" "$out.1"
      fi
      if [ ! -f "$out" ]; then
        printf 'time\tkind\tpid\tstarted\trss_kb\tswap_kb\trig\tcgroup\n' > "$out"
      fi

      now=$(date -Iseconds)
      awk -v now="$now" '
        /^MemAvailable:/ { avail = $2 }
        /^SwapTotal:/ { st = $2 }
        /^SwapFree:/ { sf = $2 }
        END { printf "%s\thost\t-\t-\t%d\t%d\t-\t-\n", now, avail, st - sf }
      ' /proc/meminfo >> "$out"

      # The node process is .claude-unwrapped, truncated to 15 chars in comm.
      ps -eo pid=,comm= | awk '$2 == ".claude-unwrapp" { print $1 }' | while read -r pid; do
        status=$(cat "/proc/$pid/status" 2>/dev/null) || continue
        rss=$(awk '/^VmRSS:/ { print $2 }' <<< "$status")
        swap=$(awk '/^VmSwap:/ { print $2 }' <<< "$status")
        started=$(ps -o lstart= -p "$pid" | xargs -r -I{} date -d {} -Iseconds)
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || true)
        rig=adhoc
        case "$cwd" in
          "$HOME"/workspaces/*)
            rig=''${cwd#"$HOME"/workspaces/}
            rig=''${rig%%/*}
            ;;
        esac
        cgroup=$(cut -d: -f3 "/proc/$pid/cgroup" 2>/dev/null || true)
        printf '%s\tclaude\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$now" "$pid" "$started" "''${rss:-0}" "''${swap:-0}" "$rig" "$cgroup" >> "$out"
      done
    '';
  };
in
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = [ claude-mem-sample ];

  systemd.user.services.claude-mem-sample = {
    Unit.Description = "Record memory use of live Claude sessions";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe claude-mem-sample;
    };
  };

  systemd.user.timers.claude-mem-sample = {
    Unit.Description = "Record memory use of live Claude sessions every five minutes";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
