--[[
  Nock 3.10.0: flight paths.

  Every flight point for your faction (and neutral ones) as a pin on the zone
  maps and the minimap (Hunter map pins, kind "flight"), and on the
  Kalimdor / Eastern Kingdoms map as small square markers joined by thin
  route lines. Hover a pin or marker: flight point, flight master, zone,
  whether you have discovered it, and where it flies.

  Discovered: Nock remembers the flight points you know each time a flight
  master's map opens (TAXIMAP_OPENED: C_TaxiMap.GetAllTaxiNodes, plus
  NumTaxiNodes / TaxiNodeName / TaxiNodeGetType). Kept per character in
  NockCharDB.flights.known; nothing else is read or written. Until the first
  flight map opens Nock does not know, and says so instead of guessing.

  Data: Data_Flights.lua (tools/flights/gen_flights.py): Forever 1.60.1
  client TaxiNodes / TaxiPath, each node matched to its QuestieDB Forever
  flight master. Nodes with no matching flight master are left out.

  /nock flights on | off           pins and routes
  /nock flights routes on | off    route lines on the continent map
  /nock flights other on | off     the other faction's flight paths too
]]

local Nock = _G.Nock
local Pins = Nock and Nock.Pins
if not (Nock and Pins and Pins.KINDS) then
  return
end

local F = {}
Nock.Flights = F

local KIND = 0
for i, k in ipairs(Pins.KINDS) do
  if k.id == "flight" then
    KIND = i
  end
end
local KDEF = Pins.KINDS[KIND]
local COLOR = { 0.70, 0.78, 0.86 }
local CONTINENTS = { [1414] = true, [1415] = true }

-- Settings -----------------------------------------------------------------------

local function DB()
  _G.NockCharDB = _G.NockCharDB or {}
  local db = _G.NockCharDB
  if type(db.flights) ~= "table" then
    db.flights = {}
  end
  if type(db.flights.known) ~= "table" then
    db.flights.known = {}
  end
  return db.flights
end

function F.PinsOn()
  return Pins.IsOn() and Pins.KindOn("flight")
end
function F.RoutesOn()
  return DB().routes ~= false
end
function F.OtherOn()
  return DB().other == true
end
function F.Synced()
  return DB().synced == true
end
function F.Known(id)
  return DB().known[id] == true
end

local function Say(msg)
  if Nock.Core and Nock.Core.Say then
    Nock.Core.Say(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Nock: " .. tostring(msg))
  end
end

-- Data -----------------------------------------------------------------------------

local nodes, links -- nodes[id] = { id, name, fac, map, x, y, cmap, cx, cy, npc, npcId }; links[id] = { otherId, ... }
local function Build()
  if nodes then
    return
  end
  nodes, links = {}, {}
  local d = Nock.FlightData
  if not d then
    return
  end
  for id, r in pairs(d.nodes) do
    nodes[id] = { id = id, name = r[1], fac = r[2], map = r[3], x = r[4] / 100, y = r[5] / 100,
      cmap = r[6], cx = r[7] / 100, cy = r[8] / 100, npc = r[9], npcId = r[10] }
    links[id] = {}
  end
  local rt = d.routes
  for i = 1, #rt - 1, 2 do
    local a, b = rt[i], rt[i + 1]
    if nodes[a] and nodes[b] then
      table.insert(links[a], b)
      table.insert(links[b], a)
    end
  end
end
F.Build = Build

function F.Nodes()
  Build()
  return nodes
end
function F.Links(id)
  Build()
  return links[id] or {}
end

local function PlayerFac()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
end

-- Shown for this character: own faction and neutral, the other faction only when asked.
function F.ShowsNode(n)
  local mine = PlayerFac()
  if not mine or n.fac:find(mine, 1, true) then
    return true
  end
  return F.OtherOn()
end

function F.FactionText(fac)
  if fac == "AH" then
    return "Neutral (both factions)"
  end
  return fac == "A" and "Alliance" or "Horde"
end

-- Tooltip lines (also used by the zone map / minimap pins).
function F.TipLines(n)
  local out = {}
  out[#out + 1] = { "Flight master: " .. (n.npc or "?"), 0.86, 0.86, 0.82 }
  out[#out + 1] = { F.FactionText(n.fac), 0.62, 0.68, 0.62 }
  if not F.Synced() then
    out[#out + 1] = { "Discovered: open any flight master's map once so Nock can check", 0.62, 0.62, 0.62 }
  elseif F.Known(n.id) then
    out[#out + 1] = { "Discovered", 0.45, 0.95, 0.55 }
  else
    out[#out + 1] = { "Not discovered yet", 1.0, 0.78, 0.30 }
  end
  local to = {}
  for _, o in ipairs(F.Links(n.id)) do
    local m = nodes[o]
    if m and F.ShowsNode(m) then
      to[#to + 1] = m.name:match("^([^,]+)") or m.name
    end
  end
  if #to > 0 then
    table.sort(to)
    local shown = {}
    for i = 1, math.min(#to, 6) do
      shown[i] = to[i]
    end
    local s = "Flies to " .. table.concat(shown, ", ")
    if #to > 6 then
      s = s .. string.format(" +%d more", #to - 6)
    end
    out[#out + 1] = { s, 0.70, 0.78, 0.86 }
  end
  return out
end

-- Pins (zone maps and minimap) ------------------------------------------------------

-- The old flight master rows in PinsData.lua are replaced by Data_Flights.lua.
if type(Nock.PinData) == "table" then
  local keep = {}
  for _, row in ipairs(Nock.PinData) do
    if row[1] ~= KIND then
      keep[#keep + 1] = row
    end
  end
  Nock.PinData = keep
end

if KDEF then
  KDEF.filter = function(e)
    local n = e.flight
    if not n or not F.ShowsNode(n) then
      return false
    end
    e.dim = F.Synced() and not F.Known(n.id) or nil
    return true
  end
  KDEF.tip = function(e)
    local lines = {}
    for _, l in ipairs(F.TipLines(e.flight)) do
      lines[#lines + 1] = string.format("|cff%02x%02x%02x%s|r", l[2] * 255, l[3] * 255, l[4] * 255, l[1])
    end
    return lines
  end
  Build()
  local rows = {}
  for _, n in pairs(nodes) do
    -- fac "AH" so the pin filter, not the shared hostile switch, decides.
    rows[#rows + 1] = { kind = KIND, fac = "AH", map = n.map, x = n.x, y = n.y, name = n.name,
      title = "Flight path", flight = n }
  end
  table.sort(rows, function(a, b) return a.flight.id < b.flight.id end)
  Pins.AddEntries(rows)
end

-- Discovered flight points ---------------------------------------------------------

local function MarkByName(name)
  if type(name) ~= "string" then
    return false
  end
  local mine = PlayerFac()
  local hit = false
  for id, n in pairs(F.Nodes()) do
    if n.name == name and (not mine or n.fac:find(mine, 1, true)) then
      DB().known[id] = true
      hit = true
    end
  end
  return hit
end

-- Reads the open flight map. Returns how many known points it saw.
function F.Sync()
  local db = DB()
  local seen = 0
  local TM = C_TaxiMap
  if TM and TM.GetAllTaxiNodes and GetTaxiMapID then
    local okm, mapID = pcall(GetTaxiMapID)
    local ok, list = pcall(TM.GetAllTaxiNodes, okm and mapID or nil)
    if ok and type(list) == "table" then
      local unreachable = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
      for _, info in ipairs(list) do
        if type(info) == "table" and info.state ~= unreachable then
          local id = tonumber(info.nodeID)
          if id and F.Nodes()[id] then
            db.known[id] = true
            seen = seen + 1
          elseif MarkByName(info.name) then
            seen = seen + 1
          end
        end
      end
    end
  end
  if NumTaxiNodes and TaxiNodeName and TaxiNodeGetType then
    local ok, n = pcall(NumTaxiNodes)
    for i = 1, (ok and tonumber(n) or 0) do
      local okt, kind = pcall(TaxiNodeGetType, i)
      if okt and (kind == "CURRENT" or kind == "REACHABLE" or kind == "DISTANT") then
        local okn, name = pcall(TaxiNodeName, i)
        if okn and MarkByName(name) then
          seen = seen + 1
        end
      end
    end
  end
  if seen > 0 then
    db.synced = true
  end
  F.Refresh()
  return seen
end

function F.Counts()
  local total, known = 0, 0
  for id, n in pairs(F.Nodes()) do
    if F.ShowsNode(n) then
      total = total + 1
      if F.Known(id) then
        known = known + 1
      end
    end
  end
  return known, total
end

-- Continent map: route lines and node markers ------------------------------------------

local provider
local host
local lines, marks = {}, {}

local function Clear()
  for _, l in ipairs(lines) do
    l:Hide()
  end
  for _, m in ipairs(marks) do
    m:Hide()
    m.node = nil
  end
end

local function Scale(map)
  local cs = (map.GetCanvasScale and map:GetCanvasScale()) or 1
  return 1 / math.max(0.01, cs)
end

local function LineColor(a, b, hot)
  local both = F.Synced() and F.Known(a.id) and F.Known(b.id)
  local alpha = hot and 0.9 or ((both or not F.Synced()) and 0.45 or 0.2)
  return COLOR[1], COLOR[2], COLOR[3], alpha
end

local function Highlight(id)
  for _, l in ipairs(lines) do
    if l:IsShown() and l.a then
      local hot = id and (l.a.id == id or l.b.id == id)
      l:SetColorTexture(LineColor(l.a, l.b, hot))
    end
  end
end

local function MarkEnter(m)
  if not (m.node and GameTooltip) then
    return
  end
  GameTooltip:SetOwner(m, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine(m.node.name, 1, 1, 1)
  for _, l in ipairs(F.TipLines(m.node)) do
    GameTooltip:AddLine(l[1], l[2], l[3], l[4], true)
  end
  local zone = Pins.ZoneName and Pins.ZoneName(m.node.map) or ""
  GameTooltip:AddLine(string.format("%s  %.0f, %.0f", zone, m.node.x * 100, m.node.y * 100), 0.62, 0.68, 0.62)
  GameTooltip:Show()
  Highlight(m.node.id)
end

local function MarkLeave()
  if GameTooltip then
    GameTooltip:Hide()
  end
  Highlight(nil)
end

local function Mark(i, parent)
  local m = marks[i]
  if not m then
    m = CreateFrame("Frame", nil, parent)
    m:EnableMouse(true)
    m.edge = m:CreateTexture(nil, "OVERLAY", nil, 1)
    m.edge:SetAllPoints()
    m.edge:SetColorTexture(0.05, 0.06, 0.06, 0.95)
    m.fill = m:CreateTexture(nil, "OVERLAY", nil, 2)
    m:SetScript("OnEnter", MarkEnter)
    m:SetScript("OnLeave", MarkLeave)
    marks[i] = m
  end
  if m:GetParent() ~= parent then
    m:SetParent(parent)
  end
  return m
end

-- Pure: which markers and lines to draw on a continent map (tested).
function F.Layout(mapID)
  local pts, segs = {}, {}
  if not CONTINENTS[mapID] then
    return pts, segs
  end
  for id, n in pairs(F.Nodes()) do
    if n.cmap == mapID and F.ShowsNode(n) then
      pts[#pts + 1] = n
    end
  end
  table.sort(pts, function(a, b) return a.id < b.id end)
  if F.RoutesOn() then
    for _, a in ipairs(pts) do
      for _, bid in ipairs(F.Links(a.id)) do
        local b = nodes[bid]
        if b and a.id < b.id and b.cmap == mapID and F.ShowsNode(b) then
          segs[#segs + 1] = { a, b }
        end
      end
    end
  end
  return pts, segs
end

local function Draw()
  Clear()
  if not (provider and provider:GetMap()) then
    return
  end
  local map = provider:GetMap()
  local mapID = map:GetMapID()
  if not CONTINENTS[mapID] or not (F.PinsOn() or F.RoutesOn()) then
    return
  end
  local canvas = map:GetCanvas()
  local cw, ch = canvas:GetWidth() or 1, canvas:GetHeight() or 1
  local sc = Scale(map)
  host = host or CreateFrame("Frame", nil, canvas)
  if host:GetParent() ~= canvas then
    host:SetParent(canvas)
  end
  host:SetAllPoints(canvas)
  host:SetFrameLevel(math.min(9000, canvas:GetFrameLevel() + 2000))
  host:Show()
  local pts, segs = F.Layout(mapID)
  if host.CreateLine then
    for i, s in ipairs(segs) do
      local l = lines[i]
      if not l then
        l = host:CreateLine(nil, "ARTWORK")
        lines[i] = l
      end
      l.a, l.b = s[1], s[2]
      l:SetColorTexture(LineColor(s[1], s[2], false))
      l:SetThickness(1.5 * sc)
      l:SetStartPoint("TOPLEFT", host, cw * s[1].cx, -ch * s[1].cy)
      l:SetEndPoint("TOPLEFT", host, cw * s[2].cx, -ch * s[2].cy)
      l:Show()
    end
  end
  if not F.PinsOn() then
    return
  end
  local size = 9 * sc
  for i, n in ipairs(pts) do
    local m = Mark(i, host)
    m.node = n
    m:SetSize(size, size)
    m:ClearAllPoints()
    m:SetPoint("CENTER", host, "TOPLEFT", cw * n.cx, -ch * n.cy)
    m:SetFrameLevel(host:GetFrameLevel() + 5)
    m.fill:ClearAllPoints()
    m.fill:SetPoint("TOPLEFT", sc * 1.5, -sc * 1.5)
    m.fill:SetPoint("BOTTOMRIGHT", -sc * 1.5, sc * 1.5)
    local mine = PlayerFac()
    local other = mine and not n.fac:find(mine, 1, true)
    if other then
      m.fill:SetColorTexture(0.55, 0.55, 0.55, 0.9)
    elseif F.Synced() and not F.Known(n.id) then
      m.fill:SetColorTexture(0.28, 0.30, 0.32, 0.95) -- not discovered: hollow-looking
    else
      m.fill:SetColorTexture(COLOR[1], COLOR[2], COLOR[3], 1)
    end
    m:Show()
  end
end

local function HookWorldMap()
  if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin and CreateFromMixins) then
    return
  end
  provider = CreateFromMixins(MapCanvasDataProviderMixin)
  function provider:RemoveAllData()
    Clear()
  end
  function provider:RefreshAllData()
    local ok, err = pcall(Draw)
    if not ok then
      F.lastError = err
    end
  end
  function provider:OnCanvasScaleChanged()
    pcall(Draw)
  end
  function provider:OnCanvasSizeChanged()
    pcall(Draw)
  end
  WorldMapFrame:AddDataProvider(provider)
end
F.HookWorldMap = HookWorldMap

function F.Refresh()
  if Pins.Refresh then
    pcall(Pins.Refresh)
  end
  if provider and WorldMapFrame and WorldMapFrame:IsShown() then
    pcall(Draw)
  end
end

-- Public ---------------------------------------------------------------------------

function F.SetOn(on)
  Pins.SetKind("flight", on)
  DB().routes = on and true or false
  if on and not Pins.IsOn() then
    Pins.SetOn(true)
  end
  F.Refresh()
end
function F.SetRoutes(on)
  DB().routes = on and true or false
  F.Refresh()
end
function F.SetOther(on)
  DB().other = on and true or false
  F.Refresh()
end

function F.Status()
  local known, total = F.Counts()
  local disc = F.Synced() and string.format("%d of %d discovered", known, total)
    or "open any flight master's map once to check which you know"
  return string.format("Flight paths: pins %s, routes %s, other faction %s. %d flight points; %s.",
    F.PinsOn() and "on" or "off", F.RoutesOn() and "on" or "off", F.OtherOn() and "on" or "off", total, disc)
end

function F.Slash(rest)
  rest = rest or ""
  local a, b = rest:match("^(%S*)%s*(%S*)")
  if a == "on" or a == "off" then
    F.SetOn(a == "on")
  elseif a == "routes" and (b == "on" or b == "off") then
    F.SetRoutes(b == "on")
  elseif (a == "other" or a == "hostile") and (b == "on" or b == "off") then
    F.SetOther(b == "on")
  elseif a ~= "" then
    Say("/nock flights on | off   /nock flights routes on | off   /nock flights other on | off")
  end
  Say(F.Status())
end

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg)
    local m = string.lower(strtrim and strtrim(msg or "") or (msg or ""))
    local cmd, rest = m:match("^(%S+)%s*(.*)$")
    if cmd == "flights" or cmd == "flight" or cmd == "fp" then
      return F.Slash(rest)
    end
    baseSlash(msg)
    if m == "help" then
      Say("/nock flights on | off — flight paths on the maps   /nock flights routes | other on | off")
    end
  end
end

local ev = CreateFrame and CreateFrame("Frame")
if ev then
  for _, e in ipairs({ "PLAYER_LOGIN", "TAXIMAP_OPENED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
      HookWorldMap()
    elseif event == "TAXIMAP_OPENED" then
      pcall(F.Sync)
    end
  end)
end
