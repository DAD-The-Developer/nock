#!/usr/bin/env python3
"""Nock 3.11.0: the best quest reward for a hunter (Lua 5.1 via lupa).

Mocks the reward screen (QuestInfoRewardsFrame buttons, GetNumQuestChoices, GetQuestItemLink), item info,
item tooltips and the worn gear. Parsing, scoring, comparing and drawing are the real addon code."""
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

lua.execute(r'''
RW = Nock.Rewards
ITEMS = {}        -- id -> { name, equipLoc, classID, subID, subName, minLevel, sell, lines = { {left, right, red} }, api = {} }
UNCACHED = {}     -- id -> true while the client "has not got it yet"
REQUESTED = {}
WORN = {}         -- slot -> id
CHOICES = {}      -- list of { id, count }
CALLS = { choose = 0, complete = 0 }
DUALWIELD = false
LEVEL = 32
QuestInfoFrame = { questLog = false }
function QuestChooseRewardItem() CALLS.choose = CALLS.choose + 1 end
function GetQuestReward() CALLS.complete = CALLS.complete + 1 end
function GetNumQuestChoices() return #CHOICES end
function link(id) return "|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:0:0|h[" .. (ITEMS[id] and ITEMS[id].name or "?") .. "]|h|r" end
function GetQuestItemLink(kind, i) local c = CHOICES[i]; return c and link(c[1]) end
function GetQuestItemInfo(kind, i) local c = CHOICES[i]; return c and ITEMS[c[1]].name, 1, c and c[2] or 1 end
function GetInventoryItemLink(unit, slot) local id = WORN[slot]; return id and link(id) end
function GetItemInfo(l)
  local id = tonumber(tostring(l):match("item:(%d+)"))
  local it = ITEMS[id]
  if not it or UNCACHED[id] then return nil end
  return it.name, l, it.quality or 2, 20, it.minLevel or 0, "x", it.subName or "", 1, it.equipLoc or "", 1, it.sell or 0, it.classID, it.subID
end
C_Item = { RequestLoadItemDataByID = function(id) REQUESTED[id] = (REQUESTED[id] or 0) + 1 end }
function GetItemStats(l)
  local id = tonumber(tostring(l):match("item:(%d+)")); local it = ITEMS[id]
  return it and it.api or {}
end
REAL_SCAN = RW.ScanLines
function RW.ScanLines(l)
  local id = tonumber(tostring(l):match("item:(%d+)")); local it = ITEMS[id]
  if not it or UNCACHED[id] then return nil end
  return it.lines
end
MOCK_SCAN = RW.ScanLines
local _isk = IsSpellKnown
function IsSpellKnown(id) if id == 674 then return DUALWIELD end return _isk(id) end
function UnitLevel(u) if u == "pet" then return 30 end return LEVEL end

-- item builders: lines mimic Classic tooltips
function item(id, name, o)
  o = o or {}
  local lines = { { left = name } }
  for _, s in ipairs(o.stats or {}) do lines[#lines + 1] = { left = s } end
  if o.armor then lines[#lines + 1] = { left = o.armor .. " Armor" } end
  if o.dps then lines[#lines + 1] = { left = "(" .. o.dps .. " damage per second)" } end
  for _, s in ipairs(o.equip or {}) do lines[#lines + 1] = { left = "Equip: " .. s } end
  for _, s in ipairs(o.red or {}) do lines[#lines + 1] = { left = s, red = true } end
  if o.classes then lines[#lines + 1] = { left = "Classes: " .. o.classes } end
  if o.use then lines[#lines + 1] = { left = "Use: " .. o.use } end
  ITEMS[id] = { name = name, equipLoc = o.loc or "", classID = o.cls, subID = o.sub, subName = o.subName, minLevel = o.req or 0,
    sell = o.sell or 0, lines = lines }
end
REAL_TB, REAL_TR = Nock.TraitPointsByTab, Nock.TalentRanks
POINTS = { 0, 0, 0 }   -- BM, MM, SV points spent
RANKS = {}             -- lowercase talent name -> rank
Nock.TraitPointsByTab = function() return POINTS[1], POINTS[2], POINTS[3] end
Nock.TalentRanks = function(names) local o = {}; for _, n in ipairs(names) do o[n] = RANKS[n] or 0 end return o end
function reset()
  POINTS = { 0, 0, 0 }; RANKS = {}
  NockCharDB.rewardsSpec = nil
  ITEMS, UNCACHED, REQUESTED, WORN, CHOICES = {}, {}, {}, {}, {}
  CALLS.choose, CALLS.complete = 0, 0
  DUALWIELD = false; LEVEL = 32
  RW.cache = {}; RW.pending = {}; RW.tries = 0
  RW.Hide()
  NockCharDB.rewards = nil
  QuestFrame = QuestFrame or CreateFrame("Frame", "QuestFrame", UIParent)
  QuestFrame:Show()
  for i = 1, 8 do
    local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
    if not b then b = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i, UIParent) end
    b.type = "choice"; b._id = i
  end
end
function choose(...) CHOICES = {}; for _, c in ipairs({ ... }) do CHOICES[#CHOICES + 1] = type(c) == "table" and c or { c, 1 } end end
function tagOf(i) local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i]; return b.nockReward and b.nockReward.tag._text or "" end
function borderOn(i)
  local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
  if not b.nockReward then return false end
  return b.nockReward.border[1]._shown ~= false
end
function lineText() return RW.line and RW.line._shown ~= false and RW.line.text._text or "" end
function show() RW.tries = 0; RW.Refresh() end
function tooltipFor(i)
  local out = {}
  local old = GameTooltip.AddLine
  GameTooltip.AddLine = function(self, t) out[#out + 1] = t end
  local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
  for _, fn in ipairs((b._hooks and b._hooks.OnEnter) or {}) do fn(b) end
  GameTooltip.AddLine = old
  return out
end
''')
L = lambda s: lua.eval(s)
def run(s): lua.execute(s)

# ---- 1. Stats upgrade --------------------------------------------------------------------------------------------------
run(r'''reset()
item(1, "Worn Leather Vest", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 60, stats = { "+3 Agility", "+4 Stamina" } })
item(2, "Wolf Hide Jerkin", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 70, stats = { "+8 Agility", "+4 Stamina" }, sell = 500 })
item(3, "Mage Robe", { loc = "INVTYPE_CHEST", cls = 4, sub = 1, subName = "Cloth", armor = 20, stats = { "+9 Intellect", "+8 Spirit" }, sell = 900 })
item(4, "Heavy Plate", { loc = "INVTYPE_CHEST", cls = 4, sub = 4, subName = "Plate", armor = 300, stats = { "+30 Strength", "+20 Stamina" }, sell = 7000 })
WORN[5] = 1
choose(2, 3, 4)
show()''')
check(L('RW.result and RW.result.pick') == 1, "stats upgrade: the leather agility chest is the pick")
check(L('tagOf(1)').startswith("Nock pick") and "+" in L('tagOf(1)') and "%" in L('tagOf(1)'), "pick tag reads 'Nock pick · +N%%' (%s)" % L('tagOf(1)'))
exp_new = 8*2.4 + 4*0.5 + 70*0.04; exp_old = 3*2.4 + 4*0.5 + 60*0.04
pct = round((exp_new - exp_old) / exp_old * 100)
check(("+%d%%" % pct) in L('tagOf(1)'), "percent is the score gain over the worn chest: +%d%% (%s)" % (pct, L('tagOf(1)')))
check(L('borderOn(1)') and not L('borderOn(2)') and not L('borderOn(3)'), "only the pick has the gold border")
check(L('tagOf(2)') in ("downgrade", "same") or L('tagOf(2)').startswith("-") or "%" in L('tagOf(2)'), "other usable choice has a compact tag (%s)" % L('tagOf(2)'))
check(L('tagOf(2)') == "downgrade", "cloth robe with int/spirit is a downgrade (%s)" % L('tagOf(2)'))
check(L('tagOf(3)') == "-", "plate shows '-' (cannot use) (%s)" % L('tagOf(3)'))
txt = L('lineText()')
check("Wolf Hide Jerkin" in txt and "+5 Agility" in txt and ("+%d%% upgrade over your Worn Leather Vest" % pct) in txt, "reason line under the frame (%s)" % txt)
check("Leather:" in txt, "armor class is shown (Leather)")
tt = list(L('tooltipFor(1)').values())
check(any("Nock pick" in x for x in tt) and any("+5 Agility" in x for x in tt), "tooltip has the pick and the reason (%s)" % tt)
tt2 = list(L('tooltipFor(3)').values())
check(any("Plate" in x and "can't wear" in x for x in tt2), "tooltip explains why plate is out (%s)" % tt2)
check(L('CALLS.choose') == 0 and L('CALLS.complete') == 0, "never chose a reward and never completed the quest")

# ---- 2. Weapon DPS -------------------------------------------------------------------------------------------------------
run(r'''reset()
item(10, "Hunting Bow", { loc = "INVTYPE_RANGED", cls = 2, sub = 2, subName = "Bows", dps = 20.0, stats = {} })
item(11, "Ranger's Longbow", { loc = "INVTYPE_RANGED", cls = 2, sub = 2, subName = "Bows", dps = 24.5, stats = { "+3 Agility" } })
item(12, "Plain Ring", { loc = "INVTYPE_FINGER", cls = 4, sub = 0, stats = { "+3 Agility" } })
item(13, "Rifle", { loc = "INVTYPE_RANGED", cls = 2, sub = 3, subName = "Guns", dps = 31.0, stats = {} })
WORN[18] = 10; WORN[11] = nil
choose(11, 12, 13)
show()''')
check(L('RW.result.pick') == 3, "weapon DPS: the rifle with +11 DPS beats the bow's +4.5 DPS (+3 agi) (pick=%s)" % L('RW.result.pick'))
d_bow = 4.5*14 + 3*2.4; d_gun = 11*14
check(abs(L('RW.result.rows[1].delta') - d_bow) < 0.01 and abs(L('RW.result.rows[3].delta') - d_gun) < 0.01, "deltas are DPS x14 + stats (%.1f / %.1f)" % (d_bow, d_gun))
check(L('RW.result.rows[2].state') == "newslot" and L('tagOf(2)') == "new slot", "ring into an empty ring slot says 'new slot' (%s)" % L('tagOf(2)'))
check("bullets" in L('lineText()'), "ranged type change is flagged (bullets) (%s)" % L('lineText()'))
check("DPS 20.0 to 24.5" in L('RW.Reason(RW.result.rows[1])'), "bow reason shows DPS 20.0 to 24.5 (%s)" % L('RW.Reason(RW.result.rows[1])'))
run(r'''reset()
item(10, "Hunting Bow", { loc = "INVTYPE_RANGED", cls = 2, sub = 2, subName = "Bows", dps = 20.0, stats = {} })
item(14, "Dull Bow", { loc = "INVTYPE_RANGED", cls = 2, sub = 2, subName = "Bows", dps = 15.0, stats = {} })
WORN[18] = 10
choose(14, 14)
show()''')
check(L('RW.result.rows[1].state') == "downgrade" and L('tagOf(1)') == "downgrade" and "nothing sells" in L('lineText()'), "a slower bow is a 'downgrade'")

# ---- 3. Unusable gear is never picked -------------------------------------------------------------------------------------
run(r'''reset()
item(20, "Cloth Cap", { loc = "INVTYPE_HEAD", cls = 4, sub = 1, subName = "Cloth", armor = 5, stats = { "+2 Agility" }, sell = 10 })
item(21, "Plate Helm", { loc = "INVTYPE_HEAD", cls = 4, sub = 4, subName = "Plate", armor = 200, stats = { "+20 Agility" } })
item(22, "Mail Helm", { loc = "INVTYPE_HEAD", cls = 4, sub = 3, subName = "Mail", armor = 150, stats = { "+20 Agility" } })
item(23, "War Mace", { loc = "INVTYPE_WEAPON", cls = 2, sub = 4, subName = "One-Handed Maces", dps = 40.0, stats = { "+20 Agility" } })
item(24, "Shield", { loc = "INVTYPE_SHIELD", cls = 4, sub = 6, subName = "Shields", armor = 500, stats = { "+20 Agility" } })
item(25, "Wand", { loc = "INVTYPE_RANGEDRIGHT", cls = 2, sub = 19, subName = "Wands", dps = 30.0, stats = { "+20 Agility" } })
item(26, "Warrior Helm", { loc = "INVTYPE_HEAD", cls = 4, sub = 2, subName = "Leather", armor = 80, stats = { "+20 Agility" }, classes = "Warrior" })
item(27, "Red Text Helm", { loc = "INVTYPE_HEAD", cls = 4, sub = 2, subName = "Leather", armor = 80, stats = { "+20 Agility" }, red = { "Requires Skinning (300)" } })
choose(21, 22, 23, 24, 25, 26, 27, 20)
show()''')
check(L('RW.result.pick') == 8, "unusable: plate/mail(32)/mace/shield/wand/other class/red text never win; the cloth cap does (pick=%s)" % L('RW.result.pick'))
for i, why in [(1, "plate"), (3, "mace"), (4, "shield"), (5, "wand"), (6, "other class"), (7, "red text")]:
    check(L('RW.result.rows[%d].state' % i) == "unusable" and L('tagOf(%d)' % i) == "-", "%s shows '-' (%s)" % (why, L('RW.result.rows[%d].why' % i)))
check(L('RW.result.rows[2].state') == "later" and L('tagOf(2)') == "lvl 40" and "level 40" in L('RW.result.rows[2].why'), "mail before 40: 'lvl 40', never picked (%s)" % L('RW.result.rows[2].why'))
run(r'''LEVEL = 40; RW.cache = {}; show()''')
check(L('RW.result.rows[2].state') in ("upgrade", "newslot") and L('RW.result.pick') == 2, "mail is usable at 40 and wins on agility/armor (pick=%s)" % L('RW.result.pick'))
check(L('RW.result.rows[1].state') == "unusable", "plate stays unusable at 40")
run(r'''reset(); LEVEL = 20
item(30, "Level 30 Bow", { loc = "INVTYPE_RANGED", cls = 2, sub = 2, subName = "Bows", dps = 40.0, req = 30, stats = {}, sell = 700 })
item(31, "Old Dagger", { loc = "INVTYPE_WEAPON", cls = 2, sub = 15, subName = "Daggers", dps = 3.0, stats = {}, sell = 50 })
WORN[18] = nil; WORN[16] = 31
choose(30, 31)
show()''')
check(L('RW.result.rows[1].state') == "later" and L('tagOf(1)') == "lvl 30", "gear above your level is 'lvl N' and never the pick (%s)" % L('tagOf(1)'))
check(L('RW.result.pick') != 1, "level-locked item is not the pick")
check("Level 30 Bow becomes an upgrade at level 30" in L('lineText()') and L('RW.result.sell') == 2, "level-locked upgrade is not offered for sale; the line says when it becomes one (%s)" % L('lineText()'))

# ---- 4. Sell fallback ----------------------------------------------------------------------------------------------------
run(r'''reset()
item(40, "Worn Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 50, stats = { "+6 Agility", "+5 Stamina" } })
item(41, "Frayed Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+2 Agility" }, sell = 12500 })
item(42, "Cloth Slippers", { loc = "INVTYPE_FEET", cls = 4, sub = 1, subName = "Cloth", armor = 10, stats = { "+3 Spirit" }, sell = 90 })
item(43, "Fine Plate Greaves", { loc = "INVTYPE_FEET", cls = 4, sub = 4, subName = "Plate", armor = 300, stats = {}, sell = 50000 })
WORN[8] = 40
choose(41, 42, 43)
show()''')
check(L('RW.result.pick') == None and L('RW.result.sell') == 3, "no upgrade: pick is the highest vendor price, even plate (sell=%s)" % L('RW.result.sell'))
txt = L('lineText()')
check("No upgrade, best to sell (5g)" in txt and "Fine Plate Greaves" in txt, "line says 'No upgrade, best to sell (5g)' (%s)" % txt)
check("Nock pick" in L('tagOf(3)') and "sell 5g" in L('tagOf(3)') and L('borderOn(3)'), "the sell choice has the border and 'sell 5g' (%s)" % L('tagOf(3)'))
run(r'''reset()
item(40, "Worn Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 50, stats = { "+6 Agility", "+5 Stamina" } })
item(41, "Frayed Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+2 Agility" }, sell = 3050 })
item(44, "Stack of Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+1 Agility" }, sell = 1000 })
WORN[8] = 40
choose(41, { 44, 4 })
show()''')
check(L('RW.result.sell') == 2 and "(40s)" in L('lineText()'), "sell value counts the stack (4 x 10s = 40s) (%s)" % L('lineText()'))
run(r'''reset()
item(40, "Worn Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 50, stats = { "+6 Agility" } })
item(41, "Junk Boots", { loc = "INVTYPE_FEET", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+2 Agility" }, sell = 3050 })
WORN[8] = 40
choose(41)
show()''')
check(L('RW.result.pick') == None and "Nock pick" not in L('tagOf(1)') and not L('borderOn(1)'), "a single choice never says 'Nock pick' or draws a border (%s)" % L('tagOf(1)'))
check(L('tagOf(1)') == "sell 3s 50c" or "sell" in L('tagOf(1)') or L('tagOf(1)') == "downgrade", "single choice still gets its compact tag (%s)" % L('tagOf(1)'))

# ---- 5. Uncached items: request, retry on GET_ITEM_INFO_RECEIVED, and on a timer -------------------------------------------
run(r'''reset()
item(50, "Worn Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 20, stats = { "+2 Agility" } })
item(51, "New Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+6 Agility" } })
item(52, "Other Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 10, stats = { "+1 Agility" } })
WORN[10] = 50
UNCACHED[51] = true
choose(51, 52)
Nock.Rewards.result = nil
RW.Refresh()''')
check(L('RW.result') is None and L('REQUESTED[51]') == 1 and L('tagOf(2)') == "", "uncached item: nothing drawn yet, item data requested")
run(r'''UNCACHED[51] = nil
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "GET_ITEM_INFO_RECEIVED", 51, true) end end
RunTimers(1)''')
check(L('RW.result and RW.result.pick') == 1 and "Nock pick" in L('tagOf(1)'), "GET_ITEM_INFO_RECEIVED: pick is drawn (%s)" % L('tagOf(1)'))
run(r'''reset()
item(50, "Worn Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 20, stats = { "+2 Agility" } })
item(51, "New Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+6 Agility" } })
item(52, "Other Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 10, stats = { "+1 Agility" } })
WORN[10] = 50
UNCACHED[52] = true
choose(51, 52)
RW.tries = 0; RW.Refresh()
UNCACHED[52] = nil      -- the event never comes; the timer retry must find it
RunTimers(1)''')
check(L('RW.result and RW.result.pick') == 1, "event missed: the timer retry still gets there")
run(r'''reset()
item(50, "Worn Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 20, stats = { "+2 Agility" } })
item(51, "New Gloves", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 30, stats = { "+6 Agility" } })
item(52, "Never Loads", { loc = "INVTYPE_HAND", cls = 4, sub = 2, subName = "Leather", armor = 10, stats = { "+1 Agility" } })
WORN[10] = 50
UNCACHED[52] = true
choose(51, 52)
RW.tries = 0; RW.Refresh()
for i = 1, 12 do RunTimers(8) end''')
check(L('RW.result and RW.result.pick') == 1 and L('tagOf(2)') == "", "an item that never loads: retries stop, the readable one is still judged (tag2='%s')" % L('tagOf(2)'))

# ---- 6. Slots: rings, trinkets, two-hand vs dual wield ----------------------------------------------------------------------
run(r'''reset()
item(60, "Good Ring", { loc = "INVTYPE_FINGER", cls = 4, sub = 0, stats = { "+8 Agility" } })
item(61, "Weak Ring", { loc = "INVTYPE_FINGER", cls = 4, sub = 0, stats = { "+2 Agility" } })
item(62, "New Ring", { loc = "INVTYPE_FINGER", cls = 4, sub = 0, stats = { "+5 Agility" } })
WORN[11] = 60; WORN[12] = 61
choose(62, 62)
show()''')
check(L('RW.result.rows[1].over') == "Weak Ring" and abs(L('RW.result.rows[1].delta') - 3*2.4) < 0.01, "rings: replaces the weaker ring (delta %.1f)" % L('RW.result.rows[1].delta'))
run(r'''WORN[12] = nil; RW.cache = {}; show()''')
check(L('RW.result.rows[1].state') == "newslot", "rings: second ring slot empty is 'new slot'")
run(r'''reset()
item(63, "Trinket A", { loc = "INVTYPE_TRINKET", cls = 4, sub = 0, stats = { "+4 Stamina" } })
item(64, "Trinket B", { loc = "INVTYPE_TRINKET", cls = 4, sub = 0, equip = { "Increases attack power by 40." } })
item(65, "Proc Trinket", { loc = "INVTYPE_TRINKET", cls = 4, sub = 0, equip = { "Your attacks do something strange." }, use = "Gain a thing." })
WORN[13] = 63; WORN[14] = 64
choose(65, 65)
show()''')
check(L('RW.result.rows[1].f.unscored') is True and "can't score" in L('RW.Reason(RW.result.rows[1])'), "trinket with an unparsed effect is flagged 'has an effect Nock can't score'")
check(L('RW.result.rows[1].over') == "Trinket A", "trinkets: replaces the weaker trinket")
# two-hander vs dual wield
run(r'''reset()
item(70, "Dagger MH", { loc = "INVTYPE_WEAPONMAINHAND", cls = 2, sub = 15, subName = "Daggers", dps = 10.0, stats = { "+3 Agility" } })
item(71, "Dagger OH", { loc = "INVTYPE_WEAPONOFFHAND", cls = 2, sub = 15, subName = "Daggers", dps = 8.0, stats = { "+2 Agility" } })
item(72, "Big Staff", { loc = "INVTYPE_2HWEAPON", cls = 2, sub = 10, subName = "Staves", dps = 25.0, stats = { "+12 Agility", "+10 Stamina" } })
item(73, "Short Sword", { loc = "INVTYPE_WEAPON", cls = 2, sub = 7, subName = "One-Handed Swords", dps = 12.0, stats = { "+5 Agility" } })
WORN[16] = 70; WORN[17] = 71; DUALWIELD = true
choose(72, 73)
show()''')
two = (25*2 + 12*2.4 + 10*0.5); old = (10*2 + 3*2.4) + (8*1 + 2*2.4)
check(abs(L('RW.result.rows[1].delta') - (two - old)) < 0.01 and len(list(L('RW.result.rows[1].cmp.repl').values())) == 2, "two-hander replaces main AND off hand (delta %.1f)" % L('RW.result.rows[1].delta'))
check(L('RW.result.rows[2].slot') in ("main hand", "off hand"), "one-hand weapon is judged for the hand it gains most in (%s)" % L('RW.result.rows[2].slot'))
run(r'''reset()
item(71, "Dagger OH", { loc = "INVTYPE_WEAPONOFFHAND", cls = 2, sub = 15, subName = "Daggers", dps = 8.0, stats = { "+2 Agility" } })
item(70, "Dagger MH", { loc = "INVTYPE_WEAPONMAINHAND", cls = 2, sub = 15, subName = "Daggers", dps = 10.0, stats = { "+3 Agility" } })
WORN[16] = 70; DUALWIELD = false; LEVEL = 15
choose(71, 71)
show()''')
check(L('RW.result.rows[1].state') == "later" and L('tagOf(1)') == "lvl 20", "off-hand weapon without Dual Wield is 'lvl 20', never the pick (%s)" % L('tagOf(1)'))
run(r'''reset()
item(72, "Big Staff", { loc = "INVTYPE_2HWEAPON", cls = 2, sub = 10, subName = "Staves", dps = 25.0, stats = { "+12 Agility" } })
item(74, "Held Orb", { loc = "INVTYPE_HOLDABLE", cls = 4, sub = 0, stats = { "+4 Agility" } })
WORN[16] = 72
choose(74, 74)
show()''')
check(L('RW.result.rows[1].state') == "nocompare" and L('tagOf(1)') == "-", "off-hand item with a two-hander equipped: can't compare, shows '-' (%s)" % L('RW.result.rows[1].why'))

# ---- 7. Tooltip text parsing -----------------------------------------------------------------------------------------------
run(r'''reset()
item(80, "Parsed", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 100,
  stats = { "+7 Agility", "+5 Stamina", "+2 Strength", "+3 Intellect", "+4 Spirit", "+10 Fire Resistance" },
  equip = { "Increases attack power by 20.", "Increases ranged attack power by 12.", "Improves your chance to get a critical strike by 1%.",
            "Improves your chance to hit by 2%.", "Restores 4 mana per 5 sec.", "Increases damage done by magical spells by 11.",
            "Increases your chance to dodge an attack by 1%.", "Increased Bows +2." } })
item(81, "Conditional", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", equip = { "Increases attack power by 20 when fighting Undead." } })
local f = RW.Facts(GetQuestItemLink and ("item:80"))
''')
f = lambda k: L('RW.Facts("item:80").%s' % k)
st = lambda k: L('RW.Facts("item:80").stats.%s' % k)
check(st('agi') == 7 and st('sta') == 5 and st('str') == 2 and st('int') == 3 and st('spi') == 4 and st('res') == 10, "primary stats and resistance parsed")
check(st('ap') == 20 and st('rap') == 12 and st('crit') == 1 and st('hit') == 2 and st('mp5') == 4, "Equip: attack power, ranged AP, crit, hit and mp5 parsed")
check(f('armor') == 100 and not f('unscored'), "armor parsed; spell damage/dodge/skill lines are not flagged")
check(L('RW.Facts("item:81").unscored') is True and not L('RW.Facts("item:81").stats.ap'), "conditional attack power ('when fighting Undead') is not counted and is flagged")
run(r'''reset()
item(82, "Api", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", stats = { "+1 Agility" } })
ITEMS[82].api = { ITEM_MOD_AGILITY_SHORT = 9, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12.5 }''')
check(L('RW.Facts("item:82").stats.agi') == 9 and L('RW.Facts("item:82").dps') == 12.5, "GetItemStats wins per stat when it has the stat; DPS from it when the tooltip has none")

# ---- 7b. The real tooltip reader (fake GameTooltip), colours and escapes --------------------------------------------------
run(r'''reset()
local fake = { rows = {} }
function fake:SetOwner() end
function fake:ClearLines() self.rows = {} end
function fake:SetHyperlink(l) self.rows = ITEMS[tonumber(l:match("item:(%d+)"))].lines end
function fake:NumLines() return #self.rows end
RW.tip = fake
RW.ScanLines = REAL_SCAN
for i = 1, 8 do
  _G["NockRewardScanTextLeft" .. i] = { GetText = function() return fake.rows[i] and fake.rows[i].left end,
    GetTextColor = function() if fake.rows[i] and fake.rows[i].red then return 1, 0.125, 0.125 end return 1, 1, 1 end }
  _G["NockRewardScanTextRight" .. i] = { GetText = function() return fake.rows[i] and fake.rows[i].right end }
end
item(95, "Real Scan", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 10, stats = { "|cff00ff00+4 Agility|r" }, red = { "|cffff2020Requires Skinning (300)|r", "Requires Level 50" } })
''')
f2 = L('RW.Facts("item:95")')
check(f2 is not None and L('RW.Facts("item:95").stats.agi') == 4 and L('RW.Facts("item:95").redText') == "Requires Skinning (300)", "real tooltip reader: stats through colour escapes, red requirement line found, red 'Requires Level' ignored")

run("RW.ScanLines = MOCK_SCAN; RW.tip = nil")

# ---- 8. Toggle and slash ---------------------------------------------------------------------------------------------------
run(r'''reset()
item(1, "Worn Leather Vest", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 60, stats = { "+3 Agility" } })
item(2, "Wolf Hide Jerkin", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 70, stats = { "+8 Agility" } })
item(3, "Other Jerkin", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", armor = 20, stats = { "+1 Agility" } })
WORN[5] = 1
choose(2, 3)
show()''')
check(L('borderOn(1)'), "baseline: marked")
run(r'''SlashCmdList.NOCK("rewards off")''')
check(not L('RW.Enabled()') and L('tagOf(1)') == "" and not L('borderOn(1)') and L('lineText()') == "", "/nock rewards off: tags, border and line gone")
run(r'''show()''')
check(L('tagOf(1)') == "" and L('lineText()') == "", "off: stays off on the next refresh")
run(r'''SlashCmdList.NOCK("rewards on")''')
check(L('RW.Enabled()') and "Nock pick" in L('tagOf(1)'), "/nock rewards on: back")
check(L('NockCharDB.rewards') is True, "saved in NockCharDB.rewards")

# ---- 9. Events draw it by themselves; closing the window clears it -------------------------------------------------------------
run(r'''RW.Hide()
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "QUEST_COMPLETE") end end
RunTimers(1)''')
check("Nock pick" in L('tagOf(1)'), "QUEST_COMPLETE draws the pick by itself")
run(r'''for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "QUEST_FINISHED") end end''')
check(L('tagOf(1)') == "" and not L('borderOn(1)'), "QUEST_FINISHED clears it")
check(L('CALLS.choose') == 0 and L('CALLS.complete') == 0, "still never chose or completed anything")
check(L('RW.Reason(RW.result and RW.result.rows[1] or RW.Judge(RW.Facts("item:2")))') != "", "reason text available")

# ---- 10. Quest log preview uses the quest log API ----------------------------------------------------------------------------------
run(r'''reset()
item(90, "Log Worn", { loc = "INVTYPE_WAIST", cls = 4, sub = 2, subName = "Leather", armor = 10, stats = { "+1 Agility" } })
item(91, "Log Reward", { loc = "INVTYPE_WAIST", cls = 4, sub = 2, subName = "Leather", armor = 20, stats = { "+6 Agility" } })
item(92, "Log Other", { loc = "INVTYPE_WAIST", cls = 4, sub = 2, subName = "Leather", armor = 5, stats = { "+1 Agility" } })
WORN[6] = 90
QuestInfoFrame.questLog = true
function GetNumQuestLogChoices() return 2 end
function GetQuestLogItemLink(kind, i) return link(i == 1 and 91 or 92) end
function GetQuestLogChoiceInfo(i) return "x", 1, 1 end
show()''')
check(L('RW.result.pick') == 1, "quest log preview: judged through GetQuestLogItemLink (pick=%s)" % L('RW.result.pick'))
run(r'''QuestInfoFrame.questLog = false; GetNumQuestLogChoices = nil''')

# ---- 11. Spec: detection, blend, talents, override -------------------------------------------------------------------------
W = lambda k: L('RW.Profile().w.%s' % k)
G = lambda k: L('RW.W.%s' % k)
approx = lambda a, b: abs(a - b) < 0.001
run("reset()")
check(L('RW.Profile().label') is None and all(approx(W(k), G(k)) for k in ("agi", "crit", "sta", "rap", "int", "dpsRanged")), "no talent points: generic hunter weights, no spec named")
run("POINTS = { 0, 31, 20 }")
check(L('RW.Profile().label') == "Marksmanship" and approx(W('crit'), 20) and approx(W('rap'), 31/51*1.15 + 20/51*1.0), "31 MM / 20 SV: Marksmanship, blended by points (rap %.3f, crit %.1f)" % (W('rap'), W('crit')))
run("POINTS = { 0, 5, 0 }")
check(L('RW.Profile().label') == "Marksmanship" and approx(W('crit'), 18 + (20 - 18) * 5/15) and approx(W('rap'), 1 + 0.15 * 5/15), "5 points: the tree only blends in a third (crit %.2f)" % W('crit'))
run("POINTS = { 0, 2, 0 }")
check(L('RW.Profile().label') is None and 18 < W("crit") < 18.3, "2 points: not named, barely moves (crit %.3f)" % W('crit'))
run("POINTS = { 15, 15, 15 }")
check(L('RW.Profile().label') in ("BM/MM",), "even split: hybrid label (%s)" % L('RW.Profile().label'))
check(approx(W('sta'), (0.65 + 0.5 + 0.65) / 3) and approx(W('crit'), (18 + 20 + 20) / 3), "even split averages the three trees")
run("POINTS = { 0, 31, 20 }; NockCharDB.rewardsSpec = 'bm'")
check(L('RW.Profile().label') == "Beast Mastery" and approx(W('sta'), 0.65) and approx(W('crit'), 18), "override beats the points (Beast Mastery weights)")
run("NockCharDB.rewardsSpec = nil; POINTS = { 0, 0, 0 }; NockCharDB.rewardsSpec = 'sv'")
check(approx(W('crit'), 20) and L('RW.Profile().label') == "Survival", "override works with no talents at all")
run("reset(); RANKS = { ['lightning reflexes'] = 5, ['mortal shots'] = 5, ['survivalist'] = 5, ['ranged weapon specialization'] = 5 }")
check(approx(W('agi'), 2.4 * 1.15) and approx(W('crit'), 18 * 1.3) and approx(W('sta'), 0.5 * 1.1) and approx(W('dpsRanged'), 14 * 1.05), "key talents multiply: Lightning Reflexes x1.15 Agi, Mortal Shots x1.30 crit, Survivalist x1.10 Sta, RWS x1.05 ranged DPS")
run("reset(); RANKS = { ['lightning reflexes'] = 2 }")
check(approx(W('agi'), 2.4 * 1.06), "partial ranks scale (2/5 Lightning Reflexes = x1.06)")

# shared-layer fallbacks for the points
run("reset(); SAVE_TP = Nock.TraitPointsByTab; Nock.TraitPointsByTab = nil; Core = Nock.Core; Core.P.points.bm, Core.P.points.mm, Core.P.points.sv = 0, 20, 0")
check(list(L('{RW.Points()}').values()) == [0, 20, 0, "core"], "falls back to the points Core.ScanSpec stored")
run("Core.P.points.mm = 0; function GetNumTalentTabs() return 3 end; function GetNumTalents() return 0 end; function GetTalentTabInfo(i) return ({ 'Beast Mastery', 'Marksmanship', 'Survival' })[i], 'x', ({ 3, 9, 14 })[i] end")
check(list(L('{RW.Points()}').values()) == [3, 9, 14, "classic"], "then the Classic GetTalentTabInfo (name, icon, points)")
run("GetNumTalentTabs = nil; GetTalentTabInfo = nil; Nock.TraitPointsByTab = SAVE_TP")

# scenario 1: Agility item vs ranged AP + crit item
S1 = r'''reset()
item(100, "Agile Jerkin", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", stats = { "+9 Agility", "+3 Stamina" } })
item(101, "Sharpshooter Vest", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", equip = { "Increases ranged attack power by 4.", "Improves your chance to get a critical strike by 1%." } })
choose(100, 101)'''
def pick_with(setup):
    run(S1); run(setup); run("show()")
    return L('RW.result.pick'), L('RW.result.label')
p, lab = pick_with("")
check(p == 1 and lab is None, "generic: the Agility item wins (22.0 vs 23.1) (pick=%s)" % p)
p, lab = pick_with("POINTS = { 0, 31, 20 }; RANKS = { ['mortal shots'] = 5 }")
check(p == 2 and lab == "Marksmanship", "Marksmanship: the ranged AP + crit item wins (pick=%s, %s)" % (p, lab))
p, lab = pick_with("POINTS = { 0, 0, 31 }; RANKS = { ['lightning reflexes'] = 5 }")
check(p == 1 and lab == "Survival", "Survival with Lightning Reflexes: Agility item wins (pick=%s, %s)" % (p, lab))
p, lab = pick_with("POINTS = { 31, 0, 0 }")
check(p == 1 and lab == "Beast Mastery", "Beast Mastery: Agility item wins (pick=%s, %s)" % (p, lab))
p, lab = pick_with("POINTS = { 0, 0, 31 }")
check(p == 2, "Survival without Lightning Reflexes leans to crit: the ranged AP + crit item wins narrowly (pick=%s)" % p)
S2 = r'''reset()
item(102, "Keen Tunic", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", stats = { "+4 Agility", "+1 Stamina" } })
item(103, "Sturdy Tunic", { loc = "INVTYPE_CHEST", cls = 4, sub = 2, subName = "Leather", stats = { "+2 Agility", "+6 Stamina", "+4 Intellect" } })
choose(102, 103)'''
def pick2(setup):
    run(S2); run(setup); run("show()")
    return L('RW.result.pick')
check(pick2("") == 1, "generic: +4 Agility beats the Stamina/Intellect tunic")
check(pick2("POINTS = { 31, 0, 0 }") == 2, "Beast Mastery: Stamina and Intellect (pet uptime, mana) tip it to the sturdy tunic")
check(pick2("POINTS = { 0, 31, 0 }") == 1, "Marksmanship: keeps the Agility tunic")
check(pick2("POINTS = { 0, 0, 31 }; RANKS = { ['lightning reflexes'] = 5 }") == 1, "Survival with Lightning Reflexes: keeps the Agility tunic")

# the card, tooltip and tag name the spec
run(S1); run("POINTS = { 0, 31, 20 }; RANKS = { ['mortal shots'] = 5 }; show()")
check(L('lineText()').startswith("Nock pick (Marksmanship): Sharpshooter Vest"), "card: 'Nock pick (Marksmanship): ...' (%s)" % L('lineText()'))
tt = list(L('tooltipFor(2)').values())
check(any("Nock pick for a hunter (Marksmanship)" in x for x in tt), "tooltip header names the spec (%s)" % tt)
check(L('tagOf(2)').startswith("Nock pick") and "(" not in L('tagOf(2)'), "button tag stays short (%s)" % L('tagOf(2)'))
run(S1); run("show()")
check(L('lineText()').startswith("Nock pick: "), "no talents: no spec in the card (%s)" % L('lineText()'))

# talents or level change while the reward window is open: the visible tags are recomputed
run(S1); run("show()")
check(L('RW.result.pick') == 1 and L('RW.result.label') is None, "window open, generic: pick 1")
run("""POINTS = { 0, 31, 20 }; RANKS = { ['mortal shots'] = 5 }
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "CHARACTER_POINTS_CHANGED") end end
RunTimers(1)""")
check(L('RW.result.pick') == 2 and "Marksmanship" in L('lineText()') and "Nock pick" in L('tagOf(2)') and not L('borderOn(1)') and L('borderOn(2)'), "CHARACTER_POINTS_CHANGED: tags, border and card move to the new pick (%s)" % L('lineText()'))
run("""POINTS = { 0, 0, 31 }; RANKS = { ['lightning reflexes'] = 5 }
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "TRAIT_CONFIG_UPDATED") end end
RunTimers(1)""")
check(L('RW.result.pick') == 1 and "Survival" in L('lineText()'), "TRAIT_CONFIG_UPDATED: re-scored again (%s)" % L('lineText()'))
run("""POINTS = { 0, 31, 20 }; RANKS = { ['mortal shots'] = 5 }
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "PLAYER_TALENT_UPDATE") end end
RunTimers(1)""")
check(L('RW.result.pick') == 2, "PLAYER_TALENT_UPDATE: re-scored")
run("""QuestFrame:Hide(); REFRESHES = 0
local orig = RW.Refresh; RW.Refresh = function() REFRESHES = REFRESHES + 1; return orig() end
POINTS = { 0, 0, 31 }
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "CHARACTER_POINTS_CHANGED") end end
RunTimers(1); RW.Refresh = orig; QuestFrame:Show()""")
check(L('REFRESHES') == 0, "no reward window open: a talent change does no work")
run(S1 + "\nLEVEL = 32\nitem(104, 'Mail Vest', { loc = 'INVTYPE_CHEST', cls = 4, sub = 3, subName = 'Mail', armor = 150, stats = { '+30 Agility' } })\nchoose(100, 104)\nshow()")
check(L('RW.result.rows[2].state') == "later", "level 32: mail waits")
run("""LEVEL = 40
for _, f in ipairs(FRAMES) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "PLAYER_LEVEL_UP") end end
RunTimers(1)""")
check(L('RW.result.pick') == 2, "PLAYER_LEVEL_UP with the window open: mail becomes the pick at 40")

# override: slash, saved value, auto, bad word
run(S1); run("POINTS = { 0, 0, 31 }; RANKS = { ['lightning reflexes'] = 5 }; show()")
check(L('RW.result.pick') == 1, "auto (Survival + Lightning Reflexes): pick 1")
run("SlashCmdList.NOCK('rewards spec mm')")
check(L('NockCharDB.rewardsSpec') == "mm" and L('RW.Spec()') == "mm" and L('RW.result.label') == "Marksmanship", "/nock rewards spec mm: saved and used, card says Marksmanship (%s)" % L('RW.result.label'))
run("SlashCmdList.NOCK('rewards spec nonsense')")
check(L('NockCharDB.rewardsSpec') == "mm", "a bad word changes nothing")
run("SlashCmdList.NOCK('rewards spec auto')")
check(L('NockCharDB.rewardsSpec') is None and L('RW.Spec()') == "auto" and L('RW.result.label') == "Survival", "/nock rewards spec auto: back to reading the talents")
for word, label in [("bm", "Beast Mastery"), ("sv", "Survival"), ("marks", "Marksmanship")]:
    run("SlashCmdList.NOCK('rewards spec %s')" % word)
    check(L('RW.result.label') == label, "spec word '%s' -> %s" % (word, label))
run("RW.SetSpec('mm')")
check(L('NockCharDB.rewardsSpec') == "mm", "Options setter works")
run("RW.SetSpec('auto')")
check(L('NockCharDB.rewardsSpec') is None, "Options setter: auto clears the override")
run("CHAT_LOG = {}; SlashCmdList.NOCK('rewards')")
out = " ".join(str(v) for v in L('CHAT_LOG').values())
check("Spec:" in out and "Agility" in out and "crit" in out, "/nock rewards prints the spec and the weights in force (%s)" % out[:140])

# the real trait-tree readers (fake C_Traits): spent points per tab and talent ranks by name
run(r'''
NAMES = { [1] = "Lightning Reflexes", [2] = "Mortal Shots", [3] = "Endurance Training" }
RANKS_REAL = { [1] = 4, [2] = 5, [3] = 0 }
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 9 } } end,
  GetTreeNodes = function() return { 1, 2, 3 } end,
  GetNodeInfo = function(cfg, id) return { ID = id, entryIDs = { id * 10 }, currentRank = RANKS_REAL[id], maxRanks = 5 } end,
  GetEntryInfo = function(cfg, e) return { definitionID = e * 10 } end,
  GetDefinitionInfo = function(d) return { overrideName = NAMES[d / 100] } end,
  GetGroupDisplayInfoByTreeID = function() return { { groupID = 11, displayName = "Beast Mastery" }, { groupID = 12, displayName = "Marksmanship" }, { groupID = 13, displayName = "Survival" } } end,
  GetGroupCurrencyInfo = function() return { { traitNodeGroupID = 11, currencyInfos = { { spent = 3 } } }, { traitNodeGroupID = 12, currencyInfos = { { spent = 22 } } }, { traitNodeGroupID = 13, currencyInfos = { { spent = 8 } } } } end,
}
Nock.TraitPointsByTab, Nock.TalentRanks = REAL_TB, REAL_TR
''')
check(list(L('{RW.Points()}').values()) == [3, 22, 8, "traits"], "real reader: points per tab from the trait groups (3 BM / 22 MM / 8 SV)")
r = L('Nock.TalentRanks({ "lightning reflexes", "mortal shots", "endurance training", "survivalist" })')
check(r["lightning reflexes"] == 4 and r["mortal shots"] == 5 and r["endurance training"] == 0 and r["survivalist"] == 0, "real reader: ranks by talent name (absent talents are 0)")
check(approx(L('RW.Profile().w.agi'), 2.4 * 1.12) and approx(L('RW.Profile().w.crit') / 1.3, L('RW.Profile().w.crit') / 1.3) and L('RW.Profile().label') == "Marksmanship", "live profile through the real readers: Lightning Reflexes 4/5 = Agility x1.12, Marksmanship")
run("C_Traits = nil; C_ClassTalents = nil")
check(L('Nock.TalentRanks({ "mortal shots" })') is None, "no trait API: ranks are nil, scoring carries on")
run("Nock.TraitPointsByTab, Nock.TalentRanks = function() return POINTS[1], POINTS[2], POINTS[3] end, function(names) local o = {}; for _, n in ipairs(names) do o[n] = RANKS[n] or 0 end return o end")

print()
if fails:
    print("REWARDS_FAIL:", len(fails), "failed")
    sys.exit(1)
print("REWARDS_TEST_OK")
