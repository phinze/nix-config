#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
print_info "Current branch: $CURRENT_BRANCH"

# Get remote info
REMOTE_URL=$(git config --get remote.origin.url || echo "")
if [[ -z "$REMOTE_URL" ]]; then
    print_error "No origin remote found"
    exit 1
fi

# Parse owner and repo from remote URL
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
elif [[ "$REMOTE_URL" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
else
    print_error "Could not parse GitHub owner/repo from remote URL: $REMOTE_URL"
    exit 1
fi

print_info "Repository: $OWNER/$REPO"

# Find PR associated with current branch
print_info "Finding pull request for branch '$CURRENT_BRANCH'..."
PR_JSON=$(gh pr view "$CURRENT_BRANCH" --json number,title,url,state 2>/dev/null || echo "")

if [[ -z "$PR_JSON" ]]; then
    print_error "No pull request found for branch '$CURRENT_BRANCH'"
    print_info "You can specify a PR number as an argument: $0 <PR_NUMBER>"
    exit 1
fi

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
PR_URL=$(echo "$PR_JSON" | jq -r '.url')
PR_STATE=$(echo "$PR_JSON" | jq -r '.state')

print_success "Found PR #$PR_NUMBER: $PR_TITLE"
print_info "URL: $PR_URL"
print_info "State: $PR_STATE"

# Create output directory
OUTPUT_DIR="./tmp/code-review/pr-${PR_NUMBER}"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

print_info "Downloading PR data to $OUTPUT_DIR..."

# Save PR metadata
print_info "Fetching PR details..."
gh pr view "$PR_NUMBER" --json number,title,body,author,createdAt,updatedAt,state,url,headRefName,baseRefName \
    > "$OUTPUT_DIR/pr-metadata.json"

# Get PR reviews
print_info "Fetching reviews..."
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" \
    --paginate \
    > "$OUTPUT_DIR/reviews.json"

# Get review comments (comments on specific lines of code)
print_info "Fetching review comments..."
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
    --paginate \
    > "$OUTPUT_DIR/review-comments.json"

# Get issue comments (general conversation)
print_info "Fetching issue comments..."
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
    --paginate \
    > "$OUTPUT_DIR/issue-comments.json"

# Get files changed
print_info "Fetching files changed..."
gh pr diff "$PR_NUMBER" --name-only > "$OUTPUT_DIR/files-changed.txt"

# Process and organize comments by file
print_info "Organizing comments by file..."
mkdir -p "$OUTPUT_DIR/by-file"

# Create a summary file
cat > "$OUTPUT_DIR/SUMMARY.md" << EOF
# PR #$PR_NUMBER: $PR_TITLE

**URL:** $PR_URL  
**State:** $PR_STATE  
**Branch:** $CURRENT_BRANCH  

## Reviews Summary

EOF

# Process reviews and create summary
jq -r '.[] | "### Review by \(.user.login) - \(.state)\n\n\(.body // "No review body")\n\nSubmitted: \(.submitted_at)\n\n---\n"' \
    "$OUTPUT_DIR/reviews.json" >> "$OUTPUT_DIR/SUMMARY.md" 2>/dev/null || true

echo -e "\n## File Comments\n" >> "$OUTPUT_DIR/SUMMARY.md"

# Process review comments and organize by file
jq -c '.[]' "$OUTPUT_DIR/review-comments.json" 2>/dev/null | while IFS= read -r comment; do
    FILE_PATH=$(echo "$comment" | jq -r '.path')
    LINE=$(echo "$comment" | jq -r '.line // .original_line // "unknown"')
    AUTHOR=$(echo "$comment" | jq -r '.user.login')
    BODY=$(echo "$comment" | jq -r '.body')
    CREATED=$(echo "$comment" | jq -r '.created_at')
    
    # Sanitize file path for filename
    SAFE_PATH=$(echo "$FILE_PATH" | tr '/' '_')
    
    # Append to file-specific comment file
    {
        echo "## Comment by $AUTHOR (Line $LINE)"
        echo "Date: $CREATED"
        echo ""
        echo "$BODY"
        echo ""
        echo "---"
        echo ""
    } >> "$OUTPUT_DIR/by-file/${SAFE_PATH}.md"
    
    # Add to summary
    echo "- **$FILE_PATH:$LINE** - $AUTHOR: $(echo "$BODY" | head -n1 | cut -c1-80)..." >> "$OUTPUT_DIR/SUMMARY.md"
done || true

echo -e "\n## General Comments\n" >> "$OUTPUT_DIR/SUMMARY.md"

# Process issue comments
jq -r '.[] | "### Comment by \(.user.login)\n\n\(.body)\n\nDate: \(.created_at)\n\n---\n"' \
    "$OUTPUT_DIR/issue-comments.json" >> "$OUTPUT_DIR/SUMMARY.md" 2>/dev/null || true

# Create an index file
cat > "$OUTPUT_DIR/INDEX.md" << EOF
# PR Review Download - PR #$PR_NUMBER

This directory contains all reviews and comments for PR #$PR_NUMBER.

## Files:

- **SUMMARY.md** - Human-readable summary of all reviews and comments
- **pr-metadata.json** - PR metadata
- **reviews.json** - All reviews
- **review-comments.json** - Comments on specific lines of code
- **issue-comments.json** - General PR conversation
- **files-changed.txt** - List of files changed in the PR
- **by-file/** - Comments organized by file

## Quick Stats:

- Reviews: $(jq '. | length' "$OUTPUT_DIR/reviews.json" 2>/dev/null || echo 0)
- Review comments: $(jq '. | length' "$OUTPUT_DIR/review-comments.json" 2>/dev/null || echo 0)
- Issue comments: $(jq '. | length' "$OUTPUT_DIR/issue-comments.json" 2>/dev/null || echo 0)
- Files changed: $(wc -l < "$OUTPUT_DIR/files-changed.txt" | tr -d ' ')

EOF

print_success "PR review data downloaded to $OUTPUT_DIR"
print_info "View summary: $OUTPUT_DIR/SUMMARY.md"
print_info "View index: $OUTPUT_DIR/INDEX.md"