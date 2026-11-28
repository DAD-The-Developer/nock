#!/usr/bin/env python3
"""Nock 3.10.2: new spells, new ranks, pet skills and new pets are placed and announced by themselves
(no Rebuild click): grouped, out of combat, never over a key the player set (Lua 5.1 via lupa)."""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
from forever_env import *

fails = []
def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)

BASE24 = ["Arcane Shot", "Serpent Sting", "Wing Clip", "Raptor Strike", "Call Pet", "Revive Pet", "Concussive Shot", "Hunter's Mark",
          "Aspect of the Hawk", "Mend Pet", "Tame Beast", "Immolation Trap", "Freezing Trap", "Aimed Shot", "Multi-Shot", "Auto Shot"]

def adv(n):
    # let time pass in half-second steps so timers started by timers fire too
    steps = int(round(n / 0.5)) + 4
    for _ in range(steps):
        lua.execute('RunTimers(0.5)')

def lines():
    return [str(c).replace("|cffd4a017Nock|r: ", "") for c in lua.eval('CHAT_LOG').values()]

def clear():
    lua.execute('CHAT_LOG = {}; CHAT = CHAT_LOG')

def world(level=24, learned=BASE24, binds=None, pet=None):
    lua.globals()._LV = level
    g.NockCharDB = lua.table(); g.NockDB = lua.table()
    lua.execute("""
      ENV.known = {}; ENV.nameLookup = "known"; ENV.rank1 = nil; ENV.pickupWorks = true
      function IsPlayerSpell(id) return ENV.knownID(id) and true or false end
      function IsSpellKnown(id) return ENV.knownID(id) and true or false end
      LEVEL = _LV; COMBAT = false
      ACTIONS = {}; CURSOR = nil; MACROS = {}; OVERRIDES = {}; TIMERQ = {}
      BINDS = { W = "MOVEFORWARD", S = "MOVEBACKWARD", Q = "STRAFELEFT", E = "STRAFERIGHT", A = "TURNLEFT", D = "TURNRIGHT", C = "TOGGLECHARACTER0",
        ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["3"] = "ACTIONBUTTON3", ["4"] = "ACTIONBUTTON4", ["5"] = "ACTIONBUTTON5", ["6"]="ACTIONBUTTON6" }
      PET.present = false; PET.book = {}; PET.bar = {}; PET.name = "Rex"; PET.family = "Wolf"
      Nock.Auto.spells = nil
    """)
    for n in learned:
        lua.execute('ENV.learn("%s")' % n)
    for k, v in (binds or {}).items():
        lua.execute('BINDS["%s"] = "%s"' % (k, v))
    if pet:
        lua.execute('PET.present = true; PET.name = "%s"; PET.family = "%s"' % (pet[0], pet[1]))
        for n, r in pet[2]:
            lua.execute('PET.learn("%s", %d)' % (n, r))
        lua.execute('PET.fillBar()')
    lua.execute('Nock.SpellbookIndex(true)')
    lua.execute('Nock.capture = {}; pcall(Nock.Setup.Apply, "bmlvl"); Nock.capture = nil')
    lua.execute('NockCharDB.auto = nil; NockCharDB.autoNews = nil')
    lua.execute('Nock.Auto.Baseline()')
    clear()

def fire(*events):
    for e in events:
        ev(e)

for e in ["ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD"]:
    ev(e)
timers()

# 1. Player learns Feign Death (no Rebuild click): bound, tiled, announced once.
world()
lua.execute('LEVEL = 30; ENV.learn("Feign Death")')
fire("LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED")
lua.execute('RunTimers(0.5)')
check(lines() == [], "nothing is said until the events settle (debounce)")
adv(3)
L = lines()
check(any(l.startswith("Added Feign Death to ") for l in L), "player learn: 'Added Feign Death to <key>' (%s)" % L)
check(lua.eval('BINDS.E') == "MACRO Nock:Feign", "player learn: E is bound to the Feign macro")
check(len(L) == 1, "exactly one chat line (%d)" % len(L))

# 2. New rank: Arcane Shot rank 1 -> 2.
world(24, BASE24)
lua.execute('ENV.known["Arcane Shot"] = 1; Nock.SpellbookIndex(true); Nock.Auto.spells = nil; Nock.Auto.Baseline()')
lua.execute('ENV.known["Arcane Shot"] = 2')
fire("SPELLS_CHANGED")
adv(3)
L = lines()
check(any("Arcane Shot upgraded to Rank 2" in l for l in L), "rank upgrade announced (%s)" % L)

# 3. Trainer bulk purchase: several learns seconds apart-ish -> one grouped message.
world(32, BASE24)
lua.execute('LEVEL = 32')
for n in ["Feign Death", "Frost Trap", "Flare", "Disengage", "Explosive Trap"]:
    lua.execute('ENV.learn("%s")' % n)
    fire("LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED")
    lua.execute('RunTimers(0.3)')
adv(3)
L = lines()
check(any("Trained 5 new spells" in l for l in L) and any(l.startswith("Added: ") and "Feign Death" in l for l in L), "bulk buy: one grouped message (%s)" % L)
check(len(L) <= 3, "bulk buy: at most 3 lines (%d)" % len(L))

# 4. Combat: nothing placed or said until the fight ends.
world()
lua.execute('LEVEL = 30; ENV.learn("Feign Death"); COMBAT = true')
fire("LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED")
adv(3)
check(lines() == [] and lua.eval('Nock.Auto.pending') is True, "combat: no chat, nothing run, the update is waiting for the fight to end")
lua.execute('COMBAT = false')
fire("PLAYER_REGEN_ENABLED")
adv(4)
L = lines()
check(any("Feign Death" in l for l in L) and lua.eval('Nock.Auto.pending') is False, "combat ends: it is placed and announced (%s)" % L)

# 5. User-set keys are never replaced; the message does not claim a key it did not bind.
world(24, BASE24)
lua.execute('BINDS.E = "MYOWNTHING"; BINDS.BUTTON3 = "TOGGLEAUTORUN"')
lua.execute('LEVEL = 30; ENV.learn("Feign Death")')
fire("LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED")
adv(4)
L = lines()
check(lua.eval('BINDS.E') == "MYOWNTHING" and lua.eval('BINDS.BUTTON3') == "TOGGLEAUTORUN", "user keys E and wheel click untouched")
check(any("Feign Death" in l and ("yours" in l or "no key" in l or "Bind" in l) for l in L) and not any("Added Feign Death to E" in l for l in L),
      "message says the key is his instead of claiming it (%s)" % L)

# 6. announce off: keys still filled, no chat.
world()
lua.execute('NockCharDB.autoNews = false; LEVEL = 30; ENV.learn("Feign Death")')
fire("LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED")
adv(4)
check(lua.eval('BINDS.E') == "MACRO Nock:Feign", "announce off: the key is still filled")
check(not any("Added" in l or "Pet " in l or "New pet" in l for l in lines()), "announce off: no new-spell chat lines (%s)" % lines())

# 7. Pet learns a new ability: announced with its pet bar slot.
world(24, BASE24, pet=("Rex", "Wolf", [("Bite", 3), ("Growl", 2)]))
lua.execute('PET.learn("Claw", 1); PET.fillBar()')
fire("PET_BAR_UPDATE")
adv(3)
L = lines()
check(any(l.startswith("Pet Rex learned Claw (Rank 1), on pet bar slot ") for l in L), "pet learns an ability: announced with its slot (%s)" % L)

# 8. Pet rank upgrade.
world(24, BASE24, pet=("Rex", "Wolf", [("Bite", 3), ("Growl", 2)]))
lua.execute('PET.learn("Bite", 4); PET.fillBar()')
fire("PET_BAR_UPDATE", "SPELLS_CHANGED")
adv(3)
L = lines()
check(any("Pet Rex: Bite upgraded to Rank 4, on pet bar slot" in l for l in L), "pet ability rank upgrade announced (%s)" % L)

# 9. A new pet is tamed: announced once with its abilities; summoning it again is quiet.
world(24, BASE24, pet=("Rex", "Wolf", [("Bite", 3), ("Growl", 2)]))
lua.execute('PET.name = "Whiskers"; PET.family = "Cat"; PET.book = {}; PET.learn("Claw", 2); PET.learn("Cower", 1); PET.learn("Dash", 1); PET.fillBar()')
fire("UNIT_PET")
adv(3)
L = lines()
check(any(l.startswith("New pet Whiskers (Cat)") and "Claw (Rank 2)" in l and "Dash" in l for l in L), "new pet tamed: announced with its abilities (%s)" % L)
clear()
fire("UNIT_PET"); adv(3)
check(lines() == [], "same pet summoned again: nothing said")
clear()
lua.execute('PET.name = "Rex"; PET.family = "Wolf"; PET.book = {}; PET.learn("Bite", 3); PET.learn("Growl", 2); PET.fillBar()')
fire("UNIT_PET"); adv(3)
check(lines() == [], "switching back to a known pet: nothing said")
clear()
lua.execute('PET.name = "Rexy"')
fire("UNIT_PET"); adv(3)
check(lines() == [], "renamed pet (same family and skills) is not a new pet")

# 10. Learned but not on the pet bar: Nock drops it on an EMPTY pet slot if there is one.
world(24, BASE24, pet=("Rex", "Wolf", [("Bite", 3)]))
lua.execute('PET.learn("Dash", 1)')   # in the book, bar not refreshed by the game
fire("PET_BAR_UPDATE"); adv(3)
L = lines()
check(any("Pet Rex learned Dash" in l and "on pet bar slot 5" in l for l in L), "pet skill missing from the bar goes on the first empty slot (%s)" % L)
check(lua.eval('PET.bar[4][1]') == "Bite" and lua.eval('PET.bar[8][1]') == "PET_MODE_AGGRESSIVE", "existing pet bar slots untouched")

# 11. No empty pet slot: it says where to find it instead of overwriting anything.
world(24, BASE24, pet=("Rex", "Wolf", [("Bite", 3), ("Claw", 3), ("Growl", 2), ("Cower", 1)]))
lua.execute('PET.learn("Dash", 1)')   # bar slots 4-7 are full
fire("PET_BAR_UPDATE"); adv(3)
L = lines()
check(any("Pet Rex learned Dash" in l and "pet spellbook" in l for l in L), "full pet bar: points to the pet spellbook, overwrites nothing (%s)" % L)
check(lua.eval('PET.bar[7][1]') == "Cower", "full pet bar slot 7 untouched")

# 12. Pet events in combat wait.
world(24, BASE24, pet=("Rex", "Wolf", [("Bite", 3)]))
lua.execute('PET.learn("Claw", 1); PET.fillBar(); COMBAT = true')
fire("PET_BAR_UPDATE"); adv(3)
check(lines() == [], "pet change in combat: quiet until the fight ends")
lua.execute('COMBAT = false'); fire("PLAYER_REGEN_ENABLED"); adv(4)
check(any("Pet Rex learned Claw" in l for l in lines()), "pet change announced after combat")

# 13. Stray events without a change say nothing.
world()
fire("SPELLS_CHANGED", "UNIT_PET", "PET_BAR_UPDATE"); adv(4)
check(lines() == [], "events with nothing new: silent")

print()
if fails:
    print("AUTO_FAIL:", len(fails), "failed")
    sys.exit(1)
print("AUTO_TEST_OK")
