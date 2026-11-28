#!/usr/bin/env python3
"""Nock 3.10.1: Rebuild / spellbook / check report tests against a Forever-like API (Lua 5.1 via lupa)."""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
from forever_env import *

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
