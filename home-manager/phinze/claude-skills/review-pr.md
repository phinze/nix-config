# PR Review Skill

Review pull request: $ARGUMENTS

Think hard and carefully about the code changes.

## Instructions

0. **Determine which PR to review**:
   - If a PR number is given in $ARGUMENTS, use that
   - If no PR specified (empty $ARGUMENTS), assume the current branch's PR:
     run `gh pr view --json number,title` to find it
   - If that fails (no PR for current branch), run `gh pr list` and ask

1. **Fetch PR metadata and ensure the branch is local**:
   - Run `gh pr view <number> --json number,title,body,author,baseRefName,headRefName,url`
   - Run `gh pr diff <number>`
   - **Check out the branch locally** if not already on it (`git switch` or
     `gh pr checkout`). Reading the full source files locally — not just the
     diff — is essential for understanding context, tracing call chains, and
     exploring how changes interact with surrounding code.

2. **Summarize the PR**:
   - What is this PR trying to accomplish?
   - Who authored it?
   - What's the scope (files changed, rough size)?

3. **Walk through the changes**:
   - Group changes logically (by feature, by file, or by layer)
   - Explain what each change does
   - **Flag areas to discuss**: things that need clarification, look surprising,
     or where you're not yet sure if something is a concern or just unfamiliar.
     Be honest about confidence level — "I want to understand this better" is
     different from "this looks wrong." Initial impressions often change after
     discussion.
   - **For behavioral/semantic changes** (not just additions): trace through
     the key workflows and scenarios affected. Read the code paths end-to-end,
     not just the diff hunks. This is where the real understanding happens —
     changes that look risky in isolation often compose into a coherent design
     when you see the full flow.

4. **Pause for discussion**:
   - Ask if I have questions or want to dive deeper into any area
   - If we find fixable issues (docs gaps, small bugs, missing test cases),
     discuss whether to contribute a commit to the branch rather than just
     commenting. If so, pause the review, do the work, then resume.
   - When the review references our own contributed commits, frame them as
     "we contributed" not as feedback on the author's code.
   - We'll discuss before drafting comments

5. **Check automated review comments for overlap**:
   - Run `gh api repos/{owner}/{repo}/pulls/{number}/comments` to fetch existing review comments
   - Identify comments from automated code review tools (e.g., bot usernames)
   - Note which of our findings overlap with automated reviewers' findings
   - For overlapping findings, reference agreement in the top-level summary rather than restating inline
   - Keep our inline comments focused on things the automated tools didn't catch

6. **Draft the review**:
   - Open with a brief line that signals this was a collaborative review, not
     a drive-by. Mention what we focused on or how deep we went. The vibe is
     "two people sat down and thought about this together" — but don't use a
     canned template. Let the phrasing fit the review naturally.
   - **Pronouns**: The review posts under the user's GitHub account, so the
     user is "I" and you are "Claude." Write "Claude and I reviewed…" — never
     "[author's name] and I" or "[user's name] and I."
   - Draft a short **top-level comment** summarizing the review
   - Draft **inline comments** for specific lines, formatted as:

~~~markdown
**File**: `path/to/file.go` (line 74)

Your comment text here...
~~~

   - Use a single line number (not ranges) - this is what the API needs

7. **Post when ready**:
   - When I say to post, use `gh api` to submit:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST --input - << 'EOF'
{
  "body": "Top-level comment here",
  "event": "APPROVE",  # or "COMMENT" or "REQUEST_CHANGES"
  "comments": [
    {"path": "path/to/file.go", "line": 74, "body": "Inline comment..."}
  ]
}
EOF
```

**Tone**: Casual and informal — technically rigorous but with moments of
lightness and fun. Use "we" in the spirit of collective code ownership
(e.g., "we could handle..." not "you should..."). Keep it brief; don't
over-explain things the author already knows. Skip nitpicks.

Focus on:
- Questions that clarify intent
- Potential issues or edge cases
- Suggestions worth making
