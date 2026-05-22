---
name: snap
description: Capture a macOS window to a PNG by app name + title, without stealing focus or interrupting the user. Use whenever you need a screenshot of a UI the user is iterating on, or when handed off a request like "snap window X" from another session.
---

# snap

Grab a PNG of a specific macOS window without bringing it forward or
interrupting what's on screen. Ideal when one session is iterating on a
UI and another session needs to look at it.

## Invocation

    snap <app-name> <title-substring>

Both args required. `snap` resolves the window's CGWindowID via
`getwindowid`, captures its compositor surface via `screencapture -l
<id> -o -x`, writes to `/tmp/snap-<unix-timestamp>.png`, and echoes the
path. Pass that path to the Read tool to view the result.

`snap` is a shell script on PATH (installed via home-manager), so it
works the same from fish, bash, or any subagent shell.

## Examples

    snap 'Google Chrome' 'localhost'
    snap Safari 'GitHub'
    snap Ghostty 'main'

## When you don't know the title

    snap --list <app-name>

Lists every window for that app with its title and id. Use this any
time `snap` returns "no window matching" — title matching is exact and
case-sensitive.

## Why it works without focus

`screencapture -l <windowID>` reads the window's backing surface
directly, so occluded windows, windows on other Spaces, and windows
behind other apps all capture fine. The user's foreground app is never
disturbed.

## Caveats

- A handful of GPU-heavy apps (games, some video players) stop
  rendering when fully occluded and produce a blank or stale image.
  Browsers and normal UI apps are unaffected.
- Darwin only. On Linux `snap` exits non-zero because neither
  `getwindowid` nor `screencapture` exists.
