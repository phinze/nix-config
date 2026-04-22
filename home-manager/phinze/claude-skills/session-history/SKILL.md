---
name: session-history
description: Search and summarize Claude Code session history. Use when the user wants to look at past conversations, find sessions about a topic, or reconstruct a debugging narrative.
user_invocable: true
---

# Session History

Search and summarize conversations from Claude Code sessions.

If invoked with an argument, treat it as the search term, topic, or date to
find across sessions.

## Helper script

This skill includes `claude-sessions.sh` for common operations. Use it
instead of writing ad hoc jq/rg pipelines. Run it without arguments for
usage.

```
claude-sessions.sh dir [path]                              # session dir for a project
claude-sessions.sh list [--all | path] [--days N]          # recent sessions
claude-sessions.sh search <term> [--all | path] [--days N] # find sessions by content
claude-sessions.sh bash <session> [filter]                 # extract Bash commands
claude-sessions.sh extract <session> <type>                # type: user, assistant, bash, tools
claude-sessions.sh search-bash <term> [--all | path] [--days N]
                                                           # search + extract matching Bash commands
claude-sessions.sh search-extract <term> <type> [--all | path] [--days N]
                                                           # search + extract content by type
claude-sessions.sh summary [--all | path] [--days N]       # per-session user-msg & tool-call counts, first user message
claude-sessions.sh recap <session>                         # numbered digest of user messages
claude-sessions.sh tools-audit <session> [--mode M] [--summary|--json|--truncate N]
                                                           # per-tool-call audit with permissionMode & outcome
```

The script lives next to this skill file. Run it with its full path:

    ~/.claude/skills/session-history/claude-sessions.sh

## Session file locations

Claude Code sessions are JSONL files stored per-project:

    ~/.claude/projects/<mangled-path>/*.jsonl

The directory name is the absolute project path with both `/` and `.`
replaced by `-` (leading one included, so names start with `-`). Reversing
this is lossy, so the script reads the literal `cwd` field out of the JSONL
for display instead.

## Process

1. **Use the helper script.** Only fall back to raw jq for unusual
   extraction needs.

2. **Triage efficiently.** Use `search` to narrow down candidates before
   extracting full content.

3. **Summarize selectively.** Extract only user messages first to
   understand the arc. Only extract assistant messages for the specific
   sessions the user cares about.

   For counting questions ("how many user messages today?", "how active
   was I in this repo?"), `summary` already emits `(U N, T M)` per
   session — sum those columns rather than writing ad hoc jq. The `U`
   count excludes tool-result messages; naive `type == "user"` filters
   conflate the two.

4. **For multi-session narratives**, establish chronological order using
   file timestamps, then read sessions in order to build the story.

5. For large session files (>256KB), always use the helper script or `jq`
   via Bash rather than the Read tool.

## Auditing tool calls

Use `tools-audit` to review what tools ran in a session. Transcripts record
`permissionMode` on user-message entries and on `permission-mode` events,
so the script tags every tool call with the mode in effect at that moment.
Outcomes come from the matching `tool_result`: `denied-user` is an
interactive rejection, `denied-rule` is a sandbox/allowlist block, `error`
is a tool-level failure, `ok` is anything that ran cleanly.

Even in yolo mode this is useful for seeing what actually happened —
errors, rule denials, and the Bash stream itself. Typical recipe for
"audit today's tool calls in repo X":

```bash
DIR=$(claude-sessions.sh dir ~/src/github.com/phinze/nix-config)
: > /tmp/audit.jsonl
today=$(date '+%Y-%m-%d')
# Portable mtime read: GNU stat on Linux, BSD stat on macOS.
_mtime() { if stat --version >/dev/null 2>&1; then stat -c %Y "$1"; else stat -f %m "$1"; fi; }
_fmtepoch() { if date --version >/dev/null 2>&1; then date -d "@$1" "$2"; else date -r "$1" "$2"; fi; }
for f in "$DIR"/*.jsonl; do
  d=$(_fmtepoch "$(_mtime "$f")" '+%Y-%m-%d')
  [[ "$d" != "$today" ]] && continue
  claude-sessions.sh tools-audit "$f" --json >> /tmp/audit.jsonl
done

# Rejections and errors first:
jq -c 'select(.outcome != "ok")' /tmp/audit.jsonl

# Then audit the Bash stream for dubiousness:
jq -r 'select(.outcome == "ok" and .tool == "Bash") | .input.command' /tmp/audit.jsonl \
  | rg 'rm -rf|git push|--force|--no-verify|gh pr (create|edit|merge|close)|gh issue (create|edit|close)|npm publish|curl .*-X (POST|PUT|DELETE|PATCH)|sudo|chmod|chown|killall|pkill'

# And Writes/Edits outside the project:
jq -r 'select(.outcome == "ok" and (.tool == "Write" or .tool == "Edit")) | [.tool, .input.file_path] | @tsv' /tmp/audit.jsonl \
  | rg -v 'nix-config'
```

Always use `--json` when piping to another tool — the default TSV
double-escapes backslashes in the input column (it's meant for human
reading), so downstream `jq` on the input field will fail.
