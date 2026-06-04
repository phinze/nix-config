---
name: recto
description: Drive a running recto diff viewer from a companion session — scroll to and highlight a file or line span. Load whenever you are explaining, reviewing, or walking through code changes in a workspace where recto might be open, or when asked to "show me where", "point at", or "tour" a diff. Lets you direct the user's eyes to the exact lines you're describing instead of just naming them.
---

# recto

recto is the user's jj-first terminal diff viewer. When it's open on a
workspace, any session inside that workspace can drive it: scroll the
diff to a span and highlight it, so when you say "look at the retry loop
in client.rs" you can actually put it on screen.

Discovery is automatic. recto listens on a Unix socket keyed to the
workspace root, so `recto focus …` run from anywhere inside the repo
reaches the recto reviewing it. No env var, no socket path to thread
through.

## Commands

    recto focus PATH:START-END   # highlight lines START..END
    recto focus PATH:LINE        # highlight a single line
    recto focus PATH             # scroll to the file, no line span
    recto clear                  # remove the current highlight
    recto ping                   # is a recto listening here?

PATH is relative to anywhere in the workspace (recto normalizes it to
the repo root). Line numbers are **new-side** — the line numbers in the
post-change file, the ones you'd see in your editor after the edit.

## How to use it in a tour

Describe the change in prose, then point recto at the lines you're
talking about as you go. The highlight is sticky: it stays put until you
focus something else or `recto clear`, so each `focus` call replaces the
last. End a tour with `recto clear` so you don't leave a stray bar on
screen.

## Reading the exit code

recto is passive: it will not switch the diff base to find your target.
It reports rather than chases.

- **exit 0** — focused. The span is on screen and highlighted.
- **exit 1** — recto is running but refused. Usually "not in current
  diff" (the file isn't in the diff for the base recto currently shows)
  or "outside any shown hunk" (the file is in the diff but those lines
  aren't part of a changed hunk). If you expected the file to be there,
  the user may need to cycle the base with `b`; tell them, don't retry
  blindly.
- **exit 2** — no recto is listening for this workspace (or you're not
  in a repo). Don't keep trying; just describe the change in text.

Always `recto ping` first if you're unsure recto is open. A clean ping
means the focus calls will land.
