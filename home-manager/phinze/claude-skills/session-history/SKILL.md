---
name: session-history
description: Search and summarize Claude Code session history, on this host or across machines and agents through atuin threads. Use when the user wants to look at past conversations, find sessions about a topic, find what a rig did (even after teardown or on the other machine), or reconstruct a debugging narrative.
user_invocable: true
---

# Session History

Search and summarize conversations from coding-agent sessions: Claude Code,
Codex and pi, on foxtrotbase and the Mac.

If invoked with an argument, treat it as the search term, topic, or date to
find across sessions.

There are two sources. **Atuin threads are the default**: every agent
session on both machines, synced, searchable, with one id everywhere. The
**raw Claude JSONL** on this host is the forensic fallback, for the few
things threads don't keep.

## Atuin threads (start here)

The atuin daemon on foxtrotbase and the Mac captures every Claude Code,
Codex, opencode and pi session as a **thread** and syncs it through atuin's
encrypted record store. Both machines' full history was imported on
2026-10-16, so threads reach back as far as the transcripts on disk did.
That includes sessions from the other machine, other agents, and rigs that
have since been torn down.

```
atuin threads search "<words>" [--harness claude-code|codex|pi] [--limit N] --style json
atuin threads list --style json            # newest first; message_count, tokens, cwd, branch, model
atuin threads show <id|harness-id|latest> --style json
```

`search` matches whole words across titles, message text and tool-call
*input*. It doesn't search tool output. A Claude rig session is titled with
the rig name, so `atuin threads search mir-2102` finds that rig's
conversation; for other agents, match on `cwd` (`~/workspaces/<rig>/...`). Every
thread has one atuin id on every machine. `list` and `search` show its last
8 hex digits, and `show` also accepts the agent's own session id.

`show --style json` returns `session` (cwd, branch, model, timestamps,
tokens, message_count) and `messages[]`. Each message has `role`,
`timestamp`, `cwd`, `git_branch` and `content[]` blocks: `text`, `tool_use`
(`name`, `input`) and `tool_result` (`content`, `is_error`). Filter that with
`jq` instead of reading a whole thread, which can run to thousands of
messages.

What threads don't keep: images, reasoning (only a marker that it
happened), `permissionMode`, and anything past 64 KiB in one tool call's
input or output (the start and end are kept; in practice that's almost only
image reads). Credentials atuin recognizes are `****`.

To *continue* a session elsewhere, rather than read it, the user runs
`atuin resume <id>`. It writes the transcript back out from sync and
resumes it, falling back to a same-named repo checkout when the original
directory doesn't exist on this machine. That's the user's move: don't
resume sessions on their behalf.

## Raw Claude JSONL (forensics on this host)

Drop to the transcripts on disk when you need what threads leave out:

- **Tool-call audits.** `tools-audit` tells a user denial from a rule
  block from a tool error using `permissionMode`; threads only have
  `is_error`.
- **Searching tool output** across many sessions (`claude-sessions.sh
  search`). With threads, that means dumping and grepping JSON per thread.
- **Exact user-vs-tool-result counts** (`summary`'s `U`/`T` columns).

### Helper script

`claude-sessions.sh` covers the common operations. Use it instead of writing
ad hoc jq/rg pipelines. Run it without arguments for usage.

```
claude-sessions.sh dir [path]                              # session dir for a project
claude-sessions.sh list [--all | path] [--days N]          # recent sessions
claude-sessions.sh search <term> [--all | path] [--days N] # find sessions by content
claude-sessions.sh peek <session> <term> [chars]           # bounded context around matches
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

### Session file locations

Claude Code sessions are JSONL files stored per-project:

    ~/.claude/projects/<mangled-path>/*.jsonl

The directory name is the absolute project path with both `/` and `.`
replaced by `-` (leading one included, so names start with `-`). Reversing
this is lossy, so the script reads the literal `cwd` field out of the JSONL
for display instead.

Each JSONL entry is a single line that can be megabytes long — tool
results, file reads, and attachments are inlined. Filename-only searches
(`search`) and field-extracting `jq` queries are cheap; matching or
extracting whole lines is not.

## Process

1. **Start with threads.** `atuin threads search` to find candidates, then
   `show --style json` filtered with jq. Go to the JSONL only for the
   forensic cases above, and remember it only covers this host.

2. **Triage efficiently.** Narrow down candidates before extracting full
   content.

3. **Summarize selectively.** Read user messages first to understand the
   arc. Only pull assistant messages and tool calls for the specific
   sessions the user cares about.

   For counting questions ("how active was I in this repo?"), `threads list
   --style json` has `message_count` and tokens per thread. For exact user
   message counts on this host, `summary` emits `(U N, T M)` per session —
   sum those columns rather than writing ad hoc jq. The `U` count excludes
   tool-result messages; naive `type == "user"` filters conflate the two.

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
