{ config, lib, pkgs, ... }:

let sources = import ../../nix/sources.nix; in {
  # It helps to set this explicitly for hosts using standalone home manager.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  # Need to explicitly set nix.package to make this work.
  # See: https://github.com/nix-community/home-manager/issues/3644#issuecomment-1418707189
  nix.package = pkgs.nix;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "phinze";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/phinze" else "/home/phinze";

  # Manage XDG home directories and set XDG_*_HOME env vars.
  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. Most packages I install using
  # per-project flakes sourced with direnv and nix-shell, so this is
  # not a huge list.
  home.packages = [
    pkgs.any-nix-shell
    pkgs.atuin
    pkgs.bat
    pkgs.bat-extras.batgrep
    pkgs.btop
    pkgs.delve
    pkgs.du-dust
    pkgs.fd
    pkgs.file
    pkgs.fzf
    pkgs.git-crypt
    pkgs.gh
    pkgs.htop
    pkgs.jq
    pkgs.ripgrep
    pkgs.tree
    pkgs.watch

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

  # Work around https://github.com/NixOS/nixpkgs/pull/217205
  programs.zsh.enable = true;

  programs.gpg.enable = true;

  programs.direnv = {
    enable = true;
    config = {
      whitelist = {
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
      safe.directory = "${config.home.homeDirectory}/projects/nixos-config";
    };
  };

  programs.go = {
    enable = true;
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
    vimAlias = true;
    extraConfig = builtins.readFile ./init.vim;
  };

  services.gpg-agent = {
    enable = pkgs.stdenv.isLinux;
    pinentryFlavor = "tty";

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
