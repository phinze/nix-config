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
    pkgs.ast-grep
    pkgs.yq-go # YAML/TOML/JSON processor
    pkgs.python3 # stdlib-only interpreter for data processing (no pip)
    pkgs.poppler-utils # pdftoppm/pdftotext so Read tool can open PDFs
    # snap: capture a macOS window to /tmp by app+title. Lives in PATH (not
    # a fish function) so subagents shelling out via bash can call it too.
    (pkgs.writeShellScriptBin "snap" (builtins.readFile ./scripts/snap.sh))
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
      # Plugins auto-load from ~/.claude/skills/<name>/ (each carries a
      # .claude-plugin/plugin.json) as of Claude Code 2.1.157. No enabledPlugins
      # block, marketplace registry, or installed_plugins.json needed anymore.
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

  # Skills-directory plugins (Claude Code 2.1.157+): any dir under
  # ~/.claude/skills/<name>/ that carries a .claude-plugin/plugin.json loads
  # automatically as <name>@skills-dir — no marketplace, no installed_plugins.json,
  # no enabledPlugins entry. This replaces the old registry + activation machinery.

  # Plugins whose upstream dir is already self-contained — symlink straight in.
  home.file.".claude/skills/frontend-design".source =
    "${inputs.claude-plugins-official}/plugins/frontend-design";
  home.file.".claude/skills/coderabbit".source = inputs.claude-plugin-coderabbit;
  home.file.".claude/skills/miren".source = "${inputs.claude-plugin-miren-skills}/plugins/miren";

  # Official LSP plugins: the upstream plugin dirs ship only a README (their
  # lspServers config lives in the marketplace catalog, not the dir), so we author
  # self-contained skills-dir plugins from the same config. These configs are tiny
  # and stable, so hand-maintaining them is cheaper than the marketplace machinery.
  home.file.".claude/skills/gopls-lsp/.claude-plugin/plugin.json".text = builtins.toJSON {
    name = "gopls-lsp";
    version = "1.0.0";
    description = "Go language server (gopls) for code intelligence";
  };
  home.file.".claude/skills/gopls-lsp/.lsp.json".text = builtins.toJSON {
    gopls = {
      command = "gopls";
      extensionToLanguage.".go" = "go";
    };
  };

  home.file.".claude/skills/clangd-lsp/.claude-plugin/plugin.json".text = builtins.toJSON {
    name = "clangd-lsp";
    version = "1.0.0";
    description = "C/C++ language server (clangd) for code intelligence";
  };
  home.file.".claude/skills/clangd-lsp/.lsp.json".text = builtins.toJSON {
    clangd = {
      command = "clangd";
      args = [ "--background-index" ];
      extensionToLanguage = {
        ".c" = "c";
        ".h" = "c";
        ".cpp" = "cpp";
        ".cc" = "cpp";
        ".cxx" = "cpp";
        ".hpp" = "cpp";
        ".hxx" = "cpp";
        ".C" = "cpp";
        ".H" = "cpp";
      };
    };
  };

  # swift-lsp only useful on macOS (sourcekit-lsp comes from Xcode).
  home.file.".claude/skills/swift-lsp/.claude-plugin/plugin.json" = lib.mkIf pkgs.stdenv.isDarwin {
    text = builtins.toJSON {
      name = "swift-lsp";
      version = "1.0.0";
      description = "Swift language server (SourceKit-LSP) for code intelligence";
    };
  };
  home.file.".claude/skills/swift-lsp/.lsp.json" = lib.mkIf pkgs.stdenv.isDarwin {
    text = builtins.toJSON {
      "sourcekit-lsp" = {
        command = "sourcekit-lsp";
        extensionToLanguage.".swift" = "swift";
      };
    };
  };

  # Custom Nix LSP plugin (nixd), authored in-tree.
  home.file.".claude/skills/nix-lsp/.claude-plugin/plugin.json".text = builtins.toJSON {
    name = "nix-lsp";
    version = "1.0.0";
    description = "Nix language server (nixd) for code intelligence";
  };
  home.file.".claude/skills/nix-lsp/.lsp.json".text = builtins.toJSON {
    nixd = {
      command = "nixd";
      extensionToLanguage.".nix" = "nix";
    };
  };

  # Global CLAUDE.md (personal preferences and policies applied to all sessions)
  home.file.".claude/CLAUDE.md" = {
    source = ./claude-global.md;
    force = true;
  };

  # Claude Code rules (always-on instructions loaded automatically)
  home.file.".claude/rules/tooling.md".source = ./claude-rules/tooling.md;

  # jj skill: version control playbook, auto-loads on any jj/git-adjacent work
  home.file.".claude/skills/jj/SKILL.md".source = ./claude-skills/jj/SKILL.md;

  # clipboard skill: steer copy/clipboard asks to the one reliable invocation
  # (heredoc into pbcopy) instead of probing for xclip/xsel/wl-copy or
  # falling back to /tmp files and tmux load-buffer.
  home.file.".claude/skills/clipboard/SKILL.md".source = ./claude-skills/clipboard/SKILL.md;

  # snap skill: capture a macOS window to /tmp by app+title without focus-stealing
  home.file.".claude/skills/snap/SKILL.md".source = ./claude-skills/snap/SKILL.md;

  # recto skill: drive a running recto diff viewer (focus/highlight a span,
  # annotate tour steps, clear, ping) so companion sessions can point the user
  # at exact lines. Ships from the recto flake input — same pinned rev as the
  # binary, so the skill always documents the CLI that's actually installed.
  home.file.".claude/skills/recto/SKILL.md".source = "${inputs.recto}/skills/recto/SKILL.md";

  # session-history skill: search/summarize Claude Code session JSONL files
  home.file.".claude/skills/session-history/SKILL.md".source =
    ./claude-skills/session-history/SKILL.md;
  home.file.".claude/skills/session-history/claude-sessions.sh" = {
    source = ./claude-skills/session-history/claude-sessions.sh;
    executable = true;
  };

  # Custom Linear MCP plugin (via official remote hosted endpoint).
  home.file.".claude/skills/linear-mcp/.claude-plugin/plugin.json".text = builtins.toJSON {
    name = "linear-mcp";
    version = "1.0.0";
    description = "Linear MCP server for issue tracking and management";
  };
  home.file.".claude/skills/linear-mcp/.mcp.json".text = builtins.toJSON {
    mcpServers = {
      linear = {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };
    };
  };

  # Claude Code slash commands (skills stored in separate files for easier editing)
  home.file.".claude/commands/whatsup-home.md".source = ./claude-skills/whatsup-home.md;
  home.file.".claude/commands/whatsup-work.md".source = ./claude-skills/whatsup-work.md;
  home.file.".claude/commands/pr-time.md".source = ./claude-skills/pr-time.md;
  home.file.".claude/commands/address-pr-review.md".source = ./claude-skills/address-pr-review.md;
  home.file.".claude/commands/review-pr.md".source = ./claude-skills/review-pr.md;
}
