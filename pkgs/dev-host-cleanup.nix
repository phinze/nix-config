{ pkgs }:
pkgs.writeShellApplication {
  name = "dev-host-cleanup";
  runtimeInputs = with pkgs; [
    coreutils
    docker-client
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

    used_pct=$(df --output=pcent / | awk 'NR == 2 { gsub(/%/, ""); print $1 }')
    if (( used_pct < min_used_pct )); then
      echo "dev-host-cleanup: / is ''${used_pct}% used; below ''${min_used_pct}% pressure threshold"
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
  '';
}
