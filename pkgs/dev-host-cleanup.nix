{ pkgs }:
pkgs.writeShellApplication {
  name = "dev-host-cleanup";
  runtimeInputs = with pkgs; [
    coreutils
    docker-client
    findutils
    gawk
    gnugrep
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

    # goimports writes a fresh ~50M module index and never removes old ones.
    # When foxtrotbase last filled up, 97 of its 104 indexes were stale.
    goimports_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/goimports"
    if [[ -d "$goimports_cache" ]]; then
      echo "dev-host-cleanup: pruning goimports indexes untouched for seven days"
      while IFS= read -r -d "" index; do
        run rm -rf "$index"
      done < <(find "$goimports_cache" -mindepth 1 -maxdepth 1 -mtime +7 -print0)
    fi

    under_pressure() {
      (( min_used_pct > 0 )) && (( $(used_pct) >= min_used_pct ))
    }

    # Dead paths only. Generations and live gcroots stay, so this takes what
    # the weekly nh-clean would, just sooner.
    if under_pressure && command -v nix-store >/dev/null; then
      echo "dev-host-cleanup: collecting dead Nix store paths"
      run nix-store --gc
    fi

    # Go never trims its module cache. Under pressure, drop the module
    # versions that no go.sum in a current checkout references. Atime can't
    # stand in for "unused" here: the gopls index reads the whole cache daily.
    gomodcache="$HOME/go/pkg/mod"
    if under_pressure && [[ -d "$gomodcache" ]]; then
      echo "dev-host-cleanup: pruning Go module versions no checkout references"
      refs=$(mktemp)
      trap 'rm -f "$refs"' EXIT
      # The cache spells uppercase letters as !lowercase. A go.sum can vanish
      # mid-scan when a rig is torn down; that must not abort the sweep
      # before the pressure notice.
      { find "$HOME/workspaces" "$HOME/src" "$HOME/worktrees" \
          \( -name .git -o -name .jj -o -name node_modules -o -name .direnv \) -prune \
          -o -name go.sum -type f -print0 2>/dev/null || true; } \
        | { xargs -0 -r cat 2>/dev/null || true; } \
        | awk '{
            v = $2; sub(/\/go\.mod$/, "", v); e = ""
            for (i = 1; i <= length($1); i++) {
              c = substr($1, i, 1); e = e (c ~ /[A-Z]/ ? "!" tolower(c) : c)
            }
            print e "@" v
          }' \
        | sort -u > "$refs"
      # An empty list would mean every version looks unreferenced.
      if [[ -s "$refs" ]]; then
        while IFS= read -r -d "" dir; do
          mod=''${dir#"$gomodcache"/}
          grep -qxF -- "$mod" "$refs" && continue
          run chmod -R u+w "$dir"
          run rm -rf "$dir"
          run rm -f "$gomodcache/cache/download/''${mod%@*}/@v/''${mod##*@}".{zip,ziphash}
        done < <(find "$gomodcache" -path "$gomodcache/cache" -prune -o -type d -name '*@*' -prune -print0)
      fi
    fi

    echo "dev-host-cleanup: sweep complete"
    df -h /

    # The sweep only reclaims what Docker considers unused. When pressure
    # survives it, say so instead of retrying silently every hour. The usual
    # culprit prune can't touch is a log whose file was deleted while a
    # forgotten process keeps writing it: invisible to du, freed only when the
    # process exits. List those, deduped by inode, so the notice names a PID.
    if under_pressure; then
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
      body="/ is still $(used_pct)% used after pruning old Docker resources, dead Nix paths and unreferenced Go modules."
      if [[ -n "$held" ]]; then
        body+=$'\n\nDeleted files still held open (freed when the process exits):\n'"$held"
      fi
      echo "$body"
      $dry_run || notify post --source dev-host-cleanup --key disk-pressure \
        --level warn --title "$(uname -n) disk at $(used_pct)%" --body "$body"
    fi
  '';
}
