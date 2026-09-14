#!/usr/bin/env bash

# Demo - Record a terminal session and turn it into a GIF ready for gh --attach

set -euo pipefail

usage() {
    cat <<USAGE
Usage: demo [-o <file.gif>] [description]

Records a terminal session with asciinema (Ctrl+D to stop) and converts it to
a GIF. Prints the GIF path when done; attach it with

    gh pr create --attach './demo.gif#<what it shows>'
    gh pr comment 123 --attach ./demo.gif
USAGE
}

out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) break ;;
    esac
    shift
done

description="$*"
timestamp=$(date +%Y%m%d-%H%M%S)
cast_file="/tmp/demo-$timestamp.cast"
gif_file="${out:-/tmp/demo-$timestamp.gif}"

echo "🎬 Recording terminal session${description:+: $description}"
echo "Press Ctrl+D when done"

if ! asciinema rec "$cast_file"; then
    echo "Recording cancelled"
    exit 1
fi

echo "🎨 Converting to GIF..."
if ! agg "$cast_file" "$gif_file"; then
    echo "Failed to convert to GIF"
    exit 1
fi

echo "✅ $gif_file"
echo "   (recording kept at $cast_file)"
