{ pkgs }:
let
  runtimeDeps = with pkgs; [
    curl
    jq
    coreutils
  ];
in
pkgs.writeShellScriptBin "claude-ntfy-hook" ''
  set -euo pipefail

  export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

  NTFY_URL="''${CLAUDE_NTFY_URL:-https://foxtrotbase.swallow-galaxy.ts.net/claude}"
  MIN_SESSION_AGE="''${CLAUDE_NTFY_MIN_SESSION_AGE:-120}"

  # Read hook JSON from stdin
  input=$(cat)
  event=$(echo "$input" | jq -r '.hook_event_name // empty')

  # Extract project name from cwd (last two path components, e.g. "phinze/infra")
  cwd=$(echo "$input" | jq -r '.cwd // empty')
  project=$(echo "$cwd" | awk -F/ '{print $(NF-1)"/"$NF}')
  session_id=$(echo "$input" | jq -r '.session_id // empty')

  case "$event" in
    SessionStart)
      if [ -n "$session_id" ]; then
        date +%s > "/tmp/claude-session-''${session_id}-start"
      fi
      ;;

    Notification)
      notification_type=$(echo "$input" | jq -r '.notification_type // "unknown"')
      message=$(echo "$input" | jq -r '.message // "Notification"')

      case "$notification_type" in
        permission_prompt)
          curl -sf -X POST "$NTFY_URL" \
            -H "Title: [$project] Needs approval" \
            -H "Priority: high" \
            -H "Tags: lock" \
            -d "$message" > /dev/null 2>&1 || true
          ;;
        *)
          curl -sf -X POST "$NTFY_URL" \
            -H "Title: [$project] Waiting for input" \
            -H "Priority: default" \
            -H "Tags: hourglass_flowing_sand" \
            -d "$message" > /dev/null 2>&1 || true
          ;;
      esac
      ;;

    Stop)
      if [ -n "$session_id" ]; then
        start_file="/tmp/claude-session-''${session_id}-start"
        if [ -f "$start_file" ]; then
          start_ts=$(cat "$start_file")
          now=$(date +%s)
          elapsed=$((now - start_ts))
          if [ "$elapsed" -ge "$MIN_SESSION_AGE" ]; then
            mins=$((elapsed / 60))
            curl -sf -X POST "$NTFY_URL" \
              -H "Title: [$project] Session complete" \
              -H "Priority: default" \
              -H "Tags: white_check_mark" \
              -d "Finished after ''${mins}m" > /dev/null 2>&1 || true
          fi
          rm -f "$start_file"
        fi
      fi
      ;;
  esac
''
