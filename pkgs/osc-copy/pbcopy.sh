#!/usr/bin/env bash
# pbcopy - Copy stdin to system clipboard via OSC 52
# Works through SSH and tmux to reach the local terminal's clipboard

# Debug mode: set PBCOPY_DEBUG=1 to see diagnostics
debug() {
  if [[ -n "$PBCOPY_DEBUG" ]]; then
    echo "[pbcopy] $*" >&2
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
    echo "[pbcopy] WARNING: tmux allow-passthrough is '${passthrough:-off}', OSC 52 may not work" >&2
    echo "[pbcopy] Run: tmux set -g allow-passthrough on" >&2
  fi

  # Inside tmux: wrap in passthrough sequence and write to pane's tty
  printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$encoded" > "$pane_tty"
  debug "sent to $pane_tty with tmux passthrough wrapper"
else
  debug "not in tmux, sending directly"
  # Outside tmux: send directly (may need /dev/tty fallback)
  printf '\033]52;c;%s\a' "$encoded"
fi
