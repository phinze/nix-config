{
  pkgs,
  gwq,
}: let
  runtimeDeps = with pkgs;
    [
      git
      jq
      tmux
    ]
    ++ [gwq];
in
  pkgs.writeShellScriptBin "git-trim" ''
    #!/usr/bin/env bash
    set -euo pipefail

    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

    # Parse command line options
    DRY_RUN=false
    INTERACTIVE=false
    while [[ $# -gt 0 ]]; do
      case $1 in
        --dry-run|-n)
          DRY_RUN=true
          shift
          ;;
        --interactive|-i)
          INTERACTIVE=true
          shift
          ;;
        --help|-h)
          echo "Usage: git trim [--dry-run|-n] [--interactive|-i]"
          echo "  --dry-run, -n       Show what would be done without actually doing it"
          echo "  --interactive, -i   Prompt before removing worktrees with uncommitted changes"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          echo "Usage: git trim [--dry-run|-n] [--interactive|-i]"
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
      read -p "Continue anyway? (y/N) " -n 1 -r </dev/tty
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

    # Function to clean up iso containers, volumes, and networks for a worktree
    cleanup_iso_resources() {
      local worktree_path="$1"

      # Check if iso command is available
      if ! command -v iso &> /dev/null; then
        return 0
      fi

      # Check if the worktree has a .iso directory
      if [ ! -d "$worktree_path/.iso" ]; then
        return 0
      fi

      # Run iso stop --all-sessions from within the worktree to clean up all sessions
      if [ "$DRY_RUN" = true ]; then
        echo "  Would run: (cd $worktree_path && iso stop --all-sessions)"
      else
        echo "  Stopping iso sessions in worktree"
        (cd "$worktree_path" && iso stop --all-sessions 2>/dev/null) || true
      fi
    }

    # Process each merged branch
    while IFS= read -r branch_line; do
      # Check if branch has a working tree (indicated by + prefix from git branch --merged)
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
        is_stale=false

        # Parse JSON to check if this branch's working tree has changes or is stale
        # Check for any non-zero values in git_status (modified, added, deleted, untracked, staged, conflicts)
        # Also check if status is "stale" or "clean" (both are safe to remove)
        worktree_info=$(echo "$GWQ_STATUS" | jq -r ".worktrees[] | select(.branch == \"$branch_name\") | {status, git_status} | @json" 2>/dev/null || echo "")

        if [ -n "$worktree_info" ]; then
          status=$(echo "$worktree_info" | jq -r '.status' 2>/dev/null || echo "")

          # Check if status is "stale"
          if [ "$status" = "stale" ]; then
            is_stale=true
          # Check if status is not "clean" and not "stale" (meaning it has changes)
          elif [ "$status" != "clean" ]; then
            has_changes=true
          else
            # For "clean" status, also verify no changes in git_status
            if echo "$worktree_info" | jq -e '.git_status | (.modified > 0 or .added > 0 or .deleted > 0 or .untracked > 0 or .staged > 0 or .conflicts > 0)' >/dev/null 2>&1; then
              has_changes=true
            fi
          fi
        fi

        if [ "$has_changes" = true ]; then
          echo -e "''${YELLOW}⚠''${NC}  Skipping $branch_name - working tree has uncommitted changes"

          # If interactive mode, show diff and ask to override
          if [ "$INTERACTIVE" = true ]; then
            # Get the worktree path to show diff
            worktree_path=$(gwq get "$branch_name" 2>/dev/null || echo "")

            if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
              echo ""
              echo "Outstanding changes:"
              echo "---"
              # Show git status and diff in the worktree
              (cd "$worktree_path" && git status --short)
              echo ""
              (cd "$worktree_path" && git diff HEAD)
              echo "---"
              echo ""

              # Prompt to override (default to no)
              read -p "Remove anyway? (y/N) " -n 1 -r </dev/tty
              echo

              if [[ $REPLY =~ ^[Yy]$ ]]; then
                # User wants to remove despite changes
                echo -e "''${GREEN}✓''${NC}  Removing $branch_name (forced removal)"

                # Get the worktree path before removing it (already have it)
                # Kill tmux session if it exists
                kill_tmux_session "$worktree_path"

                # Clean up iso resources
                cleanup_iso_resources "$worktree_path"

                # Remove the worktree and branch with --force since user confirmed
                if [ "$DRY_RUN" = true ]; then
                  echo "  Would run: gwq remove -b --force $branch_name"
                else
                  gwq remove -b --force "$branch_name"
                fi
              else
                echo "Skipped."
              fi
            fi
          fi
        else
          status_msg=""
          if [ "$is_stale" = true ]; then
            status_msg="merged, working tree stale"
          else
            status_msg="merged, working tree clean"
          fi

          if [ "$DRY_RUN" = true ]; then
            echo -e "''${GREEN}✓''${NC}  Would remove $branch_name ($status_msg)"
          else
            echo -e "''${GREEN}✓''${NC}  Removing $branch_name ($status_msg)"
          fi

          # Get the worktree path before removing it
          worktree_path=$(gwq get "$branch_name" 2>/dev/null || echo "")

          # Kill tmux session if it exists
          if [ -n "$worktree_path" ]; then
            kill_tmux_session "$worktree_path"
          fi

          # Clean up iso resources if worktree exists
          if [ -n "$worktree_path" ]; then
            cleanup_iso_resources "$worktree_path"
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
