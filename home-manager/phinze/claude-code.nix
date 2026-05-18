{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Fallback LSP servers - used when not in a devShell with project-specific LSPs
  # These are wrapped with --suffix so devShell LSPs take priority
  fallbackLsps = with pkgs; [
    nixd # Nix
    gopls # Go
    clang-tools # C/C++ (clangd)
    # sourcekit-lsp comes from Xcode on macOS, no need for fallback
  ];

  # Wrap claude-code with fallback LSPs in PATH (suffix = lower priority than devShell)
  claude-code-wrapped = pkgs.symlinkJoin {
    name = "claude-code-wrapped";
    paths = [ pkgs.claude-code ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --suffix PATH : ${lib.makeBinPath fallbackLsps} \
        --set DISABLE_UPDATES 1
    '';
  };

  # Status line script with colors
  claude-statusline = pkgs.writeShellScript "claude-statusline" ''
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
in
{
  # Claude Code package with LSP fallbacks
  home.packages = [
    claude-code-wrapped
    inputs.tuicr.defaultPackage.${pkgs.system} # Terminal UI for reviewing agent diffs locally
    pkgs.ast-grep
    pkgs.yq-go # YAML/TOML/JSON processor
    pkgs.python3 # stdlib-only interpreter for data processing (no pip)
    pkgs.poppler_utils # pdftoppm/pdftotext so Read tool can open PDFs
  ];

  # Ignore SWT (Simple Work Tracker) directories globally
  # SWT is a task tracker designed for AI agents that creates .swt/ dirs
  programs.git.ignores = [ ".swt" ];

  # Claude Code settings with statusline and LSP plugins
  home.file.".claude/settings.json" = {
    text = builtins.toJSON {
      statusLine = {
        type = "command";
        command = "${claude-statusline}";
      };
      includeCoAuthoredBy = false;
      skipDangerousModePermissionPrompt = true;
      # Enable LSP plugins: official ones + custom nix-lsp
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
        "clangd-lsp@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
        "nix-lsp" = true; # Custom plugin defined below
        "coderabbit" = true; # CodeRabbit AI code review (standalone, not in a marketplace)
        "miren@miren" = true; # Miren CLI skills (public miren-skills repo)
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        # sourcekit-lsp comes from Xcode, only available on macOS
        "swift-lsp@claude-plugins-official" = true;
      };
      hooks =
        let
          # Wire sophon into every known Claude Code hook event.
          # Unhandled events are logged by the hook command and ignored.
          sophonHook = {
            type = "command";
            command = config.services.sophon.hookCommand;
          };
          sophonOnly = [ { hooks = [ sophonHook ]; } ];
        in
        builtins.listToAttrs (
          map
            (event: {
              name = event;
              value = sophonOnly;
            })
            [
              "Notification"
              "Stop"
              "SessionEnd"
              "UserPromptSubmit"
              "PreToolUse"
              "PostToolUse"
              "PostToolUseFailure"
              "PermissionRequest"
              "SubagentStart"
              "SubagentStop"
              "PreCompact"
            ]
        )
        // {
          # SessionStart has additional hooks beyond sophon
          SessionStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = ''[ -d "$CLAUDE_PROJECT_DIR/.swt" ] && swt agent-help || true'';
                }
                sophonHook
              ];
            }
          ];
        };
    };
    force = true;
  };

  # Declarative plugin registry and marketplace config.
  # Both files are mutable (not symlinks) because Claude Code writes to them at runtime.
  # Our activation seeds them on each rebuild; Claude Code may update them between rebuilds.
  home.activation.claudePluginFiles =
    let
      homeDir = config.home.homeDirectory;
      pluginsDir = "${homeDir}/.claude/plugins";
      officialRev = inputs.claude-plugins-official.rev;
      mirenSkillsRev = inputs.claude-plugin-miren-skills.rev;
      mkPlugin =
        name:
        { gitCommitSha }:
        {
          scope = "user";
          installPath = "${pluginsDir}/${name}";
          version = "1.0.0";
          installedAt = "2026-01-01T00:00:00.000Z";
          lastUpdated = "2026-01-01T00:00:00.000Z";
          inherit gitCommitSha;
        };
      # Only marketplace plugins go in the registry (key = plugin@marketplace).
      # Standalone plugins (coderabbit, nix-lsp) work via enabledPlugins + directory presence.
      basePlugins = {
        "gopls-lsp@claude-plugins-official" = [ (mkPlugin "gopls-lsp" { gitCommitSha = officialRev; }) ];
        "clangd-lsp@claude-plugins-official" = [ (mkPlugin "clangd-lsp" { gitCommitSha = officialRev; }) ];
        "frontend-design@claude-plugins-official" = [
          (mkPlugin "frontend-design" { gitCommitSha = officialRev; })
        ];
        "miren@miren" = [
          (mkPlugin "miren" { gitCommitSha = mirenSkillsRev; })
        ];
      };
      darwinPlugins = lib.optionalAttrs pkgs.stdenv.isDarwin {
        "swift-lsp@claude-plugins-official" = [ (mkPlugin "swift-lsp" { gitCommitSha = officialRev; }) ];
      };
      registryJson = builtins.toJSON {
        version = 2;
        plugins = basePlugins // darwinPlugins;
      };
      registryFile = pkgs.writeText "installed_plugins.json" registryJson;

      # Marketplace registry — tells Claude Code where to find plugin catalogs.
      # Marketplace dirs under plugins/marketplaces/ are git clones managed by Claude Code;
      # we just seed the index so it knows they exist on fresh machines.
      mkMarketplace = name: repo: {
        source = {
          source = "github";
          inherit repo;
        };
        installLocation = "${pluginsDir}/marketplaces/${name}";
        lastUpdated = "2026-01-01T00:00:00.000Z";
      };
      marketplaces = {
        "claude-plugins-official" =
          mkMarketplace "claude-plugins-official" "anthropics/claude-plugins-official";
        "miren" = mkMarketplace "miren" "mirendev/miren-skills";
      };
      marketplacesFile = pkgs.writeText "known_marketplaces.json" (builtins.toJSON marketplaces);
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      install -m 644 ${registryFile} ${pluginsDir}/installed_plugins.json
      install -m 644 ${marketplacesFile} ${pluginsDir}/known_marketplaces.json
    '';

  # Marketplace plugins (symlinked from flake inputs)
  home.file.".claude/plugins/gopls-lsp".source =
    "${inputs.claude-plugins-official}/plugins/gopls-lsp";
  home.file.".claude/plugins/clangd-lsp".source =
    "${inputs.claude-plugins-official}/plugins/clangd-lsp";
  home.file.".claude/plugins/frontend-design".source =
    "${inputs.claude-plugins-official}/plugins/frontend-design";
  home.file.".claude/plugins/coderabbit".source = inputs.claude-plugin-coderabbit;
  home.file.".claude/plugins/miren".source = "${inputs.claude-plugin-miren-skills}/plugins/miren";
  # swift-lsp only useful on macOS (sourcekit-lsp comes from Xcode)
  home.file.".claude/plugins/swift-lsp" = lib.mkIf pkgs.stdenv.isDarwin {
    source = "${inputs.claude-plugins-official}/plugins/swift-lsp";
  };

  # Custom Nix LSP plugin (not in official marketplace)
  home.file.".claude/plugins/nix-lsp/.claude-plugin/plugin.json" = {
    text = builtins.toJSON {
      name = "nix-lsp";
      version = "1.0.0";
      description = "Nix language server (nixd) for code intelligence";
    };
  };
  home.file.".claude/plugins/nix-lsp/.lsp.json" = {
    text = builtins.toJSON {
      nixd = {
        command = "nixd";
        extensionToLanguage = {
          ".nix" = "nix";
        };
      };
    };
  };
  home.file.".claude/plugins/nix-lsp/README.md" = {
    text = ''
      # nix-lsp

      Nix language server (nixd) for Claude Code, providing code intelligence for Nix files.

      ## Supported Extensions
      `.nix`

      ## Installation

      nixd should be available in your PATH, either via:
      - Project devShell (recommended for version matching)
      - Fallback from claude-code wrapper

      ## More Information
      - [nixd GitHub](https://github.com/nix-community/nixd)
    '';
  };

  # Global CLAUDE.md (personal preferences and policies applied to all sessions)
  home.file.".claude/CLAUDE.md" = {
    source = ./claude-global.md;
    force = true;
  };

  # Claude Code rules (always-on instructions loaded automatically)
  home.file.".claude/rules/tooling.md".source = ./claude-rules/tooling.md;

  # tuicr config — catppuccin-mocha matches the rest of the setup (ghostty, tmux)
  xdg.configFile."tuicr/config.toml".text = ''
    theme = "catppuccin-mocha"
  '';

  # tuicr's agent skill: SKILL.md + tuicr-wrapper.sh live in the flake source
  home.file.".claude/skills/tuicr/SKILL.md".source = "${inputs.tuicr}/skills/tuicr/SKILL.md";
  home.file.".claude/skills/tuicr/tuicr-wrapper.sh".source =
    "${inputs.tuicr}/skills/tuicr/tuicr-wrapper.sh";

  # jj skill: version control playbook, auto-loads on any jj/git-adjacent work
  home.file.".claude/skills/jj/SKILL.md".source = ./claude-skills/jj/SKILL.md;

  # session-history skill: search/summarize Claude Code session JSONL files
  home.file.".claude/skills/session-history/SKILL.md".source =
    ./claude-skills/session-history/SKILL.md;
  home.file.".claude/skills/session-history/claude-sessions.sh" = {
    source = ./claude-skills/session-history/claude-sessions.sh;
    executable = true;
  };

  # Claude Code slash commands (skills stored in separate files for easier editing)
  home.file.".claude/commands/whatsup-home.md".source = ./claude-skills/whatsup-home.md;
  home.file.".claude/commands/whatsup-work.md".source = ./claude-skills/whatsup-work.md;
  home.file.".claude/commands/pr-time.md".source = ./claude-skills/pr-time.md;
  home.file.".claude/commands/address-pr-review.md".source = ./claude-skills/address-pr-review.md;
  home.file.".claude/commands/review-pr.md".source = ./claude-skills/review-pr.md;
}
