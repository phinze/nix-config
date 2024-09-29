# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  outputs,
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
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

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    gh
    ghq # Clone repos into dir structure
    nixvim # My configured copy of neovim
  ];

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
      };

      shellAliases = {
        # nix version of https://github.com/27medkamal/tmux-session-wizard?tab=readme-ov-file#optional-using-the-script-outside-of-tmux
        t = "${pkgs.tmuxPlugins.session-wizard}/share/tmux-plugins/session-wizard/session-wizard.sh";
      };

      interactiveShellInit = lib.concatLines [
        # any-nix-shell helps fish stick around in nix subshells
        "${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source"
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

  programs.htop.enable = true;

  programs.git = {
    enable = true;
    userName = "Paul Hinze";
    userEmail = "phinze@phinze.com";
    signing = {
      key = "70B94C31D170FB29";
      signByDefault = true;
    };
    aliases = {
      co = "checkout";
      st = "status";
    };
    ignores = [
      ".direnv"
    ];
    extraConfig = {
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
    };
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

  programs.ripgrep.enable = true;

  programs.tmux = {
    enable = true;
    shortcut = "a";
    escapeTime = 0;
    terminal = "tmux-256color";
    historyLimit = 100000;
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      catppuccin
      sensible
      {
        plugin = session-wizard;
        extraConfig = ''
          # custom session-wizard activation key
          set -g @session-wizard 't'
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

  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkIf pkgs.stdenv.isLinux "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
