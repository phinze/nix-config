-- Hammerspoon configuration
-- Replaces Karabiner-Elements for keyboard remapping

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
-- Cmd+Tab -> Hyper+W (for Raycast Switch Windows)
--------------------------------------------------------------------------------
-- Intercept left-cmd+tab and send Ctrl+Option+Shift+Cmd+W instead

local cmdTabWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()

    -- Tab key = keycode 48
    -- Check for left-cmd only (not right-cmd)
    if keyCode == 48 and flags:containExactly({'cmd'}) then
        -- Send Hyper+W (Ctrl+Option+Shift+Cmd+W)
        hs.eventtap.keyStroke({'ctrl', 'alt', 'shift', 'cmd'}, 'w', 0)
        return true  -- consume the original event
    end

    return false  -- pass through other events
end)

cmdTabWatcher:start()

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
