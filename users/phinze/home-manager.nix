{ inputs, osConfig, config, lib, pkgs, ... }:

let sources = import ../../nix/sources.nix; in {
  # It helps to set this explicitly for hosts using standalone home manager.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

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
    pkgs.nodePackages.bash-language-server
    pkgs.nodePackages.yaml-language-server
    pkgs.rust-analyzer
    pkgs.shellcheck
    pkgs.terraform-ls
    pkgs.zls
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
    } // lib.optionalAttrs (! pkgs.stdenv.isDarwin) {
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

  } // lib.optionalAttrs (pkgs.stdenv.isDarwin) {
    # Workaround from https://github.com/LnL7/nix-darwin/issues/122#issuecomment-1659465635
    loginShellInit =
      let
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


  xdg.configFile."ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    text = ''
      font-family = Hack
      clipboard-read = true
      clipboard-write = true
    '';
  };

  xdg.configFile."atuin/config.toml" = {
    text = ''
      filter_mode_shell_up_key_binding = "session"
      update_check = false
    '';
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
