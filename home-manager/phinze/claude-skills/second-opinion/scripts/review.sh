#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: review.sh --reviewer codex|claude [options]

Options:
  --scope working-copy|branch|revision  Diff scope (default: working-copy)
  --base REV                           Branch base (default: trunk()/remote default)
  --revision REV                       Revision to review
  --focus FOCUS                        general, security, performance,
                                       error-handling, or custom text
  --context auto|none|PATH             Project instructions (default: auto)
  --preview                            Print diff statistics and exit
  --prompt-only                        Print the assembled prompt and exit
  --allow-large                        Permit diffs over 2,000 changed lines
  -h, --help                           Show this help
EOF
}

reviewer=""
scope="working-copy"
base=""
revision=""
focus="general"
context="auto"
preview=false
prompt_only=false
allow_large=false

while (( $# > 0 )); do
  case "$1" in
    --reviewer) reviewer="${2:?missing reviewer}"; shift 2 ;;
    --scope) scope="${2:?missing scope}"; shift 2 ;;
    --base) base="${2:?missing base}"; shift 2 ;;
    --revision) revision="${2:?missing revision}"; shift 2 ;;
    --focus) focus="${2:?missing focus}"; shift 2 ;;
    --context) context="${2:?missing context}"; shift 2 ;;
    --preview) preview=true; shift ;;
    --prompt-only) prompt_only=true; shift ;;
    --allow-large) allow_large=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$reviewer" in
  codex|claude) ;;
  "") printf '%s\n' '--reviewer is required' >&2; exit 2 ;;
  *) printf 'unsupported reviewer: %s\n' "$reviewer" >&2; exit 2 ;;
esac

case "$scope" in
  working-copy|branch|revision) ;;
  *) printf 'unsupported scope: %s\n' "$scope" >&2; exit 2 ;;
esac

if [[ "$scope" == revision && -z "$revision" ]]; then
  printf '%s\n' '--revision is required for revision scope' >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd -- "$script_dir/.." && pwd)"
schema="$skill_dir/references/review-schema.json"
review_prompt="$skill_dir/references/review-prompt.md"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/second-opinion.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
diff_file="$tmp_dir/change.diff"
prompt_file="$tmp_dir/prompt.md"
result_file="$tmp_dir/result.json"
stderr_file="$tmp_dir/stderr.log"

if command -v jj >/dev/null 2>&1 && repo_root="$(jj root 2>/dev/null)"; then
  vcs="jj"
  cd -- "$repo_root"
  case "$scope" in
    working-copy)
      jj diff --git -r @ > "$diff_file"
      scope_label="working copy (@)"
      ;;
    branch)
      [[ -n "$base" ]] || base='trunk()'
      jj diff --git --from "$base" --to @ > "$diff_file"
      scope_label="$base..@"
      ;;
    revision)
      jj diff --git -r "$revision" > "$diff_file"
      scope_label="revision $revision"
      ;;
  esac
elif command -v git >/dev/null 2>&1 && repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  vcs="git"
  cd -- "$repo_root"
  case "$scope" in
    working-copy)
      {
        git diff --no-ext-diff HEAD
        while IFS= read -r -d '' path; do
          git diff --no-index -- /dev/null "$path" || true
        done < <(git ls-files --others --exclude-standard -z)
      } > "$diff_file"
      scope_label="working copy (HEAD)"
      ;;
    branch)
      if [[ -z "$base" ]]; then
        base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        [[ -n "$base" ]] || base="main"
      fi
      git diff --no-ext-diff "$base"...HEAD > "$diff_file"
      scope_label="$base...HEAD"
      ;;
    revision)
      git show --format= --no-ext-diff "$revision" > "$diff_file"
      scope_label="revision $revision"
      ;;
  esac
else
  printf '%s\n' 'not inside a jj or git repository' >&2
  exit 2
fi

if [[ ! -s "$diff_file" ]]; then
  printf 'No changes found for %s.\n' "$scope_label"
  exit 3
fi

read -r files added removed < <(
  awk '
    /^diff --git / { files++ }
    /^\+/ && !/^\+\+\+/ { added++ }
    /^-/ && !/^---/ { removed++ }
    END { print files + 0, added + 0, removed + 0 }
  ' "$diff_file"
)
changed=$((added + removed))

summary="VCS: $vcs
Scope: $scope_label
Files: $files
Changed lines: $changed (+$added/-$removed)"

if $preview; then
  printf '%s\n' "$summary"
  exit 0
fi

printf '%s\n' "$summary" >&2
if (( changed > 2000 )) && ! $allow_large; then
  printf '%s\n' 'Diff exceeds 2,000 changed lines; narrow it or rerun with --allow-large.' >&2
  exit 4
fi

context_files=()
case "$context" in
  auto)
    [[ -f "$repo_root/AGENTS.md" ]] && context_files+=("$repo_root/AGENTS.md")
    [[ -f "$repo_root/CLAUDE.md" ]] && context_files+=("$repo_root/CLAUDE.md")
    ;;
  none) ;;
  *)
    if [[ "$context" = /* ]]; then
      context_path="$context"
    else
      context_path="$repo_root/$context"
    fi
    [[ -f "$context_path" ]] || {
      printf 'context file not found: %s\n' "$context" >&2
      exit 2
    }
    context_files+=("$context_path")
    ;;
esac

case "$focus" in
  general) focus_text="" ;;
  security)
    focus_text="Prioritize exploitable security and authorization failures, unsafe input handling, secret exposure, and trust-boundary mistakes."
    ;;
  performance)
    focus_text="Prioritize meaningful regressions in latency, throughput, memory use, I/O, algorithmic complexity, and resource lifetime."
    ;;
  error-handling)
    focus_text="Prioritize swallowed errors, misleading recovery, partial failure, cleanup gaps, retry hazards, and incorrect user-visible failure behavior."
    ;;
  *) focus_text="$focus" ;;
esac

{
  cat "$review_prompt"
  printf '\nRepository root: %s\nReview scope: %s\n' "$repo_root" "$scope_label"
  if [[ -n "$focus_text" ]]; then
    printf '\nAdditional focus:\n%s\n' "$focus_text"
  fi
  for path in "${context_files[@]}"; do
    printf '\nProject instructions from %s:\n<project-instructions>\n' "${path#"$repo_root/"}"
    cat "$path"
    printf '\n</project-instructions>\n'
  done
  printf '\nProposed change:\n<diff>\n'
  cat "$diff_file"
  printf '\n</diff>\n'
} > "$prompt_file"

if $prompt_only; then
  cat "$prompt_file"
  exit 0
fi

case "$reviewer" in
  codex)
    if ! command -v codex >/dev/null 2>&1; then
      printf '%s\n' 'codex: command not found' >&2
      exit 127
    fi
    if ! codex exec \
      --cd "$repo_root" \
      --skip-git-repo-check \
      --sandbox read-only \
      --ephemeral \
      --output-schema "$schema" \
      --output-last-message "$result_file" \
      - < "$prompt_file" > /dev/null 2> "$stderr_file"; then
      cat "$stderr_file" >&2
      exit 1
    fi
    cat "$result_file"
    ;;
  claude)
    if ! command -v claude >/dev/null 2>&1; then
      printf '%s\n' 'claude: command not found' >&2
      exit 127
    fi
    schema_json="$(jq -c . "$schema")"
    if ! claude \
      --print \
      --safe-mode \
      --permission-mode plan \
      --tools 'Read,Grep,Glob' \
      --no-session-persistence \
      --output-format json \
      --json-schema "$schema_json" \
      < "$prompt_file" > "$result_file" 2> "$stderr_file"; then
      cat "$stderr_file" >&2
      exit 1
    fi
    if jq -e '.structured_output != null' "$result_file" >/dev/null 2>&1; then
      jq '.structured_output' "$result_file"
    elif jq -e '.result | type == "string"' "$result_file" >/dev/null 2>&1; then
      jq -r '.result' "$result_file"
    else
      cat "$result_file"
    fi
    ;;
esac
