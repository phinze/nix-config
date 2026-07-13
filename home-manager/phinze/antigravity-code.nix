{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Fallback LSP servers - used when not in a devShell with project-specific LSPs
  fallbackLsps = with pkgs; [
    nixd # Nix
    gopls # Go
    clang-tools # C/C++ (clangd)
  ];

  # Wrap antigravity-cli with fallback LSPs in PATH (suffix = lower priority than devShell)
  antigravity-cli-wrapped = pkgs.symlinkJoin {
    name = "antigravity-cli-wrapped";
    paths = [ pkgs.antigravity-cli ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/agy \
        --suffix PATH : ${lib.makeBinPath fallbackLsps}
    '';
  };

  # Status line script with colors (reused from Claude Code statusline logic)
  antigravity-statusline = pkgs.writeShellScript "antigravity-statusline" ''
    read -r input

    # ANSI color codes
    reset=$'\033[0m'
    dim=$'\033[2m'
    cyan=$'\033[36m'
    green=$'\033[32m'
    yellow=$'\033[33m'
    red=$'\033[31m'
    magenta=$'\033[35m'

    # Parse JSON
    model=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "?"')
    used=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // 0 | floor')
    cost=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_cost_usd // 0')
    cwd=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cwd // "~"')

    # Shorten home dir to ~
    cwd="''${cwd/#$HOME/\~}"

    # Color context usage based on percentage
    if [ "$used" -lt 50 ]; then
      ctx_color="$green"
    elif [ "$used" -lt 75 ]; then
      ctx_color="$yellow"
    else
      ctx_color="$red"
    fi

    # Format cost (show cents if < $1, otherwise dollars)
    if [ "$(echo "$cost < 0.01" | ${pkgs.bc}/bin/bc)" -eq 1 ]; then
      cost_fmt="<1¢"
    elif [ "$(echo "$cost < 1" | ${pkgs.bc}/bin/bc)" -eq 1 ]; then
      cents=$(echo "$cost * 100" | ${pkgs.bc}/bin/bc | cut -d. -f1)
      cost_fmt="''${cents}¢"
    else
      cost_fmt="\$$(printf '%.2f' "$cost")"
    fi

    # VCS segment: prefer jj (works in non-colocated workspaces too), fall back to git.
    # All jj calls use --ignore-working-copy to avoid snapshotting on every status refresh.
    raw_cwd=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cwd // "."')
    jj=${pkgs.unstable.jujutsu}/bin/jj
    vcs=""
    if "$jj" --no-pager --ignore-working-copy -R "$raw_cwd" root >/dev/null 2>&1; then
      # Closest-ancestor bookmark, excluding trunk so a merged trunk doesn't drag
      # the prompt back to "main". Mirrors the `jj tug` alias selector.
      bookmark=$("$jj" --no-pager --ignore-working-copy -R "$raw_cwd" log \
        -r 'heads(::@ & bookmarks()) ~ trunk()' --no-graph \
        -T 'bookmarks.map(|b| b.name()).join(",") ++ "\n"' 2>/dev/null | head -n1)
      if [ -z "$bookmark" ]; then
        bookmark=$("$jj" --no-pager --ignore-working-copy -R "$raw_cwd" log \
          -r 'heads(::@ & bookmarks())' --no-graph \
          -T 'bookmarks.map(|b| b.name()).join(",") ++ "\n"' 2>/dev/null | head -n1)
      fi

      # @ info packed as: change_id<TAB>markers<TAB>description
      at_info=$("$jj" --no-pager --ignore-working-copy -R "$raw_cwd" log -r @ --no-graph \
        -T 'change_id.short(8) ++ "\t" ++ if(conflict, "!", "") ++ if(divergent, "÷", "") ++ "\t" ++ description.first_line()' 2>/dev/null)
      change_id="''${at_info%%$'\t'*}"
      rest="''${at_info#*$'\t'}"
      markers="''${rest%%$'\t'*}"
      desc="''${rest#*$'\t'}"

      if [ "''${#desc}" -gt 40 ]; then
        desc="''${desc:0:39}…"
      fi

      if [ -n "$bookmark" ]; then
        vcs="''${magenta}''${bookmark}''${reset} ''${change_id}''${red}''${markers}''${reset}"
      elif [ -n "$change_id" ]; then
        vcs="''${change_id}''${red}''${markers}''${reset}"
      fi
      if [ -n "$desc" ]; then
        vcs="''${vcs} ''${dim}''${desc}''${reset}"
      fi
    else
      branch=$(${pkgs.git}/bin/git -C "$raw_cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      if [ -n "$branch" ]; then
        vcs="''${magenta}''${branch}''${reset}"
      fi
    fi

    # Dim separator
    sep="''${dim} · ''${reset}"

    # Build output
    out="''${cyan}''${model}''${reset}"
    out="''${out}''${sep}''${ctx_color}ctx:''${used}%''${reset}"
    out="''${out}''${sep}''${dim}''${cost_fmt}''${reset}"
    out="''${out}''${sep}''${cwd}"
    if [ -n "$vcs" ]; then
      out="''${out}''${sep}''${vcs}"
    fi

    echo "$out"
  '';

  antigravitySettingsJson = builtins.toJSON {
    colorScheme = "tokyo night";
    enableTelemetry = false;
    gcp = {
      project = "phinze-sandbox-462120";
      location = "us";
    };
    model = "Gemini 3.5 Flash";
    trustedWorkspaces = [
      "${config.home.homeDirectory}/src/github.com/phinze/nix-config"
    ];
    statusLine = {
      type = "command";
      command = "${antigravity-statusline}";
    };
  };

  antigravitySettingsFile = pkgs.writeText "antigravity-settings.json" antigravitySettingsJson;

  # Mutable JSON config files: agy rewrites these at runtime (pretty-prints,
  # normalizes), so they need to be regular files rather than nix-store
  # symlinks. Same pattern as settings.json above (see 31bc298).
  mutableJsonConfigs = {
    "plugins/nix-lsp/plugin.json" = {
      name = "nix-lsp";
    };
    "plugins/nix-lsp/lsp_config.json" = {
      nixd = {
        command = "nixd";
        extensionToLanguage = {
          ".nix" = "nix";
        };
      };
    };
    "plugins/coderabbit/plugin.json" = {
      name = "coderabbit";
    };
    "plugins/miren/plugin.json" = {
      name = "miren";
    };
    "plugins/personal-setup/plugin.json" = {
      name = "personal-setup";
    };
    "plugins/linear-mcp/plugin.json" = {
      name = "linear-mcp";
    };
    "plugins/linear-mcp/mcp_config.json" = {
      mcpServers = {
        linear = {
          serverUrl = "https://mcp.linear.app/mcp";
        };
      };
    };
    "plugins/sophon/plugin.json" = {
      name = "sophon";
    };
    "plugins/sophon/hooks.json" = {
      sophon = {
        PreInvocation = [
          {
            type = "command";
            command = "${config.services.sophon.hookCommand} --provider antigravity --event PreInvocation";
          }
        ];
        PostInvocation = [
          {
            type = "command";
            command = "${config.services.sophon.hookCommand} --provider antigravity --event PostInvocation";
          }
        ];
        Stop = [
          {
            type = "command";
            command = "${config.services.sophon.hookCommand} --provider antigravity --event Stop";
          }
        ];
      };
    };
  };

  mkMutableJson =
    relPath: content:
    pkgs.writeText (builtins.replaceStrings [ "/" ] [ "-" ] relPath) (builtins.toJSON content);

  installMutableJsonLine =
    relPath: content:
    "$DRY_RUN_CMD install -D -m 644 ${mkMutableJson relPath content} ${config.home.homeDirectory}/.gemini/antigravity-cli/${relPath}";
in
{
  # Add the wrapped antigravity-cli to packages
  home.packages = [
    antigravity-cli-wrapped
  ];

  # Note: All antigravity-cli JSON config files (settings.json, plugin.json,
  # mcp_config.json, lsp_config.json, hooks.json) are installed as mutable files via the
  # activation script below. Skill and agent directories remain HM-managed
  # symlinks since agy treats them as read-only inputs.

  # coderabbit plugin: skills + agents directories
  home.file.".gemini/antigravity-cli/plugins/coderabbit/agents".source =
    "${inputs.claude-plugin-coderabbit}/agents";
  home.file.".gemini/antigravity-cli/plugins/coderabbit/skills/code-review".source =
    "${inputs.claude-plugin-coderabbit}/skills/code-review";
  home.file.".gemini/antigravity-cli/plugins/coderabbit/skills/review/SKILL.md".source =
    "${inputs.claude-plugin-coderabbit}/commands/review.md";

  # miren plugin: skills + agents directories
  home.file.".gemini/antigravity-cli/plugins/miren/agents".source =
    "${inputs.claude-plugin-miren-skills}/plugins/miren/agents";
  home.file.".gemini/antigravity-cli/plugins/miren/skills".source =
    "${inputs.claude-plugin-miren-skills}/plugins/miren/skills";

  # personal-setup plugin: skills
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/jj/SKILL.md".source =
    ./claude-skills/jj/SKILL.md;

  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/clipboard/SKILL.md".source =
    ./claude-skills/clipboard/SKILL.md;

  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/second-opinion".source =
    ./claude-skills/second-opinion;

  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/session-history/SKILL.md".source =
    ./claude-skills/session-history/SKILL.md;
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/session-history/claude-sessions.sh" =
    {
      source = ./claude-skills/session-history/claude-sessions.sh;
      executable = true;
    };

  # Custom personal commands mapped natively as prefix-free skills
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/whatsup-home/SKILL.md".source =
    ./claude-skills/whatsup-home.md;
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/whatsup-work/SKILL.md".source =
    ./claude-skills/whatsup-work.md;
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/pr-time/SKILL.md".source =
    ./claude-skills/pr-time.md;
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/address-pr-review/SKILL.md".source =
    ./claude-skills/address-pr-review.md;
  home.file.".gemini/antigravity-cli/plugins/personal-setup/skills/review-pr/SKILL.md".source =
    ./claude-skills/review-pr.md;

  # Install all mutable JSON config files as regular files.
  home.activation.antigravityMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -D -m 644 ${antigravitySettingsFile} ${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json
    ${lib.concatStringsSep "\n    " (lib.mapAttrsToList installMutableJsonLine mutableJsonConfigs)}
  '';
}
