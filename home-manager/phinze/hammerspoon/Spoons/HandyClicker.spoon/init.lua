--- === HandyClicker ===
---
--- Logitech R400 → Handy controls.
---   Black-screen button (`.`) → opt+space tap (toggles Handy transcription)
---   Start/Stop button (F5 or Escape) → Escape tap (cancels Handy)
--- Scoped by keyboardType so the same keys from other keyboards pass through.
--- Assumes Handy's Push-to-Talk is OFF, so opt+space is tap-to-toggle.

local obj = {}
obj.__index = obj

obj.name = "HandyClicker"
obj.version = "0.3"
obj.author = "Paul Hinze <paul@miren.dev>"
obj.license = "MIT"

local R400_KB_TYPE = 40
local PERIOD = hs.keycodes.map["."]
local F5 = hs.keycodes.map["f5"]
local ESCAPE = hs.keycodes.map["escape"]

function obj:init()
  self.tap = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
    function(e)
      if e:getProperty(hs.eventtap.event.properties.keyboardEventKeyboardType) ~= R400_KB_TYPE then
        return false
      end
      local kc = e:getKeyCode()
      local isDown = e:getType() == hs.eventtap.event.types.keyDown
      local autorepeat = e:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1
      local fireOnce = isDown and not autorepeat

      if kc == PERIOD then
        if fireOnce then hs.eventtap.keyStroke({ "alt" }, "space", 0) end
        return true
      elseif kc == F5 or kc == ESCAPE then
        if fireOnce then hs.eventtap.keyStroke({}, "escape", 0) end
        return true
      end

      return false
    end
  )
end

function obj:start()
  self.tap:start()
  return self
end

function obj:stop()
  self.tap:stop()
  return self
end

return obj
