# Morning Context Rebuild

You are helping me rebuild context from the last ~24 hours of work. The goal is to surface context I may have forgotten from yesterday, NOT to recap things I just did this morning.

## Environment Context
- I use ghq/gwq for git repo organization
- **Main repos**: ~/src/github.com/<owner>/<repo> (e.g. ~/src/github.com/mirendev/runtime)
- **Worktrees**: ~/worktrees/github.com/<owner>/<repo>/<branch> for feature branches (e.g. ~/worktrees/github.com/mirendev/runtime/saga-genesis)
- Tmux session names show "github-com" but filesystem uses "github.com"
- Worktree sessions indicate active feature branch work - these are often the most relevant context
- Atuin tracks shell history with timestamps
- Claude Code sessions are stored in ~/.claude/projects/

## Work vs Personal
- **Work**: anything in the `mirendev` org (in ~/src/ or ~/worktrees/)
- **Personal**: everything else (phinze, chicago-tool-library, etc.)
- Focus ~80% on work context, mention personal only briefly if recently active

## Your Task
Analyze my active work context and give me a concise summary of what I was working on. This is a ONE-SHOT summary - do not ask follow-up questions or prompt for what to do next.

## Commands to Run
1. **Tmux sessions**: `tmux list-sessions -F '#{session_name} (#{session_windows} windows, #{?session_attached,attached,detached}) - last activity: #{t:session_activity}'`
2. **Shell history (last 24h)**: `atuin history list --after "$(date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S')" --format '{time} | {command}'` (use `gdate` on macOS)
3. **Claude sessions (last 24h)**: `find ~/.claude/projects -name 'sessions-index.json' -exec cat {} \; 2>/dev/null | jq -s --arg cutoff "$(date -d '24 hours ago' -Iseconds 2>/dev/null || gdate -d '24 hours ago' -Iseconds)" '[.[].entries[]] | map(select(.modified > $cutoff)) | sort_by(.modified) | .[] | "\(.modified) | \(.projectPath | split("/")[-1]) | \(.firstPrompt | .[0:80])..."' -r`
4. **Git status in active repos**: For 2-3 most recently active tmux sessions, check git status (remember: "github-com" in session name = "github.com" on disk)

## Context Priority
When summarizing, weight context by recency within the 24h window:
- **Yesterday's work** (6-24h ago): HIGH priority - this is what I've likely forgotten
- **This morning** (0-6h ago): LOW priority - I probably remember this
- If most activity is from this morning, dig deeper into yesterday's Claude sessions and git logs

## Output Format
Give me a concise morning-briefing style summary (no emojis). Focus on reminding me what I was doing YESTERDAY, not recapping obvious recent activity.

### Work (mirendev)
1. **Yesterday's Context**: What was I working on 6-24h ago that I might have forgotten?
2. **Active Sessions**: Which mirendev repos have tmux sessions open
3. **Claude Conversations**: Claude sessions from the last 24h (emphasize older ones)
4. **Uncommitted Work**: Any mirendev repos with uncommitted changes
5. **Suggested Starting Points**: 2-3 work items to pick up based on yesterday's momentum

### Personal (brief)
- One-liner on any recently active personal projects (if any)

End with the summary - do not ask questions or prompt for next steps.
