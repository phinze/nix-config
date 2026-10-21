{
  config,
  pkgs,
  lib,
  ...
}:
# A standing ssh connection from the Mac to foxtrotbase, so foxtrotbase has the
# laptop's agent and the bankshot bridge whenever the laptop is awake, not only
# while an interactive ssh session happens to be open.
#
# Both ride the connection itself: ForwardAgent and the bankshot RemoteForward
# come from the foxtrotbase block in ~/.ssh/config, and double-agent picks up
# the forwarded socket the way it picks up any other. A Rex session to
# foxtrotbase carries neither (Rex has no socket forwarding), so without this a
# Rex-only day can't push, sign, or xdg-open back to the laptop.
#
# The remote command matters: sshd only creates the agent socket when a session
# channel asks for it, so `ssh -N` would hold the connection and forward nothing.
# `sleep infinity` gives the session something to run without a tty, and having
# a command keeps the interactive-only RemoteCommand match out of it.
#
# After a sleep the connection is dead but ssh doesn't know yet; the keepalives
# notice within ~30s, ssh exits, and KeepAlive relaunches it.
let
  logFile = "${config.home.homeDirectory}/Library/Logs/ssh-tether.log";
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  launchd.agents.ssh-tether = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/ssh"
        "-T"
        "-o"
        "BatchMode=yes"
        "-o"
        "ServerAliveInterval=10"
        "-o"
        "ServerAliveCountMax=3"
        "foxtrotbase"
        "exec sleep infinity"
      ];
      # Interactive ssh forwards 1Password with SSH_AUTH_SOCK unset, so
      # ForwardAgent seems to follow IdentityAgent. Pinning SSH_AUTH_SOCK to the
      # same socket covers the case where it doesn't under launchd, whose
      # default would be the empty system agent.
      EnvironmentVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
      RunAtLoad = true;
      KeepAlive = true;
      # Offline (or before the tailnet is up) every attempt fails fast; this
      # keeps the retries from filling the log.
      ThrottleInterval = 30;
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
      # Standard, not Background: signing requests from foxtrotbase wait on
      # this process, and Background throttling made rig-serve's calls 30-100x
      # slower under load.
      ProcessType = "Standard";
    };
  };
}
