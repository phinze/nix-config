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

### 1b. Unresolved review threads (primary data source)

Use GraphQL to get only unresolved threads with all their comments. This is the main data source — it gives you resolution status, comment bodies, authors, file paths, and line numbers in one call.

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
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

Substitute the actual OWNER, REPO, and PR_NUMBER values. The `jq` filter discards resolved threads immediately so you only work with what matters.

### 1c. Issue comments (general PR conversation, slim format)

```bash
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" --paginate \
  | jq '[.[] | {id, author: .user.login, body}]'
```

## Phase 2: Analyze & Plan

Work through the unresolved threads from the GraphQL response:

**Filter out already-addressed threads.** If the PR author's reply is the last comment in a thread and no reviewer responded after it, treat the thread as "likely addressed, pending resolution" — exclude it from the fix plan and note it separately.

**Distinguish human vs bot reviewers.** Automated reviewers (CodeRabbit, Copilot, github-actions, etc.) behave differently from humans:
- **Human comments**: Always important — humans took time to write them
- **Bot comments**: Assess severity — real issues vs nitpicks

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

**If all items are being addressed (none skipped):** Bot threads auto-resolve when code changes are pushed. If there are no skipped items and no human threads needing replies, skip Phases 4 and 5.

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

# Post a general PR comment
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
  -f body="Response text"
```

Post one at a time, confirming as we go.

## Response Style
- Concise and friendly
- Acknowledge the reviewer's point even when disagreeing
- Use "we" language (collective ownership)
