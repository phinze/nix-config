# Ship a PR

Let's get this work shipped! Create a commit and PR for the current changes.

## Style Guide
- Focus on the "why" and the journey: what was the situation, what was wrong with it, how did we make it better
- No need to exhaustively restate the diff; trust the reader to look at the code
- No test plan section

## Steps

1. **Check the state**: Run `git status` and `git diff` to see what we're working with

2. **Consider the commit structure**: Look at the changes and decide whether they tell one story or several. If there's a natural separation (e.g. a refactor that enables a feature, a helper extraction + the thing that uses it), split them into multiple commits that build on each other. Don't force it — one commit is fine when the changes are cohesive.

3. **Draft the commit(s)**:
   - Each commit: short summary line (imperative mood) + brief narrative body
   - If multiple commits, they should read as a logical sequence
   - **Formatting**: Hard-wrap body text at 72 characters — this is standard git convention and ensures readability in `git log`, terminals, and email patches

4. **Draft the PR**:
   - **Title**: High-level summary of the whole change
   - **Description**: Casual narrative - what happened, why it was a problem, what we did about it. If there are multiple commits, the PR description can reference the progression.
   - **Formatting**: Do NOT hard-wrap lines. PR descriptions are rendered as markdown, so write flowing paragraphs that reflow naturally in the browser. Hard line breaks in the middle of sentences look broken on GitHub.

5. **Show me the draft** and ask "Look good?" - wait for approval before proceeding

6. **After approval**: Stage and commit (using `git add -p` or specific files to separate commits if needed), push, and create the PR with `gh pr create`

7. **Babysit the PR**: After the PR is created, stick around and shepherd it through CI and automated review. This phase is fully autonomous — no need to check in unless something needs human judgment.

   **7a. Watch CI**

   Wait for checks to register and complete. **CI always runs** — if you see zero checks, it means they haven't registered yet, not that the repo has no CI.

   Wait 15 seconds after the push before the first poll to give GitHub time to register checks. Then poll with:

   ```bash
   gh pr checks $PR_NUMBER
   ```

   Parse the output to determine status. Keep polling every 30 seconds until all checks have a final status (pass/fail, not pending). **Do not use `--watch`** — it streams continuous output that bloats context. A simple poll loop is better:

   ```
   sleep 15  # initial grace period for checks to register
   # then loop: gh pr checks, parse, sleep 30, repeat
   ```

   If after 2 minutes you still see zero checks, that's unexpected — mention it but keep waiting (up to 5 minutes total before flagging it as a real problem).

   Once checks resolve:

   - **All green**: Move on to 7b.
   - **Failure**: Read the failed check's logs (`gh run view $RUN_ID --log-failed`). Assess the failure:
     - If it's a straightforward fix (lint, formatting, typo, simple test update) and you're confident in the fix: fix it, commit, push, and loop back to watch CI again. **You get up to two auto-fix attempts.**
     - If the failure reveals a real issue that needs discussion, or if you've already used both auto-fix attempts: stop and report the situation. Show what failed, what you tried (if anything), and what you think the options are.

   **7b. Wait for CodeRabbit review**

   Poll for CodeRabbit's review to arrive. CodeRabbit is usually fast (under a minute), but give it up to 5 minutes. **CodeRabbit is always expected on `mirendev/` repos** — do not bail early assuming it's not set up.

   ```bash
   gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
     | jq '[.[] | select(.user.login == "coderabbitai[bot]")]'
   ```

   Poll every 30 seconds. Once the review lands, determine if it has actionable findings:

   - **Clean review**: The review body is just a summary walkthrough with no actionable sections. No nitpick comments, no outside-diff-range warnings, no inline review threads from CodeRabbit. Report that CI is green and CodeRabbit is clean — we're done.
   - **Has real comments**: The review body contains actionable sections (`🧹 Nitpick comments`, `⚠️ Outside diff range comments`) or CodeRabbit left inline review threads. Report what was found and kick off `/address-pr-review` to work through the feedback.

## Examples

### Single commit (when changes are cohesive)

```
Commit message:
Fix the thing that was broken

X was causing Y, which meant users would hit Z whenever they tried to
do W. Pulled the shared logic out into its own helper so both paths
go through the same flow now.

PR title:
Fix the thing that was broken

PR description (note: flowing paragraphs, no hard line breaks):
We had this annoying gap where X would work fine in one context but fall over in another. The root cause was that the two code paths had diverged — one got the nice treatment and the other was still doing things the old way.

Pulled the common logic into a shared helper so they both behave consistently now. The end result is that users get the same experience regardless of which path they come through.

Closes PROJ-123
```

### Multiple commits (when there's a natural separation)

```
Commit 1 (api/app/envvar.go, api/app/server.go):
Extract shared env var mutation logic into helper

The deployment server and app server both needed to do the same env
var dance, but each had its own copy. Pulled the common bits into
envvar.go so we have one path to maintain.

Commit 2 (remaining files):
Route env set/delete through deployment service

Now that the env var logic is shared, we can add SetEnvVars and
DeleteEnvVars to the deployment service. This means the CLI gets
back a deployment record and can poll for activation and show routes,
just like deploy and rollback already do.

PR title:
Route env set/delete through deployment service for post-deploy UX

PR description (note: flowing paragraphs, no hard line breaks):
`env set` and `env delete` were the odd ones out — they'd create a new version and bail immediately, while `deploy` and `rollback` both watch activation and print routes. Felt like a gap worth closing.

First commit pulls the shared env var mutation logic into its own helper, then the second commit uses that to wire up new RPCs on the deployment service. End result is all four commands give you the same "watch it roll out and show you the routes" experience.

Closes PROJ-123
```
