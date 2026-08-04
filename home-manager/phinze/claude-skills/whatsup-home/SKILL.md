---
name: whatsup-home
description: Lay-of-the-land summary of recent personal progress across side projects, CTL, NDSM, and family ops. What moved, what's mid-flight, what's worth picking back up. Use when asked what's up at home, what's been happening personally, or for a non-work catch-up after time away.
---

# Whatsup Home

Scope: last ~week of personal progress. Progress is spotty across domains
(side projects, CTL, NDSM, family ops), so the goal is to surface what's
actually moved, what's mid-flight, and what's worth picking back up. Silence
in a domain is a fine answer.

Personal work runs through rigs the same as work does, so the board is a real
source here, not just a code thing. Errands and family ops show up on it right
alongside side projects.

## Sources

Fetch in parallel:

1. **Rig board** (what's alive right now):
   - `rig ls` for every rig in flight with age and state (working / idle /
     parked). Add `--full` for PR and CI status when a side project is
     mid-review; it costs a `gh` call per repo, so skip it otherwise.
   - `rig history` for rigs torn down recently, which is how you catch things
     that finished and closed out since the last look.
   - Personal rigs are everything that isn't `mir-*`, `pr-*`, or an obviously
     mirendev kickoff. Errands read as errands ("removing umbrella screw",
     "tsa renewal"), so judge by the kickoff line.
   - **Never run `rig radar` or a bare `rig sweep`.** Both are interactive
     TUIs for a human at a terminal.
2. **Memex daily notes** (the primary journal):
   - `~/src/github.com/phinze/memex/Daily/YYYY-MM-DD.md` for the last 7 days
   - The work/home split is org-based, not tag-based: an entry referencing
     `mirendev/infra` is work, `phinze/infra` is personal. Judge by what the
     entry references (PR refs, repo paths, Linear tickets), not just the
     area tag at the start.
3. **Memex identity context** for whichever domains are active:
   - `~/src/github.com/phinze/memex/PIM/CTL.md` — Chicago Tool Library
   - `~/src/github.com/phinze/memex/PIM/NDSM.md` — Notre Dame School of
     Milwaukee
4. **Memex sketches**: `~/src/github.com/phinze/memex/Projects/Ideas/` for
   anything dropped or modified this week.
5. **GitHub activity in non-work orgs** via `gh`:
   - `gh search prs --author @me --created '>=YYYY-MM-DD'`, then filter out
     `mirendev/*`
   - Personal orgs include `phinze/*` (nix-config, memex, pim-stuff, infra,
     and others) and `chicago-tool-library/*`
6. **Claude Code sessions** (non-work):
   `claude-sessions.sh summary --all --days 7`, then filter out sessions whose
   project path is a work rig (`~/workspaces/mir-*`, `~/workspaces/pr-*`) or
   sits under the legacy `worktrees/github.com/mirendev` layout. Use
   `recap <session>` to dig into a specific one. Only Claude sessions land
   here, so a rig launched with cdx or agy shows up on the board but not in
   this list.

When a rig needs a closer look, its repos are jj workspaces under
`~/workspaces/<rig>/<repo>`. Use `jj st` and `jj log` there; git commands fail
outright with "not a git repository."

## Synthesis posture

- **Group by domain, not status**. Personal stuff doesn't have ticket
  workflows; the question is which thread is alive.
- **Lead with what moved**, then what stalled. If a domain was quiet, name it
  briefly ("nothing on NDSM this week") rather than padding.
- **Connect dots to memex sketches**: a `Projects/Ideas/` sketch from earlier
  in the week plus an active rig usually means the idea is graduating to
  implementation.
- **A parked personal rig is usually a dropped thread, not a review queue.**
  Unlike work, there's rarely anyone to review it, so an old parked rig is a
  finish-or-tear-down call.
- **Convert relative dates** to absolute when retelling.
- **End with concrete resumption recommendations**, same shape as
  `whatsup-work`:
  - "`rig wake removing-umbrella-screw` — parked two days, and it's the kind
    of thing that gets worse to restart the longer it sits."
  - "The CTL Drive reorg is half-done in last Tuesday's session; finish the
    move-and-rename pass."
  - "Sketch in `Projects/Ideas/<name>.md` from Wednesday has gone untouched;
    decide whether to advance or close out."

## What this isn't

- Not a comprehensive activity log; the daily journal covers that.
- Not a replacement for `rig radar`. Radar is the live board you look at
  yourself; this is the narrative around it, across domains that never touch
  a repo.
- Not a work status check; use `whatsup-work` for mirendev context.
- Not a one-shot. Expect iterative narrowing ("focus on CTL stuff this week").
