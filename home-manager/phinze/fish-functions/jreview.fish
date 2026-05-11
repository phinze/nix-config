# jj-flavored review: same shape as `review`, but uses jj workspaces under
# ~/workspaces/... instead of git worktrees. Main repo is auto-colocated.

# Step 1: Resolve PR details (owner, repo, number)
set -l owner
set -l repo
set -l pr_number

if test (count $argv) -eq 0
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
    set -l match (string match -r 'github\.com/([^/]+)/([^/]+)/pull/([0-9]+)' $argv[1])
    if test -z "$match"
        echo "Usage: jreview [https://github.com/OWNER/REPO/pull/NUMBER]"
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

# Step 3: Ensure main repo is cloned locally via ghq
set -l ghq_root (ghq root)
set -l main_repo "$ghq_root/github.com/$owner/$repo"
if not test -d "$main_repo"
    command ghq get "github.com/$owner/$repo"
    if test $status -ne 0
        echo "Failed to clone $owner/$repo"
        return 1
    end
end

# Step 4: Ensure the main repo is colocated with jj
if not test -d "$main_repo/.jj"
    jj git init --colocate "$main_repo"
end

# Step 5: Compute workspace path
set -l workspace_path "$HOME/workspaces/github.com/$owner/$repo/$branch_name"

if not test -d "$workspace_path"
    # For fork PRs the head branch isn't on origin — only refs/pull/N/head is.
    # Fetch via the PR ref into a local branch using git; jj imports the new
    # ref on the next jj op since we're colocated. Skip the colon form if we
    # already have the local branch (git fetch errors on existing refs).
    if not git -C "$main_repo" show-ref --verify --quiet "refs/heads/$branch_name"
        if not git -C "$main_repo" fetch origin "pull/$pr_number/head:$branch_name" --quiet
            echo "Failed to fetch pull/$pr_number/head from origin"
            return 1
        end
    end

    # Workspace names can't contain slashes; flatten for the --name arg
    set -l ws_name (string replace -a "/" "-" "$branch_name")

    mkdir -p (dirname "$workspace_path")
    if not jj -R "$main_repo" workspace add --revision "$branch_name" --name "$ws_name" "$workspace_path"
        echo "Failed to create jj workspace for $branch_name"
        return 1
    end
end

# Step 6: Compute tmux session name (matches session-wizard --full-path)
set -l session_name (string replace "$HOME" "~" "$workspace_path")
set session_name (string replace -a " " "-" $session_name)
set session_name (string replace -a "." "-" $session_name)
set session_name (string replace -a ":" "-" $session_name)
set session_name (string lower $session_name)

# Step 7: Create tmux session if it doesn't exist
set -l is_new_session 0
if not tmux has-session -t "$session_name" 2>/dev/null
    tmux new-session -d -s "$session_name" -c "$workspace_path"
    set is_new_session 1
end

# Step 8: Launch Claude for new sessions; for existing ones, notify and switch
if test $is_new_session -eq 1
    set -l base_branch (gh pr view $pr_number -R "$owner/$repo" --json baseRefName --jq '.baseRefName')
    test -z "$base_branch"; and set base_branch main

    set -l sock_name (string replace -a "/" "-" "$session_name")
    set -l nvim_sock "/tmp/nvc-$sock_name.sock"
    if test (string length "$nvim_sock") -gt 100
        set nvim_sock "/tmp/nvc-"(echo "$sock_name" | md5sum | cut -c1-12)".sock"
    end

    tmux split-window -h -t "$session_name" -c "$workspace_path" \
        "nvim --listen '$nvim_sock' -c 'ClaudeChanges origin/$base_branch'"
    tmux select-pane -t "$session_name:0.0"

    tmux send-keys -t "$session_name:0.0" "claude --dangerously-skip-permissions '/review-pr $pr_number — you are already on the PR branch in a dedicated jj workspace; skip branch verification'" Enter
else
    echo "Session already exists for $owner/$repo#$pr_number — switching to it"
end

# Step 9: Switch to session
if test -n "$TMUX"
    tmux switch-client -t "$session_name"
else
    tmux attach -t "$session_name"
end
