{
  pkgs,
  lib,
  config,
  nodeConfig ? { },
  ...
}:
let
  # Fast-moving flake inputs we keep automatically synced: software Paul writes
  # and iterates on, plus quick-turnover AI harnesses and their plugin sources.
  # Everything NOT listed here (nixpkgs, home-manager, nix-darwin, and the other
  # release-branch pins) stays manual on purpose — those are deliberate.
  syncInputs = [
    # Paul's own repos
    "rig"
    "recto"
    "bankshot"
    "double-agent"
    "sophon"
    "camlink-fix"
    "belowdeck"
    "nixvim-config"
    "pim-stuff"
    "zen-browser"
    # AI harnesses
    "claude-code-nix"
    "codex-cli-nix"
    # Claude plugin sources (flake = false)
    "claude-plugins-official"
    "claude-plugin-coderabbit"
    "claude-plugin-miren-skills"
    "claude-plugin-miren-team"
    # Miren work infra
    "iso"
    "multipass"
  ];

  # Inputs that follow their newest *release* rather than a branch. Each tick
  # asks GitHub for releases/latest and rewrites the tag pinned in flake.nix, so
  # you get "latest stable" without riding anyone's main. The flake.nix URL must
  # be `github:owner/repo/TAG` — that's where the repo and the current tag are
  # read from, so the list here is just names.
  #
  # atuin is here because it's the reason any of this exists: tracking its main
  # produced a binary with an unresolved libssl.so.3, and the all-or-nothing
  # bump meant that one bad build stalled every other input for two days.
  releaseInputs = [
    "atuin"
  ];

  host = "foxtrotbase";
  cloneDir = "${config.home.homeDirectory}/.local/state/nix-config-sync";
  resultLink = "${config.home.homeDirectory}/.local/state/nix-config-sync-result";
  deploymentState = "${config.home.homeDirectory}/.local/state/nix-config-sync-deployment";
  quarantineState = "${config.home.homeDirectory}/.local/state/nix-config-sync-quarantine.json";

  nix-config-sync = pkgs.writeShellApplication {
    name = "nix-config-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      gnugrep
      jq
      gh # git credential helper shells out to `gh auth git-credential`
      systemd
    ];
    text = ''
      if [[ "''${1:-}" == "kick" ]]; then
        if [[ $# -ne 1 ]]; then
          echo "usage: nix-config-sync kick" >&2
          exit 2
        fi
        echo "nix-config-sync: asking the user service to reconcile now..."
        systemctl --user start nix-config-sync.service
        echo "nix-config-sync: reconciliation complete"
        exit 0
      elif [[ $# -ne 0 ]]; then
        echo "usage: nix-config-sync kick" >&2
        exit 2
      fi

      REPO_URL="https://github.com/phinze/nix-config.git"
      CLONE_DIR="${cloneDir}"
      RESULT_LINK="${resultLink}"
      DEPLOYMENT_STATE="${deploymentState}"
      QUARANTINE="${quarantineState}"
      HOST="${host}"
      INPUTS=(${lib.concatStringsSep " " syncInputs})
      RELEASE_INPUTS=(${lib.concatStringsSep " " releaseInputs})

      # How long a build-breaking input stays benched before we spend a build
      # finding out whether upstream fixed it. Short enough that a same-day fix
      # lands the same day; long enough that a week-long breakage costs a
      # handful of builds rather than one per hour.
      RETRY_AFTER="6 hours"

      # `nix` and the setuid `sudo` wrapper live in the system profile, not in
      # our runtimeInputs; make sure they resolve inside the user service. The
      # home profile comes along for `rig`, which we post notifications to when
      # it happens to be installed.
      export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH"

      # Notifications are strictly best-effort. rig is not a dependency of this
      # service and must never be able to fail a reconciliation — if it isn't
      # installed, or the inbox is unwritable, the sync carries on regardless.
      notify() { # level key title body
        command -v rig >/dev/null 2>&1 || return 0
        rig notify post --source nix-config-sync \
          --level "$1" --key "$2" --title "$3" --body "$4" >/dev/null 2>&1 || true
      }
      notify_clear() { # key
        command -v rig >/dev/null 2>&1 || return 0
        rig notify dismiss "nix-config-sync/$1" >/dev/null 2>&1 || true
      }

      # Bootstrap the dedicated clone on first run. This is the bot's own copy,
      # kept entirely separate from Paul's working checkout so interim WIP there
      # is never touched.
      if [[ ! -d "$CLONE_DIR/.git" ]]; then
        mkdir -p "$(dirname "$CLONE_DIR")"
        git clone "$REPO_URL" "$CLONE_DIR"
      fi

      cd "$CLONE_DIR"

      build_system() {
        local label="$1"
        echo "nix-config-sync: building $HOST toplevel for $label..."
        nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
          --out-link "$RESULT_LINK"
      }

      record_deployment() {
        local revision="$1"
        local system="$2"

        printf '%s\n%s\n' "$revision" "$system" > "$DEPLOYMENT_STATE.tmp"
        mv "$DEPLOYMENT_STATE.tmp" "$DEPLOYMENT_STATE"
      }

      # Reconcile the host to an exact, current origin/main revision. When main
      # has not moved but the active closure differs from the one we recorded,
      # treat that as a deliberate development preview and leave it alone.
      deploy_main() {
        local attempt candidate latest deployed_rev deployed_system
        local current_system built_system
        local -a deployment=()

        for attempt in 1 2 3; do
          if ! git fetch --quiet origin main; then
            echo "nix-config-sync: fetch failed (offline?), skipping" >&2
            return 1
          fi

          # This clone belongs to the reconciler. Always discard a prior
          # interrupted run before selecting the next deployment candidate.
          git reset --hard --quiet origin/main
          git clean -fdq
          candidate=$(git rev-parse HEAD)

          if [[ -f "$DEPLOYMENT_STATE" ]]; then
            mapfile -t deployment < "$DEPLOYMENT_STATE"
          fi
          deployed_rev="''${deployment[0]:-}"
          deployed_system="''${deployment[1]:-}"
          current_system=$(readlink -f /run/current-system 2>/dev/null || true)

          if [[ "$candidate" == "$deployed_rev" &&
                -n "$current_system" &&
                "$current_system" == "$deployed_system" ]]; then
            echo "nix-config-sync: $HOST already runs origin/main at ''${candidate:0:12}"
            DEPLOY_RESULT="unchanged"
            return 0
          fi

          if [[ "$candidate" == "$deployed_rev" &&
                -n "$deployed_system" &&
                "$current_system" != "$deployed_system" ]]; then
            echo "nix-config-sync: active system differs while main is unchanged"
            echo "nix-config-sync: assuming a development preview; leaving it active"
            DEPLOY_RESULT="preview"
            return 0
          fi

          if ! build_system "origin/main ''${candidate:0:12}"; then
            echo "nix-config-sync: origin/main build failed" >&2
            return 1
          fi
          built_system=$(readlink -f "$RESULT_LINK")

          # A push during the build makes this candidate stale. Fetch again
          # before activation and retry against the newer main instead.
          if ! git fetch --quiet origin main; then
            echo "nix-config-sync: could not verify origin/main after build" >&2
            return 1
          fi
          latest=$(git rev-parse origin/main)
          if [[ "$latest" != "$candidate" ]]; then
            echo "nix-config-sync: main advanced during build; retrying ($attempt/3)"
            continue
          fi

          if [[ "$current_system" == "$built_system" ]]; then
            echo "nix-config-sync: built system is already active"
          else
            echo "nix-config-sync: activating origin/main ''${candidate:0:12} on $HOST..."
            sudo nix-env -p /nix/var/nix/profiles/system --set "$built_system"
            sudo "$built_system/bin/switch-to-configuration" switch
          fi

          record_deployment "$candidate" "$built_system"
          DEPLOY_RESULT="deployed"

          # If main moved during activation, stay in this run and converge
          # again. There is always a tiny final fetch-to-return window, but this
          # keeps a slow switch from widening it to the whole activation time.
          if git fetch --quiet origin main; then
            latest=$(git rev-parse origin/main)
            if [[ "$latest" != "$candidate" ]]; then
              echo "nix-config-sync: main advanced during activation; retrying ($attempt/3)"
              continue
            fi
          fi

          echo "nix-config-sync: origin/main ''${candidate:0:12} is active"
          return 0
        done

        echo "nix-config-sync: main kept advancing; retrying next tick" >&2
        return 1
      }

      # Ordinary config pushes get priority. A bad speculative input bump must
      # never hold an already-landed main revision back from deployment.
      DEPLOY_RESULT=""
      if ! deploy_main; then
        exit 1
      fi

      if [[ "$DEPLOY_RESULT" == "preview" ]]; then
        echo "nix-config-sync: input bumps are paused until main advances"
        exit 0
      fi

      if [[ "$DEPLOY_RESULT" == "deployed" ]]; then
        echo "nix-config-sync: deployed new main; deferring input bumps until the next tick"
        exit 0
      fi

      # ---------------------------------------------------------------------
      # Input bumps.
      #
      # This used to be one all-or-nothing transaction: bump everything, build,
      # and on failure revert the whole lock. One upstream shipping a broken
      # build therefore froze every other input indefinitely, silently, at one
      # wasted build per hour. So the failure path now bisects to find which
      # input is actually at fault, benches it, and lands the rest.
      # ---------------------------------------------------------------------

      lock_id() { # file input
        jq -r --arg i "$2" \
          '.nodes[$i].locked.rev // .nodes[$i].locked.narHash // empty' "$1"
      }

      # Currently-benched inputs whose retry window hasn't elapsed. Everything
      # else — including a benched input that's due for a retry — is a candidate.
      benched() {
        [[ -f "$QUARANTINE" ]] || return 0
        jq -r --argjson cutoff "$(date -d "-$RETRY_AFTER" +%s)" \
          '.[] | select((.lastTried | fromdateiso8601) > $cutoff) | .input' \
          "$QUARANTINE" 2>/dev/null || true
      }

      bench() { # input reason
        # Zulu, not `date -Is`. jq's fromdateiso8601 parses %Y-%m-%dT%H:%M:%SZ
        # and nothing else — hand it a numeric offset and it errors, which here
        # would mean `benched` quietly returning empty and the retry window
        # never suppressing anything at all.
        local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        local current='[]'
        if [[ -f "$QUARANTINE" ]]; then current=$(cat "$QUARANTINE"); fi
        jq --arg i "$1" --arg r "$2" --arg now "$now" '
          (map(select(.input == $i)) | first) as $prev
          | map(select(.input != $i))
          + [{
              input: $i,
              reason: $r,
              since: ($prev.since // $now),
              lastTried: $now,
              runs: (($prev.runs // 0) + 1)
            }]
        ' <<<"$current" > "$QUARANTINE.tmp" && mv "$QUARANTINE.tmp" "$QUARANTINE"
      }

      unbench() { # input
        [[ -f "$QUARANTINE" ]] || return 0
        jq --arg i "$1" 'map(select(.input != $i))' "$QUARANTINE" \
          > "$QUARANTINE.tmp" && mv "$QUARANTINE.tmp" "$QUARANTINE"
      }

      # Release-tracked inputs are pinned by tag in flake.nix, so "bump" means
      # rewriting that tag before relocking. Resolve the targets up front; the
      # rewrite itself happens in apply_set so bisection can include or exclude
      # a release input as cleanly as any other.
      declare -A RELEASE_TARGET=()
      declare -A RELEASE_FROM=()
      resolve_releases() {
        local input url owner repo tag latest
        for input in "''${RELEASE_INPUTS[@]}"; do
          url=$(sed -n "s|^[[:space:]]*$input\.url = \"github:\([^\"]*\)\";.*|\1|p" flake.nix.pre)
          if [[ -z "$url" ]]; then
            echo "nix-config-sync: $input is release-tracked but has no github: pin, skipping" >&2
            continue
          fi
          IFS=/ read -r owner repo tag <<<"$url"
          if [[ -z "$tag" ]]; then
            echo "nix-config-sync: $input has no tag in its url, skipping" >&2
            continue
          fi
          # Offline, rate-limited, or a repo that has never cut a release: all
          # non-fatal. The input simply doesn't move this tick.
          latest=$(gh api "repos/$owner/$repo/releases/latest" -q .tag_name 2>/dev/null || true)
          if [[ -z "$latest" || "$latest" == "null" || "$latest" == "$tag" ]]; then
            continue
          fi
          echo "nix-config-sync: $input release $tag → $latest"
          RELEASE_TARGET[$input]="$latest"
          RELEASE_FROM[$input]="$tag"
        done
      }

      retag() { # input tag
        sed -i "s|^\([[:space:]]*$1\.url = \"github:[^\"]*\)/[^\"/]*\";|\1/$2\";|" flake.nix
      }

      # Reset to the pristine tree, then apply exactly the named inputs. Every
      # bisection probe goes through here, so a probe can never inherit state
      # from the probe before it.
      apply_set() {
        cp flake.nix.pre flake.nix
        cp flake.lock.pre flake.lock
        local input
        for input in "$@"; do
          if [[ -n "''${RELEASE_TARGET[$input]:-}" ]]; then
            retag "$input" "''${RELEASE_TARGET[$input]}"
          fi
        done
        if [[ $# -gt 0 ]]; then
          nix flake update "$@" >/dev/null 2>&1 || return 1
        fi
        return 0
      }

      build_quiet() {
        nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
          --out-link "$RESULT_LINK" >/dev/null 2>&1
      }

      # Delta-debug a failing set down to the inputs responsible. Splitting
      # rather than walking one-by-one keeps the common single-culprit case at
      # roughly 2·log2(n) builds, and recursing into *both* halves means a tick
      # that breaks two inputs at once still finds both.
      find_culprits() {
        local -a cand=("$@")
        apply_set "''${cand[@]}"
        if build_quiet; then
          return 0
        fi
        if [[ ''${#cand[@]} -eq 1 ]]; then
          printf '%s\n' "''${cand[0]}"
          return 0
        fi
        local mid=$(( ''${#cand[@]} / 2 ))
        find_culprits "''${cand[@]:0:mid}"
        find_culprits "''${cand[@]:mid}"
      }

      cp flake.lock flake.lock.pre
      cp flake.nix flake.nix.pre
      restore_tree() {
        cp flake.nix.pre flake.nix
        cp flake.lock.pre flake.lock
        rm -f flake.lock.pre flake.nix.pre
      }

      # Membership test written as a function rather than an inline `&& break`
      # chain: this whole script runs under `set -e`, where a && list that ends
      # false is a trap worth not laying for the next reader.
      contains() { # needle haystack...
        local needle="$1"; shift
        local item
        for item in "$@"; do
          if [[ "$item" == "$needle" ]]; then return 0; fi
        done
        return 1
      }

      mapfile -t BENCHED < <(benched)
      CANDIDATES=()
      for input in "''${INPUTS[@]}" "''${RELEASE_INPUTS[@]}"; do
        if ! contains "$input" ''${BENCHED[@]+"''${BENCHED[@]}"}; then
          CANDIDATES+=("$input")
        fi
      done
      if [[ ''${#BENCHED[@]} -gt 0 ]]; then
        echo "nix-config-sync: benched (retry after $RETRY_AFTER): ''${BENCHED[*]}"
      fi

      resolve_releases

      echo "nix-config-sync: updating ''${#CANDIDATES[@]} inputs..."
      if ! apply_set "''${CANDIDATES[@]}"; then
        echo "nix-config-sync: input update failed, reverting" >&2
        restore_tree
        exit 1
      fi

      # What actually moved. A release input can move via its tag alone, so the
      # lock id is checked alongside the pinned tag.
      MOVED=()
      for input in "''${CANDIDATES[@]}"; do
        if [[ -n "''${RELEASE_TARGET[$input]:-}" ]]; then
          MOVED+=("$input")
          continue
        fi
        old=$(lock_id flake.lock.pre "$input")
        new=$(lock_id flake.lock "$input")
        if [[ -n "$new" && "$old" != "$new" ]]; then
          MOVED+=("$input")
        fi
      done

      if [[ ''${#MOVED[@]} -eq 0 ]]; then
        echo "nix-config-sync: no input updates available"
        restore_tree
        exit 0
      fi

      SKIPPED=()
      if build_quiet; then
        KEPT=("''${MOVED[@]}")
      else
        echo "nix-config-sync: bump build failed; bisecting ''${#MOVED[@]} moved input(s)..." >&2
        mapfile -t SKIPPED < <(find_culprits "''${MOVED[@]}")
        KEPT=()
        for input in "''${MOVED[@]}"; do
          if ! contains "$input" ''${SKIPPED[@]+"''${SKIPPED[@]}"}; then
            KEPT+=("$input")
          fi
        done

        echo "nix-config-sync: culprit(s): ''${SKIPPED[*]:-none found}"
        for input in ''${SKIPPED[@]+"''${SKIPPED[@]}"}; do
          bench "$input" "toplevel build failed"
        done

        # Re-verify the survivors together. If they still don't build, the
        # failure isn't attributable to any single input (a genuine interaction,
        # or something outside the bump entirely) and landing a half-bisected
        # lock would be worse than landing nothing.
        if [[ ''${#KEPT[@]} -eq 0 ]] || ! apply_set "''${KEPT[@]}" || ! build_quiet; then
          echo "nix-config-sync: nothing survivable in this bump, reverting" >&2
          restore_tree
          notify error bump-stalled "input bump stalled" \
            "no survivable subset of: ''${MOVED[*]}"
          exit 1
        fi
      fi

      # Anything that built is healthy by definition, including something that
      # was benched and has just come back.
      for input in ''${KEPT[@]+"''${KEPT[@]}"}; do
        unbench "$input"
      done

      # Describe each bumped input for the commit body. locked.rev covers the
      # git/github inputs; narHash is the fallback for anything without a rev.
      body=""
      for input in ''${KEPT[@]+"''${KEPT[@]}"}; do
        if [[ -n "''${RELEASE_TARGET[$input]:-}" ]]; then
          body+="  $input: ''${RELEASE_FROM[$input]} → ''${RELEASE_TARGET[$input]} (release)"$'\n'
          continue
        fi
        old=$(lock_id flake.lock.pre "$input")
        new=$(lock_id flake.lock "$input")
        body+="  $input: ''${old:0:12} → ''${new:0:12}"$'\n'
      done
      # A silent skip reads as "everything is fine", which is the exact lie that
      # made the atuin breakage take two days to notice. Say it in the commit.
      for input in ''${SKIPPED[@]+"''${SKIPPED[@]}"}; do
        body+="  $input: SKIPPED (build failed)"$'\n'
      done
      rm -f flake.lock.pre flake.nix.pre

      count=''${#KEPT[@]}
      subject="nix-config-sync: bump $count fast-moving input(s)"
      if [[ ''${#SKIPPED[@]} -gt 0 ]]; then
        subject+=", skip ''${#SKIPPED[@]}"
        runs=$(jq -r --arg i "''${SKIPPED[0]}" \
          '(map(select(.input == $i)) | first | .runs) // 1' "$QUARANTINE" 2>/dev/null || echo 1)
        notify warn bump-stalled "input bump skipping ''${#SKIPPED[@]} input(s)" \
          "''${SKIPPED[*]} failed to build; benched after $runs attempt(s). Everything else landed."
      else
        notify_clear bump-stalled
      fi

      echo "nix-config-sync: committing"
      echo "$subject"
      printf '%s' "$body"

      # flake.nix too: a release-tracked input moves by having its tag rewritten
      # there, and committing only the lock would leave the two disagreeing.
      git add flake.lock flake.nix
      # commit.gpgsign is true globally; this job has no interactive signing
      # agent, so disable signing for the sync commit (mirrors memex-autocommit).
      git -c commit.gpgsign=false commit --quiet -m "$subject" -m "$body"

      echo "nix-config-sync: pushing input bump to main..."
      if ! git push --quiet origin HEAD:main; then
        echo "nix-config-sync: push raced with a newer main; discarding the bump" >&2
        # The racing config push still deserves immediate deployment. The bump
        # can be regenerated against it on the next tick.
        DEPLOY_RESULT=""
        deploy_main
        exit 0
      fi

      # Re-enter the same reconciliation path after pushing. The build is
      # already cached, and a config push that races here wins before activation.
      DEPLOY_RESULT=""
      deploy_main
      echo "nix-config-sync: done"
    '';
  };
in
lib.mkIf (nodeConfig.isNixConfigSyncHost or false) (
  lib.mkMerge [
    { home.packages = [ nix-config-sync ]; }

    (lib.mkIf pkgs.stdenv.isLinux {
      systemd.user.services.nix-config-sync = {
        Unit.Description = "Reconcile nix-config main and fast-moving inputs";
        Service = {
          Type = "oneshot";
          ExecStart = "${nix-config-sync}/bin/nix-config-sync";
        };
      };
      systemd.user.timers.nix-config-sync = {
        Unit.Description = "Hourly nix-config reconciliation with jitter";
        Timer = {
          OnCalendar = "hourly";
          RandomizedDelaySec = "15min";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
  ]
)
