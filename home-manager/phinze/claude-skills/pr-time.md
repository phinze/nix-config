# Ship a PR

Let's get this work shipped! Create a commit and PR for the current changes.

## Style Guide
- **Warm, conversational, narrative** — like telling a teammate the story over coffee
- Write in flowing paragraphs, not bullet lists of changes
- Focus on the "why" and the journey: what was the situation, what was wrong with it, how did we make it better
- A little personality is good — don't be robotic or terse
- No need to exhaustively restate the diff; trust the reader to look at the code
- No test plan section

## Steps

1. **Check the state**: Run `git status` and `git diff` to see what we're working with

2. **Consider the commit structure**: Look at the changes and decide whether they tell one story or several. If there's a natural separation (e.g. a refactor that enables a feature, a helper extraction + the thing that uses it), split them into multiple commits that build on each other. Don't force it — one commit is fine when the changes are cohesive.

3. **Draft the commit(s)**:
   - Each commit: short summary line (imperative mood) + brief narrative body
   - If multiple commits, they should read as a logical sequence

4. **Draft the PR**:
   - **Title**: High-level summary of the whole change
   - **Description**: Casual narrative - what happened, why it was a problem, what we did about it. If there are multiple commits, the PR description can reference the progression.

5. **Show me the draft** and ask "Look good?" - wait for approval before proceeding

6. **After approval**: Stage and commit (using `git add -p` or specific files to separate commits if needed), push, and create the PR with `gh pr create`

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

PR description:
We had this annoying gap where X would work fine in one context but
fall over in another. The root cause was that the two code paths had
diverged — one got the nice treatment and the other was still doing
things the old way.

Pulled the common logic into a shared helper so they both behave
consistently now. The end result is that users get the same
experience regardless of which path they come through.

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

PR description:
`env set` and `env delete` were the odd ones out — they'd create a
new version and bail immediately, while `deploy` and `rollback` both
watch activation and print routes. Felt like a gap worth closing.

First commit pulls the shared env var mutation logic into its own
helper, then the second commit uses that to wire up new RPCs on the
deployment service. End result is all four commands give you the
same "watch it roll out and show you the routes" experience.

Closes PROJ-123
```
