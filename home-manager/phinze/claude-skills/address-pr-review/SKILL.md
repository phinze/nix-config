---
name: address-pr-review
description: Work through review feedback on an open pull request. Gather comments from CodeRabbit, biscuit, and human reviewers, plan and implement the fixes, then draft and post replies. Use when asked to address review comments or PR feedback, when a reviewer leaves findings on a PR, or as the handoff from pr-time when a bot review comes back with work.
---

# Address PR Review Feedback

Work through PR review comments: gather data, plan fixes, implement, draft responses, and post.

## Bot Reviewers

Every `mirendev/` PR gets reviewed by two bots. They are both expected, they
behave differently, and confusing one for the other is the usual way this goes
wrong. The differences matter in almost every phase below, so get them straight
first.

**CodeRabbit** (`coderabbitai[bot]`)
- Posts a summary issue comment, plus a review whose body carries actionable
  sections (`🧹 Nitpick comments`, `⚠️ Outside diff range comments`), plus real
  inline review threads.
- **Re-reviews automatically on every push.** Never trigger it manually.
- Auto-resolves its own threads once it sees the fix land in a push.
- Treat its findings as actionable.

**biscuit** (`miren-code-agent[bot]`)
- The name and the login differ. "biscuit" is what we call it, the API returns
  `miren-code-agent[bot]`. There is no biscuit CLI, binary, or repo mention to
  find, so don't go looking for one.
- Its review body opens with `**🍪 biscuit: <verdict>** — auto-review,
  non-blocking` and closes with a link to a full review note. Verdicts are
  `✅ ready to merge` or `⚠️ ready with caveats`.
- Reviews once, about a minute after the PR opens. **It does not re-review on
  push.** To get a fresh pass, comment `/biscuit review` on the PR and wait
  roughly a minute.
- Auto-resolves its own threads, but only when it re-runs. So after pushing
  fixes, a `/biscuit review` is what clears them. Don't reason from CodeRabbit's
  push behavior and conclude biscuit's threads will resolve themselves.
- Findings arrive in two shapes and you need to read both: real inline threads,
  and a markdown `## Inline comments` section inside the review body. When they
  come through the body, GraphQL `reviewThreads` shows nothing from biscuit and
  there is nothing to resolve, just prose to act on.
- It writes long and thinks out loud, sometimes raising a concern under a bold
  heading and then talking itself back out of it in the same paragraph. Read a
  section to its end before turning it into work.
- The verdict is advisory. It never gates the merge.

## Phase 1: Gather Data

Determine the PR to work on:
- If the request names a PR number or URL, use that
- Otherwise, auto-detect from the current branch: `gh pr view --json number,title,url,state,headRefName,baseRefName`

Parse owner/repo from gh (works in both colocated jj+git repos and jj workspaces under `~/workspaces/...` that have no `.git`, since direnv exports `GH_REPO` there):
```bash
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
```

Then gather review data. Read output directly. Do not write to intermediate files. **Run independent commands in parallel.**

### 1a. PR metadata + files changed

```bash
gh pr view $PR_NUMBER --json number,title,body,author,createdAt,updatedAt,state,url,headRefName,baseRefName
```

```bash
gh pr diff $PR_NUMBER --name-only
```

### 1b. Unresolved review threads (inline comments)

Use GraphQL to get only unresolved threads with all their comments. This captures inline review comments attached to specific lines of code.

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 10) {
            nodes {
              databaseId
              body
              author { login }
              path
              line: originalLine
            }
          }
        }
      }
    }
  }
}' | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

The `id` field on each thread node is needed later for resolving threads via the `resolveReviewThread` mutation.

Substitute the actual OWNER, REPO, and PR_NUMBER values. The `jq` filter discards resolved threads immediately so you only work with what matters.

### 1c. Review bodies (catches feedback not attached to lines)

Both bots embed some feedback directly in the review body text rather than as inline comments. These do NOT appear in `reviewThreads`, so you must fetch review bodies separately. **Read both bots' bodies**; skipping one is how findings get missed.

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
  | jq '[.[] | select(.body != null and .body != "") | {id, author: .user.login, state, body}]'
```

Parse each review body's markdown for actionable sections.

From CodeRabbit:
- `🧹 Nitpick comments`: lower-severity suggestions, often in collapsible `<details>` blocks
- `⚠️ Outside diff range comments`: issues in code adjacent to but not part of the diff, often inside `> [!CAUTION]` callouts with suggested diffs
- `🤖 Prompt for all review comments`: aggregated summary of all findings

From biscuit:
- The verdict on the first line, `✅ ready to merge` or `⚠️ ready with caveats`
- A `## Inline comments` section, which is plain markdown in the body rather than
  real review threads. Each entry names a file and line and often carries a
  `🤖 Prompt for AI Agents` block with a suggested change. These are real
  findings with nothing to resolve, so they're easy to skim past. Don't.
- Prose sections like "The one real concern" or "Actual caveat worth accepting
  consciously", which carry the substance. Read each to its end before deciding
  it's work, since biscuit sometimes retracts a concern in the same paragraph it
  raised it.

Treat all of these as review feedback alongside inline threads. They have file paths and line references embedded in the markdown even though they aren't attached to diff lines.

### 1d. Issue comments (general PR conversation, slim format)

```bash
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --paginate \
  | jq '[.[] | {id, author: .user.login, body}]'
```

## Phase 2: Analyze & Plan

Work through ALL review feedback, both inline threads (from 1b) and review body comments (from 1c):

**Inline threads (from GraphQL):** Filter out already-addressed threads. If the PR author's reply is the last comment in a thread and no reviewer responded after it, treat the thread as "likely addressed, pending resolution"; exclude it from the fix plan and note it separately.

**Review body comments (CodeRabbit nitpicks and outside-diff-range items, biscuit's `## Inline comments` and prose concerns):** Parse these from the review body markdown. Each item typically includes a file path, line reference, description, and sometimes a suggested diff. Treat them as additional review items alongside inline threads.

**Attribute every item to its reviewer.** Humans, CodeRabbit, and biscuit each need different handling, so keep the source attached to each item as you plan:
- **Human comments**: Always important. Every human thread gets a reply (acknowledging the fix or explaining why we're skipping) and manual resolution. No bot is auto-resolving these.
- **CodeRabbit**: Assess severity, real issues vs nitpicks. Addressed threads auto-resolve on the next push; skipped ones need a reply and manual resolution.
- **biscuit**: Assess severity the same way, but note its findings are advisory and non-blocking, and that its threads only resolve when it re-runs. Body-embedded items have no thread at all, so they need no reply and no resolution, just the fix (or a conscious decision to skip, worth mentioning in the summary to me even though there's nowhere to post it).

When both bots flag the same thing, fold them into one fix but track both threads, since they clear through different mechanisms.

Present a plan with these sections:

### Already Addressed
- Threads where the PR author already replied / the fix is already in place

### Will Address
- Each item to fix with brief approach
- Name the reviewer (a human, CodeRabbit, or biscuit), since that determines how the thread clears

### Will Skip (with draft responses)
- For each skipped item, draft a brief response explaining why (e.g., "Keeping it simple for now" or "Intentional, here's why...")
- These responses are valuable both as feedback for the bot and for any human reviewing the thread

### How much to run on your own

Most bot review feedback is unambiguous, and stopping to ask about every nil check wastes both our time. Post the plan so I can see it, then **go ahead on the clear-cut items without waiting**. Only actually block on the ones that carry a real decision.

**Go, no need to ask:**
- A fix where the bot is plainly right and the change is local and mechanical (nil check, error wrap, off-by-one, drained body, missing `defer Close`, a test that pins the reported behavior)
- Taking a bot's suggested diff roughly as written
- A pushback where the bot is **factually** wrong: it misread the code, its premise doesn't hold, or it flagged something the diff already handles. Say so plainly in the thread and move on.
- Declining a bot's stylistic nit that cuts against how the surrounding code already reads
- Replies to bot threads, and resolving bot threads

**Stop and ask:**
- Anything on a **human** reviewer's thread. That's a colleague in a conversation, not a bot to dispatch, so drafts get shown (see Phase 4).
- A fix that changes an API, a public interface, on-disk or wire format, or behavior beyond what the finding literally asked for
- A disagreement resting on judgment rather than fact ("this abstraction isn't worth it," "that's out of scope here"), where reasonable people could land either way
- A fix that would meaningfully grow the PR's scope, or that wants a follow-up issue instead
- Skipping something a bot flagged as a real bug, as opposed to a nit
- Anything where you find yourself writing "I think" or "probably" about whether it's the right call

The tell is whether you're choosing between defensible options or just doing the obvious thing. When genuinely torn, ask. When it's obvious, go, and show me what you did in the Phase 7 summary.

## Phase 3: Implement Fixes

Work through the fixes, both the clear-cut ones you're running with and anything I've since approved. Read the relevant source files, make the changes, and verify they look correct.

Land the fixes via jj. Edits autosnapshot into `@`. From there you can either land them as a new rev on top of the PR's last rev with `jj desc -m '<message>'`, or fold them into one of the existing PR revs with `jj squash --into <rev> -u` (the `-u` keeps the destination's message and skips the editor). After landing, push with `jj git push`. If a squash rewrote an already-pushed rev, jj moves the bookmark sideways and the remote updates without complaint.

CodeRabbit auto-resolves its threads when it sees the fix in a new push, so addressed CodeRabbit items generally don't need manual replies or resolution. biscuit's threads don't clear on push; they clear when biscuit re-runs, which Phase 7 handles. Skipped items from either bot need replies (explaining why) and manual resolution. Continue to Phase 4 for any threads that need replies, then Phase 6 to resolve any that remain unresolved.

## Phase 4: Draft Responses

Skip this phase if there are no threads needing replies.

For each comment that needs a reply, write the response text. These include skipped items (human or bot), reviewer questions, and acknowledgments of fixes.

**Bot replies just go.** Acknowledgments ("fixed in the latest push, added the nil check") and factual pushbacks to CodeRabbit or biscuit don't need my eyes first. Write them, post them in Phase 5, and include them in the Phase 7 summary.

**Human replies get drafted and shown.** Anything addressed to a person waits for my go-ahead, as does any reply carrying a judgment-call disagreement from the "stop and ask" list, whoever it's aimed at.

If there's nothing in the second category, skip straight to Phase 5.

Present the drafts that do need review together in a summary like:

```
## Response Drafts

### Reply to @reviewer on file.go:42
> Their comment text...

Draft: "Thanks, fixed in the latest push: added the nil check."

### Reply to @reviewer on file.go:87
> Their comment text...

Draft: "Good point, but keeping it inline for now since it's only used once. Happy to extract if we need it elsewhere."
```

**For those, iterate on wording until approved. Never post a human-facing reply without an explicit go-ahead.**

## Phase 5: Post Responses

Skip this phase if there are no responses to post.

Post bot replies as soon as they're written, in a batch, no need to confirm each one. Post human-facing replies only after approval. Commands:

```bash
# Reply to a review comment thread (in_reply_to = the comment ID being replied to)
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
  -f body="Response text" \
  -F in_reply_to=$COMMENT_ID

# Edit an existing reply (use when revising an approach after already posting)
gh api -X PATCH "repos/$OWNER/$REPO/pulls/comments/$COMMENT_ID" \
  -f body="Updated response text"

# Post a general PR comment
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
  -f body="Response text"
```

**Editing vs. appending:** `in_reply_to` always creates a new comment. It does not replace an existing one. If you need to revise a reply you already posted, use the PATCH endpoint to edit it in place. If appending a follow-up instead, word it as an update (e.g., "Update: we ended up going with X instead") so the thread reads naturally.

Bot replies go out together. Human-facing ones go one at a time, confirming as we go.

## Phase 6: Resolve All Threads

After responses are posted, check for any remaining unresolved threads. CodeRabbit auto-resolves its threads when it sees fixes in a new push, so addressed CodeRabbit items usually resolve themselves. Skipped items that we replied to need manual resolution. The PR review is not considered done until zero unresolved threads remain.

**Leave biscuit's addressed threads alone here.** They resolve when biscuit re-runs, which Phase 7 triggers, and letting it resolve its own threads means it actually re-reads the fix instead of us just closing the thread over it. Only resolve a biscuit thread by hand if it's still open after the re-review in 7c, or if we're skipping the item and have posted a reply explaining why.

First, re-fetch unresolved threads to get their node IDs:

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes {
              databaseId
            }
          }
        }
      }
    }
  }
}' | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | {threadId: .id, commentId: .comments.nodes[0].databaseId}]'
```

Then resolve each thread with the `resolveReviewThread` mutation:

```bash
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "THREAD_NODE_ID"}) {
    thread {
      isResolved
    }
  }
}'
```

Run all resolve mutations in parallel when there are multiple threads. Confirm zero unresolved threads remain before finishing.

## Phase 7: Babysit After Push

After fixes are pushed, stick around and make sure everything actually lands clean. This phase is fully autonomous.

**7a. Watch CI**

Sleep 15 seconds for checks to register, then poll `gh pr checks $PR_NUMBER` every 30 seconds until everything reaches a final status. **Not `--watch`**, which streams and bloats context. **CI always runs**, so zero checks means they haven't registered yet, not that the repo has none; flag it if they're still missing after 5 minutes.

- **All green**: move on to 7b.
- **Failure**: read the logs (`gh run view $RUN_ID --log-failed`). If it's a straightforward fix (lint, formatting, typo, simple test update) and you're confident, write it at `@`, land it (`jj desc -m 'fix CI: <what>'` as its own rev, or `jj squash --into <broken-rev> -u` to fold it into the failing one), `jj git push`, and loop back. **Two auto-fix attempts, then stop.** If the failure reveals something that needs discussion, stop and report instead of burning an attempt.

**7b. Re-trigger biscuit**

CodeRabbit re-reviews itself on the push. biscuit does not, so ask it:

```bash
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" -f body="/biscuit review"
```

This is a bot-facing command on our own PR, not co-authored prose, so just post it. Do it as soon as CI is green (or right after the push, since the re-review is independent of CI) so biscuit's pass runs in parallel with everything else in 7c. Skip it only if biscuit had no findings and we changed nothing it commented on.

**7c. Wait for both bot re-reviews**

**Both bots are always expected on `mirendev/` repos.** Do not bail early assuming one isn't set up, and do not call the pass clean when only one has come back. Poll for up to 5 minutes, every 30 seconds:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
  | jq '[.[] | select(.user.login == "coderabbitai[bot]" or .user.login == "miren-code-agent[bot]")
         | {author: .user.login, submitted_at, body}]'
```

Compare against what was there before our push, per bot. Note that CodeRabbit also posts empty-bodied reviews when it replies inside a thread, so a new entry with an empty body is a reply, not a fresh finding. Check the body before treating it as new.

For each bot's new review:

- **Clean**: CodeRabbit's is just a summary walkthrough with no actionable sections or new inline threads; biscuit's comes back `✅ ready to merge` (or repeats a caveat we've consciously accepted) with nothing new raised. Move on.
- **Has new comments**: Loop back to Phase 1 and work through the new feedback, attributed to whichever bot raised it.

**Polling mechanics**: Check every 30 seconds. Use `sleep 30` between checks. Keep it simple.

**7d. Verify thread resolutions**

Both bots resolve their own threads once they've re-read the code, CodeRabbit on the push and biscuit on the `/biscuit review` from 7b. After both re-reviews have landed, re-fetch unresolved threads to confirm they cleared. If an addressed thread is still open, resolve it manually with the `resolveReviewThread` mutation from Phase 6.

A bot sometimes fails to connect a fix to its thread, usually when the code moved rather than changed in place. That's worth a short reply explaining where the fix went before resolving, so the thread reads correctly for whoever comes through next.

**7e. Flip draft to ready**

Work-repo PRs are opened as drafts (by pr-time) so both bots review before humans get pinged. Once everything above is genuinely clean (7a green, 7c surfaced no new findings from either bot, 7d resolutions confirmed), that bot-first pass is done. Check whether the PR is still a draft:

```bash
gh pr view $PR_NUMBER --json isDraft --jq '.isDraft'
```

If it is, mark it ready for human review:

```bash
gh pr ready $PR_NUMBER
```

This is the moment CODEOWNERS review requests fire, so only reach it when the review is actually clean. If 7c sent you back to Phase 1 for new findings, the flip waits until that loop also lands clean. An outstanding `⚠️ ready with caveats` from biscuit doesn't block the flip, since it's advisory, but say what the caveat was when reporting, and file a follow-up issue if it named a real gap.

**7f. Final gate**

By this point you've read a diff, several review bodies, and a pile of source files, which is exactly when steps get quietly skipped. Before telling me it's done, confirm all four and be able to point at the evidence:

- [ ] CI green
- [ ] `/biscuit review` posted **after the last push**, and biscuit's re-review read. It does not re-review on its own; this is the one that gets forgotten, because CodeRabbit needs no equivalent.
- [ ] CodeRabbit's post-push review read (an empty body is a thread reply, not a finding)
- [ ] Zero unresolved threads

If any one of these is an assumption rather than something you checked, it isn't done. Say which and go check it.

Then summarize what you did on your own authority: the fixes taken, the pushbacks posted, and anything skipped. Phase 2 lets you move without asking, and this summary is what I get in exchange, so it needs to be complete enough that I'd catch a call I disagree with. Flag anything you were less than sure about, even after going ahead with it.

## After Human Approval

An approval that arrives with non-blocking inline notes means "I trust you to
flush this out and merge." Those nits are yours to resolve as you judge best,
including fixing them in the same PR after the approval landed. The approval
carries forward; a moved head commit is not by itself a reason to go back.

Re-request review only when something *major* changed since the approval: a new
direction, a real scope change, or a fix that goes against what the reviewer
actually asked for. Rebases, conflict resolutions, regenerated files, and fixes
taken in the direction the reviewer proposed are none of those, even when they
add real logic. Say what changed in the thread and merge.

Two things still gate the merge regardless of who approved:

- **CI green on the current head**, not on the commit that was approved.
- **`mergeable`**, which drifts to `CONFLICTING` on its own when trunk moves
  under you. Check it rather than assuming, since nothing announces it:
  `gh pr view $PR --json mergeable,mergeStateStatus`. Generated files are the
  usual culprit, and the fix is to rerun the generator rather than hand-edit
  the conflict markers, so `generate-check` vouches for the resolution.

biscuit's verdict is not a gate. It never was, and waiting on a re-review to
merge a human-approved PR is wasted time.

## Response Style
- Concise and friendly
- Acknowledge the reviewer's point even when disagreeing
- Use "we" language (collective ownership)
