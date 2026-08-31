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
let
  # First port above Linux's default ephemeral range (32768-60999).
  bankshotBridgePort = 61000;
in
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
    # Stable profile-based paths for agent hook commands
    ./modules/agent-hook-paths.nix
    # Claude Code configuration (package + statusline)
    ./claude-code.nix
    # Antigravity CLI configuration (wrapped package + statusline + plugins)
    ./antigravity-code.nix
    # Codex CLI configuration (package + config.toml + AGENTS.md + prompts)
    ./codex.nix
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
    # Hourly main reconciliation + input bumps (gated by nodeConfig.isNixConfigSyncHost)
    ./modules/nix-config-sync.nix
    # Ghostty + cmux terminal theming on macOS (reads ~/.config/ghostty/config)
    ./ghostty.nix
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
      outputs.overlays.small-packages
      outputs.overlays.nixvim
      outputs.overlays.recto
      outputs.overlays.rig
      outputs.overlays.pim

      # Claude Code 2.0 overlay
      inputs.claude-code-nix.overlays.default

      # Codex CLI overlay, tracking OpenAI's native binary faster than nixpkgs
      inputs.codex-cli-nix.overlays.default

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

    # `r` is to rigs what `t` is to tmux sessions. session-wizard ships a
    # binary literally named `t` (see the fish_add_path in interactiveShellInit)
    # so its picker is one keystroke from any prompt; radar is the equivalent
    # board for rigs, and deserved the same. Mirrored on the tmux side too:
    # prefix+t opens the session picker, prefix+r opens radar.
    r = "rig radar";

    # Claude Code shorthand
    cld = "claude --dangerously-skip-permissions";
    cldr = "claude --dangerously-skip-permissions --resume";

    # Antigravity CLI shorthand
    agy = "agy --dangerously-skip-permissions";
    agyr = "agy --dangerously-skip-permissions --continue";

    # Codex CLI shorthand. --dangerously-bypass-approvals-and-sandbox is the
    # exact analog of claude's --dangerously-skip-permissions: no sandbox, no
    # approval prompts. Plain `codex` stays sandboxed (see codex.nix).
    cdx = "codex --dangerously-bypass-approvals-and-sandbox";
    cdxr = "codex resume --dangerously-bypass-approvals-and-sandbox";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    # pim resolves its config.json, credentials, and tokens from PIM_DATA_DIR.
    # Point it at the pim-stuff checkout's gitignored .local/ so the globally
    # installed `pim` works from any directory (the secrets live outside the
    # nix store and can't be baked into the package).
    PIM_DATA_DIR = "${config.home.homeDirectory}/src/github.com/phinze/pim-stuff/.local";
    # Which agent `rig up`/`new`/`review` start their picker on. Trying codex
    # as the first thing I reach for; ctrl-o still cycles and --agent still
    # overrides, so this only moves the starting position. Delete the line to
    # go back to claude.
    RIG_AGENT = "codex";
  }
  // lib.optionalAttrs (osConfig.services.belowdeck.enable or false) {
    # The belowdeck darwin module hands the daemon its generated config through
    # BELOWDECK_CONFIG in the launchd plist, and nowhere else. Without the same
    # variable in the shell, `belowdeck status` falls back to
    # ~/.config/belowdeck/config.yaml, finds nothing, and reports every setting
    # as NOT SET while the daemon is running perfectly well off the store path.
    # That false lead cost real debugging time once already.
    BELOWDECK_CONFIG =
      osConfig.launchd.user.agents.belowdeck.serviceConfig.EnvironmentVariables.BELOWDECK_CONFIG;
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # nh calls its elevation program as
    #   env PATH=... HOME= USER=phinze nix build --profile ...
    # and that empty HOME is a bug with teeth. Determinate Nix builds its
    # Sentry cache path by joining HOME with ".cache"; joining onto an empty
    # base yields a *relative* path, so root writes .cache/nix/sentry into
    # whatever directory nh was run from. In a jj workspace that wedges the
    # repo outright, because jj cannot snapshot a tree holding a directory it
    # is not allowed to read.
    #
    # Repair the one assignment on the way past and hand everything else to
    # sudo untouched. /var/root matches what nix-darwin's own activation
    # script exports, so the cache lands where root's cache already is.
    NH_ELEVATION_STRATEGY =
      let
        nh-elevate = pkgs.writeShellScriptBin "nh-elevate" ''
          args=()
          for a in "$@"; do
            case "$a" in
              HOME=) args+=("HOME=/var/root") ;;
              *) args+=("$a") ;;
            esac
          done
          exec /usr/bin/sudo "''${args[@]}"
        '';
      in
      "${nh-elevate}/bin/nh-elevate";
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
      gwq # Git worktree manager that works with ghq
      recto # jj-first terminal diff viewer for reviewing agent-authored changes
      rig # workspace tool for task-shaped multi-repo work (subsumes jpickup/jreview)
      # The jj pair rides the small channel so monthly jj releases land within
      # days instead of waiting on the next manual nixpkgs-unstable bump. jjui
      # comes along because it shells out to jj and parses its output, so the
      # two want to move together when a jj release shifts something.
      small.jujutsu # jj VCS, trying it out alongside git
      small.jjui # TUI frontend for jj
      jq
      linearis # CLI tool for Linear.app with JSON output
      mtr
      nh # Nix helper for more convenient nix commands
      nixvim # My configured copy of neovim
      pim # Personal-information CLI (mail, calendar, drive, docs) — see PIM_DATA_DIR below
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
    # Packages from private repos. These need an authenticated gh for the
    # git+https flake inputs to fetch, which BOOTSTRAP.md makes step one on a
    # fresh machine. There used to be a SKIP_PRIVATE_PACKAGES escape hatch
    # here for the pre-auth case; it never worked, because `pim` (above) and
    # three refs in claude-code.nix pull private inputs unconditionally, so
    # eval died on pim-stuff whether or not the flag was set. Gating those too
    # would just move the rot — the hatch is a code path that runs once every
    # few years and is therefore always broken when you reach for it. Auth
    # first instead; it's one `nix run nixpkgs#gh -- auth login`.
    ++ [
      inputs.multipass.packages.${pkgs.stdenv.hostPlatform.system}.default # GCP Workload Identity Federation auth CLI
      inputs.iso.packages.${pkgs.stdenv.hostPlatform.system}.default # Isolated Docker environment
    ]
    ++ (nodeConfig.extraPackages or [ ]);

  programs.atuin = {
    enable = true;
    package = inputs.atuin.packages.${pkgs.stdenv.hostPlatform.system}.atuin;
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
      _rig_env() {
        has rig && eval "$(rig env 2>/dev/null)"
      }

      _rig_env

      # nix-direnv restores a cached environment after this global stdlib has
      # loaded, which otherwise discards rig's PATH shim and identity exports.
      # Wrap its public entrypoint and reapply the cwd-derived projection once
      # the dev shell is in place.
      if declare -F use_flake >/dev/null; then
        eval "$(declare -f use_flake | sed '1s/^use_flake /_rig_use_flake /')"
        use_flake() {
          local status=0
          _rig_use_flake "$@" || status=$?
          _rig_env
          return "$status"
        }
      fi
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

      # pickup/review are thin wrappers over `rig`, which owns the whole
      # task-shaped workflow now: resolve the issue/PR, drop a jj workspace
      # under ~/workspaces/<slug>/, spawn the tmux + recto + Claude layout, and
      # tear it down later via `rig reap`. The old git-worktree bodies (and the
      # jpickup/jreview jj siblings that bridged the migration) retired
      # 2026-06-26 once rig proved out in daily use. jj supremacy confirmed.
      pickup = {
        description = "Pick up a Linear issue with rig (jj workspace, tmux, Claude)";
        body = "rig up $argv";
      };

      review = {
        description = "Review a GitHub PR with rig (jj workspace, tmux, Claude)";
        body = "rig review $argv";
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

  # Skip building the home-manager manual. It pulls in an options.json doc
  # whose declaration sites embed the raw nixpkgs store path without context
  # (an upstream home-manager/nixpkgs quirk), which prints a build warning.
  # We read HM docs on the web anyway, so drop the man pages and the warning.
  manual.manpages.enable = false;

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
      safe.directory = "${config.home.homeDirectory}/src/github.com/phinze/nix-config";
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
      pkgs.unstable.gh-stack
    ];
  };

  # Allows quick one-off installation & usage of commands with `, <cmd>`
  programs.nix-index-database.comma.enable = true;

  programs.ripgrep.enable = true;

  programs.zoxide.enable = true;

  # Periodic store GC on the Mac. The NixOS hosts get this from their
  # system-level programs.nh; darwin has no nh module under Determinate Nix,
  # so we run the same janitor here in home-manager. nh just shells out to the
  # nix CLI, which sidesteps Determinate's ownership of the daemon. Without it
  # the store grew unbounded until it hit the APFS 65,535 link-count ceiling,
  # which is what rotted this machine in June 2026 (3-6s shell starts from
  # lstat'ing a 65k-entry store). Weekly `nh clean user`, keeping 3 generations.
  #
  # Note: darwin's launchd agent appends clean.extraArgs as a single argv
  # element, so use clap's --flag=value form (--keep=3, not "--keep 3").
  programs.nh = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep=3";
  };

  # Finicky configuration for URL routing (macOS only)
  home.file.".finicky.ts" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ./finicky.ts;
  };

  # Bounds what a forwarded agent can sign with; 1Password exposes every key
  # we own otherwise.
  xdg.configFile."1Password/ssh/agent.toml" = lib.mkIf pkgs.stdenv.isDarwin {
    text = lib.concatMapStrings (k: ''
      [[ssh-keys]]
      item = "${k.item}"
      vault = "${k.vault}"

    '') inputs.nix-private.data.onePasswordSshItems;
  };

  # macOS sshd reads .ssh/authorized_keys and has no authorized_keys.d, so this
  # is home-manager's job here rather than services.openssh's.
  #
  # A real file, not a home.file symlink: StrictModes walks the resolved path
  # and /nix/store is group-writable, so sshd rejects anything living there.
  home.activation.authorizedKeys = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        keys = pkgs.writeText "authorized_keys" (
          lib.concatMapStrings (k: k + "\n") [
            inputs.nix-private.data.sshKeys.laptop
            inputs.nix-private.data.sshKeys.miren
          ]
        );
      in
      ''
        run install -d -m 700 "$HOME/.ssh"
        run install -m 600 ${keys} "$HOME/.ssh/authorized_keys"
      ''
    )
  );

  # ssh matches agent keys by public key, not by comment, so IdentitiesOnly
  # needs these on disk.
  home.file.".ssh/pub/phinze-mrn-mbp.pub".text = ''
    ${inputs.nix-private.data.sshKeys.laptop}
  '';

  home.file.".ssh/pub/miren.pub".text = ''
    ${inputs.nix-private.data.sshKeys.miren}
  '';

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
        ServerAliveCountMax = lib.mkDefault 3;
        HashKnownHosts = lib.mkDefault false;
        UserKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";

        # Multiplex every egress connection, on every node. The latency win is
        # nice, but the real reason is that an already-authenticated master
        # survives the agent going away underneath it. Headless nodes reach the
        # agent through double-agent, which proxies to a socket forwarded in by
        # whatever session is attached; when Blink gets suspended on iOS that
        # socket stays open with nobody servicing it, double-agent starts
        # answering "agent refused operation", and every new connection fails
        # auth. A live master keeps working straight through it.
        #
        # %C hashes host/port/user into a fixed-length name, so the socket path
        # can't blow the 108-byte sun_path limit the way %h_%p_%r does once the
        # hostname gets long.
        ControlMaster = "auto";
        ControlPath = "/tmp/ssh_mux_%C";
        ControlPersist = "10m";

        # Keepalives exist because of multiplexing, not in spite of it. Without
        # them a master whose network died silently keeps accepting new
        # sessions that then hang until the OS gives up on the TCP connection.
        # At 30s against the ServerAliveCountMax of 3 above, a dead master
        # tears itself down in ~90s and the next connection just reconnects.
        ServerAliveInterval = 30;

        # One key per host instead of the agent's whole keyring. The fleet all
        # takes this one; blocks above override where a host wants otherwise.
        IdentitiesOnly = lib.mkDefault true;
        IdentityFile = lib.mkDefault "~/.ssh/pub/phinze-mrn-mbp.pub";
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
            # A loopback TCP listener disappears cleanly with its SSH
            # transport. Competing non-multiplexed connections can fail to
            # bind it, but cannot unlink the long-lived master's listener.
            bind.address = "127.0.0.1";
            bind.port = bankshotBridgePort;
            host.address = "/Users/phinze/.bankshot.sock";
          }
        ];
      };

      "pixiu" = {
        User = "root";
      };

      # IdentityFile accumulates rather than overrides, so these hosts offer
      # this key and the "*" default both.
      "${inputs.nix-private.data.sshHosts.miren}" = {
        IdentityFile = "~/.ssh/pub/miren.pub";
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

    # The Mac daemon keeps its private Unix socket. Linux reaches it through
    # the race-safe loopback TCP endpoint forwarded by SSH above.
    settings = lib.optionalAttrs pkgs.stdenv.isLinux {
      network = "tcp";
      address = "127.0.0.1:${toString bankshotBridgePort}";
    };

    # On macOS this is the launchd agent that owns the SSH forwards. On Linux
    # the monitor runs as a system service instead (services.bankshot.monitor
    # in the NixOS baseline), because only a system unit can be granted the
    # eBPF capabilities it needs, so home-manager should not stand up a
    # second, user-scoped one here.
    daemon = {
      enable = pkgs.stdenv.isDarwin;
      autoStart = true;
      logLevel = "info";
    };

    # Monitor configuration (applies to bankshot monitor on remote servers)
    # Default: forward all non-privileged ports (>= 1024)
    monitor = {
      pollInterval = "1s";
      gracePeriod = "30s";
      ignorePorts = [ bankshotBridgePort ];
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
