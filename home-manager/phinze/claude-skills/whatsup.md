# Morning Context Rebuild

You are helping me rebuild context after being away from my computer.

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
2. **Recent shell history**: `atuin history list --format '{time} | {command}' | tail -50`
3. **Recent Claude sessions**: `find ~/.claude/projects -name 'sessions-index.json' -exec cat {} \; 2>/dev/null | jq -s '[.[].entries[]] | sort_by(.modified) | reverse | .[:15] | .[] | "\(.modified) | \(.projectPath | split("/")[-1]) | \(.firstPrompt | .[0:80])..."' -r`
4. **Git status in active repos**: For 2-3 most recently active tmux sessions, check git status (remember: "github-com" in session name = "github.com" on disk)

## Output Format
Give me a concise morning-briefing style summary (no emojis):

### Work (mirendev)
1. **Active Sessions**: Which mirendev repos have tmux sessions open
2. **Recent Activity**: What work tasks was I doing based on shell history
3. **Claude Conversations**: Recent Claude sessions in mirendev repos
4. **Uncommitted Work**: Any mirendev repos with uncommitted changes
5. **Suggested Starting Points**: 2-3 work items to pick up

### Personal (brief)
- One-liner on any recently active personal projects (if any)

End with the summary - do not ask questions or prompt for next steps.
