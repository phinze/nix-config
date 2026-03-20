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

4. **Pause for walkthrough discussion**:
   - **This is the main event, not a preamble.** The walkthrough is where
     real understanding happens — ask if I want to go chunk by chunk, or if
     the PR is simple enough to skip straight to drafting.
   - Ask if I have questions or want to dive deeper into any area
   - If we find fixable issues (docs gaps, small bugs, missing test cases),
     discuss whether to contribute a commit to the branch rather than just
     commenting. If so, pause the review, do the work, then resume.
   - When the review references our own contributed commits, frame them as
     "we contributed" not as feedback on the author's code.
   - **Follow-up tickets are a natural output.** If we identify work worth
     tracking (refactoring opportunities, missing test coverage, future
     improvements), offer to file tickets. These are valuable review artifacts
     beyond just the PR comments.
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
   - **Pronouns and voice**: The review posts under the user's GitHub account.
     Use "Claude and [user's first name]" (e.g., "Claude and Paul here").
     The user is a real person with opinions and feelings about the work —
     let those come through explicitly. If the user expressed admiration,
     excitement, or concerns during the walkthrough, attribute those to them
     by name. Claude provides technical analysis and design observations.
     The reader should be able to tell who thinks what — not a weird amalgam
     where it's unclear whether a compliment is from a human or a bot.
   - Draft a short **top-level comment** summarizing the review
   - Draft **inline comments** for specific lines, formatted as:

~~~markdown
**File**: `path/to/file.go` (line 74)

Your comment text here...
~~~

   - Use a single line number (not ranges) - this is what the API needs

7. **Verify before posting**:
   - **Check each inline comment against the actual current code** (not just
     the diff). Multi-commit PRs may have fixed issues in later commits.
     Read the file at the target line to confirm the comment still applies.
   - Confirm the event type with the user. Almost always either **APPROVE**
     or **REQUEST_CHANGES** — never COMMENT (it's a non-action). Default to
     APPROVE with comments; we trust authors to address or consciously skip
     feedback. Use REQUEST_CHANGES only when there's a specific blocking
     concern, and clearly explain what needs to be resolved.

8. **Post when ready**:
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

**Tone**: We're colleagues who genuinely enjoy each other's code. Be
playful — genuine enthusiasm when something's clever, a little weirdness
where it fits, don't be performatively professional. Technical rigor and
warmth coexist naturally. Use "we" in the spirit of collective code
ownership (e.g., "we could handle..." not "you should..."). Keep it brief;
don't over-explain things the author already knows. Skip nitpicks. The
review should feel like it was fun to write.

When drafting, distill the user's voice from the walkthrough discussion
and let it come through in the review. If they were excited about
something, that excitement should land. If they were skeptical, that
skepticism should land. The review is the user's voice amplified by
Claude's analysis — not Claude's voice with the user's name on it.

Focus on:
- Questions that clarify intent
- Potential issues or edge cases
- Suggestions worth making
