--[[
  Nock 3.4.0: hunter tools core.

  Everything the 3.4 hunter tools share lives here, so each tool stays one
  small file:

  * Module registry: Core.Register{ id, name, ... }. Each tool has its own
    on/off switch and settings in NockCharDB.mods[id], options in the
    "Hunter tools" options section and a /nock subcommand.
  * One event frame for all tools (Core.On), with a throttle helper
    (Core.Throttle) and one shared ticker (Core.Every).
  * The profile layer every tool reads (Core.P): level, max level, known
    spells and ranks, talent spec (bm / marks / survival / hybrid) and
    context (solo, party, raid, dungeon, raid instance, battleground).
  * Shared readers: bag scan (Core.Bags), safe flag reads, target checks.
  * A big centre alert (Core.Alert) and a screen-edge flash (Core.Flash).

  Tools adapt to the profile instead of hard-coding levels, so new content
  is a data row, not new code. Leveling-only tools step aside at max level
  ("endgame mode") unless you switch them back on.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local Core = {}
Nock.Core = Core

Core.MAX_LEVEL = 60
Core.modules = {}
Core.order = {}

-- Small helpers ----------------------------------------------------------------

local function Say(msg)
  if Nock.Print then
    Nock.Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Nock: " .. tostring(msg))
  end
end
Core.Say = Say

local function Now()
  return (GetTime and GetTime()) or 0
end
Core.Now = Now

-- Forever can hand back secret values; never compare or do maths on them.
local function IsSecret(v)
  if v == nil or not issecretvalue then
    return false
  end
  local ok, s = pcall(issecretvalue, v)
  return ok and s and true or false
end
Core.IsSecret = IsSecret

function Core.Flag(v)
  if v == nil or IsSecret(v) then
    return nil
  end
  if v == true or v == 1 then
    return true
  end
  if v == false or v == 0 then
    return false
  end
  return nil
end

function Core.Number(v)
  if v == nil or IsSecret(v) then
    return nil
  end
  local ok, n = pcall(tonumber, v)
  if ok then
    return n
  end
  return nil
end

function Core.Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local res = { pcall(fn, ...) }
  if not res[1] then
    return nil
  end
  return unpack(res, 2)
end

-- Reads a unit flag API safely: true, false or nil (unknown / secret).
function Core.UnitFlag(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, v = pcall(fn, ...)
  if not ok then
    return nil
  end
  return Core.Flag(v)
end

function Core.HasHostileTarget()
  if Core.UnitFlag(UnitExists, "target") ~= true then
    return false
  end
  if Core.UnitFlag(UnitIsDead, "target") == true then
    return false
  end
  return Core.UnitFlag(UnitCanAttack, "player", "target") == true
end

function Core.InCombat()
  return Core.UnitFlag(UnitAffectingCombat, "player") == true or (InCombatLockdown and InCombatLockdown()) or false
end

function Core.Money(copper)
  copper = math.floor(tonumber(copper) or 0)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  if g > 0 then
    return string.format("%dg %ds %dc", g, s, c)
  elseif s > 0 then
    return string.format("%ds %dc", s, c)
  end
  return string.format("%dc", c)
end

function Core.Duration(sec)
  sec = math.floor(tonumber(sec) or 0)
  if sec >= 3600 then
    return string.format("%dh %02dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60))
  elseif sec >= 60 then
    return string.format("%dm", math.floor(sec / 60))
  end
  return string.format("%ds", sec)
end

function Core.Short(n)
  n = tonumber(n) or 0
  if n >= 10000 then
    return string.format("%.1fk", n / 1000)
  end
  return tostring(math.floor(n + 0.5))
end

-- Settings ---------------------------------------------------------------------

local function DB()
  _G.NockCharDB = _G.NockCharDB or {}
  local db = _G.NockCharDB
  db.mods = db.mods or {}
  return db
end

local function ModDB(id)
  local db = DB()
  db.mods[id] = db.mods[id] or {}
  return db.mods[id]
end

function Core.Get(id, key)
  local m = Core.modules[id]
  local v = ModDB(id)[key]
  if v == nil and m and m.defaults then
    v = m.defaults[key]
  end
  return v
end

function Core.Set(id, key, value)
  ModDB(id)[key] = value
  local m = Core.modules[id]
  if m and m.OnSettings then
    pcall(m.OnSettings, m, key, value)
  end
  Core.Changed(id)
end

-- Endgame mode: "auto" (at max level), "on" or "off".
function Core.EndgameSetting()
  return DB().endgame or "auto"
end

function Core.IsEndgame()
  local s = Core.EndgameSetting()
  if s == "on" then
    return true
  elseif s == "off" then
    return false
  end
  return Core.P.isMax and true or false
end

function Core.Muted()
  return DB().toolsMuted == true
end

-- Is a tool switched on and allowed right now?
function Core.Enabled(id)
  local m = Core.modules[id]
  if not m then
    return false
  end
  if Nock.IsHunter and not Nock.IsHunter() then
    return false
  end
  if Core.Get(id, "on") == false then
    return false
  end
  if m.levelingOnly and Core.IsEndgame() and Core.Get(id, "atMax") ~= true then
    return false
  end
  -- PvE nags step aside in battlegrounds and arenas unless kept on.
  if m.pvpQuiet and Core.PvPMode() and Core.Get(id, "inPvP") ~= true then
    return false
  end
  return true
end

-- PvP mode: in a battleground or arena, unless switched off (/nock tools pvp off).
function Core.PvPSetting()
  return DB().pvpMode ~= false
end

function Core.PvPMode()
  return Core.PvPSetting() and Core.P.context == "pvp"
end

-- Battleground / arena queue: "none", "queued", "confirm" (popped) or "active".
function Core.QueueStatus()
  local best = "none"
  local rank = { none = 0, queued = 1, active = 2, confirm = 3 }
  local maxID = (GetMaxBattlefieldID and Core.Number(Core.Call(GetMaxBattlefieldID))) or (_G.MAX_BATTLEFIELD_QUEUES or 3)
  if not GetBattlefieldStatus then
    return best
  end
  for i = 1, maxID do
    local s = Core.Call(GetBattlefieldStatus, i)
    if type(s) == "string" and not IsSecret(s) and rank[s] and rank[s] > rank[best] then
      best = s
    end
  end
  return best
end

-- Profile layer ----------------------------------------------------------------

Core.P = {
  level = 1,
  isMax = false,
  faction = "Alliance",
  known = {}, -- spell name -> highest known rank (1 when the client shows no ranks)
  rankInfo = false, -- true once the spellbook showed real "Rank N" text
  spec = "none", -- bm, marks, survival, hybrid, none
  points = { bm = 0, mm = 0, sv = 0 },
  context = "solo", -- solo, party, raid, dungeon, raidinstance, pvp
  instance = "none",
  arena = false, -- true inside an arena (only if the client has them)
  queue = "none", -- battleground queue status
  resting = false,
}
local P = Core.P

local function RankOf(sub)
  if type(sub) ~= "string" or IsSecret(sub) then
    return nil
  end
  local n = sub:match("(%d+)")
  if n and sub:lower():find("rank", 1, true) then
    return tonumber(n)
  end
  return nil
end
Core.RankOf = RankOf

local function AddKnown(known, name, sub, spellID)
  if type(name) ~= "string" or IsSecret(name) or name == "" then
    return
  end
  local r = RankOf(sub)
  if not r and spellID and C_Spell and C_Spell.GetSpellSubtext then
    local ok, s = pcall(C_Spell.GetSpellSubtext, spellID)
    if ok then
      r = RankOf(s)
    end
  end
  if r then
    P.rankInfo = true
  end
  r = r or 1
  if not known[name] or known[name] < r then
    known[name] = r
  end
end

local function ScanModernBook(known)
  local SB = C_SpellBook
  if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then
    return false
  end
  local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
  local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
  local flyout = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
  local okN, lines = pcall(SB.GetNumSpellBookSkillLines)
  if not okN or type(lines) ~= "number" then
    return false
  end
  for line = 1, lines do
    local okL, info = pcall(SB.GetSpellBookSkillLineInfo, line)
    if okL and type(info) == "table" and not info.shouldHide then
      local first = (info.itemIndexOffset or 0) + 1
      local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
      for i = first, last do
        local okI, it = pcall(SB.GetSpellBookItemInfo, i, bank)
        if okI and type(it) == "table" and it.itemType ~= future and it.itemType ~= flyout and not it.isOffSpec then
          AddKnown(known, it.name, it.subName, it.spellID or it.actionID)
        end
      end
    end
  end
  return true
end

local function ScanLegacyBook(known)
  if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName) then
    return false
  end
  local okT, tabs = pcall(GetNumSpellTabs)
  if not okT or type(tabs) ~= "number" then
    return false
  end
  for tab = 1, tabs do
    local ok, _, _, offset, num = pcall(GetSpellTabInfo, tab)
    if ok and offset and num then
      for i = offset + 1, offset + num do
        local okI, kind = pcall(GetSpellBookItemInfo, i, "spell")
        if okI and kind ~= "FUTURESPELL" and kind ~= "FLYOUT" then
          local okN, name, sub = pcall(GetSpellBookItemName, i, "spell")
          if okN then
            AddKnown(known, name, sub)
          end
        end
      end
    end
  end
  return true
end

function Core.ScanSpells()
  local known = {}
  local ok = pcall(ScanModernBook, known)
  if not ok or next(known) == nil then
    pcall(ScanLegacyBook, known)
  end
  P.known = known
  P.spellsAt = Now()
end

-- Highest known rank of a spell, or 0. Falls back to Nock.PlayerKnows so a
-- spell is never reported missing just because the book scan failed.
function Core.Rank(name)
  local r = P.known[name]
  if r then
    return r
  end
  if Nock.PlayerKnows then
    local ok, known = pcall(Nock.PlayerKnows, name)
    if ok and known then
      return 1
    end
  end
  return 0
end

function Core.Knows(name, rank)
  return Core.Rank(name) >= (rank or 1)
end

function Core.ScanSpec()
  local bm, mm, sv
  if Nock.TraitPointsByTab then
    local ok, a, b, c = pcall(Nock.TraitPointsByTab)
    if ok then
      bm, mm, sv = a, b, c
    end
  end
  bm, mm, sv = tonumber(bm) or 0, tonumber(mm) or 0, tonumber(sv) or 0
  P.points.bm, P.points.mm, P.points.sv = bm, mm, sv
  local total = bm + mm + sv
  local spec = "none"
  if total > 0 then
    local top, name = bm, "bm"
    if mm > top then
      top, name = mm, "marks"
    end
    if sv > top then
      top, name = sv, "survival"
    end
    -- One tree clearly ahead = that spec; otherwise hybrid.
    spec = (top >= total * 0.6 or total < 5) and name or "hybrid"
  elseif Nock.DetectSpec then
    local ok, s = pcall(Nock.DetectSpec)
    if ok and (s == "bm" or s == "marks" or s == "survival") then
      spec = s
    end
  end
  P.spec = spec
end

-- Is the build leaning a given way? "bm", "marks" or "survival". Hybrids
-- count for any tree with 11+ points.
function Core.Leans(which)
  if P.spec == which then
    return true
  end
  local key = which == "bm" and "bm" or (which == "marks" and "mm" or "sv")
  return P.spec == "hybrid" and (P.points[key] or 0) >= 11
end

function Core.ScanContext()
  local inInst, kind = false, "none"
  if IsInInstance then
    local ok, a, b = pcall(IsInInstance)
    if ok then
      inInst, kind = Core.Flag(a) == true, (type(b) == "string" and not IsSecret(b)) and b or "none"
    end
  end
  local raid = Core.UnitFlag(IsInRaid) == true
  local group = Core.UnitFlag(IsInGroup) == true
  local ctx = "solo"
  if inInst and (kind == "pvp" or kind == "arena") then
    ctx = "pvp"
  elseif inInst and kind == "raid" then
    ctx = "raidinstance"
  elseif inInst and kind == "party" then
    ctx = "dungeon"
  elseif raid then
    ctx = "raid"
  elseif group then
    ctx = "party"
  end
  P.instance = inInst and kind or "none"
  P.context = ctx
  P.arena = inInst and kind == "arena" or false
  if not P.arena and ctx == "pvp" and IsActiveBattlefieldArena then
    P.arena = Core.UnitFlag(IsActiveBattlefieldArena) == true
  end
  P.resting = Core.UnitFlag(IsResting) == true
end

function Core.ScanLevel()
  local lvl = Core.Number(UnitLevel and UnitLevel("player")) or P.level or 1
  P.level = lvl
  P.isMax = lvl >= Core.MAX_LEVEL
  local f = UnitFactionGroup and Core.Call(UnitFactionGroup, "player")
  if f == "Horde" or f == "Alliance" then
    P.faction = f
  end
end

function Core.ScanAll()
  Core.ScanLevel()
  Core.ScanSpells()
  Core.ScanSpec()
  Core.ScanContext()
end

-- Bags -------------------------------------------------------------------------
-- One cached bag scan for every tool. Rebuilt after BAG_UPDATE_DELAYED.

local bagCache, bagDirty = {}, true

local function ItemInfo(id)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f then
    return nil
  end
  local ok, name, _, quality, ilvl, minLevel, itemType, subType, stack, _, _, price, classID = pcall(f, id)
  if not ok then
    return nil
  end
  return name, quality, ilvl, minLevel, itemType, subType, price, classID
end
Core.ItemInfo = ItemInfo

local function ItemSpell(id)
  local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if not f then
    return nil
  end
  local ok, name = pcall(f, id)
  if ok and type(name) == "string" and not IsSecret(name) then
    return name
  end
  return nil
end

local function SlotInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then
      return info.itemID, info.stackCount or 1, info.quality, info.isLocked, info.hasNoValue
    end
    return nil
  end
  if GetContainerItemInfo then
    local ok, _, count, locked, quality, _, _, link, _, noValue, id = pcall(GetContainerItemInfo, bag, slot)
    if ok then
      return id, count or 1, quality, locked, noValue
    end
  end
  return nil
end

local function NumSlots(bag)
  local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local n = f and Core.Call(f, bag)
  return tonumber(n) or 0
end

function Core.ScanBags()
  local list = {}
  local bags = _G.NUM_BAG_SLOTS or 4
  for bag = 0, bags do
    for slot = 1, NumSlots(bag) do
      local id, count, quality, locked, noValue = SlotInfo(bag, slot)
      if id and not IsSecret(id) then
        local name, q2, ilvl, minLevel, itemType, subType, price, classID = ItemInfo(id)
        list[#list + 1] = {
          bag = bag, slot = slot, id = id, count = tonumber(count) or 1,
          quality = tonumber(quality or q2) or 1, locked = locked, noValue = noValue,
          name = name, ilvl = tonumber(ilvl) or 0, minLevel = tonumber(minLevel) or 0,
          itemType = itemType, subType = subType, price = tonumber(price) or 0,
          classID = classID, spell = ItemSpell(id),
        }
      end
    end
  end
  bagCache, bagDirty = list, false
  return list
end

function Core.Bags()
  if bagDirty then
    Core.ScanBags()
  end
  return bagCache
end

function Core.BagsDirty()
  bagDirty = true
end

-- Own food / water by the item's use spell.
function Core.IsFood(item)
  local s = item and item.spell
  return s == "Food" or s == "Refreshment" or s == "Well Fed" or false
end

function Core.IsDrink(item)
  local s = item and item.spell
  return s == "Drink" or s == "Refreshment" or false
end

-- Pet food diet of an item: the data table first, then name keywords.
function Core.FoodDiet(item)
  local D = Nock.Data or {}
  if item and D.PetFood and D.PetFood[item.id] then
    return D.PetFood[item.id]
  end
  local name = item and item.name
  if type(name) ~= "string" then
    return nil
  end
  -- Only food: consumables with a Food spell, or raw meat/fish trade goods.
  local isFoodish = Core.IsFood(item) or item.classID == 7 or item.itemType == "Trade Goods" or item.subType == "Meat"
  if not isFoodish then
    return nil
  end
  for _, row in ipairs(D.PetFoodWords or {}) do
    if name:find(row[1], 1, true) then
      return row[2]
    end
  end
  return nil
end

-- Events -----------------------------------------------------------------------

local bus = CreateFrame("Frame")
Core.bus = bus
local handlers = {} -- event -> list of { id, fn }

local function Fail(id, err)
  Core.errors = Core.errors or {}
  if not Core.errors[id] then
    Core.errors[id] = tostring(err)
  end
end

function Core.On(event, id, fn)
  if not handlers[event] then
    handlers[event] = {}
    local ok = pcall(bus.RegisterEvent, bus, event)
    if not ok then
      handlers[event].bad = true
    end
  end
  table.insert(handlers[event], { id = id, fn = fn })
end

local function Dispatch(event, ...)
  local list = handlers[event]
  if not list then
    return
  end
  for _, h in ipairs(list) do
    if h.id == "core" or Core.Enabled(h.id) then
      local ok, err = pcall(h.fn, event, ...)
      if not ok then
        Fail(h.id, err)
      end
    end
  end
end
Core.Dispatch = Dispatch

bus:SetScript("OnEvent", function(_, event, ...)
  Dispatch(event, ...)
end)

-- Throttle: true at most once per `interval` seconds for `key`.
local stamps = {}
function Core.Throttle(key, interval)
  local t = Now()
  local last = stamps[key]
  if last and t - last < interval then
    return false
  end
  stamps[key] = t
  return true
end

function Core.ResetThrottle(key)
  stamps[key] = nil
end

-- Shared ticker: Core.Every(id, seconds, fn). Runs only while the tool is on.
local jobs = {}
local ticker = CreateFrame("Frame")
Core.ticker = ticker
local acc = 0
local function Tick(_, elapsed)
  acc = acc + (elapsed or 0)
  if acc < 0.05 then
    return
  end
  local dt = acc
  acc = 0
  for _, job in ipairs(jobs) do
    job.left = job.left - dt
    if job.left <= 0 then
      job.left = job.interval
      if Core.Enabled(job.id) then
        local ok, err = pcall(job.fn, dt)
        if not ok then
          Fail(job.id, err)
        end
      end
    end
  end
end

function Core.Every(id, interval, fn)
  table.insert(jobs, { id = id, interval = interval, left = interval, fn = fn })
  if ticker.SetScript then
    ticker:SetScript("OnUpdate", Tick)
  end
end
Core._Tick = Tick

-- Registry ---------------------------------------------------------------------
--[[
  def = {
    id = "pet", name = "Pet happiness and feeding", desc = "...",
    cmd = { "pet" },            -- /nock pet ...
    levelingOnly = false,       -- steps aside at max level unless atMax = true
    defaults = { on = true, ... },
    options = { { key = "sound", label = "...", tip = "..." }, ... },
    help = { "/nock pet — ..." },
    Init = function(self) end,  -- once, at PLAYER_LOGIN
    Slash = function(self, rest) end,
    Report = function(self) return { "line", ... } end, -- Field Kit page
    OnProfile = function(self, what) end, -- "level", "spells", "spec", "context"
    OnSettings = function(self, key, value) end,
    Refresh = function(self) end, -- after any setting change / enable / disable
  }
]]
function Core.Register(def)
  if type(def) ~= "table" or not def.id then
    return nil
  end
  def.defaults = def.defaults or {}
  if def.defaults.on == nil then
    def.defaults.on = true
  end
  if not Core.modules[def.id] then
    table.insert(Core.order, def.id)
  end
  Core.modules[def.id] = def
  return def
end

function Core.Module(id)
  return Core.modules[id]
end

function Core.Changed(id)
  local m = Core.modules[id]
  if m and m.Refresh then
    local ok, err = pcall(m.Refresh, m)
    if not ok then
      Fail(id, err)
    end
  end
  if Nock.UI and Nock.UI.Refresh then
    pcall(Nock.UI.Refresh)
  end
end

function Core.ProfileChanged(what)
  for _, id in ipairs(Core.order) do
    local m = Core.modules[id]
    if m.OnProfile then
      local ok, err = pcall(m.OnProfile, m, what)
      if not ok then
        Fail(id, err)
      end
    end
  end
end

-- Alerts -----------------------------------------------------------------------
-- 3.5.0: every on-screen alert goes through Nock.Alerts (Alerts.lua): one
-- tidy stack, priority queue, de-duplication and cooldowns. Core.Alert is
-- kept so older calls still work; new code calls Nock.Alerts:Fire(id, vars).

Core.COLORS = {
  bad = { 0.90, 0.30, 0.25 },
  warn = { 0.95, 0.72, 0.25 },
  good = { 0.30, 0.85, 0.55 },
  info = { 0.45, 0.75, 0.95 },
}

function Core.Alert(text, opts)
  local A = Nock.Alerts
  if not A then
    return false
  end
  return A:FireAdhoc(text, opts or {})
end

function Core.HideAlert(key)
  local A = Nock.Alerts
  if A then
    A:Clear(key)
  end
end

-- Screen-edge flash.
local flash
function Core.Flash(r, g, b, duration)
  if Core.Muted() then
    return
  end
  if not flash then
    flash = CreateFrame("Frame", "NockEdgeFlash", UIParent)
    flash:SetAllPoints(UIParent)
    flash:SetFrameStrata("BACKGROUND")
    if flash.EnableMouse then
      flash:EnableMouse(false)
    end
    flash.tex = flash:CreateTexture(nil, "BACKGROUND")
    flash.tex:SetAllPoints()
    flash.tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    if flash.tex.SetBlendMode then
      flash.tex:SetBlendMode("ADD")
    end
    flash:Hide()
    flash:SetScript("OnUpdate", function(self)
      local left = (self.untilT or 0) - Now()
      if left <= 0 then
        self:Hide()
        return
      end
      local d = self.dur or 0.8
      local p = 1 - left / d
      self:SetAlpha(math.sin(p * math.pi) * (self.peak or 0.3))
    end)
  end
  -- Subtle: a soft tinted vignette, never a full-screen blink.
  if (DB().alerts or {}).flash == false then
    return
  end
  flash.peak = 0.3
  flash.tex:SetVertexColor(r or 1, g or 0.3, b or 0.2)
  flash.dur = duration or 0.8
  flash.untilT = Now() + flash.dur
  flash:Show()
end

-- Pins helper: nearest pin of a kind (1 trainer, 2 pet trainer, 3 stable, 4 ammo).
function Core.NearestPin(kind)
  if Nock.Pins and Nock.Pins.Nearest then
    local ok, e, yards = pcall(Nock.Pins.Nearest, kind)
    if ok then
      return e, yards
    end
  end
  return nil
end

function Core.PinText(e, yards)
  if not e then
    return nil
  end
  local zone = ""
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, e.map)
    if ok and info and info.name then
      zone = " in " .. info.name
    end
  end
  local dist = yards and string.format(" (%d yd)", math.floor(yards + 0.5)) or ""
  return string.format("%s%s%s", e.name or "?", zone, dist)
end

-- Slash ------------------------------------------------------------------------

local function ModuleByCmd(cmd)
  for _, id in ipairs(Core.order) do
    local m = Core.modules[id]
    for _, c in ipairs(m.cmd or {}) do
      if c == cmd then
        return m
      end
    end
  end
  return nil
end
Core.ModuleByCmd = ModuleByCmd

-- Shared on/off handling: "/nock <cmd> on|off|leveling" before the tool's own words.
local function ModuleSlash(m, rest)
  rest = rest or ""
  if rest == "on" or rest == "off" then
    Core.Set(m.id, "on", rest == "on")
    Say(string.format("%s: %s", m.name, rest == "on" and "on" or "off"))
    return
  end
  if rest == "at60" or rest == "atmax" then
    local v = not (Core.Get(m.id, "atMax") == true)
    Core.Set(m.id, "atMax", v)
    Say(string.format("%s at max level: %s", m.name, v and "shown" or "hidden"))
    return
  end
  if not Core.Enabled(m.id) and rest == "" then
    if Core.Get(m.id, "on") == false then
      Say(string.format("%s is off. /nock %s on", m.name, m.cmd[1]))
    else
      Say(string.format("%s steps aside at max level. /nock %s at60 to keep it.", m.name, m.cmd[1]))
    end
    return
  end
  if m.Slash then
    m:Slash(rest)
  end
end
Core.ModuleSlash = ModuleSlash

function Core.Slash(rest)
  rest = rest or ""
  local word, more = rest:match("^(%S*)%s*(.*)$")
  if word == "mute" then
    DB().toolsMuted = not Core.Muted()
    Say("Hunter tool alerts: " .. (Core.Muted() and "muted" or "on"))
  elseif word == "sound" then
    DB().toolsSound = DB().toolsSound == false
    Say("Hunter tool sounds: " .. (DB().toolsSound == false and "off" or "on"))
  elseif word == "endgame" then
    if more == "on" or more == "off" or more == "auto" then
      DB().endgame = more
    end
    Core.ProfileChanged("level")
    Say(string.format("Endgame mode: %s (%s now)", Core.EndgameSetting(), Core.IsEndgame() and "endgame" or "leveling"))
  elseif word == "pvp" then
    if more == "on" or more == "off" then
      DB().pvpMode = more == "on"
    else
      DB().pvpMode = not Core.PvPSetting()
    end
    Core.ProfileChanged("context")
    Say(string.format("PvP mode: %s (%s now)", Core.PvPSetting() and "on in battlegrounds and arenas" or "off",
      Core.PvPMode() and "PvP" or "not in PvP"))
  elseif word == "errors" then
    local any = false
    for id, err in pairs(Core.errors or {}) do
      Say(id .. ": " .. err)
      any = true
    end
    if not any then
      Say("No hunter tool errors.")
    end
  else
    Core.PrintTools()
  end
end

function Core.PrintTools()
  Say(string.format("Hunter tools (%s, level %d, %s, %s):", Core.IsEndgame() and "endgame" or "leveling",
    P.level, P.spec, P.context))
  for _, id in ipairs(Core.order) do
    local m = Core.modules[id]
    local state = Core.Enabled(id) and "|cff40e39aon|r" or (Core.Get(id, "on") == false and "|cffff5544off|r"
      or ((m.pvpQuiet and Core.PvPMode()) and "|cff9cc4b1quiet in PvP|r" or "|cff9cc4b1resting at 60|r"))
    Say(string.format("  /nock %s — %s: %s", m.cmd and m.cmd[1] or id, m.name, state))
  end
  Say("  /nock tools mute | sound | endgame auto|on|off | pvp on|off   /nock kit — the Field Kit page")
end

-- Each tool's /nock words ride on the main /nock command.
local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg)
    local m = string.lower(strtrim and strtrim(msg or "") or (msg or ""))
    local cmd, rest = m:match("^(%S+)%s*(.*)$")
    if cmd == "tools" then
      return Core.Slash(rest)
    elseif cmd == "kit" or cmd == "fieldkit" then
      return Core.OpenKit()
    end
    local mod = cmd and ModuleByCmd(cmd)
    if mod then
      return ModuleSlash(mod, rest)
    end
    baseSlash(msg)
    if m == "help" then
      Say("Hunter tools (each one: /nock <word> on | off):")
      for _, id in ipairs(Core.order) do
        for _, line in ipairs(Core.modules[id].help or {}) do
          Say(line)
        end
      end
      Say("/nock tools — list all hunter tools   /nock tools mute — silence alerts   /nock kit — Field Kit page")
    end
  end
end

-- Field Kit page opener (UI_Kit.lua fills this in).
function Core.OpenKit(section)
  if Nock.Kit and Nock.Kit.Open then
    return Nock.Kit.Open(section)
  end
  for _, id in ipairs(Core.order) do
    local m = Core.modules[id]
    if m.Report and Core.Enabled(id) then
      Say("|cff40e39a" .. m.name .. "|r")
      for _, line in ipairs(m:Report() or {}) do
        Say("  " .. line)
      end
    end
  end
end

-- Keybinding globals ------------------------------------------------------------

function _G.Nock_OpenKit()
  Core.OpenKit()
end

function _G.Nock_MuteTools()
  Core.Slash("mute")
end

-- Lifecycle --------------------------------------------------------------------

local started = false
local function Start()
  if started then
    return
  end
  started = true
  Core.ScanAll()
  for _, id in ipairs(Core.order) do
    local m = Core.modules[id]
    if m.Init then
      local ok, err = pcall(m.Init, m)
      if not ok then
        Fail(id, err)
      end
    end
  end
  Core.ProfileChanged("all")
end
Core.Start = Start

local spellsPending = false
local function SpellsSoon()
  if spellsPending then
    return
  end
  spellsPending = true
  local function run()
    spellsPending = false
    Core.ScanSpells()
    Core.ProfileChanged("spells")
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0.5, run)
  else
    run()
  end
end

Core.On("PLAYER_LOGIN", "core", function()
  Start()
end)
Core.On("PLAYER_ENTERING_WORLD", "core", function()
  Start()
  Core.ScanContext()
  Core.ScanLevel()
  Core.ProfileChanged("context")
end)
Core.On("PLAYER_LEVEL_UP", "core", function(_, level)
  local n = Core.Number(level)
  if n then
    P.level = n
    P.isMax = n >= Core.MAX_LEVEL
  else
    Core.ScanLevel()
  end
  Core.ProfileChanged("level")
end)
Core.On("SPELLS_CHANGED", "core", SpellsSoon)
Core.On("LEARNED_SPELL_IN_TAB", "core", SpellsSoon)
Core.On("CHARACTER_POINTS_CHANGED", "core", function()
  Core.ScanSpec()
  Core.ProfileChanged("spec")
end)
Core.On("TRAIT_CONFIG_UPDATED", "core", function()
  Core.ScanSpec()
  Core.ProfileChanged("spec")
end)
Core.On("GROUP_ROSTER_UPDATE", "core", function()
  Core.ScanContext()
  Core.ProfileChanged("context")
end)
Core.On("ZONE_CHANGED_NEW_AREA", "core", function()
  Core.ScanContext()
  Core.ProfileChanged("context")
end)
Core.On("UPDATE_BATTLEFIELD_STATUS", "core", function()
  local before = P.queue
  P.queue = Core.QueueStatus()
  Core.ScanContext()
  if P.queue ~= before then
    Core.ProfileChanged(P.queue == "confirm" and "queuepop" or "context")
  end
end)
Core.On("PLAYER_UPDATE_RESTING", "core", function()
  Core.ScanContext()
  Core.ProfileChanged("resting")
end)
Core.On("BAG_UPDATE_DELAYED", "core", function()
  Core.BagsDirty()
end)
Core.On("BAG_UPDATE", "core", function()
  Core.BagsDirty()
end)
