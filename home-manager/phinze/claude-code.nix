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
        --suffix PATH : ${lib.makeBinPath fallbackLsps}
    '';
  };

  # PostToolUse hook: poke neovim's diffview when Claude modifies files
  claude-diffview-hook = pkgs.writeShellScript "claude-diffview-hook" ''
    input=$(cat)
    tool=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.tool_name // ""')

    # Only care about file-modifying tools
    case "$tool" in
      Write|Edit|MultiEdit) ;;
      *) exit 0 ;;
    esac

    # Derive tmux session name from cwd (same formula as pickup/review fish functions)
    cwd=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cwd // ""')
    [ -z "$cwd" ] && exit 0

    session_name=$(echo "$cwd" | sed "s|$HOME|~|" | tr ' .:' '---' | tr '[:upper:]' '[:lower:]')

    # Flatten slashes to hyphens so the socket path doesn't imply subdirectories
    sock_name=$(echo "$session_name" | tr '/' '-')

    # Socket path: env override or derived from session name
    sock="''${CLAUDE_NVIM_SOCK:-/tmp/nvc-''${sock_name}.sock}"

    # Truncate socket path if too long for unix domain socket (108 char limit)
    if [ ''${#sock} -gt 100 ]; then
      hash=$(echo "$sock_name" | ${pkgs.coreutils}/bin/md5sum | cut -c1-12)
      sock="/tmp/nvc-''${hash}.sock"
    fi

    # Skip if neovim isn't listening
    [ -S "$sock" ] || exit 0

    # Simple debounce: skip if last poke was <2 seconds ago
    debounce_file="/tmp/claude-diffview-debounce-$$PPID"
    now=$(date +%s)
    last=$(cat "$debounce_file" 2>/dev/null || echo 0)
    if [ $((now - last)) -lt 2 ]; then
      exit 0
    fi
    echo "$now" > "$debounce_file"

    # Tell neovim to re-check files on disk
    ${pkgs.neovim}/bin/nvim --server "$sock" --remote-send '<cmd>checktime<CR>' 2>/dev/null || true
  '';

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
    pkgs.ast-grep
    pkgs.yq-go # YAML/TOML/JSON processor
    pkgs.python3 # stdlib-only interpreter for data processing (no pip)
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
        "coderabbit@claude-plugins-official" = true; # CodeRabbit AI code review
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
          diffviewHook = {
            type = "command";
            command = "${claude-diffview-hook}";
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
          # PostToolUse: sophon + poke neovim diffview on file changes
          PostToolUse = [
            {
              hooks = [
                diffviewHook
                sophonHook
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
        "clangd-lsp@claude-plugins-official" = [ (mkPlugin "clangd-lsp" { gitCommitSha = officialRev; }) ];
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
  home.file.".claude/plugins/clangd-lsp".source =
    "${inputs.claude-plugins-official}/plugins/clangd-lsp";
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

  # Neovim commands for reviewing Claude Code changes
  # Placed in site/plugin/ so neovim loads it automatically
  home.file.".local/share/nvim/site/plugin/claude-review.lua".text = ''
    -- Refresh quickfix with changed hunks (shared by ClaudeChanges and ClaudeWatch)
    local function refresh_changes(base)
      local cmd
      if base then
        cmd = string.format("git diff --name-only %s...HEAD", base)
      else
        cmd = "git diff --name-only"
      end
      local files = vim.fn.systemlist(cmd)
      if vim.v.shell_error ~= 0 or #files == 0 then
        return
      end

      for _, file in ipairs(files) do
        if file ~= "" then
          vim.fn.bufadd(file)
          vim.fn.bufload(file)
        end
      end

      vim.defer_fn(function()
        require('gitsigns').setqflist("all", { open = false })
      end, 500)
    end

    -- ClaudeChanges: one-shot populate quickfix with changed hunks
    vim.api.nvim_create_user_command('ClaudeChanges', function(opts)
      local base = opts.args ~= "" and opts.args or nil
      if base then
        require('gitsigns').change_base(base, true)
      end
      refresh_changes(base)
      -- Open quickfix on first run
      vim.defer_fn(function() vim.cmd("copen") end, 600)
    end, { nargs = "?", desc = "Populate quickfix with changed hunks (optional: base ref)" })

    -- ClaudeWatch: open neo-tree git_status + auto-refresh quickfix on a timer
    local watch_timer = nil
    vim.api.nvim_create_user_command('ClaudeWatch', function(opts)
      local base = opts.args ~= "" and opts.args or nil
      if base then
        require('gitsigns').change_base(base, true)
      end

      -- Open neo-tree git_status sidebar
      vim.cmd("Neotree git_status")

      -- Initial population
      refresh_changes(base)

      -- Stop any existing timer
      if watch_timer then
        watch_timer:stop()
        watch_timer:close()
      end

      -- Refresh every 5 seconds
      watch_timer = vim.uv.new_timer()
      watch_timer:start(5000, 5000, vim.schedule_wrap(function()
        vim.cmd("checktime")
        refresh_changes(base)
      end))

      vim.notify("Watching for changes (5s interval)", vim.log.levels.INFO)
    end, { nargs = "?", desc = "Watch for changes: neo-tree + auto-refresh quickfix" })

    -- ClaudeUnwatch: stop the timer
    vim.api.nvim_create_user_command('ClaudeUnwatch', function()
      if watch_timer then
        watch_timer:stop()
        watch_timer:close()
        watch_timer = nil
        vim.notify("Stopped watching", vim.log.levels.INFO)
      end
    end, {})
  '';

  # Global CLAUDE.md (personal preferences and policies applied to all sessions)
  home.file.".claude/CLAUDE.md" = {
    source = ./claude-global.md;
    force = true;
  };

  # Claude Code rules (always-on instructions loaded automatically)
  home.file.".claude/rules/tooling.md".source = ./claude-rules/tooling.md;

  # Claude Code slash commands (skills stored in separate files for easier editing)
  home.file.".claude/commands/whatsup.md".source = ./claude-skills/whatsup.md;
  home.file.".claude/commands/pr-time.md".source = ./claude-skills/pr-time.md;
  home.file.".claude/commands/address-pr-review.md".source = ./claude-skills/address-pr-review.md;
  home.file.".claude/commands/review-pr.md".source = ./claude-skills/review-pr.md;
  home.file.".claude/commands/eod.md".source = ./claude-skills/eod.md;
}
