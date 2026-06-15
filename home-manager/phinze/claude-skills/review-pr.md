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
   - This overlap is mostly for our own triage, so we don't restate inline what
     a bot already caught. It rarely belongs in the posted review at all —
     mention a bot only when the agreement or disagreement actually changes the
     verdict.
   - Keep our inline comments focused on things the automated tools didn't catch

6. **Draft the review**:
   - **Lead with the verdict.** The first sentence is the most load-bearing
     finding or the overall call, not a roll call ("Claude and Paul here")
     or a methodology recital ("we traced..."). Attach evidence to claims
     instead of front-loading it: "auth chain fails closed everywhere
     (traced end to end, including the Ctrl-C flush path)" beats "we
     traced the auth chain end to end. It's solid."
   - **Sign off with `--p+🤖`.** That's the standing marker that Claude was
     involved; no per-review announcement needed. Mention Claude by name in
     the body only when attribution is doing real work for a specific
     judgment (e.g., "Claude rebuilt the token model from scratch before
     we reviewed").
   - **Pronouns and voice**: The review posts under the user's GitHub account
     and should read as collaborative: Claude's analysis plus the user's
     judgment. If the user expressed admiration, excitement, or concerns
     during the walkthrough, that should come through in the prose.
   - Draft a short **top-level comment** summarizing the review. Default
     shape: a few sentences. When there are multiple inline comments, add
     a triage line so the author knows where to start (e.g., "inline
     notes below; the org-boundary one is the only one with teeth").
     Long-form architectural discussion belongs in inline comments,
     follow-up tickets, or a direct conversation — not the review body.
     A longer top-level is fine only when every paragraph is verified
     and load-bearing.
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
   - **Verify a flagged issue can actually occur at runtime, not just that it
     exists in the code's type-space.** Before raising (or worse, contributing
     a fix for) a problem, trace whether any real path reaches it. We once
     drafted and tested a fix for a "recurring error log" that couldn't fire
     under the actual single-subnet allocator — the condition existed in the
     types but no production path produced it. A guard for an unreachable case
     is speculative code, and a review comment claiming an observed problem
     that can't happen is just wrong.
   - Confirm the event type with the user. Almost always either **APPROVE**
     or **REQUEST_CHANGES** — never COMMENT (it's a non-action). Default to
     APPROVE with comments; we trust authors to address or consciously skip
     feedback. Use REQUEST_CHANGES only when there's a specific blocking
     concern, and clearly explain what needs to be resolved.
   - **If we're taking the pen** (pushing commits to the branch), the
     review that announces it should be REQUEST_CHANGES from the start so
     the mechanical state matches the intent — no approve-then-flip dance.
     Flip to APPROVE once our commits have landed.

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

**Tone: respect the reader.** Every choice in the review serves the
person who has to act on it. That cashes out three ways:

- **Don't make claims we haven't verified.** "We traced the auth chain"
  means we traced it. If something is a hunch or an open question, frame
  it as one. Confidence labels help the reader triage; they aren't
  hedging.
- **Don't write three sentences when one will do.** But don't
  over-compress either: if meaning or intent requires decoding, the
  compression failed just as badly as padding would have. The test is a
  single read: the author should come away knowing what we think and
  what to do about it.
- **Say operational things plainly.** "We're going to push commits,
  hold off merging" is a coordination signal, not prose. It goes in the
  first sentence, in plain words, never inside a joke or metaphor.
- **Most of the analysis is for you, not the review.** The depth you go
  to build confidence — tracing call chains, sizing a concurrency
  question, drafting a fix you then abandon — usually earns no words in
  the post. Trace deep, post narrow. An hour-long review and a
  five-minute one can both correctly land as "LGTM"; the work shows up as
  the *confidence* behind the verdict, not as paragraphs proving you did
  it.

Friendly, fun, and informal lives in how individual sentences are
phrased, not in how many there are. Genuine enthusiasm when something's
clever. Humor is a garnish (a line, an emoji), never the structure;
extended bits and themes are out — we once lost a real "we're taking
the pen" signal inside one and collided with the author's own pushes.

Use "we" in the spirit of collective code ownership (e.g., "we could
handle..." not "you should..."). Skip nitpicks.

**Don't narrate the change back to the author.** Walking through what
each part of the PR does just restates their own description — they wrote
it, they know it. Spend words only on judgment, gaps, and things they
can't see from their own diff.

When drafting, distill the user's voice from the walkthrough discussion
and let it come through in the review. If they were excited about
something, that excitement should land. If they were skeptical, that
skepticism should land. The review is the user's voice amplified by
Claude's analysis — not Claude's voice with the user's name on it.

Focus on:
- Questions that clarify intent
- Potential issues or edge cases
- Suggestions worth making

If tracing already answered a question, don't pose it as a question —
that makes the author re-derive what you already know. State it as an
observation, or if it just confirms things are fine, cut it.
