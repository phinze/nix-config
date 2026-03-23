# Nushell experiment module
#
# Self-contained nushell setup for toe-dipping. Enables nushell alongside fish
# with starship, zoxide, atuin, and direnv integrations so it feels like home.
#
# Usage: launch `nu` from fish to try it out. Does not change default shell.
{ config, lib, pkgs, ... }:
let
  cfg = config.phinze.nushell;
in
{
  options.phinze.nushell = {
    enable = lib.mkEnableOption "nushell experiment";
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;

      # Shell aliases matching fish config
      shellAliases = {
        vi = "nvim";
        vim = "nvim";
      };

      environmentVariables = {
        EDITOR = "nvim";
      };

      extraConfig = ''
        # Sane defaults for interactive use
        $env.config.show_banner = false
        $env.config.edit_mode = "vi"

        # Completions tuning
        $env.config.completions.algorithm = "fuzzy"

        # Clear default prompt indicator so it doesn't append after starship
        $env.PROMPT_INDICATOR = ""
        $env.PROMPT_INDICATOR_VI_INSERT = ""
        $env.PROMPT_INDICATOR_VI_NORMAL = ""
      '';
    };

    # Starship prompt (replaces pure theme from fish)
    # Only enable for nushell — fish keeps its pure plugin
    programs.starship = {
      enable = true;
      enableFishIntegration = false;
      enableNushellIntegration = true;
      settings = {
        # Keep it minimal like pure
        add_newline = true;
        format = lib.concatStrings [
          "$directory"
          "$git_branch"
          "$git_status"
          "$cmd_duration"
          "$line_break"
          "$character"
        ];
        character = {
          success_symbol = "[❯](purple)";
          error_symbol = "[❯](red)";
          vimcmd_symbol = "[❮](green)";
        };
        directory = {
          truncate_to_repo = false;
          truncation_length = 0; # show full path, like pure
          style = "bold blue";
        };
        git_branch = {
          format = "[$branch]($style) ";
          style = "242"; # muted gray like pure
        };
        git_status = {
          # Pure uses * for dirty, ⇡⇣ for ahead/behind
          format = "[$all_status$ahead_behind]($style) ";
          style = "242";
          modified = "*";
          staged = "*";
          untracked = "*";
          deleted = "*";
          renamed = "*";
          conflicted = "*";
          ahead = "⇡";
          behind = "⇣";
          diverged = "⇡⇣";
        };
        cmd_duration = {
          min_time = 5000;
          format = "[$duration]($style) ";
          style = "yellow";
        };
      };
    };

    # Ensure integrations generate nushell config
    # (atuin, zoxide, direnv are already enabled in home.nix —
    #  home-manager auto-generates nushell integration when nushell is enabled)
  };
}
