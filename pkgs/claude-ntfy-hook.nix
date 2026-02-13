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

  NTFY_URL="''${CLAUDE_NTFY_URL:-http://foxtrotbase:2586/claude}"
  MIN_SESSION_AGE="''${CLAUDE_NTFY_MIN_SESSION_AGE:-120}"

  # Read hook JSON from stdin
  input=$(cat)
  event=$(echo "$input" | jq -r '.hook_event_name // empty')

  case "$event" in
    SessionStart)
      session_id=$(echo "$input" | jq -r '.session_id // empty')
      if [ -n "$session_id" ]; then
        date +%s > "/tmp/claude-session-''${session_id}-start"
      fi
      ;;

    Notification)
      notification_type=$(echo "$input" | jq -r '.notification_type // "unknown"')
      title=$(echo "$input" | jq -r '.title // "Claude Code"')
      message=$(echo "$input" | jq -r '.message // "Notification"')

      case "$notification_type" in
        permission_prompt)
          curl -sf -X POST "$NTFY_URL" \
            -H "Title: $title" \
            -H "Priority: high" \
            -H "Tags: lock" \
            -d "$message" > /dev/null 2>&1 || true
          ;;
        *)
          curl -sf -X POST "$NTFY_URL" \
            -H "Title: $title" \
            -H "Priority: default" \
            -H "Tags: hourglass_flowing_sand" \
            -d "$message" > /dev/null 2>&1 || true
          ;;
      esac
      ;;

    Stop)
      session_id=$(echo "$input" | jq -r '.session_id // empty')
      if [ -n "$session_id" ]; then
        start_file="/tmp/claude-session-''${session_id}-start"
        if [ -f "$start_file" ]; then
          start_ts=$(cat "$start_file")
          now=$(date +%s)
          elapsed=$((now - start_ts))
          if [ "$elapsed" -ge "$MIN_SESSION_AGE" ]; then
            mins=$((elapsed / 60))
            curl -sf -X POST "$NTFY_URL" \
              -H "Title: Session complete" \
              -H "Priority: default" \
              -H "Tags: white_check_mark" \
              -d "Claude Code session finished after ''${mins}m" > /dev/null 2>&1 || true
          fi
          rm -f "$start_file"
        fi
      fi
      ;;
  esac
''
