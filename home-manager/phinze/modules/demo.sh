#!/usr/bin/env bash

# Demo - Record terminal demo and share as GIF via GitHub gist

set -euo pipefail

# Parse description from arguments
description="$*"

if [[ -z "$description" ]]; then
    echo "Usage: demo <description>"
    echo "Records a terminal demo and shares it as a GIF via GitHub gist"
    exit 1
fi

timestamp=$(date +%Y%m%d-%H%M%S)
cast_file="/tmp/demo-$timestamp.cast"
gif_file="/tmp/demo-$timestamp.gif"
md_file="/tmp/demo-$timestamp.md"

echo "🎬 Recording terminal session..."
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

# Create markdown file
{
    echo "# Demo: $description"
    echo ""
    echo "Created: $(date)"
    echo ""
    echo "## Demo"
    echo ""
    echo "![Demo Animation](demo-$timestamp.gif)"
    echo ""
    echo "## Files"
    echo "- \`demo-$timestamp.cast\` - Original asciinema recording"
    echo "- \`demo-$timestamp.gif\` - GIF animation"
} > "$md_file"

echo "📤 Creating private GitHub gist..."
gist_output=$(gh gist create --desc "$description" "$md_file" "$cast_file" 2>&1)
gist_url=$(echo "$gist_output" | tail -1)

if [[ ! "$gist_url" =~ https://gist.github.com/ ]]; then
    echo "Failed to create gist"
    exit 1
fi

# Extract gist ID from URL
gist_id="${gist_url##*/}"

echo "📎 Adding GIF to gist..."
gist_dir="/tmp/gist-$gist_id"

# Clone the gist
if ! git clone -q "https://gist.github.com/$gist_id.git" "$gist_dir" 2>/dev/null; then
    echo "Failed to clone gist"
    exit 1
fi

# Copy GIF to gist and push
cp "$gif_file" "$gist_dir/demo-$timestamp.gif"
cd "$gist_dir"
git add "demo-$timestamp.gif"
git commit -q --no-gpg-sign -m "Add demo GIF"

if ! { git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null; }; then
    echo "Failed to upload GIF to gist"
    cd - > /dev/null
    rm -rf "$gist_dir"
    exit 1
fi

cd - > /dev/null

# Get GitHub username
github_user=$(gh api user --jq .login 2>/dev/null || echo "phinze")

echo "✅ Demo uploaded!"
echo "Gist URL: $gist_url"
echo "Raw GIF URL: https://gist.githubusercontent.com/$github_user/$gist_id/raw/demo-$timestamp.gif"
echo ""
echo "📋 Markdown embed:"
echo "![Demo](https://gist.githubusercontent.com/$github_user/$gist_id/raw/demo-$timestamp.gif)"

# Clean up
rm -rf "$gist_dir" "$md_file" "$cast_file" "$gif_file"