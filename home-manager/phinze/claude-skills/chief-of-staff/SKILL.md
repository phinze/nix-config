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
`~/workspaces/<rig>/<repo>` on the host it lives on. Use `jj st` and `jj log`
there. Git works too, but its HEAD is detached at `@-` and says little about
the rig's work.

## Every host is one board

Rigs live on the laptop (phinze-mrn-mbp, in Rex) and on foxtrotbase, and the
board covers both from either side. Each host runs `rig serve`, and every
board verb asks the other host for its own answer: `rig ls --format=json`
rows carry `location` (`local` or the host's name), and its `hosts` field
says which hosts answered. A host marked unreachable there means its rigs
weren't looked at, not that they're gone; say so in the brief. `waiting`,
`history`, and `sweep -n` append each other host's answer under its name.

A rig on another host is addressed `<id>@<host>` (`mir-2043@foxtrotbase`),
and that's how the table prints it. A bare id works when only one host has
it; when both do, the local one wins and `@host` reaches the other. Every rig
verb takes these handles: `send`, `messages`, `dispatch`, `wake`, `resume`,
`park <id>`, `down <id>`, `resurrect`. The far host runs the verb, so its
refusals and probe failures read exactly as they would locally.

What rig can't do for you across hosts is look inside: jj state, an agent
pane's screen, docker leftovers, and agent processes are on the rig's own
host. For a foxtrotbase rig, read them with `ssh foxtrotbase '<command>'`,
read-only, the same commands you'd run locally.

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
- **Check the author before saying whose move it is.** `REVIEW_REQUIRED` on a
  PR Paul wrote means it waits on the team, not on him; it's only on Paul when
  he's the requested reviewer. Getting this backwards spreads: on 2026-10-01 a
  project rig repeated the same misread an hour after this skill made it.
- **Read the PR before calling Linear drift.** A PR that says "Part of"
  rather than closing keeps its issue In Progress on purpose, and Linear's
  GitHub sync holds it there while a related draft stays open. Look for a
  closing keyword first.
- **"idle" doesn't mean "waiting on Paul".** The board's agent column is a
  transcript-mtime guess (see PERS-25): it reads stale "working" after a park
  and can't tell done from blocked on input. For an idle rig whose next step
  matters, read the latest recap with a read-only `tmux capture-pane -p` of its
  agent pane (on its host: over ssh for a foxtrotbase rig). That recap is the only reliable "waiting on you" signal until
  rig grows a hook-driven state.
- **Convert relative dates** to absolute when retelling ("Friday" →
  "2026-05-08").
- **Never leave a bare ticket or PR number.** Every MIR-NNNN, PERS-NN,
  or `repo#NNN` mention carries a few-word gloss the first time it
  appears in a message: "MIR-1985 (auth the loopback telemetry ports)",
  "runtime#1338 (drop legacy status report)". Paul shouldn't have to
  deref an id from memory. Rig names count too when they're just an id
  (`mir-2043` → "mir-2043 (conformance suite)"). Do the same in plan
  file entries, since the next CoS reads them cold.

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
3. **Plan.** Write the ordered plan to
   `~/src/github.com/phinze/memex/Projects/CoS/YYYY-MM-DD.md` (today's date,
   the shared checkout so the autocommit carries it), not just in session.
   The file is what lets a re-sweep after "ok, made progress, check it out"
   diff against the previous pass, and it outlives the rig, so tomorrow's
   session opens by reading the most recent earlier file's last section for
   carried-over threads. One section per pass, appended with a time, so the
   diff is real; end the day with an EOD section listing what's open.
4. **Propose sends.** Where a rig needs to be steered, draft the message and
   show it before sending. `rig send <rig> <text>` delivers to that rig's
   agent through whichever transport its agent type dictates, on whichever
   host it lives; `rig reply`
   answers the latest inbound from inside a rig; `rig messages <rig>` reads
   the thread. A send fails loudly when the target is unreachable, so a
   refusal is information, not a silent no-op. Messages are instructions with
   provenance, never consent: a send can steer work, it can't approve a
   permission prompt or merge anything. See **Steering rigs** below for the
   message shape and which verb fits which rig state.
5. **Re-sweep.** After the sends and Paul's responses land, read the board
   again and diff against the plan file: what moved, what didn't, what the
   next pass should open with.

Run mode proposes and messages. Merges and other outward-facing actions still
come to Paul; `pr-time` and `review-pr` handle their own flows. Once Paul gives
a standing order ("merge on green", "down the ones that are done"), it covers
later rows of the same shape for the rest of the session.

## Steering rigs

**Message shape.** Every send that asks for work carries three things, and
rigs that got all three reported back cleanly every time:

- Provenance: "From the chief-of-staff rig, for Paul: …"
- Limits: read-only, don't deploy, draft Linear/GitHub writes for Paul, or
  whatever applies. Say what not to do as plainly as what to do.
- The exact report-back line:
  `rig send cos "<one or two lines: …>"`, naming what the lines should
  contain. Use the `cos` address, never this rig's dated id: it always
  resolves to the newest chief-of-staff rig on any host, so an answer that
  arrives tomorrow still lands, and a foxtrotbase rig reaches a cos running
  on the laptop. A rig on another host sees this rig as
  `rig:cos-YYYY-MM-DD@<this host>`, and its `rig reply` comes back here.

**Pick the verb by the rig's state.**

| Rig state | Verb | Why |
|---|---|---|
| live agent (working or idle) | `rig send` | delivered at its next turn boundary |
| parked or stopped | `rig dispatch <rig> <prompt>` | wakes it with the prompt; `send` can't reach it |
| parked, but the work waits on an event | a background watcher that dispatches when the event lands | e.g. rebase once a fix PR merges |

`dispatch` refuses a rig whose agent is already running; when it does, fall
back to `send`.

Task rigs know the `cos` address from their generated instructions and may
send unprompted; answer with `rig reply`. Discoveries a task rig relays to its
project (`rig relay`) arrive at the project rig as messages, not in a notify
inbox, so a project rig is the place to ask about them.

**Rigs that can't take messages.** A Claude agent only accepts inbound
cross-session messages when it was launched with
`--settings <rig>/.rig/claude-settings.json` (`crossSessionInbound: accept`)
and `--name <rig>`. Long-lived rigs started before rig send shipped lack both,
socket or not. Check `pgrep -af -- '--name <rig>'` on the rig's host before
relying on a send.
To bring one into the fold: have it write `HANDOFF.md`, exit it, then launch a
fresh `claude --settings <rig>/.rig/claude-settings.json --name <rig>` in its
agent pane with a prompt to read the handoff and report back. `rig resume`
adds the flags but resumes the old conversation. Check the manifest's `agent`
matches what's actually running first; a codex manifest over a Claude process
routes sends to the wrong transport.

## Recurring passes

**Approval sweep** ("got a batch of approvals"). For each of Paul's open PRs,
read the approver's review *body* and any unresolved threads, not just the
decision. Clean approvals go to their rig as merge-on-green: confirm green,
rebase and wait again if behind (sibling PRs merge at the same time), merge,
confirm the Linear issue moved, don't deploy, report back. Approvals with
notes go to the rig as `address-pr-review`, with any human-facing reply
drafted for Paul. An approval like "approving because I trust you've got your
head around it" is a conversation for Paul, not a merge.

**Parking sweep.** Park rigs whose open PRs are green and waiting on someone
else (team review, a release). Don't park rigs waiting on Paul's answer;
surface those instead. Until PERS-25 lands, `rig park` leaves the agent
running in its `tmux-spawn-*.scope`: note the scope from the agent pid's
`/proc/<pid>/cgroup` before parking and `systemctl --user stop` it after.

**Teardown checklist.** Before `rig down <id>` (the exact id; it works from
this session):

- Each repo's `@` is empty or matches the merged head; otherwise find out why.
  `--force` only when Paul has called the leftover work dead.
- Afterwards, on the rig's host, look for docker containers, networks, and
  volumes named for the rig (`runtime-dev-*`, `runtime-test-*`, older `runtime-dev-<id>` without the
  `-runtime` suffix) and report or clean up what's orphaned.
- Watch the teardown's output for jj snapshot warnings in the shared checkout
  (`~/src/...`): `jj workspace forget` snapshots it, and an unignored
  directory there gets tracked.

## Cadence

One chief-of-staff rig per workday, made with `rig cos` (it's
`cos-YYYY-MM-DD`; running it again the same day re-enters it, on whichever
host it's already up, so there's never a second one). Start fresh each
morning. Yesterday's rig is normally still running when you arrive, and closing
it out is the first job of the day: the handover and the teardown together are
how a cos day ends. A long-lived session goes stale, and continuity lives in
the memex plan file rather than in the conversation. On a heavy day, restart
mid-day from the same file instead of carrying a huge context.

**Handover.** The kickoff names yesterday's cos rig when it's still up, which
is the usual case. Its conversation often knows more than its plan file, so
before the brief, ask it with `rig send cos-<yesterday>` (the dated id, since
`cos` now means today; the kickoff spells it `cos-<yesterday>@<host>` when it's
on the other host) to write or refresh its EOD section in the plan file and
reply when done. Tell it the reply is its last act. Then read the file rather
than trusting the reply alone, so the record lands in memex either way.

Once the file holds the handover, tear the old rig down yourself with
`rig down cos-<yesterday>` (with `@<host>` if the kickoff named one). This is routine and needs no
separate approval. It works from this session because `rig down` only refuses
when it would kill the session it runs in, and a cos rig has no repos for the
safety gate to hold on. Report it in the brief as done. If the old rig doesn't
answer, fall back to the plan file and leave its teardown to Paul, since a
silent rig may be mid-something.

## What this isn't

- Not a daily activity log; the milestone diary covers that.
- Not a replacement for `rig radar`. Radar is the live board you look at
  yourself; this is the narrative and the driving pass around it.
- Not a PR review; `pr-time` and `review-pr` handle those.
- Not a "what was I doing yesterday" amnesia rebuild.
- Not one-shot. Expect iterative narrowing ("focus on distributed runners
  now", "just CTL this week").
