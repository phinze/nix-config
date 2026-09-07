on_power() {
  /usr/bin/pmset -g batt | grep -q "Now drawing from 'AC Power'"
}

active_system() {
  readlink -f /run/current-system
}

authenticate() {
  /usr/bin/sudo -S -p '' -v </dev/null
}

activate_system() {
  /usr/bin/sudo -n "$ACTIVATOR" "$1" </dev/null
}

launchctl() {
  /bin/launchctl "$@"
}

set_status() {
  jq -n --arg phase "$1" --arg message "$2" --arg time "$(date -u +%FT%TZ)" \
    '{phase: $phase, message: $message, time: $time}' > "$STATE_DIR/status.json.tmp"
  mv "$STATE_DIR/status.json.tmp" "$STATE_DIR/status.json"
  echo "nix-config-sync: $1: $2"
}

notify() {
  "$NOTIFIER" -title "Nix configuration" -message "$1" -group nix-config-sync || true
}

record_deployment() {
  jq -n --arg revision "$1" --arg system "$2" \
    '{revision: $revision, system: $system}' > "$STATE_DIR/deployed.json.tmp"
  mv "$STATE_DIR/deployed.json.tmp" "$STATE_DIR/deployed.json"
}

request_install() {
  "$NOTIFIER" -title "Configuration update ready" \
    -message "Install ${1:0:12}? Approve with Touch ID. Offer expires in 15 minutes." \
    -group nix-config-sync -action Install -timeout 900
}

start_installer() {
  local token="$1" plist="$STATE_DIR/installer-$1.plist"
  jq -n --arg label "$LABEL.install.$token" --arg program "$0" --arg token "$token" \
    --arg log "$LOG_DIR/install.log" \
    '{Label: $label, ProgramArguments: [$program, "install", $token], RunAtLoad: true,
      KeepAlive: false, StandardOutPath: $log, StandardErrorPath: $log}' > "$plist.json"
  if ! /usr/bin/plutil -convert xml1 -o "$plist" "$plist.json"; then
    rm -f "$plist.json" "$plist"
    return 1
  fi
  rm -f "$plist.json"
  if ! launchctl bootstrap "gui/$(id -u)" "$plist"; then
    rm -f "$plist"
    return 1
  fi
}

cleanup_installer() {
  rm -f "$STATE_DIR/installer-$1.plist"
  launchctl bootout "gui/$(id -u)/$LABEL.install.$1" >/dev/null 2>&1 || true
}

reconcile() {
  local candidate current deployed_revision deployed_system built token answer notification_status
  local forced=0
  if [[ -f "$STATE_DIR/kicked" ]]; then
    forced=1
    rm -f "$STATE_DIR/kicked"
  fi
  if [[ "$forced" -eq 0 ]] && ! on_power; then
    set_status deferred "On battery; leaving the system alone"
    return 0
  fi
  set_status checking "Fetching committed main"
  if [[ ! -d "$STATE_DIR/repo/.git" ]]; then
    git clone https://github.com/phinze/nix-config.git "$STATE_DIR/repo" || return
  fi
  cd "$STATE_DIR/repo" || return
  git fetch --quiet origin main || return
  git reset --hard --quiet origin/main || return
  git clean -fdq || return
  candidate=$(git rev-parse HEAD) || return
  current=$(active_system) || return
  deployed_revision=$(jq -r '.revision' "$STATE_DIR/deployed.json" 2>/dev/null || true)
  deployed_system=$(jq -r '.system' "$STATE_DIR/deployed.json" 2>/dev/null || true)
  if [[ "$candidate" == "$deployed_revision" ]]; then
    if [[ "$current" == "$deployed_system" ]]; then
      set_status current "Already running ${candidate:0:12}"
    else
      set_status preview "Main is unchanged; preserving the manually activated system"
    fi
    return 0
  fi
  rm -f "$STATE_DIR/pending.json"
  set_status building "Building ${candidate:0:12} for $HOST"
  nix build ".#darwinConfigurations.$HOST.system" --no-update-lock-file --no-write-lock-file \
    --out-link "$STATE_DIR/result" || return
  built=$(readlink -f "$STATE_DIR/result") || return
  if [[ "$built" == "$current" ]]; then
    record_deployment "$candidate" "$built"
    set_status current "${candidate:0:12} produces the already active system"
    return 0
  fi
  if [[ "$forced" -eq 0 ]] && ! on_power; then
    set_status deferred "Build ready, but now on battery"
    return 0
  fi
  token=$(/usr/bin/uuidgen) || return
  jq -n --arg token "$token" --arg revision "$candidate" --arg system "$built" \
    --arg previous "$current" --argjson expires "$(($(date +%s) + 900))" \
    --argjson forced "$forced" \
    '{token: $token, revision: $revision, system: $system, previous: $previous, expires: $expires, forced: ($forced == 1)}' \
    > "$STATE_DIR/pending.json.tmp"
  mv "$STATE_DIR/pending.json.tmp" "$STATE_DIR/pending.json"
  set_status ready "${candidate:0:12} is built; waiting for Install"
  notification_status=0
  answer=$(request_install "$candidate") || notification_status=$?
  if [[ "$notification_status" != 0 && "$notification_status" != 6 ]]; then
    rm -f "$STATE_DIR/pending.json"
    echo "Notification failed ($notification_status); check notification permissions" >&2
    return "$notification_status"
  fi
  if [[ "$notification_status" == 6 || "$answer" != Install ]]; then
    rm -f "$STATE_DIR/pending.json"
    set_status deferred "No install requested; retry on the next tick or kick"
    return 0
  fi
  set_status awaiting-auth "Starting background installer for ${candidate:0:12}"
  start_installer "$token"
}

install_pending() {
  local token candidate built previous expires forced
  if [[ ! -f "$STATE_DIR/pending.json" ]]; then
    echo "No pending offer; run nix-config-sync kick" >&2
    return 1
  fi
  token=$(jq -er '.token' "$STATE_DIR/pending.json") || return
  expires=$(jq -er '.expires' "$STATE_DIR/pending.json") || return
  forced=$(jq -r '.forced // false' "$STATE_DIR/pending.json" 2>/dev/null || echo "false")
  if [[ "$1" != "$token" || $(date +%s) -gt "$expires" ]]; then
    echo "This install offer has expired; run nix-config-sync kick" >&2
    return 1
  fi
  if [[ "$forced" != "true" ]] && ! on_power; then
    set_status deferred "On battery; install postponed"
    return 0
  fi
  candidate=$(jq -er '.revision' "$STATE_DIR/pending.json") || return
  built=$(jq -er '.system' "$STATE_DIR/pending.json") || return
  previous=$(jq -er '.previous' "$STATE_DIR/pending.json") || return
  if [[ "$(active_system)" != "$previous" ]]; then
    set_status deferred "Active system changed since this offer; kick to check again"
    rm -f "$STATE_DIR/pending.json"
    return 0
  fi
  set_status awaiting-auth "Approve ${candidate:0:12} with Touch ID"
  if ! authenticate; then
    rm -f "$STATE_DIR/pending.json"
    set_status deferred "Authentication cancelled or unavailable; retry on the next tick or kick"
    notify "Install deferred: Touch ID was cancelled or unavailable."
    return 0
  fi
  if [[ "$forced" != "true" ]] && ! on_power; then
    set_status deferred "Power disconnected during authentication; install postponed"
    return 0
  fi
  if [[ "$(active_system)" != "$previous" ]]; then
    set_status deferred "Active system changed during authentication; kick to check again"
    rm -f "$STATE_DIR/pending.json"
    return 0
  fi
  set_status activating "Installing ${candidate:0:12} in the background"
  activate_system "$built" || return
  if [[ "$(active_system)" != "$built" ]]; then
    echo "Activation returned without making the offered system current" >&2
    return 1
  fi
  record_deployment "$candidate" "$built"
  rm -f "$STATE_DIR/pending.json"
  set_status current "Installed ${candidate:0:12}"
  notify "Configuration ${candidate:0:12} installed."
}

main() {
  umask 077
  mkdir -p "$STATE_DIR" "$LOG_DIR"
  case "${1:-}" in
    kick)
      [[ $# -eq 1 ]] || return 2
      touch "$STATE_DIR/kicked"
      launchctl kickstart "gui/$(id -u)/$LABEL"
      echo "Reconciliation requested; use nix-config-sync status or logs"
      ;;
    status)
      [[ $# -eq 1 ]] || return 2
      if [[ -f "$STATE_DIR/status.json" ]]; then
        jq -r '"\(.time) \(.phase): \(.message)"' "$STATE_DIR/status.json"
      else
        echo "No reconciliation recorded yet"
      fi
      ;;
    logs)
      [[ $# -eq 1 ]] || return 2
      touch "$LOG_DIR/agent.log" "$LOG_DIR/install.log"
      exec tail -F "$LOG_DIR/agent.log" "$LOG_DIR/install.log"
      ;;
    run)
      [[ $# -eq 1 ]] || return 2
      exec /usr/bin/lockf -k -t 0 "$STATE_DIR/lock" "$0" _run
      ;;
    install)
      [[ $# -eq 2 ]] || return 2
      [[ "$2" =~ ^[A-Fa-f0-9-]{36}$ ]] || return 2
      INSTALL_TOKEN="$2"
      trap 'cleanup_installer "$INSTALL_TOKEN"' EXIT
      /usr/bin/lockf -k -t 10 "$STATE_DIR/lock" "$0" _install "$2"
      ;;
    _run|_install)
      set -E
      trap 'set_status failed "Sync stopped; see nix-config-sync logs"; notify "Sync did not finish. See nix-config-sync logs."' ERR
      if [[ "$1" == _run && $# -eq 1 ]]; then
        reconcile
      elif [[ "$1" == _install && $# -eq 2 ]]; then
        install_pending "$2"
      else
        return 2
      fi
      ;;
    *)
      echo "usage: nix-config-sync {kick|status|logs|run}" >&2
      return 2
      ;;
  esac
}
