{pkgs}: let
  runtimeDeps = with pkgs; [
    git
    gwq
    jq
    tmux
  ];
in
  pkgs.writeShellScriptBin "git-trim" ''
    #!/usr/bin/env bash
    set -euo pipefail

    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

    # Parse command line options
    DRY_RUN=false
    while [[ $# -gt 0 ]]; do
      case $1 in
        --dry-run|-n)
          DRY_RUN=true
          shift
          ;;
        --help|-h)
          echo "Usage: git trim [--dry-run|-n]"
          echo "  --dry-run, -n  Show what would be done without actually doing it"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          echo "Usage: git trim [--dry-run|-n]"
          exit 1
          ;;
      esac
    done

    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    # Get the main branch (usually main or master)
    MAIN_BRANCH="main"
    if ! git rev-parse --verify "$MAIN_BRANCH" >/dev/null 2>&1; then
      MAIN_BRANCH="master"
    fi

    # Safety check: ensure we're in the main working tree, not a worktree
    if [ -f ".git" ]; then
      # .git is a file in worktrees, pointing to the real git directory
      echo -e "''${RED}Error:''${NC} This command must be run from the main repository checkout, not from a worktree."
      echo "Please switch to the main repository directory and try again."
      exit 1
    fi

    # Additional check: ensure we're on the main branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$MAIN_BRANCH" ]; then
      echo -e "''${YELLOW}Warning:''${NC} You are on branch '$current_branch', not '$MAIN_BRANCH'."
      echo "It's recommended to run this command from the main branch."
      read -p "Continue anyway? (y/N) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
      fi
    fi

    if [ "$DRY_RUN" = true ]; then
      echo "DRY RUN: Checking for branches merged to $MAIN_BRANCH..."
    else
      echo "Checking for branches merged to $MAIN_BRANCH..."
    fi

    # Get list of merged branches (excluding current branch and main/master)
    MERGED_BRANCHES=$(git branch --merged "$MAIN_BRANCH" | grep -v "^\*" | grep -v "^  $MAIN_BRANCH$" | grep -v "^  master$" || true)

    if [ -z "$MERGED_BRANCHES" ]; then
      echo "No merged branches found to clean up."
      exit 0
    fi

    # Get gwq status to check for working trees with changes
    GWQ_STATUS=$(gwq status --json 2>/dev/null || echo '{"worktrees":[]}')

    # Function to kill tmux session if it exists
    kill_tmux_session() {
      local worktree_path="$1"
      local home_dir="$HOME"

      # Convert absolute path to relative path with ~ prefix
      # e.g., /home/phinze/src/github.com/foo/bar -> ~/src/github.com/foo/bar
      # Use sed for the substitution since bash parameter expansion might have issues in Nix strings
      local session_name=$(echo "$worktree_path" | sed "s|^$home_dir|~|")

      # Replace dots with hyphens in session name (tmux doesn't allow dots)
      session_name="''${session_name//./-}"

      if tmux has-session -t "$session_name" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
          echo "  Would kill tmux session: $session_name"
        else
          echo "  Killing tmux session: $session_name"
          tmux kill-session -t "$session_name"
        fi
      fi
    }

    # Process each merged branch
    while IFS= read -r branch_line; do
      # Check if branch has a working tree (indicated by + prefix)
      if [[ "$branch_line" =~ ^\+[[:space:]]*(.*) ]]; then
        branch_name="''${BASH_REMATCH[1]}"
        has_worktree=true
      else
        # Trim leading/trailing whitespace
        branch_name=$(echo "$branch_line" | xargs)
        has_worktree=false
      fi

      if [ -z "$branch_name" ]; then
        continue
      fi

      if [ "$has_worktree" = true ]; then
        # Check if working tree has changes using gwq status
        has_changes=false

        # Parse JSON to check if this branch's working tree has changes
        # Check for any non-zero values in git_status (modified, added, deleted, untracked, staged, conflicts)
        # or if status is not "clean"
        if echo "$GWQ_STATUS" | jq -e ".worktrees[] | select(.branch == \"$branch_name\" and (.status != \"clean\" or .git_status.modified > 0 or .git_status.added > 0 or .git_status.deleted > 0 or .git_status.untracked > 0 or .git_status.staged > 0 or .git_status.conflicts > 0))" >/dev/null 2>&1; then
          has_changes=true
        fi

        if [ "$has_changes" = true ]; then
          echo -e "''${YELLOW}⚠''${NC}  Skipping $branch_name - working tree has uncommitted changes"
        else
          if [ "$DRY_RUN" = true ]; then
            echo -e "''${GREEN}✓''${NC}  Would remove $branch_name (merged, working tree clean)"
          else
            echo -e "''${GREEN}✓''${NC}  Removing $branch_name (merged, working tree clean)"
          fi

          # Get the worktree path before removing it
          worktree_path=$(gwq get "$branch_name" 2>/dev/null || echo "")

          # Kill tmux session if it exists
          if [ -n "$worktree_path" ]; then
            kill_tmux_session "$worktree_path"
          fi

          # Remove the worktree and branch
          if [ "$DRY_RUN" = true ]; then
            echo "  Would run: gwq remove -b $branch_name"
          else
            gwq remove -b "$branch_name"
          fi
        fi
      else
        # No working tree, safe to delete
        if [ "$DRY_RUN" = true ]; then
          echo -e "''${GREEN}✓''${NC}  Would delete $branch_name (merged, no working tree)"
          echo "  Would run: git branch -d $branch_name"
        else
          echo -e "''${GREEN}✓''${NC}  Deleting $branch_name (merged, no working tree)"
          git branch -d "$branch_name"
        fi
      fi
    done <<< "$MERGED_BRANCHES"

    echo "Branch cleanup complete!"
  ''
