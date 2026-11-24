-- Nock 3.4.0: hunter tools tests (Lua 5.1, run by run_tools.py).
dofile(NOCK_DIR .. "../tests/stubs_tools.lua")
local fails = 0
local function check(cond, msg)
  if cond then print("ok  " .. msg) else print("FAIL " .. msg); fails = fails + 1 end
end
local function has(list, needle)
  for _, v in ipairs(list) do
    if tostring(v):find(needle, 1, true) then return true end
  end
  return false
end

-- Secure button attributes.
local baseCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
  local f = baseCreate(kind, name, parent)
  f._attr = {}
  f._template = template
  rawset(f, "SetAttribute", function(self, k, v) self._attr[k] = v end)
  rawset(f, "GetAttribute", function(self, k) return self._attr[k] end)
  return f
end

local caps = { BUTTON4 = Obj("Cap") }
caps.BUTTON4.entry = { kind = "spell", name = "Wing Clip" }
caps.BUTTON4:Show()
Nock.Overlay = function() return { caps = caps, utilCaps = {} } end
local known = {}
for _, b in ipairs(BOOK) do known[b[1]] = b[3] end
Nock.PlayerKnows = function(name) local id = known[name]; return id ~= nil, id, name, nil end
POINTS = { 21, 5, 0 }
Nock.TraitPointsByTab = function() return POINTS[1], POINTS[2], POINTS[3] end

local FILES = {
  "PinsData.lua", "HunterMap.lua", "Quiver.lua", "Core.lua", "Movers.lua", "Alerts.lua", "Data_Alerts.lua", "Data_Spells.lua", "Data_Pets.lua", "Data_TameSpawns.lua", "Data_Food.lua", "Data_Route.lua",
  "Tool_PetCare.lua", "Tool_Supplies.lua", "Tool_Vendor.lua", "Tool_Range.lua", "Tool_Taming.lua", "Tool_Aspects.lua",
  "Tool_Feign.lua", "Tool_Guide.lua", "Tool_Trainer.lua", "Tool_Tracker.lua", "Data_PvP.lua", "Tool_PvP.lua",
}
for _, f in ipairs(FILES) do
  local chunk = assert(loadfile(NOCK_DIR .. f))
  chunk("Nock")
end
local Core = Nock.Core
local function fire(ev, ...)
  for _, f in ipairs(FRAMES) do
    local h = f._scripts.OnEvent
    if h and f._events and f._events[ev] then h(f, ev, ...) end
  end
end
local function tickFor(seconds)
  local steps = math.floor(seconds / 0.1 + 0.5)
  for _ = 1, steps do
    NOW = NOW + 0.1
    Core._Tick(nil, 0.1)
    RunTimers()
  end
end
local function lastAlert() return Core.lastFired or "" end
local function clearAlert() Core.lastFired = nil; Core.lastAlert = nil; Core.HideAlert(); if Nock.Alerts then Nock.Alerts:ResetCooldowns() end end

fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
RunTimers()

-- Registry ----------------------------------------------------------------------
check(#Core.order == 11, "eleven tools registered (" .. #Core.order .. ")")
local errs = 0
-- 3.5.0 pins: hunter vendor categories -----------------------------------------------
local PN = Nock.Pins
local pc = PN.Counts()
for _, k in ipairs({ "ranged:A", "ranged:H", "quiver:A", "quiver:H", "petfood:A", "petfood:H", "quest:A", "quest:H", "flight:A", "flight:H" }) do
  check((pc[k] or 0) > 0, "pins have " .. k .. " (" .. tostring(pc[k]) .. ")")
end
check(PN.KindOn("flight") and PN.KindOn("ranged") and PN.KindOn("petfood"), "3.10.0: flight paths on by default, vendor kinds on")
local arrowVendor
for _, r in ipairs(Nock.PinData) do
  if r[8]:find("a", 1, true) and r[9] > 0 then arrowVendor = r break end
end
check(arrowVendor ~= nil, "an arrow vendor with stock data")
local ev = { goods = arrowVendor[8], stock = Nock.PinStock[arrowVendor[9]] }
local oldInv, oldInst = GetInventoryItemID, C_Item.GetItemInfoInstant
GetInventoryItemID = function(_, slot) if slot == 18 then return 2504 end return oldInv(_, slot) end
C_Item.GetItemInfoInstant = function(id) return id, "Weapon", "Bows", "INVTYPE_RANGED", 1, 2, 2 end
check(PN.AmmoCode() == "a", "bow equipped: arrows are your ammo")
local gl = PN.GoodsLines(ev)
local sawArrows = false
for _, l in ipairs(gl) do
  if l.left:find("Arrows", 1, true) then
    sawArrows = true
    check(l.mark == "your ammo" and l.right ~= "", "arrows line marked as your ammo with the best arrow: " .. l.right)
  end
end
check(sawArrows, "tooltip lists the vendor's arrows")
GetInventoryItemID, C_Item.GetItemInfoInstant = oldInv, oldInst
local codes = PN.PetDietCodes()
check(codes and codes.M and codes.F and not codes.B, "pet diet codes from the pet's food types")
local bestLow = PN.StockByGoods(ev, 1)
check(bestLow.a and bestLow.a.best, "best item for a level 1 hunter exists")
check(Nock.PinItems and next(Nock.PinItems) ~= nil, "vendor item table loaded")

-- 3.5.0 alert manager -------------------------------------------------------------------
local A = Nock.Alerts
check(A and A.defs["feign.resisted"] and A.defs["range.clipoff"] and A.defs["supplies.leave"], "alert registry loaded")
local nDefs = 0
for _ in pairs(A.defs) do nDefs = nDefs + 1 end
check(nDefs >= 20, "20+ alerts declared (" .. nDefs .. ")")
A:Clear(); A:ResetCooldowns()
local function visibleIds()
  local out = {}
  for _, t in ipairs(A.visible or {}) do out[#out + 1] = t.item.def.id end
  return table.concat(out, ",")
end
A:Fire("supplies.town", { list = "Ammo 100/600" })
A:Fire("aspect.travel", { pick = "Aspect of the Cheetah" })
check(#A.visible == 2, "two toasts visible: " .. visibleIds())
A:Fire("train.levelup", { list = "Serpent Sting 3" })
check(#A.visible == 2 and #A.queue == 1, "third info alert waits in the queue")
A:Fire("feign.resisted", nil, { force = true })
check(A.visible[1].item.def.id == "feign.resisted", "critical goes on top: " .. visibleIds())
check(#A.visible == 2, "still only two on screen")
A:Fire("feign.resisted", nil, { force = true })
check(#A.visible == 2, "duplicate refreshes instead of stacking")
A:Clear(); A:ResetCooldowns()
check(A:Fire("supplies.town", { list = "x" }), "first fire shows")
A:Clear()
check(not A:Fire("supplies.town", { list = "x" }), "cooldown blocks a repeat")
A:ResetCooldowns(); A:SetCategory("supplies", false)
check(not A:Fire("supplies.town", { list = "x" }), "category off blocks")
A:SetCategory("supplies", true); A:SetAlert("supplies.town", false)
check(not A:Fire("supplies.town", { list = "x" }), "single alert off blocks")
A:SetAlert("supplies.town", true); A:SetQuiet(true)
check(not A:Fire("supplies.town", { list = "x" }) and A:Fire("feign.resisted", nil, { force = true }), "quiet mode: critical only")
A:SetQuiet(false); A:Clear(); A:ResetCooldowns()
check(not A:Fire("range.deadzone"), "PvP-only alert stays off in the open world")
check(A.Format("{pet} is unhappy", { pet = "Grr" }) == "Grr is unhappy", "title templates")
A:Test()
check(#A.visible >= 1, "test alerts show")
SlashCmdList.NOCK("alerts test")
check(#A.visible >= 1, "/nock alerts test")
A:Clear()
check(type(_G.Nock_TestAlerts) == "function", "test alerts binding function")

for id, e in pairs(Core.errors or {}) do print("  error " .. id .. ": " .. e); errs = errs + 1 end
check(errs == 0, "no tool errors after login")
for _, id in ipairs(Core.order) do
  local m = Core.modules[id]
  check(m.cmd and #m.cmd > 0 and m.name and m.help, id .. ": has command, name and help")
  local ok, out = pcall(m.Report, m)
  check(ok and type(out) == "table" and #out > 0, id .. ": report works")
  check(Core.Enabled(id), id .. ": on by default")
end
local cmds = {}
for _, id in ipairs(Core.order) do for _, c in ipairs(Core.modules[id].cmd) do
  check(not cmds[c], "unique command " .. c); cmds[c] = true
end end
for _, taken in ipairs({ "xp", "guide", "next", "options", "help", "threat", "pins", "quiver" }) do
  check(not cmds[taken], "does not steal /nock " .. taken)
end

-- Profile layer -------------------------------------------------------------------
local P = Core.P
check(P.level == 24 and not P.isMax, "profile level 24")
check(Core.Rank("Serpent Sting") == 3 and Core.Rank("Wing Clip") == 1, "known ranks from the spellbook")
check(P.rankInfo == true, "rank info detected")
check(Core.Rank("Volley") == 0, "unknown spell rank 0")
check(P.spec == "bm", "spec bm from talent points")
POINTS = { 11, 11, 9 }; fire("CHARACTER_POINTS_CHANGED")
check(P.spec == "hybrid" and Core.Leans("bm") and Core.Leans("marks") and not Core.Leans("survival"), "hybrid spec leans")
POINTS = { 0, 5, 26 }; fire("CHARACTER_POINTS_CHANGED")
check(P.spec == "survival", "survival spec")
INSTANCE = { true, "party" }; fire("ZONE_CHANGED_NEW_AREA")
check(P.context == "dungeon", "dungeon context")
INSTANCE = { true, "raid" }; fire("ZONE_CHANGED_NEW_AREA")
check(P.context == "raidinstance", "raid instance context")
INSTANCE = { false, "none" }; fire("ZONE_CHANGED_NEW_AREA")
check(P.context == "solo", "solo context")

-- Settings and slash -----------------------------------------------------------------
SlashCmdList.NOCK("pet off")
check(not Core.Enabled("pet") and NockCharDB.mods.pet.on == false, "/nock pet off persists")
SlashCmdList.NOCK("pet on")
check(Core.Enabled("pet"), "/nock pet on")
SlashCmdList.NOCK("options")
check(LAST_BASE == "options", "other /nock words reach the base handler")
for k in pairs(NockCharDB.mods) do check(not k:find("-", 1, true), "no name keys in mods: " .. k) end
CHAT = {}
SlashCmdList.NOCK("help")
check(has(CHAT, "/nock pet") and has(CHAT, "/nock range") and has(CHAT, "/nock tools"), "help lists the tools")
CHAT = {}
SlashCmdList.NOCK("tools")
check(has(CHAT, "Wing Clip"), "/nock tools lists every tool")

-- 1 Pet ---------------------------------------------------------------------------------
local Pet = Core.Module("pet")
check(Pet.FoodGrade(20, 24) == 3 and Pet.FoodGrade(14, 24) == 2 and Pet.FoodGrade(10, 24) == 1 and Pet.FoodGrade(5, 24) == 0, "food grades")
local diets = Pet.Diets()
check(diets.Meat and diets.Fish and not diets.Bread, "diet from GetPetFoodTypes")
Core.BagsDirty()
local food = Pet.PickFood(Core.Bags(), diets, 24)
check(food and food.id == 2287, "picks the meat the cat eats")
local btn = _G.NockFeedButton
check(btn and btn._attr.type == "macro", "secure feed button exists")
Pet.UpdateButton()
check(btn._attr.macrotext == "/cast Feed Pet\n/use item:2287", "feed macro uses the best food")
CONTENTS[0][6] = { 3770, 4 }; Core.BagsDirty(); Pet.UpdateButton()
check(btn._attr.macrotext:find("item:3770", 1, true), "prefers food that keeps a level 24 pet happy")
FOODTYPES = { "Fungus" }; Pet.UpdateButton()
check(btn._attr.macrotext:find("/run", 1, true) == 1, "no matching food: macro warns instead")
FOODTYPES = { "Meat", "Fish" }
CONTENTS[0][6] = { 3770, 4 }; Core.BagsDirty(); Pet.UpdateButton()
COMBAT = true; CONTENTS[0][6] = nil; Core.BagsDirty(); Pet.UpdateButton()
check(btn._attr.macrotext:find("item:3770", 1, true), "never rewrites the secure button in combat")
COMBAT = false; fire("PLAYER_REGEN_ENABLED")
check(btn._attr.macrotext == "/cast Feed Pet\n/use item:2287", "rewrites after combat")
clearAlert()
HAPPY = 1; fire("UNIT_HAPPINESS", "pet")
check(lastAlert():find("is unhappy", 1, true), "unhappy pet alert")
HAPPY = 3; fire("UNIT_HAPPINESS", "pet")

-- 2 Supplies -------------------------------------------------------------------------------
local Sup = Core.Module("supplies")
local stock = Sup.Stock(Core.Bags(), 150, diets)
check(stock.ammo == 150 and stock.petfood == 10 and stock.drink == 8 and stock.food == 16, "stock counts")
local short = Sup.Short(stock, { ammo = 600, petfood = 10, food = 5, drink = 10 }, { hasPet = true, own = true, drink = true })
check(#short == 2 and short[1]:find("ammo") and short[2]:find("water"), "short list")
INV.count = 120
clearAlert()
RESTING = true; fire("PLAYER_UPDATE_RESTING")
RESTING = false; fire("PLAYER_UPDATE_RESTING")
check(lastAlert():find("Leaving town low", 1, true) and lastAlert():find("mmo", 1, true), "big warning when leaving town short: " .. lastAlert())

-- 3 Vendor -------------------------------------------------------------------------------------
local Ven = Core.Module("vendor")
check(#Ven.JunkList(Core.ScanBags()) == 2, "two junk stacks")
REPAIR = { 31250, true }; USED = {}; CHAT = {}; clearAlert()
fire("MERCHANT_SHOW"); RunTimers()
check(#USED == 2 and USED[1] == "0:2", "sold the greys")
check(REPAIRED == "own", "repaired from own gold, not guild")
check(lastAlert():find("Sold 2 junk for 2s 45c", 1, true) and lastAlert():find("Repaired for 3g 12s 50c", 1, true), "on-screen summary: " .. lastAlert())
check(#CHAT == 0, "no chat spam for the vendor summary")
fire("MERCHANT_CLOSED")
SHIFT = true; USED = {}; fire("MERCHANT_SHOW"); SHIFT = false
check(#USED == 0, "Shift skips once")
fire("MERCHANT_CLOSED")

-- 4 Range / Wing Clip ------------------------------------------------------------------------------
local R = Core.Module("range")
check(R.Classify(true, false, nil, nil) == "melee", "classify melee")
check(R.Classify(false, true, nil, nil) == "ok", "classify ranged")
check(R.Classify(false, false, nil, 0.5) == "deadzone", "classify dead zone from recent melee")
check(R.Classify(false, false, true, nil) == "deadzone", "classify dead zone from interact distance")
check(R.Classify(false, false, false, 10) == "far", "classify too far")
check(R.Classify(nil, nil, nil, nil) == nil, "secret readings: no guess")
UNITS.target = true; COMBAT = true
RANGE = { ["Raptor Strike"] = true, ["Wing Clip"] = true, ["Auto Shot"] = false }
tickFor(0.2)
check(R.frame and R.frame._shown and R.frame.head._text == "Wing Clip, then step back", "melee: Wing Clip prompt")
check(caps.BUTTON4.nockClipGlow and caps.BUTTON4.nockClipGlow._shown, "Wing Clip key glows")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2974)
tickFor(0.2)
check(R.frame.head._text == "Step back" and R.frame.sub._text:find("Wing Clip 10s", 1, true), "clipped: step back with timer")
check(not caps.BUTTON4.nockClipGlow._shown, "glow off once clipped")
clearAlert()
tickFor(10.2)
check(lastAlert():find("Wing Clip fell off", 1, true), "fall-off alert while still in melee")
RANGE = { ["Raptor Strike"] = false, ["Wing Clip"] = false, ["Auto Shot"] = false }
tickFor(0.2)
check(R.frame.head._text == "Dead zone", "dead zone readout")
RANGE = { ["Raptor Strike"] = false, ["Wing Clip"] = false, ["Auto Shot"] = true }
tickFor(0.2)
check(not R.frame._shown, "hidden at shooting range")
UNITS.target = false; COMBAT = false
tickFor(0.2)

-- 5 Taming ---------------------------------------------------------------------------------------------
local Tm = Core.Module("tame")
check(Tm.InBand("23", 24, false) and Tm.InBand("27", 24, false) and not Tm.InBand("40", 24, false) and Tm.InBand("40", 24, true), "level band")
local miss = Tm.Missing("Cat", { Bite = 2, Claw = 3 }, 30)
local byName = {}
for _, m in ipairs(miss) do byName[m.name] = m end
check(byName.Bite and byName.Bite.nextRank == 3 and byName.Bite.ready, "Bite 3 ready for a level 30 cat")
check(byName.Prowl and byName.Prowl.nextRank == 1, "Prowl missing")
check(#Tm.NearRares(24, false) > 0, "rares near level 24")
local counts, total = Nock.Pins.Counts()
check((counts["tame:AH"] or 0) >= 60, "rare beasts added as pins (" .. tostring(counts["tame:AH"]) .. ")")
check(Nock.Pins.KINDS[#Nock.Pins.KINDS].id == "tame", "tame pin kind registered")
-- 3.7.1 rare spawn facts
check(Tm.RespawnText({ 3600, 7200 }) == "1-2 h", "respawn 1-2 h: " .. tostring(Tm.RespawnText({ 3600, 7200 })))
check(Tm.RespawnText({ 5400, 9000 }) == "1.5-2.5 h", "respawn 1.5-2.5 h")
check(Tm.RespawnText({ 1800, 5400 }) == "30 min - 1.5 h", "respawn 30 min - 1.5 h: " .. tostring(Tm.RespawnText({ 1800, 5400 })))
local lupos = Tm.Spawn("Lupos")
check(lupos and lupos.rank == 4 and lupos.spots == 16 and lupos.pct == 6 and lupos.one, "Lupos: rare, 16 spots, one up, 6% each")
local ll = table.concat(Tm.SpawnLines(lupos), "|")
check(ll:find("Rare spawn", 1, true) and ll:find("Respawn: 4-6 h", 1, true) and ll:find("about 6%% at each") and ll:find("Chance it is up now: unknown", 1, true), "Lupos tooltip lines: " .. ll)
local takk = table.concat(Tm.SpawnLines(Tm.Spawn("Takk the Leaper")), "|")
check(takk:find("Rare elite spawn", 1, true) and takk:find("Patrols", 1, true) and not takk:find("%%"), "Takk: rare elite, patrol, no % (one spot)")
local mist = table.concat(Tm.SpawnLines(Tm.Spawn("Mist Howler")), "|")
check(mist:find("Spawn spots: 2", 1, true) and not mist:find("%%") and not mist:find("one up", 1, true), "Mist Howler: 2 unpooled spots, no %")
check(table.concat(Tm.SpawnLines({ rank = 0 }), "|"):find("Common spawn", 1, true), "non-rare says Common spawn")
local npct = 0
for _, sp in pairs(Nock.Data.TameSpawns) do
  if sp.pct then
    npct = npct + 1
    check(sp.one and sp.spots > 1 and sp.pct == math.floor(100 / sp.spots + 0.5), "pct is 100/spots only for one-up pools")
  end
end
check(npct == 16, "16 rares with a per-spot share, got " .. npct)
local mx, my = Tm.Medoid({ 10, 10, 50, 50, 52, 52, 90, 90 })
check(mx == 50 and my == 50, "medoid pin spot")
local kdef = Nock.Pins.KINDS[#Nock.Pins.KINDS]
local ovd = kdef.overlay({ name = "Lupos" }, 1431)
check(ovd and #ovd.pts == 32, "overlay: 16 Lupos spots on Duskwood")
check(kdef.overlay({ name = "Lupos" }, 1429) == nil, "overlay: nothing on another map")
local ovt = kdef.overlay({ name = "Takk the Leaper" }, 1413)
check(ovt and #ovt.paths == 1 and #ovt.paths[1] >= 4, "overlay: Takk patrol path")

-- 6 Aspects -----------------------------------------------------------------------------------------------
local As = Core.Module("aspects")
check(As.CombatAspect(function(n) return n == "Aspect of the Monkey" end) == "Aspect of the Monkey", "Monkey before Hawk")
check(As.CombatAspect(function(n) return true end) == "Aspect of the Hawk", "Hawk once known")
check(not As.CombatOK("Aspect of the Cheetah", "Aspect of the Hawk") and As.CombatOK("Aspect of the Hawk", "Aspect of the Hawk"), "combat aspect check")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 5118)
check(As.Current() == "Aspect of the Cheetah", "tracks aspect from casts")
clearAlert(); COMBAT = true
fire("PLAYER_REGEN_DISABLED"); NOW = NOW + 1; RunTimers()
check(lastAlert():find("Cheetah is on in combat", 1, true), "Cheetah in combat warning")
COMBAT = false
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 13165)

-- 7 Feign -----------------------------------------------------------------------------------------------------
local Fd = Core.Module("feign")
check(Fd.Resisted(false, false) == true and Fd.Resisted(true, false) == false and Fd.Resisted(nil, false) == nil, "resist logic")
clearAlert(); FEIGN = false
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 5384); NOW = NOW + 0.5; RunTimers()
check(lastAlert():find("Feign Death resisted", 1, true) == 1, "resisted alert")
clearAlert(); FEIGN = true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 5384); NOW = NOW + 0.5; RunTimers()
check(lastAlert() == "", "no alert when feign worked")

-- 8 Route ---------------------------------------------------------------------------------------------------------
local Gd = Core.Module("route")
local band = Gd.Band("Horde", 37)
check(band and band[3]:find("Riverglades", 1, true), "Horde 37: Riverglades")
check(Gd.Band("Alliance", 5)[3]:find("Elwynn", 1, true), "Alliance 5: Elwynn")
check(Gd.Band("Alliance", 60)[1] == 55, "level 60 uses the last band")
local ms = Gd.Milestones(30, "marks", 0, 0)
local sv = false
for _, r in ipairs(ms) do if r[3] == "survival" then sv = true end end
check(#ms >= 1 and not sv, "spec-filtered milestones")
check(has(Gd:Report(), "Wing Clip") or has(Gd.Milestones(12, "bm", 0, 0)[1], ""), "route report")
local wc = false
for _, r in ipairs(Nock.Data.Milestones) do if r[2]:find("Wing Clip, then step back", 1, true) then wc = true end end
check(wc, "guide teaches Wing Clip, then step back")

-- 9 Trainer -------------------------------------------------------------------------------------------------------
local Tr = Core.Module("train")
local rows = { { 4, "Serpent Sting", 1 }, { 10, "Serpent Sting", 2 }, { 18, "Serpent Sting", 3 }, { 26, "Serpent Sting", 4 },
  { 20, "Aspect of the Cheetah", 0 }, { 20, "Counterattack", 1, true }, { 30, "Counterattack", 2, true } }
local rk = { ["Serpent Sting"] = 2 }
local m1 = Tr.Missing(rows, 26, function(n) return rk[n] or 0 end, true, false)
check(#m1 == 2 and m1[1][2] == "Aspect of the Cheetah" and m1[2][2] == "Serpent Sting" and m1[2][3] == 4, "missing ranks, highest only, talents skipped")
local m2 = Tr.Missing(rows, 25, function(n) return rk[n] or 0 end, false, false)
check(#m2 == 1 and m2[1][2] == "Aspect of the Cheetah", "no rank info: no rank nagging")
rk.Counterattack = 1
local m3 = Tr.Missing(rows, 30, function(n) return rk[n] or 0 end, true, false)
local ca = false
for _, r in ipairs(m3) do if r[2] == "Counterattack" and r[3] == 2 then ca = true end end
check(ca, "talent rank listed once you have the talent")
check(#Tr.PetNew(20) > 0, "pet trainer ranks at 20")
clearAlert(); CHAT = {}
LEVEL = 26; fire("PLAYER_LEVEL_UP", 26); NOW = NOW + 3; RunTimers()
check(lastAlert():find("New at your trainer", 1, true), "level-up trainer alert")
check(#CHAT == 0, "no chat spam for the trainer alert")

-- 10 Tracker ------------------------------------------------------------------------------------------------------------
local Tk = Core.Module("tracker")
local before = Tk.Line()
check(before:find("about ", 1, true) == 1 and not before:find("?", 1, true) and before:find("kills to 27", 1, true), "before the first kill: estimate, no '?': " .. before)
check(Tk.EstimateKillXP(28, 0) == 185 and Tk.EstimateKillXP(28, 500) == 370, "same-level mob XP estimate")
local k, ph, tl = Tk.Leveling(1000, 10000, 300, 9000, 1800)
check(k == 30 and math.floor(ph) == 18000 and math.floor(tl) == 1800, "kills / XP per hour / time to level")
fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold dies, you gain 300 experience. (+150 exp Rested bonus)")
check(Tk.Average(Tk.session.recent) == 300, "kill XP parsed")
fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "You have slain Kobold!")
check(Tk.Kills() == 1, "kill counted once")
XP = 1300; fire("PLAYER_XP_UPDATE")
check(Tk.session.xp == 300, "XP delta")
check(Tk.Line():find("kills to 27", 1, true), "leveling line: " .. Tk.Line())

-- Endgame -----------------------------------------------------------------------------------------------------------------
LEVEL = 60; fire("PLAYER_LEVEL_UP", 60); NOW = NOW + 3; RunTimers()
check(P.isMax and Core.IsEndgame(), "endgame at 60")
check(Tk.Line():find("/h", 1, true) and Tk.Line():find("Session", 1, true), "tracker switches to gold per hour")
check(has(Gd:Report(), "Checklist"), "guide switches to the checklist")
check(Sup.Short({ ammo = 1500, petfood = 40, food = 30, drink = 30 }, ({ ammo = 2000, petfood = 30, food = 20, drink = 20 }), { hasPet = true, own = true, drink = true })[1]:find("ammo"), "raid-night ammo target")
SlashCmdList.NOCK("tools endgame off")
check(not Core.IsEndgame(), "endgame mode can be switched off")
SlashCmdList.NOCK("tools endgame auto")

-- PvP ---------------------------------------------------------------------------------------------------------------------
local Pv = Core.Module("pvp")
check(not Core.PvPMode(), "not PvP in the open world")
INSTANCE = { true, "pvp" }; fire("ZONE_CHANGED_NEW_AREA")
check(P.context == "pvp" and Core.PvPMode(), "battleground = PvP mode")
check(not Core.Enabled("tracker") and not Core.Enabled("train") and Core.Enabled("range") and Core.Enabled("feign"), "PvE nags quiet, combat cues stay")
INSTANCE = { true, "arena" }; fire("ZONE_CHANGED_NEW_AREA")
check(Core.PvPMode() and P.arena, "arena = PvP mode")
local role, sting = Pv.Advice("MAGE", function(n) return n == "Serpent Sting" end)
check(role == "caster" and sting == "Serpent Sting", "Viper not known: falls back to Serpent")
role, sting = Pv.Advice("WARRIOR", function() return true end)
check(role == "melee" and sting == "Scorpid Sting", "Scorpid vs warrior")
check(Pv.FirstSlow(function(n) return n == "Hamstring" and 5 or 0 end) == "Hamstring", "slow found")
check(Pv.FirstSlow(function() return 0 end) == false, "not slowed")
check(Pv.FirstSlow(function() return nil end) == nil, "auras hidden: no guess")
UNITS.target = true; UnitIsPlayer = function() return true end
UnitClass = function() return "Rogue", "ROGUE" end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
C_UnitAuras = { GetAuraDataBySpellName = function(_, name) if name == "Evasion" then return { expirationTime = NOW + 8 } end end }
NOW = NOW + 0.3; Core._Tick(nil, 0.3)
check(Pv.frame and Pv.frame._shown and Pv.frame.lines[1]._text:find("Rogue", 1, true), "PvP readout for enemy player")
check(Pv.frame.lines[3]._text:find("Evasion", 1, true), "big enemy buff called out")
check(Pv.frame.lines[2]._text:find("Not slowed", 1, true), "not slowed cue")
clearAlert(); SPELLNAME[42292] = "PvP Trinket"
fire("UNIT_SPELLCAST_SUCCEEDED", "target", "c", 42292)
check(lastAlert():find("Trinket", 1, true), "trinket alert")
check(has(Gd:Report(), "Trap juggling"), "route shows PvP notes in PvP")
SlashCmdList.NOCK("tools pvp off")
check(not Core.PvPMode() and Core.Enabled("tracker"), "PvP mode can be switched off")
SlashCmdList.NOCK("tools pvp on")
UNITS.target = false; INSTANCE = { false, "none" }; fire("ZONE_CHANGED_NEW_AREA")
NOW = NOW + 0.3; Core._Tick(nil, 0.3)
check(not Pv.frame._shown, "readout hides outside PvP")
GetBattlefieldStatus = function() return "confirm" end
INV.count = 50; clearAlert()
fire("UPDATE_BATTLEFIELD_STATUS")
check(lastAlert():find("Queue popped", 1, true), "low ammo when the queue pops")

-- Tools tab (Field Kit) -----------------------------------------------------------------------------------------------
local RP = {}
Nock.UI = { lib = { RefreshPage = RP, CONTENT_W = 848,
  MakeScroll = function(parent) local sc, ch = Obj("Scroll"), Obj("Frame"); return sc, ch end,
  WindowMetrics = function() return { body = 16, header = 20, content = 848 } end } }
assert(loadfile(NOCK_DIR .. "UI_Kit.lua"))("Nock")
local page = Nock.UI.extraPages.kit(Obj("Page"))
RP.kit(page)
check(#page.sections == 11, "Tools tab: a section per tool (" .. #page.sections .. ")")
check(page.sections[1].head._text:find("Pet happiness", 1, true) and page.sections[1].body._text ~= "", "Tools tab section text")
SlashCmdList.NOCK("tracker off"); RP.kit(page)
local off = false
for _, s in ipairs(page.sections) do if s.head._text:find("(off)", 1, true) then off = true end end
check(off, "Tools tab shows switched-off tools")
SlashCmdList.NOCK("tracker on")

-- 3.4.1 frames: movable, default spots, unlock / lock / reset -------------------------------------------------------------
Nock.Threat = { SetLocked = function(on) THREAT_LOCKED = on; return true end, ResetPos = function() THREAT_RESET = true end }
local trk = _G.NockTrackerFrame
check(trk and Core.movers.tracker, "tracker is a registered movable frame")
local p1 = trk._points
check(p1[1] == "TOP" and p1[3] == "TOP" and p1[5] == -34, "tracker defaults to top centre, away from the bow bar")
check(trk._w >= 260, "tracker frame wide enough for its text (" .. tostring(trk._w) .. ")")
check(not Tk.Line():find("?", 1, true), "no '?' in the tracker line: " .. Tk.Line())
check(Core.movers.range and Core.movers.pvp and Core.movers.alert, "range, PvP and alert frames are movable")
check(_G.NockRangeFrame._mouse ~= true, "range readout does not take the mouse while locked")
SlashCmdList.NOCK("unlock")
check(Core.Unlocked() and NockCharDB.quiverLocked == false and THREAT_LOCKED == false, "/nock unlock: all frames incl. quiver and threat")
check(trk.nockMoverHL and trk.nockMoverHL.text._shown, "unlocked frames show their outline and name")
check(_G.NockRangeFrame._shown and _G.NockRangeFrame._mouse == true, "range readout shows a sample and takes the mouse while unlocked")
NOW = NOW + 1; Core._Tick(nil, 1)
check(_G.NockRangeFrame._shown, "readout stays up while unlocked")
-- drag
trk._points = { "TOP", UIParent, "TOP", 120, -80 }
trk._scripts.OnDragStart(trk); trk._scripts.OnDragStop(trk)
check(NockCharDB.positions.tracker and NockCharDB.positions.tracker[3] == 120, "drag saves the position")
SlashCmdList.NOCK("lock")
check(not Core.Unlocked() and NockCharDB.quiverLocked == nil and THREAT_LOCKED == true, "/nock lock")
check(not trk.nockMoverHL.text._shown and not _G.NockRangeFrame._shown, "outlines and samples hidden after lock")
SlashCmdList.NOCK("tracker unlock")
check(Core.Get("tracker", "unlocked") == true and trk.nockMoverHL.text._shown, "/nock tracker unlock")
SlashCmdList.NOCK("tracker reset")
check(trk._points[1] == "TOP" and trk._points[4] == 0 and NockCharDB.positions.tracker == nil and not trk.nockMoverHL.text._shown, "/nock tracker reset")
NockCharDB.positions.range = { "CENTER", "CENTER", 5, 5 }
SlashCmdList.NOCK("reset positions")
check(next(NockCharDB.positions) == nil and THREAT_RESET, "/nock reset positions")
SlashCmdList.NOCK("unlock"); COMBAT = true; fire("PLAYER_REGEN_DISABLED"); COMBAT = false
check(not Core.Unlocked(), "combat locks frames again")

-- Mute ---------------------------------------------------------------------------------------------------------------------
SlashCmdList.NOCK("tools mute")
clearAlert(); Fd.Fire()
check(lastAlert() == "", "muted: no alerts")
SlashCmdList.NOCK("tools mute")

for id, e in pairs(Core.errors or {}) do print("  error " .. id .. ": " .. e); fails = fails + 1 end
if fails > 0 then
  error(fails .. " hunter tool checks failed")
end
print("TOOLS_TEST_OK")
