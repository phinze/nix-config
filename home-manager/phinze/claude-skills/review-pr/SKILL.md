---
name: review-pr
description: Review someone else's pull request through independent agent understanding, shared orientation, and joint critique, with exact comments co-authored in Recto. Use when asked to review a PR, inspect someone's changes, or work from a PR number or URL.
---

# PR Review Skill

**The user owns the judgment. The user and agent write the review together in
Recto.**

That division is the whole design. You are good at tracing a call chain across
four files and proving whether a thing can happen. The user supplies taste,
context, and the final verdict. Neither person has to write a complete comment
alone. During composition, both edit the same exact public-facing Markdown in
Recto until it says what they mean.

Work in three passes. **First, understand the change independently. Second,
help the user build their own understanding. Third, critique it together and
compare notes before composing comments.** This sequencing keeps explanation
separate from evaluation without asking the agent to stop noticing things.
Candidate concerns found during the first pass stay hypotheses until the joint
critique begins.

Recto holds the working review. GitHub receives the approved artifact.

## Setup

Do this quietly and quickly. It is plumbing, not review.

1. **Find the PR.** If the request names a number or URL, use it. Otherwise
   `gh pr view --json number,title` for the current branch's PR, and if that
   fails, `gh pr list` and ask.

2. **Check the mutex, then claim it.** Fetch metadata including assignees and
   the exact head:

       gh pr view <number> --json number,title,body,author,baseRefName,headRefName,headRefOid,url,assignees

   The assignee is our advisory "I'm reviewing this" lock. If someone other
   than us holds it, stop and surface them by name. Ask whether to pile on or
   back off rather than silently claiming over them. The author self-assigning
   is not a review claim; note it and carry on. If it is unassigned or already
   us, take it with `gh pr edit <number> --add-assignee @me` before reading
   deeply, so the claim is visible early.

3. **Get the branch local.** Fetch the diff with `gh pr diff <number>`, then
   read whole files out of the working tree. The diff alone will not let you
   trace a call chain, and tracing call chains is the job.

   Assume a rig is already sitting on the PR head, because that is where this
   almost always runs. Confirm it rather than checking anything out: compare
   `@-`'s commit id with `headRefOid`. Matching means there is nothing to do.
   Only if they differ, or you are outside a rig, is there a branch to switch
   to. Say so before switching a rig workspace, since its Recto and `rig pr`
   are pointed at that workspace.

4. **Attach the PR to Recto.** In a rig, route through Rig and name the repo:

       rig recto <repo> ping
       rig recto <repo> pr <owner/repo#number>

   Outside a rig, use `recto ping` and `recto pr` directly. Attaching fetches a
   read-only PR snapshot and opens its overview. It does not publish anything.
   If no Recto is listening, continue with the conversation fallback below,
   but say that the shared draft surface is unavailable.

5. **On a stacked PR, fix Recto's base.** If `baseRefName` is not trunk,
   Recto may be showing every PR below this one. Compare `recto ping`'s `files`
   with the PR diff. If they disagree, tell the user to press `b` and set the
   base to `baseRefName`. Recto does not switch bases on its own, and until the
   base is right, focus calls and draft anchors land in the wrong document.

## The head moves

Record the `headRefOid` you mapped. GitHub stamps a commit id on every review
comment for the same reason: the author can force-push while you read.

When a new head is a rebase with identical changes, conclusions may survive,
but anchors still need verification. When the content changed, re-check both.

Recto drafts are deliberately locked to one repository, PR number, and head.
If the head moves while drafts exist, do not delete them merely to make
`recto pr` succeed. Peek with `recto review`, tell the user the slate belongs
to the old head, and decide together whether to port each body to a new anchor
or discard it. Only then delete the old drafts, attach the new snapshot, and
recreate the comments that still apply.

## Phase 1: Agent understanding

Build a causal model of the change before trying to teach or judge it. Read the
author's framing, the whole diff, the surrounding source, relevant history and
tests, CI, and existing reviews. Trace entry points, data and control flow,
changed invariants, failure paths, and the behavior before and after the patch.

This pass is allowed to produce candidate concerns. Treat them as private
hypotheses, not review findings, and do not announce locations or leave
"something here for later" teasers. Their purpose is to make the eventual
critique informed, not to steer the user's first read.

Finish this pass when you can explain the mechanism plainly and answer basic
questions about how the change works. Tell the user you have the change mapped,
then move into the shared walkthrough.

## Phase 2: Shared understanding

Help the user build their own model of the change. Your job is to remove the
tedium from orientation, not to substitute your judgment for theirs.

### Hand over the map

Open with facts they would otherwise spend ten minutes assembling:

- What the change is trying to do, in the author's framing, and who wrote it
- Scope: files, rough size, and how the changes group
- Structural facts: what is new, edited, or deleted, and whether the base is a
  stacked branch or trunk
- CI state, and whether a bot reviewed the current head
- On a re-review, what landed since our last review and what the author said in
  reply

Then explain the mechanism you mapped. Understanding can be analytical: "the
replay buffer sits between the reader and decoder, stores complete frames, and
drains on reconnect." Critique evaluates it: "the replay buffer can lose the
last frame and should drain before reconnect." Keep the walkthrough on the
first side of that line.

### Be on call

Then stop talking and answer things. The user reads; you trace. Where does
this field get set, does this path ever run, who else writes this, what did
this look like before. Read the actual source, run a repro, and check the
adjacent subsystem. Most of this work should never appear in the posted
review.

The user closes this pass when they say they are oriented, ask to compare
notes, start evaluating the design, or ask a question such as "is this safe?"
An evaluative question naturally opens joint critique.

## Phase 3: Joint critique and composition

### Compare notes

Invite the user's critique slate first by default, so your hypotheses do not
anchor their read. If they ask for your take first, give it. Then put your
candidate concerns beside theirs all at once and sort the combined slate into
overlap, user-only observations, agent-only observations, and genuine
disagreements.

Investigate the candidates together. Verify each against the current head,
discard what does not survive inspection, and refine what does. Neither slate
is privileged, and a disagreement is something to resolve with code and
evidence rather than authorship.

Once a point survives that comparison, compose its public wording in Recto.

### One shared slate

The exact body that may become public lives in Recto's shared review draft.
It is session-durable, local-only, and safe to read repeatedly:

    recto review

In a rig, use `rig recto <repo> review`. The response carries the PR identity,
head oid, stable comment ids, anchors, bodies, and `last_editor`.
`last_editor` coordinates concurrent editing; it is not public attribution and
cannot tell you who authored the words already present.

The user creates or opens a yellow shared draft with `c` on a diff line, Enter
on its file-pane child row, or a double click in either pane. You can create
one from the companion side:

    recto review-comment 'path/to/file.go:99=Draft Markdown'

Revise the same object by stable id:

    recto review-comment --id 7 'Revised Markdown'

An empty replacement deletes it. Every mutation returns the complete updated
draft, so read that response rather than assuming the write landed.

### Work comment by comment

Use this loop for each finding:

1. Read the current body with `recto review` immediately before touching it.
2. Verify the technical claim against the current head and real runtime paths.
3. Discuss the point as needed, then revise the shared body directly when the
   direction is clear. If the wording choice is genuinely open, offer the
   alternatives before writing.
4. Read back the mutation response. Briefly name any substantive change you
   made and whether it changes the authorship class, so the user knows what to
   inspect in Recto.
5. Let the user edit it in place. Re-peek before the next agent revision.

Do not edit several ids from one stale snapshot. `review-comment --id`
replaces the whole body, so a delayed write can overwrite a user edit even
though reads are non-consuming. One comment at a time keeps the collaboration
legible and the race window small.

### Mark the actual authorship

Recto is a shared editor, but not every comment is co-written. Classify each
public body by how its prose was actually authored:

1. **Totally human-written:** post the user's words unadorned. Agent research,
   verification, or typo spotting does not claim authorship of prose the user
   wrote.
2. **Co-written as one voice:** use the jointly revised body and sign it at the
   end with `--p+🤖`.
3. **Totally agent-written:** prefix the body with `🤖`.
4. **Human prefix, agent continuation:** keep the user's opening unmarked,
   then separate and mark the agent-authored continuation:

       The retry should stay bounded by the request deadline.

       ---

       🤖 `pollUntilReady` receives the parent context here, but the loop calls
       `time.Sleep`, so cancellation is not observed until the next poll.

The fourth class is deliberately different from fused co-authorship. It lets
the reader see where the human framing ends and the agent-supplied trace
begins. Do not add both the split marker and the `--p+🤖` signoff.

Preserve wording the user chose deliberately. When both people have revised a
single voice, call it co-written rather than pretending the final prose is
untouched human text. Conversely, investigation behind a human-written
sentence does not require a robot mark. Track the class in the conversation;
`last_editor` only identifies the most recent keystrokes.

Incomplete drafts may use a loud `TODO`, because they are local. A `TODO` is a
hard publication blocker, not plausible text that can accidentally ship.

### Verify every claim

A claim earns its place only when you have traced it to a real runtime path.
It is not enough that a problem exists in the type-space; check whether any
production path reaches it. Say plainly when a claim does not survive, and say
it before polishing the prose.

When a contested claim reduces to pure logic such as formatting, hashing,
comparison, ordering, or parsing, copy the actual function into a scratch
program and run it. A transcript settles competing assertions better than
another paragraph. If the review body says you ran something, actually run it
and state the scope precisely.

Check each comment against current code, not only the original diff.
Multi-commit PRs often fix a problem later in the stack.

### Triage overlap

Fetch existing inline comments with:

    gh api repos/{owner}/{repo}/pulls/{number}/comments

Tell the user when a human or bot already caught the same issue so the shared
draft is not a duplicate. This is mostly triage; a bot belongs in the public
body only when the agreement or disagreement changes the substance.

## Verdict and top-level summary

The verdict is the user's call. Almost always use **APPROVE** or
**REQUEST_CHANGES**, not COMMENT. Default to APPROVE with comments; trust the
author to address or consciously skip non-blocking feedback. Save
REQUEST_CHANGES for a specific blocking concern. If we take the pen and push
commits ourselves, request changes while those commits are outstanding, then
approve once they land.

Recto currently owns inline comment drafts, not the top-level review body.
Compose that short summary in conversation, show its exact final text, and
apply the same four-way authorship classification. A co-written summary ends
with `--p+🤖`; a human-written one is unadorned; an agent-written one starts
with `🤖`; a human prefix plus agent continuation uses the split form.

## Publication boundary

No Recto authoring command posts to GitHub. Publishing is a separate,
explicitly approved action.

Before asking to send:

1. Re-read `headRefOid`, local `@-`, and `recto review`'s
   `pull_request.head_oid`. All three must name the head whose code and anchors
   you verified.
2. Re-check every path and line against that head. Reject empty bodies and any
   remaining `TODO`.
3. Confirm each inline body and the top-level summary carry the marker for
   their actual authorship class. Do not infer this from `last_editor`.
4. Fetch existing comments one last time for duplicate or newly resolved
   findings.
5. Build the exact review payload. Set `commit_id` explicitly. For a one-line
   current-side comment, use `line` and `side: "RIGHT"`. For a Recto range,
   preserve both ends with `start_line`, `start_side: "RIGHT"`, `line`, and
   `side: "RIGHT"`.
6. Show the user the exact verdict, top-level body, authorship class, and every
   inline body in posting order. Wait for an explicit send confirmation.

Then post one final review:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST --input review.json
```

```jsonc
{
  "commit_id": "<verified head oid>",
  "body": "Top-level summary\n\n--p+🤖",
  "event": "APPROVE",
  "comments": [
    {
      "path": "path/to/file.go",
      "line": 74,
      "side": "RIGHT",
      "body": "Exact co-written Recto body\n\n--p+🤖"
    },
    {
      "path": "path/to/other.go",
      "start_line": 80,
      "start_side": "RIGHT",
      "line": 84,
      "side": "RIGHT",
      "body": "Exact shared Recto range body"
    }
  ]
}
```

Set `event` to the user's chosen verdict: `APPROVE`, `REQUEST_CHANGES`, or
`COMMENT`. If the user explicitly chooses a separate GitHub staging step,
omit `event` to create a pending review.

After posting, confirm each returned or listed comment has the intended body,
commit id, path, and a non-null position. A force-push between assembly and
send can strand an anchor. Only after GitHub reflects the complete artifact
should you offer to clear the corresponding local drafts from Recto. Delete
them after the user agrees. If posting or verification fails, leave the drafts
intact.

## Input channels

### Shared review drafts

`recto review` is the primary composition channel. It is a peek, never a
drain. Agent and user edits converge on the same stable comment ids.

### Private agent notes

Peach private notes are direction from the user to the local agent, not public
prose. `recto ping` reports them as `pending_comments`. Drain with
`recto notes` only when the user says they are ready for action; draining is
destructive and each note is delivered exactly once. Never move a private note
into the public draft by assumption. Discuss it, verify it, then deliberately
create a shared yellow draft if that is where it belongs.

Do not use `recto note` yourself. The user owns that inbound channel; use
conversation or Recto annotations for your side.

### Conversation fallback

If Recto is unavailable, keep an explicit ledger of exact bodies and anchors
in conversation. Work comment by comment with the same verification loop, then
read the complete assembled review back before posting.

## Other outputs

A review is not only comments.

- Fixable things can be commits. Docs gaps, small bugs, and missing tests may
  be better as contributions to the branch. Pause the review, do the work, and
  resume. When the review references those commits, frame them as "we
  contributed," not as feedback on the author's code.
- Follow-up tickets are natural artifacts for refactors, coverage gaps, and
  future improvements.

Offer either once where it genuinely beats a comment. Repeating "want me to
fix this?" after every finding turns review into logistics negotiation.

## What you do not do

- Infer or write the user's verdict
- Volunteer critique during shared understanding
- Treat either person's first wording as untouchable
- Post a claim you have not traced
- Overwrite a shared body you did not just re-read
- Mislabel authorship based on who happened to edit last
- Promote a private agent note into public prose by assumption
- Send a review artifact the user has not inspected in full and approved

Most of your work never reaches the post, and that is correct. An hour of
tracing and five minutes of it can end as a two-sentence approval. The tracing
becomes the confidence behind the shared words, not paragraphs proving it
happened.
