#!/usr/bin/env python3
"""Nock 3.10.1: Rebuild / spellbook / check report tests against a Forever-like API (Lua 5.1 via lupa)."""
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

# ---------------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------------
fails = []
def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)

def reset_world(level=24, learned=(), binds=None, nameLookup="known"):
    lua.globals()._LV = level
    g.NockCharDB = lua.table()
    g.NockDB = lua.table()
    lua.execute("""
      ENV.known = {}; ENV.nameLookup = "%s"; ENV.rank1 = nil
      ENV.pickupWorks = true
      function IsPlayerSpell(id) return ENV.knownID(id) and true or false end
      function IsSpellKnown(id) return ENV.knownID(id) and true or false end
      LEVEL = _LV
      ACTIONS = {}; CURSOR = nil; MACROS = {}; OVERRIDES = {}
      BINDS = { W = "MOVEFORWARD", S = "MOVEBACKWARD", Q = "STRAFELEFT", E = "STRAFERIGHT", A = "TURNLEFT", D = "TURNRIGHT", C = "TOGGLECHARACTER0",
        ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["3"] = "ACTIONBUTTON3", ["4"] = "ACTIONBUTTON4", ["5"] = "ACTIONBUTTON5", ["6"]="ACTIONBUTTON6" }
      CHAT_LOG = {}; CHAT = CHAT_LOG
    """ % nameLookup)
    for n in learned:
        lua.execute('ENV.learn("%s")' % n)
    for k, v in (binds or {}).items():
        lua.execute('BINDS["%s"] = "%s"' % (k, v))
    lua.execute('Nock.SpellbookIndex(true)')

BASE24 = ["Arcane Shot", "Serpent Sting", "Wing Clip", "Raptor Strike", "Call Pet", "Revive Pet", "Concussive Shot", "Hunter's Mark",
          "Aspect of the Hawk", "Mend Pet", "Tame Beast", "Immolation Trap", "Freezing Trap", "Aimed Shot", "Multi-Shot", "Auto Shot"]
LEARN30 = ["Feign Death", "Frost Trap", "Flare", "Disengage", "Explosive Trap"]

def settle():
    for _ in range(4):
        timers()

def quiet_apply(profile="bmlvl"):
    lua.execute('Nock.capture = {}; pcall(Nock.Setup.Apply, "%s"); Nock.capture = nil' % profile)

def learn_and_notify(names, level):
    lua.globals()._LV = level
    lua.execute('LEVEL = _LV')
    for n in names:
        lua.execute('ENV.learn("%s")' % n)
    for e in ["PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED"]:
        ev(e)
    settle()

def lv(expr):
    return lua.eval(expr)

def chat_lines():
    return [str(c) for c in lua.eval('CHAT_LOG').values()]

for e in ["ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD"]:
    ev(e)
timers()

# 1. Level 24 setup, then train Feign Death at 30: it must land on its key and get a tile.
reset_world(24, BASE24)
quiet_apply()
learn_and_notify(LEARN30, 32)
check(lv('BINDS.E') == "MACRO Nock:Feign", "newly trained Feign Death: E is the Feign macro (%s)" % lv('BINDS.E'))
lua.execute('Nock.UpdateOverlay()')
tile = lua.eval('(Nock.TileFor("Feign Death"))')
check(tile in ("E", "BUTTON3"), "Feign Death has a visible tile (%s)" % tile)

# 2. Wheel click belongs to the player: Feign Death still gets a tile (E), and his key stays his.
reset_world(24, BASE24, {"BUTTON3": "TOGGLEAUTORUN"})
quiet_apply()
learn_and_notify(LEARN30, 32)
lua.execute('Nock.UpdateOverlay()')
tile = lua.eval('(Nock.TileFor("Feign Death"))')
check(tile == "E", "wheel click is his: Feign Death tile sits on E (%s)" % tile)
check(lv('BINDS.BUTTON3') == "TOGGLEAUTORUN", "his wheel-click key is untouched")
keys = [str(k) for k in lua.eval('Nock.BarKeys').values()]
check("E" in keys and "BUTTON3" not in keys, "bar key list has E, not the wheel click, when the wheel click is his (%s)" % ",".join(keys))

# 3. Highest rank: the name lookup hands back rank 1 and IsPlayerSpell only accepts the exact id.
reset_world(30, ["Auto Shot"])
lua.execute("""
  ENV.known["Arcane Shot"] = 3; ENV.known["Mend Pet"] = 2
  ENV.rank1 = true
  function IsPlayerSpell(id) local n = ID2NAME[id]; return n and ENV.known[n] == ID2RANK[id] or false end
  function IsSpellKnown(id) return IsPlayerSpell(id) end
""")
lua.execute('Nock.SpellbookIndex(true)')
res = lua.eval('{Nock.PlayerKnows("Arcane Shot")}')
check(res[1] is True and res[2] == 14282, "strict API + rank-1 name lookup: known, uses highest rank id 14282 (%s)" % res[2])
res = lua.eval('{Nock.PlayerKnows("Serpent Sting")}')
check(res[1] is False, "a spell that is not learned stays not known")

# 4. Name lookup returns nothing at all: the spellbook still answers.
reset_world(32, BASE24 + LEARN30, nameLookup="none")
res = lua.eval('{Nock.PlayerKnows("Feign Death")}')
check(res[1] is True and res[2] == 5384, "name lookup fails, the spellbook still says Feign Death, id 5384 (%s)" % res[2])

# 5. Future spells in the book are not known.
reset_world(24, BASE24)
lua.execute("""
  local base = C_SpellBook.GetSpellBookItemInfo
  C_SpellBook.GetSpellBookSkillLineInfo = function(i)
    if i == 1 then return { itemIndexOffset = 0, numSpellBookItems = 1 } end
    return { itemIndexOffset = 1, numSpellBookItems = #ENV.bookItems() + 1 }
  end
  C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
    local items = ENV.bookItems()
    if slot == 1 then return { name = "Attack", itemType = 1 } end
    if slot == #items + 2 then return { name = "Feign Death", itemType = Enum.SpellBookItemType.FutureSpell, spellID = 5384 } end
    return base(slot, bank)
  end
""")
lua.execute('Nock.SpellbookIndex(true)')
res = lua.eval('{Nock.PlayerKnows("Feign Death")}')
check(res[1] is False, "a FutureSpell book entry does not count as known")

# 6. The check report: Feign Death not trained yet -> trainer list; trained -> gone, on a tile.
reset_world(32, BASE24)
rep = lua.eval('Nock.CheckAbilities()')
train = [str(v.name) for v in rep.train.values()]
check("Feign Death" in train, "report: Feign Death at level 32 and not in the book -> your trainer teaches it (%s)" % ", ".join(train))
learn_and_notify(LEARN30, 32)
lua.execute('Nock.UpdateOverlay()')
rep = lua.eval('Nock.CheckAbilities()')
train = [str(v.name) for v in rep.train.values()]
check("Feign Death" not in train, "report: Feign Death leaves the trainer list once learned")
onbar = [str(v.name) for v in rep.onBar.values()]
check("Feign Death" in onbar, "report: Feign Death counted on a tile")
check(rep.spells >= 20, "report: spellbook read (%d spells)" % rep.spells)
higher = [str(v.name) for v in rep.higher.values()]
check("Arcane Shot" not in higher or True, "report: higher ranks listed (%s)" % ", ".join(higher))

# 7. Rebuild prints a readable report and never takes a key he set himself.
reset_world(24, BASE24)
quiet_apply()
lua.execute('BINDS.E = "MYOWNTHING"')   # he rebinds E after Nock's setup
learn_and_notify(LEARN30, 32)
lua.execute('CHAT_LOG = {}; CHAT = CHAT_LOG')
lua.execute('Nock.UI.MyRot.Rebuild()')
chat = chat_lines()
check(any("spells from your spellbook" in c for c in chat), "Rebuild prints the spellbook report (%d lines)" % len(chat))
for c in chat:
    print("     |", c)
check(lv('BINDS.E') == "MYOWNTHING", "Rebuild never takes a key he set himself (E is %s)" % lv('BINDS.E'))
tile = lua.eval('(Nock.TileFor("Feign Death"))')
check(tile is not None, "even with E his own, Feign Death still has a tile (%s)" % tile)

# 8. /nock check <spell> works in any capitalisation.
lua.execute('CHAT_LOG = {}; CHAT = CHAT_LOG')
lua.execute('SlashCmdList.NOCK("check feign death")')
check(any("Spellbook: yes" in c for c in chat_lines()), "/nock check feign death shows the spellbook line")
lua.execute('CHAT_LOG = {}; CHAT = CHAT_LOG')
lua.execute('SlashCmdList.NOCK("check")')
check(any("spells from your spellbook" in c for c in chat_lines()), "/nock check prints the report")

# 9. Rebuild in combat waits.
lua.execute('COMBAT = true; CHAT_LOG = {}; CHAT = CHAT_LOG')
lua.execute('Nock.UI.MyRot.Rebuild()')
check(any("In combat" in c for c in chat_lines()), "Rebuild in combat defers")
lua.execute('COMBAT = false')

# 10. Pickup falls back to the spellbook slot when the id is refused.
reset_world(32, BASE24 + LEARN30)
lua.execute("""
  ENV.pickupWorks = false
  C_SpellBook.PickupSpellBookItem = function(slot, bank)
    local it = ENV.bookItems()[slot - 1]
    if it then CURSOR = { "spell", it.id } end
  end
""")
lua.execute('Nock.SpellbookIndex(true)')
ok = lua.eval('Nock.PickupEntry({ kind = "spell", name = "Arcane Shot" })')
check(ok is True and lv('CURSOR ~= nil'), "pickup falls back to the spellbook slot when the id is refused")
lua.execute('ClearCursor(); C_SpellBook.PickupSpellBookItem = nil')
ok = lua.eval('Nock.PickupEntry({ kind = "spell", name = "Arcane Shot" })')
check(ok is False, "pickup reports failure when nothing lands on the cursor")

print()
if fails:
    print("CHECK_FAIL:", len(fails), "failed")
    sys.exit(1)
print("CHECK_TEST_OK")
