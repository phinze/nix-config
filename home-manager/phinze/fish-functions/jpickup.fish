# jj-flavored pickup: same shape as `pickup`, but uses jj workspaces under
# ~/workspaces/... instead of git worktrees. The main repo is auto-colocated
# the first time it's touched.

# Step 1: Resolve issue identifier (same logic as pickup)
set -l identifier

if test (count $argv) -eq 0
    set -l selection (linearis issues list --limit 25 2>/dev/null | jq -r '.[] | "\(.identifier)\t\(.state.name)\t\(.title)"' | fzf --height=40% --reverse --with-nth=1,2,3 --delimiter='\t' --prompt="Pick issue: ")
    if test -z "$selection"
        return 0
    end
    set identifier (echo "$selection" | cut -f1)
else if string match -qr '^[A-Z]+-[0-9]+$' $argv[1]
    set identifier $argv[1]
else
    set -l selection (linearis issues search "$argv" 2>/dev/null | jq -r '.[] | "\(.identifier)\t\(.state.name)\t\(.title)"' | fzf --height=40% --reverse --with-nth=1,2,3 --delimiter='\t' --prompt="Pick issue: ")
    if test -z "$selection"
        return 0
    end
    set identifier (echo "$selection" | cut -f1)
end

# Step 2: Get branch name from Linear
set -l branch_name (linearis issues read $identifier 2>/dev/null | jq -r '.branchName // empty')
if test -z "$branch_name"
    echo "No branch name found for $identifier"
    return 1
end

# Step 3: Locate the main repo. `git rev-parse --git-common-dir` points at
# the main repo's .git from any worktree, and at .git from the main repo
# itself. realpath normalizes both into an absolute path.
set -l git_common (git rev-parse --git-common-dir 2>/dev/null)
if test -z "$git_common"
    echo "Not in a git repo — cd into a checkout first"
    return 1
end
set -l main_repo (realpath (dirname $git_common))

# Derive owner/repo from the ghq path (~/src/github.com/<owner>/<repo>)
set -l rel_path (string replace "$HOME/src/" "" $main_repo)
set -l parts (string split "/" $rel_path)
set -l owner $parts[2]
set -l repo $parts[3]
if test -z "$owner" -o -z "$repo"
    echo "Could not derive owner/repo from $main_repo"
    return 1
end

# Step 4: Ensure the main repo is colocated with jj
if not test -d "$main_repo/.jj"
    jj git init --colocate "$main_repo"
end

# Step 5: Compute workspace path and create it if needed
set -l workspace_path "$HOME/workspaces/github.com/$owner/$repo/$branch_name"

if not test -d "$workspace_path"
    # Best-effort fetch; if the branch isn't on origin yet this is a no-op
    jj -R "$main_repo" git fetch --branch "$branch_name" 2>/dev/null

    # Determine starting revision: prefer remote bookmark, then local, then trunk
    set -l start_rev
    if jj -R "$main_repo" log -r "$branch_name@origin" --no-graph -T '"x"' 2>/dev/null | grep -q .
        set start_rev "$branch_name@origin"
    else if jj -R "$main_repo" log -r "$branch_name" --no-graph -T '"x"' 2>/dev/null | grep -q .
        set start_rev "$branch_name"
    else
        set start_rev "trunk()"
    end

    # Workspace names can't contain slashes; flatten for the --name arg
    set -l ws_name (string replace -a "/" "-" "$branch_name")

    mkdir -p (dirname "$workspace_path")
    if not jj -R "$main_repo" workspace add --revision "$start_rev" --name "$ws_name" "$workspace_path"
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

# Step 8: For new sessions, split layout and launch Claude
if test $is_new_session -eq 1
    set -l sock_name (string replace -a "/" "-" "$session_name")
    set -l nvim_sock "/tmp/nvc-$sock_name.sock"
    if test (string length "$nvim_sock") -gt 100
        set nvim_sock "/tmp/nvc-"(echo "$sock_name" | md5sum | cut -c1-12)".sock"
    end

    tmux split-window -h -t "$session_name" -c "$workspace_path" \
        "nvim --listen '$nvim_sock' -c ClaudeChanges"
    tmux select-pane -t "$session_name:0.0"

    tmux send-keys -t "$session_name:0.0" "claude --dangerously-skip-permissions 'Picking up $identifier — use the Linear MCP (it may take a few seconds to connect) to read the issue, mark it In Progress and assigned to me, then help me plan.'" Enter
end

# Step 9: Switch to session
if test -n "$TMUX"
    tmux switch-client -t "$session_name"
else
    tmux attach -t "$session_name"
end
