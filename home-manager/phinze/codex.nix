{
  config,
  lib,
  pkgs,
  ...
}:
let
  nixConfigDir = "${config.home.homeDirectory}/src/github.com/phinze/nix-config";

  # ~/.codex/config.toml. Codex is fast-moving; the schema here is validated
  # against `codex doctor` for the pinned version. Keep it small and let the
  # tool's own defaults handle everything we don't have an opinion about.
  codexConfig = {
    # ChatGPT Pro plan: lean on the strongest reasoning tier by default.
    model_reasoning_effort = "high";

    # Base posture mirrors plain `claude` (not yolo): Codex edits inside the
    # workspace sandbox and asks before escalating. Full yolo lives in the
    # `cdx` shell shortcut (--dangerously-bypass-approvals-and-sandbox), the
    # exact analog of `cld` = claude --dangerously-skip-permissions. Codex 0.133
    # deprecated on-failure, so interactive base uses on-request.
    approval_policy = "on-request";
    sandbox_mode = "workspace-write";

    # Dev machines are trusted; let sandboxed commands reach the network so
    # builds/tests/curl don't trip an approval on every run.
    sandbox_workspace_write.network_access = true;

    # Rig gives Codex panes a stable semantic title through lifecycle hooks.
    # An explicit empty list disables Codex's activity/project OSC renderer so
    # it does not overwrite that title on every spinner frame.
    tui.terminal_title = [ ];

    tools.web_search = true;

    # Linear issue tracking over the official remote MCP endpoint. Same server
    # the Claude Code and Antigravity configs use. First use needs an OAuth
    # handshake: `codex mcp login linear`.
    mcp_servers.linear.url = "https://mcp.linear.app/mcp";

    # Pre-trust this repo so Codex doesn't prompt on first entry.
    projects.${nixConfigDir}.trust_level = "trusted";
  };

  codexConfigFile = (pkgs.formats.toml { }).generate "codex-config.toml" codexConfig;

  codexThreadTitle = import ./codex-thread-title.nix { inherit pkgs; };

  # Codex intentionally follows Claude Code's hook payload contract. Keep the
  # Sophon command provider-specific so it can grow adapter behavior without
  # guessing which harness emitted an otherwise identical event.
  sophonHook = {
    type = "command";
    command = "${config.services.sophon.hookCommand} --provider codex";
  };
  threadTitleHook = {
    type = "command";
    command = "${codexThreadTitle}/bin/codex-thread-title";
  };
  codexHooksFile = pkgs.writeText "codex-hooks.json" (
    builtins.toJSON {
      hooks = builtins.listToAttrs (
        map
          (event: {
            name = event;
            value = [
              {
                hooks = [
                  sophonHook
                ]
                ++ lib.optional (builtins.elem event [
                  "SessionStart"
                  "Stop"
                ]) threadTitleHook;
              }
            ];
          })
          [
            "SessionStart"
            "PermissionRequest"
            "PreToolUse"
            "PostToolUse"
            "Stop"
          ]
      );
    }
  );

  # Personal skills, shared verbatim with the Claude Code and Antigravity
  # installs. A prompt only fires when the human types the slash command, and
  # the model never sees that it exists; a skill carries a description the
  # loader matches on, so Codex can discover and activate one on its own. That
  # distinction is why the PR workflows live here and not in promptCommands.
  skillDirs = {
    second-opinion = ./claude-skills/second-opinion;
    pr-time = ./claude-skills/pr-time;
    address-pr-review = ./claude-skills/address-pr-review;
    review-pr = ./claude-skills/review-pr;
    whatsup-home = ./claude-skills/whatsup-home;
    whatsup-work = ./claude-skills/whatsup-work;
  };

  # Keep each slash command tiny: it explicitly activates the installed skill,
  # whose own directory gives Codex a stable base for bundled scripts. The
  # shim exists purely so typing /pr-time still works out of muscle memory.
  skillShim =
    name: sentence:
    pkgs.writeText "${name}-prompt.md" ''
      Use ${"$" + name} to ${sentence}.

      User request: $ARGUMENTS
    '';

  # Personal slash-commands. In Codex, a markdown file at
  # ~/.codex/prompts/<name>.md becomes /<name>. Every one of ours is now a
  # shim over a skill of the same name, so the typed command and the model's
  # own reach for the workflow land on identical instructions.
  promptCommands = lib.mapAttrs skillShim {
    second-opinion = "get an independent code review";
    pr-time = "ship this work as a PR";
    address-pr-review = "work through the review feedback on the PR";
    review-pr = "review a pull request";
    whatsup-home = "catch up on what's been happening outside work";
    whatsup-work = "catch up on where mirendev work stands";
  };
in
{
  home.packages = [
    pkgs.codex
    codexThreadTitle
  ];

  home.file =
    # Global instructions (the CLAUDE.md equivalent). Read-only input, so a
    # nix-store symlink is fine.
    {
      ".codex/AGENTS.md".source = ./codex-global.md;
      ".codex/hooks.json".source = codexHooksFile;
    }
    # Skills: model-discoverable, each its own directory.
    // lib.mapAttrs' (name: src: {
      name = ".codex/skills/${name}";
      value.source = src;
    }) skillDirs
    # Custom prompts / slash-commands.
    // lib.mapAttrs' (name: src: {
      name = ".codex/prompts/${name}.md";
      value.source = src;
    }) promptCommands;

  # config.toml is installed as a mutable regular file rather than a symlink:
  # `codex mcp add`, `codex mcp login`, and `codex plugin` all rewrite it at
  # runtime, which a read-only nix-store symlink would break.
  #
  # It is merged rather than overwritten, which is where it parts ways with the
  # antigravity and karabiner modules. Those files hold preferences; this one
  # also holds decisions — the directories you told Codex to trust and the hook
  # hashes you approved. A plain install revoked every one of them on each
  # switch, so the next Codex start asked about the folder and the hooks again,
  # and it silently undid the directory trust rig seeds for every rig it
  # creates. Nix still wins on every key it declares; Codex keeps the rest.
  home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${./codex-config-merge.py} \
      ${codexConfigFile} ${config.home.homeDirectory}/.codex/config.toml
  '';
}
