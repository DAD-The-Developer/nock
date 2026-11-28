#!/usr/bin/env python3
"""Nock 3.13.0: rank badges on bar tiles and the highest rank in every Nock slot (Lua 5.1 via lupa)."""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
from forever_env import *

fails = []
def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)

for e in ["ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD"]:
    ev(e)
timers()
L = lambda s: lua.eval(s)
def run(s): lua.execute(s)

run(r'''
RK = Nock.Ranks
RANKLESS = { ["Feign Death"] = true, ["Auto Shot"] = true }
local _sub = C_Spell.GetSpellSubtext
C_Spell.GetSpellSubtext = function(id)
  if type(id) == "number" and id >= 90000 then return "Rank " .. (id - 90000) end
  local n = ID2NAME[id]
  if n and RANKLESS[n] then return "" end
  return _sub(id)
end
function world()
  ENV.known = {}; COMBAT = false; ACTIONS = {}; CURSOR = nil; CHAT_LOG = {}; TIMERQ = {}
  NockCharDB.ranks = nil; NockCharDB.autoNews = nil
  PET.present = false; PET.book = {}; PET.bar = {}
  for _, n in ipairs({ "Arcane Shot", "Serpent Sting", "Feign Death", "Raptor Strike" }) do ENV.learn(n) end
  ENV.known["Arcane Shot"] = 2
  Nock.SpellbookIndex(true)
end
function cap(entry, shown)
  local c = CreateFrame("Frame", nil, UIParent)
  c.entry = entry
  c.icon = c:CreateTexture()
  c.mbadge = c:CreateTexture(); c.mbadge:Hide()
  if shown ~= false then c:Show() end
  return c
end
function text(c) return c.nockRank and c.nockRank._shown ~= false and c.nockRank._text or "" end
FAKE = { caps = {}, utilCaps = {}, pet = { caps = {} } }
REAL_OVERLAY = Nock.Overlay
Nock.Overlay = function() return FAKE end
function lines() local t = {}; for _, v in ipairs(CHAT_LOG) do t[#t + 1] = tostring(v):gsub("|c%x+Nock|r: ", "") end; return table.concat(t, " || ") end
''')

# ---- badges ----------------------------------------------------------------------------------------------
run(r'''world()
A = cap({ kind = "macro", name = "Nock:Arcane", macro = "#showtooltip Arcane Shot\n/cast Arcane Shot" })
S = cap({ kind = "spell", name = "Serpent Sting" })
F = cap({ kind = "macro", name = "Nock:Feign", requires = "Feign Death" })
U = cap({ kind = "spell", name = "Volley" })   -- not known
H = cap({ kind = "spell", name = "Raptor Strike" }, false)
FAKE.caps = { ["2"] = A, ["5"] = S, E = F, ["6"] = H }
FAKE.utilCaps = { Z = U }
RK.Paint()''')
check(L('text(A)') == "R2", "macro tile (cast by name) shows the rank it casts: R2 (%s)" % L('text(A)'))
check(L('text(S)') == "R2", "spell tile shows R2 (%s)" % L('text(S)'))
check(L('text(F)') == "", "rankless spell (Feign Death): no badge")
check(L('text(U)') == "", "spell you don't know: no badge")
check(L('text(H)') == "", "hidden tile: no badge")
pt = L('A.nockRank._points[1]')
check(pt[1] == "BOTTOMLEFT" and pt[3] == "BOTTOMLEFT" and L('A.nockRank._points[1][2] == A.icon'), "badge sits in the icon's bottom-left corner (key badge is top-left, countdown centre, paw bottom-right)")
check(L('A.nockRank._size') == 12 or L('A.nockRank._font') is not None, "badge font is set (12 outline)")
run(r'''ENV.known["Arcane Shot"] = 3; Nock.SpellbookIndex(true); A.mbadge:Show(); RK.Paint()''')
check(L('text(A)') == "R3", "rank-up repaints: R3")
check(L('A.nockRank._points[1][5]') == 9, "with a mouse badge in that corner the rank sits just above it")
run("SlashCmdList.NOCK('ranks off')")
check(L('text(A)') == "" and L('text(S)') == "" and L('NockCharDB.ranks') is False, "/nock ranks off hides every badge")
run("RK.Paint()")
check(L('text(A)') == "", "stays off on repaint")
run("SlashCmdList.NOCK('ranks on')")
check(L('text(A)') == "R3", "/nock ranks on brings them back")

# ---- pet tiles -------------------------------------------------------------------------------------------------
run(r'''world()
PET.present = true; PET.learn("Bite", 4); PET.learn("Growl", 2); PET.fillBar()
P4 = cap(nil); P4.slot = 4
P5 = cap(nil); P5.slot = 5
P1 = cap(nil); P1.slot = 1   -- Attack (a token)
FAKE.caps = {}; FAKE.utilCaps = {}; FAKE.pet.caps = { P1, P4, P5 }
RK.Paint()''')
check(L('text(P4)') == "R4" and L('text(P5)') == "R2", "pet bar tiles show the rank on the pet bar (Bite R4, Growl R2)")
check(L('text(P1)') == "", "pet command tokens (Attack) have no badge")

# ---- old rank in a Nock slot ---------------------------------------------------------------------------------------
run(r'''world()
ENV.known["Arcane Shot"] = 3
Nock.SpellbookIndex(true)
ACTIONS[2] = { "spell", 3044 }          -- Arcane Shot Rank 1, placed long ago
ACTIONS[3] = { "spell", 1978 }          -- the player's own Serpent Sting R1 where the layout wants Arcane Shot
ACTIONS[4] = { "item", 6948 }           -- an item
LAY = { { kind = "spell", name = "Arcane Shot", slot = 2 }, { kind = "spell", name = "Arcane Shot", slot = 3 },
        { kind = "spell", name = "Arcane Shot", slot = 4 }, { kind = "macro", name = "Nock:Multi", slot = 5 } }
OUT = RK.Sweep(LAY)''')
check(L('ACTIONS[2][2]') == 14282, "slot 2 still holding Arcane Shot Rank 1 now holds Rank 3 (id %s)" % L('ACTIONS[2][2]'))
check(L('OUT[1]') == "Arcane Shot on bar slot 2 upgraded from Rank 1 to Rank 3.", "the change is described (%s)" % L('OUT[1]'))
check(L('ACTIONS[3][2]') == 1978 and L('ACTIONS[4][1]') == "item", "a slot holding a different spell or an item is never touched")
check(L('#OUT') == 1 and L('CURSOR') is None, "only the stale slot changed; cursor left empty")
run("OUT = RK.Sweep(LAY)")
check(L('#OUT') == 0, "nothing to do the second time")
run(r'''world(); ENV.known["Arcane Shot"] = 3; Nock.SpellbookIndex(true); ACTIONS[2] = { "spell", 3044 }; COMBAT = true
OUT = RK.Sweep(LAY)''')
check(L('#OUT') == 0 and L('ACTIONS[2][2]') == 3044 and L('RK.pending') is True, "in combat: nothing is moved, the sweep waits")
run(r'''COMBAT = false
local orig = RK.Sweep
RK.Sweep = function(l) return orig(l or LAY) end
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "PLAYER_REGEN_ENABLED") end end
RK.Sweep = orig''')
check(L('ACTIONS[2][2]') == 14282 and "upgraded from Rank 1 to Rank 3" in L('lines()'), "fight ends: the slot is upgraded and announced (%s)" % L('lines()'))

# through the learn / rank-up pass (Nock.Auto) and on login
run(r'''world()
Nock.Auto.spells = nil; Nock.Auto.Baseline()
ACTIONS[2] = { "spell", 3044 }
local orig = RK.Sweep
RK.Sweep = function(l) return orig(LAY) end
ENV.known["Arcane Shot"] = 3; Nock.SpellbookIndex(true)
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "SPELLS_CHANGED", "player") end end
for i = 1, 10 do RunTimers(0.5) end
RK.Sweep = orig''')
check(L('ACTIONS[2][2]') == 14282 and "Arcane Shot upgraded to Rank 3" in L('lines()') and "bar slot 2 upgraded from Rank 1 to Rank 3" in L('lines()'), "rank-up pass: announces the new rank and upgrades the stale slot (%s)" % L('lines()'))
run(r'''world(); ENV.known["Arcane Shot"] = 3; Nock.SpellbookIndex(true); ACTIONS[2] = { "spell", 3044 }
local orig = RK.Sweep
RK.Sweep = function(l) return orig(LAY) end
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "PLAYER_ENTERING_WORLD") end end
for i = 1, 12 do RunTimers(0.5) end
RK.Sweep = orig''')
check(L('ACTIONS[2][2]') == 14282 and "upgraded from Rank 1 to Rank 3" in L('lines()'), "login: stale slot upgraded and said once (%s)" % L('lines()'))
run(r'''world(); NockCharDB.autoNews = false; ENV.known["Arcane Shot"] = 3; Nock.SpellbookIndex(true); ACTIONS[2] = { "spell", 3044 }
local orig = RK.Sweep; RK.Sweep = function(l) return orig(LAY) end
RK.SweepAndSay(); RK.Sweep = orig''')
check(L('ACTIONS[2][2]') == 14282 and "upgraded" not in L('lines()'), "announcements off: still upgraded, nothing said")

# ---- pet bar holding an old rank ---------------------------------------------------------------------------------------
run(r'''world()
PET.present = true; PET.learn("Bite", 4); PET.learn("Growl", 2); PET.fillBar()
PET.bar[4] = { "Bite", false, 3 }        -- the pet bar still has Rank 3
OUT = RK.Sweep({})''')
check(L('PET.bar[4][3]') == 4, "pet bar slot holding Bite Rank 3 now holds Rank 4")
check(L('OUT[1]') == "Pet bar slot 4: Bite upgraded from Rank 3 to Rank 4.", "described (%s)" % L('OUT[1]'))
check(L('PET.bar[5][1]') == "Growl" and L('PET.bar[5][3]') == 2 and L('PET.bar[8][1]') == "PET_MODE_AGGRESSIVE", "other pet slots untouched")
run("FAKE.pet.caps = { P4 }; P4.slot = 4; RK.Paint()")
check(L('text(P4)') == "R4", "pet tile shows the new rank")
run(r'''world(); PET.present = true; PET.learn("Bite", 4); PET.fillBar(); PET.bar[4] = { "Bite", false, 3 }; COMBAT = true; OUT = RK.Sweep({})''')
check(L('PET.bar[4][3]') == 3 and L('#OUT') == 0, "pet bar not touched in combat")

# the real overlay, if this mock built one
run("Nock.Overlay = REAL_OVERLAY")
print("ok   (real overlay present: %s)" % (L('Nock.Overlay() ~= nil')))

print()
if fails:
    print("RANKS_FAIL:", len(fails), "failed")
    sys.exit(1)
print("RANKS_TEST_OK")
