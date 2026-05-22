#!/usr/bin/env bash
set -eu

usage() {
  echo "usage: snap <app-name> <window-title>" >&2
  echo "       snap --list <app-name>" >&2
  echo "  window-title is matched exactly; use --list to find it" >&2
  exit 2
}

require_getwindowid() {
  if ! command -v getwindowid >/dev/null 2>&1; then
    echo "snap: missing getwindowid (smokris/getwindowid tap; macOS only)" >&2
    exit 1
  fi
}

if [ $# -lt 1 ]; then usage; fi

if [ "$1" = --list ]; then
  if [ $# -lt 2 ]; then usage; fi
  require_getwindowid
  exec getwindowid "$2" --list
fi

if [ $# -lt 2 ]; then usage; fi
require_getwindowid

id=$(getwindowid "$1" "$2" 2>/dev/null || true)
if [ -z "$id" ]; then
  echo "snap: no window matching app='$1' title='$2'" >&2
  echo "  try: snap --list '$1'" >&2
  exit 1
fi

out="/tmp/snap-$(date +%s).png"
screencapture -l "$id" -o -x "$out"
echo "$out"
