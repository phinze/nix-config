# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
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
    inputs.nixvim.homeManagerModules.nixvim
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

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
    homeDirectory = "/home/phinze";
  };

  home.packages = with pkgs; [
    ghq
  ];

  programs.atuin.enable = true;

  programs.bat.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fish = {
    enable = true;

    plugins = with pkgs.fishPlugins; [
      { name = "pure"; src = pure.src; }
      { name = "foreign-env"; src = foreign-env.src; }
      { name = "fzf-fish"; src = fzf-fish.src; }
    ];

    # any-nix-shell helps fish stick around in nix subshells
    interactiveShellInit = ''
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source
    '';
  };

  programs.fd.enable = true;

  programs.fzf = {
    enable = true;
    enableFishIntegration = false;
  };

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

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;

    globals.mapleader = " ";

    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
    plugins.lsp = {
      enable = true;
      keymaps = {
        extra = [
          {
            mode = "n";
            key = "<leader>li";
            action = "<cmd>LspInfo<cr>";
            options.desc = "Show LSP info";
          }
          {
            mode = "n";
            key = "<leader>ll";
            action.__raw = "function() vim.lsp.codelens.refresh() end";
            options.desc = "LSP CodeLens refresh";
          }
          {
            mode = "n";
            key = "<leader>lL";
            action.__raw = "function() vim.lsp.codelens.run() end";
            options.desc = "LSP CodeLens run";
          }
        ];

        lspBuf = {
          "<leader>la" = {
            action = "code_action";
            desc = "LSP code action";
          };

          gd = {
            action = "definition";
            desc = "Go to definition";
          };

          gI = {
            action = "implementation";
            desc = "Go to implementation";
          };

          gy = {
            action = "type_definition";
            desc = "Go to type definition";
          };

          K = {
            action = "hover";
            desc = "LSP hover";
          };
        };
      };
    };
    plugins.telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
    };
    plugins.treesitter = {
      enable = true;
    };
    plugins.tmux-navigator.enable = true;
    plugins.which-key.enable = true;

    extraPlugins =[
      pkgs.vimPlugins.vimux
    ];

    keymaps = [
      # Telescope
      {
        key = "<leader>o";
        action = "<cmd>Telescope find_files<CR>";
      }

      # Vimux
      {
        key = "<leader>v";
        action = "<cmd>VimuxPromptCommand<CR>";
      }
      {
        key = "<CR>";
        action = ":wa <CR> :VimuxRunLastCommand<CR>";
      }
    ];
  };

  programs.ripgrep.enable = true;

  programs.tmux = {
    enable = true;
    shortcut = "a";
    escapeTime = 0;
    terminal = "screen-256color";
    historyLimit = 100000;
    keyMode = "vi";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      vim-tmux-navigator
      catppuccin
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
      # Recommended by nvim :checkhealth
      set-option -sa terminal-overrides ',xterm-256color:RGB'
		'';
  };

  programs.zoxide.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
