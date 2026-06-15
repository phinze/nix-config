# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  config,
  osConfig,
  pkgs,
  lib,
  nodeConfig ? { },
  ...
}:
{
  # You can import other home-manager modules here
  imports = [
    # Allows mistyped commands to suggest packages instead of displaying a
    # command-not-found error
    inputs.nix-index-database.homeModules.nix-index
    # Bankshot for opening files/URLs from remote systems
    inputs.bankshot.homeManagerModules.default
    # Double-agent for resilient SSH agent proxy
    inputs.double-agent.homeManagerModules.default
    # Sophon for Claude Code notification + response relay
    inputs.sophon.homeManagerModules.default
    # Claude Code configuration (package + statusline)
    ./claude-code.nix
    # Antigravity CLI configuration (wrapped package + statusline + plugins)
    ./antigravity-code.nix
    # Karabiner-Elements for keyboard remapping (incl. R400 → Handy)
    ./karabiner.nix
    # Tmux terminal multiplexer
    ./tmux.nix
    # Demo recorder for terminal sessions
    ./modules/demo-recorder.nix
    # Screenshot module for website captures
    ./modules/screenshot.nix
    # Dynamic SSH git signing key selection
    ./modules/git-signing.nix
    # Nushell experiment (launch `nu` to try it)
    ./modules/nushell.nix
    # Nightly cleanup of stale dev sessions and merged branches
    ./modules/dev-cleanup.nix
    # Hourly memex commit+push (gated by nodeConfig.isMemexHost)
    ./modules/memex-autocommit.nix
  ]
  ++ lib.optionals (nodeConfig.isGraphical or false) [
    # Graphical-specific configuration
    ./graphical.nix
  ];

  # SSH signing keys — single source of truth for all nodes
  phinze.git.signing = {
    keys = [
      {
        name = "delevingne";
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKri4aveRRo7osskk6Wg8urqRm1RuAZK0bksJvKiHcKUk55kQoES/aPIr+vC5tVETE+2AHrFmIuZfGf2PHeruwM=";
      }
      {
        name = "foxtrotbase";
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEu+8Why8CmSWV5FHEeIsaAgYTN156U3kpCa/QMxdnaC";
      }
      {
        name = "xiezhi";
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDHP/N4P043PsjSR8rsvpBDAwOy7PEZCMVM1+gs32Nn";
      }
    ];
    emails = [
      "phinze@phinze.com"
      "paul@miren.dev"
    ];
  };

  # Nushell experiment — try `nu` alongside fish
  phinze.nushell.enable = true;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.nixvim
      outputs.overlays.recto
      outputs.overlays.rig

      # Claude Code 2.0 overlay
      inputs.claude-code-nix.overlays.default

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home = {
    username = "phinze";
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/phinze" else "/home/phinze";
  };

  home.shellAliases = {
    # Since we aren't using a home-manager module for neovim, set neovim aliases here
    vi = "nvim";
    vim = "nvim";

    # Claude Code shorthand
    cld = "claude --dangerously-skip-permissions";
    cldr = "claude --dangerously-skip-permissions --resume";

    # Antigravity CLI shorthand
    agy = "agy --dangerously-skip-permissions";
    agyr = "agy --dangerously-skip-permissions --continue";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages =
    with pkgs;
    [
      ccusage # Analyze Claude Code token usage and costs
      coderabbit # AI-powered code review CLI
      delta # Syntax-highlighting pager for git
      ghq # Clone repos into dir structure
      git-trim # Smart cleanup of merged branches with worktree awareness
      google-cloud-sdk # I want to run gcloud from anywhere
      inputs.multipass.packages.${pkgs.system}.default # GCP Workload Identity Federation auth CLI
      gwq # Git worktree manager that works with ghq
      hunkdiff # Review-first terminal diff viewer for agentic coders
      ilmari # tmux popup radar for agent panes (Codex, Claude Code, etc.)
      lumen # Visual git diff viewer in the terminal
      recto # jj-first terminal diff viewer for reviewing agent-authored changes
      rig # workspace tool for task-shaped multi-repo work (subsumes jpickup/jreview)
      unstable.jujutsu # jj VCS, trying it out alongside git
      unstable.jjui # TUI frontend for jj
      jq
      linearis # CLI tool for Linear.app with JSON output
      mtr
      nh # Nix helper for more convenient nix commands
      nixvim # My configured copy of neovim
      opencode # AI coding agent for the terminal, multi-provider
      unstable.fabric-ai # AI framework for augmenting humans
      unstable.deno # JS runtime required by yt-dlp for YouTube signature solving
      unstable.mpv # Media player for YouTube DJ sets and streams
      unstable.yt-dlp # Video downloader, used by mpv and fabric
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # Docker CLI tools for macOS with Colima
      docker-client
      docker-compose
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      osc-copy # Provides pbcopy/xclip/xsel via OSC 52 for clipboard access through SSH/tmux
    ]
    # Private packages that require gh authentication
    # Note: Include by default; bootstrap users can set SKIP_PRIVATE_PACKAGES=1
    ++ lib.optionals ((builtins.getEnv "SKIP_PRIVATE_PACKAGES") != "1") [
      inputs.iso.packages.${pkgs.system}.default # Isolated Docker environment
    ]
    ++ (nodeConfig.extraPackages or [ ]);

  programs.atuin = {
    enable = true;
    package = inputs.atuin.packages.${pkgs.system}.atuin;
    settings = {
      # Nix will handle updates tyvm
      update_check = false;

      # Scope ctrl-r history search to current git repo by default.
      # Worktrees of the same repo share a scope, so ephemeral
      # worktrees don't lose history.
      workspaces = true;
      filter_mode = "workspace";

      # Don't intersperse global history when just pressing up arrow
      filter_mode_shell_up_key_binding = "session";

      # Silently drop commands containing secrets from history
      history_filter = [
        "_API_KEY="
        "_SECRET="
        "_TOKEN="
        "_PASSWORD="
      ];

      # New default in recent versions, enter to run, tab to complete
      enter_accept = true;

      # Enable sync v2 which is the new default
      sync = {
        records = true;
      };

      # Suggestions from default config to make stats more interesting
      stats = {
        common_subcommands = [
          "docker"
          "git"
          "go"
          "nix"
          "systemctl"
          "tmux"
        ];
        ignored_commands = [
          "cd"
          "ls"
          "vi"
          "vim"
        ];
      };
    };
  };

  programs.bat.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;

    # Loaded before every .envrc. When the cwd is under a jj workspace,
    # auto-export GH_REPO so gh works without git context (a non-default jj
    # workspace has no .git). Two layouts are supported during the rig
    # transition:
    #   - rig (flat): ~/workspaces/<slug>/<repo>/...  → owner/repo read out of
    #     the rig's .rig.toml [repos] table (the flat path can't encode it).
    #   - legacy:     ~/workspaces/<host>/<owner>/<repo>/...  → parsed from path.
    # Loaded before every .envrc. All workspace-layout and manifest knowledge
    # lives in rig itself: `rig env` prints export lines for the cwd (rig
    # identity, GH_REPO, including the legacy ~/workspaces/<host>/<owner>/
    # <repo> path-parse) and prints nothing outside a workspace. This has to
    # happen in the stdlib rather than rig-written .envrc files: direnv loads
    # only the nearest .envrc (no cascade), so a repo shipping its own .envrc
    # (nix devshells) would shadow anything the basedir exports.
    stdlib = ''
      has rig && eval "$(rig env 2>/dev/null)"
    '';

    # Auto-allow direnv for trusted organizations (repos and worktrees)
    config = {
      whitelist = {
        prefix = [
          # Main repository directories
          "${config.home.homeDirectory}/src/github.com/phinze"
          "${config.home.homeDirectory}/src/github.com/mirendev"
          # Worktree directories managed by gwq
          "${config.home.homeDirectory}/worktrees/github.com/phinze"
          "${config.home.homeDirectory}/worktrees/github.com/mirendev"
          # jj workspaces: rig's flat ~/workspaces/<slug>/ shape plus the
          # legacy ~/workspaces/<host>/<owner>/<repo>/ from jpickup/jreview.
          "${config.home.homeDirectory}/workspaces"
        ];
      };
    };
  };

  programs.fish = {
    enable = true;

    plugins = with pkgs.fishPlugins; [
      {
        name = "async-prompt";
        src = async-prompt.src;
      }
      {
        name = "pure";
        src = pure.src;
      }
      {
        name = "foreign-env";
        src = foreign-env.src;
      }
      {
        name = "fzf-fish";
        src = fzf-fish.src;
      }
    ];

    functions = {
      # Override the default greeting function with an empty body to silence
      # the welcome message. Survives fish upgrades that reset universal vars
      # (e.g. the fish 4.x rewrite), since it ships as a config-managed file.
      fish_greeting = "";

      ghq = {
        description = "wraps ghq utility to provide 'look' subcommand which cds to repo";
        body = ''
          if test "$argv[1]" = "look" -a -n "$argv[2]"
              cd (command ghq list -e -p $argv[2])
              return
          end

            command ghq $argv
        '';
      };

      wt = {
        description = "Worktree management: fuzzy find, switch, or create";
        body = ''
          if test (count $argv) -eq 0
              # No args: fuzzy find existing worktrees
              set -l worktree (gwq list --json | jq -r '.[] | .path' | fzf --height=40% --reverse)
              if test -n "$worktree"
                  t $worktree
              end
          else
              # Arg provided: check if worktree exists
              set -l branch_name $argv[1]
              set -l worktree_path (gwq get $branch_name 2>/dev/null)

              if test -n "$worktree_path"
                  # Worktree exists, switch to it
                  t $worktree_path
              else
                  # Worktree doesn't exist, create it
                  # Check if branch exists locally or remotely
                  if git show-ref --verify --quiet refs/heads/$branch_name; or git ls-remote --heads origin $branch_name | grep -q .
                      # Branch exists, use gwq add without -b
                      gwq add $branch_name
                  else
                      # Branch doesn't exist, create new with -b
                      gwq add -b $branch_name
                  end

                  if test $status -eq 0
                      set -l new_worktree_path (gwq get $branch_name)
                      t $new_worktree_path
                  else
                      echo "Failed to create worktree"
                      return 1
                  end
              end
          end
        '';
      };

      wtc = {
        description = "Create worktree: interactive or with specified branch";
        body = ''
          if test (count $argv) -eq 0
              # No args: interactive mode
              gwq add -i
          else
              # Arg provided: create worktree
              set -l branch_name $argv[1]

              # Check if branch exists locally or remotely
              if git show-ref --verify --quiet refs/heads/$branch_name; or git ls-remote --heads origin $branch_name | grep -q .
                  # Branch exists, use gwq add without -b
                  gwq add $branch_name
              else
                  # Branch doesn't exist, create new with -b
                  gwq add -b $branch_name
              end

              if test $status -eq 0
                  set -l worktree_path (gwq get $branch_name)
                  t $worktree_path
              else
                  echo "Failed to create worktree"
                  return 1
              end
          end
        '';
      };

      link-in = {
        description = "Link a ghq repo into ./tmp/ for LLM context";
        body = ''
          set -l ghq_root (ghq root)

          if test (count $argv) -eq 0
              # No args: fuzzy find from ghq list
              set -l selection (ghq list | fzf --height=40% --reverse --prompt="Link repo: ")
              if test -z "$selection"
                  return 0
              end
              set repo_path "$ghq_root/$selection"
              set repo_name (basename $selection)
          else
              set -l relative_path $argv[1]
              set repo_name (basename $relative_path)

              # If no slash in arg, try to infer org from current directory
              if not string match -q '*/*' $relative_path
                  # Extract org from cwd - works for both ~/src/github.com/ORG/... and ~/worktrees/github.com/ORG/...
                  set -l current_org (pwd | string match -r 'github\.com/([^/]+)' | tail -n1)

                  if test -n "$current_org"
                      # Try org/repo first
                      set -l org_repo_path "$ghq_root/github.com/$current_org/$relative_path"
                      if test -d "$org_repo_path"
                          set repo_path "$org_repo_path"
                      end
                  end
              end

              # Fall back to treating arg as full path relative to github.com
              if not set -q repo_path
                  set repo_path "$ghq_root/github.com/$relative_path"
              end

              if not test -d "$repo_path"
                  echo "Repository not found: $repo_path"
                  return 1
              end
          end

          mkdir -p tmp/
          ln -sfn (realpath $repo_path) "./tmp/$repo_name"
          echo "Linked $repo_name -> $repo_path"
        '';
      };

      pickup = {
        description = "Pick up a Linear issue: create worktree, tmux session, and start Claude";
        body = ''
          # Step 1: Resolve issue identifier
          set -l identifier

          if test (count $argv) -eq 0
              # No args: list recent issues via fzf
              set -l selection (linearis issues list --limit 25 2>/dev/null | jq -r '.[] | "\(.identifier)\t\(.state.name)\t\(.title)"' | fzf --height=40% --reverse --with-nth=1,2,3 --delimiter='\t' --prompt="Pick issue: ")
              if test -z "$selection"
                  return 0
              end
              set identifier (echo "$selection" | cut -f1)
          else if string match -qr '^[A-Z]+-[0-9]+$' $argv[1]
              # Direct issue identifier (e.g. MIR-664)
              set identifier $argv[1]
          else
              # Search query
              set -l selection (linearis issues search "$argv" 2>/dev/null | jq -r '.[] | "\(.identifier)\t\(.state.name)\t\(.title)"' | fzf --height=40% --reverse --with-nth=1,2,3 --delimiter='\t' --prompt="Pick issue: ")
              if test -z "$selection"
                  return 0
              end
              set identifier (echo "$selection" | cut -f1)
          end

          # Step 2: Get branch name from Linear
          set -l branch_name (linearis issues read $identifier 2>/dev/null | jq -r '.branchName // empty')
          if test -z "$branch_name"
              echo "No branch name found for $identifier"
              return 1
          end

          # Step 3: Create or find worktree
          set -l worktree_path (gwq get $branch_name 2>/dev/null)

          if test -z "$worktree_path"
              # Worktree doesn't exist, create it
              git fetch origin main --quiet 2>/dev/null
              if git show-ref --verify --quiet refs/heads/$branch_name 2>/dev/null; or git ls-remote --heads origin $branch_name 2>/dev/null | grep -q .
                  gwq add $branch_name 2>/dev/null
              else
                  git branch $branch_name origin/main 2>/dev/null
                  gwq add $branch_name 2>/dev/null
              end

              if test $status -ne 0
                  echo "Failed to create worktree for $branch_name"
                  return 1
              end

              set worktree_path (gwq get $branch_name 2>/dev/null)
          end

          # Step 4: Compute tmux session name (matches session-wizard --full-path)
          set -l session_name (string replace "$HOME" "~" "$worktree_path")
          set session_name (string replace -a " " "-" $session_name)
          set session_name (string replace -a "." "-" $session_name)
          set session_name (string replace -a ":" "-" $session_name)
          set session_name (string lower $session_name)

          # Step 5: Create tmux session if it doesn't exist
          set -l is_new_session 0
          if not tmux has-session -t "$session_name" 2>/dev/null
              tmux new-session -d -s "$session_name" -c "$worktree_path"
              set is_new_session 1
          end

          # Step 6: For new sessions, create split layout and launch Claude
          if test $is_new_session -eq 1
              # Split: lumen diff on the right (auto-refresh on file changes), Claude on the left
              tmux split-window -h -t "$session_name" -c "$worktree_path" \
                  "lumen diff -w --theme catppuccin-mocha"
              tmux select-pane -t "$session_name:0.0"

              tmux send-keys -t "$session_name:0.0" "claude --dangerously-skip-permissions 'Picking up $identifier — use the Linear MCP (it may take a few seconds to connect) to read the issue, mark it In Progress and assigned to me, then help me plan.'" Enter
          end

          # Step 7: Switch to session
          if test -n "$TMUX"
              tmux switch-client -t "$session_name"
          else
              tmux attach -t "$session_name"
          end
        '';
      };

      review = {
        description = "Review a GitHub PR: create worktree, tmux session, and start Claude";
        body = builtins.readFile ./fish-functions/review.fish;
      };

      # TODO(rig-transition, added 2026-06-05): the `rig` package now covers
      # both of these (rig up / rig review). Keeping them as a fallback for a
      # short shakedown period; remove jpickup/jreview (and their .fish files)
      # once rig has proven out in daily use.
      jpickup = {
        description = "Pick up a Linear issue with jj: create workspace, tmux session, and start Claude";
        body = builtins.readFile ./fish-functions/jpickup.fish;
      };

      jreview = {
        description = "Review a GitHub PR with jj: create workspace, tmux session, and start Claude";
        body = builtins.readFile ./fish-functions/jreview.fish;
      };

      fish_jj_prompt = {
        description = "Print jj prompt segment: closest-bookmark, change_id, * for undescribed, description, state markers";
        body = ''
          if not command -sq jj
              return 1
          end
          if not jj root --quiet >/dev/null 2>&1
              return 1
          end

          # Find the bookmark to show: closest non-trunk ancestor first
          # (so feature branches surface), falling back to include trunk
          # so we still see "main" when sitting on it directly. Matches
          # the logic in the `jj tug` alias.
          set -l bookmark_name (jj log --ignore-working-copy --no-graph --color never \
              -r 'latest(heads(::@ & bookmarks()) ~ trunk(), 1)' \
              -T 'bookmarks.join(",")' 2>/dev/null)
          if test -z "$bookmark_name"
              set bookmark_name (jj log --ignore-working-copy --no-graph --color never \
                  -r 'latest(heads(::@ & bookmarks()), 1)' \
                  -T 'bookmarks.join(",")' 2>/dev/null)
          end

          # Render the rest of @'s info
          set -l rest (jj log --ignore-working-copy --no-graph --color never -r @ -T '
            separate(" ",
              change_id.shortest(),
              if(empty, "", if(description.first_line(), "", "*")),
              if(description.first_line(),
                surround("\"", "\"",
                  if(description.first_line().substr(0, 24).starts_with(description.first_line()),
                    description.first_line().substr(0, 24),
                    description.first_line().substr(0, 23) ++ "…"))),
              if(conflict, "(conflict)"),
              if(divergent, "(divergent)"),
              if(hidden, "(hidden)"))
          ')

          if test -n "$bookmark_name"
              printf '%s %s\n' "$bookmark_name" "$rest"
          else
              echo $rest
          end
        '';
      };

      _pure_prompt_git = {
        description = "Override pure's git segment: render jj info in jj repos, git otherwise";
        body = ''
          set ABORT_FEATURE 2

          if set --query pure_enable_git; and test "$pure_enable_git" != true
              return
          end

          # jj-first: render fish_jj_prompt when in a jj repo (workspaces
          # and colocated), tinted with pure's branch color for consistency.
          if command -sq jj; and jj root --quiet >/dev/null 2>&1
              set --local jj_info (fish_jj_prompt)
              set --local color (_pure_set_color $pure_color_git_branch)
              echo "$color$jj_info"
              return
          end

          # Pure's original git rendering. Re-sync if upstream pure changes
          # _pure_prompt_git's segment composition.
          if not type -q --no-functions git
              return $ABORT_FEATURE
          end

          set --local is_git_repository (command git rev-parse --is-inside-work-tree 2>/dev/null)

          if test -n "$is_git_repository"
              set --local git_prompt (_pure_prompt_git_branch)(_pure_prompt_git_dirty)(_pure_prompt_git_stash)
              set --local git_pending_commits (_pure_prompt_git_pending_commits)

              if test (_pure_string_width $git_pending_commits) -ne 0
                  set --append git_prompt $git_pending_commits
              end

              echo $git_prompt
          end
        '';
      };
    }
    // lib.optionalAttrs (osConfig.networking.hostName == "foxtrotbase") {
      df = {
        description = "df that skips fuse.sshfs to avoid hangs when the laptop is asleep";
        body = ''
          echo "fyi skipping sshfs" >&2
          command df -x fuse.sshfs $argv
        '';
      };
    };

    interactiveShellInit = lib.concatLines [
      # nix version of https://github.com/27medkamal/tmux-session-wizard?tab=readme-ov-file#optional-using-the-script-outside-of-tmux
      "fish_add_path ${pkgs.tmuxPlugins.session-wizard}/share/tmux-plugins/session-wizard/bin"

      # any-nix-shell helps fish stick around in nix subshells
      "${pkgs.any-nix-shell}/bin/any-nix-shell fish | source"

      # gwq shell completion
      "gwq completion fish | source"

      # Add ~/bin to PATH if it exists
      "fish_add_path ~/bin"

      # Pure prompt settings
      "set -g pure_shorten_window_title_current_directory_length 1"
      "set -g pure_truncate_window_title_current_directory_keeps 2"
    ];
  }
  // lib.optionalAttrs (pkgs.stdenv.isDarwin) {
    loginShellInit =
      let
        # This naive quoting is good enough in this case. There shouldn't be any
        # double quotes in the input string, and it needs to be double quoted in case
        # it contains a space (which is unlikely!)
        dquote = str: "\"" + str + "\"";

        makeBinPathList = map (path: path + "/bin");
      in
      ''
        fish_add_path --move --prepend --path ${
          lib.concatMapStringsSep " " dquote (makeBinPathList osConfig.environment.profiles)
        }
        set fish_user_paths $fish_user_paths
      '';
  };

  programs.fd.enable = true;

  programs.fzf = {
    enable = true;
    enableFishIntegration = false;
  };

  programs.gpg.enable = true;

  programs.home-manager.enable = true;

  programs.htop = {
    enable = true;
    settings = {
      hide_kernel_threads = true;
      hide_userland_threads = true;
    };
  };

  programs.git = {
    enable = true;
    signing.signByDefault = true;
    ignores = [
      ".direnv"
      ".antigravitycli/"
    ];
    includes = [
      {
        condition = "gitdir:~/src/github.com/mirendev/";
        contents = {
          user = {
            email = "paul@miren.dev";
          };
        };
      }
    ];
    settings = {
      user.name = "Paul Hinze";
      user.email = "phinze@phinze.com";
      alias = {
        co = "checkout";
        st = "status";
        trim = "!git-trim";
        wt = "!gwq";
        wtl = "!gwq list --json | jq -r '.[] | \"\\(.branch) (\\(.path))\"'";
        wtc = "!gwq create";
        wtd = "!gwq delete";
        wts = "!gwq switch";
      };
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        dark = true;
        hyperlinks = true;
        true-color = "always";
        syntax-theme = "Dracula";
        minus-style = "syntax #3b1d2b";
        minus-emph-style = "syntax #5c2a3f";
        plus-style = "syntax #1d3b2b";
        plus-emph-style = "syntax #2a5c3f";
        # Make filenames stand out
        file-style = "bold yellow";
        file-decoration-style = "yellow ul ol";
      };
      credential.helper = "!gh auth git-credential";
      github.user = "phinze";
      push.default = "current";
      init.defaultBranch = "main";
      safe.directory = "${config.home.homeDirectory}/src/github.com/phinze/nixos-config";
      push.autoSetupRemote = true;
      ghq.root = "~/src";
      fetch.prune = true;
    }
    // ((nodeConfig.git or { }).extraConfig or { });
  };

  programs.gh = {
    enable = true;
    package = pkgs.unstable.gh;
    settings = {
      aliases = {
        cl = "repo clone";
        pl = "pr list";
        co = "pr checkout";
      };
    };
    extensions = [
      pkgs.gh-poi
    ];
  };

  # Allows quick one-off installation & usage of commands with `, <cmd>`
  programs.nix-index-database.comma.enable = true;

  programs.ripgrep.enable = true;

  programs.zoxide.enable = true;

  # Finicky configuration for URL routing (macOS only)
  home.file.".finicky.ts" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ./finicky.ts;
  };

  programs.ssh = {
    enable = true;

    # Opt out of home-manager's legacy `Host *` defaults and declare the ones
    # we actually want under settings."*" ourselves. Keeping enableDefaultConfig
    # on emits a deprecation warning; this is the upstream-recommended migration.
    enableDefaultConfig = false;

    settings = {
      "*" = {
        # The defaults home-manager used to inject via enableDefaultConfig.
        # Left as mkDefault so other modules can still override per-host.
        ForwardAgent = lib.mkDefault false;
        AddKeysToAgent = lib.mkDefault "no";
        Compression = lib.mkDefault false;
        ServerAliveInterval = lib.mkDefault 0;
        ServerAliveCountMax = lib.mkDefault 3;
        HashKnownHosts = lib.mkDefault false;
        UserKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
        ControlMaster = lib.mkDefault "no";
        ControlPath = lib.mkDefault "~/.ssh/master-%r@%n:%p";
        ControlPersist = lib.mkDefault "no";
      }
      // lib.optionalAttrs (pkgs.stdenv.isDarwin || (nodeConfig.isGraphical or false)) {
        ControlMaster = "auto";
        ControlPath = "/tmp/ssh_mux_%h_%p_%r";
        ControlPersist = "10m";
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      }
      // lib.optionalAttrs (pkgs.stdenv.isLinux && (nodeConfig.isGraphical or false)) {
        IdentityAgent = "\"~/.1password/agent.sock\"";
      };

      "foxtrotbase" = {
        ForwardAgent = true;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        RemoteForward = [
          {
            bind.address = "/home/phinze/.bankshot.sock";
            host.address = "/Users/phinze/.bankshot.sock";
          }
        ];
      };

      "pixiu" = {
        User = "root";
      };
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # Only set up RemoteCommand for interactive sessions (no CLI command).
      # The `command ""` predicate means `ssh foxtrotbase 'cmd'` still works
      # normally. The attribute name is used verbatim as the block header
      # because it starts with `Match `.
      "Match host foxtrotbase command \"\"" = {
        # Suppress focus-event noise during SSH connection:
        # 1. stty -echo: prevent echoing of focus events already in flight
        # 2. printf '\e[?1004l': tell terminal to stop sending focus events
        # The login shell (exec $SHELL) restores terminal settings.
        RemoteCommand = "stty -echo 2>/dev/null; printf '\\e[?1004l'; bankshot monitor reconcile >/dev/null 2>&1 || true; exec \$SHELL -l";
        RequestTTY = "yes";
      };
    };
  };

  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    pinentry.package = pkgs.pinentry-tty;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  xdg.configFile."aerospace/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ./aerospace.toml;
  };

  xdg.configFile."jj/config.toml".source = ./jj-config.toml;
  xdg.configFile."jjui/config.toml".source = ./jjui-config.toml;

  xdg.configFile."gwq/config.toml".text = ''
    # Base directory for worktrees
    worktree_base = "${config.home.homeDirectory}/worktrees"

    # Template for worktree directory names
    # Available variables: {{.Owner}}, {{.Repo}}, {{.Host}}, {{.BranchName}}
    naming_template = "{{.Host}}/{{.Owner}}/{{.Repo}}/{{.BranchName}}"

    # Enable tmux integration to automatically create sessions
    enable_tmux = true

    # Template for tmux session names when creating worktrees
    # Available variables: {{.Owner}}, {{.Repo}}, {{.Host}}, {{.BranchName}}
    tmux_session_name_template = "{{.Repo}}/{{.BranchName}}"

    # Automatically switch to tmux session after creating worktree
    tmux_switch_session = true
  '';

  programs.bankshot = {
    enable = true;
    enableXdgOpen = true;

    # Enable the bankshot monitor
    daemon = {
      enable = true;
      autoStart = true;
      logLevel = "info";
      # Use capability-wrapped binary for eBPF port monitoring on NixOS
      executablePath = lib.mkIf pkgs.stdenv.isLinux "/run/wrappers/bin/bankshot";
    };

    # Monitor configuration (applies to bankshot monitor on remote servers)
    # Default: forward all non-privileged ports (>= 1024)
    monitor = {
      pollInterval = "1s";
      gracePeriod = "30s";
      ignoreProcesses = [
        "sshd"
        "systemd"
        "ssh-agent"
        "miren"
        "agy"
        "agy-wrapped"
        ".agy-wrapped"
        "etcd"
        "victoria"
        "containerd"
        "postgres"
        "/\\.test$/"
        "/^chromedp-runner/"
      ];
    };
  };

  services.sophon = {
    enable = true;
    nodeName = osConfig.networking.hostName;
    daemonUrl = "https://sophon.inze.ph";
    agent.enable = true;
    agent.advertiseUrl = "http://${osConfig.networking.hostName}.swallow-galaxy.ts.net:2588";
  };

  services.double-agent = {
    enable = true;
    socketPath = "${config.home.homeDirectory}/.ssh/agent.sock";
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkIf pkgs.stdenv.isLinux "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
