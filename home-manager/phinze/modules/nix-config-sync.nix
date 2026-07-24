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
    "atuin"
    # Claude plugin sources (flake = false)
    "claude-plugins-official"
    "claude-plugin-coderabbit"
    "claude-plugin-miren-skills"
    "claude-plugin-miren-team"
    # Miren work infra
    "iso"
    "multipass"
  ];

  host = "foxtrotbase";
  cloneDir = "${config.home.homeDirectory}/.local/state/nix-config-sync";
  resultLink = "${config.home.homeDirectory}/.local/state/nix-config-sync-result";
  deploymentState = "${config.home.homeDirectory}/.local/state/nix-config-sync-deployment";

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
      HOST="${host}"
      INPUTS=(${lib.concatStringsSep " " syncInputs})

      # `nix` and the setuid `sudo` wrapper live in the system profile, not in
      # our runtimeInputs; make sure they resolve inside the user service.
      export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

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

      # Only after main is active do we attempt the independent input-bump
      # transaction. Snapshot the lock so the commit can say exactly what moved.
      cp flake.lock flake.lock.pre

      echo "nix-config-sync: updating ''${#INPUTS[@]} inputs..."
      if ! nix flake update "''${INPUTS[@]}" 2>&1 |
        { grep -v '^warning:' || true; }
      then
        echo "nix-config-sync: input update failed, reverting lock" >&2
        git checkout --quiet -- flake.lock
        rm -f flake.lock.pre
        exit 1
      fi

      if git diff --quiet flake.lock; then
        echo "nix-config-sync: no input updates available"
        rm -f flake.lock.pre
        exit 0
      fi

      # Prove the bumped closure builds before it lands on main.
      if ! build_system "the proposed input bump"; then
        echo "nix-config-sync: input bump build failed, reverting lock" >&2
        git checkout --quiet -- flake.lock
        rm -f flake.lock.pre
        exit 1
      fi

      # Describe each bumped input for the commit body. locked.rev covers the
      # git/github inputs; narHash is the fallback for anything without a rev.
      body=""
      for input in "''${INPUTS[@]}"; do
        old=$(jq -r --arg i "$input" \
          '.nodes[$i].locked.rev // .nodes[$i].locked.narHash // empty' flake.lock.pre)
        new=$(jq -r --arg i "$input" \
          '.nodes[$i].locked.rev // .nodes[$i].locked.narHash // empty' flake.lock)
        if [[ -n "$new" && "$old" != "$new" ]]; then
          body+="  $input: ''${old:0:12} → ''${new:0:12}"$'\n'
        fi
      done
      rm -f flake.lock.pre

      count=$(printf '%s' "$body" | grep -c . || true)
      subject="nix-config-sync: bump $count fast-moving input(s)"

      echo "nix-config-sync: committing"
      echo "$subject"
      printf '%s' "$body"

      git add flake.lock
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
