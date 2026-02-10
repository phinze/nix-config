# PR Review Skill

Review pull request: $ARGUMENTS

Think hard and carefully about the code changes.

## Instructions

0. **If no PR specified** (empty $ARGUMENTS):
   - Run `gh pr list` to show open PRs
   - Ask which one I'd like to review
   - Continue with the selected PR number

1. **Fetch PR metadata and diff**:
   - Run `gh pr view $ARGUMENTS --json number,title,body,author,baseRefName,headRefName,url`
   - Run `gh pr diff $ARGUMENTS`

2. **Summarize the PR**:
   - What is this PR trying to accomplish?
   - Who authored it?
   - What's the scope (files changed, rough size)?

3. **Walk through the changes**:
   - Group changes logically (by feature, by file, or by layer)
   - Explain what each change does
   - **Flag areas of concern**: complexity, edge cases, security issues, missing tests, unclear intent, potential bugs

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
   - Start the top-level comment with a brief co-author intro:
     "Paul & Claude here from a review session where we [1-sentence summary of what we did]. Here's where we landed:"
   - This sets context that the review was collaborative, not a drive-by
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

**Tone**: Concise, informal, and friendly. Use "we" pronouns in the spirit of collective code ownership (e.g., "we might want to handle..." not "you should...").

Focus on:
- Questions that clarify intent
- Potential issues or edge cases
- Suggestions for improvement (not nitpicks)
