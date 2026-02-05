#!/usr/bin/env bash
# pbcopy - Copy stdin to system clipboard via OSC 52
# Works through SSH and tmux to reach the local terminal's clipboard

encoded=$(base64 | tr -d '\n')

if [[ -n "$TMUX" ]]; then
  # Inside tmux: wrap in passthrough sequence and write to pane's tty
  pane_tty=$(tmux display-message -p '#{pane_tty}')
  printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$encoded" > "$pane_tty"
else
  # Outside tmux: send directly (may need /dev/tty fallback)
  printf '\033]52;c;%s\a' "$encoded"
fi
