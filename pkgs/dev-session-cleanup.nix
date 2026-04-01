{
  pkgs,
  gwq,
}:
let
  runtimeDeps =
    with pkgs;
    [
      coreutils
      findutils
      gawk
      git
      ghq
      gnugrep
      gnused
      jq
      procps
      tmux
    ]
    ++ [ gwq ];
in
pkgs.writeShellScriptBin "dev-session-cleanup" ''
  set -uo pipefail

  export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

  # Defaults
  DRY_RUN=false
  PHASE=""
  MAX_IDLE=86400  # 24 hours

  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run|-n)
        DRY_RUN=true
        shift
        ;;
      --phase)
        PHASE="$2"
        shift 2
        ;;
      --max-idle|--claude-max-age)
        MAX_IDLE="$2"
        shift 2
        ;;
      --help|-h)
        echo "Usage: dev-session-cleanup [--dry-run|-n] [--phase liveness|worktrees|claude] [--max-idle SECONDS]"
        echo ""
        echo "Nightly cleanup of stale dev sessions and merged git branches."
        echo ""
        echo "  --dry-run, -n              Show what would be done without acting"
        echo "  --phase liveness|worktrees|claude"
        echo "                             Run only the specified phase"
        echo "  --max-idle SECONDS         Max idle time before reaping (default: 86400 = 24h)"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  # Colors (disabled when not on a terminal)
  if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
  else
    GREEN=""
    YELLOW=""
    BLUE=""
    NC=""
  fi

  log() { echo -e "''${BLUE}[cleanup]''${NC} $*"; }
  log_ok() { echo -e "  ''${GREEN}✓''${NC} $*"; }
  log_warn() { echo -e "  ''${YELLOW}⚠''${NC} $*"; }

  # ─── Phase 1: Build liveness map ─────────────────────────────────────

  NOW=$(date +%s)

  # Map tmux session names to their most recent window_activity across all panes.
  # window_activity tracks when the window last had *output* — not when it was
  # viewed. This tells us whether a session has been producing output recently.
  # (session_activity updates on view, making it useless; window_activity is output-based)
  declare -A session_activity_map
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    session=$(echo "$line" | awk '{print $1}')
    activity=$(echo "$line" | awk '{print $2}')
    if [ -z "''${session_activity_map[$session]+x}" ] || [ "$activity" -gt "''${session_activity_map[$session]}" ]; then
      session_activity_map[$session]=$activity
    fi
  done < <(tmux list-panes -a -F '#{session_name} #{window_activity}' 2>/dev/null)

  # Map tmux pane PIDs to their window's last activity time (for Claude process reaping).
  declare -A pane_activity_map
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ppid=$(echo "$line" | awk '{print $1}')
    pactivity=$(echo "$line" | awk '{print $2}')
    pane_activity_map[$ppid]=$pactivity
  done < <(tmux list-panes -a -F '#{pane_pid} #{window_activity}' 2>/dev/null)

  # Check if a tmux session is active (has recent pane output).
  # Returns 0 (true) if session exists and has activity within MAX_IDLE, 1 otherwise.
  is_session_active() {
    local session_name=$1
    if [ -n "''${session_activity_map[$session_name]+x}" ]; then
      local idle_seconds=$(( NOW - session_activity_map[$session_name] ))
      if [ "$idle_seconds" -lt "$MAX_IDLE" ]; then
        return 0
      fi
    fi
    return 1
  }

  # Get idle seconds for a tmux session. Returns -1 if session not found.
  get_session_idle() {
    local session_name=$1
    if [ -n "''${session_activity_map[$session_name]+x}" ]; then
      echo $(( NOW - session_activity_map[$session_name] ))
    else
      echo -1
    fi
  }

  # Walk up the process tree from a PID to find its tmux pane's last activity time.
  # Returns seconds since last pane activity, or the process age if no pane is found.
  get_pid_idle_seconds() {
    local check_pid=$1
    local fallback_etimes=$2
    while [ "$check_pid" -gt 1 ] 2>/dev/null; do
      if [ -n "''${pane_activity_map[$check_pid]+x}" ]; then
        echo $(( NOW - pane_activity_map[$check_pid] ))
        return
      fi
      check_pid=$(ps -o ppid= -p "$check_pid" 2>/dev/null | tr -d ' ')
    done
    # No tmux pane found (orphan?) — fall back to process age
    echo "$fallback_etimes"
  }

  phase_liveness() {
    log "Phase 1: Building liveness map"
    log "  ''${#session_activity_map[@]} tmux sessions tracked"
    log "  ''${#pane_activity_map[@]} tmux panes tracked"
    log "  Idle threshold: $((MAX_IDLE / 3600))h"
  }

  # ─── Phase 2: Worktree reaping ───────────────────────────────────────

  phase_worktrees() {
    log "Phase 2: Reaping merged branches and stale worktrees"

    local repos_trimmed=0
    local branches_removed=0

    while IFS= read -r repo_path; do
      # Skip if not a main checkout (worktrees have .git as a file)
      if [ ! -d "$repo_path/.git" ]; then
        continue
      fi

      # Determine main branch
      local main_branch="main"
      if ! git -C "$repo_path" rev-parse --verify "$main_branch" >/dev/null 2>&1; then
        main_branch="master"
        if ! git -C "$repo_path" rev-parse --verify "$main_branch" >/dev/null 2>&1; then
          continue  # no main or master, skip
        fi
      fi

      # Quick check: skip repos with no branches beyond main/master (avoids expensive fetch)
      local branch_count
      branch_count=$(git -C "$repo_path" branch | grep -v "^\*" | grep -v "^  $main_branch$" | grep -v "^  master$" | wc -l)
      if [ "$branch_count" -eq 0 ]; then
        continue
      fi

      # Fetch and prune remote tracking branches
      git -C "$repo_path" fetch --prune --quiet 2>/dev/null || true

      # Find merged branches (excluding main/master and current)
      local merged
      merged=$(git -C "$repo_path" branch --merged "$main_branch" \
        | grep -v "^\*" \
        | grep -v "^  $main_branch$" \
        | grep -v "^  master$" \
        || true)

      if [ -z "$merged" ]; then
        continue
      fi

      local repo_name
      repo_name=$(echo "$repo_path" | sed "s|^$HOME/src/||")
      log "Repo: $repo_name"

      # Get gwq status for this repo
      local gwq_status
      gwq_status=$(cd "$repo_path" && gwq status --json 2>/dev/null || echo '{"worktrees":[]}')

      repos_trimmed=$((repos_trimmed + 1))

      while IFS= read -r branch_line; do
        local branch_name has_worktree

        if [[ "$branch_line" =~ ^\+[[:space:]]*(.*) ]]; then
          branch_name="''${BASH_REMATCH[1]}"
          has_worktree=true
        else
          branch_name=$(echo "$branch_line" | xargs)
          has_worktree=false
        fi

        [ -z "$branch_name" ] && continue

        if [ "$has_worktree" = true ]; then
          # Check for uncommitted changes via gwq
          local worktree_info status has_changes
          worktree_info=$(echo "$gwq_status" | jq -r \
            ".worktrees[] | select(.branch == \"$branch_name\") | {status, git_status} | @json" \
            2>/dev/null || echo "")
          has_changes=false

          if [ -n "$worktree_info" ]; then
            status=$(echo "$worktree_info" | jq -r '.status' 2>/dev/null || echo "")
            if [ "$status" != "clean" ] && [ "$status" != "stale" ]; then
              has_changes=true
            elif [ "$status" = "clean" ]; then
              if echo "$worktree_info" | jq -e \
                '.git_status | (.modified > 0 or .added > 0 or .deleted > 0 or .untracked > 0 or .staged > 0 or .conflicts > 0)' \
                >/dev/null 2>&1; then
                has_changes=true
              fi
            fi
          fi

          if [ "$has_changes" = true ]; then
            log_warn "Skipping $branch_name — uncommitted changes"
            continue
          fi

          # Get worktree path to check for active session
          local worktree_path
          worktree_path=$(cd "$repo_path" && gwq get "$branch_name" 2>/dev/null || echo "")

          if [ -n "$worktree_path" ]; then
            # Build tmux session name: ~/worktrees/... with dots→hyphens
            local session_name
            session_name=$(echo "$worktree_path" | sed "s|^$HOME|~|")
            session_name="''${session_name//./-}"

            # Check if session is active before removing
            if is_session_active "$session_name"; then
              local idle_seconds idle_hours
              idle_seconds=$(get_session_idle "$session_name")
              idle_hours=$((idle_seconds / 3600))
              log_warn "Skipping $branch_name — active session (idle ''${idle_hours}h)"
              continue
            fi

            # Session is either absent or idle beyond threshold — tear it down
            if tmux has-session -t "$session_name" 2>/dev/null; then
              if [ "$DRY_RUN" = true ]; then
                log_ok "Would kill tmux session: $session_name"
              else
                tmux kill-session -t "$session_name" 2>/dev/null || true
              fi
            fi

            # Clean up iso resources if present
            if command -v iso &>/dev/null && [ -d "$worktree_path/.iso" ]; then
              if [ "$DRY_RUN" = false ]; then
                (cd "$worktree_path" && iso stop --all-sessions 2>/dev/null) || true
              fi
            fi
          fi

          if [ "$DRY_RUN" = true ]; then
            log_ok "Would remove $branch_name (merged, worktree)"
          else
            (cd "$repo_path" && gwq remove -b "$branch_name" 2>/dev/null) || true
            log_ok "Removed $branch_name"
          fi
        else
          # No worktree — just delete the branch
          if [ "$DRY_RUN" = true ]; then
            log_ok "Would delete $branch_name (merged, no worktree)"
          else
            git -C "$repo_path" branch -d "$branch_name" 2>/dev/null || true
            log_ok "Deleted $branch_name"
          fi
        fi

        branches_removed=$((branches_removed + 1))
      done <<< "$merged"
    done < <(ghq list --full-path)

    log "Phase 2 complete: $branches_removed branches across $repos_trimmed repos"
  }

  # ─── Phase 3: Stale Claude Code reaping ───────────────────────────────

  phase_claude() {
    log "Phase 3: Reaping Claude Code processes idle for more than $((MAX_IDLE / 3600))h"

    local killed=0

    # Find claude-unwrapped processes with their age in seconds
    while IFS= read -r line; do
      [ -z "$line" ] && continue

      local pid etimes
      pid=$(echo "$line" | awk '{print $1}')
      etimes=$(echo "$line" | awk '{print $2}')

      # Check pane activity instead of just process age
      local idle_seconds
      idle_seconds=$(get_pid_idle_seconds "$pid" "$etimes")

      # Skip if recently active
      if [ "$idle_seconds" -lt "$MAX_IDLE" ]; then
        continue
      fi

      local age_hours=$((etimes / 3600))
      local idle_hours=$((idle_seconds / 3600))

      # Get the working directory for context
      local cwd
      cwd=$(readlink -f /proc/$pid/cwd 2>/dev/null || echo "unknown")
      cwd=$(echo "$cwd" | sed "s|^$HOME|~|")

      if [ "$DRY_RUN" = true ]; then
        log_ok "Would kill PID $pid (''${age_hours}h old, idle ''${idle_hours}h, $cwd)"
      else
        kill -TERM "$pid" 2>/dev/null || true
        log_ok "Sent SIGTERM to PID $pid (''${age_hours}h old, idle ''${idle_hours}h, $cwd)"
      fi

      killed=$((killed + 1))
    done < <(ps -eo pid,etimes,args --no-headers | grep 'claude-unwrapped' | grep -v grep | awk '{print $1, $2}')

    # Wait for graceful shutdown, then SIGKILL survivors
    if [ "$killed" -gt 0 ] && [ "$DRY_RUN" = false ]; then
      log "Waiting 10s for graceful shutdown..."
      sleep 10

      # Re-check: only SIGKILL processes that are still idle
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        local pid etimes
        pid=$(echo "$line" | awk '{print $1}')
        etimes=$(echo "$line" | awk '{print $2}')
        local idle_seconds
        idle_seconds=$(get_pid_idle_seconds "$pid" "$etimes")
        if [ "$idle_seconds" -ge "$MAX_IDLE" ]; then
          kill -KILL "$pid" 2>/dev/null || true
          log_warn "Sent SIGKILL to PID $pid"
        fi
      done < <(ps -eo pid,etimes,args --no-headers | grep 'claude-unwrapped' | grep -v grep | awk '{print $1, $2}')
    fi

    log "Phase 3 complete: $killed processes reaped"
  }

  # ─── Main ─────────────────────────────────────────────────────────────

  if [ "$DRY_RUN" = true ]; then
    log "DRY RUN — no changes will be made"
  fi

  # Normalize phase aliases
  case "$PHASE" in
    git-trim) PHASE="worktrees" ;;
  esac

  # Liveness map is always built (other phases depend on it)
  if [ -z "$PHASE" ] || [ "$PHASE" = "liveness" ]; then
    phase_liveness
  fi

  if [ -z "$PHASE" ] || [ "$PHASE" = "worktrees" ]; then
    phase_worktrees || log_warn "Phase 2 (worktrees) encountered errors"
  fi

  if [ -z "$PHASE" ] || [ "$PHASE" = "claude" ]; then
    phase_claude || log_warn "Phase 3 (claude) encountered errors"
  fi

  log "All done."
''
