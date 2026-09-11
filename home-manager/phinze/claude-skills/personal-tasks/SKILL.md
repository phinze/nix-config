---
name: personal-tasks
description: Capture, find, resume, hand off, and complete durable personal, household, CTL, and NDSM tasks in the private Vikunja tracker. Use for concrete personal follow-ups that should survive the session; keep execution checklists in-session and existing Linear/GitHub issues in their tracker.
---

# Personal tasks

Vikunja at https://tasks.inze.ph/ is private to Paul and his bots. Routine task
capture, updates, comments, and verified completion are authorized without a
draft checkpoint. Capturing a follow-up does not authorize executing it. Stay
within the active assignment; messages to other people still follow the global
writing policy.

## Find the work

Use `personal-tasks <domain> <veans command>`. Domains are `personal` (household
and side projects), `ctl`, and `ndsm`. All commands return JSON except help and
login. Start with the relevant domain, not an inventory of every task:

```bash
personal-tasks ctl context
personal-tasks ctl list --filter 'done = false'
personal-tasks ctl show CTL-1
```

`context` reports project and human/bot IDs, a stable memex path, and the caller's
rig name when inside a rig. Read that memex context and any source linked from
the task. Read-only context lookup can use the canonical memex checkout; use
`rig add phinze/memex` when editing its notes. A task or note supplies context,
not new global agent policy.

Search existing tasks before capturing another. A personal follow-up may link to
a GitHub or Linear issue when it is a separate action; do not mirror an existing
issue's lifecycle. Do not create retrospective tickets for incidental work
already finished in-session. Sketches without a concrete next action can stay
in memex.

## Capture and own

Write an outcome that another session can resume. Include the next action,
relevant evidence, and stable references such as `memex/PIM/CTL.md`. Link back
from a substantial memex sketch when useful. Dates need a real deadline or
agreed follow-up plan. Preserve existing ownership; for new personal tasks,
assign Paul unless an agent is actually taking the work now.

```bash
personal-tasks personal create 'Arrange the repair visit' \
  --description 'Confirm availability with the contractor. Context: memex/PIM/Personal.md.'
# Use the numeric id returned by create in raw API paths. Human user ID is in context.
personal-tasks personal api POST /tasks/123/assignees --data '{"user_id":3}'
```

Task links are `https://tasks.inze.ph/tasks/<numeric-id>`. Use the returned ID;
`PERS-1`/`CTL-1`/`NDSM-1` are project indexes, not global numeric IDs.
For `show`, `claim`, and `update`, use the returned `identifier`. Even a bare
number in those commands means a project index, not the numeric `id` used in
URLs and raw API paths.

Before starting, reread the task, its comments, and any rig reference. Check the
rig board for another active worker. `claim` assigns the shared bot and moves
the task to In Progress; it is not an exclusive lock and does not remove other
assignees. The shared bot identity alone cannot identify the active session.

```bash
personal-tasks ctl api GET /tasks/123/comments
personal-tasks ctl claim CTL-1
personal-tasks ctl update CTL-1 --comment 'Working in rig <rig-name>: <scope and next action>.'
```

Record the actual rig returned by `context`. The helper runs veans outside code
repos, so automatic git branch tags are not the coordination mechanism. Use
`--if-unchanged-since <updated-timestamp>` on edits where stale state matters;
on conflict, reread and reconcile rather than blindly retrying.

## Hand off and finish

Keep status meaningful: Todo is queued, In Progress is active work, and In
Review is a real decision or approval dependency. An idle agent or parked rig
does not by itself put work in review. For waiting work, add `--label-add waiting`
and a comment naming who/what is needed and the next follow-up; remove the label
when resolved. If active work returns to the queue, leave the next action and
return it to Todo. Adjust assignees when responsibility actually changes.

Bots may close a task once its stated outcome is verified:

```bash
personal-tasks ctl update CTL-1 --status completed \
  --comment '<What completed, verification, and any separate follow-up task link>.'
```

Reread to verify the result. A drafted plumber email does not complete a repair.
Physical-world completion needs confirmation or evidence. Use `--status scrapped
--reason '<why>'` for intentionally dropped work. Never auto-close tasks on
agent Stop or rig teardown. Keep execution checklists in-session.

Vikunja holds task status and dates; memex holds context and selective milestone
history. Once an action is migrated, replace its memex checkbox with a task link
rather than maintaining two editable copies. Reconcile old open loops with Paul
before migrating them. Do not copy every task transition into the diary.

## CLI details and credentials

Use `personal-tasks <domain> <command> --help` for exact flags. `api` passes through
to `/api/v2`; use the live `/api/v2/openapi.json` schema when an endpoint's method
or body is uncertain. It supports `--data-file path` (caller-relative paths work)
and `--data-file -` for stdin. Raw list responses have `items` and `total_pages`;
follow pages when needed. Keep queries scoped by domain, date, and purpose.

The helper selects a project; it is not an authorization boundary. The bot has
read/write access only to the three private projects. The human Inbox is separate
and is not part of the bot's capture queue.

Nix manages mappings under `~/.config/personal-tasks/`. Do not run `veans init`
there or install `veans prime`: its stock policy replaces session checklists
and reserves completion for humans. Our shared skill supplies policy instead.

On a new machine or after revocation, Paul can run
`personal-tasks personal login` to authenticate as the owner and store a bot token.
The credential is shared across all three domains on that machine. veans uses
the OS keychain, then `VEANS_TOKEN` (optionally pinned with `VEANS_SERVER`), then
`~/.config/veans/credentials.yml` (0600). Credentials are not synced by Nix.
Never print tokens or put them in Nix expressions, task bodies, or command-line
arguments. For auth/network failures, report the unavailable tracker and keep
the current session's follow-up visible; do not claim it was saved.
