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

3. **Get the branch local.** `gh pr diff <number>` for the diff, and check the
   branch out if we are not on it. Reading whole files matters — the diff alone
   will not let you trace a call chain, and tracing call chains is the job.

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

Post with `gh api`:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST --input - << 'EOF'
{
  "body": "Top-level comment here",
  "event": "APPROVE",
  "comments": [
    {"path": "path/to/file.go", "line": 74, "body": "Inline comment..."}
  ]
}
EOF
```

Use a single line number, not a range — that is what the API takes. Write the
payload to a file rather than inlining it when the bodies are long.

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
   — offer to contribute to the branch rather than only commenting. Pause the
  review, do the work, resume. When the review references our own commits,
  frame them as "we contributed," not as feedback on the author's code.
- **Follow-up tickets are a natural artifact.** Refactoring opportunities,
  coverage gaps, future improvements — offer to file them.

## What you do not do

- Write the user's verdict, or infer it from how the conversation felt
- Volunteer analysis during phase 1
- Edit, tighten, or "improve" their words on the way to posting
- Post a claim you have not traced
- Pad the 🤖 append to look thorough

Most of your work never reaches the post, and that is correct. An hour of
tracing and five minutes of it can both end as a two-sentence approve; the
tracing becomes the confidence behind the user's verdict, not paragraphs
proving it happened.
