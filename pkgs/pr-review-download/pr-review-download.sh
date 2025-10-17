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

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    exit 1
fi

# Check if claude is installed (for filtering step)
if ! command -v claude &> /dev/null; then
    print_warning "Claude CLI not found - will skip intelligent filtering"
    SKIP_FILTERING=true
else
    SKIP_FILTERING=false
fi

# Check for explicit parameters: owner repo pr-number
if [[ $# -eq 3 ]]; then
    OWNER="$1"
    REPO="$2"
    PR_NUMBER="$3"
    print_info "Using provided parameters: $OWNER/$REPO PR #$PR_NUMBER"

    # Fetch PR details
    PR_JSON=$(gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" --json number,title,url,state 2>/dev/null || echo "")

    if [[ -z "$PR_JSON" ]]; then
        print_error "Could not find PR #$PR_NUMBER in $OWNER/$REPO"
        exit 1
    fi

    PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
    PR_URL=$(echo "$PR_JSON" | jq -r '.url')
    PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
    CURRENT_BRANCH="(external PR)"
else
    # Auto-detect from current branch
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        print_info "Usage: $0 <owner> <repo> <pr-number>"
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
        print_info "You can specify explicit parameters: $0 <owner> <repo> <pr-number>"
        exit 1
    fi

    PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
    PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
    PR_URL=$(echo "$PR_JSON" | jq -r '.url')
    PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
fi

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
gh pr view "$PR_NUMBER" --repo "$OWNER/$REPO" --json number,title,body,author,createdAt,updatedAt,state,url,headRefName,baseRefName \
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

# Get review threads with resolution status (GraphQL)
print_info "Fetching review thread resolution status..."
gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes {
              id
            }
          }
        }
      }
    }
  }
}" | jq '.data.repository.pullRequest.reviewThreads.nodes | map({id: .comments.nodes[0].id, isResolved: .isResolved})' > "$OUTPUT_DIR/thread-resolution.json"

# Get issue comments (general conversation)
print_info "Fetching issue comments..."
gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/comments" \
    --paginate \
    > "$OUTPUT_DIR/issue-comments.json"

# Get files changed
print_info "Fetching files changed..."
gh pr diff "$PR_NUMBER" --repo "$OWNER/$REPO" --name-only > "$OUTPUT_DIR/files-changed.txt"

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
# Use process substitution to avoid subshell issue with pipe
UNRESOLVED_COUNT=0
RESOLVED_COUNT=0

while IFS= read -r comment; do
    COMMENT_ID=$(echo "$comment" | jq -r '.id')
    FILE_PATH=$(echo "$comment" | jq -r '.path')
    LINE=$(echo "$comment" | jq -r '.line // .original_line // "unknown"')
    AUTHOR=$(echo "$comment" | jq -r '.user.login')
    BODY=$(echo "$comment" | jq -r '.body')
    CREATED=$(echo "$comment" | jq -r '.created_at')

    # Check if this comment's thread is resolved using GraphQL data
    IS_RESOLVED=$(jq -r --arg id "$COMMENT_ID" '.[] | select(.id == $id) | .isResolved' "$OUTPUT_DIR/thread-resolution.json" 2>/dev/null || echo "false")

    if [[ "$IS_RESOLVED" == "true" ]]; then
        STATUS="✅ RESOLVED"
        ((RESOLVED_COUNT++)) || true
    else
        STATUS="❌ UNRESOLVED"
        ((UNRESOLVED_COUNT++)) || true
    fi

    # Sanitize file path for filename
    SAFE_PATH=$(echo "$FILE_PATH" | tr '/' '_')

    # Append to file-specific comment file
    {
        echo "## Comment by $AUTHOR (Line $LINE) - $STATUS"
        echo "Date: $CREATED"
        echo ""
        echo "$BODY"
        echo ""
        echo "---"
        echo ""
    } >> "$OUTPUT_DIR/by-file/${SAFE_PATH}.md"

    # Add to summary
    echo "- **$FILE_PATH:$LINE** - $AUTHOR [$STATUS]: $(echo "$BODY" | head -n1 | cut -c1-80)..." >> "$OUTPUT_DIR/SUMMARY.md"
done < <(jq -c '.[]' "$OUTPUT_DIR/review-comments.json" 2>/dev/null) || true

# Save comment stats
cat > "$OUTPUT_DIR/comment-stats.txt" << EOF
Resolved: $RESOLVED_COUNT
Unresolved: $UNRESOLVED_COUNT
Total: $((RESOLVED_COUNT + UNRESOLVED_COUNT))
EOF

echo -e "\n## General Comments\n" >> "$OUTPUT_DIR/SUMMARY.md"

# Process issue comments
jq -r '.[] | "### Comment by \(.user.login)\n\n\(.body)\n\nDate: \(.created_at)\n\n---\n"' \
    "$OUTPUT_DIR/issue-comments.json" >> "$OUTPUT_DIR/SUMMARY.md" 2>/dev/null || true

# Create an index file
cat > "$OUTPUT_DIR/INDEX.md" << EOF
# PR Review Download - PR #$PR_NUMBER

This directory contains all reviews and comments for PR #$PR_NUMBER.

## Files:

- **ACTIONABLE.md** - ⭐ Claude-filtered action items (critical issues, questions, etc.)
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
  $(cat "$OUTPUT_DIR/comment-stats.txt" 2>/dev/null | sed 's/^/  - /' || echo "")
- Issue comments: $(jq '. | length' "$OUTPUT_DIR/issue-comments.json" 2>/dev/null || echo 0)
- Files changed: $(wc -l < "$OUTPUT_DIR/files-changed.txt" | tr -d ' ')

EOF

# Run Claude-powered filtering if available
if [[ "$SKIP_FILTERING" == "false" ]]; then
    print_info "Running intelligent comment filtering with Claude..."

    # Build the prompt with all comments
    PROMPT_FILE="$OUTPUT_DIR/filter-prompt.txt"
    cat > "$PROMPT_FILE" << 'PROMPT_EOF'
You are helping filter code review comments for action in a Claude Code session.

Your task: Analyze the review comments below and categorize them into:
1. **Critical Issues** - Bugs, security issues, or logic errors that must be fixed
2. **Important Feedback** - Substantive suggestions for improvement (design, architecture, performance)
3. **Style/Nitpicks** - Minor style suggestions, formatting, naming
4. **Questions** - Questions from reviewers that need responses
5. **Noise** - Automated tool comments (especially CodeRabbit), already-addressed items, or irrelevant comments

Note: All comments below are UNRESOLVED on GitHub. Resolved comments have been filtered out.

For each category, list only the actionable items with:
- File path and line number
- Author (if human reviewer)
- Brief summary of the comment (1-2 sentences max)

## PR Context

PROMPT_EOF

    # Add PR metadata
    echo "**Title:** $PR_TITLE" >> "$PROMPT_FILE"
    echo "**Author:** $(jq -r '.author.login' "$OUTPUT_DIR/pr-metadata.json")" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"
    jq -r '.body // "No description"' "$OUTPUT_DIR/pr-metadata.json" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"
    echo "**Files changed:**" >> "$PROMPT_FILE"
    cat "$OUTPUT_DIR/files-changed.txt" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"

    # Add all review comments
    echo "## Review Comments to Filter" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"

    jq -c '.[]' "$OUTPUT_DIR/review-comments.json" 2>/dev/null | while IFS= read -r comment; do
        COMMENT_ID=$(echo "$comment" | jq -r '.id')

        # Check if this comment's thread is resolved
        IS_RESOLVED=$(jq -r --arg id "$COMMENT_ID" '.[] | select(.id == $id) | .isResolved' "$OUTPUT_DIR/thread-resolution.json" 2>/dev/null || echo "false")

        if [[ "$IS_RESOLVED" == "true" ]]; then
            # Skip resolved comments
            continue
        fi

        FILE_PATH=$(echo "$comment" | jq -r '.path')
        LINE=$(echo "$comment" | jq -r '.line // .original_line // "unknown"')
        AUTHOR=$(echo "$comment" | jq -r '.user.login')
        BODY=$(echo "$comment" | jq -r '.body')

        cat >> "$PROMPT_FILE" << EOF

---
**File:** $FILE_PATH:$LINE
**Author:** $AUTHOR

$BODY

EOF
    done || true

    # Add issue comments
    COMMENT_COUNT=$(jq '. | length' "$OUTPUT_DIR/issue-comments.json" 2>/dev/null || echo 0)
    if [[ "$COMMENT_COUNT" -gt 0 ]]; then
        echo "" >> "$PROMPT_FILE"
        echo "## General PR Comments" >> "$PROMPT_FILE"
        echo "" >> "$PROMPT_FILE"

        jq -c '.[]' "$OUTPUT_DIR/issue-comments.json" 2>/dev/null | while IFS= read -r comment; do
            AUTHOR=$(echo "$comment" | jq -r '.user.login')
            BODY=$(echo "$comment" | jq -r '.body')

            cat >> "$PROMPT_FILE" << EOF

---
**Author:** $AUTHOR

$BODY

EOF
        done || true
    fi

    # Run Claude from the output directory to avoid picking up project CLAUDE.md
    (
        cd "$OUTPUT_DIR"
        claude -p < filter-prompt.txt > ACTIONABLE.md 2>&1
    )

    if [[ -f "$OUTPUT_DIR/ACTIONABLE.md" ]]; then
        print_success "Generated filtered action items: $OUTPUT_DIR/ACTIONABLE.md"
    else
        print_warning "Failed to generate ACTIONABLE.md"
    fi
else
    print_info "Skipping intelligent filtering (Claude CLI not available)"
fi

print_success "PR review data downloaded to $OUTPUT_DIR"
print_info "View summary: $OUTPUT_DIR/SUMMARY.md"
print_info "View index: $OUTPUT_DIR/INDEX.md"
if [[ -f "$OUTPUT_DIR/ACTIONABLE.md" ]]; then
    print_info "View filtered action items: $OUTPUT_DIR/ACTIONABLE.md"
fi