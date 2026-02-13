# Step 1: Resolve PR details (owner, repo, number)
set -l owner
set -l repo
set -l pr_number

if test (count $argv) -eq 0
    # No args: interactive fzf picker of PRs requesting my review
    set -l selection (gh search prs --review-requested=@me --state=open \
        --json repository,number,title,url \
        --jq '.[] | "\(.repository.nameWithOwner)\t#\(.number)\t\(.title)\t\(.url)"' \
        | fzf --height=40% --reverse --with-nth=1,2,3 --delimiter='\t' --prompt="Review PR: ")
    if test -z "$selection"
        return 0
    end
    set -l nwo (echo "$selection" | cut -f1)
    set owner (string split '/' "$nwo")[1]
    set repo (string split '/' "$nwo")[2]
    set pr_number (echo "$selection" | cut -f2 | string replace '#' '')
else
    # Parse PR URL
    set -l match (string match -r 'github\.com/([^/]+)/([^/]+)/pull/([0-9]+)' $argv[1])
    if test -z "$match"
        echo "Usage: review [https://github.com/OWNER/REPO/pull/NUMBER]"
        return 1
    end
    set owner $match[2]
    set repo $match[3]
    set pr_number $match[4]
end

# Step 2: Get head branch name
set -l branch_name (gh pr view $pr_number -R "$owner/$repo" --json headRefName --jq '.headRefName')
if test -z "$branch_name"
    echo "Could not get branch name for $owner/$repo#$pr_number"
    return 1
end

# Step 3: Ensure repo is cloned locally
set -l ghq_root (ghq root)
set -l repo_path "$ghq_root/github.com/$owner/$repo"
if not test -d "$repo_path"
    command ghq get "github.com/$owner/$repo"
    if test $status -ne 0
        echo "Failed to clone $owner/$repo"
        return 1
    end
end

# Step 4: Create worktree via gwq
set -l original_dir (pwd)
cd "$repo_path"
git fetch origin "$branch_name" --quiet 2>/dev/null
set -l worktree_path (gwq get "$branch_name" 2>/dev/null)

if test -z "$worktree_path"
    gwq add "$branch_name" 2>/dev/null
    if test $status -ne 0
        cd "$original_dir"
        echo "Failed to create worktree for $branch_name"
        return 1
    end
    set worktree_path (gwq get "$branch_name" 2>/dev/null)
end
cd "$original_dir"

# Step 5: Compute tmux session name (matches session-wizard --full-path)
set -l session_name (string replace "$HOME" "~" "$worktree_path")
set session_name (string replace -a " " "-" $session_name)
set session_name (string replace -a "." "-" $session_name)
set session_name (string replace -a ":" "-" $session_name)
set session_name (string lower $session_name)

# Step 6: Create tmux session if it doesn't exist
set -l is_new_session 0
if not tmux has-session -t "$session_name" 2>/dev/null
    tmux new-session -d -s "$session_name" -c "$worktree_path"
    set is_new_session 1
end

# Step 7: Launch Claude only for new sessions
if test $is_new_session -eq 1
    tmux send-keys -t "$session_name" "claude --dangerously-skip-permissions '/review-pr $pr_number'" Enter
end

# Step 8: Switch to session
if test -n "$TMUX"
    tmux switch-client -t "$session_name"
else
    tmux attach -t "$session_name"
end
