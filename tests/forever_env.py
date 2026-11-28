#!/usr/bin/env python3
"""Shared mock of the WoW Forever hunter API for run_check.py and run_auto.py (Lua 5.1 via lupa). Importing this loads the whole addon."""
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parent.parent; ROOT = root/"Nock"; TESTS = root/"tests"
toc = (ROOT/"Nock_Forever.toc").read_text()
files = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
stubs = (TESTS/"stubs_threat.lua").read_text(); stubs = stubs[:stubs.find("NockCharDB = {}")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(stubs); lua.execute((TESTS/"stubs_fresh.lua").read_text())
lua.execute(r'''
local CF = CreateFrame
local noop = function() end
local function fallback(f)
  local m = getmetatable(f)
  if m and type(m.__index) == "table" then
    local idx = m.__index
    m.__index = function(t, k) local v = idx[k]; if v ~= nil then return v end; if type(k)=="string" and k:match("^%u") then return noop end end
  end
  return f
end
local function anyFallback(o)
  if type(o) ~= "table" then return o end
  local m = getmetatable(o) or {}
  local old = m.__index
  m.__index = function(t, k)
    local v
    if type(old) == "function" then v = old(t, k) elseif type(old) == "table" then v = old[k] end
    if v ~= nil then return v end
    if type(k) == "string" and k:match("^%u") then return noop end
  end
  setmetatable(o, m)
  return o
end
function CreateFrame(...)
  local f = fallback(CF(...))
  anyFallback(f)
  local cfs, ctex = f.CreateFontString, f.CreateTexture
  if cfs then f.CreateFontString = function(self, ...) return anyFallback(cfs(self, ...)) end end
  if ctex then f.CreateTexture = function(self, ...) return anyFallback(ctex(self, ...)) end end
  return f
end

NOW = 1000
function GetTime() return NOW end
TIMERQ = {}
C_Timer = { After = function(d, fn) TIMERQ[#TIMERQ+1] = { at = NOW + (d or 0), fn = fn } end }
function RunTimers(adv)
  NOW = NOW + (adv or 0)
  local again = true
  while again do
    again = false
    for i, t in ipairs(TIMERQ) do
      if t.at <= NOW then table.remove(TIMERQ, i); local ok, e = pcall(t.fn); if not ok then print("TIMER ERR", e) end; again = true; break end
    end
  end
end
-- Forever-like world -------------------------------------------------------------
LEVEL = 32
ENV = { book = {}, known = {}, nameLookup = "known" }  -- nameLookup: "known" | "any" | "none"
-- spell table: name -> {id=, ranks={ids}}
SPELLS = {
  ["Feign Death"]={5384}, ["Revive Pet"]={982}, ["Tame Beast"]={1515}, ["Call Pet"]={883}, ["Mend Pet"]={136,3111,3661},
  ["Feed Pet"]={6991}, ["Arcane Shot"]={3044,14281,14282}, ["Serpent Sting"]={1978,13549}, ["Wing Clip"]={2974,14267},
  ["Raptor Strike"]={2973,14260}, ["Freezing Trap"]={1499}, ["Frost Trap"]={13809}, ["Immolation Trap"]={13795},
  ["Concussive Shot"]={5116}, ["Hunter's Mark"]={1130}, ["Aspect of the Hawk"]={13165,14318}, ["Aspect of the Monkey"]={13163},
  ["Aspect of the Cheetah"]={5118}, ["Multi-Shot"]={2643}, ["Aimed Shot"]={19434}, ["Disengage"]={781}, ["Flare"]={1543},
  ["Explosive Trap"]={13813}, ["Eyes of the Beast"]={1002}, ["Eagle Eye"]={6197}, ["Beast Lore"]={1462}, ["Rapid Fire"]={3045},
  ["Track Beasts"]={1494}, ["Track Humanoids"]={19883}, ["Dismiss Pet"]={2641}, ["Auto Shot"]={75}, ["Scare Beast"]={1513},
  ["Mongoose Bite"]={1495}, ["Distracting Shot"]={20736}, ["Viper Sting"]={3034}, ["Scorpid Sting"]={3043},
  ["Aspect of the Pack"]={13159}, ["Volley"]={1510},
}
ID2NAME, ID2RANK = {}, {}
for n, ids in pairs(SPELLS) do for r, id in ipairs(ids) do ID2NAME[id] = n; ID2RANK[id] = r end end
-- ENV.book: ordered list of {name=, rank=} that the spellbook shows (one entry per spell name, highest rank)
function ENV.learn(name, rank) ENV.known[name] = rank or #SPELLS[name] end
function ENV.knownID(id) local n = ID2NAME[id]; return n and ENV.known[n] and ID2RANK[id] <= ENV.known[n] end
function ENV.bookItems()
  local t = {}
  for n, r in pairs(ENV.known) do t[#t+1] = { name = n, rank = r, id = SPELLS[n][r] } end
  table.sort(t, function(a, b) return a.name < b.name end)
  return t
end
function UnitLevel(u) if u == "pet" then return 30 end return LEVEL end
function GetSpellInfo(n)
  local id = type(n) == "number" and n or nil
  if not id then
    local s = SPELLS[n]
    if not s then return nil end
    if ENV.nameLookup == "none" then return nil end
    if ENV.nameLookup == "known" and not ENV.known[n] then return nil end
    id = ENV.known[n] and SPELLS[n][ENV.known[n]] or s[1]
    if ENV.rank1 then id = s[1] end
  end
  local nm = ID2NAME[id]; if not nm then return nil end
  return nm, nil, 132161, 0, 0, 0, id
end
C_Spell = {
  GetSpellInfo = function(n)
    local nm, _, ic, _, _, _, id = GetSpellInfo(n)
    if not nm then return nil end
    return { name = nm, iconID = ic, spellID = id }
  end,
  GetSpellName = function(id) return ID2NAME[id] end,
  GetSpellSubtext = function(id) local r = ID2RANK[id]; return r and ("Rank " .. r) or "" end,
}
function IsPlayerSpell(id) return ENV.knownID(id) and true or false end
function IsSpellKnown(id) return ENV.knownID(id) and true or false end
function GetSpellTexture() return 132161 end
SB_FUTURE = true
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 2 end,
  GetSpellBookSkillLineInfo = function(i)
    local items = ENV.bookItems()
    if i == 1 then return { name = "General", itemIndexOffset = 0, numSpellBookItems = 1 } end
    return { name = "Beast Mastery", itemIndexOffset = 1, numSpellBookItems = #items }
  end,
  GetSpellBookItemInfo = function(slot, bank)
    if slot == 1 then return { name = "Attack", itemType = 1, spellID = 6603 } end
    local it = ENV.bookItems()[slot - 1]
    if not it then return nil end
    return { name = it.name, subName = "Rank " .. it.rank, spellID = it.id, itemType = 1, isPassive = false }
  end,
  GetSpellBookItemName = function(slot, bank) local it = ENV.bookItems()[slot - 1]; return it and it.name end,
}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 3 } }

-- bindings
BINDS = { W = "MOVEFORWARD", S = "MOVEBACKWARD", Q = "STRAFELEFT", E = "STRAFERIGHT", A = "TURNLEFT", D = "TURNRIGHT", C = "TOGGLECHARACTER0",
  ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["3"] = "ACTIONBUTTON3", ["4"] = "ACTIONBUTTON4", ["5"] = "ACTIONBUTTON5", ["6"]="ACTIONBUTTON6" }
OVERRIDES, WRITES, SAVES = {}, 0, {}
function GetNumBindings() return 0 end
function GetBinding() end
function GetBindingAction(k) return BINDS[k] or "" end
function GetBindingKey(c) for k, v in pairs(OVERRIDES) do if v == c then return k end end; for k, v in pairs(BINDS) do if v == c then return k end end end
function SetBinding(k, c) WRITES = WRITES + 1; BINDS[k] = c; return true end
function SetBindingSpell(k, n) return SetBinding(k, "SPELL " .. n) end
function SetBindingClick(k, b, m) return SetBinding(k, "CLICK " .. b .. ":" .. (m or "LeftButton")) end
function SetBindingMacro(k, n) return SetBinding(k, "MACRO " .. n) end
function SaveBindings(set) SAVES[#SAVES + 1] = set end
function GetCurrentBindingSet() return 1 end
function SetOverrideBindingClick(owner, prio, key, btn) OVERRIDES[key] = "CLICK " .. btn .. ":LeftButton"; return true end
function ClearOverrideBindings() OVERRIDES = {} end
COMBAT = false
function InCombatLockdown() return COMBAT end
function StaticPopup_Show() end
function UnitName() return "Ben" end
function GetRealmName() return "Forever" end
MACROS = {}
function GetMacroIndexByName(n) for i, m in ipairs(MACROS) do if m.name == n then return i end end return 0 end
function CreateMacro(n, ic, body) if #MACROS >= (ENV.macroCap or 18) then error("too many macros") end MACROS[#MACROS+1] = {name=n, body=body}; return #MACROS end
function EditMacro(i, n, ic, body) MACROS[i].body = body; return i end
function GetMacroInfo(i) local m = MACROS[i]; if m then return m.name end end
ACTIONS = {}
CURSOR = nil
function GetActionInfo(s) local a = ACTIONS[s]; if a then return a[1], a[2] end end
function HasAction(s) return ACTIONS[s] ~= nil end
function GetCursorInfo() if CURSOR then return CURSOR[1], CURSOR[2] end end
function ClearCursor() CURSOR = nil end
function PickupSpell(id) if type(id) == "number" and ID2NAME[id] and ENV.pickupWorks ~= false then CURSOR = { "spell", id } end end
C_Spell.PickupSpell = nil
function PickupMacro(n) CURSOR = { "macro", GetMacroIndexByName(n) } end
function PlaceAction(s) if CURSOR then ACTIONS[s] = CURSOR; CURSOR = nil end end
function IsUsableSpell() return true, false end
function PetHasActionBar() return true end
function HasPetUI() return true, true end
function GetTalentTabInfo() return "Beast Mastery", "x", 31 end

-- Pet: a pet out (PET.present), its name/family, its pet spellbook and its 10-slot pet bar.
PET = { present = false, name = "Rex", family = "Wolf", book = {}, bar = {}, auto = false }
function UnitExists(u) if u == "pet" then return PET.present end return u == "player" end
function UnitName(u) if u == "pet" then return PET.present and PET.name or nil end return "Ben" end
function UnitCreatureFamily(u) if u == "pet" and PET.present then return PET.family end end
function PET.learn(name, rank, passive) PET.book[#PET.book + 1] = { name = name, rank = rank, passive = passive }
  for i, b in ipairs(PET.book) do if b.name == name and b ~= PET.book[#PET.book] then table.remove(PET.book, i) break end end end
function PET.fillBar() PET.bar = { [1] = { "PET_ACTION_ATTACK", true }, [2] = { "PET_ACTION_FOLLOW", true }, [3] = { "PET_ACTION_WAIT", true } }
  local slot = 4
  for _, b in ipairs(PET.book) do if not b.passive and slot <= 7 then PET.bar[slot] = { b.name, false, b.rank }; slot = slot + 1 end end
  PET.bar[8] = { "PET_MODE_AGGRESSIVE", true }; PET.bar[9] = { "PET_MODE_DEFENSIVE", true }; PET.bar[10] = { "PET_MODE_PASSIVE", true } end
function GetPetActionInfo(i) local b = PET.bar[i]; if b then return b[1], "tex", b[2], false, false, false, b[3] and (90000 + b[3]) or nil end end
function PickupPetAction(slot) if CURSOR and CURSOR[1] == "pet" then PET.bar[slot] = { CURSOR[2], false, CURSOR[3] }; CURSOR = nil end end
C_SpellBook.HasPetSpells = function() return #PET.book end
local _gi = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
  if bank == 1 then
    local b = PET.book[slot]; if not b then return nil end
    return { name = b.name, subName = "Rank " .. b.rank, isPassive = b.passive, itemType = 1, spellID = 90000 + b.rank }
  end
  return _gi(slot, bank)
end
C_SpellBook.PickupSpellBookItem = function(slot, bank)
  if bank == 1 then local b = PET.book[slot]; if b then CURSOR = { "pet", b.name, b.rank } end end
end
Enum.SpellBookSpellBank.Pet = 1
''')
g = lua.globals()
for f in files:
    g._SRC = (ROOT/f).read_text(); g._N = f
    lua.execute('assert(loadstring(_SRC,_N))("Nock")')
def ev(name, *args):
    g._EV = name
    lua.execute('''
      for _, f in ipairs(FRAMES or {}) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then local ok, e = pcall(fn, f, _EV, "player"); if not ok then print("EVENT ERR", _EV, e) end end end
    ''')
def timers():
    lua.execute('RunTimers(3)')
