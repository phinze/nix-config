-- Hammerspoon configuration
-- Replaces Karabiner-Elements for keyboard remapping

-- Enable IPC so the `hs` CLI can talk to Hammerspoon
require("hs.ipc")

--------------------------------------------------------------------------------
-- ControlEscape: Tap Control for Escape, Hold for Control
--------------------------------------------------------------------------------
-- Requires: System Preferences > Keyboard > Modifier Keys > Caps Lock -> Control
-- This spoon makes that remapped Control key send Escape when tapped alone
-- Only applies to built-in keyboard (type 43) - Moonlander handles this in firmware

hs.loadSpoon("ControlEscape")
spoon.ControlEscape:start()

--------------------------------------------------------------------------------
-- SemicolonNav: Hold semicolon for vim navigation layer (DISABLED)
--------------------------------------------------------------------------------
-- Hold ; + h/j/k/l → arrow keys (left/down/up/right)
-- Tap ; alone → semicolon
-- Only applies to built-in keyboard - Moonlander handles this in firmware
-- TODO: Fix semicolon tap not registering - keyStroke gets consumed by eventtap?

-- hs.loadSpoon("SemicolonNav")
-- spoon.SemicolonNav:start()

--------------------------------------------------------------------------------
-- HandyClicker: Logitech R400 → Handy transcribe toggle (opt+space)
--------------------------------------------------------------------------------
-- Black-screen button on the R400 sends `.`; we intercept it (scoped to the
-- R400's keyboardType) and translate to a single opt+space tap, which toggles
-- Handy recording on/off. Requires Handy's Push-to-Talk setting to be OFF.

hs.loadSpoon("HandyClicker")
spoon.HandyClicker:start()

--------------------------------------------------------------------------------
-- Window/App Switching
--------------------------------------------------------------------------------
-- Using rcmd (Mac App Store) instead of eventtap hacks
-- Right-Cmd + letter to switch apps

--------------------------------------------------------------------------------
-- Reload config automatically when files change
--------------------------------------------------------------------------------
function reloadConfig(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

local configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
configWatcher:start()

hs.alert.show("Hammerspoon config loaded")
