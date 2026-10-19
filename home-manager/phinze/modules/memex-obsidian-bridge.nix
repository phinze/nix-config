{
  pkgs,
  lib,
  config,
  nodeConfig ? { },
  ...
}:
let
  vault = "${config.xdg.dataHome}/memex-obsidian";

  # Moves changes between the Obsidian Sync vault (phone, Mac) and memex's git
  # main. Git stays the record; Obsidian Sync is only the delivery route to
  # devices. See memex Projects/Ideas/memex-obsidian-sync.md.
  #
  # The vault is its own clone, not the shared checkout, so hand edits land as
  # `Obsidian:` commits instead of disappearing into anonymous `Sync:` ones.
  memex-obsidian-bridge = pkgs.writeShellApplication {
    name = "memex-obsidian-bridge";
    runtimeInputs = with pkgs; [
      git
      coreutils
      gnugrep
      gh # git credential helper shells out to `gh auth git-credential`
      obsidian-headless
    ];
    text = ''
      vault=${lib.escapeShellArg vault}

      if [[ ! -d "$vault/.git" ]]; then
        git clone --quiet https://github.com/phinze/memex.git "$vault"
      fi
      cd "$vault"

      # `ob login` and `ob sync-setup` are interactive (password, MFA, E2E
      # key), so until a human has run them there is nothing to bridge.
      if ! ob sync-status --path "$vault" >/dev/null 2>&1; then
        echo "memex-obsidian-bridge: vault not linked to Obsidian Sync yet, skipping" >&2
        exit 0
      fi

      # Same guards as memex-autocommit, with higher stakes: anything left in
      # this working tree gets uploaded to every device on the next ob sync.
      if [[ -d .git/rebase-merge || -d .git/rebase-apply || -e .git/MERGE_HEAD ]]; then
        echo "memex-obsidian-bridge: rebase or merge in progress, skipping" >&2
        exit 1
      fi
      if grep -rln '^<<<<<<< ' --include='*.md' . >/dev/null 2>&1; then
        echo "memex-obsidian-bridge: conflict markers in working tree, skipping" >&2
        exit 1
      fi

      # ob runs one-shot inside this job rather than as a continuous watcher.
      # A rebase can briefly leave conflict markers in the tree, and a watcher
      # would ship them to the phone within seconds. Serialized, ob and git
      # never write here at the same time.
      ob sync --path "$vault"

      # Obsidian doesn't end files with a newline, and agents append diary
      # lines with `>>`, which would glue their line onto the end of Paul's.
      while IFS= read -r -d "" f; do
        if [[ -s "$f" && -n "$(tail -c1 "$f")" ]]; then
          echo >> "$f"
        fi
      done < <(git ls-files -z --modified --others --exclude-standard -- '*.md')

      git add -A
      if ! git diff --cached --quiet; then
        mapfile -t changed < <(git diff --cached --name-only)
        subject="Obsidian: ''${changed[0]}"
        if (( ''${#changed[@]} > 1 )); then
          subject+=" (+$(( ''${#changed[@]} - 1 )) more)"
        fi
        git commit --quiet --no-gpg-sign -m "$subject" \
          -m "Hand edits from an Obsidian Sync device, committed by memex-obsidian-bridge."
      fi

      git fetch --quiet || true

      # Daily/*.md is merge=union, so diary collisions with agents resolve on
      # their own. A prose collision elsewhere aborts here and leaves the
      # commit unpushed; Obsidian Sync keeps working, git just lags until a
      # human sorts it out.
      if ! git -c commit.gpgsign=false rebase --quiet origin/main; then
        git rebase --abort || true
        echo "memex-obsidian-bridge: rebase onto origin/main failed, needs a human" >&2
        exit 1
      fi

      if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
        git push --quiet origin HEAD:main
      fi

      # Hand the merged result, including agent commits, back to devices.
      ob sync --path "$vault"
    '';
  };
in
lib.mkIf ((nodeConfig.isMemexObsidianBridgeHost or false) && pkgs.stdenv.hostPlatform.isLinux) {
  home.packages = [
    memex-obsidian-bridge
    pkgs.obsidian-headless
  ];

  systemd.user.services.memex-obsidian-bridge = {
    Unit.Description = "Bridge memex between Obsidian Sync and git";
    Service = {
      Type = "oneshot";
      ExecStart = "${memex-obsidian-bridge}/bin/memex-obsidian-bridge";
    };
  };
  systemd.user.timers.memex-obsidian-bridge = {
    Unit.Description = "Run the memex Obsidian bridge every 5 minutes";
    Timer = {
      OnCalendar = "*:0/5";
      RandomizedDelaySec = "30s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
