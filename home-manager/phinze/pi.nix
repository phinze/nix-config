{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;

  # Secrets live outside the store and outside any repo. The LithosAI key is
  # created by hand from the console; the OAuth file key is minted on first
  # activation (below) and only ever read by the wrapper.
  lithosTokenFile = "${home}/.config/lithosai/token";
  oauthKeyFile = "${home}/.config/pi/mcp-oauth-key";

  # Pi is the agent we run against LithosAI, whose API is plain OpenAI Chat
  # Completions. Claude Code and Codex can only reach it through a LiteLLM
  # translation proxy; Pi speaks the protocol natively, so nothing sits in
  # between. Stable nixpkgs is a dozen releases behind, hence unstable.
  piPackage = pkgs.unstable.pi-coding-agent;

  # Context and output limits are local metadata: LithosAI's /v1/models does
  # not publish them, and Pi falls back to generic defaults that make its
  # context meter and compaction lie. Kimi's figures come from LithosAI's own
  # integration docs; the rest are left to Pi's defaults until we look them up
  # in the console.
  models = {
    providers.lithosai = {
      baseUrl = "https://api.lithosai.cloud/v1";
      api = "openai-completions";
      apiKey = "$LITHOSAI_API_KEY";
      models = [
        {
          id = "moonshotai/Kimi-K3";
          name = "Kimi K3";
          contextWindow = 262144;
          maxTokens = 32768;
        }
        {
          id = "moonshotai/Kimi-K3-fast";
          name = "Kimi K3 fast";
          contextWindow = 262144;
          maxTokens = 32768;
        }
        {
          id = "deepseek-ai/DeepSeek-V4.1-Flash";
          name = "DeepSeek V4.1 Flash";
        }
        {
          id = "deepseek-ai/DeepSeek-V4.1-Flash-fast";
          name = "DeepSeek V4.1 Flash fast";
        }
        {
          id = "zai-org/GLM-5.3";
          name = "GLM 5.3";
        }
      ];
    };
  };

  # The keys nix owns in ~/.pi/agent/settings.json. Pi writes to the same file
  # (theme, changelog version, a Ctrl+S model save), so this is merged in on
  # activation rather than symlinked; see piMutableConfig below.
  settings = {
    defaultProvider = "lithosai";
    defaultModel = "moonshotai/Kimi-K3";

    # Loaded from the store instead of `pi install`, which would need npm on
    # PATH and update itself behind our back.
    packages = [ "${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter" ];

    # rig-peer is the pi half of `rig send`'s pi transport: presence file +
    # socket, so peer rigs can deliver messages at the turn boundary. It
    # ships inside the rig package so both sides version together; the
    # extension and its wire format are one change in one repo. A session
    # loads it at startup, so a bumped rig input means a restart to pick it
    # up — until then the rig simply has no presence and sends fail loudly.
    extensions = [ "${pkgs.rig}/share/rig/rig-peer.ts" ];

    # Every skill Claude Code has, read in place. interface-design keeps its
    # SKILL.md under a hidden .claude/ directory, which discovery skips, so it
    # is named explicitly.
    skills = [
      "~/.claude/skills"
      "~/.claude/skills/interface-design/.claude/skills"
    ];

    # grep, find, and ls ship with Pi but start disabled. Without them the
    # model reaches for bash to do the same job less safely.
    defaultTools = [
      "read"
      "bash"
      "edit"
      "write"
      "grep"
      "find"
      "ls"
    ];

    enableInstallTelemetry = false;
  };

  # pi-mcp-adapter config. Linear is the same remote endpoint Claude Code and
  # Codex use, authorized once with `/mcp-auth linear` inside Pi. The adapter
  # refuses to store OAuth tokens in plaintext and wants a Secret Service
  # keyring by default, which a headless VM doesn't run, so tokens go to its
  # AES-GCM file store under ~/.pi/agent/mcp-oauth-encrypted/ instead, keyed
  # by oauthKeyFile.
  mcpAdapter = {
    settings.oauthCredentialStore = "encrypted-file";
    mcpServers.linear = {
      url = "https://mcp.linear.app/mcp";
      auth = "oauth";
    };
  };

  json = pkgs.formats.json { };
  settingsFile = json.generate "pi-settings.json" settings;
  mcpAdapterFile = json.generate "pi-mcp-adapter.json" mcpAdapter;

  # Global instructions. codex-global.md is already the agent-neutral
  # adaptation of claude-global.md; only its opening paragraph names Codex's
  # file layout, so swap that paragraph rather than keep a third copy. The
  # assert catches the day that paragraph is edited and the swap silently
  # stops matching.
  codexIntro = ''
    Adapted from the shared global instructions used across my agents (the Claude
    Code `CLAUDE.md`). Same person, same voice, same policies — the mechanics below
    are written for Codex (config in `~/.codex`, skills under `~/.codex/skills/`
    and custom commands as prompts under `~/.codex/prompts/`) rather than Claude's
    skills/settings.
  '';
  piIntro = ''
    Adapted from the shared global instructions used across my agents (the Claude
    Code `CLAUDE.md`). Same person, same voice, same policies. You are running in
    Pi (config in `~/.pi/agent`), with the same skills Claude Code uses, read from
    `~/.claude/skills`. Some of those skills mention Claude-only tools (Monitor,
    AskUserQuestion, Agent, Artifact); where one does, get the same outcome with
    the tools you have, usually bash.
  '';
  codexGlobal = builtins.readFile ./codex-global.md;
  piGlobal =
    assert lib.assertMsg (lib.hasInfix codexIntro codexGlobal)
      "pi.nix: codex-global.md's intro paragraph changed; update codexIntro to match";
    builtins.replaceStrings [ codexIntro ] [ piIntro ] codexGlobal;

  # `pi` on PATH is this wrapper. It reads both secrets from files at launch,
  # so nothing sensitive is baked into the store or left in a shell profile.
  # A missing token is not fatal: Pi still starts, and says the LithosAI
  # models are unavailable.
  piWrapper = pkgs.writeShellApplication {
    name = "pi";
    text = ''
      if [[ -z "''${LITHOSAI_API_KEY:-}" && -r ${lithosTokenFile} ]]; then
        LITHOSAI_API_KEY=$(<${lithosTokenFile})
        export LITHOSAI_API_KEY
      fi
      if [[ -z "''${PI_MCP_ADAPTER_OAUTH_FILE_KEY:-}" && -r ${oauthKeyFile} ]]; then
        PI_MCP_ADAPTER_OAUTH_FILE_KEY=$(<${oauthKeyFile})
        export PI_MCP_ADAPTER_OAUTH_FILE_KEY
      fi
      exec ${lib.getExe piPackage} "$@"
    '';
  };
in
{
  home.packages = [ piWrapper ];

  home.file = {
    ".pi/agent/AGENTS.md".text = piGlobal;
    # Read-only input; Pi keeps its own writable model state in
    # models-store.json alongside.
    ".pi/agent/models.json".source = json.generate "pi-models.json" models;
  };

  # settings.json and mcp-adapter.json both have a second writer (Pi itself,
  # and the adapter's /mcp-adapter panel), so each is deep-merged: nix wins on
  # every key it declares, anything else already in the file survives. Arrays
  # are replaced whole, which is what we want for packages and skills.
  home.activation.piMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    merge_json() {
      local generated=$1 deployed=$2
      $DRY_RUN_CMD mkdir -p "$(dirname "$deployed")"
      if [[ -f "$deployed" && ! -L "$deployed" ]]; then
        local merged
        merged=$(${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$deployed" "$generated")
        [[ -n "''${DRY_RUN:-}" ]] || printf '%s\n' "$merged" > "$deployed"
      else
        $DRY_RUN_CMD rm -f "$deployed"
        $DRY_RUN_CMD install -m 600 "$generated" "$deployed"
      fi
    }
    merge_json ${settingsFile} ${home}/.pi/agent/settings.json
    merge_json ${mcpAdapterFile} ${home}/.pi/agent/mcp-adapter.json

    # Mint the OAuth file key once. Losing it only costs a re-run of
    # /mcp-auth, but rotating it on every switch would cost that every time.
    if [[ ! -s ${oauthKeyFile} ]]; then
      $DRY_RUN_CMD mkdir -p -m 700 "$(dirname ${oauthKeyFile})"
      [[ -n "''${DRY_RUN:-}" ]] || (umask 077; ${lib.getExe pkgs.openssl} rand -base64 32 > ${oauthKeyFile})
    fi
  '';
}
