-- Nock 3.3.0: map pins and quiver counter tests (Lua 5.1, run by run_pins.py).
local fails = 0
local function check(cond, msg)
  if cond then print("ok  " .. msg) else print("FAIL " .. msg); fails = fails + 1 end
end

-- Generic stub object: records a few calls, ignores the rest.
local function Obj(kind)
  local o = { _kind = kind, _shown = false, _points = {}, _w = 0, _h = 0, _scale = 1, _scripts = {}, _alpha = 1, _level = 5 }
  local m = {}
  function m:SetSize(w, h) self._w, self._h = w, h end
  function m:GetWidth() return self._w end
  function m:GetHeight() return self._h end
  function m:SetPoint(...) self._points = { ... } end
  function m:GetPoint() local p = self._points; return p[1], p[2], p[3], p[4], p[5] end
  function m:ClearAllPoints() self._points = {} end
  function m:Show() self._shown = true end
  function m:Hide() self._shown = false end
  function m:IsShown() return self._shown end
  function m:IsVisible() return self._shown end
  function m:SetScale(s) self._scale = s end
  function m:GetScale() return self._scale end
  function m:SetAlpha(a) self._alpha = a end
  function m:SetScript(n, f) self._scripts[n] = f end
  function m:GetScript(n) return self._scripts[n] end
  function m:GetParent() return self._parent end
  function m:SetParent(p) self._parent = p end
  function m:GetFrameLevel() return self._level end
  function m:SetFrameLevel(l) self._level = l end
  function m:GetFrameStrata() return "MEDIUM" end
  function m:SetTexture(p) self._tex = p end
  function m:SetVertexColor(r, g, b, a) self._v = { r, g, b, a } end
  function m:SetText(t) self._text = t end
  function m:GetText() return self._text end
  function m:SetTextColor(r, g, b) self._color = { r, g, b } end
  function m:CreateTexture() return Obj("Texture") end
  function m:CreateFontString() return Obj("FontString") end
  function m:CreateAnimationGroup()
    local g = Obj("AnimationGroup")
    function g:CreateAnimation() return Obj("Animation") end
    function g:Play() self._playing = true end
    function g:Stop() self._playing = false end
    function g:IsPlaying() return self._playing end
    return g
  end
  function m:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
  setmetatable(o, { __index = function(_, k)
    if m[k] then return m[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
  end })
  return o
end

FRAMES = {}
function CreateFrame(kind, name, parent)
  local f = Obj(kind)
  f._parent = parent
  if name then _G[name] = f end
  FRAMES[#FRAMES + 1] = f
  return f
end
UIParent = Obj("Frame")
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function hooksecurefunc() end
function UnitFactionGroup() return FACTION end
FACTION = "Alliance"
CVARS = { rotateMinimap = "0" }
function GetCVar(k) return CVARS[k] end
FACING = 0
function GetPlayerFacing() return FACING end
function IsIndoors() return false end
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHAT[#CHAT + 1] = m end }
GameTooltip = Obj("GameTooltip")
bit = { band = function(a, b) local r, p = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end; a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2 end; return r end }

-- Fake map system: every map is 1000 x 1000 yards, same instance.
function CreateVector2D(x, y)
  return { x = x, y = y, GetXY = function(v) return v.x, v.y end }
end
PLAYER_MAP, PLAYER_X, PLAYER_Y = 1455, 0.70, 0.85
C_Map = {
  GetWorldPosFromMapPos = function(map, pos)
    return 0, CreateVector2D(1000 - pos.y * 1000, 1000 - pos.x * 1000)
  end,
  GetBestMapForUnit = function() return PLAYER_MAP end,
  GetPlayerMapPosition = function() return CreateVector2D(PLAYER_X, PLAYER_Y) end,
  GetMapInfo = function(id) return { name = "Map" .. id } end,
}
Minimap = Obj("Minimap")
Minimap:SetSize(200, 200)
Minimap:Show()
function Minimap:GetZoom() return 0 end
function Minimap:GetViewRadius() return 100 end

-- World map canvas.
MapCanvasDataProviderMixin = {}
function MapCanvasDataProviderMixin:GetMap() return self._map end
function CreateFromMixins(m) local o = {}; for k, v in pairs(m) do o[k] = v end; return o end
local canvas = Obj("Canvas"); canvas:SetSize(1000, 700)
WorldMapFrame = Obj("WorldMapFrame")
WorldMapFrame._mapID = 1455
function WorldMapFrame:GetMapID() return self._mapID end
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetCanvasScale() return 2 end
function WorldMapFrame:AddDataProvider(p) p._map = self; self._provider = p end

-- Inventory.
INV = { id = 2512, count = 0 }
BAGS = { [1] = { slots = 16, fam = 0 }, [2] = { slots = 0, fam = 0 } }
function GetInventorySlotInfo(s) assert(s == "AmmoSlot"); return 0 end
function GetInventoryItemID(_, slot) if slot == 0 then return INV.id end end
function GetInventoryItemCount(_, slot) return INV.count end
C_Item = { GetItemNameByID = function() return "Rough Arrow" end, GetItemMaxStackSizeByID = function() return 200 end }
C_Container = {
  GetContainerNumSlots = function(b) return BAGS[b] and BAGS[b].slots or 0 end,
  GetContainerNumFreeSlots = function(b) return 0, BAGS[b] and BAGS[b].fam or 0 end,
}
NUM_BAG_SLOTS = 4

SlashCmdList = { NOCK = function(msg) LAST_BASE = msg end }
Nock = { Print = function(m) CHAT[#CHAT + 1] = m end, IsHunter = function() return true end,
         BarSize = function() return "large" end, StyleId = function() return STYLE end }
STYLE = "emerald"
NockCharDB = {}

for _, f in ipairs({ "PinsData.lua", "HunterMap.lua", "Quiver.lua" }) do
  local chunk = assert(loadfile(NOCK_DIR .. f))
  chunk("Nock")
end

local function fire(ev, ...)
  for _, f in ipairs(FRAMES) do
    local h = f._scripts.OnEvent
    if h and f._events and f._events[ev] then h(f, ev, ...) end
  end
end
local function tick()
  for _, f in ipairs(FRAMES) do
    local h = f._scripts.OnUpdate
    if h then h(f, 1) end
  end
end
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")

-- Data sanity -------------------------------------------------------------
local P = Nock.Pins
local counts, total = P.Counts()
check(total >= 150, "pin data has " .. total .. " NPCs")
local function find(name)
  for _, r in ipairs(Nock.PinData) do if r[6] == name then return r end end
end
local function near(r, map, x, y, tol)
  return r and r[3] == map and math.abs(r[4] - x) <= tol and math.abs(r[5] - y) <= tol
end
check(near(find("Olmin Burningbeard"), 1455, 70.9, 83.6, 4), "Ironforge hunter trainer in the Hall of Arms")
check(near(find("Ormak Grimshot"), 1454, 66, 18.5, 4), "Orgrimmar hunter trainer in the Valley of Honor")
check(near(find("Jocaste"), 1457, 40.4, 8.6, 4), "Darnassus hunter trainer in the Cenarion Enclave")
check(near(find("Holt Thunderhorn"), 1456, 57.3, 89.8, 4), "Thunder Bluff hunter trainer on Hunter Rise")
for _, k in ipairs({ "trainer:A", "trainer:H", "pet:A", "pet:H", "stable:A", "stable:H", "ammo:A", "ammo:H" }) do
  check((counts[k] or 0) > 0, "has " .. k .. " (" .. tostring(counts[k]) .. ")")
end

-- Minimap -----------------------------------------------------------------
tick()
local function shownMini()
  local out = {}
  for _, f in ipairs(FRAMES) do
    if f._parent == Minimap and f._shown and f.entry then out[#out + 1] = f end
  end
  return out
end
local mini = shownMini()
check(#mini > 0, "minimap shows pins in Ironforge (" .. #mini .. ")")
local olmin
for _, f in ipairs(mini) do if f.entry.name == "Olmin Burningbeard" then olmin = f end end
check(olmin ~= nil, "Olmin is on the minimap")
if olmin then
  -- Olmin at 70.9,83.6, player at 70,85: 9 yd east, 14 yd north. Radius 100 => 100 px half-width.
  local _, _, _, x, y = olmin:GetPoint()
  check(math.abs(x - 9) < 0.6 and math.abs(y - 14) < 0.6, string.format("Olmin offset east/north (%.1f, %.1f)", x, y))
end
for _, f in ipairs(mini) do
  check(f.entry.fac:find("A") ~= nil, "only friendly pins: " .. f.entry.name)
end

-- Rotation: facing west (pi/2) puts a pin due west straight up.
CVARS.rotateMinimap = "1"; FACING = math.pi / 2
PLAYER_X, PLAYER_Y = 0.719, 0.836 -- 10 yards east of Olmin
tick()
for _, f in ipairs(shownMini()) do
  if f.entry.name == "Olmin Burningbeard" then
    local _, _, _, x, y = f:GetPoint()
    check(math.abs(x) < 0.6 and math.abs(y - 10) < 0.6, string.format("rotated: pin ahead is up (%.1f, %.1f)", x, y))
  end
end
CVARS.rotateMinimap = "0"; FACING = 0

-- Far away: nearest of each kind is clamped to the edge.
PLAYER_X, PLAYER_Y = 0.10, 0.10
tick()
local edge = shownMini()
check(#edge > 0 and #edge <= 4, "out of range: one edge pin per kind (" .. #edge .. ")")
for _, f in ipairs(edge) do
  local _, _, _, x, y = f:GetPoint()
  local d = math.sqrt(x * x + y * y)
  check(math.abs(d - 93) < 1, string.format("edge pin on the rim (%.1f px)", d))
end

-- Turning a kind off hides it.
SlashCmdList.NOCK("pins stable")
check(P.KindOn("stable") == false, "/nock pins stable hides stable masters")
PLAYER_X, PLAYER_Y = 0.70, 0.85
tick()
for _, f in ipairs(shownMini()) do
  check(f.entry.kind ~= 3, "no stable pins after hiding: " .. f.entry.name)
end
SlashCmdList.NOCK("pins stable")
check(P.KindOn("stable") == true, "stable masters back")

-- World map -----------------------------------------------------------------
WorldMapFrame:Show()
WorldMapFrame._provider:RefreshAllData()
local wshown = 0
for _, f in ipairs(FRAMES) do
  if f._parent == canvas and f._shown and f.entry then
    wshown = wshown + 1
    check(f.entry.map == 1455, "world pin on the viewed map")
    if f.entry.name == "Olmin Burningbeard" then
      local _, rel, rp, x, y = f:GetPoint()
      check(rel == canvas and rp == "TOPLEFT", "world pin anchored to canvas")
      check(f:GetScale() == 0.5 and math.abs(x - 1000 * 0.709 / 0.5) < 1 and math.abs(y + 700 * 0.836 / 0.5) < 1, "world pin position scaled")
    end
  end
end
check(wshown > 0, "world map shows Ironforge pins (" .. wshown .. ")")

-- Off switch.
SlashCmdList.NOCK("pins")
check(not P.IsOn(), "/nock pins turns pins off")
tick()
check(#shownMini() == 0, "no minimap pins when off")
SlashCmdList.NOCK("pins")
check(P.IsOn(), "/nock pins turns them back on")

-- Horde sees Horde.
FACTION = "Horde"; P.Refresh()
PLAYER_MAP, PLAYER_X, PLAYER_Y = 1454, 0.66, 0.19
tick()
local horde = shownMini()
check(#horde > 0, "Horde minimap pins in Orgrimmar")
for _, f in ipairs(horde) do check(f.entry.fac:find("H") ~= nil, "horde-friendly: " .. f.entry.name) end

-- Quiver ------------------------------------------------------------------
local Q = Nock.Quiver
local function quiverState()
  fire("BAG_UPDATE"); Q.Update()
  local f = _G.NockQuiverFrame
  return f, f.ring._v
end
INV.count = 900
local f, c = quiverState()
check(f and f._shown, "quiver counter shown by default")
check(f.count._text == "900", "count text 900")
check(c[1] < 0.5 and c[2] > 0.8, "900/1000 with no quiver is green")
check(f.art._tex:find("q_quiver"), "Emerald uses the quiver art")
INV.count = 500; f, c = quiverState()
check(c[1] > 0.9 and c[2] > 0.7, "500/1000 is yellow")
INV.count = 200; f, c = quiverState()
check(c[1] > 0.9 and c[2] < 0.4, "200/1000 is red")
check(f.pulse:IsPlaying(), "low ammo pulses")
BAGS[2] = { slots = 8, fam = 1 } -- 8-slot quiver x 200 = 1600
INV.count = 1200; f, c = quiverState()
check(c[1] < 0.5, "1200/1600 in a quiver is green")
INV.count = 800; f, c = quiverState()
check(c[1] > 0.9 and c[2] > 0.7, "800/1600 in a quiver is yellow")
STYLE = "gunsmith"; Q.Restyle()
check(f.art._tex:find("q_pouch"), "Gunsmith uses the ammo pouch art")
INV.id = nil; f, c = quiverState()
check(f.count._text == "0" and c[1] > 0.9 and c[2] < 0.4, "no ammo loaded shows red 0")
SlashCmdList.NOCK("quiver")
check(NockCharDB.quiver == false and not f._shown, "/nock quiver hides it")
SlashCmdList.NOCK("quiver")
check(f._shown, "/nock quiver shows it again")
SlashCmdList.NOCK("quiver unlock")
check(NockCharDB.quiverLocked == false, "/nock quiver unlock")
NockCharDB.quiverPos = { "CENTER", "CENTER", 10, 10 }
SlashCmdList.NOCK("quiver reset")
check(NockCharDB.quiverPos == nil, "/nock quiver reset clears the position")
SlashCmdList.NOCK("style gun")
check(LAST_BASE == "style gun", "other /nock commands still reach Nock")

-- Settings keys must not hold names.
for k in pairs(NockCharDB) do
  check(not tostring(k):lower():find("name"), "no name keys: " .. k)
end

if fails > 0 then
  error(fails .. " pin/quiver checks failed")
end
print("PINS_TEST_OK")
