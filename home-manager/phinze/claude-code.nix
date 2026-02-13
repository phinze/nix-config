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
    # sourcekit-lsp comes from Xcode on macOS, no need for fallback
  ];

  # ntfy push notification hook for Claude Code (built directly, not via overlay,
  # so it works on both NixOS and darwin without nixpkgs.overlays)
  claude-ntfy-hook = pkgs.callPackage ../../pkgs/claude-ntfy-hook.nix { };

  # Wrap claude-code with fallback LSPs in PATH (suffix = lower priority than devShell)
  claude-code-wrapped = pkgs.symlinkJoin {
    name = "claude-code-wrapped";
    paths = [ pkgs.claude-code ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --suffix PATH : ${lib.makeBinPath fallbackLsps}
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

    # Get git branch if in a repo
    branch=$(${pkgs.git}/bin/git -C "$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cwd // "."')" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    # Dim separator
    sep="''${dim} · ''${reset}"

    # Build output
    out="''${cyan}''${model}''${reset}"
    out="''${out}''${sep}''${ctx_color}ctx:''${used}%''${reset}"
    out="''${out}''${sep}''${dim}''${cost_fmt}''${reset}"
    out="''${out}''${sep}''${cwd}"
    if [ -n "$branch" ]; then
      out="''${out}''${sep}''${magenta}''${branch}''${reset}"
    fi

    echo "$out"
  '';
in
{
  # Claude Code package with LSP fallbacks
  home.packages = [
    claude-code-wrapped
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
      # Enable LSP plugins: official ones + custom nix-lsp
      enabledPlugins = {
        "gopls-lsp@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
        "nix-lsp" = true; # Custom plugin defined below
        "coderabbit@claude-plugins-official" = true; # CodeRabbit AI code review
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        # sourcekit-lsp comes from Xcode, only available on macOS
        "swift-lsp@claude-plugins-official" = true;
      };
      hooks = {
        SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = ''[ -d "$CLAUDE_PROJECT_DIR/.swt" ] && swt agent-help || true'';
              }
              {
                type = "command";
                command = "${claude-ntfy-hook}/bin/claude-ntfy-hook";
              }
            ];
          }
        ];
        Notification = [
          {
            hooks = [
              {
                type = "command";
                command = "${claude-ntfy-hook}/bin/claude-ntfy-hook";
              }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "${claude-ntfy-hook}/bin/claude-ntfy-hook";
              }
            ];
          }
        ];
      };
    };
    force = true;
  };

  # Declarative plugin registry — replaces imperative `claude plugin install`
  # Each entry points installPath at our nix-managed plugin directories.
  # Written as a mutable file (not symlink) because claude tries to write to it.
  home.activation.claudePluginRegistry =
    let
      homeDir = config.home.homeDirectory;
      pluginsDir = "${homeDir}/.claude/plugins";
      officialRev = inputs.claude-plugins-official.rev;
      coderabbitRev = inputs.claude-plugin-coderabbit.rev;
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
      basePlugins = {
        "gopls-lsp@claude-plugins-official" = [ (mkPlugin "gopls-lsp" { gitCommitSha = officialRev; }) ];
        "frontend-design@claude-plugins-official" = [
          (mkPlugin "frontend-design" { gitCommitSha = officialRev; })
        ];
        "coderabbit@claude-plugins-official" = [
          (mkPlugin "coderabbit" { gitCommitSha = coderabbitRev; })
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
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      install -m 644 ${registryFile} ${pluginsDir}/installed_plugins.json
    '';

  # Marketplace plugins (symlinked from flake inputs)
  home.file.".claude/plugins/gopls-lsp".source =
    "${inputs.claude-plugins-official}/plugins/gopls-lsp";
  home.file.".claude/plugins/frontend-design".source =
    "${inputs.claude-plugins-official}/plugins/frontend-design";
  home.file.".claude/plugins/coderabbit".source = inputs.claude-plugin-coderabbit;
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

  # Claude Code slash commands (skills stored in separate files for easier editing)
  home.file.".claude/commands/whatsup.md".source = ./claude-skills/whatsup.md;
  home.file.".claude/commands/pr-time.md".source = ./claude-skills/pr-time.md;
  home.file.".claude/commands/address-pr-review.md".source = ./claude-skills/address-pr-review.md;
  home.file.".claude/commands/review-pr.md".source = ./claude-skills/review-pr.md;
}
