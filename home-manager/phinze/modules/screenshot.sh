#!/usr/bin/env bash

# Screenshot - Capture website screenshot and share via GitHub gist

set -euo pipefail

# Function to show help
show_help() {
    cat << EOF
Usage: screenshot <url> [resolution...] [options]

Examples:
  screenshot https://example.com                    # Default resolution (1366x768)
  screenshot https://example.com 1920x1080          # Single resolution
  screenshot https://example.com 1920x1080 768x1024 # Multiple resolutions

Options:
  -h, --help     Show this help message

The screenshot will be uploaded to a GitHub gist and the URL will be provided.
EOF
}

# Check for help flag or no arguments
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Parse arguments
url="$1"
shift

# Collect resolutions
resolutions=()
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ ^[0-9]+x[0-9]+$ ]]; then
        resolutions+=("$1")
    fi
    shift
done

# Use default resolution if none specified
if [[ ${#resolutions[@]} -eq 0 ]]; then
    resolutions=("1366x768")
fi

# Create description
description="Screenshot of $url at ${resolutions[*]}"

# Setup temporary directory
timestamp=$(date +%Y%m%d-%H%M%S)
temp_dir="/tmp/screenshot-$timestamp"
mkdir -p "$temp_dir"

echo "📸 Capturing screenshot..."
echo "URL: $url"
echo "Resolution(s): ${resolutions[*]}"

# Build and execute pageres command
cd "$temp_dir"
if ! pageres "$url" "${resolutions[@]}" --filename="screenshot-$timestamp"; then
    echo "Failed to capture screenshot"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Find generated screenshots
screenshots=(screenshot-$timestamp*.png)

if [[ ${#screenshots[@]} -eq 0 ]] || [[ ! -f "${screenshots[0]}" ]]; then
    echo "No screenshots generated"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Create markdown file
md_file="$temp_dir/README.md"
{
    echo "# $description"
    echo ""
    echo "Created: $(date)"
    echo ""
    echo "## Screenshots"
    echo ""
    
    for screenshot in "${screenshots[@]}"; do
        # Extract resolution from filename if possible
        if [[ "$screenshot" =~ -([0-9]+x[0-9]+)\.png$ ]]; then
            resolution="${BASH_REMATCH[1]}"
            echo "### $resolution"
        fi
        echo "![$screenshot]($screenshot)"
        echo ""
    done
    
    echo "## Source"
    echo "- URL: $url"
    echo "- Captured: $(date)"
} > "$md_file"

echo "📤 Creating private GitHub gist..."
gist_output=$(gh gist create --desc "$description" "$md_file" 2>&1)
gist_url=$(echo "$gist_output" | tail -1)

if [[ ! "$gist_url" =~ https://gist.github.com/ ]]; then
    echo "Failed to create gist"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Extract gist ID from URL
gist_id="${gist_url##*/}"

echo "📎 Adding screenshots to gist..."
gist_dir="/tmp/gist-$gist_id"

# Clone the gist
if ! git clone -q "https://gist.github.com/$gist_id.git" "$gist_dir" 2>/dev/null; then
    echo "Failed to clone gist"
    cd - > /dev/null
    rm -rf "$temp_dir"
    exit 1
fi

# Copy screenshots to gist and push
cp "${screenshots[@]}" "$gist_dir/"
cd "$gist_dir"
git add *.png
git commit -q --no-gpg-sign -m "Add screenshots"

if ! { git push -q origin master 2>/dev/null || git push -q origin main 2>/dev/null; }; then
    echo "Failed to upload screenshots to gist"
    cd - > /dev/null
    rm -rf "$temp_dir" "$gist_dir"
    exit 1
fi

cd - > /dev/null

echo "✅ Screenshots uploaded!"
echo "Gist URL: $gist_url"
echo ""
echo "📋 Direct image URLs:"
for screenshot in "${screenshots[@]}"; do
    # Get GitHub username from git config
    github_user=$(gh api user --jq .login 2>/dev/null || echo "phinze")
    echo "https://gist.githubusercontent.com/$github_user/$gist_id/raw/$screenshot"
done
echo ""
echo "📋 Markdown embeds:"
for screenshot in "${screenshots[@]}"; do
    github_user=$(gh api user --jq .login 2>/dev/null || echo "phinze")
    if [[ "$screenshot" =~ -([0-9]+x[0-9]+)\.png$ ]]; then
        resolution="${BASH_REMATCH[1]}"
        echo "![$resolution](https://gist.githubusercontent.com/$github_user/$gist_id/raw/$screenshot)"
    else
        echo "![$screenshot](https://gist.githubusercontent.com/$github_user/$gist_id/raw/$screenshot)"
    fi
done

# Clean up
rm -rf "$temp_dir" "$gist_dir"