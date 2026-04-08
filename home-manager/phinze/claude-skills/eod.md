# End of Day Summary

You are writing an end-of-day summary for the memex (personal knowledge vault). The goal is to produce a concise, useful record of what happened on a given day, the kind of note that's valuable to read a week or a month from now.

## Date

If an argument is provided (e.g. `/eod 2026-04-06`), use that as the target date. Otherwise default to today's date.

Set these variables for use throughout the steps below:

- **TARGET_DATE**: the date to summarize, in `YYYY-MM-DD` format
- **NEXT_DATE**: the day after TARGET_DATE, for range queries

## Environment Context
- Memex repo: ~/src/github.com/phinze/memex
- Daily notes go in: `Daily/YYYY-MM-DD.md`
- I use ghq/gwq for git repo organization
- **Main repos**: ~/src/github.com/<owner>/<repo>
- **Worktrees**: ~/worktrees/github.com/<owner>/<repo>/<branch>
- Tmux session names show "github-com" but filesystem uses "github.com"
- Atuin tracks shell history with timestamps
- Claude Code sessions are stored in ~/.claude/projects/

## Work vs Personal
- **Work**: anything in the `mirendev` org
- **Personal**: everything else (phinze, chicago-tool-library, etc.)

## Your Task

Gather the target day's activity, synthesize it, write a daily note, commit and push.

### Step 1: Gather Signals

Run these commands to understand what happened on TARGET_DATE:

1. **Tmux sessions**: `tmux list-sessions -F '#{session_name} (#{session_windows} windows, #{?session_attached,attached,detached}) - last activity: #{t:session_activity}'`
2. **Shell history**: `atuin search --after TARGET_DATE --before NEXT_DATE --format '{time} | {command}'`
3. **Claude sessions**: `find ~/.claude/projects -name 'sessions-index.json' -exec cat {} \; 2>/dev/null | jq -s --arg start "TARGET_DATE" --arg end "NEXT_DATE" '[.[].entries[]] | map(select(.modified > $start and .modified < $end)) | sort_by(.modified) | .[] | "\(.modified) | \(.projectPath | split("/")[-1]) | \(.firstPrompt | .[0:120])..."' -r`
4. **Git activity across repos**: For each active tmux session, check `git log --oneline --since="TARGET_DATE" --until="NEXT_DATE" --author="Paul Hinze"` (remember: "github-com" in session name = "github.com" on disk)
5. **Read Claude session transcripts** for the most active sessions from that day. Transcripts are at `~/.claude/projects/{cwd-slug}/{session-id}.jsonl`. Focus on user messages and assistant text blocks, skip tool calls.

### Step 2: Write the Daily Note

Write a markdown file to `~/src/github.com/phinze/memex/Daily/TARGET_DATE.md`.

Format:

```markdown
---
date: YYYY-MM-DD
---

## Work

Summary of work activity. Organize by project/repo, not chronologically.
For each project, note:
- What was done (commits, PRs, decisions)
- Key context or reasoning worth remembering
- Open threads / things to pick up tomorrow

## Personal

Summary of personal project activity (if any). Same structure as work.

## Notes

Anything interesting that came up — links, ideas, things to look into.
Only include this section if there's something worth noting.
```

Guidelines:
- Be concise. Each project should be 2-5 bullet points, not paragraphs.
- Focus on *decisions and outcomes*, not activity logs. "Chose X over Y because Z" is more valuable than "ran 14 commands".
- Link to PRs/issues using `owner/repo#123` format when relevant.
- If a Claude session had an interesting discussion or design decision, capture the gist — this is the "open source the process" angle.
- If there's genuinely nothing interesting to note, it's fine for a section to be brief.
- Don't fabricate activity. If it was a quiet day, say so.

### Step 3: Commit and Push

```bash
cd ~/src/github.com/phinze/memex
git add "Daily/TARGET_DATE.md"
git commit --no-gpg-sign -m "Daily: TARGET_DATE"
git push
```

If the file already exists (e.g., from manual notes earlier in the day), append your summary below the existing content under a `## EOD Summary` heading rather than overwriting.
