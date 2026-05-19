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
in
{
  # Add the wrapped antigravity-cli to packages
  home.packages = [
    antigravity-cli-wrapped
  ];

  # Antigravity CLI declarative settings
  home.file.".gemini/antigravity-cli/settings.json" = {
    text = builtins.toJSON {
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
    force = true;
  };

  # Define custom personal-setup Claude plugin bundling all your personal skills and commands
  home.file.".claude/plugins/personal-setup/.claude-plugin/plugin.json" = {
    text = builtins.toJSON {
      name = "personal-setup";
      version = "1.0.0";
      description = "Paul's personal custom skills and commands";
    };
  };

  # Skills
  home.file.".claude/plugins/personal-setup/skills/tuicr/SKILL.md".source = "${inputs.tuicr}/skills/tuicr/SKILL.md";
  home.file.".claude/plugins/personal-setup/skills/tuicr/tuicr-wrapper.sh".source = "${inputs.tuicr}/skills/tuicr/tuicr-wrapper.sh";

  home.file.".claude/plugins/personal-setup/skills/jj/SKILL.md".source = ./claude-skills/jj/SKILL.md;

  home.file.".claude/plugins/personal-setup/skills/clipboard/SKILL.md".source = ./claude-skills/clipboard/SKILL.md;

  home.file.".claude/plugins/personal-setup/skills/session-history/SKILL.md".source = ./claude-skills/session-history/SKILL.md;
  home.file.".claude/plugins/personal-setup/skills/session-history/claude-sessions.sh" = {
    source = ./claude-skills/session-history/claude-sessions.sh;
    executable = true;
  };

  # Commands (converted to skills automatically by agy plugin import)
  home.file.".claude/plugins/personal-setup/commands/whatsup-home.md".source = ./claude-skills/whatsup-home.md;
  home.file.".claude/plugins/personal-setup/commands/whatsup-work.md".source = ./claude-skills/whatsup-work.md;
  home.file.".claude/plugins/personal-setup/commands/pr-time.md".source = ./claude-skills/pr-time.md;
  home.file.".claude/plugins/personal-setup/commands/address-pr-review.md".source = ./claude-skills/address-pr-review.md;
  home.file.".claude/plugins/personal-setup/commands/review-pr.md".source = ./claude-skills/review-pr.md;

  # Activation script to automatically run 'agy plugin import' for all required plugins
  home.activation.antigravityImportPlugins = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    # Wait for Claude plugin files to be written first, then run agy plugin import
    # This automatically syncs all your personal setups, mpc-servers, skills and custom commands into agy
    $DRY_RUN_CMD ${antigravity-cli-wrapped}/bin/agy plugin import ~/.claude/plugins/personal-setup
    $DRY_RUN_CMD ${antigravity-cli-wrapped}/bin/agy plugin import ~/.claude/plugins/nix-lsp
    $DRY_RUN_CMD ${antigravity-cli-wrapped}/bin/agy plugin import ~/.claude/plugins/miren
    $DRY_RUN_CMD ${antigravity-cli-wrapped}/bin/agy plugin import ~/.claude/plugins/coderabbit
  '';
}
