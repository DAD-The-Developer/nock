#!/usr/bin/env python3
"""Nock 3.13.0: gold while levelling (Tool_Gold.lua, Data_Gold.lua, the junk seller guard) (Lua 5.1 via lupa)."""
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
G = Nock.Gold
Core = Nock.Core
-- items: id -> { name, quality, price (vendor, each), classID, subclassID, subType, stack }
ITEMS = {
  [100] = { "Broken Fang", 0, 45, 15, 0, "Junk", 20 },
  [101] = { "Ruined Pelt", 0, 30000, 15, 0, "Junk", 1 },        -- a grey worth 3g (still junk: vendor only)
  [200] = { "Light Leather", 1, 15, 7, 6, "Leather", 20 },
  [201] = { "Copper Ore", 1, 5, 7, 7, "Metal & Stone", 20 },
  [202] = { "Peacebloom", 1, 10, 7, 9, "Herb", 20 },
  [300] = { "Heavy Bracers", 1, 12000, 4, 2, "Leather", 1 },   -- white, sells for 1g 20s
  [301] = { "Cheap Cloak", 1, 300, 4, 1, "Cloth", 1 },
  [400] = { "Bandit Cinch of the Monkey", 2, 800, 4, 2, "Leather", 1 },
  [500] = { "Pattern: Embossed Leather Gloves", 1, 50, 9, 1, "Leatherworking", 1 },
  [600] = { "Wolf Heart", 1, 0, 12, 0, "Quest", 20 },
  [700] = { "Hornwood Recurve Bow", 1, 30, 2, 2, "Bows", 1 },
}
function GetItemInfo(item)
  local id = tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
  local t = id and ITEMS[id]
  if not t then return nil end
  return t[1], "|cffffffff|Hitem:" .. id .. "::::|h[" .. t[1] .. "]|h|r", t[2], 10, 0, "x", t[6], t[7], "", 0, t[3], t[4], t[5]
end
C_Item = nil
function link(id) return select(2, GetItemInfo(id)) end
BAGS = {}
USED = {}
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot)
  local b = BAGS[bag * 100 + slot]; if not b then return nil end
  local t = ITEMS[b[1]]
  return { itemID = b[1], stackCount = b[2], quality = t[2], isLocked = false, hasNoValue = t[3] == 0, hyperlink = link(b[1]) }
end
C_Container.UseContainerItem = function(bag, slot) USED[#USED + 1] = BAGS[bag * 100 + slot] and BAGS[bag * 100 + slot][1] or "empty" end
function setbags(list) BAGS = {}; for i, v in ipairs(list) do BAGS[i] = v end; Core.BagsDirty() end
MONEY = 0
function GetMoney() return MONEY end
FIRED = {}
local fire = Nock.Alerts.Fire
Nock.Alerts.Fire = function(self, id, vars, opts) FIRED[#FIRED + 1] = { id = id, vars = vars, opts = opts }; return true end
function lines() local t = {}; for _, v in ipairs(CHAT_LOG) do t[#t + 1] = tostring(v) end; return table.concat(t, " || ") end
function reset() CHAT_LOG = {}; FIRED = {}; USED = {}; _G.Auctionator = nil; Core.Set("gold", "threshold", nil); Core.Set("gold", "mount", nil) end
''')

# ---- pricing ----------------------------------------------------------------------------------------------------
run('reset(); I = G.Info(200); V = G.Value(I, 14)')
check(L('I.price') == 15 and L('I.classID') == 7 and L('I.subType') == "Leather", "item info read from GetItemInfo (price, class, sub type)")
check(L('V.vendor') == 15 and L('V.ah') is None and L('V.best') == 210 and L('V.source') == "vendor", "no Auctionator: vendor price only, 14 x 15c = 2s 10c")
run('T = G.TipLines(G.Info(200), 14)')
check(L('T[1][1]') == "Vendor  15c each, 2s 10c for 14" and L('T[2]') is None, "tooltip: vendor each + stack, no auction line (%s)" % L('T[1][1]'))
run('T = G.TipLines(G.Info(300), 1)')
check(L('T[1][1]') == "Vendor  1g 20s 0c" and L('T[2][1]') == "Keep — worth selling" and L('T[2].keep') is True, "white worth 1g 20s: vendor line + keep tag")
run('T = G.TipLines(G.Info(100), 5)')
check(L('T[1][2]') == "junk — Nock sells it at the next vendor" and L('T[2]') is None, "grey: says the junk seller sells it, never a keep tag")
run('T = G.TipLines(G.Info(600), 3)')
check(L('T[1][1]') == "No vendor price" and L('T[2]') is None, "quest item: no price, no keep tag")
# tooltip hook adds the lines
run(r'''setbags({ { 300, 1 } })
TT = { added = {} }
function TT:AddLine(t) self.added[#self.added + 1] = t end
function TT:AddDoubleLine(a, b) self.added[#self.added + 1] = a .. " | " .. b end
function TT:Show() self.shown = true end
G.OnBagTip(TT, 0, 1)''')
check(L('#TT.added') == 2 and "Keep" in L('TT.added[2]') and L('TT.shown') is True, "bag tooltip hook adds the value lines (%s)" % L('TT.added[2]'))
run(r'''Core.Set("gold", "value", false); TT.added = {}; G.OnBagTip(TT, 0, 1); Core.Set("gold", "value", nil)''')
check(L('#TT.added') == 0, "/nock gold value off: tooltips untouched")

# ---- keep threshold -----------------------------------------------------------------------------------------------
run('reset()')
check(L('G.Threshold()') == 10000, "default keep value is 1g")
check(L('(G.IsKeep(G.Info(300), G.Value(G.Info(300), 1)))') is True, "1g 20s white: keep")
check(L('(G.IsKeep(G.Info(301), G.Value(G.Info(301), 1)))') is False, "3s white: no keep tag")
check(L('select(2, G.IsKeep(G.Info(400), G.Value(G.Info(400), 1)))') == "quality", "any green: keep (8s vendor)")
check(L('select(2, G.IsKeep(G.Info(500), G.Value(G.Info(500), 1)))') == "recipe", "recipe / pattern: keep")
check(L('(G.IsKeep(G.Info(101), G.Value(G.Info(101), 1)))') is False, "grey worth 3g: no keep tag (vendor is the only buyer; the junk seller handles it)")
run('SlashCmdList.NOCK("gold threshold 0.02")')
check(L('G.Threshold()') == 200 and L('(G.IsKeep(G.Info(301), G.Value(G.Info(301), 1)))') is True, "/nock gold threshold 0.02 -> 2s; the 3s cloak now gets the tag")
check(L('(G.IsKeep(G.Info(200), G.Value(G.Info(200), 20)))') is True, "the threshold counts the stack: 20 Light Leather = 3s")
run('SlashCmdList.NOCK("gold threshold 1")')
check(L('G.Threshold()') == 10000, "back to 1g")

# ---- junk-only autosell safety --------------------------------------------------------------------------------------
run(r'''reset(); Core.Set("vendor", "sell", nil)
setbags({ { 100, 5 }, { 300, 1 }, { 400, 1 }, { 500, 1 }, { 101, 1 }, { 200, 20 }, { 600, 3 } })
V = Core.Module("vendor")
J = V.JunkList(Core.ScanBags())''')
check(L('#J') == 2 and L('J[1].id') == 100 and L('J[2].id') == 101, "junk list: only the two greys (keep-tagged and valuable items never)")
run(r'''function IsShiftKeyDown() return false end
function CanMerchantRepair() return false end
Core.Dispatch("MERCHANT_SHOW")
for i = 1, 5 do RunTimers(0.5) end''')
check(L('#USED') == 2 and L('USED[1]') == 100 and L('USED[2]') == 101, "at a vendor only the greys are sold (%s)" % L('table.concat(USED, ",")'))
# bags shift mid-sale: the queued slot now holds a green -> skipped
run(r'''USED = {}; CHAT_LOG = {}
setbags({ { 100, 5 }, { 400, 1 } })
Q = V.JunkList(Core.ScanBags())
BAGS[1] = { 400, 1 }   -- the grey moved, a green is in its slot now
''')
check(L('V.StillJunk(Q[1])') is False, "re-check before selling: a slot that now holds a green is not sold")
run('BAGS[1] = { 100, 5 }')
check(L('V.StillJunk(Q[1])') is True, "same grey still there: sold")
run('Core.Dispatch("MERCHANT_CLOSED")')

# ---- session gold and gold per hour ---------------------------------------------------------------------------------
check(L('G.PerHour(5000, 30)') is None, "first minute: no gold per hour yet")
check(L('G.PerHour(5000, 1800)') == 10000, "50s in 30 min = 1g per hour")
check(L('G.PerHour(12345, 3600)') == 12345, "one hour: the same")
run(r'''reset(); MONEY = 100000; G.ResetSession(); local t0 = NOW
MONEY = 130000; Core.Dispatch("PLAYER_MONEY")   -- +3g
MONEY = 125000; Core.Dispatch("PLAYER_MONEY")   -- repair -50s
MONEY = 145000; Core.Dispatch("PLAYER_MONEY")   -- +2g
NOW = t0 + 1800
S = G.Session()''')
check(L('S.earned') == 50000 and L('S.spent') == 5000 and L('S.net') == 45000, "session: earned 5g, spent 50s, net 4g 50s")
check(L('S.perHour') == 100000, "5g earned in 30 min = 10g per hour")
run('SlashCmdList.NOCK("gold reset"); S = G.Session()')
check(L('S.earned') == 0 and L('S.perHour') is None, "/nock gold reset starts a new session")

# ---- Auctionator present / absent ------------------------------------------------------------------------------------
run(r'''reset()
check_absent = G.HasAuctionator()
AH = { [200] = 60, [300] = 0, [202] = 25 }
Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(caller, l)
  CALLER = caller
  local id = tonumber(l:match("item:(%d+)")); return AH[id]
end } } }
V2 = G.Value(G.Info(200), 20)
V3 = G.Value(G.Info(300), 1)''')
check(L('check_absent') is False, "Auctionator absent: detected")
check(L('V2.ah') == 60 and L('V2.best') == 1200 and L('V2.source') == "auction" and L('CALLER') == "Nock", "Auctionator present: 20 Light Leather at 60c = 12s, read through API.v1 as caller Nock")
check(L('V3.ah') is None and L('V3.best') == 12000, "no auction price (0): falls back to vendor")
run('T = G.TipLines(G.Info(200), 20)')
check(L('T[2][1]') == "Auction  60c each, 12s 0c for 20" and L('T[2][2]') == "Auctionator", "tooltip gets the auction line, labelled Auctionator")
run(r'''Auctionator.API.v1.GetAuctionPriceByItemLink = function() error("boom") end
V4 = G.Value(G.Info(200), 2)''')
check(L('V4.ah') is None and L('V4.vendor') == 15, "Auctionator erroring: guarded by pcall, vendor only")
run(r'''Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, l) local id = tonumber(l:match("item:(%d+)")); return AH[id] end } } }
setbags({ { 200, 20 }, { 202, 10 }, { 300, 1 } })
B = G.BagValue(Core.ScanBags())''')
check(L('B.vendor') == 300 + 100 + 12000 and L('B.ah') == 1200 + 250 + 12000, "bag value: vendor %s, auction %s (auction where known, else vendor)" % (L('B.vendor'), L('B.ah')))
run('Auctionator = nil; B = G.BagValue(Core.ScanBags())')
check(L('B.ah') is None, "no Auctionator: no auction total")
check(L('B.keep[1].name') == "Heavy Bracers", "keep list in the bags, dearest first")

# ---- dashboard -------------------------------------------------------------------------------------------------------------
run(r'''reset(); MONEY = 0; G.ResetSession(); local t0 = NOW
MONEY = 20000; Core.Dispatch("PLAYER_MONEY"); NOW = t0 + 3600
Core.P.level = 30
D = G.DashInfo()''')
check(L('D.value') == "+2g" and L('D.note') == "2g / hr", "dashboard: +2g this session, 2g / hr (%s, %s)" % (L('D.value'), L('D.note')))
check(L('D.sub') == "Bags 1g 24s vendor  ·  Mount 2%", "dashboard line: bag vendor value and mount fund (%s)" % L('D.sub'))
check(abs(L('D.meter') - 0.02) < 1e-9, "the meter is the mount fund")
run(r'''NockCharDB.dash = NockCharDB.dash or {}; NockCharDB.dash.shown = true
if Nock.Dash.SetShown then Nock.Dash.SetShown(true) end
Nock.Dash.Update()''')
check(L('Nock.Dash.frame and Nock.Dash.frame.gold.value._text') == "+2g", "dashboard panel paints the gold block (%s)" % L('Nock.Dash.frame and Nock.Dash.frame.gold.value._text'))
run('SlashCmdList.NOCK("gold dash off"); Nock.Dash.Update()')
check(L('G.DashInfo()') is None and L('Nock.Dash.frame.gold.value._shown') is False, "/nock gold dash off hides it")
run('SlashCmdList.NOCK("gold dash on")')

# ---- valuable drop alert ------------------------------------------------------------------------------------------------
run(r'''reset()
function loot(id, n) Core.Dispatch("CHAT_MSG_LOOT", n and string.format("You receive loot: %sx%d.", link(id), n) or string.format("You receive loot: %s.", link(id))) end
loot(400)''')
check(L('#FIRED') == 1 and L('FIRED[1].id') == "gold.drop" and L('FIRED[1].vars.why') == "Green", "green drop: one calm toast")
run('FIRED = {}; loot(500)')
check(L('#FIRED') == 1 and L('FIRED[1].vars.why') == "Recipe", "recipe drop: toast")
run('FIRED = {}; loot(300)')
check(L('#FIRED') == 1 and L('FIRED[1].vars.why') == "Worth 1g 20s" and L('FIRED[1].vars.worth') == "Vendor 1g 20s", "white over the threshold: toast with its worth")
run('FIRED = {}; loot(301); loot(200, 5); loot(100, 3); loot(600)')
check(L('#FIRED') == 0, "cheap white, small leather stack, cheap grey, quest item: no toast")
run('FIRED = {}; loot(200, 20); AH = { [200] = 600 }; Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, l) return AH[tonumber(l:match("item:(%d+)"))] end } } }; loot(200, 20)')
check(L('#FIRED') == 1 and L('FIRED[1].vars.worth') == "Auction 1g 20s  ·  vendor 3s", "with Auctionator a leather stack worth 1g 20s at auction alerts")
run(r'''FIRED = {}; Auctionator = nil
Core.Dispatch("CHAT_MSG_LOOT", "Thrall receives loot: " .. link(400) .. ".")''')
check(L('#FIRED') == 0, "other players' loot is ignored")
run(r'''FIRED = {}; ITEMS[401] = nil
Core.Dispatch("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:401::::|h[Owl Bracers]|h|r.")''')
check(L('#FIRED') == 0, "item not cached yet: waits")
run(r'''ITEMS[401] = { "Owl Bracers", 2, 900, 4, 2, "Leather", 1 }; Core.Dispatch("GET_ITEM_INFO_RECEIVED", 401)''')
check(L('#FIRED') == 1 and "Owl Bracers" in L('FIRED[1].vars.item'), "item info arrives: the toast fires")
run('FIRED = {}; SlashCmdList.NOCK("gold drops off"); loot(400); SlashCmdList.NOCK("gold drops on")')
check(L('#FIRED') == 0, "/nock gold drops off: silent")

# ---- mount fund ------------------------------------------------------------------------------------------------------------------
run('reset(); F = G.Fund(250000)')
check(L('F.target') == 1000000 and L('F.left') == 750000 and abs(L('F.pct') - 0.25) < 1e-9, "mount fund: 25g of 100g (riding 90g + mount 10g from the data)")
check(L('Nock.Data.Gold.Mount.riding') == 900000 and L('Nock.Data.Gold.Mount.mount') == 100000 and L('Nock.Data.Gold.Mount.level') == 40, "data: riding 90g, level-40 mount 10g")
check("Classic data" in L('F.source'), "labelled Classic data")
run('SlashCmdList.NOCK("gold mount 80"); F = G.Fund(250000)')
check(L('F.target') == 800000 and L('F.source') == "your target", "/nock gold mount 80 sets your own target")
run('F = G.Fund(900000)')
check(L('F.left') == 0 and L('F.pct') == 1, "over the target: full, nothing left")
run('SlashCmdList.NOCK("gold mount auto"); F = G.Fund(0)')
check(L('F.target') == 1000000, "/nock gold mount auto goes back to the data")

# ---- professions ----------------------------------------------------------------------------------------------------------------
run(r'''reset()
SKILLS = {}
function GetNumSkillLines() return #SKILLS end
function GetSkillLineInfo(i) local s = SKILLS[i]; return s[1], s[4], true, s[2], 0, 0, s[3] end
SKILLS = { { "Professions", 0, 0, true }, { "Skinning", 52, 75 }, { "Fishing", 10, 75 } }
P = G.Professions()''')
check(L('P.Skinning.rank') == 52 and L('P.Skinning.max') == 75 and L('P.Professions') is None, "reads professions from the skills window")
run('N = G.NextRank("Skinning", 52, 75, 12)')
check(L('N.rank') == "Journeyman" and L('N.ready') is True and L('N.cost') == 500 and L('N.cap') == 150, "Skinning 52/75 at level 12: Journeyman ready (5s, cap 150)")
run('N = G.NextRank("Skinning", 52, 75, 8)')
check(L('N.ready') is False and L('N.why') == "needs level 10", "at level 8: needs level 10")
run('N = G.NextRank("Mining", 130, 150, 18)')
check(L('N.rank') == "Expert" and L('N.why') == "needs level 20", "Mining 130/150 at 18: Expert needs level 20")
run('N = G.NextRank("Herbalism", 210, 225, 40)')
check(L('N.rank') == "Artisan" and L('N.ready') is True and L('N.cost') == 50000, "Herbalism 210/225 at 40: Artisan ready (5g)")
run('TIPS = G.ProfTips(P, 12)')
check("Mining or Herbalism" in L('TIPS[1]') and "Skinning" not in L('TIPS[1]'), "has Skinning: suggests Mining or Herbalism (%s)" % L('TIPS[1]'))
check(L('TIPS[2]') == "Train Journeyman Skinning now (5s): 52/75, it raises the cap to 150.", "train reminder line (%s)" % L('TIPS[2]'))
run('TIPS = G.ProfTips({}, 12)')
check("Skinning + Mining or Herbalism" in L('TIPS[1]'), "no professions: Skinning + Mining or Herbalism")
run('TIPS = G.ProfTips({ Tailoring = { rank = 40, max = 75 }, Enchanting = { rank = 30, max = 75 } }, 12)')
check(L('#TIPS') == 0, "two crafting professions already: no nagging")
run(r'''FIRED = {}; CHAT_LOG = {}; for k in pairs(G.told) do G.told[k] = nil end
Core.P.level = 12; G.CheckProfs(); G.CheckProfs()''')
check(L('#FIRED') == 1 and L('FIRED[1].id') == "gold.train", "rank reminder fires once (not every check)")
check(L('#CHAT_LOG') == 1 and "Gold tip" in L('lines()'), "free slot tip said once in chat")
run(r'''setbags({ { 200, 20 }, { 201, 10 }, { 202, 5 }, { 300, 1 } })
H = G.HoldList(Core.ScanBags())''')
check(L('#H') == 3 and L('H[1].name') == "Light Leather" and L('H[1].ah') is None, "worth holding: leather, ore, herb stacks (vendor value without Auctionator)")

# ---- ammo at a vendor ------------------------------------------------------------------------------------------------------------
run(r'''reset()
OFF = { { id = 2512, price = 10, qty = 200 }, { id = 2515, price = 50, qty = 200 }, { id = 3030, price = 300, qty = 200 },
        { id = 2516, price = 10, qty = 200 }, { id = 11285, price = 1000, qty = 200 }, { id = 700, price = 30 } }
B1, C1 = G.PickAmmo(OFF, "Arrow", 30)''')
check(L('B1.name') == "Razor Arrow" and L('C1.name') == "Sharp Arrow", "level 30 bow: Razor Arrow best, Sharp Arrow cheaper but weaker")
run('B2 = G.PickAmmo(OFF, "Arrow", 12)')
check(L('B2.name') == "Sharp Arrow", "level 12: Sharp Arrow (Razor needs 25)")
run('B3 = G.PickAmmo(OFF, "Bullet", 30)')
check(L('B3.name') == "Light Shot", "gun: only bullets count")
check(L('G.PickAmmo({ { id = 700 } }, "Arrow", 30)') is None, "a vendor with no ammo: nothing said")
run(r'''function GetInventoryItemLink(u, s) if s == 18 then return link(700) end end
function GetMerchantNumItems() return #OFF end
function GetMerchantItemID(i) return OFF[i].id end
function GetMerchantItemInfo(i) return "x", 1, OFF[i].price, OFF[i].qty end
Core.P.level = 30; CHAT_LOG = {}
Core.Dispatch("MERCHANT_SHOW"); Core.Dispatch("MERCHANT_CLOSED")''')
check("Best arrows here for you: Razor Arrow, 3s per 200 (7.5 damage). Sharp Arrow is cheaper (50c) but weaker (3.5)." in L('lines()'), "at the vendor: one ammo line (%s)" % L('lines()'))
check(L('#USED') == 0, "nothing bought or sold by the gold tool")

# ---- trainer ranks that can wait ------------------------------------------------------------------------------------------------
run(r'''W = G.CanWait({ { name = "Arcane Shot", rank = 4, cost = 2000 }, { name = "Scorpid Sting", rank = 2, cost = 1800 },
  { name = "Volley", rank = 1, cost = 3000 }, { name = "Swordsmanship", rank = 2, cost = 100 } },
  function(n) return n == "Arcane Shot" end)''')
check(L('#W') == 1 and L('W[1].name') == "Scorpid Sting", "trainer: Scorpid Sting R2 (not on your bars) can wait; Arcane Shot (on a tile) and new spells never")

# ---- camps ---------------------------------------------------------------------------------------------------------------
run(r'''CAMPS = Nock.Data.Gold.Camps
ok = true; nskin, ncoin = 0, 0
for _, c in ipairs(CAMPS) do
  if not (c[2] > 0 and c[3] >= 0 and c[3] <= 100 and c[4] >= 0 and c[4] <= 100 and c[5] <= c[6] and c[7] >= 8 and #c[8] >= 1) then ok = false end
  if c[1] == "skin" then nskin = nskin + 1 else ncoin = ncoin + 1 end
end''')
check(L('ok') and L('nskin') > 50 and L('ncoin') > 50, "camp data well formed (%d skinning, %d coin camps)" % (L('nskin'), L('ncoin')))
check(L('G.CampInBand(6, 9, 8)') and not L('G.CampInBand(20, 24, 8)') and not L('G.CampInBand(1, 3, 12)'), "camps are filtered to your level band")
run('G.AddPins()')
check(L('G.kinds.skin ~= nil and G.kinds.coin ~= nil'), "two pin kinds on the shared map pins")
run(r'''local K = Nock.Pins.KINDS[G.kinds.skin]
E = { data = { "skin", 1412, 47.6, 47.7, 7, 8, 84, { "Prairie Stalker", "Flatland Cougar" }, nil } }
Core.P.level = 8; SHOW8 = K.filter(E); Core.P.level = 20; SHOW20 = K.filter(E)
TIP = K.tip(E)''')
check(L('SHOW8') is True and L('SHOW20') is False, "Mulgore stalker camp shows at 8, not at 20")
check(L('TIP[1]') == "84 spawn spots, level 7-8" and "Classic data" in L('TIP[4]'), "pin tip: spawn count, levels, names, labelled Classic data")
run('Core.P.level = 8; SlashCmdList.NOCK("gold pins off"); SHOWOFF = Nock.Pins.KINDS[G.kinds.skin].filter(E); SlashCmdList.NOCK("gold pins on")')
check(L('SHOWOFF') is False, "/nock gold pins off hides them")

# ---- slash -------------------------------------------------------------------------------------------------------------------------
run('CHAT_LOG = {}; SlashCmdList.NOCK("gold")')
check("This session" in L('lines()') and "Mount fund" in L('lines()') and "keep at 1g" in L('lines()'), "/nock gold prints the status")

print()
if fails:
    print("GOLD_FAIL:", len(fails), "failed")
    sys.exit(1)
print("GOLD_TEST_OK")
