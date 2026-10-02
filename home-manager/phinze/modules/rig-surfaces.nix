{
  osConfig,
  pkgs,
  lib,
  ...
}:
# How rig's radar on one machine sees rigs on another without ssh. foxtrotbase
# runs `rig serve`, which answers its rigs, sessions, and agent panes over the
# tailnet to callers on the allow list; the Mac's radar lists it through a
# rig+http surface and only opens ssh (through its tmux portal) to enter one.
#
# The surface lives in surfaces.toml rather than config.toml because rig
# rewrites config.toml whole on every `rig config` write, so nix can't own it,
# and the 2026-09-28 wipe that deleted it took the hand-written surfaces along.
# A config.toml entry still wins, for a one-off override without a rebuild.
lib.mkMerge [
  (lib.mkIf pkgs.stdenv.isDarwin {
    xdg.configFile."rig/surfaces.toml".text = ''
      [surfaces]
      foxtrotbase = "rig+http://foxtrotbase"
    '';
  })

  (lib.mkIf (pkgs.stdenv.isLinux && osConfig.networking.hostName == "foxtrotbase") {
    systemd.user.services.rig-serve = {
      Unit.Description = "Answer other hosts' rig radars over the tailnet";
      Service = {
        # Binds this host's tailnet IP, which may not exist yet at login;
        # restarting until it does is simpler than ordering against tailscaled
        # from a user unit.
        ExecStart = "${lib.getExe pkgs.rig} serve --allow phinze@github";
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
