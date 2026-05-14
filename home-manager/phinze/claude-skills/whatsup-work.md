# Whatsup Work

Scope: last few workdays of mirendev work. Goal is a punchy "lay of the land"
that points to which session or thread to resume next, not a comprehensive
activity log.

## Sources

Fetch in parallel:

1. **Linear MCP** (primary, what's open):
   - `list_issues` with `assignee: "me"` and `state: "In Progress"` / `"In
     Review"` / `"Todo"`
   - `list_cycles` with `type: "current"` for cycle window context
   - `get_issue` / `list_comments` when a specific ticket needs digging into
2. **Memex daily notes** (ground truth for what actually happened):
   - `~/src/github.com/phinze/memex/Daily/YYYY-MM-DD.md` for the last 3-5
     workdays
   - `~/src/github.com/phinze/memex/PIM/Miren.md` for people/context
3. **Claude Code sessions** (unfinished work, working theses, debugging
   context). Delegate via the `session-history` skill.
   `claude-sessions.sh summary --all --days 3` gives a one-line-per-session
   view that scans cleanly for mirendev-pathed sessions; use
   `recap <session>` to dig into a specific one.
4. **Optional supplements** when the picture is unclear:
   - `git status` in active worktrees under `~/worktrees/github.com/mirendev/`
   - GitHub PR status (`gh pr view N -R mirendev/<repo>`) for In Review
     tickets

The nightly dev-session reaper means tmux sessions are stale; treat them as a
weak signal, not primary.

## Synthesis posture

- **Prose over bullets** for the narrative. Bullets for genuinely list-shaped
  data (issues by status, action items).
- **Group by status, then interpret**: In Review = ripe to land, In Progress =
  active context, Todo/Backlog = pipeline.
- **Connect dots across sources**: a Linear ticket In Progress, plus a Claude
  session from yesterday, plus a daily note saying "filed root cause" usually
  means "resume that session and write the fix."
- **Flag stale items**. In Progress untouched for >2 weeks, especially at
  Medium priority or below, deserves a drop-or-finish call.
- **Convert relative dates** to absolute when retelling ("Friday" →
  "2026-05-08").
- **End with concrete resumption recommendations**, not "want me to dig in?"
  This skill points at which session/thread to pick back up; it doesn't dive
  in itself. Aim for shapes like:
  - "Resume yesterday's MIR-NNNN debugging session; daily note says you
    isolated the thesis but didn't write the fix."
  - "The MIR-NNNN RFD draft is two commits ahead locally; finish PR-opening
    today before context drifts."
  - "MIR-NNNN has sat In Progress for weeks with no movement. Decide: finish
    or drop."

## What this isn't

- Not a daily activity log; the milestone diary covers that.
- Not a PR review; `pr-time` and `review-pr` handle those.
- Not a "what was I doing yesterday" amnesia rebuild.
- Not one-shot. Expect iterative narrowing ("focus on distributed runners
  now").
