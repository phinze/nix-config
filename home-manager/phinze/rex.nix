# Rex (Superlogical's terminal multiplexer) configuration for macOS.
#
# This writes ~/.config/rex/init.lua, which is Rex's whole account-level
# config: it binds keys with rex.bind and takes them away with rex.unbind.
# Rex is installed from its own DMG rather than nixpkgs, so there is no
# package here — only the config file, the way ghostty.nix handles the
# Homebrew cask.
#
# Rex is macOS-only today (Linux server packages are on their roadmap), so
# the module is wrapped in mkIf isDarwin; foxtrotbase keeps running tmux.
{
  lib,
  pkgs,
  config,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  xdg.configFile."rex/init.lua".text = ''
    -- rig radar, Rex's answer to leader-r.
    --
    -- The handler is handed the session the keypress happened in, which is
    -- the one thing Rex's API will not tell a caller: focus is client-local
    -- state the server does not hold, so nothing else can ask "which session
    -- is on screen". Passing it to rig as REX_SESSION means rig opens the
    -- board over the session you are actually looking at, and rig stays the
    -- only place that knows how to size, paint, and place the layer.
    --
    -- Backgrounded so the server is not waiting on us; rig returns as soon
    -- as the layer exists.
    local rig = "${config.home.profileDirectory}/bin/rig"

    rex.bind("cmd+shift+r", function(ctx)
      os.execute("REX_SESSION=" .. ctx.session_id .. " " .. rig .. " radar --popup >/dev/null 2>&1 &")
    end)
  '';
}
