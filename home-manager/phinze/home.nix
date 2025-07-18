# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  config,
  osConfig,
  pkgs,
  lib,
  nodeConfig ? {},
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # Allows mistyped commands to suggest packages instead of displaying a
    # command-not-found error
    inputs.nix-index-database.hmModules.nix-index
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.nixvim

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
    homeDirectory =
      if pkgs.stdenv.isDarwin
      then "/Users/phinze"
      else "/home/phinze";
  };

  home.shellAliases = {
    # Since we aren't using a home-manager module for neovim, set neovim aliases here
    vi = "nvim";
    vim = "nvim";
  };

  home.sessionVariables =
    {
      EDITOR = "nvim";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    };

  home.packages = with pkgs;
    [
      ccusage # Analyze Claude Code token usage and costs
      gh
      ghq # Clone repos into dir structure
      google-cloud-sdk # I want to run gcloud from anywhere
      gwq # Git worktree manager that works with ghq
      jq
      nixvim # My configured copy of neovim
      unstable.claude-code
    ]
    ++ (nodeConfig.extraPackages or []);

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
  };

  programs.fish =
    {
      enable = true;

      plugins = with pkgs.fishPlugins; [
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
          description = "Quick switch between ghq repos and their worktrees";
          body = ''
            # If we're in a ghq repo, offer to switch to a worktree
            set -l current_path (pwd)
            if string match -q "$HOME/src/*" $current_path
                # Extract the repo path relative to ghq root
                set -l repo_rel_path (string replace "$HOME/src/" "" $current_path | string split -m 2 "/")[1-3] | string join "/"

                # Check if we have worktrees for this repo
                set -l worktrees (gwq list --path | grep -E "^$HOME/worktrees/$repo_rel_path/")

                if test (count $worktrees) -gt 0
                    # Use fzf to select a worktree
                    set -l selected (printf "%s\n" $worktrees | fzf --height=20% --reverse --header="Select worktree")
                    if test -n "$selected"
                        cd $selected
                    end
                else
                    echo "No worktrees found for current repo. Use 'git wt' to create one."
                end
            # If we're in a worktree, offer to go back to the main repo
            else if string match -q "$HOME/worktrees/*" $current_path
                set -l repo_path (string replace "$HOME/worktrees/" "$HOME/src/" $current_path | string split -m 3 "/" | string join "/")
                if test -d $repo_path
                    cd $repo_path
                else
                    echo "Could not find main repo at $repo_path"
                end
            else
                echo "Not in a ghq repo or gwq worktree"
            end
          '';
        };

        wtcd = {
          description = "cd to a gwq worktree using fuzzy finder";
          body = ''
            set -l worktree (gwq list --path | fzf --height=40% --reverse)
            if test -n "$worktree"
                cd $worktree
            end
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
      loginShellInit = let
        # This naive quoting is good enough in this case. There shouldn't be any
        # double quotes in the input string, and it needs to be double quoted in case
        # it contains a space (which is unlikely!)
        dquote = str: "\"" + str + "\"";

        makeBinPathList = map (path: path + "/bin");
      in ''
        fish_add_path --move --prepend --path ${lib.concatMapStringsSep " " dquote (makeBinPathList osConfig.environment.profiles)}
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
      wt = "!gwq";
      wtl = "!gwq list";
      wtc = "!gwq create";
      wtd = "!gwq delete";
      wts = "!gwq switch";
    };
    ignores = [
      ".direnv"
    ];
    extraConfig =
      {
        branch.autosetuprebase = "always";
        color.ui = true;
        core.askPass = ""; # needs to be empty to use terminal for ask pass
        credential.helper = "!gh auth git-credential";
        github.user = "phinze";
        push.default = "tracking";
        init.defaultBranch = "main";
        safe.directory = "${config.home.homeDirectory}/src/github.com/phinze/nixos-config";
        push.autoSetupRemote = true;
        ghq.root = "~/src";
      }
      // (nodeConfig.git.extraConfig or {});
  };

  programs.gh = {
    enable = true;
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
      # Allow programs inside tmux (Neovim specifically) to set clipboard contents
      set -s set-clipboard on
    '';
  };

  programs.zoxide.enable = true;

  programs.ssh = {
    enable = true;
    matchBlocks =
      {
        "foxtrotbase" =
          {
            forwardAgent = true;
          }
          // lib.optionalAttrs pkgs.stdenv.isDarwin {
            remoteForwards = [
              {
                bind.address = "/home/phinze/.opener.sock";
                host.address = "/Users/phinze/.opener.sock";
              }
            ];
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
      };
  };

  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    pinentryPackage = pkgs.pinentry-tty;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  xdg.configFile."ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ./ghostty.config;
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

  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkIf pkgs.stdenv.isLinux "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
