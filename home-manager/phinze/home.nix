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
    # Hammerspoon for keyboard remapping (replaces Karabiner-Elements)
    ./hammerspoon.nix
    # Demo recorder for terminal sessions
    ./modules/demo-recorder.nix
    # Screenshot module for website captures
    ./modules/screenshot.nix
  ]
  ++ lib.optionals (nodeConfig.isGraphical or false) [
    # Graphical-specific configuration
    ./graphical.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.nixvim
      outputs.overlays.multipass

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
      multipass # GCP Workload Identity Federation auth CLI
      gwq # Git worktree manager that works with ghq
      jq
      linearis # CLI tool for Linear.app with JSON output
      mtr
      nh # Nix helper for more convenient nix commands
      nixvim # My configured copy of neovim
      unstable.fabric-ai # AI framework for augmenting humans
      mpv # Media player for YouTube DJ sets and streams
      yt-dlp # For fabric's video features
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # Docker CLI tools for macOS with Colima
      docker-client
      docker-compose
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      osc-copy # Provides pbcopy via OSC 52 for clipboard access through SSH/tmux
    ]
    # Private packages that require gh authentication
    # Note: Include by default; bootstrap users can set SKIP_PRIVATE_PACKAGES=1
    ++ lib.optionals ((builtins.getEnv "SKIP_PRIVATE_PACKAGES") != "1") [
      inputs.iso.packages.${pkgs.system}.default # Isolated Docker environment
    ]
    ++ (nodeConfig.extraPackages or [ ]);

  programs.atuin = {
    enable = true;
    settings = {
      # Nix will handle updates tyvm
      update_check = false;

      # Don't intersperse global history when just pressing up arrow
      filter_mode_shell_up_key_binding = "session";

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

          # Step 6: Launch Claude only for new sessions
          if test $is_new_session -eq 1
              tmux send-keys -t "$session_name" "claude --dangerously-skip-permissions 'Picking up $identifier — use the Linear MCP to read the issue, mark it In Progress and assigned to me, then help me plan.'" Enter
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

      whatsup = {
        description = "Get Claude to summarize your active work context";
        body = ''
          claude --dangerously-skip-permissions -p /whatsup
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
    userName = "Paul Hinze";
    userEmail = "phinze@phinze.com";
    signing = {
      key = lib.mkDefault (nodeConfig.git.signing.key or "70B94C31D170FB29");
      signByDefault = true;

      # TODO: when home-manager gets these first class in the next release, wire them in instead of the extraConfig
      # format = lib.mkDefault (nodeConfig.git.signing.format or "openpgp");
      # signer = lib.mkDefault (nodeConfig.git.signing.signer or null);
    };
    aliases = {
      co = "checkout";
      st = "status";
      trim = "!git-trim";
      wt = "!gwq";
      wtl = "!gwq list --json | jq -r '.[] | \"\\(.branch) (\\(.path))\"'";
      wtc = "!gwq create";
      wtd = "!gwq delete";
      wts = "!gwq switch";
    };
    ignores = [
      ".direnv"
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
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      core.pager = "env COLORTERM=truecolor delta";
      interactive.diffFilter = "env COLORTERM=truecolor delta --color-only";
      delta = {
        navigate = true;
        dark = true;
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
      gpg = {
        format = "ssh";
      };
      "gpg \"ssh\"" = lib.mkMerge [
        # On macOS, use the 1Password op-ssh-sign from homebrew installation
        (lib.mkIf pkgs.stdenv.isDarwin {
          program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        })
        # On Linux, when SSH agent is forwarded, use ssh-keygen which will use the forwarded agent
        (lib.mkIf pkgs.stdenv.isLinux {
          program = "/run/current-system/sw/bin/ssh-keygen";
          allowedSignersFile = "~/.ssh/allowed_signers";
        })
      ];
    }
    // (nodeConfig.git.extraConfig or { });
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

  programs.tmux = {
    enable = true;
    shortcut = "a";
    escapeTime = 0;
    terminal = "tmux-256color";
    historyLimit = 100000;
    keyMode = "vi";

    # See https://github.com/nix-community/home-manager/issues/6266
    sensibleOnTop = false;

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_flags "icon"

          set -g status-right-length 100
          set -g status-left-length 100
          set -g status-left ""
          set -g status-right "#{E:@catppuccin_status_application}"
          set -ag status-right "#{E:@catppuccin_status_session}"
          set -ag status-right "#{E:@catppuccin_status_host}"
        '';
      }
      {
        plugin = session-wizard;
        extraConfig = ''
          # custom session-wizard activation key
          set -g @session-wizard "t"
          # sometimes I edit multiple repos w/ the same name
          set -g @session-wizard-mode "full-path"
        '';
      }
      vim-tmux-navigator
      {
        plugin = pain-control;
        extraConfig = ''
          # I like vim-style splits vs pain-control's pipe-ish mnemonics.
          bind s split-window -v -c "#{pane_current_path}"
          bind v split-window -h -c "#{pane_current_path}"

          bind ^s split-window -v -c "#{pane_current_path}"
          bind ^v split-window -h -c "#{pane_current_path}"
        '';
      }
    ];

    extraConfig = ''
      # Set terminal/tab title to "【 hostname 】› session" (last 2 path segments of session name)
      set-option -g set-titles on
      set-option -g set-titles-string "【 #h 】#(echo '#{session_name}' | rev | cut -d'/' -f1-2 | rev)"

      # Allow passthrough of escape sequences (needed for OSC 52 clipboard from subprocesses)
      set -g allow-passthrough on

      # Allow programs inside tmux (Neovim specifically) to set clipboard contents
      set -s set-clipboard on

      # Enable focus events for autoread functionality in Neovim
      set -g focus-events on

      # Update environment variables when attaching to tmux
      set -g update-environment "DISPLAY SSH_ASKPASS SSH_AUTH_SOCK SSH_CONNECTION PATH"
    '';
  };

  programs.zoxide.enable = true;

  # SSH allowed signers for git commit verification
  home.file.".ssh/allowed_signers".source = ./ssh-allowed-signers;

  # Finicky configuration for URL routing (macOS only)
  home.file.".finicky.ts" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ./finicky.ts;
  };

  programs.ssh = {
    enable = true;
    controlMaster = lib.mkIf (pkgs.stdenv.isDarwin || (nodeConfig.isGraphical or false)) "auto";
    controlPath = lib.mkIf (
      pkgs.stdenv.isDarwin || (nodeConfig.isGraphical or false)
    ) "/tmp/ssh_mux_%h_%p_%r";
    controlPersist = lib.mkIf (pkgs.stdenv.isDarwin || (nodeConfig.isGraphical or false)) "10m";
    matchBlocks = {
      "foxtrotbase" = {
        forwardAgent = true;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        remoteForwards = [
          {
            bind.address = "/home/phinze/.bankshot.sock";
            host.address = "/Users/phinze/.bankshot.sock";
          }
        ];
        extraOptions = {
          # Disable terminal focus reporting during connection (printf '\e[?1004l')
          # to prevent ^[[I/^[[O escape sequences from appearing as noise.
          # tmux will re-enable focus events when it starts.
          RemoteCommand = "printf '\\e[?1004l'; bankshot monitor reconcile 2>/dev/null || true; exec \$SHELL -l";
          RequestTTY = "yes";
        };
      };

      "pixiu" = {
        user = "root";
      };
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      "*" = {
        extraOptions = {
          IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
        };
      };
    }
    // lib.optionalAttrs (pkgs.stdenv.isLinux && (nodeConfig.isGraphical or false)) {
      "*" = {
        extraOptions = {
          IdentityAgent = "\"~/.1password/agent.sock\"";
        };
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
    monitor = {
      portRanges = [
        {
          start = 3000;
          end = 9999;
        }
      ];
      ignoreProcesses = [
        "sshd"
        "systemd"
        "ssh-agent"
      ];
      pollInterval = "1s";
      gracePeriod = "30s";
    };
  };

  services.sophon = {
    enable = true;
    ntfyUrl = "https://foxtrotbase.swallow-galaxy.ts.net/claude";
    baseUrl = "https://foxtrotbase.swallow-galaxy.ts.net";
    nodeName = osConfig.networking.hostName;
    daemon.enable = pkgs.stdenv.isLinux; # foxtrotbase runs the daemon
    agent.enable = true;
    agent.advertiseUrl = lib.mkIf (!pkgs.stdenv.isLinux)
      "http://${osConfig.networking.hostName}.swallow-galaxy.ts.net:2588";
    daemonUrl = "https://foxtrotbase.swallow-galaxy.ts.net"; # all hosts use the public URL
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
