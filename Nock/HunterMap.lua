--[[
  Nock 3.3.0: hunter map pins.

  Hunter trainers, pet trainers, stable masters and ammo vendors on the
  minimap and the world map, for your faction. On by default, nothing to set
  up. The client has no API for NPC locations, so the spots come from the
  built-in list in PinsData.lua.

  Minimap: pins in range sit where the NPC stands (zoom, indoor/outdoor and a
  rotating minimap are handled). The nearest one of each kind that is out of
  range stays pinned to the minimap edge, dimmed, so you always know which way
  to go. Updates are throttled to 10 a second and skip work when you have not
  moved.

  World map: a map data provider places pins on the zone you are viewing.

  /nock pins                        all pins on or off
  /nock pins trainer|pet|stable|ammo  one kind on or off
  /nock pins minimap | map          minimap or world map pins on or off
  /nock pins hostile                also show the other faction's NPCs
]]

local Nock = _G.Nock
if not Nock then
  return
end

local Pins = {}
Nock.Pins = Pins

local TEX = "Interface\\AddOns\\Nock\\Media\\Textures\\pins\\"

Pins.KINDS = {
  { id = "trainer", label = "Hunter trainers", role = "Hunter Trainer", tex = TEX .. "pin_trainer", color = { 0.91, 0.76, 0.35 } },
  { id = "pet", label = "Pet trainers", role = "Pet Trainer", tex = TEX .. "pin_pet", color = { 0.37, 0.83, 0.54 } },
  { id = "stable", label = "Stable masters", role = "Stable Master", tex = TEX .. "pin_stable", color = { 0.82, 0.56, 0.30 } },
  { id = "ammo", label = "Ammo vendors", role = "Ammo vendor", tex = TEX .. "pin_ammo", color = { 0.50, 0.71, 0.90 } },
}
local KIND_BY_ID = {}
for i, k in ipairs(Pins.KINDS) do
  KIND_BY_ID[k.id] = i
end
local extraRows = {} -- pins added by other Nock tools (3.4.0: rare tameable beasts)

local MINI_SIZE = 18
local MINI_EDGE_SIZE = 14
local WORLD_SIZE = 22
local EDGE_MAX_YARDS = 1500
local TICK = 0.1

-- Settings --------------------------------------------------------------------

local function Opt()
  _G.NockCharDB = _G.NockCharDB or {}
  local db = _G.NockCharDB
  if type(db.pins) ~= "table" then
    db.pins = {}
  end
  return db.pins
end

local function Peek()
  local db = _G.NockCharDB
  return (db and type(db.pins) == "table") and db.pins or {}
end

function Pins.IsOn()
  return Peek().on ~= false
end
function Pins.KindOn(id)
  local hide = Peek().hide
  return not (type(hide) == "table" and hide[id])
end
function Pins.MinimapOn()
  return Peek().minimap ~= false
end
function Pins.WorldOn()
  return Peek().world ~= false
end
function Pins.HostileOn()
  return Peek().hostile == true
end

local function Say(msg)
  if Nock.Print then
    Nock.Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Nock: " .. tostring(msg))
  end
end

-- Data --------------------------------------------------------------------------

local entries -- built once: { kind, fac, map, x, y, name, title, goods, wx, wy, inst }
local visible = {} -- filtered by faction and kind
local byMap = {}
local worldDone = false

local function Build()
  if entries then
    return
  end
  entries = {}
  for _, row in ipairs(Nock.PinData or {}) do
    entries[#entries + 1] = {
      kind = row[1], fac = row[2], map = row[3], x = row[4] / 100, y = row[5] / 100,
      name = row[6], title = row[7], goods = row[8] or "",
    }
  end
  for _, e in ipairs(extraRows) do
    entries[#entries + 1] = e
  end
end

--[[ 3.4.0: other tools add their own pin kinds.
  def = { id, label, role, tex, color, filter = function(e) return show end,
          tip = function(e) return { "line", ... } end }
  Returns the kind number to use in Pins.AddEntries rows. ]]
function Pins.AddKind(def)
  if KIND_BY_ID[def.id] then
    return KIND_BY_ID[def.id]
  end
  Pins.KINDS[#Pins.KINDS + 1] = def
  KIND_BY_ID[def.id] = #Pins.KINDS
  return #Pins.KINDS
end

-- rows: { kind = n, fac = "AH", map = uiMapID, x = 0-1, y = 0-1, name = "...", title = "...", data = any }
function Pins.AddEntries(rows)
  for _, e in ipairs(rows) do
    e.goods = e.goods or ""
    e.fac = e.fac or "AH"
    extraRows[#extraRows + 1] = e
    if entries then
      entries[#entries + 1] = e
    end
  end
  worldDone = false
end

-- World (yard) positions are only available once the map system is up.
local function ResolveWorld()
  if worldDone or not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
    return
  end
  Build()
  for _, e in ipairs(entries) do
    if not e.tried then
      e.tried = true
      local ok, inst, pos = pcall(C_Map.GetWorldPosFromMapPos, e.map, CreateVector2D(e.x, e.y))
      if ok and inst and pos then
        e.wx, e.wy = pos:GetXY() -- wx grows to the north, wy grows to the west
        e.inst = inst
      end
    end
  end
  worldDone = true
end

local function PlayerFactionLetter()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Alliance" then
    return "A"
  elseif f == "Horde" then
    return "H"
  end
end

local function Filter()
  Build()
  wipe(visible)
  wipe(byMap)
  local mine = PlayerFactionLetter()
  local hostile = Pins.HostileOn()
  for _, e in ipairs(entries) do
    local kdef = Pins.KINDS[e.kind]
    local kindId = kdef and kdef.id
    local friendly = (not mine) or e.fac:find(mine, 1, true)
    local wanted = true
    if kdef and kdef.filter then
      local ok, v = pcall(kdef.filter, e)
      wanted = ok and v and true or false
    end
    if kindId and wanted and Pins.KindOn(kindId) and (friendly or hostile) then
      e.hostile = not friendly
      visible[#visible + 1] = e
      local list = byMap[e.map]
      if not list then
        list = {}
        byMap[e.map] = list
      end
      list[#list + 1] = e
    end
  end
end

local function ZoneName(map)
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, map)
    if ok and info and info.name then
      return info.name
    end
  end
  return (Nock.PinZones and Nock.PinZones[map]) or "?"
end

local function GoodsText(g)
  local parts = {}
  if g:find("a", 1, true) then parts[#parts + 1] = "arrows" end
  if g:find("b", 1, true) then parts[#parts + 1] = "bullets" end
  if g:find("q", 1, true) then parts[#parts + 1] = "quivers and ammo pouches" end
  if #parts == 0 then
    return nil
  end
  return "Sells " .. table.concat(parts, ", ")
end

-- Tooltip -----------------------------------------------------------------------

local function ShowTip(frame)
  local e = frame.entry
  if not (e and GameTooltip) then
    return
  end
  local kind = Pins.KINDS[e.kind]
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  GameTooltip:SetText(e.name, 1, 1, 1)
  local c = kind.color
  GameTooltip:AddLine(kind.role, c[1], c[2], c[3])
  if e.title and e.title ~= "" and e.title ~= kind.role then
    GameTooltip:AddLine(e.title, 0.75, 0.75, 0.75)
  end
  local goods = e.kind == 4 and GoodsText(e.goods)
  if goods then
    GameTooltip:AddLine(goods, 0.9, 0.9, 0.9, true)
  end
  if kind.tip then
    local ok, lines = pcall(kind.tip, e)
    if ok and type(lines) == "table" then
      for _, line in ipairs(lines) do
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
      end
    end
  end
  GameTooltip:AddLine(string.format("%s  %.0f, %.0f", ZoneName(e.map), e.x * 100, e.y * 100), 0.95, 0.88, 0.55)
  if frame.dist then
    GameTooltip:AddLine(string.format("%d yards away", frame.dist), 0.7, 0.7, 0.7)
  end
  if e.hostile then
    GameTooltip:AddLine("Other faction", 1, 0.3, 0.25)
  end
  GameTooltip:Show()
end

local function HideTip()
  if GameTooltip then
    GameTooltip:Hide()
  end
end

local function NewPin(parent, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  f:EnableMouse(true)
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetAllPoints()
  f.icon = t
  f:SetScript("OnEnter", ShowTip)
  f:SetScript("OnLeave", HideTip)
  f:Hide()
  return f
end

local function SetEntry(f, e)
  f.entry = e
  f.icon:SetTexture(Pins.KINDS[e.kind].tex)
  f.icon:SetDesaturated(e.hostile and true or false)
end

-- Minimap -----------------------------------------------------------------------

local miniPins = {}
local miniUsed = 0
local lastKey

local function MiniPin(i)
  local f = miniPins[i]
  if not f then
    f = NewPin(Minimap, MINI_SIZE)
    f:SetFrameStrata(Minimap:GetFrameStrata())
    f:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    miniPins[i] = f
  end
  return f
end

local function HideMini(from)
  for i = from or 1, #miniPins do
    miniPins[i]:Hide()
    miniPins[i].entry = nil
  end
end

local OUTDOOR = { [0] = 233.33, [1] = 200, [2] = 166.67, [3] = 133.33, [4] = 100, [5] = 66.67 }
local INDOOR = { [0] = 150, [1] = 120, [2] = 90, [3] = 60, [4] = 40, [5] = 25 }

local function ViewRadius()
  if Minimap.GetViewRadius then
    local ok, r = pcall(Minimap.GetViewRadius, Minimap)
    if ok and type(r) == "number" and r > 0 then
      return r
    end
  end
  local zoom = Minimap:GetZoom() or 0
  local indoors = IsIndoors and IsIndoors()
  return (indoors and INDOOR or OUTDOOR)[zoom] or 200
end

local function PlayerWorld()
  if not (C_Map and C_Map.GetBestMapForUnit) then
    return
  end
  local map = C_Map.GetBestMapForUnit("player")
  if not map then
    return
  end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then
    return
  end
  local inst, world = C_Map.GetWorldPosFromMapPos(map, pos)
  if not (inst and world) then
    return
  end
  local x, y = world:GetXY()
  return x, y, inst
end

local function IsSquare()
  local f = _G.GetMinimapShape
  if type(f) == "function" then
    local ok, shape = pcall(f)
    return ok and shape == "SQUARE"
  end
  return false
end

local nearest = {}

local function UpdateMinimapNow(force)
  if not (Pins.IsOn() and Pins.MinimapOn() and Minimap and Minimap:IsVisible()) then
    if miniUsed > 0 then
      HideMini(1)
      miniUsed = 0
    end
    lastKey = nil
    return
  end
  ResolveWorld()
  local px, py, inst = PlayerWorld()
  if not px then
    HideMini(1)
    miniUsed = 0
    lastKey = nil
    return
  end
  local radius = ViewRadius()
  local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
  local facing = 0
  if rotate and GetPlayerFacing then
    facing = GetPlayerFacing() or 0
  end
  local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
  local key = string.format("%.1f:%.1f:%d:%.2f:%.2f:%.0f", px, py, inst, radius, facing, w)
  if key == lastKey and not force then
    return
  end
  lastKey = key

  local cosA, sinA = 1, 0
  if rotate then
    cosA, sinA = math.cos(-facing), math.sin(-facing)
  end
  local square = IsSquare()
  wipe(nearest)
  local used = 0
  local r2 = radius * radius

  for _, e in ipairs(visible) do
    if e.inst == inst and e.wx then
      local dx = py - e.wy -- east
      local dy = e.wx - px -- north
      local d2 = dx * dx + dy * dy
      if d2 <= r2 * 0.94 then
        if rotate then
          dx, dy = dx * cosA - dy * sinA, dx * sinA + dy * cosA
        end
        used = used + 1
        local f = MiniPin(used)
        SetEntry(f, e)
        f.dist = math.floor(math.sqrt(d2) + 0.5)
        f:SetSize(MINI_SIZE, MINI_SIZE)
        f:SetAlpha(1)
        f:ClearAllPoints()
        f:SetPoint("CENTER", Minimap, "CENTER", dx / radius * w, dy / radius * h)
        f:Show()
        nearest[e.kind] = false -- one in range already
      elseif nearest[e.kind] ~= false and d2 < EDGE_MAX_YARDS * EDGE_MAX_YARDS then
        local n = nearest[e.kind]
        if not n or d2 < n.d2 then
          nearest[e.kind] = { e = e, dx = dx, dy = dy, d2 = d2 }
        end
      end
    end
  end

  for _, n in pairs(nearest) do
    if n then
      local dx, dy = n.dx, n.dy
      if rotate then
        dx, dy = dx * cosA - dy * sinA, dx * sinA + dy * cosA
      end
      local d = math.sqrt(n.d2)
      local ex, ey
      if square then
        local m = math.max(math.abs(dx), math.abs(dy))
        ex, ey = dx / m * (w - 7), dy / m * (h - 7)
      else
        ex, ey = dx / d * (w - 7), dy / d * (h - 7)
      end
      used = used + 1
      local f = MiniPin(used)
      SetEntry(f, n.e)
      f.dist = math.floor(d + 0.5)
      f:SetSize(MINI_EDGE_SIZE, MINI_EDGE_SIZE)
      f:SetAlpha(0.8)
      f:ClearAllPoints()
      f:SetPoint("CENTER", Minimap, "CENTER", ex, ey)
      f:Show()
    end
  end

  if used < miniUsed then
    HideMini(used + 1)
  end
  miniUsed = used
end

local function UpdateMinimap(force)
  local ok, err = pcall(UpdateMinimapNow, force)
  if not ok then
    -- Position APIs can refuse inside instances; hide quietly and try again later.
    HideMini(1)
    miniUsed = 0
    lastKey = nil
    Pins.lastError = err
  end
end

-- World map ---------------------------------------------------------------------

local worldPins = {}
local worldUsed = 0
local provider

local function HideWorld()
  for i = 1, #worldPins do
    worldPins[i]:Hide()
    worldPins[i].entry = nil
  end
  worldUsed = 0
end

local function PlaceWorldPin(f, canvas, scale)
  local e = f.entry
  f:SetScale(scale)
  f:ClearAllPoints()
  f:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * e.x / scale, -canvas:GetHeight() * e.y / scale)
end

local function PinScale(map)
  local cs = (map.GetCanvasScale and map:GetCanvasScale()) or 1
  if cs <= 0 then
    cs = 1
  end
  return 1 / cs
end

local function RefreshWorld()
  HideWorld()
  if not (provider and provider:GetMap()) then
    return
  end
  if not (Pins.IsOn() and Pins.WorldOn()) then
    return
  end
  local map = provider:GetMap()
  local mapID = map:GetMapID()
  local list = mapID and byMap[mapID]
  if not list then
    return
  end
  local canvas = map:GetCanvas()
  local scale = PinScale(map)
  for _, e in ipairs(list) do
    worldUsed = worldUsed + 1
    local f = worldPins[worldUsed]
    if not f then
      f = NewPin(canvas, WORLD_SIZE)
      worldPins[worldUsed] = f
    end
    if f:GetParent() ~= canvas then
      f:SetParent(canvas)
    end
    f:SetFrameLevel(math.min(9000, canvas:GetFrameLevel() + 2100))
    SetEntry(f, e)
    f.dist = nil
    PlaceWorldPin(f, canvas, scale)
    f:Show()
  end
end

local function RescaleWorld()
  if not (provider and provider:GetMap()) then
    return
  end
  local map = provider:GetMap()
  local canvas = map:GetCanvas()
  local scale = PinScale(map)
  for i = 1, worldUsed do
    if worldPins[i].entry then
      PlaceWorldPin(worldPins[i], canvas, scale)
    end
  end
end

local function HookWorldMap()
  if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin and CreateFromMixins) then
    return
  end
  provider = CreateFromMixins(MapCanvasDataProviderMixin)
  function provider:RemoveAllData()
    HideWorld()
  end
  function provider:RefreshAllData()
    local ok, err = pcall(RefreshWorld)
    if not ok then
      Pins.lastError = err
    end
  end
  function provider:OnCanvasScaleChanged()
    pcall(RescaleWorld)
  end
  function provider:OnCanvasSizeChanged()
    pcall(RescaleWorld)
  end
  WorldMapFrame:AddDataProvider(provider)
end

-- Public ------------------------------------------------------------------------

function Pins.Refresh()
  Filter()
  lastKey = nil
  UpdateMinimap(true)
  if provider and provider.RefreshAllData and WorldMapFrame and WorldMapFrame:IsShown() then
    provider:RefreshAllData()
  end
  local UI = Nock.UI
  if UI and UI.Refresh then
    pcall(UI.Refresh)
  end
end

function Pins.SetOn(on)
  Opt().on = on and true or false
  Pins.Refresh()
end
function Pins.SetKind(id, on)
  local o = Opt()
  if type(o.hide) ~= "table" then
    o.hide = {}
  end
  o.hide[id] = (not on) or nil
  Pins.Refresh()
end
function Pins.SetMinimap(on)
  Opt().minimap = on and true or false
  Pins.Refresh()
end
function Pins.SetWorld(on)
  Opt().world = on and true or false
  Pins.Refresh()
end
function Pins.SetHostile(on)
  Opt().hostile = on and true or false
  Pins.Refresh()
end

function Pins.Toggle()
  Pins.SetOn(not Pins.IsOn())
  Say("Hunter map pins " .. (Pins.IsOn() and "on." or "off."))
end
_G.Nock_TogglePins = Pins.Toggle

-- Nearest friendly pin of a kind (number), whether or not that kind is shown.
-- Returns entry, yards; nil when unknown (instances, no position).
function Pins.Nearest(kind)
  ResolveWorld()
  Build()
  local px, py, inst = PlayerWorld()
  if not px then
    return nil
  end
  local mine = PlayerFactionLetter()
  local best, bestD2
  for _, e in ipairs(entries) do
    if e.kind == kind and e.inst == inst and e.wx and ((not mine) or e.fac:find(mine, 1, true)) then
      local dx, dy = py - e.wy, e.wx - px
      local d2 = dx * dx + dy * dy
      if not bestD2 or d2 < bestD2 then
        best, bestD2 = e, d2
      end
    end
  end
  if not best then
    return nil
  end
  return best, math.sqrt(bestD2)
end

function Pins.ZoneName(map)
  return ZoneName(map)
end

function Pins.Counts()
  Build()
  local out = {}
  for _, e in ipairs(entries) do
    local k = Pins.KINDS[e.kind].id .. ":" .. e.fac
    out[k] = (out[k] or 0) + 1
  end
  return out, #entries
end

local ALIAS = {
  trainer = "trainer", trainers = "trainer", hunter = "trainer",
  pet = "pet", pets = "pet", pettrainer = "pet",
  stable = "stable", stables = "stable", stablemaster = "stable",
  tame = "tame", rares = "tame", rare = "tame", beasts = "tame",
  ammo = "ammo", arrows = "ammo", arrow = "ammo", bullets = "ammo", vendor = "ammo", vendors = "ammo",
}

function Pins.Slash(rest)
  rest = rest or ""
  if rest == "" then
    return Pins.Toggle()
  end
  if rest == "on" or rest == "off" then
    Pins.SetOn(rest == "on")
    return Say("Hunter map pins " .. rest .. ".")
  end
  if rest == "minimap" or rest == "mini" then
    Pins.SetMinimap(not Pins.MinimapOn())
    return Say("Minimap pins " .. (Pins.MinimapOn() and "on." or "off."))
  end
  if rest == "map" or rest == "world" or rest == "worldmap" then
    Pins.SetWorld(not Pins.WorldOn())
    return Say("World map pins " .. (Pins.WorldOn() and "on." or "off."))
  end
  if rest == "hostile" or rest == "enemy" or rest == "both" then
    Pins.SetHostile(not Pins.HostileOn())
    return Say("Other faction's NPCs " .. (Pins.HostileOn() and "shown (greyed)." or "hidden."))
  end
  local id = ALIAS[rest]
  if id then
    Pins.SetKind(id, not Pins.KindOn(id))
    local k = Pins.KINDS[KIND_BY_ID[id]]
    if not k then
      return Say("That pin kind is not loaded.")
    end
    return Say(k.label .. " " .. (Pins.KindOn(id) and "shown." or "hidden."))
  end
  Say("/nock pins — all on or off.  /nock pins trainer | pet | stable | ammo — one kind.  /nock pins minimap | map | hostile")
end

-- Driver ------------------------------------------------------------------------

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + (elapsed or 0)
  if acc < TICK then
    return
  end
  acc = 0
  UpdateMinimap(false)
end)
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("MINIMAP_UPDATE_ZOOM")
driver:RegisterEvent("CVAR_UPDATE")
driver:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    pcall(HookWorldMap)
    Filter()
  elseif event == "PLAYER_ENTERING_WORLD" then
    Filter()
  end
  lastKey = nil
end)
