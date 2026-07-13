---
name: second-opinion
description: Run a read-only code review through another installed agent CLI (Claude or Codex) for jj or git working-copy, branch, or revision diffs. Use when the user asks for a second opinion, independent or external review, a review from another model, a Codex or Claude review, a comparison between models, or /second-opinion.
---

# Second Opinion

Ask a fresh model from another provider to review a code change. Use the bundled
runner so diff collection, project context, output shape, and read-only flags stay
consistent across Claude, Codex, and Antigravity hosts.

## Choose defaults

Infer parameters from the request and avoid questions when these defaults fit:

- Use the working-copy diff, a general review focus, and project context.
- From Claude, use Codex. From Codex, use Claude. From Antigravity, use Codex.
- If the user names a reviewer, scope, revision, base, focus, or context choice,
  honor it.
- If the user asks to compare models or requests both, run Claude and Codex in
  parallel and synthesize their agreements and disagreements.
- Ask only when a required revision/base is missing or the request is genuinely
  ambiguous. A bare `/second-opinion` should run with the defaults.

This workflow sends the selected diff and included project instructions to the
chosen model provider. Never use it silently as part of an ordinary local review.

## Run the review

Resolve paths relative to this `SKILL.md`, then set `runner` to the absolute path
of `scripts/review.sh` in this skill directory.

1. Preview the selected diff:

   ```bash
   "$runner" --reviewer codex --scope working-copy --preview
   ```

   Supported scopes are `working-copy`, `branch`, and `revision`. For a branch
   diff, add `--base <rev>` when the default `trunk()` or remote default branch
   is not right. For one revision, add `--revision <rev>`.

2. If the preview reports no diff, stop. If it reports more than 2,000 changed
   lines, ask whether to proceed or narrow the scope. Pass `--allow-large` only
   after the user chooses to proceed.

3. Run the reviewer and capture its JSON before presenting it:

   ```bash
   "$runner" \
     --reviewer codex \
     --scope working-copy \
     --focus general \
     > /tmp/second-opinion-codex.json
   ```

   Reviewer values are `codex` and `claude`. Focus values are `general`,
   `security`, `performance`, `error-handling`, or free-form text. Context
   defaults to `auto`, which includes repo-root `AGENTS.md` and `CLAUDE.md` when
   present. Use `--context none` or `--context <path>` to override it.

4. For a comparison, invoke the runner twice in parallel with separate output
   files. The commands are read-only and do not share mutable state.

The runner prefers jj whenever `jj root` succeeds. It uses git only outside a jj
repository, including untracked files for git working-copy reviews.

## Triage the result

Treat the external review as evidence, not truth.

- Parse the JSON with `jq` and order findings by severity.
- Verify every finding against the current source and reachable behavior before
  presenting it. Drop stale, speculative, or incorrectly cited findings.
- Lead with actionable findings and file/line references. End with the reviewer's
  verdict and confidence.
- Attribute claims clearly when comparing reviewers. Call out agreement, useful
  disagreement, and false positives rather than pasting two opaque blobs.
- If there are no verified findings, say so plainly.
- Do not edit code, post comments, or otherwise act on a finding unless the user
  separately asks.

## Handle failures

- If a CLI is missing, report the missing command and use the other installed
  reviewer when that still satisfies the request.
- If authentication fails, report it. Do not silently switch accounts, models,
  or providers.
- If structured output is malformed, preserve the raw output, explain the parse
  failure, and review it manually.
- If a review times out, suggest a narrower scope. Do not weaken read-only flags
  to make it complete.

This skill is adapted from Trail of Bits' `second-opinion` skill. See
`LICENSE.md` for attribution and adaptation notes.
