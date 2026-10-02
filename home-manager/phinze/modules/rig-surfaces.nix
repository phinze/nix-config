{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
# How rig's radar on one machine sees rigs on another without ssh. Each host
# runs `rig serve`, which answers its rigs, sessions, and agent panes over the
# tailnet to callers on its allow list, and each lists the other through a
# rig+http surface.
#
# Entering goes the way the screen does. The Mac radar opens its own ssh
# portal into foxtrotbase, since the Mac's Rex is the screen. foxtrotbase's
# radar, seen through that same Rex, can't move the Mac's client, so Enter on
# a Mac row asks the Mac's serve to show it (POST /v1/show), and the Mac moves
# its own screen. That needs Rex.app's Remote Control setting on.
#
# The surfaces live in surfaces.toml rather than config.toml because rig
# rewrites config.toml whole on every `rig config` write, so nix can't own it,
# and the 2026-09-28 wipe that deleted it took the hand-written surfaces along.
# A config.toml entry still wins, for a one-off override without a rebuild.
#
# --icon is what other radars draw in front of this host's rows instead of its
# name: Font Awesome's laptop (U+F109) and server (U+F233), the same family as
# the radar's other glyphs.
let
  isFoxtrotbase = pkgs.stdenv.isLinux && osConfig.networking.hostName == "foxtrotbase";
  laptopIcon = "";
  serverIcon = "";
in
lib.mkMerge [
  (lib.mkIf pkgs.stdenv.isDarwin {
    xdg.configFile."rig/surfaces.toml".text = ''
      [surfaces]
      foxtrotbase = "rig+http://foxtrotbase"
    '';

    # Only foxtrotbase asks, and it's a tagged node, so it's allowed by node
    # name: its login is the tag placeholder, which names nobody.
    launchd.agents.rig-serve = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe pkgs.rig)
          "serve"
          "--allow"
          "foxtrotbase"
          "--icon"
          laptopIcon
        ];
        # Binds the tailnet IP, which may not exist yet at login or after a
        # wake; KeepAlive relaunches until it does.
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        EnvironmentVariables.PATH = lib.concatStringsSep ":" [
          "/etc/profiles/per-user/${config.home.username}/bin"
          "${config.home.homeDirectory}/.nix-profile/bin"
          "/run/current-system/sw/bin"
          "/usr/local/bin" # the tailscale CLI
          "/usr/bin"
          "/bin"
        ];
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/rig-serve.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/rig-serve.log";
        ProcessType = "Background";
      };
    };
  })

  (lib.mkIf isFoxtrotbase {
    xdg.configFile."rig/surfaces.toml".text = ''
      [surfaces]
      phinze-mrn-mbp = "rig+http://phinze-mrn-mbp"
    '';

    systemd.user.services.rig-serve = {
      Unit.Description = "Answer other hosts' rig radars over the tailnet";
      Service = {
        # Binds this host's tailnet IP, which may not exist yet at login;
        # restarting until it does is simpler than ordering against tailscaled
        # from a user unit.
        ExecStart = "${lib.getExe pkgs.rig} serve --allow phinze@github --icon ${serverIcon}";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          # tmux needs TMUX_TMPDIR to find the user's server socket; without it
          # every session looks absent and every rig reads as stopped.
          "TMUX_TMPDIR=%t"
          # tailscale (whois, ip), tmux, and gh for the PR refresh, resolved
          # the way interactive sessions resolve them.
          "PATH=%h/bin:/etc/profiles/per-user/%u/bin:%h/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };
  })
]
