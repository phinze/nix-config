# Rex (Superlogical's terminal multiplexer) configuration.
#
# This writes ~/.config/rex/init.lua, which is Rex's whole account-level
# config: it binds keys with rex.bind, takes them away with rex.unbind, and
# adds command-palette entries with rex.action.
# On macOS Rex is installed from its own DMG rather than nixpkgs, so there is
# no package here, only the config file, the way ghostty.nix handles the
# Homebrew cask. On Linux it's a server only, installed system-wide by
# modules/nixos/rex.nix; a host gets the agent wiring below when that module
# runs its login server. A key pressed in a pane runs that pane's server's
# init.lua (probed 2026-10-22, PERS-63), so foxtrotbase gets a small one of
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
        rex.action({
          name = "rig_radar",
          title = "Rig Radar",
          category = "Rig",
          keywords = "rig radar switch session hop",
          run = function(ctx)
            local _, err = rex.call("session.new_layer", {
              session_id = ctx.session_id,
              bounds = { 0.1, 0.1, 0.8, 0.8 },
              focus = true,
              layout = rex.layout.block({
                flavor = "com.superlogical.terminal.shell",
                options = {
                  command = { "/bin/sh", "-lc", "RIG_RADAR_BG='#181825' rig radar" },
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
        local bankshot = "${config.home.profileDirectory}/bin/bankshot"

        -- cmd+v with an image, or a copied recording, on the Mac's clipboard.
        -- Rex can't paste either into a pane on this host: an image becomes a
        -- bare "v", and a file becomes its Mac path. So bankshot fetches it
        -- into its inbox here, and that path is pasted instead, bracketed so
        -- Claude Code attaches an image. With neither, returning nothing
        -- leaves the key to Rex's own paste. The Mac is the one pressing the
        -- key, so it's awake; still, every cmd+v here costs a round trip to
        -- it, and the timeout leaves room for a long recording.
        rex.bind("cmd+v", function(ctx)
          local r = rex.exec({ bankshot, "paste" }, { timeout = 60 })
          if not (r and r.ok) then return end
          local path = r.stdout:gsub("%s+$", "")
          rex.call("com.superlogical.terminal.write", {
            session_id = ctx.session_id,
            block_id = ctx.block_id,
            args = { data = "\27[200~" .. path .. "\27[201~" },
          })
          return true
        end)
      '';
      # The server reads init.lua once, so a deploy has to tell it to look
      # again. It may be down mid-switch; it reads the file when it starts.
      xdg.configFile."rex/init.lua".onChange = ''
        ${osConfig.services.rex.package}/bin/rex config reload --autostart=false || true
      '';
    })
  ];
}
