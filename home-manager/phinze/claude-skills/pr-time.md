# Ship a PR

Let's get this work shipped! Create a commit and PR for the current changes.

## Style Guide
- **Concise, informal, casual, narrative** - like explaining to a coworker
- No need to restate the diff in detail
- No test plan section
- Focus on the "why" and the story, not the "what"

## Steps

1. **Check the state**: Run `git status` and `git diff` to see what we're working with

2. **Draft the commit message**:
   - First line: short summary (imperative mood)
   - Body: brief narrative of what was wrong and how we fixed it

3. **Draft the PR**:
   - **Title**: Same as commit first line (or slightly more descriptive)
   - **Description**: Casual narrative - what happened, why it was a problem, what we did about it

4. **Show me the draft** and ask "Look good?" - wait for approval before proceeding

5. **After approval**: Commit, push, and create the PR with `gh pr create`

## Example Output Format

```
Commit message:
Fix the thing that was broken

Found that X was causing Y. Fixed by doing Z instead.

PR title:
Fix the thing that was broken

PR description:
Noticed this morning that X wasn't working right. Turns out Y was
happening because of Z. Switched to A approach which handles this
better.

Look good?
```
