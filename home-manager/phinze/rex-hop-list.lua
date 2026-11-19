-- Builds the session list for rig_hop in init.lua (rex.nix): every live
-- session on this Mac and its connected hosts, with agent status, ordered by
-- most-recent visit.
--
-- Reading status requires attaching to sessions and then detaching. Doing that
-- on the app's own connection breaks its terminal (409), so this runs in a
-- separate `rex do` process. That CLI must be preview.22 or newer, since focus
-- history requires API revision 19.
--
-- Also resolves each remote host's client_id for the calling app
-- (rex.args.client on this Mac). Switching to a remote session has to go
-- through that host, and client IDs are server-local, so we match by client
-- label across servers and ignore stale, disconnected entries.

-- Parses an RFC 3339 timestamp ("2026-11-19T16:38:23.79-06:00") into epoch
-- seconds so timestamps from hosts in different time zones compare directly.
local function epoch(t)
  local y, mo, d, h, mi, sec, rest = (t or ""):match(
    "^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)[%.%d]*(.*)$")
  if y == nil then return 0 end
  y, mo, d = tonumber(y), tonumber(mo), tonumber(d)
  -- Days from the civil date (Howard Hinnant's algorithm). os.time would
  -- interpret the date in the local time zone and ignore the offset.
  if mo <= 2 then y = y - 1 end
  local f = math.floor
  local era = f(y / 400)
  local yoe = y - era * 400
  local doy = f((153 * (mo + (mo > 2 and -3 or 9)) + 2) / 5) + d - 1
  local doe = yoe * 365 + f(yoe / 4) - f(yoe / 100) + doy
  local days = era * 146097 + doe - 719468
  local off = 0
  local sign, oh, om = rest:match("^([+-])(%d+):(%d+)$")
  if sign then
    off = (tonumber(oh) * 60 + tonumber(om)) * 60
    if sign == "-" then off = -off end
  end
  return days * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(sec) - off
end

-- Returns the most recently reported agent status in a session (or nil if
-- nothing reports one) and the active window's label, which rig sets to the
-- task title.
local function session_status(api, session_id)
  local a = api.call("session.attach", { session_id = session_id })
  local latest, title
  local view = (a and a.view) or {}
  for _, w in ipairs(view.windows or {}) do
    if w.window_id == view.active_window_id or title == nil then
      if w.label ~= nil and w.label ~= "" then title = w.label end
    end
  end
  for _, w in ipairs(view.windows or {}) do
    for _, layer in ipairs(w.layers or {}) do
      if layer.kind == "tiled" then
        for _, b in ipairs(layer.blocks or {}) do
          local r = api.block.call("com.superlogical.terminal", "program_status",
            { session_id = session_id, block_id = b.block_id })
          for _, rec in ipairs((r and r.records) or {}) do
            if rec.id == nil or rec.id == "" then
              local at = epoch(rec.updated_at)
              if latest == nil or at > latest.at then
                latest = { at = at, state = rec.state }
              end
            end
          end
        end
      end
    end
  end
  api.call("session.detach", { session_id = session_id })
  return latest, title
end

-- Formats agent state and age to match Rex's own switcher ("Done now",
-- "Idle 4m", "Working 2h").
local function agent_badge(state, secs)
  local age
  if secs < 60 then age = "now"
  elseif secs < 3600 then age = math.floor(secs / 60) .. "m"
  elseif secs < 86400 then age = math.floor(secs / 3600) .. "h"
  else age = math.floor(secs / 86400) .. "d" end
  state = state or "unknown"
  return state:sub(1, 1):upper() .. state:sub(2) .. " " .. age
end

-- Maps session_id => focus rank on a server (1 = currently focused), most
-- recent first, deduplicated. Returns empty if the server predates focus
-- history (Server preview.22, API revision 19).
local HISTORY_DEPTH = 100
local function visit_order(api)
  local order, n, cursor = {}, 0, nil
  for _ = 1, HISTORY_DEPTH do
    local ok, r = pcall(api.call, "focus_history.reverse", { cursor = cursor })
    if not ok or r == nil or not r.reversed then break end
    if r.session_id ~= nil and order[r.session_id] == nil then
      n = n + 1
      order[r.session_id] = n
    end
    if r.cursor == nil or r.cursor == cursor then break end
    cursor = r.cursor
  end
  return order
end

local function hop_sessions()
  local now = os.time()
  local apis = { { name = "Mac", api = rex, icon = "terminal" } }
  for _, name in ipairs(rex.servers()) do
    apis[#apis + 1] = { name = name, api = rex.server(name), icon = "server" }
  end
  local rows = {}
  for _, s in ipairs(apis) do
    -- Skip unreachable servers rather than failing the whole hop.
    pcall(function()
      local visited = visit_order(s.api)
      for _, sess in ipairs(s.api.call("session.list").sessions or {}) do
        local st, wtitle = session_status(s.api, sess.session_id)
        local name = (sess.label or ""):gsub("^[^%w]+", "")
        rows[#rows + 1] = {
          id = sess.session_id,
          server = s.api ~= rex and s.name or nil,
          title = wtitle or name,
          at = st and st.at or 0,
          visit = visited[sess.session_id],
          -- Omit the host name: the prompt is narrow and the icon already
          -- distinguishes remote sessions from local ones.
          subtitle = name,
          detail = st and agent_badge(st.state, now - st.at) or nil,
          icon = s.icon,
        }
      end
    end)
  end
  -- Visited sessions first (most recent visit), then unvisited by agent report
  -- time, then sessions with no agent alphabetically. Focus history has no
  -- timestamps, so rank ties across servers break by agent report time.
  table.sort(rows, function(a, b)
    if (a.visit ~= nil) ~= (b.visit ~= nil) then return a.visit ~= nil end
    if a.visit ~= b.visit then return a.visit < b.visit end
    if a.at ~= b.at then return a.at > b.at end
    return a.title < b.title
  end)
  return rows
end

local function app_label(client_id)
  for _, c in ipairs((rex.call("client.list", {}) or {}).clients or {}) do
    if c.client_id == client_id then return c.info and c.info.label end
  end
end

local function apps_by_server(label)
  local found = {}
  for _, name in ipairs(rex.servers()) do
    pcall(function()
      local mine, apps = {}, {}
      for _, c in ipairs((rex.server(name).call("client.list", {}) or {}).clients or {}) do
        local up = c.connection_state == nil or c.connection_state == "connected"
        if up and c.info and c.info.kind == "app" then
          apps[#apps + 1] = c.client_id
          if label ~= nil and c.info.label == label then mine[#mine + 1] = c.client_id end
        end
      end
      if #mine == 1 then found[name] = mine[1]
      elseif #mine == 0 and #apps == 1 then found[name] = apps[1] end
    end)
  end
  return found
end

local args = rex.args or {}
return { rows = hop_sessions(), apps = apps_by_server(app_label(args.client)) }
