{ pkgs }:

pkgs.writeShellApplication {
  name = "codex-thread-title";
  runtimeInputs = [
    pkgs.codex
    pkgs.coreutils
    pkgs.gawk
    pkgs.jq
    pkgs.tmux
    pkgs.util-linux
  ];
  text = ''
    latest_indexed_title() {
      local index="$1"
      local session_id="$2"
      [[ -f "$index" ]] || return 0
      jq -sr --arg id "$session_id" \
        '[.[] | select(.id == $id)][-1].thread_name // ""' "$index" 2>/dev/null
    }

    set_pane_title() {
      local pane="$1"
      local title="$2"
      [[ -n "$pane" && -n "$title" ]] || return 0
      tmux select-pane -t "$pane" -T "$title" >/dev/null 2>&1 || true
    }

    worker() {
      local session_id="$1"
      local transcript_path="$2"
      local pane="$3"
      local codex_home="''${CODEX_HOME:-$HOME/.codex}"
      local index="$codex_home/session_index.jsonl"
      local cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/codex-thread-title"
      local state="$cache_dir/$session_id.json"

      [[ -n "$session_id" && -f "$transcript_path" ]] || return 0
      mkdir -p "$cache_dir"
      exec 9>"$cache_dir/$session_id.lock"
      flock -n 9 || return 0

      local indexed cached_title last_turns user_turns
      indexed="$(latest_indexed_title "$index" "$session_id")"
      cached_title=""
      last_turns=0
      if [[ -f "$state" ]]; then
        cached_title="$(jq -r '.title // ""' "$state" 2>/dev/null || true)"
        last_turns="$(jq -r '.user_turns // 0' "$state" 2>/dev/null || printf '0')"
      fi

      # No cache means rig did not author the indexed title. Preserve native
      # and manual names forever. A changed title also revokes our ownership.
      if [[ -n "$indexed" && ( -z "$cached_title" || "$indexed" != "$cached_title" ) ]]; then
        set_pane_title "$pane" "$indexed"
        return 0
      fi

      user_turns="$(jq -s '[.[] | select(.type == "event_msg" and .payload.type == "user_message")] | length' "$transcript_path")"
      [[ "$user_turns" =~ ^[0-9]+$ && "$user_turns" -gt 0 ]] || return 0

      # Generate immediately, then only after another six user turns. This is
      # frequent enough to follow a thread that changes direction without
      # spending a model call on every Stop hook.
      if [[ -n "$cached_title" && "$user_turns" -lt $((last_turns + 6)) ]]; then
        set_pane_title "$pane" "$cached_title"
        return 0
      fi

      local excerpt prompt output title latest record state_tmp
      excerpt="$(${pkgs.jq}/bin/jq -cs '
        def semantic:
          if .type != "event_msg" then empty
          elif .payload.type == "user_message" then
            {role: "user", text: .payload.message}
          elif .payload.type == "agent_message" then
            {role: "assistant", text: .payload.message}
          else empty end;
        [.[] | semantic
          | select((.text | type) == "string" and (.text | length) > 0)
          | .text = .text[0:1500]] as $messages
        | ([ $messages[] | select(.role == "user") ][0:1] + $messages[-6:])
      ' "$transcript_path")"
      [[ "$excerpt" != "[]" ]] || return 0

      prompt="Write a concise title for this coding-agent thread. Return only the title: a present-tense task phrase, at most 8 words, no quotes or trailing punctuation. Base it on what the user is trying to accomplish, not on tool mechanics. Transcript excerpt: $excerpt"
      output="$(mktemp)"
      trap 'rm -f "$output"' RETURN

      if ! printf '%s\n' "$prompt" | codex exec \
        --ephemeral \
        --ignore-user-config \
        --ignore-rules \
        --disable hooks \
        --skip-git-repo-check \
        --sandbox read-only \
        --model "''${CODEX_THREAD_TITLE_MODEL:-gpt-5.4-mini}" \
        --output-last-message "$output" \
        - >/dev/null 2>&1; then
        return 0
      fi

      title="$(tr '\n' ' ' < "$output" | awk '{$1=$1; for (i=1; i<=NF && i<=8; i++) printf "%s%s", (i>1 ? OFS : ""), $i; print ""}')"
      title="''${title%[.!?;:]}"
      title="''${title#\"}"
      title="''${title%\"}"
      [[ -n "$title" ]] || return 0

      # Re-check after inference so a manual or native rename that raced us
      # wins. Our previous generated title is the only safe value to replace.
      latest="$(latest_indexed_title "$index" "$session_id")"
      if [[ -n "$latest" && "$latest" != "$cached_title" ]]; then
        set_pane_title "$pane" "$latest"
        return 0
      fi
      mkdir -p "$codex_home"
      if [[ "$title" != "$latest" ]]; then
        record="$(jq -cn \
          --arg id "$session_id" \
          --arg thread_name "$title" \
          --arg updated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{id: $id, thread_name: $thread_name, updated_at: $updated_at}')"
        printf '%s\n' "$record" >> "$index"
      fi

      state_tmp="$(mktemp "$cache_dir/$session_id.json.XXXXXX")"
      jq -cn --arg title "$title" --argjson user_turns "$user_turns" \
        '{title: $title, user_turns: $user_turns}' > "$state_tmp"
      mv "$state_tmp" "$state"
      set_pane_title "$pane" "$title"
    }

    if [[ "''${1:-}" == "--worker" ]]; then
      shift
      worker "$@"
      exit 0
    fi

    # Hooks are on the interactive turn's critical path. Detach the expensive
    # inference and keep every failure invisible to the parent Codex session.
    payload="$(cat)"
    session_id="$(jq -r '.session_id // empty' <<< "$payload")"
    transcript_path="$(jq -r '.transcript_path // empty' <<< "$payload")"
    event="$(jq -r '.hook_event_name // empty' <<< "$payload")"
    cwd="$(jq -r '.cwd // empty' <<< "$payload")"
    pane="''${TMUX_PANE:-}"
    codex_home="''${CODEX_HOME:-$HOME/.codex}"
    indexed="$(latest_indexed_title "$codex_home/session_index.jsonl" "$session_id")"
    set_pane_title "$pane" "''${indexed:-$(basename "$cwd")}"

    if [[ "$event" == "Stop" && -n "$session_id" && -n "$transcript_path" ]]; then
      nohup "$0" --worker "$session_id" "$transcript_path" "$pane" \
        </dev/null >/dev/null 2>&1 &
    fi
    exit 0
  '';
}
