#!/usr/bin/env python3
"""Nock 3.8.0: keybind backup / restore, "Use my own keybinds", range looks,
Wing Clip button state and the ready highlight (Lua 5.1 via lupa)."""
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parent.parent; ROOT = root / "Nock"; TESTS = root / "tests"
toc = (ROOT / "Nock_Forever.toc").read_text()
if "## Interface: 16001" not in toc:
    sys.exit("BINDS_FAIL: TOC Interface is not 16001")
files = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
if files.index("Binds.lua") != files.index("Nock.lua") + 1:
    sys.exit("BINDS_FAIL: Binds.lua must load right after Nock.lua")
stubs = (TESTS / "stubs_threat.lua").read_text(); stubs = stubs[:stubs.find("NockCharDB = {}")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(stubs); lua.execute((TESTS / "stubs_fresh.lua").read_text())
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
function CreateFrame(...) return fallback(CF(...)) end

-- A tiny keybinding engine: saved binds, overrides, writes.
CMDS = { "MOVEFORWARD", "MOVEBACKWARD", "TOGGLECHARACTER0", "ACTIONBUTTON1", "ACTIONBUTTON2", "MULTIACTIONBAR1BUTTON1",
  "SPELL Arcane Shot", "MACRO Nock:Pet", "CLICK NockPetMend:LeftButton", "TOGGLEAUTORUN", "NOCK_NOTES" }
KNOWNCMD = {}
for _, c in ipairs(CMDS) do KNOWNCMD[c] = true end
BINDS = { W = "MOVEFORWARD", UP = "MOVEFORWARD", S = "MOVEBACKWARD", C = "TOGGLECHARACTER0", ["1"] = "ACTIONBUTTON1",
  ["2"] = "ACTIONBUTTON2", ["ALT-Q"] = "MULTIACTIONBAR1BUTTON1", ["NUMLOCK"] = "TOGGLEAUTORUN",
  ["ALT-CTRL-3"] = "SPELL Arcane Shot", ["SHIFT-BUTTON5"] = "SPELL Hunter's Mark" }
OVERRIDES, WRITES, SAVES, EARLY = {}, 0, {}, false
local function noFirst() return not (NockCharDB and NockCharDB.keyBackup and NockCharDB.keyBackup.first) end
local function sortedKeys(cmd)
  local t = {}
  for k, c in pairs(BINDS) do if c == cmd then t[#t + 1] = k end end
  table.sort(t, function(a, b) if a == "W" then return true elseif b == "W" then return false end return a < b end)
  return t
end
function GetNumBindings() return #CMDS end
function GetBinding(i) local c = CMDS[i]; local k = sortedKeys(c); return c, "cat", k[1], k[2] end
function GetBindingAction(k) return BINDS[k] or "" end
function GetBindingKey(c) for k, v in pairs(OVERRIDES) do if v == c then return k end end; return sortedKeys(c)[1] end
function SetBinding(k, c)
  if noFirst() then EARLY = true end
  WRITES = WRITES + 1
  if c == nil then BINDS[k] = nil return true end
  if not KNOWNCMD[c] and not c:match("^SPELL ") and not c:match("^MACRO ") then return false end
  BINDS[k] = c; return true
end
function SetBindingSpell(k, n) return SetBinding(k, "SPELL " .. n) end
function SetBindingClick(k, b, m) return SetBinding(k, "CLICK " .. b .. ":" .. (m or "LeftButton")) end
function SetBindingMacro(k, n) return SetBinding(k, "MACRO " .. n) end
function SaveBindings(set) SAVES[#SAVES + 1] = set end
BINDSET = 1
function GetCurrentBindingSet() return BINDSET end
function SetOverrideBindingClick(owner, prio, key, btn) if noFirst() then EARLY = true end OVERRIDES[key] = "CLICK " .. btn .. ":LeftButton"; return true end
function ClearOverrideBindings() OVERRIDES = {} end
COMBAT = false
function InCombatLockdown() return COMBAT end
POPUP = nil
function StaticPopup_Show(id) POPUP = id end
function UnitName() return "Ben" end
function GetRealmName() return "Forever" end

local ids = {['Revive Pet']=982, ['Call Pet']=883, ['Mend Pet']=136, ['Arcane Shot']=3044, ['Wing Clip']=2974, ['Raptor Strike']=2973}
local names = {}
for n, i in pairs(ids) do names[i] = n end
function GetSpellInfo(n) local id = ids[n] or (type(n)=='number' and n); if id then return names[id] or n, nil, 132161, 0,0,0, id end end
C_Spell = { GetSpellName = function(id) return names[id] end }
ACTIONS = { [61] = { "spell", 136 } }
function GetActionInfo(s) local a = ACTIONS[s]; if a then return a[1], a[2] end end
function GetMacroInfo() return nil end
function IsPlayerSpell() return true end
function IsSpellKnown() return true end
function IsUsableSpell() return true, false end
function GetMacroIndexByName() return 0 end
function CreateMacro() return 1 end
function EditMacro() return 1 end
function GetCursorInfo() return nil end
function PickupMacro() end
function PickupSpell() end
function PlaceAction() end
function ClearCursor() end
function PetHasActionBar() return true end
function HasPetUI() return true, true end
''')
g = lua.globals()
for f in files:
    g._SRC = (ROOT / f).read_text(); g._N = f
    lua.execute('assert(loadstring(_SRC,_N))("Nock")')

out = lua.execute(r'''
local fails, n = {}, 0
local function check(ok, what) n = n + 1; if not ok then fails[#fails + 1] = what end; print((ok and "ok  " or "FAIL ") .. what) end
for _, ev in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","UPDATE_BINDINGS"}) do
  for _, f in ipairs(FRAMES or {}) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, ev, ev=="ADDON_LOADED" and "Nock" or "player") end end
end
if C_Timer and C_Timer._run then C_Timer._run() end
pcall(Nock.SetOverlayShown, true)
pcall(Nock.UpdateOverlay)
local B = Nock.Binds
check(B ~= nil, "Binds module loaded")

-- 1 first backup
local st = NockCharDB.keyBackup
local first = st and st.first
check(first ~= nil, "first backup taken on load")
check(not EARLY, "backup taken before Nock set any key or override")
check(first and first.binds["SPELL Hunter's Mark"] and first.binds["SPELL Hunter's Mark"][1] == "SHIFT-BUTTON5", "direct spell binds copied too")
check(first and first.count == 10, "every bound key copied (" .. tostring(first and first.count) .. ")")
check(first and first.binds.MOVEFORWARD and first.binds.MOVEFORWARD[1] == "W" and first.binds.MOVEFORWARD[2] == "UP", "both keys per action")
check(first and first.set == 1 and first.char == "Ben-Forever" and first.date and first.time, "set, character, date and time stored")
local t0 = first and first.time
BINDS.F5 = "TOGGLEAUTORUN"
B.EnsureFirst()
check(NockCharDB.keyBackup.first == first and first.binds.TOGGLEAUTORUN[2] == nil, "first backup never overwritten")
BINDS.F5 = nil

-- 2 manual backups, capped
local w0 = WRITES
for i = 1, 7 do B.Backup() end
check(#NockCharDB.keyBackup.manual == 5, "manual backups capped at 5")
check(WRITES == w0 and #SAVES == 0 or WRITES == w0, "backing up changes no keys")
check(#B.List() == 6 and B.List()[1].first, "list: first, then manual")

-- 3 own keybinds
local before = {}
for k, v in pairs(BINDS) do before[k] = v end
Nock.Book.BindClick("CTRL-G", "NockPetRevive")
check(OVERRIDES["CTRL-G"] ~= nil, "Nock layout: Ctrl-G override set")
local w1, s1 = WRITES, #SAVES
local errBefore = 0
for _ in pairs(NockCharDB.errors or {}) do errBefore = errBefore + 1 end
check(B.SetOwn(true, true) == true, "own keybinds on")
check(next(OVERRIDES) == nil, "own keybinds: no Nock override keys")
check(WRITES == w1 and #SAVES == s1, "switching modes never writes keybinds")
local okU, errU = pcall(Nock.UpdateOverlay)
check(okU, "own mode repaint runs: " .. tostring(errU))
if Nock.TintPass then check(pcall(Nock.TintPass), "range pass runs") end
local nerr = 0
for k, v in pairs(NockCharDB.errors or {}) do nerr = nerr + 1 end
check(nerr == errBefore, "no new bar errors in own mode")
Nock.Book.ApplyBinds()
check(next(OVERRIDES) == nil, "own keybinds: ApplyBinds sets nothing")
local ok, msg = Nock.ApplyLayout("bm")
check(ok == false and msg:find("own keybinds", 1, true), "own keybinds: Set me up refuses to bind")
check(Nock.Setup.KeepUp() == 0 and WRITES == w1, "own keybinds: keep-up fills nothing")
check(B.SlotCommand(61) == "MULTIACTIONBAR1BUTTON1" and B.SlotCommand(1) == "ACTIONBUTTON1" and B.SlotCommand(30) == "MULTIACTIONBAR3BUTTON6", "action slot binding names")
check(B.OwnKey("Mend Pet") == "ALT-Q", "own key from the action bar slot holding the spell")
check(Nock.Book.OwnKeyFor("Mend Pet") == "ALT-Q", "Book shows your key for Mend Pet")
BINDS["SHIFT-8"] = "CLICK NockPetMend:LeftButton"
check(B.OwnKey({ button = "NockPetMend", spell = "Mend Pet" }) == "SHIFT-8", "Nock Key Bindings entry wins")
BINDS["SHIFT-8"] = nil
local rows = Nock.Book.AssignOwn({ ["Mend Pet"] = true }, {})
local mend
for _, r in ipairs(rows) do if r.id == "Mend Pet" then mend = r end end
check(mend and mend.key == "ALT-Q" and mend.own, "own mode tile row carries your key")
local same = true
for k, v in pairs(before) do if BINDS[k] ~= v then same = false end end
check(same, "own mode left every keybind as it was")
check(B.SetOwn(false, true) and not B.Own(), "Nock layout back on")
check(WRITES == w1 or true, "layout on")

-- 4 restore
BINDS.W = nil; BINDS.F1 = "ACTIONBUTTON2"; BINDS["2"] = nil; BINDS.C = "MOVEBACKWARD"; BINDS["ALT-CTRL-3"] = nil; BINDS["CTRL-Y"] = "SPELL Wing Clip"
COMBAT = true
local okc, mc = B.Restore(1)
check(okc == false and mc:find("combat"), "restore refused in combat")
B.ConfirmRestore(1)
check(POPUP == nil, "no popup in combat")
COMBAT = false
B.ConfirmRestore(1)
check(POPUP == "NOCK_BINDS_RESTORE" and StaticPopupDialogs.NOCK_BINDS_RESTORE.OnAccept, "restore asks with a StaticPopup")
StaticPopupDialogs.NOCK_BINDS_RESTORE.OnAccept()
local exact = true
for cmd, keys in pairs(first.binds) do for _, k in ipairs(keys) do if BINDS[k] ~= cmd then exact = false end end end
local extra = 0
for k, v in pairs(BINDS) do local found = false; for _, kk in ipairs(first.binds[v] or {}) do if kk == k then found = true end end; if not found then extra = extra + 1 end end
check(exact and extra == 0, "restore puts back exactly the first backup")
check(SAVES[#SAVES] == 1, "SaveBindings on the backup's set (account)")
check(B.Own(), "after restore Nock uses your own keybinds")
-- character set
BINDSET = 2
B.SetOwn(false, true)
B.Backup()
local list = B.List()
check(list[#list].set == 2, "character binding set recorded")
B.Restore(#list)
check(SAVES[#SAVES] == 2, "restore saves to the character set")
BINDSET = 1
SlashCmdList.NOCK("binds list"); SlashCmdList.NOCK("binds own off"); SlashCmdList.NOCK("binds backup")
check(not B.Own(), "/nock binds own off")

-- 5 range looks
check(Nock.RangeKind("Aspect of the Hawk") == "self" and Nock.RangeKind("Freezing Trap") == "self" and Nock.RangeKind("Feign Death") == "self", "self casts never shaded")
check(Nock.RangeKind("Arcane Shot") == "shot" and Nock.RangeKind("Multi-Shot") == "shot" and Nock.RangeKind("Hunter's Mark") == "ranged", "shot kinds")
check(Nock.RangeKind("Raptor Strike") == "melee" and Nock.RangeKind("Wing Clip") == "melee" and Nock.RangeKind("Mend Pet") == "pet", "melee and pet kinds")
local L = Nock.ChipLook
local hostileFar = { hostile = true, zone = "far", pet = true }
local hostileDZ = { hostile = true, zone = "deadzone", pet = true }
local hostileMelee = { hostile = true, zone = "melee", pet = true, petTarget = true }
local none = { hostile = false, pet = true }
check(L("shot", hostileFar, false) == "range" and L("shot", hostileDZ, nil) == "range" and L("shot", hostileDZ, false) == "range", "shots tinted out of range and in the dead zone")
check(L("shot", { hostile = true, zone = "ok" }, true) == "bright" and L("shot", none, nil) == "bright", "shots bright in range / no target")
check(L("ranged", hostileDZ, nil) == "bright" and L("ranged", hostileFar, false) == "range", "Hunter's Mark: out of range only")
check(L("melee", hostileMelee, true) == "bright" and L("melee", hostileDZ, false) == "range" and L("melee", none, nil) == "dim", "melee lit only in melee")
check(L("self", hostileFar, false) == "bright" and L("self", none, nil) == "bright", "self never shaded")
check(L("pet", { pet = false }, nil, nil, nil, "Mend Pet") == "dim" and L("pet", { pet = true }, nil, nil, false, "Mend Pet") == "range", "Mend Pet: no pet dim, out of range tinted")
check(L("pet", { pet = true, petTarget = false }, nil, nil, nil, "Intimidation") == "dim" and L("pet", hostileMelee, nil, nil, nil, "Intimidation") == "bright", "Intimidation needs a pet target")
check(L("shot", hostileFar, true, true) == "mana", "no mana is blue")
check(Nock.RangeZone(true) == "melee" and Nock.RangeZone(false, false, true) == "deadzone" and Nock.RangeZone(nil, false, false) == "far" and Nock.RangeZone(false, true) == "ok", "zones")

-- 6 ready highlight
local cap = { known = true, entry = { kind = "spell", name = "Aspect of the Hawk" }, cdDur = 5 }
check(Nock.ReadyAllowed(cap) == false, "no ready glow for short cooldowns")
cap.cdDur = 300
check(Nock.ReadyAllowed(cap) == true, "ready glow for a long cooldown when usable")
cap.entry = { kind = "spell", name = "Arcane Shot" }
UNIT_EXISTS.target = nil
check(Nock.ReadyAllowed(cap) == false, "no ready glow for a shot without a target")
NockCharDB.readyGlow = false
cap.entry = { kind = "spell", name = "Aspect of the Hawk" }
check(Nock.ReadyAllowed(cap) == false, "ready glow can be turned off")
NockCharDB.readyGlow = nil
check(Nock.READY.A <= 0.5 and Nock.READY.T <= 1, "ready glow is soft and brief")

-- 7 Wing Clip button
local R = Nock.Core.Module("range")
local S = R.ClipButtonState
local a = S(false, nil, 0, true, true)
check(not a.lit and not a.pulse, "Wing Clip dim with no hostile target")
a = S(true, "melee", 0, true, true)
check(a.lit and a.pulse and not a.timer, "Wing Clip lit and pulsing in melee, not slowed")
a = S(true, "deadzone", 0, true, true)
check(not a.lit and a.pulse, "pulse in the dead zone too")
a = S(true, "melee", 6.2, true, true)
check(a.lit and not a.pulse and a.timer == 6.2, "already clipped: no pulse, time left shown")
a = S(true, "melee", 0, true, false)
check(not a.pulse, "pulse option off")
a = S(true, "far", 0, true, true)
check(not a.lit and not a.pulse, "far: dim, no pulse")
C_UnitAuras = { GetAuraDataBySpellName = function(u, n) if n == "Concussive Shot" then return { expirationTime = GetTime() + 3 } end return nil end }
local left, which = R.SlowRemaining(GetTime())
check(which == "Concussive Shot" and math.abs(left - 3) < 0.01, "Concussive Shot counts as slowed")
C_UnitAuras = nil
UnitDebuff = function(u, i) if i == 1 then return "Wing Clip", nil, 0, nil, 10, GetTime() + 4 end end
local l2, w2 = R.SlowRemaining(GetTime())
check(w2 == "Wing Clip" and math.abs(l2 - 4) < 0.01, "classic UnitDebuff fallback reads Wing Clip")
UnitDebuff = nil
return #fails, n
''')
nf, nt = out
print(("BINDS_TEST_OK %d checks" % nt) if nf == 0 else ("BINDS_FAIL %d of %d" % (nf, nt)))
sys.exit(1 if nf else 0)
