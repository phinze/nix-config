{ pkgs }:
pkgs.writeShellApplication {
  name = "dev-host-cleanup";
  runtimeInputs = with pkgs; [
    coreutils
    docker-client
    findutils
    gawk
    util-linux
  ];
  text = ''
    set -euo pipefail

    dry_run=false
    min_used_pct=0
    max_age_hours=168 # seven days

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --dry-run|-n)
          dry_run=true
          shift
          ;;
        --if-used-pct)
          min_used_pct="''${2:?--if-used-pct needs a percentage}"
          shift 2
          ;;
        --help|-h)
          echo "usage: dev-host-cleanup [--dry-run|-n] [--if-used-pct PERCENT]"
          exit 0
          ;;
        *)
          echo "dev-host-cleanup: unknown option: $1" >&2
          exit 2
          ;;
      esac
    done

    used_pct() {
      df --output=pcent / | awk 'NR == 2 { gsub(/%/, ""); print $1 }'
    }

    # rig notify is best effort: a missing inbox must not fail the sweep.
    notify() {
      rig notify "$@" >/dev/null 2>&1 || true
    }

    if (( $(used_pct) < min_used_pct )); then
      echo "dev-host-cleanup: / is $(used_pct)% used; below ''${min_used_pct}% pressure threshold"
      $dry_run || notify dismiss dev-host-cleanup/disk-pressure
      exit 0
    fi

    lock_root="''${XDG_RUNTIME_DIR:-/tmp}"
    exec 9>"$lock_root/dev-host-cleanup.lock"
    if ! flock -n 9; then
      echo "dev-host-cleanup: another sweep is already running"
      exit 0
    fi

    if ! docker info >/dev/null 2>&1; then
      echo "dev-host-cleanup: Docker daemon unavailable" >&2
      exit 1
    fi

    run() {
      if $dry_run; then
        printf 'would run:'
        printf ' %q' "$@"
        printf '\n'
      else
        "$@"
      fi
    }

    echo "dev-host-cleanup: pruning unused Docker resources older than seven days"
    run docker container prune --force --filter "until=''${max_age_hours}h"
    run docker image prune --all --force --filter "until=''${max_age_hours}h"
    run docker network prune --force --filter "until=''${max_age_hours}h"
    run docker builder prune --all --force --filter "until=''${max_age_hours}h"

    # Docker volume prune has no age filter. Inspect only dangling (unreferenced)
    # volumes and remove the ones whose creation time is beyond the same cutoff.
    cutoff=$(date --date="$max_age_hours hours ago" +%s)
    while IFS= read -r volume; do
      [[ -n "$volume" ]] || continue
      created=$(docker volume inspect --format '{{.CreatedAt}}' "$volume" 2>/dev/null || true)
      [[ -n "$created" ]] || continue
      created_epoch=$(date --date="$created" +%s 2>/dev/null || true)
      [[ -n "$created_epoch" ]] || continue
      if (( created_epoch <= cutoff )); then
        run docker volume rm "$volume"
      fi
    done < <(docker volume ls --quiet --filter dangling=true)

    echo "dev-host-cleanup: sweep complete"
    df -h /

    # The sweep only reclaims what Docker considers unused. When pressure
    # survives it, say so instead of retrying silently every hour. The usual
    # culprit prune can't touch is a log whose file was deleted while a
    # forgotten process keeps writing it: invisible to du, freed only when the
    # process exits. List those, deduped by inode, so the notice names a PID.
    if (( min_used_pct > 0 )) && (( $(used_pct) >= min_used_pct )); then
      held=$(
        { find /proc/[0-9]*/fd -lname '*(deleted)' 2>/dev/null || true; } \
          | while IFS= read -r fd; do
              read -r inode size < <(stat -L -c '%i %s' "$fd" 2>/dev/null) || continue
              (( size >= 1073741824 )) || continue
              pid=''${fd#/proc/}; pid=''${pid%%/*}
              echo "$inode $((size / 1073741824))G pid $pid ($(cat "/proc/$pid/comm" 2>/dev/null)) $(readlink "$fd")"
            done \
          | sort -u -k1,1 | cut -d' ' -f2-
      )
      body="/ is still $(used_pct)% used after pruning Docker resources older than seven days."
      if [[ -n "$held" ]]; then
        body+=$'\n\nDeleted files still held open (freed when the process exits):\n'"$held"
      fi
      echo "$body"
      $dry_run || notify post --source dev-host-cleanup --key disk-pressure \
        --level warn --title "$(uname -n) disk at $(used_pct)%" --body "$body"
    fi
  '';
}
