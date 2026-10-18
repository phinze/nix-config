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
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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

  # Pi reads ~/.claude/skills too, so these two cover every agent we run.
  home.file.".claude/skills/rex/SKILL.md".source = rexSkill;
  home.file.".codex/skills/rex/SKILL.md".source = rexSkill;

  xdg.configFile."rex/init.lua".text = ''
    -- tmux muscle memory, rebuilt for rigs that live in Rex rather than tmux
    -- (see tmux.nix for the originals). The prefix is a one-shot mode, which
    -- Rex draws as a which-key popup listing what the next key does.

    local rig = "${config.home.profileDirectory}/bin/rig"

    -- rig radar. The handler is handed the session the keypress happened in,
    -- which is the one thing Rex's API will not tell a caller: focus is
    -- client-local state the server does not hold, so nothing else can ask
    -- "which session is on screen". Passing it to rig as REX_SESSION means rig
    -- opens the board over the session you are actually looking at, and rig
    -- stays the only place that knows how to size, paint, and place the layer.
    --
    -- rex.exec waits, but rig returns as soon as the layer exists, and the
    -- server keeps handling keys while a config action waits. preview.15
    -- took os.execute away in favour of it.
    rex.action({
      name = "rig_radar",
      title = "Rig Radar",
      category = "Rig",
      keywords = "rig radar switch session hop",
      run = function(ctx)
        rex.exec({ rig, "radar", "--popup" },
          { env = { REX_SESSION = ctx.session_id }, stdout = false, stderr = false })
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

    -- A block ssh'd into foxtrotbase's tmux gets its prefix and navigator
    -- keys handed straight down the pty, so the remote tmux keeps owning them.
    local function nested(fg)
      return fg == "ssh" or fg == "mosh-client" or fg == "tmux"
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
}
