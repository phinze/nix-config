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
  --prompt-only                        Print a replayable prompt, preserve its snapshot, and exit
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
manifest_file="$tmp_dir/change-summary.txt"
prompt_file="$tmp_dir/prompt.md"
result_file="$tmp_dir/result.json"
review_file="$tmp_dir/review.json"
stderr_file="$tmp_dir/stderr.log"

resolve_jj_commit() {
  local rev="$1" resolved
  if ! resolved="$(jj log -r "$rev" --no-graph -T 'commit_id ++ "\n"' 2>/dev/null)"; then
    printf 'cannot resolve jj revision: %s\n' "$rev" >&2
    return 1
  fi
  if [[ -z "$resolved" || "$resolved" == *$'\n'* ]]; then
    printf 'jj revision must resolve to one commit: %s\n' "$rev" >&2
    return 1
  fi
  printf '%s' "$resolved"
}

if command -v jj >/dev/null 2>&1 && repo_root="$(jj root 2>/dev/null)"; then
  vcs="jj"
  cd -- "$repo_root"
  case "$scope" in
    working-copy)
      target_commit="$(resolve_jj_commit '@')"
      jj --ignore-working-copy diff --git -r "$target_commit" > "$diff_file"
      scope_label="working copy (@)"
      boundary_label="jj revision $target_commit"
      inspect_command="jj --ignore-working-copy diff --git -r $target_commit"
      boundary_note=""
      ;;
    branch)
      [[ -n "$base" ]] || base='trunk()'
      base_commit="$(resolve_jj_commit "$base")"
      target_commit="$(resolve_jj_commit '@')"
      jj --ignore-working-copy diff --git --from "$base_commit" --to "$target_commit" > "$diff_file"
      scope_label="$base..@"
      boundary_label="jj range $base_commit..$target_commit"
      inspect_command="jj --ignore-working-copy diff --git --from $base_commit --to $target_commit"
      boundary_note=""
      ;;
    revision)
      target_commit="$(resolve_jj_commit "$revision")"
      jj --ignore-working-copy diff --git -r "$target_commit" > "$diff_file"
      scope_label="revision $revision"
      boundary_label="jj revision $target_commit"
      inspect_command="jj --ignore-working-copy diff --git -r $target_commit"
      boundary_note=""
      ;;
  esac
elif command -v git >/dev/null 2>&1 && repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  vcs="git"
  cd -- "$repo_root"
  case "$scope" in
    working-copy)
      base_commit="$(git rev-parse 'HEAD^{commit}')"
      {
        git diff --no-ext-diff "$base_commit"
        while IFS= read -r -d '' path; do
          git diff --no-index -- /dev/null "$path" || true
        done < <(git ls-files --others --exclude-standard -z)
      } > "$diff_file"
      scope_label="working copy (HEAD)"
      boundary_label="git working-copy snapshot relative to $base_commit"
      inspect_command="git --no-optional-locks diff --no-ext-diff $base_commit"
      boundary_note="The live git working tree can move; the snapshot is authoritative."
      ;;
    branch)
      if [[ -z "$base" ]]; then
        base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        [[ -n "$base" ]] || base="main"
      fi
      base_commit="$(git merge-base "$base" HEAD)"
      target_commit="$(git rev-parse 'HEAD^{commit}')"
      git diff --no-ext-diff "$base_commit" "$target_commit" > "$diff_file"
      scope_label="$base...HEAD"
      boundary_label="git range $base_commit..$target_commit"
      inspect_command="git --no-optional-locks diff --no-ext-diff $base_commit $target_commit"
      boundary_note=""
      ;;
    revision)
      target_commit="$(git rev-parse "${revision}^{commit}")"
      git show --format= --no-ext-diff "$target_commit" > "$diff_file"
      scope_label="revision $revision"
      boundary_label="git revision $target_commit"
      inspect_command="git --no-optional-locks show --format= --no-ext-diff $target_commit"
      boundary_note=""
      ;;
  esac
else
  printf '%s\n' 'not inside a jj or git repository' >&2
  exit 2
fi

if [[ ! -s "$diff_file" ]]; then
  printf 'No changes found for %s.\n' "$scope_label" >&2
  exit 3
fi

if command -v sha256sum >/dev/null 2>&1; then
  snapshot_sha256="$(sha256sum "$diff_file" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
  snapshot_sha256="$(shasum -a 256 "$diff_file" | awk '{ print $1 }')"
else
  printf '%s\n' 'cannot hash review snapshot: sha256sum or shasum is required' >&2
  exit 127
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

awk '
  function emit() {
    if (seen) printf "%s (+%d/-%d)\n", header, file_added, file_removed
  }
  /^diff --git / {
    emit()
    header = $0
    sub(/^diff --git /, "", header)
    file_added = 0
    file_removed = 0
    seen = 1
    next
  }
  /^\+/ && !/^\+\+\+/ { file_added++ }
  /^-/ && !/^---/ { file_removed++ }
  END { emit() }
' "$diff_file" > "$manifest_file"

summary="VCS: $vcs
Scope: $scope_label
Files: $files
Changed lines: $changed (+$added/-$removed)"

if $preview; then
  printf '%s\n' "$summary"
  exit 0
fi

printf '%s\n' "$summary" >&2

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
  printf '\nReview environment:\n'
  printf -- '- Repository root: %s\n' "$repo_root"
  printf -- '- VCS: %s\n' "$vcs"
  printf -- '- Review scope: %s\n' "$scope_label"
  printf -- '- Immutable boundary: %s\n' "$boundary_label"
  printf -- '- Authoritative diff snapshot: %s\n' "$diff_file"
  printf -- '- Reproduce with: %s\n' "$inspect_command"
  if [[ -n "$boundary_note" ]]; then
    printf -- '- Boundary note: %s\n' "$boundary_note"
  fi
  printf -- '- Files: %d\n' "$files"
  printf -- '- Changed lines: %d (+%d/-%d)\n' "$changed" "$added" "$removed"
  if [[ -n "$focus_text" ]]; then
    printf '\nAdditional focus:\n%s\n' "$focus_text"
  fi
  printf '\nChanged-file summary:\n'
  cat "$manifest_file"
  printf '\nProject instruction files to read:\n'
  if (( ${#context_files[@]} == 0 )); then
    printf '%s\n' '(none supplied)'
  else
    for path in "${context_files[@]}"; do
      printf -- '- %s\n' "$path"
    done
  fi
} > "$prompt_file"

if $prompt_only; then
  trap - EXIT
  cat "$prompt_file"
  printf 'Review snapshot preserved at %s\n' "$diff_file" >&2
  exit 0
fi

claude_add_dirs=("$tmp_dir")
for path in "${context_files[@]}"; do
  claude_add_dirs+=("$(dirname -- "$path")")
done

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
    cp "$result_file" "$review_file"
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
      --restricted \
      --add-dir "${claude_add_dirs[@]}" \
      --permission-mode plan \
      --tools 'Read,Grep,Glob,Bash' \
      --no-session-persistence \
      --output-format json \
      --json-schema "$schema_json" \
      < "$prompt_file" > "$result_file" 2> "$stderr_file"; then
      cat "$stderr_file" >&2
      exit 1
    fi
    if jq -e '.structured_output != null' "$result_file" >/dev/null 2>&1; then
      jq '.structured_output' "$result_file" > "$review_file"
    elif jq -e '.result | type == "string"' "$result_file" >/dev/null 2>&1; then
      jq -r '.result' "$result_file" > "$review_file"
    else
      cp "$result_file" "$review_file"
    fi
    ;;
esac

if ! jq -e --arg expected "$snapshot_sha256" \
  '.snapshot_sha256 == $expected' "$review_file" >/dev/null 2>&1; then
  printf '%s\n' 'reviewer did not verify the authoritative diff snapshot' >&2
  cat "$review_file" >&2
  exit 1
fi

cat "$review_file"
