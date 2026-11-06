# Rex (Superlogical's terminal multiplexer) configuration.
#
# This writes ~/.config/rex/init.lua, which is Rex's whole account-level
# config: it binds keys with rex.bind, takes them away with rex.unbind, and
# adds command-palette entries with rex.action.
# On macOS Rex is installed from its own DMG rather than nixpkgs, so there is
# no package here, only the config file, the way ghostty.nix handles the
# Homebrew cask. On Linux it's a server only, installed system-wide by
# modules/nixos/rex.nix; a host gets the agent wiring below when that module
# runs its login server. The Mac's bindings work in foxtrotbase panes too
# (cmd+shift+r, seen 2026-11-04), and a Lua function bound on foxtrotbase also
# fires from the Mac (cmd+v, PERS-63), so foxtrotbase gets a small init.lua of
# its own for what only it can do.
{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  # What `rex skill setup` installs, declared here because setup edits
  # ~/.claude/settings.json and ~/.codex/hooks.json in place, and both are
  # ours. The stub defers to `rex __internal skill`, so the guide follows
  # whatever Rex is installed without a rebuild. The SessionStart hooks that
  # go with it live in claude-code.nix and codex.nix, beside the others.
  rexSkill = pkgs.writeText "rex-SKILL.md" ''
    ---
    name: rex
    description: Use the rex CLI to manage Rex sessions, open tabs, arrange panes, run commands, inspect terminal output, and control connected Rex apps.
    metadata:
      rex-stub: "2"
    ---

    Run `rex __internal skill` and follow the guide it prints. The guide comes from
    the installed Rex CLI, so it describes the commands available in that version.

    If the command fails, the installed Rex version predates the guide. Start with
    `rex whoami --json`, then use `rex --help` and `rex COMMAND --help`.
  '';
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  options.phinze.rex.enable = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    default = isDarwin || (osConfig.services.rex.loginServer.enable or false);
    description = "Whether this host runs Rex, so agents get its skill and session hooks.";
  };

  config = lib.mkMerge [
    (lib.mkIf config.phinze.rex.enable {
      # Pi reads ~/.claude/skills too, so these two cover every agent we run.
      home.file.".claude/skills/rex/SKILL.md".source = rexSkill;
      home.file.".codex/skills/rex/SKILL.md".source = rexSkill;
    })

    (lib.mkIf isDarwin {
      # Rex prepends its CLI's directory to every terminal's PATH and also exports
      # it as REX_BIN_DIR, which is the half that survives nix-darwin's PATH reset
      # in /etc/zshenv and fish's login init. Putting it back is Rex's own
      # guidance for that case, and it follows wherever the bundle keeps the CLI:
      # build 1203 renamed `Helpers/Rex Server.app` to `Rex Server.rex` and broke
      # the wrapper that used to live here by naming the path.
      programs.fish.shellInit = ''
        if set -q REX_BIN_DIR
          fish_add_path --global --path --prepend $REX_BIN_DIR
        end
      '';

      xdg.configFile."rex/init.lua".text = ''
        -- tmux muscle memory, rebuilt for rigs that live in Rex rather than tmux
        -- (see tmux.nix for the originals). The prefix is a one-shot mode, which
        -- Rex draws as a which-key popup listing what the next key does.

        -- rig radar, as a floating layer over the session the keypress happened
        -- in. The handler is handed that session, which is the one thing Rex's
        -- API will not tell a caller: focus is client-local state the server
        -- does not hold, so nothing else can ask "which session is on screen".
        --
        -- The layer is made here rather than by `rig radar --popup` because
        -- this action runs in the Mac's server even when the session lives on
        -- foxtrotbase. A rig run from here only knows the Mac's sessions, while
        -- rex.call goes to whichever server owns ctx.session_id, and the
        -- layer's shell starts on that host. So one path covers both: a Mac
        -- session gets the Mac's rig, a foxtrotbase session gets foxtrotbase's.
        -- The login shell is what puts rig on PATH on either host.
        --
        -- Unlike foxtrotbase's radar, this one hands rig the app's label
        -- rather than ctx.client_id. The id is the Mac as this Mac's server
        -- knows it, and means nothing to foxtrotbase, while every server
        -- sees the same label. rig needs it to switch the Mac on enter while
        -- the phone is also connected; without it rig falls back to
        -- switching the one connected app.
        local function client_label(ctx)
          local list = rex.call("client.list", {})
          for _, c in ipairs(list and list.clients or {}) do
            if c.client_id == ctx.client_id then return c.info and c.info.label end
          end
        end

        -- One radar per session. Pressing the key again replaces the radar
        -- rather than focusing it, because the server's focus calls don't move
        -- the focus on screen, and this way the new one always has it. Other
        -- sessions keep theirs, so one left open elsewhere can't get in the
        -- way here. A failed close is ignored: a spare radar beats no radar.
        local function close_radars(session_id)
          local view = rex.call("session.view", { session_id = session_id })
          for _, w in ipairs(view and view.windows or {}) do
            for _, layer in ipairs(w.layers or {}) do
              for _, b in ipairs(layer.blocks or {}) do
                if b.label == "radar" then
                  rex.call("session.close_layer",
                    { session_id = session_id, layer_id = layer.layer_id })
                  break
                end
              end
            end
          end
        end

        rex.action({
          name = "rig_radar",
          title = "Rig Radar",
          category = "Rig",
          keywords = "rig radar switch session hop",
          run = function(ctx)
            close_radars(ctx.session_id)
            local _, err = rex.call("session.new_layer", {
              session_id = ctx.session_id,
              bounds = { 0.1, 0.1, 0.8, 0.8 },
              focus = true,
              layout = rex.layout.block({
                flavor = "com.superlogical.terminal.shell",
                label = "radar",
                options = {
                  command = { "/bin/sh", "-lc", "RIG_REX_CLIENT_LABEL='"
                    .. (client_label(ctx) or ""):gsub("'", "") .. "' RIG_RADAR_BG='#181825' rig radar" },
                  exit = { on_completion = true },
                  theme = { background = "#181825", foreground = "#cdd6f4" },
                },
              }),
            })
            if err ~= nil then error(err, 0) end
          end,
        })

        -- The foreground program of the block a key landed in, with nix's
        -- .foo-wrapped and .foo-unwrapped dressing stripped.
        local function foreground(ctx)
          if not ctx.block_id then return nil end
          local p = rex.call("com.superlogical.terminal.process",
            { session_id = ctx.session_id, block_id = ctx.block_id })
          local name = p and p.foreground and p.foreground.name
          if not name then return nil end
          return (name:gsub("^%.", ""):gsub("%-unwrapped$", ""):gsub("%-wrapped$", ""))
        end

        rex.mode("prefix", { exclusive = true })

        -- A block running tmux gets its prefix and navigator keys handed straight
        -- down the pty, so tmux keeps owning them. ssh and mosh don't count: a
        -- plain ssh to a host has no tmux to hand them to, and passing them
        -- along left no way to change panes. Over ssh, ctrl+a a reaches a remote
        -- tmux, and ctrl+hjkl move Rex panes even when the remote program is nvim.
        local function nested(fg)
          return fg == "tmux"
        end
        local function passthrough(ctx, byte)
          rex.call("com.superlogical.terminal.write",
            { session_id = ctx.session_id, block_id = ctx.block_id, args = { data = byte } })
        end

        -- Both keys below are Lua actions rather than plain bindings because
        -- they choose at press time. rex.client.queue is how an action asks the
        -- client to do the other branch, and it only works inside an action (a
        -- bare function bound to a key errors).
        rex.action({
          name = "leader",
          title = "Leader",
          category = "Keys",
          run = function(ctx)
            if nested(foreground(ctx)) then
              passthrough(ctx, "\1")
            else
              rex.client.queue("client.mode.enter", { name = "prefix", once = true })
            end
          end,
        })
        rex.bind("ctrl+a", "leader")

        -- ctrl+hjkl is vim-tmux-navigator with Rex standing in for tmux. In nvim
        -- the key goes to nvim, which moves between its own splits and calls
        -- `rex do pane.focus.*` at its edges (nixvim-config does that half).
        --
        -- One trap found the hard way: don't reach for session.focus_direction,
        -- which moves the server's focus rather than the client-local focus on
        -- screen. The keys are bound physically ([KeyJ]) because that's what was
        -- in place when this first worked; the logical form may be fine, but it
        -- hasn't been retested.
        local ctrl_byte = { h = "\8", j = "\10", k = "\11", l = "\12" }
        for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
          rex.action({
            name = "nav_" .. dir,
            title = "Navigate " .. dir:gsub("^%l", string.upper),
            category = "Keys",
            run = function(ctx)
              local fg = foreground(ctx)
              if nested(fg) or fg == "nvim" then
                passthrough(ctx, ctrl_byte[key])
              else
                rex.client.queue("pane.focus", { direction = dir })
              end
            end,
          })
          rex.bind("ctrl+[Key" .. key:upper() .. "]", "nav_" .. dir)
          rex.bind("prefix/" .. key, "pane.focus." .. dir)
          rex.bind("prefix/shift+" .. key, "pane.resize", { direction = dir, amount = 5 })
        end

        rex.bind("cmd+shift+r", "rig_radar")
        rex.bind("prefix/r", "rig_radar")
        rex.bind("prefix/t", "session.switch")
        rex.bind("prefix/s", "pane.split.down")
        rex.bind("prefix/v", "pane.split.right")
        rex.bind("prefix/ctrl+s", "pane.split.down")
        rex.bind("prefix/ctrl+v", "pane.split.right")
        rex.bind("prefix/z", "pane.zoom")
        rex.bind("prefix/x", "pane.close")
        rex.bind("prefix/shift+b", "pane.move_to_new_tab")
        rex.bind("prefix/c", "client.tab.new")
        rex.bind("prefix/n", "client.tab.next")
        rex.bind("prefix/p", "client.tab.previous")
        rex.bind("prefix/,", "client.tab.rename")
        rex.bind("prefix/shift+4", "session.rename")
        rex.bind("prefix/shift+r", "client.config.reload")
        rex.bind("prefix/a", "pane.send_key", { key = "ctrl+a" })
        rex.bind("prefix/ctrl+a", "pane.send_key", { key = "ctrl+a" })
        for i = 1, 9 do
          rex.bind("prefix/" .. i, "client.tab.goto", { index = i })
        end
        rex.bind("prefix/escape", "client.mode.exit")

        -- No cmd+w. It's File > Close, which destroys the whole session without
        -- asking, and it sits one modifier away from ctrl+w (delete word). Two
        -- sessions lost to that slip mid-typing. The menu item stays for when
        -- closing a session is actually the point.
        rex.unbind("cmd+w")

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
              if w.window_id == view.active_window_id then
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
    })

    (lib.mkIf (config.phinze.rex.enable && !isDarwin && osConfig.networking.hostName == "foxtrotbase") {
      xdg.configFile."rex/init.lua".text = ''
        -- rig radar for the phone, whose only server is this one. The Mac
        -- shows its own radar from its own init.lua, so this one is the
        -- iPhone's (probed on Rex for iOS 1542). It's a tab rather than the
        -- Mac's floating layer because iOS doesn't draw layers, and the
        -- action moves the phone to the tab itself because a new window
        -- doesn't take focus on a client. ctx.client_id is the phone as this
        -- server knows it, which rig needs to switch it on enter while the
        -- Mac is also connected.
        rex.action({
          name = "rig_radar",
          title = "Rig Radar",
          category = "Rig",
          keywords = "rig radar switch session hop",
          run = function(ctx)
            -- One radar tab per session, as on the Mac: a new one replaces any
            -- already open, and a failed close still leaves a radar to use.
            local view = rex.call("session.view", { session_id = ctx.session_id })
            for _, w in ipairs(view and view.windows or {}) do
              if w.label == "radar" then
                rex.call("session.close_window",
                  { session_id = ctx.session_id, window_id = w.window_id })
              end
            end

            local win, err = rex.call("session.new_window", {
              session_id = ctx.session_id,
              window_label = "radar",
              focus = true,
              layout = rex.layout.block({
                flavor = "com.superlogical.terminal.shell",
                label = "radar",
                options = {
                  command = { "/bin/sh", "-lc", "RIG_REX_CLIENT='" .. (ctx.client_id or "") .. "' rig radar" },
                  exit = { on_completion = true },
                },
              }),
            })
            if err ~= nil then error(err, 0) end
            rex.client.queue("session.select", { session_id = ctx.session_id, window_id = win.window_id })
          end,
        })
      '';
      # The server reads init.lua once, so a deploy has to tell it to look
      # again. It may be down mid-switch; it reads the file when it starts.
      xdg.configFile."rex/init.lua".onChange = ''
        ${osConfig.services.rex.package}/bin/rex config reload --autostart=false || true
      '';
    })
  ];
}
