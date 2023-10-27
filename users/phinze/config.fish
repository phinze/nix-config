#-------------------------------------------------------------------------------
# SSH Agent
#-------------------------------------------------------------------------------
function __ssh_agent_is_started -d "check if ssh agent is already started"
	if begin; test -f $SSH_ENV; and test -z "$SSH_AGENT_PID"; end
		source $SSH_ENV > /dev/null
	end

	if test -z "$SSH_AGENT_PID"
		return 1
	end

	ssh-add -l > /dev/null 2>&1
	if test $status -eq 2
		return 1
	end
end

function __ssh_agent_start -d "start a new ssh agent"
  ssh-agent -c | sed 's/^echo/#echo/' > $SSH_ENV
  chmod 600 $SSH_ENV
  source $SSH_ENV > /dev/null
  ssh-add
end

if not test -d $HOME/.ssh
    mkdir -p $HOME/.ssh
    chmod 0700 $HOME/.ssh
end

if test -d $HOME/.gnupg
    chmod 0700 $HOME/.gnupg
end

if test -z "$SSH_ENV"
    set -xg SSH_ENV $HOME/.ssh/environment
end

# if not __ssh_agent_is_started
#     __ssh_agent_start
# end

#-------------------------------------------------------------------------------
# Vim
#-------------------------------------------------------------------------------
# We should move this somewhere else but it works for now
mkdir -p $HOME/.vim/{backup,swap,undo}

#-------------------------------------------------------------------------------
# Prompt
#-------------------------------------------------------------------------------
# Do not show any greeting
set --universal --erase fish_greeting
function fish_greeting; end
funcsave -q fish_greeting

set -g theme_color_scheme dracula

# Automatically set tmux window name
function set_tmux_window_to_pwd --on-event fish_prompt
  if not set -q disable_tmux_window_pwd
    if tmux info &> /dev/null
      tmux rename-window $(basename $PWD)
    end
  end
end
funcsave -q set_tmux_window_to_pwd

#-------------------------------------------------------------------------------
# Vars
#-------------------------------------------------------------------------------
contains $HOME/bin $fish_user_paths; or set -Ua fish_user_paths $HOME/bin

# Exported variables
if isatty
    set -x GPG_TTY (tty)
end

# Enable any-nix-shell
any-nix-shell fish --info-right | source

set -gx HOMEBREW_GITHUB_API_TOKEN (gh config get -h github.com oauth_token)
set -gx GITHUB_TOKEN (gh config get -h github.com oauth_token)

# Atuin
if status --is-interactive
  atuin init fish | source
end
