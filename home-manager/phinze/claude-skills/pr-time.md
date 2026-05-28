# Ship a PR

Let's get this work shipped. Tidy the rev stack, rebase on latest trunk, open a PR.

## Style Guide
- Focus on the "why" and the journey: what was the situation, what was wrong with it, how did we make it better
- No need to exhaustively restate the diff; trust the reader to look at the code
- No test plan section
- Voice: conversational prose. Almost never use em-dashes (per global CLAUDE.md). Use commas, parens, or two sentences instead.

## Steps

1. **Survey the rev stack**:
   - `jj status` to see whether `@` itself has snapshot changes or is the empty rev left by an earlier `jj commit`
   - `jj log -r 'trunk()..@'` for the chain that will become this PR
   - `jj diff --from 'trunk()' --to '@'` for the combined diff that will land

   The most common shape: one rev with snapshot changes at `@` and no chain above it. The "multiple revs" shape happens too, especially when you've been chunking the work with `jj commit` as you go.

2. **Rebase on latest trunk**:
   - `jj git fetch` refreshes the remote-tracking state, so `trunk()` resolves to current `main@origin`
   - `jj log -r 'trunk() & ::@' --no-graph -T 'commit_id ++ "\n"'` shows the most recent trunk commit in this branch's history. If that matches `trunk()`, we're already current. Skip.
   - Otherwise `jj rebase -d 'trunk()'` to rebase the branch onto latest trunk
   - On conflicts: stop. Surface what conflicted and let the human resolve. Don't auto-resolve.

   This is implicit consent from running /pr-time, so just go. If something looks wrong afterwards, `jj op log` and `jj op restore <id>` are your backout.

3. **Decide the rev structure**:
   What's there usually reads either as one cohesive change or as a natural sequence. Either is fine. The question is whether the current shape matches the story you want to tell.

   - **One big rev that's really two things**: `jj split -i` for an interactive hunk picker, or `jj split <paths>` to cut along file boundaries
   - **Several revs that are really one thing**: `jj squash --into <parent> -u` (the `-u` keeps the destination's message and skips the editor)
   - **Out of order**: `jj rebase -r <rev> --before <other>` to move a rev
   - **Noise** (WIP scratches, abandoned attempts): `jj abandon -r <rev>`

   Don't over-engineer. If the work is one focused change, keep it as one rev. If it's two clear steps, two revs. Forcing structure for its own sake is worse than letting the shape match the work.

4. **Polish the rev messages**:
   - Each rev: short summary line (imperative mood) + blank line + brief narrative body
   - `jj desc -r <rev> -m '<message>'` with the whole thing in one single-quoted string (newlines preserved); or `jj desc -r <rev>` to drop into your editor
   - **Formatting**: hard-wrap body text at 72 characters. Standard git convention, keeps things readable in `jj log`, terminals, and email patches.

5. **Draft the PR**:
   - **Title**: high-level summary of the whole change
   - **Description**: casual narrative. What happened, why it was a problem, what we did about it. If there are multiple revs, the description can reference the progression.
   - **Formatting**: do NOT hard-wrap lines. PR descriptions are rendered as markdown, so write flowing paragraphs that reflow naturally in the browser. Hard line breaks in the middle of sentences look broken on GitHub.

6. **Show me the draft** and ask "Look good?". Wait for approval before pushing.

7. **After approval**: advance the bookmark, push, open the PR.

   First find or create the branch bookmark:
   ```
   jj bookmark list
   ```
   - **Existing bookmark on this stack**: `jj tug` moves the closest non-trunk ancestor bookmark to `@-` (or to `@` if `@` itself is the tip rev with no empty rev above it; adjust the target if needed)
   - **No bookmark yet**: pick the branch name (often inferrable from the workspace dir or a Linear issue), then `jj bookmark create <branch-name> -r @-`

   Then push and open. `gh pr create` reads git's current branch to default `--head`, and in a colocated jj repo that still reports whatever branch git was on (usually `main`), not the jj bookmark we just moved. So pass `--head` explicitly using the bookmark sitting at `@-`:
   ```bash
   jj git push
   gh pr create \
     --head "$(jj log -r '@-' --no-graph -T 'bookmarks.join(\",\")')" \
     --title "..." --body "..."
   ```
   Edge case: if `@-` has multiple bookmarks, the inline command emits them comma-joined and gh will reject it. Rare; pick one and pass it manually if you hit it.

8. **Babysit the PR**: After the PR is created, stick around and shepherd it through CI and automated review. This phase is fully autonomous. No need to check in unless something needs human judgment.

   **8a. Watch CI**

   Wait for checks to register and complete. **CI always runs**. If you see zero checks, it means they haven't registered yet, not that the repo has no CI.

   Wait 15 seconds after the push before the first poll to give GitHub time to register checks. Then poll with:

   ```bash
   gh pr checks $PR_NUMBER
   ```

   Parse the output to determine status. Keep polling every 30 seconds until all checks have a final status (pass/fail, not pending). **Do not use `--watch`**: it streams continuous output that bloats context. A simple poll loop is better:

   ```
   sleep 15  # initial grace period for checks to register
   # then loop: gh pr checks, parse, sleep 30, repeat
   ```

   If after 2 minutes you still see zero checks, that's unexpected. Mention it but keep waiting (up to 5 minutes total before flagging it as a real problem).

   Once checks resolve:

   - **All green**: move on to 8b.
   - **Failure**: read the failed check's logs (`gh run view $RUN_ID --log-failed`). Assess the failure:
     - If it's a straightforward fix (lint, formatting, typo, simple test update) and you're confident: write the fix into `@` (which is empty after the earlier commit), then either land it as its own rev with `jj desc -m 'fix CI: <what>'` or fold it into the breaking rev with `jj squash --into <broken-rev> -u`. `jj tug && jj git push`, then loop back to watch CI again. **You get up to two auto-fix attempts.**
     - If the failure reveals a real issue that needs discussion, or if you've already used both auto-fix attempts: stop and report the situation. Show what failed, what you tried (if anything), and what you think the options are.

   **8b. Wait for CodeRabbit review**

   Poll for CodeRabbit's review to arrive. CodeRabbit is usually fast (under a minute), but give it up to 5 minutes. **CodeRabbit is always expected on `mirendev/` repos**. Do not bail early assuming it's not set up.

   ```bash
   gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
     | jq '[.[] | select(.user.login == "coderabbitai[bot]")]'
   ```

   Poll every 30 seconds. Once the review lands, determine if it has actionable findings:

   - **Clean review**: the review body is just a summary walkthrough with no actionable sections. No nitpick comments, no outside-diff-range warnings, no inline review threads from CodeRabbit. Report that CI is green and CodeRabbit is clean. We're done.
   - **Has real comments**: the review body contains actionable sections (`🧹 Nitpick comments`, `⚠️ Outside diff range comments`) or CodeRabbit left inline review threads. Report what was found and kick off `/address-pr-review` to work through the feedback.

## Examples

### Single rev (when the work is cohesive)

```
Rev message (via `jj desc -m`):
Fix the thing that was broken

X was causing Y, which meant users would hit Z whenever they tried to
do W. Pulled the shared logic out into its own helper so both paths
go through the same flow now.

PR title:
Fix the thing that was broken

PR description (note: flowing paragraphs, no hard line breaks):
We had this annoying gap where X would work fine in one context but fall over in another. The root cause was that the two code paths had diverged, with one getting the nice treatment while the other was still doing things the old way.

Pulled the common logic into a shared helper so they both behave consistently now. The end result is that users get the same experience regardless of which path they come through.

Closes PROJ-123
```

### Multiple revs (when there's a natural separation)

```
Rev 1 (api/app/envvar.go, api/app/server.go):
Extract shared env var mutation logic into helper

The deployment server and app server both needed to do the same env
var dance, but each had its own copy. Pulled the common bits into
envvar.go so we have one path to maintain.

Rev 2 (remaining files):
Route env set/delete through deployment service

Now that the env var logic is shared, we can add SetEnvVars and
DeleteEnvVars to the deployment service. This means the CLI gets
back a deployment record and can poll for activation and show routes,
just like deploy and rollback already do.

PR title:
Route env set/delete through deployment service for post-deploy UX

PR description (note: flowing paragraphs, no hard line breaks):
`env set` and `env delete` were the odd ones out: they'd create a new version and bail immediately, while `deploy` and `rollback` both watch activation and print routes. Felt like a gap worth closing.

First rev pulls the shared env var mutation logic into its own helper, then the second rev uses that to wire up new RPCs on the deployment service. End result is all four commands give you the same "watch it roll out and show you the routes" experience.

Closes PROJ-123
```
