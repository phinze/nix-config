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

  flake-sync = pkgs.writeShellApplication {
    name = "flake-sync";
    runtimeInputs = with pkgs; [
      git
      coreutils
      gnugrep
      jq
      gh # git credential helper shells out to `gh auth git-credential`
    ];
    text = ''
      REPO_URL="https://github.com/phinze/nix-config.git"
      CLONE_DIR="${cloneDir}"
      RESULT_LINK="${resultLink}"
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

      # The bot owns this clone outright, so always start pristine on the latest
      # main. Hard reset means we never build on stale state or bake leftover
      # cruft into a sync commit. Offline is fine, just try again next tick.
      if ! git fetch --quiet origin main; then
        echo "flake-sync: fetch failed (offline?), skipping" >&2
        exit 0
      fi
      git reset --hard --quiet origin/main
      git clean -fdq

      # Snapshot the lock so we can describe exactly what moved.
      cp flake.lock flake.lock.pre

      echo "flake-sync: updating ''${#INPUTS[@]} inputs..."
      nix flake update "''${INPUTS[@]}" 2>&1 | grep -v '^warning:' || true

      if git diff --quiet flake.lock; then
        echo "flake-sync: no updates available"
        rm -f flake.lock.pre
        exit 0
      fi

      # Build gate: prove the closure actually builds before anything lands on
      # main or gets activated. A broken fast-mover (say a bad rig push) reverts
      # the lock here and we retry on the next tick instead of shipping it.
      echo "flake-sync: building $HOST toplevel..."
      if ! nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
           --out-link "$RESULT_LINK"; then
        echo "flake-sync: build failed, reverting lock" >&2
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
      subject="flake-sync: bump $count fast-moving input(s)"

      echo "flake-sync: committing"
      echo "$subject"
      printf '%s' "$body"

      git add flake.lock
      # commit.gpgsign is true globally; this job has no interactive signing
      # agent, so disable signing for the sync commit (mirrors memex-autocommit).
      git -c commit.gpgsign=false commit --quiet -m "$subject" -m "$body"

      echo "flake-sync: pushing to main..."
      if ! git push --quiet origin HEAD:main; then
        echo "flake-sync: push rejected (raced?), resetting for next tick" >&2
        git fetch --quiet origin main || true
        git reset --hard --quiet origin/main
        exit 1
      fi

      # Activate the already-built closure. Everything above ran as phinze (so
      # gh credentials fetch the private inputs); root only flips the system
      # profile and switches, so it never needs to fetch anything itself.
      echo "flake-sync: activating on $HOST..."
      target=$(readlink -f "$RESULT_LINK")
      sudo nix-env -p /nix/var/nix/profiles/system --set "$target"
      sudo "$target/bin/switch-to-configuration" switch
      echo "flake-sync: done"
    '';
  };
in
lib.mkIf (nodeConfig.isFlakeSyncHost or false) (
  lib.mkMerge [
    { home.packages = [ flake-sync ]; }

    (lib.mkIf pkgs.stdenv.isLinux {
      systemd.user.services.flake-sync = {
        Unit.Description = "Sync fast-moving flake inputs and switch";
        Service = {
          Type = "oneshot";
          ExecStart = "${flake-sync}/bin/flake-sync";
        };
      };
      systemd.user.timers.flake-sync = {
        Unit.Description = "Hourly fast-moving flake input sync with jitter";
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
