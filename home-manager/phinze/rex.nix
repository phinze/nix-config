# Rex (Superlogical's terminal multiplexer) configuration for macOS.
#
# This writes ~/.config/rex/init.lua, which is Rex's whole account-level
# config: it binds keys with rex.bind, takes them away with rex.unbind, and
# adds command-palette entries with rex.action.
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

    -- Palette: the radar again, for when the chord isn't in your fingers.
    -- A rex.action lands in the command palette on its own; no bind needed.
    rex.action({
      name = "rig_radar",
      title = "Rig Radar",
      category = "Rig",
      keywords = "rig radar switch session hop",
      run = function(ctx)
        os.execute("REX_SESSION=" .. ctx.session_id .. " " .. rig .. " radar --popup >/dev/null 2>&1 &")
      end,
    })

    -- Palette: close the frontmost floating layer in this session. A layer
    -- closes when its process exits, so one whose process won't (a tmux
    -- client that ended up inside the radar popup, say) otherwise has no way
    -- out short of closing the whole session.
    rex.action({
      name = "close_layer",
      title = "Close Floating Layer",
      category = "Layers",
      keywords = "close popup layer float escape stuck radar",
      run = function(ctx)
        local view, err = rex.call("session.view", { session_id = ctx.session_id })
        if err ~= nil then error(err, 0) end
        for _, w in ipairs(view.windows) do
          if w.active then
            for i = #w.layers, 1, -1 do
              local layer = w.layers[i]
              if layer.kind ~= "tiled" then
                local _, e = rex.call("session.close_layer",
                  { session_id = ctx.session_id, layer_id = layer.layer_id })
                if e ~= nil then error(e, 0) end
                return
              end
            end
          end
        end
      end,
    })
  '';
}
