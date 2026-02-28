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
      tmux-smooth-scroll = pkgs.tmuxPlugins.mkTmuxPlugin {
        pluginName = "smooth-scroll";
        rtpFilePath = "smooth-scroll.tmux";
        version = "unstable-2025-02-28";
        src = pkgs.fetchFromGitHub {
          owner = "phinze";
          repo = "tmux-smooth-scroll";
          rev = "4f8bfcd97ac231a27580392bedc314d94000bd45";
          hash = "sha256-2oDwVMuuu6gnaKqaqUjTdJ4nMuvOIt04W5SipxHBxQY=";
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
          set -g @catppuccin_load_text " #(awk '{print $1}' /proc/loadavg)"
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
    ];

    extraConfig = ''
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
