-- Nock 3.4.0: shared stubs for the hunter tools tests (copied from test_pins.lua).
local fails = 0
local function check(cond, msg)
  if cond then print("ok  " .. msg) else print("FAIL " .. msg); fails = fails + 1 end
end

-- Generic stub object: records a few calls, ignores the rest.
function Obj(kind)
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
  function m:EnableMouse(on) self._mouse = on end
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


-- 3.4.0 additions ------------------------------------------------------------------
NOW = 1000
function GetTime() return NOW end
TIMERS = {}
C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = { at = NOW + d, fn = fn } end }
function RunTimers()
  local again = true
  while again do
    again = false
    for i, t in ipairs(TIMERS) do
      if t.at <= NOW then
        table.remove(TIMERS, i)
        t.fn()
        again = true
        break
      end
    end
  end
end
LEVEL, PETLEVEL = 24, 24
function UnitLevel(u) if u == "pet" then return PETLEVEL end return LEVEL end
UNITS = { player = true, pet = true, target = false }
function UnitExists(u) return UNITS[u] and true or false end
function UnitIsDead(u) return false end
function UnitIsDeadOrGhost() return false end
function UnitCanAttack(_, u) return UNITS[u] and HOSTILE or false end
HOSTILE = true
COMBAT = false
function UnitAffectingCombat() return COMBAT end
function InCombatLockdown() return COMBAT end
INSTANCE = { false, "none" }
function IsInInstance() return INSTANCE[1], INSTANCE[2] end
function IsInRaid() return false end
function IsInGroup() return GROUP or false end
RESTING = false
function IsResting() return RESTING end
function IsMounted() return false end
function IsSwimming() return false end
function UnitOnTaxi() return false end
SPEED = 0
function GetUnitSpeed() return SPEED end
HAPPY = 3
function GetPetHappiness() return HAPPY end
FOODTYPES = { "Meat", "Fish" }
function GetPetFoodTypes() return unpack(FOODTYPES) end
function UnitCreatureFamily(u) if u == "pet" then return "Cat" end end
function UnitName(u) return u == "pet" and "Kitty" or "Hunter" end
function UnitGUID(u) return u == "target" and TARGET_GUID or "Player-1" end
TARGET_GUID = "Creature-1"
FEIGN = false
function UnitIsFeignDeath() return FEIGN end
XP, XPMAX = 1000, 10000
function UnitXP() return XP end
function UnitXPMax() return XPMAX end
function GetXPExhaustion() return 500 end
MONEY = 100000
function GetMoney() return MONEY end
SHIFT = false
function IsShiftKeyDown() return SHIFT end
SOUNDS = {}
function PlaySound(id) SOUNDS[#SOUNDS + 1] = id end
function CheckInteractDistance() return CLOSE end
CLOSE = nil

-- Spells: name -> {rank, id}; spell IDs map back to names.
BOOK = {
  { "Auto Shot", nil, 75 }, { "Serpent Sting", "Rank 3", 1978 }, { "Arcane Shot", "Rank 2", 3044 },
  { "Raptor Strike", "Rank 3", 2973 }, { "Wing Clip", "Rank 1", 2974 }, { "Aspect of the Hawk", "Rank 2", 13165 },
  { "Aspect of the Monkey", nil, 13163 }, { "Aspect of the Cheetah", nil, 5118 }, { "Feign Death", nil, 5384 },
  { "Feed Pet", nil, 6991 }, { "Call Pet", nil, 883 }, { "Concussive Shot", nil, 5116 }, { "Hunter's Mark", "Rank 1", 1130 },
}
SPELLNAME = {}
for _, b in ipairs(BOOK) do SPELLNAME[b[3]] = b[1] end
Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 3 } }
PETBOOK = { { "Bite", "Rank 2" }, { "Claw", "Rank 3" }, { "Growl", "Rank 2" } }
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
  GetSpellBookItemInfo = function(i, bank)
    if bank == 1 then
      local p = PETBOOK[i]
      return p and { name = p[1], subName = p[2], itemType = 1 }
    end
    local b = BOOK[i]
    return b and { name = b[1], subName = b[2], spellID = b[3], itemType = 1 }
  end,
  HasPetSpells = function() return #PETBOOK end,
}
RANGE = {}
C_Spell = {
  IsSpellInRange = function(name) return RANGE[name] end,
  GetSpellName = function(id) return SPELLNAME[id] end,
}

-- Bag contents: bag -> slot -> item.
ITEMS = {
  [117] = { "Tough Jerky", 1, 5, 1, "Consumable", "Food & Drink", 6, 0, "Food" },
  [2287] = { "Haunch of Meat", 1, 15, 5, "Consumable", "Food & Drink", 25, 0, "Food" },
  [3770] = { "Mutton Chop", 1, 25, 15, "Consumable", "Food & Drink", 50, 0, "Food" },
  [159] = { "Refreshing Spring Water", 1, 5, 1, "Consumable", "Food & Drink", 1, 0, "Drink" },
  [4540] = { "Tough Hunk of Bread", 1, 5, 1, "Consumable", "Food & Drink", 1, 0, "Food" },
  [3300] = { "Rabbit's Foot", 0, 1, 0, "Junk", "Junk", 75, 15, nil },
  [7074] = { "Chipped Claw", 0, 1, 0, "Junk", "Junk", 20, 15, nil },
  [2512] = { "Rough Arrow", 1, 5, 1, "Projectile", "Arrow", 1, 6, nil },
}
CONTENTS = {
  [0] = { [1] = { 2287, 10 }, [2] = { 3300, 3 }, [3] = { 7074, 1 }, [4] = { 159, 8 }, [5] = { 4540, 6 } },
}
USED = {}
C_Container.GetContainerNumSlots = function(b) if b == 0 then return 16 end return BAGS[b] and BAGS[b].slots or 0 end
C_Container.GetContainerItemInfo = function(b, s)
  local c = CONTENTS[b] and CONTENTS[b][s]
  if not c then return nil end
  return { itemID = c[1], stackCount = c[2], quality = ITEMS[c[1]][2] }
end
C_Container.UseContainerItem = function(b, s) USED[#USED + 1] = b .. ":" .. s end
C_Item.GetItemInfo = function(id)
  local i = ITEMS[id]
  if not i then return nil end
  return i[1], "link", i[2], i[3], i[4], i[5], i[6], 20, "", 0, i[7], i[8]
end
C_Item.GetItemSpell = function(id) local i = ITEMS[id]; return i and i[9] end
REPAIR = { 0, false }
function CanMerchantRepair() return true end
function GetRepairAllCost() return REPAIR[1], REPAIR[2] end
REPAIRED = nil
function RepairAllItems(guild) REPAIRED = guild == true and "guild" or "own" end
