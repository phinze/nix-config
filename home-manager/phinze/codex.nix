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

  # Personal slash-commands, reused verbatim from the Claude Code skill sources.
  # In Codex, a markdown file at ~/.codex/prompts/<name>.md becomes /<name>.
  promptCommands = {
    whatsup-home = ./claude-skills/whatsup-home.md;
    whatsup-work = ./claude-skills/whatsup-work.md;
    pr-time = ./claude-skills/pr-time.md;
    address-pr-review = ./claude-skills/address-pr-review.md;
    review-pr = ./claude-skills/review-pr.md;
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
    # Custom prompts / slash-commands.
    // lib.mapAttrs' (name: src: {
      name = ".codex/prompts/${name}.md";
      value.source = src;
    }) promptCommands;

  # config.toml is installed as a mutable regular file rather than a symlink:
  # `codex mcp add`, `codex mcp login`, and `codex plugin` all rewrite it at
  # runtime, which a read-only nix-store symlink would break. Same tradeoff the
  # antigravity module makes for its JSON configs — edit the nix source, not
  # the deployed file; a home-manager switch overwrites it.
  home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -D -m 644 ${codexConfigFile} ${config.home.homeDirectory}/.codex/config.toml
  '';
}
