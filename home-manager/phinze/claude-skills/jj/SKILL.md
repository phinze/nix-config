---
name: jj
description: Use jj (Jujutsu) for version control. Load whenever jj or jujutsu comes up, or for any version-control operation on this machine — commits, rebases, branches, history queries — even if the user says "git". Covers jj verbs, workspace handling, destructive-op rules, and the semantic-commit workflow.
---

# jj (Jujutsu)

I'm using jj for version control. Reach for jj first; only fall back to git
when jj genuinely has no equivalent. Common verbs: `jj status`, `jj diff`
(or `jj diff -r @-`), `jj log`, `jj show`. To view a file at a revision use
`jj file show <path> -r <rev>` (not `jj cat`). To exclude paths from a
command, use fileset syntax: `jj diff '~package-lock.json'` or
`jj diff '~dir1 & ~dir2'`.

- When asked to start work on something and you're on an empty commit with
  no description, set a short description before editing files. Refine it
  as the work clarifies.
- **`jj new` before editing, not after.** Auto-snapshot folds working-copy
  changes into `@` on the next jj command. When `@` is a described/finished
  rev (a milestone you just landed, or one I asked you to leave alone),
  edits leak into it silently and the only way out is a post-hoc split.
  When starting a new logical chunk on top of a finished rev, create the
  child first: `jj new` (optionally with `-m '<msg>'`), then edit. If
  you've already smooshed, recover by finding the op id where the parent
  was last in its intended state (`jj op log`), use `jj --at-op <op-id>
  file show -r <rev> <path>` to read its content per file, restore those
  files in place to let auto-snapshot clean the parent on the next jj
  command, then `jj new` and re-apply your edits from a stash.
- To trace the origin of a line: `jj file annotate <file> | grep
  '<pattern>'`, then `jj log -r <id>` for context. If that rev is a
  refactor or rename, repeat with `-r <id>-` (and the old path if it moved)
  until you find the substantive change.
- Snapshot work in progress with `jj new` or `jj commit` (equivalent to
  `jj desc` + `jj new`) so each chunk is reviewable.
- I prefer semantic commits — each rev should be a self-contained logical
  change. When iterating on an existing rev A, work in a new rev on top of
  A and leave it there. Don't squash on your own initiative, and don't
  frame standalone revs as squash candidates ("ready to squash whenever",
  etc.) — that primes the wrong default. If I want work folded in, I'll
  ask or do it myself.
- For parallel approaches, use `jj new <base>` to create siblings off a
  common base, implement each, then compare. No bookmarks needed.
- When using `jj squash`, avoid the editor popup with `-m '<msg>'` or `-u`
  to keep the destination message. The two flags are mutually exclusive.
- Whether to run a destructive jj op (`squash`, `abandon`, `rebase`)
  depends on which commits it touches:
  - Scratch commits you created earlier in the session whose only purpose
    was to snapshot intermediate work can be reorganized among themselves
    (squashed together, abandoned, reworded) — as long as the result is
    still a rev on top of my target, not folded into it.
  - Don't modify commits that existed before the current session,
    including the rev I'm iterating on, without being asked.
  - When I do ask for a destructive op on pre-existing commits, confirm
    which commits are involved before running it.
- I may squash your work into the previous commit while you're working.
  That's normal — check `@-` (e.g., `jj diff -r @-`) if you need to
  confirm your changes landed.
- `--ignore-immutable` may be needed when abandoning divergent commits
  from other authors (e.g., after rebasing on their branch and a force
  push). The config treats commits not authored by me as immutable.
- `jj tug` is a custom alias that moves the closest ancestor bookmark to
  `@-`, useful for advancing a branch pointer to current work without
  retyping its name.

## Inside a jj workspace

When the cwd is under `~/workspaces/...`, you're in a non-default jj
workspace. These have `.jj/` but no `.git/`, so plain `git` commands fail
with "not a git repository". Use jj equivalents — `jj log`, `jj diff`,
`jj show`, `jj file show`, `jj file annotate` — and don't burn cycles
trying to coax git into working.

`gh` works fine because direnv's stdlib auto-exports `GH_REPO=<owner>/<repo>`
whenever the cwd is under `~/workspaces/<host>/<owner>/<repo>/...`. So
`gh pr view`, `gh pr diff`, `gh search`, etc. behave normally without any
explicit setup. If `gh` complains about a missing repo context, check
that direnv has loaded — a `.envrc` (or stub) needs to exist in the
workspace and direnv has to have allowed it.

The main checkout under `~/src/github.com/<owner>/<repo>` IS colocated
(has both `.jj/` and `.git/`). If you genuinely need git for something
that has no jj equivalent, run it there with `git -C <main-repo> ...`
rather than trying to make git work in the workspace.
