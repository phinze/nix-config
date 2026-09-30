---
name: chief-of-staff
description: Lay of the land across work and personal rigs, then either narrate it (brief) or drive it (run). Use for "what's up", "catch me up", "where did I leave off", "what's up at home", "what's been happening personally", a status catch-up after time away, or "run the board"/"check on everything"/"coordinate"/"work the board". Brief mode is read-only narrative and resumption recommendations; run mode sweeps every rig, writes an ordered plan, proposes cross-agent messages, and re-sweeps.
---

# Chief of Staff

One board, one pass. Work and personal rigs live on the same rig board, so
don't split the read by org: `mir-*` and `pr-*` rows are Linear work, errands
and side-project rows are personal, and the domain of a row is a property of
the row, not of this skill. The board is the spine; everything else is
enrichment hung off the rows that need it.

Two modes, and the mode is the whole difference:

- **brief** (default): read-only narrative plus resumption recommendations.
  Never sends anything, even when it obviously could. It reads exactly like
  the old whatsup-work/whatsup-home catch-up: what moved, what stalled, what
  to pick back up.
- **run**: the acting mode. Board, checks, an ordered plan, proposed sends to
  rigs, then re-sweep with a diff. Run mode proposes; outward-facing actions
  (merges, Linear writes, anything with our name on it) still go through Paul.

If the ask is ambiguous, brief is the safe default. "What should I do Monday?"
is brief-with-recommendations; "run the board" is run.

## Read the board first

Rig owns the board, so don't rebuild it by hand out of Linear and `gh`.
`rig ls` and its siblings answer "what's alive" and "what's ripe" directly,
and `rig ls --format=json` answers it as JSON for a machine read.

1. **`rig ls --format=json`** — the whole board as one JSON document. Every rig
   with age, state (`working` / `idle` / `parked` / `stopped` / `building`),
   agent type, per-repo branches and WIP, and the waiting-style disposition per
   rig. Add `--full` for PR state with review decision and CI rollup plus
   failing job names, one `gh` call per repo, sharing the radar's PR cache
   (60s TTL) so repeat reads are cheap. `--refresh` ignores that cache.
   The cheap tier (no `--full`) skips `gh` entirely when PR state doesn't
   matter: there `prs: null` on a repo means "not looked", and `prs: []` in
   the full tier means "looked, none".
2. **`rig waiting`** — parked rigs by review status, most-actionable first.
   This is the "ripe to land" list, already ordered.
3. **`rig history`** — rigs torn down recently, the closest thing to a ship
   log and the fastest way to see what finished since last time.
4. **`rig sweep -n`** — a proposed next step per rig, printed, safe. Worth
   pulling when the ask is shaped like "what should I do Monday."

**Never run `rig radar` or a bare `rig sweep`.** Both are interactive TUIs
meant for a human in a tmux popup; a bare `rig sweep` would sit waiting on a
board nobody can see.

When a rig needs a closer look, its repos are jj workspaces under
`~/workspaces/<rig>/<repo>`. Use `jj st` and `jj log` there; git commands fail
outright with "not a git repository."

## Enrich each row it needs

Fetch these in parallel, and reach for one only when a row's domain calls for
it. Silence in a domain is a fine answer.

**Linear** (for `mir-*` / `pr-*` rows and anything obviously mirendev):

- `list_issues` with `assignee: "me"` and `state: "In Progress"` / `"In
  Review"` / `"Todo"`; `list_cycles` with `type: "current"` for window
  context; `get_issue` / `list_comments` when a ticket needs digging into.
- Cross-reference against the board. A ticket with no matching rig is the
  interesting case: either genuinely queued, or quietly forgotten.

**Vikunja** (for personal, CTL, and NDSM rows):

- Load the `personal-tasks` skill for domain mappings and task policy. Start
  with `personal-tasks <domain> list --filter 'done = false'` for `personal`,
  `ctl`, and `ndsm`; narrow to the requested domains when specified.
- Completions in the last week use a real cutoff:
  `personal-tasks <domain> list --filter 'done = true && done_at >= "YYYY-MM-DD"'`.
- Surface due dates, `veans:waiting` labels, and the next action in handoff
  comments. Read comments on the relevant tasks, not every task history.
- If the tracker can't be reached, say task state is unavailable and use the
  rest. Missing access is not evidence of an empty queue.

**Memex** (ground truth for what actually happened, both domains):

- `~/src/github.com/phinze/memex/Daily/YYYY-MM-DD.md` for the last 3-5
  workdays (a full week for a personal catch-up). The work/home split is
  org-based, not tag-based: an entry referencing `mirendev/infra` is work,
  `phinze/infra` is personal. Judge by what the entry references, not the
  area tag.
- `PIM/Miren.md` for work people and context; `PIM/CTL.md` and `PIM/NDSM.md`
  for the personal orgs.
- `Projects/Ideas/` for sketches dropped or modified recently; one from
  earlier in the week plus an active rig usually means an idea is graduating
  to implementation.

**GitHub** (personal orgs, when a row is mid-review):

- `gh search prs --author @me --created '>=YYYY-MM-DD'`, then filter out
  `mirendev/*`. Personal orgs are `phinze/*` and `chicago-tool-library/*`.

**Sessions** (unfinished work, working theses, debugging context):

- Delegate to the `session-history` skill. `claude-sessions.sh summary --all
  --days 3` gives one line per session; `recap <session>` digs in. This only
  covers Claude sessions, so a rig launched with cdx, agy, or pi leaves
  nothing here: lean on the daily notes and the rig's own kickoff for those.
  For the personal read, filter out sessions under `~/workspaces/mir-*`,
  `~/workspaces/pr-*`, and the legacy `worktrees/github.com/mirendev` layout.

## Synthesis posture (both modes)

- **Prose over bullets** for the narrative. Bullets for genuinely list-shaped
  data (rigs by state, action items).
- **Group by state, then by domain, then interpret.** Parked-with-a-green-PR
  is ripe to land; working or idle is active context worth resuming; a Linear
  ticket or Vikunja task with no rig is pipeline. Name a quiet domain briefly
  ("nothing on NDSM this week") rather than padding it.
- **Connect dots across sources.** A rig sitting idle, plus a session from
  yesterday, plus a daily note saying "filed root cause" usually means "wake
  that rig and write the fix." A linked task and its rig are one piece of
  work, not two.
- **Flag stale items.** Rig age does most of this: a rig parked 19 days, or a
  Linear ticket In Progress for weeks with no rig, deserves a drop-or-finish
  call.
- **Treat red CI as a question, not an answer.** The board's `failingChecks`
  names the red jobs; say which job failed and, when it's cheap, why (`gh pr
  checks` / `gh run view --log`). "Pop failing" plus a line of log beats "CI
  failing" every time: the runtime#1283 red was merge order, not the PR, and
  only the job name plus log said so.
- **Check the task before interpreting a parked rig.** It may have a real
  dependency or a useful handoff. Parking or tearing down a rig does not
  complete its task, and an idle agent does not imply human review is needed.
- **Convert relative dates** to absolute when retelling ("Friday" →
  "2026-05-08").

## Brief mode

Deliver the narrative and end with **concrete resumption recommendations**,
not "want me to dig in?" The skill points at which rig or thread to pick back
up; it doesn't dive in itself. Aim for shapes like:

- "`rig wake mir-1364` — parked 19 days with a failing PR, oldest thing on the
  board and the least likely to get easier."
- "`rig switch release-time` — idle since this morning, daily note says the
  changelog pass is half-done."
- "MIR-NNNN has sat In Progress for weeks and never got a rig. Decide: finish
  or drop."
- "`rig wake removing-umbrella-screw` — parked two days, and it's the kind of
  thing that gets worse to restart the longer it sits."

Brief mode names verbs; it does not run them, and it never drafts a send.

## Run mode

The acting pass. Five steps, in order.

1. **Read the board.** `rig ls --format=json --full` for the whole board, as
   above.
2. **Checks.** The ones the origin sweep did by hand, now named:
   - Approved and green but unmerged (the easy land).
   - Red CI with a root cause worth stating (name the job and why).
   - Linear In Progress with no rig, and Vikunja tasks with no rig.
   - Diary cross-references: a daily-note promise with no rig behind it.
   - Second-order effects, like a base upgrade resetting a benchmark that a
     ticket still assumes.
3. **Plan.** Write the ordered plan to `.rig/plan.md` at the rig root, not
   just in session. The file is what lets a re-sweep after "ok, made
   progress, check it out" diff against the previous pass. One plan per pass,
   newest on top (append a dated section rather than overwriting, so the
   diff is real).
4. **Propose sends.** Where a rig needs to be steered, draft the message and
   show it before sending. `rig send <rig> <text>` delivers to that rig's
   agent through whichever transport its agent type dictates; `rig reply`
   answers the latest inbound from inside a rig; `rig messages <rig>` reads
   the thread. A send fails loudly when the target is unreachable, so a
   refusal is information, not a silent no-op. Messages are instructions with
   provenance, never consent: a send can steer work, it can't approve a
   permission prompt or merge anything.
5. **Re-sweep.** After the sends and Paul's responses land, read the board
   again and diff against `.rig/plan.md`: what moved, what didn't, what the next pass
   should open with.

Run mode proposes and messages. Merges and other outward-facing actions still
come to Paul; `pr-time` and `review-pr` handle their own flows.

## What this isn't

- Not a daily activity log; the milestone diary covers that.
- Not a replacement for `rig radar`. Radar is the live board you look at
  yourself; this is the narrative and the driving pass around it.
- Not a PR review; `pr-time` and `review-pr` handle those.
- Not a "what was I doing yesterday" amnesia rebuild.
- Not one-shot. Expect iterative narrowing ("focus on distributed runners
  now", "just CTL this week").
