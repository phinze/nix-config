# Dynamic SSH signing key selector for git
#
# Git calls: <program> -Y sign -f <key> -n git <file>
# This wrapper ignores the -f <key> argument, queries the SSH agent for
# available keys, matches against an allowlist in priority order, and
# signs with the first match.
{
  lib,
  writeShellScriptBin,
  openssh,
  coreutils,
  signingKeys,
}:
let
  # Build the allowlist as a bash array literal
  keyArray = lib.concatMapStringsSep "\n" (k: "  ${lib.escapeShellArg k.publicKey}") signingKeys;
  keyNames = lib.concatMapStringsSep "\n" (k: "  ${lib.escapeShellArg k.name}") signingKeys;
in
writeShellScriptBin "git-ssh-sign" ''
  set -euo pipefail

  export PATH="${lib.makeBinPath [ openssh coreutils ]}:$PATH"

  # Git uses gpg.ssh.program for both signing and verification.
  # Only intercept "-Y sign" calls; pass everything else to ssh-keygen as-is.
  is_sign=false
  for arg in "$@"; do
    if [[ "$arg" == "sign" ]]; then
      is_sign=true
      break
    fi
  done

  if [[ "$is_sign" == "false" ]]; then
    exec ssh-keygen "$@"
  fi

  # Parse git's arguments: -Y sign -f <key> -n git <file>
  # We need to strip -f <key> and replace with our own key
  args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f)
        shift 2  # skip -f and its argument
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  # Allowlist of signing keys in priority order
  allowed_keys=(
  ${keyArray}
  )

  allowed_names=(
  ${keyNames}
  )

  # Query agent for available keys
  agent_keys=$(ssh-add -L 2>/dev/null) || {
    echo "git-ssh-sign: ERROR: ssh-add -L failed. Is an SSH agent running?" >&2
    exit 1
  }

  # Find the first allowed key present in the agent
  matched_key=""
  matched_name=""
  for i in "''${!allowed_keys[@]}"; do
    key="''${allowed_keys[$i]}"
    # Match on the key type + base64 data (first two fields)
    key_fingerprint=$(echo "$key" | awk '{print $1, $2}')
    if echo "$agent_keys" | grep -qF "$key_fingerprint"; then
      matched_key="$key"
      matched_name="''${allowed_names[$i]}"
      break
    fi
  done

  if [[ -z "$matched_key" ]]; then
    echo "git-ssh-sign: ERROR: No matching signing key found in SSH agent." >&2
    echo "Checked keys:" >&2
    for i in "''${!allowed_keys[@]}"; do
      echo "  - ''${allowed_names[$i]}: ''${allowed_keys[$i]}" >&2
    done
    echo "Agent has:" >&2
    echo "$agent_keys" | while read -r line; do
      echo "  - $line" >&2
    done
    exit 1
  fi

  echo "git-ssh-sign: signing with key '$matched_name'" >&2

  # Write matched key to temp file for ssh-keygen
  tmpkey=$(mktemp)
  trap 'rm -f "$tmpkey"' EXIT
  echo "$matched_key" > "$tmpkey"

  # Call ssh-keygen with our selected key
  ssh-keygen -f "$tmpkey" "''${args[@]}"
''
