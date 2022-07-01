{ config, lib, pkgs, ... }:

let sources = import ../../nix/sources.nix; in {
  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. Most packages I install using
  # per-project flakes sourced with direnv and nix-shell, so this is
  # not a huge list.
  home.packages = [
    pkgs.any-nix-shell
    pkgs.btop
    pkgs.delve
    pkgs.fd
    pkgs.fzf
    pkgs.git-crypt
    pkgs.gh
    pkgs.go
    pkgs.htop
    pkgs.jq
    pkgs.ripgrep
    pkgs.terraform
    pkgs.tree
    pkgs.watch
    pkgs.zathura

    # lsps
    pkgs.gopls
    pkgs.rust-analyzer
    pkgs.terraform-ls
  ];

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "less -FirSwX";
  };

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.gpg.enable = true;

  programs.bash = {
    enable = true;
    shellOptions = [];
    historyControl = [ "ignoredups" "ignorespace" ];
    initExtra = builtins.readFile ./bashrc;

    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
    };
  };

  programs.direnv= {
    enable = true;
    config = {
      whitelist = {
        prefix= [
          "$HOME/code/go/src/github.com/hashicorp"
          "$HOME/code/go/src/github.com/phinze"
        ];

        exact = ["$HOME/.envrc"];
      };
    };
  };
  programs.direnv.nix-direnv.enable = true;

  programs.fish = {
    enable = true;
    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
      (builtins.readFile ./config.fish)
      "set -g SHELL ${pkgs.fish}/bin/fish"
    ]);

    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";

      # Two decades of using a Mac has made this such a strong memory
      # that I'm just going to keep it consistent.
      pbcopy = "xclip";
      pbpaste = "xclip -o";
    };

    plugins = map (n: {
      name = n;
      src  = sources.${n};
    }) [
      "fish-fzf"
      "fish-foreign-env"
      "fish-pure"
    ];
  };

  programs.git = {
    enable = true;
    userName = "Paul Hinze";
    userEmail = "phinze@phinze.com";
    signing = {
      key = "70B94C31D170FB29";
      signByDefault = true;
    };
    aliases = {
      prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      root = "rev-parse --show-toplevel";
      co = "checkout";
      st = "status";
    };
    ignores = [
      ".direnv"
      ".byebug_history"
    ];
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      credential.helper = "!gh auth git-credential";
      github.user = "phinze";
      push.default = "tracking";
      init.defaultBranch = "main";
      safe.directory = "/home/phinze/projects/nixos-config";
    };
  };

  programs.go = {
    enable = true;
    goPath = "code/go";
    goPrivate = [ "github.com/phinze" "github.com/hashicorp" "rfc822.mx" ];
  };

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
      {
        plugin = mkTmuxPlugin rec {
          pluginName = "dracula";
          version = "2.0.0";
          src = pkgs.fetchFromGitHub {
            owner = "dracula";
            repo = "tmux";
            rev = "v${version}";
            sha256 = "ILs+GMltb2AYNUecFMyQZ/AuETB0PCFF2InSnptVBos=";
          };
        };
        extraConfig = ''
          set -g @dracula-show-powerline true
          set -g @dracula-show-left-icon ∞
          set -g @dracula-plugins "time"
        '';
      }
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

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    vimAlias = true;
    extraConfig = builtins.readFile ./init.vim;
  };

  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "tty";

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };
}
