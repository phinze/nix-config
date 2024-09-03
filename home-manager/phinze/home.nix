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

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;

    globals.mapleader = " ";
    globalOpts = {
      number = true;
      ts = 2;
      shiftwidth = 2;
      ignorecase = true;
      smartcase = true;
      incsearch = true;
      scrolloff = 5;
    };

    colorschemes.catppuccin.enable = true;
    plugins.cmp = {
      enable = true;
      settings.sources = [
        {name = "nvim_lsp";}
        {name = "path";}
        {name = "buffer";}
      ];
    };
    plugins.conform-nvim = {
      enable = true;

      formattersByFt = {
        "_" = ["trim_whitespace"];
        "*" = ["codespell"];
        go = ["goimports" "golines" "gofmt" "gofumpt"];
        javascript = [["prettierd" "prettier"]];
        json = ["jq"];
        lua = ["stylua"];
        nix = ["alejandra"];
        python = ["isort" "black"];
        rust = ["rustfmt"];
        sh = ["shellcheck" "shellharden" "shfmt"];
        terraform = ["terraform_fmt"];
      };
      formatters = {
        black = {
          command = "${lib.getExe pkgs.black}";
        };
        isort = {
          command = "${lib.getExe pkgs.isort}";
        };
        alejandra = {
          command = "${lib.getExe pkgs.alejandra}";
        };
        jq = {
          command = "${lib.getExe pkgs.jq}";
        };
        prettierd = {
          command = "${lib.getExe pkgs.prettierd}";
        };
        stylua = {
          command = "${lib.getExe pkgs.stylua}";
        };
        shellcheck = {
          command = "${lib.getExe pkgs.shellcheck}";
        };
        shfmt = {
          command = "${lib.getExe pkgs.shfmt}";
        };
        shellharden = {
          command = "${lib.getExe pkgs.shellharden}";
        };
      };

      formatOnSave = ''
        function(bufnr)
          local ignore_filetypes = { }
          if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
            return
          end

          -- Disable with a global or buffer-local variable
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
          end

          -- Disable autoformat for files in a certain path
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if bufname:match("/node_modules/") then
            return
          end
          return { timeout_ms = 1000, lsp_fallback = true }
        end
      '';
    };
    plugins.gitsigns = {
      enable = true;
    };
    plugins.indent-blankline = {
      enable = true;
      settings.scope.enabled = true;
    };
    plugins.lualine.enable = true;
    plugins.lsp = {
      enable = true;
      servers = {
        nixd.enable = true;
      };
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
    plugins.none-ls.enable = true;
    plugins.nvim-osc52 = {
      enable = true;
    };
    plugins.oil = {
      enable = true;
    };
    plugins.rainbow-delimiters.enable = true;
    plugins.telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
    };
    plugins.treesitter = {
      enable = true;
      indent = true;
    };
    plugins.treesitter-context = {
      enable = true;
      settings.max_lines = 3;
    };
    plugins.treesitter-textobjects = {
      enable = true;
      select = {
        enable = true;
        lookahead = true;
        keymaps = {
          "aa" = "@parameter.outer";
          "ia" = "@parameter.inner";
          "af" = "@function.outer";
          "if" = "@function.inner";
          "ac" = "@class.outer";
          "ic" = "@class.inner";
          "ii" = "@conditional.inner";
          "ai" = "@conditional.outer";
          "il" = "@loop.inner";
          "al" = "@loop.outer";
          "at" = "@comment.outer";
        };
      };
      move = {
        enable = true;
        gotoNextStart = {
          "]m" = "@function.outer";
          "]]" = "@class.outer";
        };
        gotoNextEnd = {
          "]M" = "@function.outer";
          "][" = "@class.outer";
        };
        gotoPreviousStart = {
          "[m" = "@function.outer";
          "[[" = "@class.outer";
        };
        gotoPreviousEnd = {
          "[M" = "@function.outer";
          "[]" = "@class.outer";
        };
      };
      swap = {
        enable = true;
        swapNext = {
          "<leader>a" = "@parameters.inner";
        };
        swapPrevious = {
          "<leader>A" = "@parameter.outer";
        };
      };
    };
    plugins.treesitter-refactor = {
      enable = true;
      highlightDefinitions.enable = true;
    };
    plugins.trouble.enable = true;
    plugins.tmux-navigator.enable = true;
    plugins.which-key.enable = true;

    extraPlugins = [
      pkgs.vimPlugins.vimux
      pkgs.vimPlugins.guess-indent-nvim
    ];

    extraConfigLua = ''
      require("guess-indent").setup({})
    '';

    keymaps = [
      # Telescope
      {
        key = "<leader>o";
        action = "<cmd>Telescope find_files<CR>";
        options.desc = "Find files";
      }
      {
        key = "<leader>g";
        action = "<cmd>Telescope live_grep<CR>";
        options.desc = "Find files";
      }

      # Vimux
      {
        key = "<leader>v";
        action = "<cmd>VimuxPromptCommand<CR>";
        options.desc = "Run command in Vimux";
      }
      {
        key = "<CR>";
        action = ":wa <CR> :VimuxRunLastCommand<CR>";
        options.desc = "Rerun last command in Vimux";
      }

      # Oil
      {
        key = "-";
        action = "<cmd>Oil<CR>";
        options.desc = "Open parent directory";
      }

      # treesitter-context
      {
        key = "[c";
        action = "<cmd>lua require(\"treesitter-context\").go_to_context(vim.v.count1)<CR>";
        options.desc = "Jump to beginning of context";
      }

      # conform-nvim
      {
        key = "<leader>F";
        action = "<cmd>lua require(\"conform\").format({ bufnr = args.buf, async = true })<CR>";
        options.desc = "Format buffer";
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
      set-option -sa terminal-features ',screen-256color:RGB'
    '';
  };

  programs.zoxide.enable = true;

  services.gpg-agent = {
    enable = pkgs.stdenv.isLinux;
    pinentryPackage = pkgs.pinentry-tty;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
