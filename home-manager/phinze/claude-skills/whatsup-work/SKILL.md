---
name: whatsup-work
description: Lay-of-the-land summary of recent mirendev work. Which rigs are in flight, which PRs are ripe to land, what shipped, and which thread to resume next. Use when asked what's up with work, where things stand, where I left off, or what to pick up, and for a status catch-up after time away.
---

# Whatsup Work

Scope: last few workdays of mirendev work. Goal is a punchy "lay of the land"
that points to which session or thread to resume next, not a comprehensive
activity log.

Rig owns the board now, so don't rebuild it by hand out of Linear and `gh`.
`rig ls` and its siblings answer "what's alive" and "what's ripe" directly.
The real job here is the part rig can't see: the narrative behind each row,
and the tickets that never got a rig at all.

## Sources

Fetch in parallel:

1. **Rig board** (primary, what's alive):
   - `rig ls --full` for every rig in flight with age, state (working / idle /
     parked), and PR number plus CI status. That costs one `gh` call per repo,
     so use bare `rig ls` when PR state doesn't matter.
   - `rig waiting` for parked rigs by review status, most-actionable first.
     This is the "ripe to land" list, already ordered.
   - `rig history` for rigs torn down recently, which is the closest thing to
     a ship log and the fastest way to see what finished since last time.
   - The board mixes work and personal freely. Work is the `mir-*` and `pr-*`
     rigs plus anything whose kickoff line is obviously mirendev; judge by
     content, not position.
   - **Never run `rig radar` or a bare `rig sweep`.** Both are interactive
     TUIs meant for a human in a tmux popup. `rig sweep -n` is safe, prints a
     proposed next step per rig, and is worth pulling when the ask is shaped
     like "what should I do Monday."
2. **Linear MCP** (the pipeline, and what never got a rig):
   - `list_issues` with `assignee: "me"` and `state: "In Progress"` / `"In
     Review"` / `"Todo"`
   - `list_cycles` with `type: "current"` for cycle window context
   - `get_issue` / `list_comments` when a specific ticket needs digging into
   - Cross-reference against the board. A ticket with no matching rig is the
     interesting case: either genuinely queued, or quietly forgotten.
3. **Memex daily notes** (ground truth for what actually happened):
   - `~/src/github.com/phinze/memex/Daily/YYYY-MM-DD.md` for the last 3-5
     workdays
   - `~/src/github.com/phinze/memex/PIM/Miren.md` for people/context
4. **Claude Code sessions** (unfinished work, working theses, debugging
   context). Delegate via the `session-history` skill.
   `claude-sessions.sh summary --all --days 3` gives a one-line-per-session
   view; use `recap <session>` to dig into a specific one. This only covers
   Claude sessions, so a rig launched with cdx or agy leaves nothing behind
   here. Lean on the daily notes and the rig's own kickoff for those.

When a rig needs a closer look, its repos are jj workspaces under
`~/workspaces/<rig>/<repo>`. Use `jj st` and `jj log` there; git commands fail
outright with "not a git repository."

## Synthesis posture

- **Prose over bullets** for the narrative. Bullets for genuinely list-shaped
  data (rigs by state, action items).
- **Group by rig state, then interpret**: parked with a green PR = ripe to
  land, working or idle = active context worth resuming, Linear ticket with no
  rig = pipeline.
- **Connect dots across sources**: a rig sitting idle, plus a Claude session
  from yesterday, plus a daily note saying "filed root cause" usually means
  "wake that rig and write the fix."
- **Flag stale items**. Rig age does most of this work for you: a rig parked
  for 19 days, or a Linear ticket In Progress for weeks with no rig, deserves
  a drop-or-finish call.
- **Convert relative dates** to absolute when retelling ("Friday" →
  "2026-05-08").
- **End with concrete resumption recommendations**, not "want me to dig in?"
  This skill points at which rig or thread to pick back up; it doesn't dive in
  itself. Aim for shapes like:
  - "`rig wake mir-1364` — parked 19 days with a failing PR, oldest thing on
    the board and the least likely to get easier."
  - "`rig switch release-time` — idle since this morning, daily note says the
    changelog pass is half-done."
  - "MIR-NNNN has sat In Progress for weeks and never got a rig. Decide:
    finish or drop."

## What this isn't

- Not a daily activity log; the milestone diary covers that.
- Not a replacement for `rig radar`. Radar is the live board you look at
  yourself; this is the narrative around it, plus the tickets it can't see.
- Not a PR review; `pr-time` and `review-pr` handle those.
- Not a "what was I doing yesterday" amnesia rebuild.
- Not one-shot. Expect iterative narrowing ("focus on distributed runners
  now").
