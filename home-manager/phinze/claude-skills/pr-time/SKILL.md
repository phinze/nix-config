---
name: pr-time
description: Ship a change as a pull request. Tidy the jj rev stack, rebase on trunk, draft narrative rev messages and a PR description, then babysit the PR through CI and both bot reviewers. Use when asked to run pr-time, prep or open a PR, ship this work, or when a finished change needs to become a pull request.
---

# Ship a PR

Let's get this work shipped. Tidy the rev stack, rebase on latest trunk, open a PR.

## Style Guide
- Focus on the "why" and the journey: what was the situation, what was wrong with it, how did we make it better
- No need to exhaustively restate the diff; trust the reader to look at the code
- No test plan section
- Voice: conversational prose. Almost never use em-dashes (per global CLAUDE.md). Use commas, parens, or two sentences instead.

## Bot Reviewers

Every `mirendev/` PR gets reviewed by two bots. They are both expected, they
behave differently, and confusing one for the other is the usual way this goes
wrong. Know which is which before step 8.

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
- Auto-resolves its own threads, but only when it re-runs. So a `/biscuit
  review` after pushing fixes is what clears them.
- Findings arrive in two shapes and you need to read both: real inline threads,
  and a markdown `## Inline comments` section inside the review body. When they
  come through the body, GraphQL `reviewThreads` shows nothing from biscuit and
  there is nothing to resolve, just prose to act on.
- It writes long and thinks out loud, sometimes raising a concern under a bold
  heading and then talking itself back out of it in the same paragraph. Read a
  section to its end before turning it into work.
- The verdict is advisory. It never gates the merge.

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

   **Work repos open as drafts.** On `mirendev/*` repos, open the PR as a draft so both bots do their pass before any human reviewer gets pinged. CODEOWNERS review requests don't fire until a PR leaves draft, so this keeps the ordering bot-first, humans-after. Check the owner:
   ```bash
   gh repo view --json owner --jq '.owner.login'
   ```
   If it's `mirendev`, add `--draft` to the `gh pr create` above. Both bots review drafts (CodeRabbit's `drafts` auto-review setting is on org-wide, and biscuit reviews on open regardless), so the babysit loop below works unchanged, and step 8b flips the PR to ready once both bots are clean. Personal repos (solo, no reviewers) open normally, no draft.

8. **Babysit the PR**: After the PR is created, stick around and shepherd it through CI and automated review. This phase is fully autonomous. No need to check in unless something needs human judgment.

   **8a. Watch CI**

   Sleep 15 seconds for checks to register, then poll `gh pr checks $PR_NUMBER` every 30 seconds until everything reaches a final status. **Not `--watch`**, which streams and bloats context. **CI always runs**, so zero checks means they haven't registered yet, not that the repo has none; flag it if they're still missing after 5 minutes.

   - **All green**: move on to 8b.
   - **Failure**: read the logs (`gh run view $RUN_ID --log-failed`). If it's a straightforward fix (lint, formatting, typo, simple test update) and you're confident, write it into `@` (empty after the earlier commit), land it (`jj desc -m 'fix CI: <what>'` as its own rev, or `jj squash --into <broken-rev> -u` to fold it into the breaking one), then `jj tug && jj git push` and loop back. **Two auto-fix attempts, then stop.** If the failure reveals something that needs discussion, stop and report what failed, what you tried, and what the options look like.

   **8b. Wait for both bot reviews**

   Two bots review every `mirendev/` PR and **both are always expected**, so don't bail early assuming one isn't set up, and don't call the pass done when only one has landed:

   - **CodeRabbit** (`coderabbitai[bot]`), whose findings land as actionable body sections (`🧹 Nitpick comments`, `⚠️ Outside diff range comments`) and inline threads.
   - **biscuit** (`miren-code-agent[bot]`), whose body opens `**🍪 biscuit: <verdict>**` and whose findings may sit in a markdown `## Inline comments` section in that body rather than in real threads. There is no biscuit CLI to go find.

   Both usually arrive within a couple of minutes of the PR opening; give them up to 5.

   ```bash
   gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
     | jq '[.[] | select(.user.login == "coderabbitai[bot]" or .user.login == "miren-code-agent[bot]")
            | {author: .user.login, submitted_at, body}]'
   ```

   Poll every 30 seconds until both have shown up. Then read both bodies and any inline threads, and decide whether there's actionable feedback:

   - **Both clean**: CodeRabbit's body is just the summary walkthrough, with no actionable sections and no inline threads, and biscuit came back `✅ ready to merge` with nothing raised in its body. The bot-first pass is done. If the PR is still a draft (`gh pr view $PR_NUMBER --json isDraft --jq '.isDraft'`), flip it to ready for human review: `gh pr ready $PR_NUMBER`. Report that CI is green, both bots are clean, and the PR is ready. We're done.
   - **Either has findings**: report what turned up, attributed by name so it's clear which bot said what, then kick off `/address-pr-review`.

   A `⚠️ ready with caveats` from biscuit isn't automatically work. Read the caveat: sometimes it names a real gap worth a follow-up issue, sometimes it's biscuit narrating a worry it then resolves on its own. Judge it, don't reflex-fix it.

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
