--- === SemicolonNav ===
---
--- Hold semicolon to activate a vim-style navigation layer:
---   h → left arrow
---   j → down arrow
---   k → up arrow
---   l → right arrow
---
--- Tap semicolon alone to send semicolon.
--- Only applies to built-in keyboard (type 43).

local obj = {}
obj.__index = obj

-- Metadata
obj.name = 'SemicolonNav'
obj.version = '0.1'
obj.author = 'Paul Hinze'
obj.license = 'MIT'

-- Keyboard type for built-in MacBook keyboard
-- Note: This varies by machine. Use debug logging in init.lua to find yours.
local BUILTIN_KEYBOARD_TYPE = 91

-- Key codes
local KEY_SEMICOLON = 41
local KEY_H = 4
local KEY_J = 38
local KEY_K = 40
local KEY_L = 37

-- Navigation mapping
local NAV_KEYS = {
  [KEY_H] = 'left',
  [KEY_J] = 'down',
  [KEY_K] = 'up',
  [KEY_L] = 'right',
}

function obj:init()
  self.semicolonHeld = false
  self.layerUsed = false

  -- Timeout: if semicolon held longer than this, don't send semicolon on release
  local CANCEL_DELAY_SECONDS = 0.500
  self.cancelTimer = hs.timer.delayed.new(CANCEL_DELAY_SECONDS, function()
    print("SemicolonNav: timeout expired, marking as used")
    self.layerUsed = true  -- treat as "used" so we don't send semicolon
  end)

  -- Watch for semicolon key events
  self.semicolonTap = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
      -- Only process events from built-in keyboard
      local kbType = event:getProperty(hs.eventtap.event.properties.keyboardEventKeyboardType)
      if kbType ~= BUILTIN_KEYBOARD_TYPE then
        return false
      end

      local keyCode = event:getKeyCode()
      local eventType = event:getType()

      -- Handle semicolon
      if keyCode == KEY_SEMICOLON then
        if eventType == hs.eventtap.event.types.keyDown then
          -- Don't re-trigger on key repeat
          if self.semicolonHeld then
            return true  -- consume repeat events
          end
          print("SemicolonNav: semicolon DOWN")
          self.semicolonHeld = true
          self.layerUsed = false
          self.cancelTimer:start()
          return true  -- consume the semicolon keydown
        else  -- keyUp
          print(string.format("SemicolonNav: semicolon UP (held=%s, used=%s)", tostring(self.semicolonHeld), tostring(self.layerUsed)))
          self.cancelTimer:stop()
          local shouldSendSemicolon = self.semicolonHeld and not self.layerUsed
          self.semicolonHeld = false
          self.layerUsed = false
          if shouldSendSemicolon then
            print("SemicolonNav: sending semicolon")
            -- Use a short delay to avoid event loop issues
            hs.timer.doAfter(0.01, function()
              hs.eventtap.keyStrokes(';')
            end)
          end
          return true  -- consume the semicolon keyup
        end
      end

      -- Handle navigation keys when semicolon is held
      if self.semicolonHeld and eventType == hs.eventtap.event.types.keyDown then
        local arrowKey = NAV_KEYS[keyCode]
        if arrowKey then
          self.layerUsed = true
          -- Preserve modifiers (for shift+arrow selection, etc.)
          local flags = event:getFlags()
          local mods = {}
          if flags.shift then table.insert(mods, 'shift') end
          if flags.ctrl then table.insert(mods, 'ctrl') end
          if flags.alt then table.insert(mods, 'alt') end
          if flags.cmd then table.insert(mods, 'cmd') end
          hs.eventtap.keyStroke(mods, arrowKey, 0)
          return true  -- consume the original key
        end
      end

      return false  -- pass through other keys
    end
  )
end

--- SemicolonNav:start()
--- Method
--- Start the semicolon navigation layer
function obj:start()
  self.semicolonTap:start()
end

--- SemicolonNav:stop()
--- Method
--- Stop the semicolon navigation layer
function obj:stop()
  self.semicolonTap:stop()
  self.cancelTimer:stop()
  self.semicolonHeld = false
  self.layerUsed = false
end

return obj
