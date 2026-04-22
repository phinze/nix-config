#!/usr/bin/env bash
set -euo pipefail

# Common operations on Claude Code session history files.
# Sessions: JSONL in ~/.claude/projects/<mangled-path>/*.jsonl

SESSIONS_ROOT="$HOME/.claude/projects"

# Detect stat/date flavor once (GNU coreutils vs BSD). NixOS ships GNU,
# macOS ships BSD unless the user installs coreutils.
if stat --version >/dev/null 2>&1; then
  _stat_flavor=gnu
else
  _stat_flavor=bsd
fi

# Epoch mtime of a file
file_mtime() {
  if [[ "$_stat_flavor" == gnu ]]; then stat -c %Y "$1"; else stat -f %m "$1"; fi
}

# Print "epoch path" lines for one or more files (for sorting by mtime)
stat_mtime_paths() {
  if [[ "$_stat_flavor" == gnu ]]; then stat -c '%Y %n' "$@"; else stat -f '%m %N' "$@"; fi
}

# Format an epoch seconds value, e.g. fmt_epoch 1712345678 '+%Y-%m-%d'
fmt_epoch() {
  if [[ "$_stat_flavor" == gnu ]]; then date -d "@$1" "$2"; else date -r "$1" "$2"; fi
}

# Format N-days-ago as +%Y%m%d
ymd_days_ago() {
  if [[ "$_stat_flavor" == gnu ]]; then
    date -d "$1 days ago" '+%Y%m%d'
  else
    date -v-"$1"d '+%Y%m%d'
  fi
}

usage() {
  cat <<'EOF'
Usage: claude-sessions <command> [args]

Commands:
  dir [path]                        Print session directory for a project path (default: $PWD)
  list [--all | path] [--days N]    List recent sessions, most recent first
  search <term> [--all | path] [--days N]
                                    Search sessions for a term (uses rg)
  bash <session> [filter]           Extract Bash commands from a session
  extract <session> <type>          Extract content: user, assistant, bash, tools
  search-bash <term> [--all | path] [--days N]
                                    Search sessions and show matching Bash commands
  search-extract <term> <type> [--all | path] [--days N]
                                    Search sessions and extract content by type
  summary [--all | path] [--days N] List sessions with date, project, activity (U/T = user msgs/tools), first user message
  recap <session>                   Compact digest: all user messages (truncated) showing work progression
  tools-audit <session> [--mode M] [--summary|--json|--truncate N]
                                    Audit tool_use events. Default output is TSV columns:
                                    timestamp, permissionMode, outcome, tool, input (compact JSON).
                                    Outcome is ok | denied-user | denied-rule | error | no-result.
                                    --mode filters to a single permissionMode.
                                    --summary prints counts grouped by mode x outcome x tool.
                                    --json emits JSONL (tool.input is a real JSON value — use
                                      this when downstream code needs to reparse the input).
                                    --truncate N trims the TSV input column for readability.

With --all, commands include sessions from every project directory.
EOF
  exit 1
}

# Convert an absolute path to the Claude session directory name
session_dir() {
  local project_path="${1:-$PWD}"
  # Claude Code mangles both '/' and '.' to '-'
  local mangled
  mangled=$(echo "$project_path" | tr '/.' '--')
  echo "$SESSIONS_ROOT/$mangled"
}

# Filter file paths on stdin to those modified within N days
filter_by_days() {
  local days="${1:?days required}"
  local cutoff
  cutoff=$(ymd_days_ago "$days")
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local d
    d=$(fmt_epoch "$(file_mtime "$f")" '+%Y%m%d')
    if [[ "$d" -ge "$cutoff" ]]; then
      echo "$f"
    fi
  done
}

# Pull the project path out of the session JSONL's cwd field.
session_project() {
  local session="$1"
  local cwd
  cwd=$(jq -r 'select(.cwd) | .cwd' "$session" 2>/dev/null | head -1)
  if [[ -n "$cwd" ]]; then
    echo "${cwd/#$HOME/\~}"
  else
    # Fallback: try to reverse-mangle (lossy: dots and slashes collapse)
    echo "$session" | sed "s|.*/projects/||; s|/[^/]*\$||; s|-|/|g"
  fi
}

# Format a session path as "project (date)"
format_session_header() {
  local session="$1"
  local project date
  project=$(session_project "$session")
  date=$(fmt_epoch "$(file_mtime "$session")" '+%Y-%m-%d')
  echo "=== $project ($date) ==="
}

# Parse --days N from args, returning remaining args via REPLY_ARGS and days via REPLY_DAYS
parse_days_opt() {
  REPLY_DAYS=""
  REPLY_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days) REPLY_DAYS="$2"; shift 2 ;;
      *) REPLY_ARGS+=("$1"); shift ;;
    esac
  done
}

# Apply --days filter if set, otherwise pass through
maybe_filter_days() {
  if [[ -n "${REPLY_DAYS:-}" ]]; then
    filter_by_days "$REPLY_DAYS"
  else
    cat
  fi
}

# List sessions sorted by modification time, most recent first
cmd_list() {
  parse_days_opt "$@"
  set -- "${REPLY_ARGS[@]+"${REPLY_ARGS[@]}"}"
  local dir
  if [[ "${1:-}" == "--all" ]]; then
    fd --extension jsonl --changed-within 30d . "$SESSIONS_ROOT" --exec bash -c '
      for f; do
        if stat --version >/dev/null 2>&1; then stat -c "%Y %n" "$f"; else stat -f "%m %N" "$f"; fi
      done' _ {} \
      | sort -rn | awk '{print $2}' \
      | maybe_filter_days
    return
  fi
  dir=$(session_dir "${1:-$PWD}")
  if [[ ! -d "$dir" ]]; then
    echo "No sessions found in $dir" >&2
    exit 1
  fi
  stat_mtime_paths "$dir"/*.jsonl 2>/dev/null | sort -rn | awk 'NR<=20 {print $2}' \
    | maybe_filter_days
}

# Search for a term across sessions
cmd_search() {
  local term="${1:?search term required}"
  shift
  parse_days_opt "$@"
  set -- "${REPLY_ARGS[@]+"${REPLY_ARGS[@]}"}"
  if [[ "${1:-}" == "--all" ]]; then
    rg --files-with-matches --glob '*.jsonl' "$term" "$SESSIONS_ROOT" 2>/dev/null \
      | maybe_filter_days || true
  else
    local dir
    dir=$(session_dir "${1:-$PWD}")
    rg --files-with-matches "$term" "$dir"/*.jsonl 2>/dev/null | maybe_filter_days || true
  fi
}

# Extract Bash commands from a session, optionally filtering by substring
cmd_bash() {
  local session="${1:?session file required}"
  local filter="${2:-}"
  if [[ -n "$filter" ]]; then
    jq -r --arg f "$filter" '
      select(.type == "assistant") | .message.content[]? |
      select(.type == "tool_use" and .name == "Bash") |
      .input.command | select(contains($f))
    ' "$session"
  else
    jq -r '
      select(.type == "assistant") | .message.content[]? |
      select(.type == "tool_use" and .name == "Bash") | .input.command
    ' "$session"
  fi
}

# Extract different content types from a session
cmd_extract() {
  local session="${1:?session file required}"
  local type="${2:?type required: user, assistant, bash, tools}"
  case "$type" in
    user)
      jq -r '
        select(.type == "user") | .message.content |
        if type == "string" then .
        elif type == "array" then map(select(.type == "text") | .text) | join("\n")
        else empty end
      ' "$session"
      ;;
    assistant)
      jq -r '
        select(.type == "assistant") | .message.content[]? |
        select(.type == "text") | .text
      ' "$session"
      ;;
    bash)
      cmd_bash "$session"
      ;;
    tools)
      jq -r '
        select(.type == "assistant") | .message.content[]? |
        select(.type == "tool_use") | "\(.name): \(.input | tostring[:120])"
      ' "$session"
      ;;
    *)
      echo "Unknown type: $type (expected: user, assistant, bash, tools)" >&2
      exit 1
      ;;
  esac
}

# Search sessions and extract matching Bash commands from all of them
cmd_search_bash() {
  local term="${1:?search term required}"
  shift
  local sessions
  sessions=$(cmd_search "$term" "$@")
  [[ -z "$sessions" ]] && return 0
  while IFS= read -r session; do
    [[ -z "$session" ]] && continue
    local cmds
    cmds=$(cmd_bash "$session" "$term")
    if [[ -n "$cmds" ]]; then
      format_session_header "$session"
      echo "$cmds"
      echo
    fi
  done <<< "$sessions"
}

# Search sessions and extract content by type from all of them
cmd_search_extract() {
  local term="${1:?search term required}"
  local type="${2:?type required: user, assistant, bash, tools}"
  shift 2
  local sessions
  sessions=$(cmd_search "$term" "$@")
  [[ -z "$sessions" ]] && return 0
  while IFS= read -r session; do
    [[ -z "$session" ]] && continue
    local content
    content=$(cmd_extract "$session" "$type")
    if [[ -n "$content" ]]; then
      format_session_header "$session"
      echo "$content"
      echo
    fi
  done <<< "$sessions"
}

# Count user turns and tool executions in a session.
# Output: "(U N, T M)" where N = user messages (excludes tool_result messages),
# M = tool calls by assistant.
count_session_activity() {
  local session="$1"
  jq -rs '
    ([.[] | select(.type == "user") | .message.content |
      if type == "string" then true
      elif type == "array" then any(.[]; .type == "text")
      else false end | select(.)
    ] | length) as $turns |
    ([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")] | length) as $tools |
    "(U \($turns), T \($tools))"
  ' "$session" 2>/dev/null
}

# List sessions with date, project, message count, and first user message
cmd_summary() {
  local sessions
  sessions=$(cmd_list "$@")
  [[ -z "$sessions" ]] && return 0
  while IFS= read -r session; do
    [[ -z "$session" ]] && continue
    [[ "$session" == */subagents/* ]] && continue
    local project date first_msg activity
    project=$(session_project "$session")
    first_msg=$(jq -rn '
      first(inputs | select(.type == "user") | .message.content |
        if type == "string" then select(startswith("<") | not)
        elif type == "array" then [.[] | select(.type == "text") | .text | select(startswith("<") | not)] | first // empty
        else empty end
      ) | .[:120]
    ' "$session" 2>/dev/null || true)
    activity=$(count_session_activity "$session")
    date=$(fmt_epoch "$(file_mtime "$session")" '+%Y-%m-%d %H:%M')
    echo "$date | $project | $activity | $first_msg"
  done <<< "$sessions"
}

# Audit tool calls in a session: map each tool_use to the permissionMode in
# effect and the outcome (ok / denied-user / denied-rule / error). Useful for
# reviewing what tools ran, errors hit, and rules that fired — still valuable
# under yolo where interactive denials are rare.
cmd_tools_audit() {
  local session="${1:?session file required}"
  shift || true
  local mode_filter=""
  local do_summary=0
  local do_json=0
  local truncate_n=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) mode_filter="$2"; shift 2 ;;
      --summary) do_summary=1; shift ;;
      --json) do_json=1; shift ;;
      --truncate) truncate_n="$2"; shift 2 ;;
      *) echo "unknown flag: $1" >&2; exit 1 ;;
    esac
  done

  # Slurp the session, build an outcome map from tool_result entries keyed by
  # tool_use_id, then walk in order tracking the running permissionMode and
  # emit one record per tool_use. Mode starts at "default" and updates on any
  # entry carrying permissionMode (user messages and permission-mode events).
  # Emit JSONL first (tool.input is a real JSON value — safe to reparse) and
  # let callers pick a display format via --summary / --truncate, or consume
  # the JSONL directly with --json.
  local records
  records=$(jq -cs '
    def outcome_map:
      [ .[] | select(.type == "user") as $u
        | $u.message.content[]? | select(.type == "tool_result")
        | { key: .tool_use_id,
            value: (if $u.toolUseResult == "User rejected tool use" then "denied-user"
                    elif (.content | tostring | test("Permission for this action has been denied")) then "denied-rule"
                    elif .is_error == true then "error"
                    else "ok" end) } ] | from_entries;

    . as $all
    | ($all | outcome_map) as $o
    | reduce $all[] as $e ({mode:"default", rows:[]};
        if $e.permissionMode then .mode = $e.permissionMode
        elif $e.type == "assistant" then
          reduce ($e.message.content[]? | select(.type == "tool_use")) as $tu (.;
            .rows += [{ts: $e.timestamp, mode: .mode,
                       outcome: ($o[$tu.id] // "no-result"),
                       tool: $tu.name, input: $tu.input}])
        else . end)
    | .rows[]
  ' "$session")

  if [[ -n "$mode_filter" ]]; then
    records=$(echo "$records" | jq -c --arg m "$mode_filter" 'select(.mode == $m)')
  fi

  if [[ "$do_summary" -eq 1 ]]; then
    echo "$records" | jq -r '[.mode, .outcome, .tool] | @tsv' \
      | sort | uniq -c | sort -rn
  elif [[ "$do_json" -eq 1 ]]; then
    echo "$records"
  else
    # TSV for terminal readability: tool input is compact JSON, optionally
    # truncated. The input column IS escaped by @tsv (backslashes doubled,
    # real tabs/newlines escaped) so it is safe to display but not trivially
    # reparseable as JSON — use --json when you need to reparse.
    echo "$records" \
      | jq -r --argjson n "$truncate_n" '
          (.input | tostring) as $raw
          | (if $n > 0 and ($raw | length) > $n then ($raw[0:$n] + "…") else $raw end) as $inp
          | [.ts, .mode, .outcome, .tool, $inp] | @tsv'
  fi
}

# Compact digest of a session: all user messages truncated, showing work progression
cmd_recap() {
  local session="${1:?session file required}"
  format_session_header "$session"
  jq -r '
    select(.type == "user") | .message.content |
    if type == "string" then select(startswith("<") | not)
    elif type == "array" then [.[] | select(.type == "text") | .text | select(startswith("<") | not)] | first // empty
    else empty end |
    .[0:150]
  ' "$session" 2>/dev/null | awk '{printf "%6d\t%s\n", NR, $0}'
}

[[ $# -eq 0 ]] && usage

command="$1"
shift

case "$command" in
  dir)            session_dir "$@" ;;
  list)           cmd_list "$@" ;;
  search)         cmd_search "$@" ;;
  bash)           cmd_bash "$@" ;;
  extract)        cmd_extract "$@" ;;
  search-bash)    cmd_search_bash "$@" ;;
  search-extract) cmd_search_extract "$@" ;;
  summary)        cmd_summary "$@" ;;
  recap)          cmd_recap "$@" ;;
  tools-audit)    cmd_tools_audit "$@" ;;
  *)              usage ;;
esac
