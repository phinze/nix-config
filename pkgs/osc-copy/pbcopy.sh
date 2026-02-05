#!/usr/bin/env bash
# pbcopy - Copy stdin to system clipboard via OSC 52
# Works through SSH and tmux to reach the local terminal's clipboard
printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')"
