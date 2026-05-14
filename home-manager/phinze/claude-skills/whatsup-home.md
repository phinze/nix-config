# Whatsup Home

Scope: last ~week of personal progress. Progress is spotty across domains
(side projects, CTL, NDSM, family ops), so the goal is to surface what's
actually moved, what's mid-flight, and what's worth picking back up. Silence
in a domain is a fine answer.

## Sources

Fetch in parallel:

1. **Memex daily notes** (the primary journal):
   - `~/src/github.com/phinze/memex/Daily/YYYY-MM-DD.md` for the last 7 days
   - The work/home split is org-based, not tag-based: an entry referencing
     `mirendev/infra` is work, `phinze/infra` is personal. Judge by what the
     entry references (PR refs, repo paths, Linear tickets), not just the
     area tag at the start.
2. **Memex identity context** for whichever domains are active:
   - `~/src/github.com/phinze/memex/PIM/CTL.md` — Chicago Tool Library
   - `~/src/github.com/phinze/memex/PIM/NDSM.md` — Notre Dame School of
     Milwaukee
3. **Memex sketches**: `~/src/github.com/phinze/memex/Projects/Ideas/` for
   anything dropped or modified this week.
4. **GitHub activity in non-work orgs** via `gh`:
   - `gh search prs --author @me --created '>=YYYY-MM-DD'`, then filter out
     `mirendev/*`
   - Personal orgs include `phinze/*` (nix-config, memex, pim-stuff, infra,
     and others) and `chicago-tool-library/*`
5. **Claude Code sessions** (non-work):
   `claude-sessions.sh summary --all --days 7`, then filter out sessions
   whose project path contains `mirendev` or `worktrees/github.com/mirendev`.
   Use `recap <session>` to dig into a specific one.

## Synthesis posture

- **Group by domain, not status**. Personal stuff doesn't have ticket
  workflows; the question is which thread is alive.
- **Lead with what moved**, then what stalled. If a domain was quiet, name it
  briefly ("nothing on NDSM this week") rather than padding.
- **Connect dots to memex sketches**: a `Projects/Ideas/` sketch from earlier
  in the week plus an active Claude session usually means the idea is
  graduating to implementation.
- **Convert relative dates** to absolute when retelling.
- **End with concrete resumption recommendations**, same shape as
  `whatsup-work`:
  - "Pick up last Sunday's `lumen` packaging session and decide whether to go
    greenfield ratatui diff tool or live with the bolt-on."
  - "The CTL Drive reorg is half-done in last Tuesday's session; finish the
    move-and-rename pass."
  - "Sketch in `Projects/Ideas/<name>.md` from Wednesday has gone untouched;
    decide whether to advance or close out."

## What this isn't

- Not a comprehensive activity log; the daily journal covers that.
- Not a work status check; use `whatsup-work` for mirendev context.
- Not a one-shot. Expect iterative narrowing ("focus on CTL stuff this week").
