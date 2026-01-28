{
  config,
  lib,
  pkgs,
  ...
}: let
  # Fallback LSP servers - used when not in a devShell with project-specific LSPs
  # These are wrapped with --suffix so devShell LSPs take priority
  fallbackLsps = with pkgs; [
    nixd # Nix
    gopls # Go
    # sourcekit-lsp comes from Xcode on macOS, no need for fallback
  ];

  # Wrap claude-code with fallback LSPs in PATH (suffix = lower priority than devShell)
  claude-code-wrapped = pkgs.symlinkJoin {
    name = "claude-code-wrapped";
    paths = [pkgs.claude-code];
    buildInputs = [pkgs.makeWrapper];
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
in {
  # Claude Code package with LSP fallbacks
  home.packages = [
    claude-code-wrapped
  ];

  # Ignore SWT (Simple Work Tracker) directories globally
  # SWT is a task tracker designed for AI agents that creates .swt/ dirs
  programs.git.ignores = [".swt"];

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
        "nix-lsp" = true; # Custom plugin defined below
      } // lib.optionalAttrs pkgs.stdenv.isDarwin {
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
            ];
          }
        ];
      };
    };
    force = true;
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

  # Claude Code slash commands
  home.file.".claude/commands/whatsup.md" = {
    text = ''
      # Morning Context Rebuild

      You are helping me rebuild context after being away from my computer.

      ## Environment Context
      - I use ghq/gwq for git repo organization
      - **Main repos**: ~/src/github.com/<owner>/<repo> (e.g. ~/src/github.com/mirendev/runtime)
      - **Worktrees**: ~/worktrees/github.com/<owner>/<repo>/<branch> for feature branches (e.g. ~/worktrees/github.com/mirendev/runtime/saga-genesis)
      - Tmux session names show "github-com" but filesystem uses "github.com"
      - Worktree sessions indicate active feature branch work - these are often the most relevant context
      - Atuin tracks shell history with timestamps
      - Claude Code sessions are stored in ~/.claude/projects/

      ## Work vs Personal
      - **Work**: anything in the `mirendev` org (in ~/src/ or ~/worktrees/)
      - **Personal**: everything else (phinze, chicago-tool-library, etc.)
      - Focus ~80% on work context, mention personal only briefly if recently active

      ## Your Task
      Analyze my active work context and give me a concise summary of what I was working on. This is a ONE-SHOT summary - do not ask follow-up questions or prompt for what to do next.

      ## Commands to Run
      1. **Tmux sessions**: `tmux list-sessions -F '#{session_name} (#{session_windows} windows, #{?session_attached,attached,detached}) - last activity: #{t:session_activity}'`
      2. **Recent shell history**: `atuin history list --format '{time} | {command}' | tail -50`
      3. **Recent Claude sessions**: `find ~/.claude/projects -name 'sessions-index.json' -exec cat {} \; 2>/dev/null | jq -s '[.[].entries[]] | sort_by(.modified) | reverse | .[:15] | .[] | "\(.modified) | \(.projectPath | split("/")[-1]) | \(.firstPrompt | .[0:80])..."' -r`
      4. **Git status in active repos**: For 2-3 most recently active tmux sessions, check git status (remember: "github-com" in session name = "github.com" on disk)

      ## Output Format
      Give me a concise morning-briefing style summary (no emojis):

      ### Work (mirendev)
      1. **Active Sessions**: Which mirendev repos have tmux sessions open
      2. **Recent Activity**: What work tasks was I doing based on shell history
      3. **Claude Conversations**: Recent Claude sessions in mirendev repos
      4. **Uncommitted Work**: Any mirendev repos with uncommitted changes
      5. **Suggested Starting Points**: 2-3 work items to pick up

      ### Personal (brief)
      - One-liner on any recently active personal projects (if any)

      End with the summary - do not ask questions or prompt for next steps.
    '';
  };

  home.file.".claude/commands/pr-time.md" = {
    text = ''
      # Ship a PR

      Let's get this work shipped! Create a commit and PR for the current changes.

      ## Style Guide
      - **Concise, informal, casual, narrative** - like explaining to a coworker
      - No need to restate the diff in detail
      - No test plan section
      - Focus on the "why" and the story, not the "what"

      ## Steps

      1. **Check the state**: Run `git status` and `git diff` to see what we're working with

      2. **Draft the commit message**:
         - First line: short summary (imperative mood)
         - Body: brief narrative of what was wrong and how we fixed it

      3. **Draft the PR**:
         - **Title**: Same as commit first line (or slightly more descriptive)
         - **Description**: Casual narrative - what happened, why it was a problem, what we did about it

      4. **Show me the draft** and ask "Look good?" - wait for approval before proceeding

      5. **After approval**: Commit, push, and create the PR with `gh pr create`

      ## Example Output Format

      ```
      Commit message:
      Fix the thing that was broken

      Found that X was causing Y. Fixed by doing Z instead.

      PR title:
      Fix the thing that was broken

      PR description:
      Noticed this morning that X wasn't working right. Turns out Y was
      happening because of Z. Switched to A approach which handles this
      better.

      Look good?
      ```
    '';
  };

  home.file.".claude/commands/review-pr.md" = {
    text = ''
      # PR Review Skill

      Review pull request: $ARGUMENTS

      Think hard and carefully about the code changes.

      ## Instructions

      0. **If no PR specified** (empty $ARGUMENTS):
         - Run `gh pr list` to show open PRs
         - Ask which one I'd like to review
         - Continue with the selected PR number

      1. **Fetch PR metadata and diff**:
         - Run `gh pr view $ARGUMENTS --json number,title,body,author,baseRefName,headRefName,url`
         - Run `gh pr diff $ARGUMENTS`

      2. **Summarize the PR**:
         - What is this PR trying to accomplish?
         - Who authored it?
         - What's the scope (files changed, rough size)?

      3. **Walk through the changes**:
         - Group changes logically (by feature, by file, or by layer)
         - Explain what each change does
         - **Flag areas of concern**: complexity, edge cases, security issues, missing tests, unclear intent, potential bugs

      4. **Pause for discussion**:
         - Ask if I have questions or want to dive deeper into any area
         - We'll discuss before drafting comments

      5. **Draft PR comments**:
         - When I'm ready, draft individual comments in raw markdown
         - Use fenced code blocks so the markdown is visible (not rendered)
         - Format each comment like:

      ~~~markdown
      **File**: `path/to/file.ts` (lines 42-45)

      Your comment text here...
      ~~~

      **Tone**: Concise, informal, and friendly. Use "we" pronouns in the spirit of collective code ownership (e.g., "we might want to handle..." not "you should...").

      Focus on:
      - Questions that clarify intent
      - Potential issues or edge cases
      - Suggestions for improvement (not nitpicks)
    '';
  };
}
