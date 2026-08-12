---
name: review-pr
description: Review someone else's pull request, with the user writing the comments and you supporting. Claim it with the assignee mutex, hand over a map of the change, answer what the user asks while they orient, then verify their claims and post what they wrote. Use when asked to review a PR, look over someone's changes, or when handed a PR number or URL to review.
---

# PR Review Skill

**The user writes the review. You do the mechanics and the digging.**

That division is the whole design. You are very good at tracing a call chain
across four files and proving whether a thing can actually happen; you are bad
at having an opinion in someone else's voice. So the user's words go out, and
yours support them.

Work in two phases. **Phase 1 is orientation**: the user builds their own read
of the change, and you are a resource they pull from. **Phase 2 is
composition**: they call the verdict and write the comments, you verify and
post. Phase 1 ends when *the user* says they are oriented, not when you think
the walkthrough is complete.

## Setup

Do this quietly and quickly. It is plumbing, not review.

1. **Find the PR.** If the request names a number or URL, use it. Otherwise
   `gh pr view --json number,title` for the current branch's PR, and if that
   fails, `gh pr list` and ask.

2. **Check the mutex, then claim it.** Fetch metadata including assignees:

       gh pr view <number> --json number,title,body,author,baseRefName,headRefName,url,assignees

   The assignee is our advisory "I'm reviewing this" lock. If someone other
   than us holds it, stop and surface them by name — ask whether to pile on or
   back off rather than silently claiming over them. The author self-assigning
   is not a review claim; note it and carry on. If it is unassigned or already
   us, take it with `gh pr edit <number> --add-assignee @me` before reading
   deeply, so the claim is visible early.

3. **Get the branch local.** `gh pr diff <number>` for the diff, then read whole
   files out of the working tree — the diff alone will not let you trace a call
   chain, and tracing call chains is the job.

   Assume you are in a rig already sitting on the PR's head, because that is
   where this almost always runs. Confirm it rather than checking anything out:
   compare `@-`'s commit id to `headRefOid`. Matching means you are there and
   there is nothing to do. Only if they differ, or you are outside a rig, is
   there a branch to switch to — and say so before switching a rig's workspace,
   since the rig is dedicated to this task and recto and `rig pr` are pointed
   at it. That same comparison is the one you repeat before submitting, so
   running it here also gives you the head you will check against later.

4. **On a stacked PR, fix recto's base.** If `baseRefName` is not trunk, recto
   is almost certainly showing the wrong diff: `recto --pr` uses
   `fork_point(trunk() | @)`, which on a stack renders every PR below this one
   as well. Run `recto ping` and compare its `files` count to the PR's. If they
   disagree, tell the user to press `b` and set the base to `baseRefName` —
   recto will not switch bases on its own, and until it does your `focus` and
   `annotate` calls land in the wrong document.

## The head moves

The repo shifts under you while you read; the `jj` skill covers that side. What
is specific to reviewing is that the author can force-push mid-review. When the
whole stack comes back with new commit ids and identical messages, that is a
rebase — your reading still holds, so re-verify anchors, not conclusions. Name
the commit id whenever you record what you checked; GitHub stamps one on every
review comment for exactly this reason.

## Phase 1 — Orientation

The user is building their own model of the change. Your job is to remove the
tedium from that, not to do it for them.

### Hand over the map

Open with facts they would otherwise spend ten minutes assembling:

- What the change is trying to do, in the author's own framing, and who wrote it
- Scope: files, rough size, how it groups
- Structural facts: what is new versus edited, what got deleted, whether the
  base is a stacked branch or trunk
- CI state, and whether any bot has reviewed the current head
- **On a re-review**: what has landed since our last review, and what the
  author said in reply to it. This is the most valuable map you can hand over
  and it is pure fact — commits and replies, not your assessment of them.

### The line between map and analysis

Counts, structure, and what the author asserts are all map. Anything carrying
an implied *look here* is analysis, and analysis is parked.

- Map: "74 files, base is a stacked branch, the exec proxy dropped from 383
  lines to 124."
- Parked: "the replay buffer is new machinery and worth a hard look."

The test is whether you are volunteering judgment. If you are, park it.

### Be on call

Then stop talking and answer things. The user reads; you trace. Where does
this field get set, does this path ever run, who else writes this, what did
this look like before. Go read the actual source, run a repro, check the
adjacent subsystem. This is where most of the value is, and almost none of it
will appear in the posted review.

### Holding back, without being precious about it

While the user orients, noticing is your job and announcing is not. But do not
sandbag either. When you find something real, name it in a few words with a
location and stop there:

> There's something in `run_detach.go`'s `Read` I want to show you later.

That is enough for them to pull it forward if it bears on what they are already
looking at, and short enough not to hijack their read. Do not deliver the
mechanism, the evidence, or the severity unless asked.

Keep a running count so you can say what is parked when phase 2 opens. Do not
turn the hold-back into a ritual — if the user asks what you have, tell them.

### Ending phase 1

The user closes it. They may say they are oriented, start dictating comments,
or ask what you parked. Any of those moves you to phase 2. Do not prompt for it
more than once.

## Phase 2 — Composition

### The user writes; you verify

They call the verdict and write the comments. Your work here is to make sure
nothing false goes out under their name.

**Verify every claim before it posts — theirs and yours.** A claim earns its
place only when you have traced it to a real runtime path. It is not enough
that a problem exists in the code's type-space; check whether any path reaches
it. A guard for an unreachable case is speculative code, and a comment
describing an observed problem that cannot happen is just wrong — worse when it
goes out in the user's voice. Watch for the shape that catches people: an error
log whose condition exists in the types while no production path produces it.

Say so plainly when a claim does not survive, and say it *before* posting. This
is the single most useful thing you do in phase 2 — the user supplies the
instinct, you supply the patience to check it.

**Prove it rather than arguing it.** When a contested claim reduces to pure
logic — string formatting, hashing, comparison, ordering, parsing — copy the
function verbatim into a scratch program and run it. A disagreement between the
author and a bot over whether two names can collide ends the moment you paste
in `tickRunName`, feed it two plausible inputs, and print the output. This is
worth reaching for exactly when a thread has stalled into competing assertions:
prose invites another round, a transcript does not. Copy the code rather than
paraphrasing its behavior, and say in the comment that you ran it.

**Check each comment against the current code**, not just the diff. Multi-commit
PRs fix things in later commits; read the file at the target line and confirm
the comment still applies.

**Triage bot overlap.** Fetch existing comments with
`gh api repos/{owner}/{repo}/pulls/{number}/comments` and tell the user where a
bot already caught the same thing, so they are not restating it. This is mostly
for our own triage — it rarely belongs in the posted review, and a bot is worth
naming only when the agreement or disagreement changes the verdict.

**Release what you parked**, now that it is additive to their read rather than a
substitute for it.

### Comment format

The user's words go out verbatim, first, unedited. Where detail helps, append
yours below a separator, marked with 🤖:

~~~markdown
**File**: `path/to/file.go` (line 99)

A lone Ctrl-P returning `(0, nil)` here kills stdin for the rest of the session.

---

🤖 `stream.ServeReader` runs unbatched on this path, so `serveReader.Recv`
ships `buf[:0]`, and `rscReader.Read` turns a zero-length value into `io.EOF`
(`pkg/rpc/stream/stream.go:84`). The input pump's `io.Copy` ends there and
never restarts.
~~~

🤖 is the house convention for agent-authored content in review threads.

Rules for the append:

- **Verbatim by default.** Post exactly what the user wrote. Do not tighten,
  reorder, or improve it. If a note reads as shorthand only they can parse,
  ask whether to expand it — do not expand it on your own initiative.
- **Append only when it carries weight**: a trace, a file:line citation, repro
  output, a cross-reference to a comment elsewhere in the codebase. Not a
  restatement of what they just said in more words.
- **No append is the common case.** A comment that stands on its own gets
  nothing.
- Never let the 🤖 section contradict or hedge the user's claim. If you think
  they are wrong, say so to them before posting, not underneath them in public.

### Verdict and posting

The verdict is the user's call. Almost always **APPROVE** or
**REQUEST_CHANGES**, never COMMENT (a non-action). Default to APPROVE with
comments — we trust authors to address or consciously skip feedback. Save
REQUEST_CHANGES for a specific blocking concern. If we are taking the pen and
pushing commits ourselves, the review that announces it should be
REQUEST_CHANGES from the start so the mechanics match the intent, flipping to
APPROVE once our commits land.

**Sign off with `--p+🤖`.** That is the standing marker that Claude was
involved; no per-review announcement is needed.

**Don't invent context.** No on-call rotation, team size, or process you do not
actually know — this applies to anything you append.

**Default to posting a draft.** Omit `event` and the review is created in
`PENDING` state: a draft only the user can see, with every inline comment
editable in the Files changed tab and a "Finish your review" button where they
pick the verdict at submit time.

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST --input review.json
```

```jsonc
{
  "body": "Top-level comment here",
  // no "event" key -> PENDING
  "comments": [
    {"path": "path/to/file.go", "line": 74, "body": "Inline comment..."}
  ]
}
```

This fits the division better than anything else in the skill. The user writes
their prose in GitHub, where they are already comfortable editing, and the
verdict becomes theirs by construction rather than by your restraint. Add
`"event": "APPROVE"` only when the user has said the words and wants it out in
one shot.

Use a single line number, not a range — that is what the API takes. Write the
payload to a file rather than inlining it when the bodies are long; build the
JSON with a script so you are not hand-escaping newlines and backticks.

**Scaffolding the user's half.** When you assemble a draft before they have
written their lines, never put plausible prose in their slot — it will ship in
their voice. Use a loud placeholder with the strawman after it:

    ⚠️ **TODO — replace with your words.** Strawman: <one sentence>

    ---

    🤖 <your half>

An unedited comment then reads as visibly unfinished, and the strawman is right
there to accept or overwrite.

### Editing a draft

You will want to revise your own half after the user reads it. Three facts,
learned the hard way:

- Pending comments **404** on the REST `pulls/comments/{id}` endpoint. They are
  not published comments yet.
- The GraphQL `updatePullRequestReviewComment` mutation edits them fine. Get the
  `node_id` from `pulls/{n}/reviews/{review_id}/comments`.
- Pending comments have **no edit history**. `userContentEdits` is empty, so an
  overwrite is unrecoverable by any means.

The mutation takes a whole body, which makes the rule absolute: **read the
current body first, then splice.** Keep everything above the `---` byte for
byte and replace only the 🤖 block below it. The user edits their half in the
UI while you are working; a body you compose from memory will silently destroy
whatever they wrote since you last looked. If you do clobber their words, say
so immediately and plainly — you cannot recover them, and they need to know to
re-paste rather than discovering it after submit.

To discard a draft entirely:
`gh api repos/{owner}/{repo}/pulls/{n}/reviews/{review_id} --method DELETE`.

### Before and after submitting

The head can move under you. Before submitting, re-read `headRefOid` and
compare it to what you mapped anchors against. After submitting, confirm each
comment came back with a non-null `position` — a force-push between drafting
and submitting can strand comments on a commit nobody is looking at.

    gh api repos/{owner}/{repo}/pulls/{n}/comments \
      --jq '.[] | select(.user.login=="<us>") |
            "\(.path) line=\(.line) commit=\(.commit_id[0:8]) outdated=\(.position==null)"'

## Input channels

**Recto, when it is up.** The user marks up the diff and `recto comments`
drains their notes with path and line already attached. Load the `recto` skill
for the mechanics. Two things carry over from it: comments are delivered
exactly once, so only drain when you are ready to act on them; and `recto
comment` is the user's tool, not yours — never write notes into the set you
are about to drain.

**Conversation, otherwise.** The user says the comments; you keep a running
ledger and ask for an anchor when the target is ambiguous. Read the assembled
review back before posting.

## Other outputs

A review is not only comments.

- **Fixable things can be commits.** Docs gaps, small bugs, missing test cases
   — contributing to the branch is sometimes better than commenting. Pause the
  review, do the work, resume. When the review references our own commits,
  frame them as "we contributed," not as feedback on the author's code.
- **Follow-up tickets are a natural artifact.** Refactoring opportunities,
  coverage gaps, future improvements — offer to file them.

**Offer once, not per finding.** Both of the above are worth raising when they
genuinely beat a comment, and are noise attached to every item on the slate.
Repeating "want me to just fix this?" down a list of six turns a review into a
negotiation about logistics. Make the offer once, for the items where it
actually applies, and take silence as no.

## What you do not do

- Write the user's verdict, or infer it from how the conversation felt
- Volunteer analysis during phase 1
- Edit, tighten, or "improve" their words on the way to posting
- Post a claim you have not traced
- Pad the 🤖 append to look thorough
- Send a comment body you did not just read back first

Most of your work never reaches the post, and that is correct. An hour of
tracing and five minutes of it can both end as a two-sentence approve; the
tracing becomes the confidence behind the user's verdict, not paragraphs
proving it happened.
