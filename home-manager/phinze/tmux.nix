{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    escapeTime = 0;
    terminal = "tmux-256color";
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;

    # See https://github.com/nix-community/home-manager/issues/6266
    sensibleOnTop = false;

    plugins = let
      loadCommand = if pkgs.stdenv.isDarwin
        then "sysctl -n vm.loadavg | awk '{print $2}'"
        else "awk '{print $1}' /proc/loadavg";
      tmux-smooth-scroll = pkgs.tmuxPlugins.mkTmuxPlugin {
        pluginName = "smooth-scroll";
        rtpFilePath = "smooth-scroll.tmux";
        version = "unstable-2025-03-02";
        src = pkgs.fetchFromGitHub {
          owner = "phinze";
          repo = "tmux-smooth-scroll";
          rev = "073729b62610279b8baa8b853f03652602997d96";
          hash = "sha256-8z+HzHLFo3DBBZLBNOKHyoBsMIyQ4M4lEl/72V3J78Y=";
        };
      };
    in with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_flags "icon"

          set -g status-right-length 100
          set -g status-left-length 100
          set -g status-left ""
          set -g @catppuccin_load_text " #(${loadCommand})"
          set -g status-right "#{E:@catppuccin_status_load}"
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
      {
        plugin = tmux-smooth-scroll;
        extraConfig = ''
          set -g @smooth-scroll-mouse "false"
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
      {
        plugin = resurrect;
        extraConfig = ''
          # Keep pane text visible across restarts.
          set -g @resurrect-capture-pane-contents 'on'

          # Resurrect Claude Code panes by RESUMING the on-disk conversation for
          # the pane's directory instead of starting a fresh chat. resurrect's
          # inline strategy is `match->restore-command`. The leading ~ is
          # resurrect's "match leniently as a substring" token (NOT a home dir),
          # so `bin/claude` matches the real command line
          # (.../bin/claude ...) regardless of its profile path, and the pane is
          # relaunched as `claude --continue`, reattaching to the latest session
          # for that cwd. Assumes one Claude pane per directory.
          set -g @resurrect-processes '"~bin/claude->claude --continue --dangerously-skip-permissions"'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          # Auto-save every 15 min and auto-restore on a fresh server. This is
          # what makes the post-upgrade `tmux kill-server` cheap: reopen a pane
          # and every session/window/pane (and resumed Claude) comes back.
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # ilmari: popup radar for agent panes (Codex, Claude Code, OpenCode, ...)
      bind-key i display-popup -E -w 90% -h 85% "ilmari"

      # Set terminal/tab title to "【 hostname 】› session" (last 2 path segments of session name)
      set-option -g set-titles on
      set-option -g set-titles-string "【 #h 】#(echo '#{session_name}' | rev | cut -d'/' -f1-2 | rev)"

      # Allow passthrough of escape sequences (needed for OSC 52 clipboard from subprocesses)
      set -g allow-passthrough on

      # Ghostty's terminfo has Tc/setrgbf/setrgbb but tmux doesn't auto-promote
      # those to feature flags; hyperlinks (OSC 8) has no terminfo representation at all.
      set -as terminal-features ",xterm-ghostty:RGB:hyperlinks"

      # Allow programs inside tmux (Neovim specifically) to set clipboard contents
      set -s set-clipboard on

      # Enable focus events for autoread functionality in Neovim
      set -g focus-events on

      # Update environment variables when attaching to tmux
      set -g update-environment "DISPLAY SSH_ASKPASS SSH_AUTH_SOCK SSH_CONNECTION PATH"

      # Copy-mode mouse tweaks:
      # - Single-line wheel steps (tmux defaults to 5)
      # - Auto-exit copy mode when scrolling past the bottom
      # - Mouse select copies without exiting copy mode
      bind-key -T copy-mode-vi WheelUpPane send-keys -X scroll-up
      bind-key -T copy-mode-vi WheelDownPane {
        send-keys -X scroll-down
        if-shell -F "#{&&:#{pane_in_mode},#{==:#{scroll_position},0}}" {
          send-keys -X cancel
        }
      }
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection
    '';
  };
}
