{ pkgs }:
let
  runtimeDeps = with pkgs; [
    iproute2 # for ss
    gawk
    procps # for ps
  ];
in
pkgs.writeShellScriptBin "whoson" ''
  set -euo pipefail

  export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"

  if [ $# -eq 0 ]; then
    echo "Usage: whoson <port>"
    exit 1
  fi

  PORT="$1"

  # Check if anything is listening on this port (without -p, doesn't need privileges)
  if ! ss -tln "sport = :$PORT" 2>/dev/null | grep -q "LISTEN"; then
    echo "No process listening on port $PORT"
    exit 1
  fi

  # Now try to get the PID (requires privileges for other users' processes)
  PID=$(ss -tlnp "sport = :$PORT" 2>/dev/null | awk 'NR>1 {match($0, /pid=([0-9]+)/, arr); if(arr[1]) print arr[1]}' | head -1)

  if [ -z "$PID" ]; then
    echo "Port $PORT is listening, but cannot see process info (try sudo)"
    exit 1
  fi

  # Get the command
  CMD=$(ps -p "$PID" -o args= 2>/dev/null || echo "unknown")

  # Get the working directory
  PWD_PATH=$(readlink -f "/proc/$PID/cwd" 2>/dev/null || echo "unknown")

  echo "PID: $PID"
  echo "CMD: $CMD"
  echo "PWD: $PWD_PATH"
''
