---
name: pr-time
description: Ship a finished change by direct push or pull request. Tidy the jj rev stack, rebase on trunk, polish revision messages, then follow the repository's delivery policy. Use when asked to run pr-time, ship this work, prep or open a PR, or otherwise publish a finished change.
---

# Ship a Change

## Delivery Path

Explicit user and repository instructions win. Otherwise, GitHub repositories
owned by `phinze` ship directly to `main`; repositories owned by anyone else
ship through a pull request. Check the owner rather than inferring it from a
local path:

```bash
gh repo view --json owner --jq '.owner.login'
```

Both paths use Steps 1–4. A direct push then follows the direct-push branch
below and stops. A pull request continues through Steps 5–8.

## Style Guide

Applies to rev messages and PR descriptions. You write the first draft; I own
the intent, judgment, and final approval.

The reader's attention is finite and worth being kind to. Give them the
situation, what was wrong with it, and what we did. They can get the rest from
the code. No test plan section. Conversational and a little informal, and almost
never an em-dash (per global CLAUDE.md).

**Length is what this skill gets wrong.** Write it short the first time rather
than padding and cutting back. Follow a repo template or known local convention
when one exists; otherwise draft from the change and use the cut list below.

What has to come out is nearly always the same:

- **The hunt rather than the finding.** Reproduction counts, "I confirmed this
  three ways", the order things were discovered in. Verification is a clause.
- **Spurious precision.** "45,045 against 4,094" says what "around 90%" says,
  slower.
- **The same point at two altitudes.** A summarizing paragraph followed by an
  elaborating one is one paragraph.
- **Roads not taken**, expanded. Usually a clause.
- **Mechanism.** Detail belongs next to the code it explains, so put it in the
  rev message, a comment, or the README. Moving it is a relocation, not a loss,
  and it's most of how a description gets long in the first place.

Most `mirendev/*` repos are public, so keep internal hostnames, private repo
names, and infra topology out. Anonymize sample output rather than dropping it;
the reader only needs the shape.

## Bot Reviewers

Every `mirendev/` PR gets reviewed by biscuit, and biscuit is the only bot
reviewer. CodeRabbit was our second one until 2026-09-24, when we suspended the
app after measuring biscuit as the stronger reviewer (RFD-95, MIR-1896). A
`coderabbitai[bot]` review on an older PR is history, not something to wait for.

**biscuit** (`miren-code-agent[bot]`)
- The name and the login differ. "biscuit" is what we call it, the API returns
  `miren-code-agent[bot]`. There's no CLI to run; it triggers itself on PR
  events and takes one command, as a PR comment. The implementation is
  `mirendev/reviewagent`, under `internal/biscuit/`, on the rare occasion you
  actually need it.
- Its body opens `**🍪 biscuit: <verdict>** — auto-review, non-blocking`.
  Verdicts are `✅ ready to merge`, `⚠️ ready with caveats`, or `🚧 not ready`,
  and the verdict is advisory. It never gates the merge.
- Reviews when the PR opens, taking five to ten minutes, and **re-reviews on
  push**: a push cancels any review still reading the old head, then waits for
  the pushes to settle (two minutes after the last one) and reviews the new
  head once, as a delta on its previous review. So a review after a push lands
  seven to twelve minutes after the push, and each push inside that window
  restarts the clock. Batch pushes rather than trickling them.
- A push that lands back on a head it already reviewed is skipped, so a
  revert doesn't buy a new review.
- **Every review names its commit**: the footer reads ``reviewed at `abc1234` ``.
  Compare that against `gh pr view --json headRefOid` to know whether the
  verdict is of the current head, rather than guessing from what changed.
- **Earlier reviews get folded.** When a new review posts, each older one is
  rewritten into a `<details>` block whose summary line carries the old verdict,
  its commit, and "superseded by a newer review", with an
  `<!-- biscuit:superseded -->` marker. The API still returns them, so when
  listing reviews skip any body carrying that marker or you'll read a stale
  verdict as current.
- **Its progress is a check run named `biscuit` on the head**, in the merge
  box next to CI. `queued` while the settle window runs, `in_progress` once
  the review starts, then the verdict as the conclusion: `success` for ready,
  `neutral` for caveats, `action_required` for not ready, `cancelled` for a
  review that stopped without a verdict (superseded by a push, or failed). A
  head with no row hasn't been looked at. `gh pr checks` shows the state but
  drops the check's title, so read the row itself:

  ```bash
  gh api "repos/$OWNER/$REPO/commits/$(gh pr view $PR_NUMBER --json headRefOid --jq .headRefOid)/check-runs" \
    --jq '.check_runs[] | select(.name == "biscuit") | "\(.status) \(.conclusion // "-") \(.output.title)"'
  ```

  That prints e.g. `queued - waiting for pushes to settle`, `in_progress -
  reviewing 08dd23e`, or `completed success ready to merge`; nothing means no
  row on this head yet.

  **Keep that row out of the CI gate.** `gh pr checks` buckets
  `action_required` and `cancelled` as failures and `queued` as pending, so
  a `not ready` verdict or a settle window in progress looks like broken CI
  if you don't filter the row out.
- `/biscuit review` is the escape hatch, not the routine: it reviews right now,
  skipping the settle window, and cancels any review in flight. Don't post it
  while its check row is `queued` or `in_progress`, since that just restarts a
  review of the same head.
- Auto-resolves its own threads when its re-review lands.
- Findings arrive in two shapes and you need to read both: real inline threads,
  and a markdown `## Inline comments` section inside the review body. In the
  second case GraphQL `reviewThreads` shows nothing and there's nothing to
  resolve, just prose to act on.
- It writes long and thinks out loud, sometimes raising a concern under a bold
  heading and talking itself back out of it in the same paragraph. Read a section
  to its end before turning it into work.

## Steps

1. **Survey the rev stack**:
   - `jj status` to see whether `@` itself has snapshot changes or is the empty rev left by an earlier `jj commit`
   - `jj log -r 'trunk()..@'` for the chain that will become this PR
   - `jj diff --from 'trunk()' --to '@'` for the combined diff that will land

2. **Rebase on latest trunk**. Implicit consent from running /pr-time, so just go.
   - `jj git fetch` refreshes remote-tracking state, so `trunk()` resolves to current `main@origin`
   - `jj log -r 'trunk() & ::@' --no-graph -T 'commit_id ++ "\n"'` shows the most recent trunk commit in this branch's history. If it matches `trunk()`, skip.
   - Otherwise `jj rebase -d 'trunk()'`
   - On conflicts: resolve what's mechanical or obvious, escalate what's a judgment
     call. Then confirm `jj diff --from 'trunk()' --to '@'` shows our change with
     none of trunk's work reverted, and say what you resolved.

3. **Decide the rev structure**. One cohesive change or a natural sequence, either is fine. The only question is whether the current shape matches the story, and forcing structure for its own sake is worse than letting the shape match the work. Handle obvious cleanup yourself. Before a split or reorder that would materially change the review story, show me the proposed stack and wait for a go-ahead.
   - **One big rev that's really two things**: `jj split -i` for an interactive hunk picker, or `jj split <paths>` to cut along file boundaries
   - **Several revs that are really one thing**: `jj squash --into <parent> -u` (`-u` keeps the destination's message and skips the editor)
   - **Noise** (WIP scratches, abandoned attempts): `jj abandon -r <rev>`

4. **Polish the rev messages**. Short imperative summary line, blank line, brief narrative body hard-wrapped at 72 per git convention. Write and apply them yourself; they do not need separate approval. `jj desc -r <rev> -m '<message>'` with the whole thing in one single-quoted string (newlines preserved), or `jj desc -r <rev>` for the editor.

   These carry more weight than their length suggests. The style guide sends mechanism here rather than into the description, so this is where the durable technical prose lives, and its reader arrives from `blame` with the diff already in front of them. Give that reader the why: what the situation was, what forced the change, what you considered and rejected. A body that restates the summary line, or narrates a diff they are already looking at, gives them nothing.

   **Direct-push branch:** Verify the stack is a direct descendant of current
   `trunk()`, move `main` to the tip change revision (`@`, or `@-` when `@` is
   an empty working-copy revision), and push it:

   ```bash
   jj bookmark move main --to <tip-revision>
   jj git push --bookmark main
   ```

   A routine direct push needs no PR prose or writing checkpoint. If the push
   rejects because `main` advanced, fetch, rebase onto the new `trunk()`, and
   retry. Stop after the push and report the revisions that landed.

5. **Draft the PR. You take the first pass; I make the call.**

   A description argues for the change: what mattered, what the tradeoffs were,
   and why one approach beat another. Draft that argument from the conversation,
   the rev stack, the combined diff, and any project context you actually have.
   Follow any repo template that already exists.

   Do not invent intent from code and present it as fact. When a material part
   of the rationale is missing, either write a narrower draft that does not need
   it or ask one focused question. Do not hand me the source material and a blank
   page merely because some judgment is mine.

   **UI change? Shoot it first.** When the diff touches what someone sees
   (web components, templates, styles, a CLI's output), capture the states the
   description will argue about before drafting, per the `pr-shots` skill.
   Reference them in the body as `![alt](/abs/path/shot.png)`; step 7 passes
   each file to `gh pr create --attach` and gh rewrites the references.

   Draft both parts:
   - **Title**: a high-level summary of the whole change
   - **Description**: the short argument for the change, per the style guide.
     With multiple revs it can reference the progression. Mention what the PR is
     stacked on when the relationship matters to the reader.

   Make the issue relationship explicit at the end of the body when the task
   context carries one. For a Linear issue, use `Closes MIR-123` when this PR
   completes the issue, `Part of MIR-123` when the issue remains open for more
   work, or `Related to MIR-123` when the link is informational. Rig-created
   branches leave out the exact Linear identifier, so this line is what links
   the PR and controls issue automation. Infer the relationship from the agreed
   scope when it is clear; ask one focused question when completion is genuinely
   ambiguous.

   For a GitHub issue, use `Closes #123` (or
   `Closes owner/repo#123` across repositories) only when the PR completes it.
   `Part of #123` is a useful plain reference but is not a GitHub closing
   keyword. GitHub only applies closing keywords when the PR targets the
   default branch, so a PR currently stacked on another branch should reference
   the issue without promising automatic closure.

6. **Trim, verify, and show the exact draft.** Reread it against the cut list
   and the combined diff. Say so when the available rationale is uncertain or
   when a claim does not match the code. Do NOT hard-wrap the description; it
   renders as Markdown, and mid-sentence line breaks look broken on GitHub.

   Show me the final rev stack with its messages, followed by the exact PR title
   and body, and ask "Look good?". List any screenshot paths the body references
   so I can open them. This is the one writing checkpoint. Wait for approval
   before pushing. If I revise the prose, check my factual claims
   against the diff, preserve the intent and wording I chose, and show the final
   artifact again if your corrections materially change it.

   Skip meta scaffolding in the draft and in your own reporting: which bookmark
   you picked, whether the repo opens drafts, or how you settled the rev
   structure. Do it, don't narrate it.

7. **After approval**: advance the bookmark, push, open the PR.

   `jj bookmark list` first.
   - **Existing bookmark on this stack**: `jj tug` moves the closest non-trunk ancestor bookmark to `@-` (or to `@` if `@` is the tip rev with no empty rev above it)
   - **No bookmark yet**: in a Rig workspace, use the branch recorded for this
     repo in the rig manifest. Do not reconstruct it from the workspace dir or
     ask Linear for a branch name; Rig's work branch intentionally differs from
     both. Outside Rig, `jj bookmark create <branch-name> -r @-` with a name
     appropriate to the task.

   `gh pr create` defaults `--head` from git's current branch, which in a colocated repo still reports whatever git was on (usually `main`), not the bookmark we just moved. So pass it explicitly:
   ```bash
   jj git push
   gh pr create \
     --head "$(jj log -r '@-' --no-graph -T 'bookmarks.join(\",\")')" \
     --title "..." --body "..." \
     --attach /abs/path/shots/one.png   # one per image the body references
   ```

   **Stacked on another open PR?** Don't hand-set `--base`. `gh stack link` sets the base to the parent's head branch *and* groups the PRs in GitHub's stack UI, so run it right after creation:
   ```bash
   STACK_NUMBER=$(gh api "repos/$OWNER/$REPO/stacks?pull_request=$PARENT_PR_NUMBER" \
     --jq '.[0].number // empty')
   gh stack link "${STACK_NUMBER:-$PARENT_PR_NUMBER}" "$PR_NUMBER"
   ```
   A stack number appends to an existing stack; falling back to the parent's PR number starts a new two-PR one. Skip entirely for a PR based on trunk.

   **Work repos open as drafts.** Check with `gh repo view --json owner --jq '.owner.login'`, and if it's `mirendev`, add `--draft`. CODEOWNERS review requests don't fire until a PR leaves draft, which keeps the ordering bot-first, humans-after. biscuit reviews drafts, so step 8 works unchanged and 8b flips it to ready. Personal repos open normally.

8. **Babysit the PR**: fully autonomous from here. Only check in if something needs human judgment.

   **8a. Watch CI**

   Sleep 15 seconds for checks to register, then poll every 30 seconds until everything is final. **Not `--watch`**, which streams and bloats context. **CI always runs**, so zero checks means they haven't registered yet; flag it if they're still missing after 5 minutes.

   ```bash
   gh pr checks $PR_NUMBER --json name,state,bucket,description \
     --jq 'map(select(.name != "biscuit"))'
   ```

   The `biscuit` row is its review progress, not CI (see Bot Reviewers); 8b reads it. Leaving it in makes a `not ready` verdict look like a red build and a settle window look like a hung one.

   - **All green**: on to 8b.
   - **Failure**: read the logs (`gh run view $RUN_ID --log-failed`). If it's straightforward (lint, formatting, typo, simple test update) and you're confident, write the fix into `@`, land it (`jj desc -m 'fix CI: <what>'` as its own rev, or `jj squash --into <broken-rev> -u` to fold it into the breaking one), then `jj tug && jj git push` and loop. **Two auto-fix attempts, then stop.** If the failure needs discussion, report what failed, what you tried, and the options.

   **8b. Wait for biscuit's review**

   Don't bail early assuming it isn't set up. See Bot Reviewers above for where its findings hide. biscuit takes five to ten minutes from the PR opening, and if 8a pushed a CI fix the clock restarts from that push plus the two-minute settle, so allow up to 12 minutes from the last push.

   ```bash
   gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
     | jq '[.[] | select(.user.login == "miren-code-agent[bot]")
            | select(.body // "" | contains("biscuit:superseded") | not)
            | {author: .user.login, submitted_at, body}]'
   ```

   Poll every 30 seconds until it shows up, then read the body and any inline threads.

   biscuit's review counts only if it's of the head you pushed. Its footer names the commit, so check it rather than trusting the timestamp:

   ```bash
   HEAD=$(gh pr view $PR_NUMBER --json headRefOid --jq .headRefOid)
   gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" --paginate \
     | jq -r --arg head "$HEAD" '[.[] | select(.user.login == "miren-code-agent[bot]" and .body != ""
            and (.body // "" | contains("biscuit:superseded") | not))]
            | last.body // "" | (capture("reviewed at `(?<sha>[0-9a-f]+)`").sha // null) as $sha
            | if $sha == null then "no biscuit review yet"
              elif ($head | startswith($sha)) then "current"
              else "stale: reviewed at \($sha)" end'
   ```

   A stale review with the `biscuit` check `queued` or `in_progress` means the re-review is on its way; keep waiting. Stale with the check `cancelled` (or no row for this head) well past the 12 minutes is the one case that warrants `/biscuit review`.

   - **Clean** (`✅ ready to merge` with nothing raised): if it's still a draft, `gh pr ready $PR_NUMBER`. Report green CI, clean review, ready for humans. Done.
   - **Findings**: report what turned up, then kick off `/address-pr-review`.

   A `⚠️ ready with caveats` isn't automatically work. Sometimes it names a real gap worth a follow-up issue, sometimes it's biscuit narrating a worry it then resolves on its own. Judge it, don't reflex-fix it.

## Example

Two revs, because there's a natural separation:

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

PR description (flowing paragraphs, no hard line breaks):
`env set` and `env delete` were the odd ones out: they'd create a new version and bail immediately, while `deploy` and `rollback` both watch activation and print routes. Felt like a gap worth closing.

First rev pulls the shared env var mutation logic into its own helper, then the second uses that to wire up new RPCs on the deployment service. End result is all four commands give you the same "watch it roll out and show you the routes" experience.

Closes PROJ-123
```

That's a small change. A meatier one gets three or four paragraphs, not eight.
Here's a paragraph that didn't survive a real trim:

> `www` gets the same treatment and rides along on the same certificate. That
> turns out to be free: DNSimple's default certificate name covers the root
> domain and `www` together, and listing `www` in `alternate_names` is rejected
> as a duplicate.

What shipped: "`www` gets the same record and rides the same certificate." The
quirk went in the rev message, where the next person to touch that resource will
find it. Two more paragraphs went the same way, and 383 words became 204.
