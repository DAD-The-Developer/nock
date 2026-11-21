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

-- Kind order is importance order: a vendor that fits several kinds shows the
-- first one that is switched on. edge = keep the nearest one on the minimap
-- rim when out of range; perMini = at most this many in range on the minimap.
Pins.KINDS = {
  { id = "trainer", label = "Hunter trainers", role = "Hunter Trainer", tex = TEX .. "pin_trainer", color = { 0.91, 0.76, 0.35 } },
  { id = "pet", label = "Pet trainers", role = "Pet Trainer", tex = TEX .. "pin_pet", color = { 0.37, 0.83, 0.54 } },
  { id = "stable", label = "Stable masters", role = "Stable Master", tex = TEX .. "pin_stable", color = { 0.82, 0.56, 0.30 } },
  { id = "ammo", label = "Ammo vendors", role = "Arrows and bullets", tex = TEX .. "pin_ammo", color = { 0.50, 0.71, 0.90 } },
  { id = "ranged", label = "Bowyers and gunsmiths", role = "Bows, guns and crossbows", tex = TEX .. "pin_ranged", color = { 0.78, 0.62, 0.92 } },
  { id = "quiver", label = "Quiver and ammo pouch vendors", role = "Quivers and ammo pouches", tex = TEX .. "pin_quiver", color = { 0.62, 0.84, 0.86 } },
  { id = "petfood", label = "Pet food vendors", role = "Pet food", tex = TEX .. "pin_petfood", color = { 0.93, 0.55, 0.42 }, edge = false, perMini = 2 },
  { id = "quest", label = "Hunter quests", role = "Hunter quests", tex = TEX .. "pin_quest", color = { 0.98, 0.84, 0.30 }, edge = false },
  { id = "flight", label = "Flight masters", role = "Flight master", tex = TEX .. "pin_flight", color = { 0.70, 0.78, 0.86 }, edge = false, perMini = 1, defaultOff = true },
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
  local v
  if type(hide) == "table" then
    v = hide[id]
  end
  if v == nil then
    local k = Pins.KINDS[KIND_BY_ID[id] or 0]
    return not (k and k.defaultOff)
  end
  return not v
end
function Pins.PetFoodAll()
  return Peek().petfoodAll == true
end
function Pins.MiniPerKind()
  return tonumber(Peek().perKind) or 3
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
  local stocks, quests = Nock.PinStock or {}, Nock.PinQuests or {}
  for _, row in ipairs(Nock.PinData or {}) do
    local e = {
      kind = row[1], fac = row[2], map = row[3], x = row[4] / 100, y = row[5] / 100,
      name = row[6], title = row[7], goods = row[8] or "",
      stock = stocks[row[9] or 0], quests = quests[row[10] or 0],
    }
    -- Every kind this NPC belongs to (the vendor sells it / gives the quest).
    local k = { [e.kind] = true }
    local g = e.goods
    if g:find("[ab]") then k[4] = true end
    if g:find("[wgct]") then k[5] = true end
    if g:find("[qp]") then k[6] = true end
    if g:find("[MFBCRU]") then k[7] = true end
    if e.quests then k[8] = true end
    e.kinds = k
    entries[#entries + 1] = e
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
    e.kinds = e.kinds or { [e.kind] = true }
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

-- What the player can use right now (for the pet food filter and highlights).
local DIET_CODE = { Meat = "M", Fish = "F", Bread = "B", Cheese = "C", Fruit = "R", Fungus = "U" }
local function PetDietCodes()
  local Core = Nock.Core
  local pet = Core and Core.Module and Core.Module("pet")
  local ok, diets = false, nil
  if pet and pet.Diets then
    ok, diets = pcall(pet.Diets)
  end
  local out, any = {}, false
  if ok and type(diets) == "table" then
    for d in pairs(diets) do
      local c = DIET_CODE[d] or (d == "Raw Meat" and "M") or (d == "Raw Fish" and "F")
      if c then
        out[c] = true
        any = true
      end
    end
  end
  return any and out or nil
end
Pins.PetDietCodes = PetDietCodes

local function PlayerLevel()
  return (UnitLevel and tonumber((UnitLevel("player")))) or 1
end

-- Built-in kind filters (other tools pass their own in AddKind).
local BUILTIN_FILTER = {
  [7] = function(e)
    if Pins.PetFoodAll() then
      return true
    end
    local codes = PetDietCodes()
    if not codes then
      return false -- no pet out: pet food vendors stay off the map
    end
    for c in pairs(codes) do
      if e.goods:find(c, 1, true) then
        return true
      end
    end
    return false
  end,
  [8] = function(e)
    local lvl = PlayerLevel()
    for _, q in ipairs(e.quests or {}) do
      if (q[2] or 0) <= lvl + 3 then
        return true
      end
    end
    return false
  end,
}

local function KindPasses(i, e)
  local kdef = Pins.KINDS[i]
  if not (kdef and Pins.KindOn(kdef.id)) then
    return false
  end
  local f = kdef.filter or BUILTIN_FILTER[i]
  if f then
    local ok, v = pcall(f, e)
    return ok and v and true or false
  end
  return true
end

local function Filter()
  Build()
  wipe(visible)
  wipe(byMap)
  Pins.worldCache = {}
  local mine = PlayerFactionLetter()
  local hostile = Pins.HostileOn()
  for _, e in ipairs(entries) do
    local friendly = (not mine) or e.fac:find(mine, 1, true)
    e.showKind, e.alsoKind = nil, nil
    if friendly or hostile then
      for i = 1, #Pins.KINDS do
        if e.kinds[i] and KindPasses(i, e) then
          if not e.showKind then
            e.showKind = i
          elseif not e.alsoKind then
            e.alsoKind = i
          end
        end
      end
    end
    if e.showKind then
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

-- Vendor goods, in the order the tooltip lists them. icon is the fallback
-- when the client has no icon for the vendor's own item yet.
local GOODS = {
  { "a", "Arrows", "Interface\\Icons\\INV_Ammo_Arrow_02" },
  { "b", "Bullets", "Interface\\Icons\\INV_Ammo_Bullet_02" },
  { "q", "Quivers", "Interface\\Icons\\INV_Misc_Quiver_02" },
  { "p", "Ammo pouches", "Interface\\Icons\\INV_Misc_Ammo_Bullet_01" },
  { "w", "Bows", "Interface\\Icons\\INV_Weapon_Bow_07" },
  { "g", "Guns", "Interface\\Icons\\INV_Weapon_Rifle_01" },
  { "c", "Crossbows", "Interface\\Icons\\INV_Weapon_Crossbow_01" },
  { "t", "Thrown", "Interface\\Icons\\INV_ThrowingKnife_02" },
  { "M", "Pet food: meat", "Interface\\Icons\\INV_Misc_Food_14", diet = true },
  { "F", "Pet food: fish", "Interface\\Icons\\INV_Misc_Fish_22", diet = true },
  { "B", "Pet food: bread", "Interface\\Icons\\INV_Misc_Food_11", diet = true },
  { "C", "Pet food: cheese", "Interface\\Icons\\INV_Misc_Food_03", diet = true },
  { "R", "Pet food: fruit", "Interface\\Icons\\INV_Misc_Food_19", diet = true },
  { "U", "Pet food: fungus", "Interface\\Icons\\INV_Mushroom_08", diet = true },
  { "d", "Drinks", "Interface\\Icons\\INV_Drink_07" },
}
Pins.GOODS = GOODS

-- Ranged weapon in slot 18: "a" for bows and crossbows, "b" for guns.
local function AmmoCode()
  local id = GetInventoryItemID and GetInventoryItemID("player", 18)
  if not id then
    return nil
  end
  local sub
  if C_Item and C_Item.GetItemInfoInstant then
    sub = select(7, C_Item.GetItemInfoInstant(id))
  elseif GetItemInfoInstant then
    sub = select(7, GetItemInfoInstant(id))
  end
  if sub == 2 or sub == 18 then
    return "a"
  elseif sub == 3 then
    return "b"
  end
end
Pins.AmmoCode = AmmoCode

local function ItemIcon(id, fallback)
  if C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, id)
    if ok and icon then
      return icon
    end
  end
  return fallback
end

-- For one vendor: per goods code, every item and the best one for a level
-- (highest required level you can use; else the lowest).
function Pins.StockByGoods(e, level)
  local out = {}
  local items = Nock.PinItems or {}
  for _, id in ipairs(e.stock or {}) do
    local it = items[id]
    if it then
      local g = out[it[1]]
      if not g then
        g = { n = 0 }
        out[it[1]] = g
      end
      g.n = g.n + 1
      local lv = it[2] or 0
      local b = g.best
      if lv <= level then
        if not b or b.lv > level or lv > b.lv then
          g.best = { id = id, lv = lv, name = it[3] }
        end
      elseif not b or (b.lv > level and lv < b.lv) then
        g.best = { id = id, lv = lv, name = it[3] }
      end
    end
  end
  return out
end

local function GoodsLines(e)
  local lines = {}
  if not e.goods or e.goods == "" then
    return lines
  end
  local level = PlayerLevel()
  local ammo = AmmoCode()
  local diets = PetDietCodes() or {}
  local stock = Pins.StockByGoods(e, level)
  for _, g in ipairs(GOODS) do
    local code = g[1]
    if e.goods:find(code, 1, true) then
      local st = stock[code]
      local best = st and st.best
      local icon = best and ItemIcon(best.id, g[3]) or g[3]
      local mark, r, gg, b = nil, 0.86, 0.86, 0.82
      if code == ammo then
        mark, r, gg, b = "your ammo", 0.45, 0.95, 0.55
      elseif g.diet and diets[code] then
        mark, r, gg, b = "your pet eats this", 0.45, 0.95, 0.55
      end
      local left = string.format("|T%s:16:16:0:0:64:64:5:59:5:59|t  %s", tostring(icon), g[2])
      local right = ""
      if best then
        local usable = best.lv <= level
        right = string.format("%s%s|r", usable and "|cffe8dcb0" or "|cff9a9a9a", best.name)
        if best.lv > 1 then
          right = right .. string.format(usable and "  |cff9fd49f%d|r" or "  |cffd47a6a%d|r", best.lv)
        end
      end
      lines[#lines + 1] = { left = left, right = right, r = r, g = gg, b = b, mark = mark }
    end
  end
  return lines
end
Pins.GoodsLines = GoodsLines

-- Tooltip -----------------------------------------------------------------------

local function TipEntry(e, dist)
  local kind = Pins.KINDS[e.showKind or e.kind] or Pins.KINDS[e.kind]
  GameTooltip:AddLine(e.name, 1, 1, 1)
  local c = kind.color
  local role = (e.title and e.title ~= "") and e.title or kind.role
  GameTooltip:AddLine(role, c[1], c[2], c[3])
  local goods = GoodsLines(e)
  if #goods > 0 then
    GameTooltip:AddLine(" ")
    for _, l in ipairs(goods) do
      GameTooltip:AddDoubleLine(l.left, l.right, l.r, l.g, l.b, 1, 1, 1)
      if l.mark then
        GameTooltip:AddLine("        " .. l.mark, 0.45, 0.95, 0.55)
      end
    end
  end
  if e.quests then
    GameTooltip:AddLine(" ")
    local lvl = PlayerLevel()
    local shown = 0
    for _, q in ipairs(e.quests) do
      if shown < 4 then
        local qc = (q[2] or 0) <= lvl and { 0.98, 0.84, 0.30 } or { 0.62, 0.62, 0.62 }
        GameTooltip:AddDoubleLine("|TInterface\\GossipFrame\\AvailableQuestIcon:14|t  " .. q[1], tostring(q[2] or ""), qc[1], qc[2], qc[3], 0.7, 0.7, 0.7)
        shown = shown + 1
      end
    end
    if #e.quests > 4 then
      GameTooltip:AddLine(string.format("        +%d more hunter quests", #e.quests - 4), 0.6, 0.6, 0.6)
    end
  end
  local kdef = Pins.KINDS[e.kind]
  if kdef and kdef.tip then
    local ok, lines = pcall(kdef.tip, e)
    if ok and type(lines) == "table" then
      for _, line in ipairs(lines) do
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
      end
    end
  end
  GameTooltip:AddLine(string.format("%s  %.0f, %.0f%s", ZoneName(e.map), e.x * 100, e.y * 100, dist and string.format("  ·  %d yd", dist) or ""), 0.62, 0.68, 0.62)
  if e.hostile then
    GameTooltip:AddLine("Other faction", 1, 0.3, 0.25)
  end
end

local function ShowTip(frame)
  local e = frame.entry
  if not (e and GameTooltip) then
    return
  end
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()
  local group = frame.group
  if group and #group > 1 then
    -- Clustered pins (a city): one short block per NPC, at most five.
    for i, ge in ipairs(group) do
      if i > 5 then
        GameTooltip:AddLine(string.format("+%d more here — zoom in", #group - 5), 0.6, 0.6, 0.6)
        break
      end
      if i > 1 then
        GameTooltip:AddLine(" ")
      end
      TipEntry(ge, nil)
    end
  else
    TipEntry(e, frame.dist)
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
  -- 3.5.0: a small dot in the second category's colour (sells more than one
  -- hunter thing), and a count for clustered pins.
  local dot = f:CreateTexture(nil, "OVERLAY", nil, 2)
  dot:SetSize(math.max(5, size * 0.3), math.max(5, size * 0.3))
  dot:SetPoint("BOTTOMRIGHT", 1, -1)
  dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
  dot:Hide()
  f.dot = dot
  local count = f:CreateFontString(nil, "OVERLAY")
  if count.SetFont then
    pcall(count.SetFont, count, "Fonts\\FRIZQT__.TTF", math.max(9, math.floor(size * 0.5)), "OUTLINE")
  end
  count:SetPoint("TOPRIGHT", 3, 3)
  f.count = count
  f:SetScript("OnEnter", ShowTip)
  f:SetScript("OnLeave", HideTip)
  f:Hide()
  return f
end

local function SetEntry(f, e, group)
  f.entry = e
  f.group = group
  local k = Pins.KINDS[e.showKind or e.kind] or Pins.KINDS[e.kind]
  f.icon:SetTexture(k.tex)
  f.icon:SetDesaturated(e.hostile and true or false)
  local also = e.alsoKind and Pins.KINDS[e.alsoKind]
  if also and f.dot then
    f.dot:SetVertexColor(also.color[1], also.color[2], also.color[3])
    f.dot:Show()
  elseif f.dot then
    f.dot:Hide()
  end
  if f.count then
    f.count:SetText((group and #group > 1) and tostring(#group) or "")
  end
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

  -- 3.5.0 clutter control: gather what is in range, most important kind and
  -- nearest first; cap each kind, and fold pins that would overlap into one.
  local cand = {}
  for _, e in ipairs(visible) do
    if e.inst == inst and e.wx then
      local dx = py - e.wy -- east
      local dy = e.wx - px -- north
      local d2 = dx * dx + dy * dy
      local k = e.showKind
      if d2 <= r2 * 0.94 then
        cand[#cand + 1] = { e = e, dx = dx, dy = dy, d2 = d2, k = k }
        nearest[k] = false -- one in range already
      elseif nearest[k] ~= false and (Pins.KINDS[k].edge ~= false) and d2 < EDGE_MAX_YARDS * EDGE_MAX_YARDS then
        local n = nearest[k]
        if not n or d2 < n.d2 then
          nearest[k] = { e = e, dx = dx, dy = dy, d2 = d2 }
        end
      end
    end
  end
  table.sort(cand, function(a, b)
    if a.k ~= b.k then
      return a.k < b.k
    end
    return a.d2 < b.d2
  end)
  local perKind, placed = {}, {}
  local defCap = Pins.MiniPerKind()
  local minSep = MINI_SIZE * 0.6
  for _, c in ipairs(cand) do
    local cap = Pins.KINDS[c.k].perMini or defCap
    if defCap >= 99 then
      cap = 99
    end
    if (perKind[c.k] or 0) < cap then
      local dx, dy = c.dx, c.dy
      if rotate then
        dx, dy = dx * cosA - dy * sinA, dx * sinA + dy * cosA
      end
      local sx, sy = dx / radius * w, dy / radius * h
      local host
      for _, pl in ipairs(placed) do
        if math.abs(pl.sx - sx) < minSep and math.abs(pl.sy - sy) < minSep then
          host = pl
          break
        end
      end
      if host then
        host.group[#host.group + 1] = c.e
      else
        perKind[c.k] = (perKind[c.k] or 0) + 1
        placed[#placed + 1] = { sx = sx, sy = sy, c = c, group = { c.e } }
      end
    end
  end
  for _, pl in ipairs(placed) do
    used = used + 1
    local f = MiniPin(used)
    SetEntry(f, pl.c.e, pl.group)
    f.dist = math.floor(math.sqrt(pl.c.d2) + 0.5)
    f:SetSize(MINI_SIZE, MINI_SIZE)
    f:SetAlpha(1)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Minimap, "CENTER", pl.sx, pl.sy)
    f:Show()
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
      SetEntry(f, n.e, nil)
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
local lastWorldScale
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
  f:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * (f.mx or e.x) / scale, -canvas:GetHeight() * (f.my or e.y) / scale)
end

-- 3.5.0: pins for any zone or city map, not just the NPC's own map. NPCs from
-- a neighbouring map (a city on its zone map, a zone on the city map) are
-- projected through world coordinates. Cached per map until the filter changes.
local function PinsForMap(mapID)
  Pins.worldCache = Pins.worldCache or {}
  local cached = Pins.worldCache[mapID]
  if cached then
    return cached
  end
  local out = {}
  local seen = {}
  for _, e in ipairs(byMap[mapID] or {}) do
    out[#out + 1] = { e = e, x = e.x, y = e.y }
    seen[e] = true
  end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local mtype = info and info.mapType
  if mtype and mtype >= 3 and C_Map.GetMapPosFromWorldPos and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    ResolveWorld()
    local ok, inst = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
    if ok and inst then
      for _, e in ipairs(visible) do
        if not seen[e] and e.inst == inst and e.wx then
          local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, inst, CreateVector2D(e.wx, e.wy), mapID)
          if ok2 and pos then
            local x, y = pos:GetXY()
            if x and y and x > 0.005 and x < 0.995 and y > 0.005 and y < 0.995 then
              out[#out + 1] = { e = e, x = x, y = y }
            end
          end
        end
      end
    end
  end
  Pins.worldCache[mapID] = out
  return out
end
Pins.PinsForMap = PinsForMap

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
  local list = mapID and PinsForMap(mapID)
  if not list or #list == 0 then
    return
  end
  local canvas = map:GetCanvas()
  local scale = PinScale(map)
  -- Cluster pins that would overlap at this zoom (cities): most important
  -- kind on top, the rest listed in its tooltip with a count.
  local cw, ch = canvas:GetWidth() or 1, canvas:GetHeight() or 1
  local sep = WORLD_SIZE * scale * 0.75
  lastWorldScale = scale
  table.sort(list, function(a, b)
    return (a.e.showKind or 99) < (b.e.showKind or 99)
  end)
  local placed = {}
  for _, p in ipairs(list) do
    local px, py = p.x * cw, p.y * ch
    local host
    for _, pl in ipairs(placed) do
      if math.abs(pl.px - px) < sep and math.abs(pl.py - py) < sep then
        host = pl
        break
      end
    end
    if host then
      host.group[#host.group + 1] = p.e
    else
      placed[#placed + 1] = { px = px, py = py, p = p, group = { p.e } }
    end
  end
  for _, pl in ipairs(placed) do
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
    SetEntry(f, pl.p.e, pl.group)
    f.mx, f.my = pl.p.x, pl.p.y
    f.dist = nil
    PlaceWorldPin(f, canvas, scale)
    f:Show()
  end
end

local function RescaleWorld()
  if not (provider and provider:GetMap()) then
    return
  end
  -- Zoom changed enough to re-cluster: rebuild instead of just moving.
  local sc = PinScale(provider:GetMap())
  if lastWorldScale and math.abs(sc - lastWorldScale) > 0.15 * lastWorldScale then
    lastWorldScale = sc
    return RefreshWorld()
  end
  lastWorldScale = lastWorldScale or sc
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
  -- Explicit true/false so default-off kinds (flight masters) remember "on".
  o.hide[id] = not on
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
function Pins.Nearest(kind, accept)
  ResolveWorld()
  Build()
  local px, py, inst = PlayerWorld()
  if not px then
    return nil
  end
  local mine = PlayerFactionLetter()
  local best, bestD2
  for _, e in ipairs(entries) do
    if (e.kind == kind or (e.kinds and e.kinds[kind])) and e.inst == inst and e.wx and ((not mine) or e.fac:find(mine, 1, true)) and ((not accept) or accept(e)) then
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
    for i in pairs(e.kinds or { [e.kind] = true }) do
      local k = Pins.KINDS[i].id .. ":" .. e.fac
      out[k] = (out[k] or 0) + 1
    end
  end
  return out, #entries
end

local ALIAS = {
  trainer = "trainer", trainers = "trainer", hunter = "trainer",
  pet = "pet", pets = "pet", pettrainer = "pet",
  stable = "stable", stables = "stable", stablemaster = "stable",
  tame = "tame", rares = "tame", rare = "tame", beasts = "tame",
  ammo = "ammo", arrows = "ammo", arrow = "ammo", bullets = "ammo", vendor = "ammo", vendors = "ammo",
  ranged = "ranged", bows = "ranged", guns = "ranged", bowyer = "ranged", gunsmith = "ranged", weapons = "ranged",
  quiver = "quiver", quivers = "quiver", pouch = "quiver", pouches = "quiver",
  petfood = "petfood", food = "petfood", ["pet food"] = "petfood",
  quest = "quest", quests = "quest",
  flight = "flight", flights = "flight", fly = "flight", taxi = "flight",
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
  if rest == "petfood all" or rest == "food all" then
    Opt().petfoodAll = not Pins.PetFoodAll()
    Pins.Refresh()
    return Say(Pins.PetFoodAll() and "Showing every pet food vendor." or "Showing pet food vendors for your pet's diet only.")
  end
  local n = rest:match("^minimap (%d+)$") or rest:match("^nearest (%d+)$")
  if n then
    Opt().perKind = tonumber(n)
    Pins.Refresh()
    return Say("Minimap: up to " .. n .. " pins of each kind in range.")
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
  Say("/nock pins — all on or off.  /nock pins trainer | pet | stable | ammo | ranged | quiver | petfood | quest | flight — one kind.  /nock pins minimap | map | hostile | nearest 3 | petfood all")
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
driver:RegisterEvent("PLAYER_LEVEL_UP")
if driver.RegisterUnitEvent then
  driver:RegisterUnitEvent("UNIT_PET", "player")
end
driver:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    pcall(HookWorldMap)
    Filter()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" or event == "PLAYER_LEVEL_UP" then
    -- Pet food (diet) and hunter quest (level) pins depend on these.
    Filter()
    if event ~= "PLAYER_ENTERING_WORLD" and provider and provider.RefreshAllData and WorldMapFrame and WorldMapFrame:IsShown() then
      provider:RefreshAllData()
    end
  end
  lastKey = nil
end)
