---
name: pr-shots
description: Capture screenshots or a short video of a web UI change with agent-browser and attach them to a PR, issue, or review comment with gh --attach. Use whenever a change touches UI and the PR description or a comment would be clearer with a picture, when asked to screenshot a page or component, or as the handoff from pr-time or address-pr-review for UI work. Covers the headless-Chrome flow, element crops, dark mode, and the attach syntax.
---

# PR Shots

A PR that changes what someone sees should show it. `gh` 2.99+ uploads
images and video straight into a PR body or comment with `--attach`, so the
only work is capturing the right picture. This skill is that path. Don't
rediscover it: no hunting `/nix/store` for a chromium, no `bun add
playwright`, no hand-written driver script, no gist, no imagemagick crop by
pixel coordinates.

## Tools

- **`agent-browser`** for anything served over HTTP. Headless Chrome driven
  one shell command at a time, on PATH everywhere. Chrome is baked in on
  Linux; on macOS it finds the installed one.
- **`snap`** for a native macOS window (see the `snap` skill).
- **`demo`** for a terminal session as a GIF.

Project-specific bits live in the project's CLAUDE.md or `run` skill: the dev
server command and port, and whatever gets a logged-in session (a dev-login
URL, a cookie, a form). Look there first, and add what you learn there rather
than here.

## Capture

Work in a `shots/` directory under the scratchpad. One session per rig keeps
the browser warm between commands and its cookies between sessions.

```bash
export AGENT_BROWSER_SESSION=<rig-name>
agent-browser set viewport 1280 800 2               # CSS size, 2x pixels
agent-browser open http://localhost:PORT/path        # dev login goes here if the app has one
agent-browser wait 'section[aria-label=Server]'      # a selector, or a millisecond count
agent-browser snapshot -i                            # interactive elements with refs
agent-browser find role button click --name "Upgrade to v0.14.0"
agent-browser wait 'dialog[open]'
agent-browser screenshot 'section[aria-label=Server]' shots/upgrade-dialog.png
agent-browser screenshot --full shots/cluster-page.png
agent-browser close
```

`snapshot -i` is the accessibility tree with refs; `click @e4` acts on one,
and `find role|text|testid ... click` acts by description. Refs go stale
whenever the page changes, so re-snapshot after a navigation. `screenshot
<selector> <path>` crops to one element and is almost always the right call;
a whole page only earns its place when the layout is the point.

Dark mode is a launch option, so it needs its own session:

```bash
agent-browser --session dark --color-scheme dark open http://localhost:PORT/path
```

A video, for a flow rather than a state (attach accepts it too, with no alt
text):

```bash
agent-browser record start shots/upgrade.webm
...
agent-browser record stop
```

`agent-browser skills get core` has the full command reference when
something here isn't enough.

## What to shoot

The states the description argues about, and nothing else. Two to four
images is the usual count; a PR with seven screenshots is a PR whose
description isn't doing its job. If the change is visual, a before/after pair
beats prose about the difference. Name files by what they show
(`empty-state.png`, `failed-deploy-chip.png`), not by when you took them.

Read each PNG before attaching it. A blank or half-rendered capture usually
means the `wait` was for the wrong thing, and a crop that includes half a
neighbouring card means the selector was too broad.

## Attach

Reference the files in the body as ordinary Markdown images and gh rewrites
each reference to the uploaded asset. Absolute paths sidestep any question of
what the cwd is. Alt text comes from the reference, or after `#` on the flag
for files the body doesn't mention.

```bash
gh pr create --title ... --body-file body.md \
  --attach /abs/path/shots/upgrade-dialog.png \
  --attach '/abs/path/shots/rolled-back.png#The section after a rollback'

gh pr edit 123 --attach ./after.png            # appends to the existing body
gh pr comment 123 --body "How it looks after the fix:" --attach ./fixed.png
gh issue create --attach ./repro.png
```

Up to 50 files per command. If some uploads fail the PR still lands with the
ones that worked, the command exits non-zero, and the URL still prints.

## Where this sits

pr-time step 5 captures before drafting, so the writing checkpoint shows the
image paths alongside the body and the attach rides on the `gh pr create`.
address-pr-review reaches for `gh pr comment --attach` when a fix is easier
to see than to describe.
