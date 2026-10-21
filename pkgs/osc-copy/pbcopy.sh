#!/usr/bin/env bash
# osc-copy - Copy stdin to system clipboard via OSC 52
# Works through SSH and tmux to reach the local terminal's clipboard
# Installed as: pbcopy, xclip, xsel

progname=$(basename "$0")

# Debug mode: set PBCOPY_DEBUG=1 to see diagnostics
debug() {
  if [[ -n "$PBCOPY_DEBUG" ]]; then
    echo "[$progname] $*" >&2
  fi
}

encoded=$(base64 | tr -d '\n')
debug "encoded ${#encoded} bytes"

if [[ -n "$TMUX" ]]; then
  debug "TMUX detected: $TMUX"

  pane_tty=$(tmux display-message -p '#{pane_tty}')
  debug "pane_tty: $pane_tty"

  passthrough=$(tmux show -g allow-passthrough 2>/dev/null | awk '{print $2}')
  debug "allow-passthrough: ${passthrough:-<not set>}"

  if [[ "$passthrough" != "on" && "$passthrough" != "all" ]]; then
    echo "[$progname] WARNING: tmux allow-passthrough is '${passthrough:-off}', OSC 52 may not work" >&2
    echo "[$progname] Run: tmux set -g allow-passthrough on" >&2
  fi

  # Inside tmux: wrap in passthrough sequence and write to pane's tty
  printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$encoded" > "$pane_tty"
  debug "sent to $pane_tty with tmux passthrough wrapper"
else
  debug "not in tmux, sending directly"

  # Outside tmux, stdout is the terminal when a person runs this, but not when
  # an agent does: Claude Code's Bash tool captures stdout, and the sequence
  # lands in the tool result instead of reaching the terminal. tmux hid this by
  # handing us the pane's tty; in Rex (or any bare terminal) we find it
  # ourselves, from the first ancestor with a terminal on one of its stdio fds.
  out=/dev/stdout
  if [[ ! -t 1 ]]; then
    pid=$$
    while [[ "$pid" -gt 1 && "$out" == /dev/stdout ]]; do
      for fd in 0 1 2; do
        target=$(readlink "/proc/$pid/fd/$fd" 2>/dev/null)
        if [[ "$target" == /dev/pts/* || "$target" == /dev/tty* ]]; then
          out=$target
          break
        fi
      done
      pid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo 1)
    done
  fi
  debug "writing to $out"

  printf '\033]52;c;%s\a' "$encoded" > "$out"
fi
