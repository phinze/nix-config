# Address PR Review Feedback

Work through PR review comments: gather data, plan fixes, implement, draft responses, and post.

## Phase 1: Gather Data

Determine the PR to work on:
- If `$ARGUMENTS` is provided, use it as the PR number
- Otherwise, auto-detect from the current branch: `gh pr view --json number,title,url,state,headRefName,baseRefName`

Parse owner/repo from the git remote:
```bash
git config --get remote.origin.url
```

Then gather review data. Read output directly — do NOT write to intermediate files. **Run independent commands in parallel.**

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

Bot reviewers like CodeRabbit embed some feedback directly in the review body text rather than as inline comments. This includes nitpick comments (`🧹 Nitpick comments`) and outside-diff-range comments (`⚠️ Outside diff range comments`). These do NOT appear in `reviewThreads` — you must fetch review bodies separately.

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
  | jq '[.[] | select(.body != null and .body != "") | {id, author: .user.login, state, body}]'
```

Parse the review body markdown for actionable sections. Look for headings/sections like:
- `🧹 Nitpick comments` — lower-severity suggestions, often in collapsible `<details>` blocks
- `⚠️ Outside diff range comments` — issues in code adjacent to but not part of the diff, often inside `> [!CAUTION]` callouts with suggested diffs
- `🤖 Prompt for all review comments` — aggregated summary of all findings

Treat nitpick and outside-diff-range items as review feedback alongside inline threads. They have file paths and line references embedded in the markdown even though they aren't attached to diff lines.

### 1d. Issue comments (general PR conversation, slim format)

```bash
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --paginate \
  | jq '[.[] | {id, author: .user.login, body}]'
```

## Phase 2: Analyze & Plan

Work through ALL review feedback — both inline threads (from 1b) and review body comments (from 1c):

**Inline threads (from GraphQL):** Filter out already-addressed threads. If the PR author's reply is the last comment in a thread and no reviewer responded after it, treat the thread as "likely addressed, pending resolution" — exclude it from the fix plan and note it separately.

**Review body comments (nitpicks + outside-diff-range):** Parse these from the review body markdown. Each item typically includes a file path, line reference, description, and sometimes a suggested diff. Treat them as additional review items alongside inline threads.

**Distinguish human vs bot reviewers.** Automated reviewers (CodeRabbit, Copilot, github-actions, etc.) behave differently from humans:
- **Human comments**: Always important. Every human thread gets a reply (acknowledging the fix or explaining why we're skipping) and manual resolution. No bot is auto-resolving these.
- **Bot comments**: Assess severity — real issues vs nitpicks. Addressed bot threads auto-resolve on push; skipped ones need a reply and manual resolution.

Present a plan with these sections:

### Already Addressed
- Threads where the PR author already replied / the fix is already in place

### Will Address
- Each item to fix with brief approach
- Note whether the commenter is human or bot

### Will Skip (with draft responses)
- For each skipped item, draft a brief response explaining why (e.g., "Keeping it simple for now" or "Intentional — here's why...")
- These responses are valuable both as feedback for the bot and for any human reviewing the thread

**Wait for approval before proceeding.**

## Phase 3: Implement Fixes

Work through the approved fixes. Read the relevant source files, make the changes, and verify they look correct.

Bot reviewers like CodeRabbit will auto-resolve their threads when they see the fix in a new push, so addressed items generally don't need manual replies or resolution. Skipped items do need replies (explaining why) and manual resolution. Continue to Phase 4 for any threads that need replies, then Phase 6 to resolve any that remain unresolved.

## Phase 4: Draft Responses

Skip this phase if there are no threads needing replies.

For each comment that needs a reply — skipped items (human or bot), questions from reviewers, acknowledgments of fixes — draft the response text.

Present ALL drafts together in a summary like:

```
## Response Drafts

### Reply to @reviewer on file.go:42
> Their comment text...

Draft: "Thanks, fixed in the latest push — added the nil check."

### Reply to @reviewer on file.go:87
> Their comment text...

Draft: "Good point, but keeping it inline for now since it's only used once. Happy to extract if we need it elsewhere."
```

**Iterate on wording until approved. Never post without explicit go-ahead.**

## Phase 5: Post Responses

Skip this phase if there are no responses to post.

Only after explicit approval, post responses using these commands:

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

**Editing vs. appending:** `in_reply_to` always creates a new comment — it does not replace an existing one. If you need to revise a reply you already posted, use the PATCH endpoint to edit it in place. If appending a follow-up instead, word it as an update (e.g., "Update: we ended up going with X instead") so the thread reads naturally.

Post one at a time, confirming as we go.

## Phase 6: Resolve All Threads

After responses are posted, check for any remaining unresolved threads. Bot reviewers like CodeRabbit will auto-resolve their threads when they see fixes in a new push, so addressed items usually resolve themselves. Skipped items that we replied to need manual resolution. The PR review is not considered done until zero unresolved threads remain.

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

Wait for checks to register and complete. **CI always runs** — if you see zero checks, it means they haven't registered yet, not that the repo has no CI.

Wait 15 seconds after the push before the first poll to give GitHub time to register checks. Then poll with:

```bash
gh pr checks $PR_NUMBER
```

Parse the output to determine status. Keep polling every 30 seconds until all checks have a final status (pass/fail, not pending). **Do not use `--watch`** — it streams continuous output that bloats context. A simple poll loop is better.

If after 2 minutes you still see zero checks, that's unexpected — mention it but keep waiting (up to 5 minutes total before flagging it as a real problem).

Once checks resolve:

- **All green**: Move on to 7b.
- **Failure**: Read the failed check's logs (`gh run view $RUN_ID --log-failed`). Assess the failure:
  - If it's a straightforward fix (lint, formatting, typo, simple test update) and you're confident in the fix: fix it, commit, push, and loop back to watch CI again. **You get up to two auto-fix attempts.**
  - If the failure reveals a real issue that needs discussion, or if you've already used both auto-fix attempts: stop and report the situation.

**7b. Verify CodeRabbit resolutions**

After the push, CodeRabbit should auto-resolve threads for issues we fixed. Give it up to 2 minutes, then re-fetch unresolved threads to confirm they cleared. If any addressed threads are still unresolved, resolve them manually with the `resolveReviewThread` mutation from Phase 6.

**7c. Check for new CodeRabbit comments**

The new push may trigger a fresh CodeRabbit review with new findings. **CodeRabbit is always expected on `mirendev/` repos** — do not bail early assuming it's not set up. Poll for it (up to 5 minutes, every 30 seconds):

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
  | jq '[.[] | select(.user.login == "coderabbitai")]'
```

Compare the review list against what was there before our push. If a new review appeared:

- **Clean**: Just a summary walkthrough, no actionable sections or new inline threads. Report that everything is green and clean.
- **Has new comments**: New actionable sections (`🧹 Nitpick comments`, `⚠️ Outside diff range comments`) or new inline threads from CodeRabbit. Loop back to Phase 1 and work through the new feedback.

**Polling mechanics**: Check every 30 seconds. Use `sleep 30` between checks. Keep it simple.

## Response Style
- Concise and friendly
- Acknowledge the reviewer's point even when disagreeing
- Use "we" language (collective ownership)
