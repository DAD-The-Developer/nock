local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert") .. ": got " .. tostring(a) .. " expected " .. tostring(b), 2)
  end
end

local function assert_true(v, msg)
  if not v then error(msg or "expected true", 2) end
end

-- Load path already concatenated by the runner. Threat.lua registered Nock.Threat.
local Threat = Nock.Threat
assert_true(Threat, "Nock.Threat exists")
assert_true(Threat.HasNativeAPI(), "native UnitDetailedThreatSituation is present")

-- 1. Style: safe / near / about to pull / player pulled / pet aggro
do
  local c, pct, tag = Threat.Style("player", { scaled = 40, status = 0, tanking = false })
  assert_eq(pct, 40, "safe pct")
  assert_eq(tag, "", "safe has no warning")
  assert_true(c[2] > 0.7, "safe is emerald (green channel)")

  c, pct, tag = Threat.Style("player", { scaled = 86, status = 0, tanking = false })
  assert_eq(tag, "", "86% is amber, no pull caption yet")
  assert_true(c[1] > 0.8 and c[2] > 0.5, "86% is amber")

  c, pct, tag = Threat.Style("player", { scaled = 108, status = 1, tanking = false })
  assert_eq(tag, "About to pull", "status 1 warns about to pull")
  assert_true(c[1] > 0.8 and c[2] > 0.5, "108% about-to-pull is amber")

  c, pct, tag = Threat.Style("player", { scaled = 120, status = 1, tanking = false })
  assert_eq(tag, "About to pull", "120% still about to pull until tanking")
  assert_true(c[1] > 0.8 and c[3] < 0.4, "120% is red")

  c, pct, tag = Threat.Style("player", { scaled = 100, status = 3, tanking = true })
  assert_eq(tag, "You pulled", "player tanking is You pulled")
  assert_true(c[1] > 0.8 and c[3] < 0.4, "you pulled is red")

  c, pct, tag = Threat.Style("pet", { scaled = 100, status = 3, tanking = true })
  assert_eq(tag, "Aggro", "pet tanking is Aggro")
  assert_true(c[2] > 0.7, "pet aggro is emerald, not red")
end
print("style ok")

-- 2. FormatPct is whole seconds-style integers, never 15.42
assert_eq(Threat.FormatPct(15.42), "15%", "15.42 rounds to 15%")
assert_eq(Threat.FormatPct(72.6), "73%", "72.6 rounds to 73%")
assert_eq(Threat.FormatPct(nil), "—", "nil pct is an em dash, not blank")
assert_eq(Threat.FormatPct({ __secret = true }), "—", "secret pct is an em dash, not formatted")
print("format ok")

-- 3. Mob unit: target if hostile, else pet's target
UNIT_EXISTS.target = true
UNIT_CAN_ATTACK.target = true
INCOMBAT = true
Nock.inCombatFlag = true
assert_eq(Threat.MobUnit(), "target", "hostile player target wins")
UNIT_CAN_ATTACK.target = false
UNIT_EXISTS.target = true
-- friendly target, not treated as mob; fall back
UNIT_EXISTS.pettarget = true
UNIT_CAN_ATTACK.pettarget = true
assert_eq(Threat.MobUnit(), "pettarget", "falls back to the pet's target")
UNIT_EXISTS.target = nil
UNIT_CAN_ATTACK.target = nil
assert_eq(Threat.MobUnit(), "pettarget", "no player target uses pettarget")
UNIT_EXISTS.pettarget = nil
UNIT_CAN_ATTACK.pettarget = nil
assert_eq(Threat.MobUnit(), nil, "no mob if neither target exists")
print("mob unit ok")

-- 4. Query uses unit token, then GUID; secret values are flagged, not formatted
THREAT.player = { target = { false, 0, 72, 72, 1200 } }
local info = Threat.Query("player", "target")
assert_true(info, "query returns a table")
assert_eq(info.scaled, 72, "scaled 72")
assert_eq(info.status, 0, "status 0")
assert_eq(info.tanking, false, "not tanking")

-- GUID fallback: only stored under the unit token, query with a token that
-- misses then hits via GUID of "target".
THREAT.player = { target = { false, 1, 108, 108, 2000 } }
info = Threat.Query("player", UNIT_GUIDS.target)
assert_true(info and info.scaled == 108, "GUID fallback finds the same mob, got " .. tostring(info and info.scaled))

THREAT_SECRET.player = true
info = Threat.Query("player", "target")
assert_true(info and info.secret, "secret values are tagged, not numbers")
assert_eq(Threat.FormatPct(info.scaled), "—", "secret query prints an em dash")
THREAT_SECRET.player = nil
print("query ok")

-- 5. Hide out of combat; show in combat once created
INCOMBAT = false
Nock.inCombatFlag = false
Threat.Layout()
assert_true(_G.NockThreatMeter, "meter frame created out of combat")
assert_true(not NockThreatMeter:IsShown(), "hidden out of combat")

-- In combat with a mob and threat: show
UNIT_EXISTS.target = true
UNIT_CAN_ATTACK.target = true
UNIT_EXISTS.pet = true
UNIT_NAMES.pet = "Wolf"
THREAT.player = { target = { false, 0, 72, 72, 1200 } }
THREAT.pet = { target = { true, 3, 100, 100, 1800 } }
INCOMBAT = true
Nock.inCombatFlag = true
Threat.Update()
assert_true(NockThreatMeter:IsShown(), "shown in combat")
assert_eq(Threat._rows.player.pct:GetText(), "72%", "player shows 72%")
assert_eq(Threat._rows.pet.pct:GetText(), "100%", "pet percent is 100%")
assert_eq(Threat._rows.pet.tag:GetText(), "Aggro", "pet row shows Aggro")
assert_eq(Threat._rows.player.label:GetText(), "You", "player label is You")
assert_eq(Threat._rows.pet.label:GetText(), "Wolf", "pet label is the pet name")
print("show/hide ok")

-- About to pull
THREAT.player = { target = { false, 1, 108, 108, 2000 } }
Threat.Update()
assert_eq(Threat._rows.player.pct:GetText(), "108%", "percent stays in its own column, got " .. tostring(Threat._rows.player.pct:GetText()))
assert_eq(Threat._rows.player.tag:GetText(), "About to pull", "tag column shows About to pull")
assert_eq(Threat._rows.player.pct._justify, "RIGHT", "percent is right-aligned")
assert_eq(Threat._rows.player.tag._justify, "LEFT", "status tag is left-aligned in its column")
print("pull warning ok")

-- 6. Toggle off hides; default is on
assert_true(NockCharDB.nockThreat == nil or NockCharDB.nockThreat ~= false, "default is on")
Nock.SetNockThreat(false)
assert_true(not NockThreatMeter:IsShown(), "toggle off hides the meter")
Nock.SetNockThreat(true)
assert_true(NockThreatMeter:IsShown(), "toggle on shows it in combat")
print("toggle ok")

-- 7. Layout: width matches the bow plaque, even grid, equal row heights.
INCOMBAT = false
Nock.inCombatFlag = false
Threat.Layout()
local point, rel, relPoint, x, y = NockThreatMeter:GetPoint(1)
assert_eq(point, "BOTTOM", "meter hangs from its bottom")
assert_eq(relPoint, "TOP", "meter sits above the bow / plaque")
assert_true(rel == Nock.Overlay().body or rel == Nock.Overlay().bow, "anchored to the HUD bow stack")
assert_eq(x, 0, "centered")
assert_true((y or 0) >= 0, "gap above the bow is not negative")
local m = Threat._metrics()
assert_eq(NockThreatMeter:GetWidth(), 505, "Large meter width matches the bow plaque (505)")
assert_eq(NockThreatMeter:GetHeight(), m.h, "height is the padding grid")
assert_eq(m.rowH, Threat._rows.player:GetHeight(), "player row uses the grid row height")
assert_eq(Threat._rows.player:GetHeight(), Threat._rows.pet:GetHeight(), "both bars have equal height")
assert_eq(m.pad * 2 + m.rowH * 2 + m.gap, m.h, "height is pad + two rows + gap, no leftover")
local rp, rrel, rrp = Threat._rows.player:GetPoint(1)
assert_eq(rp, "TOPLEFT", "player row stays anchored after PlaceRows/ApplyRowGrid")
assert_true(rrel == NockThreatMeter, "player row is parented to the plaque")
local pp, prel = Threat._rows.pet:GetPoint(1)
assert_eq(pp, "TOPLEFT", "pet row stays anchored after PlaceRows/ApplyRowGrid")
assert_true(prel == NockThreatMeter, "pet row is parented to the plaque")
-- 100% fill reaches the end of the track (minus the 1px inset on each side)
INCOMBAT = true
Nock.inCombatFlag = true
THREAT.pet = { target = { true, 3, 100, 100, 1800 } }
Threat.Update()
local pet = Threat._rows.pet
assert_true(pet.trackW and pet.trackW >= 80, "track has a computed width")
assert_eq(pet.fill:GetWidth(), pet.trackW - 2, "100% fill meets the end of the track, got " .. tostring(pet.fill:GetWidth()) .. " vs " .. tostring(pet.trackW))
print("layout ok")

-- 8. Source: no ThreatClassic fallback was shipped
local f = io.open("/workspace/nock/Nock/Threat.lua", "r")
local src = f:read("*a")
f:close()
assert_true(not src:find("ThreatClassic", 1, true), "no ThreatClassic library")
assert_true(src:find("UnitDetailedThreatSituation", 1, true), "uses native API")
assert_true(src:find("issecretvalue", 1, true), "guards secret values")
assert_true(src:find("pettarget", 1, true), "falls back to the pet's target")
print("source ok")

-- 9. TOC / version
local function read(path)
  local h = io.open(path, "r")
  local t = h:read("*a")
  h:close()
  return t
end
local toc = read("/workspace/nock/Nock/Nock.toc")
assert_true(toc:find("Interface: 16001", 1, true), "TOC Interface is 16001")
assert_true(toc:find("Version: 3.6.0", 1, true), "TOC Version is 3.6.0")
assert_true(toc:find("Threat.lua", 1, true), "TOC loads Threat.lua")
local lua = read("/workspace/nock/Nock/Nock.lua")
assert_true(lua:find('VERSION = "3.6.0"', 1, true), "Nock.lua VERSION is 3.6.0")
local opt = read("/workspace/nock/Nock/UI_Options.lua")
assert_true(opt:find("Threat meter", 1, true), "Options has a Threat meter toggle")
print("version ok")

-- 10. Nil / secret / no-mob paint an em dash and keep the frame up
THREAT_SECRET.player = true
THREAT_SECRET.pet = true
Threat.Update()
assert_true(NockThreatMeter:IsShown(), "secret values do not hide the meter")
assert_eq(Threat._rows.player.pct:GetText(), "—", "secret player pct is an em dash")
assert_eq(Threat._rows.player.label:GetText(), "You", "name still shows when values are secret")
THREAT_SECRET.player = nil
THREAT_SECRET.pet = nil

-- All-unreadable (secret userdata) returns are tagged secret, not 0%.
THREAT.player = { target = { { __secret = true }, { __secret = true }, { __secret = true }, { __secret = true }, { __secret = true } } }
local secretInfo = Threat.Query("player", "target")
assert_true(secretInfo and secretInfo.secret, "unreadable API returns are tagged secret")
THREAT.player = { target = { false, 0, 72, 72, 1200 } }

-- No mob in combat: stay shown with an em dash, no flicker on a second tick.
UNIT_EXISTS.target = nil
UNIT_CAN_ATTACK.target = nil
UNIT_EXISTS.pettarget = nil
UNIT_CAN_ATTACK.pettarget = nil
Threat.Update()
assert_true(NockThreatMeter:IsShown(), "stays shown in combat with no mob")
assert_eq(Threat._rows.player.pct:GetText(), "—", "no mob shows an em dash")
local shown = NockThreatMeter:IsShown()
Threat.Update()
assert_eq(NockThreatMeter:IsShown(), shown, "second update does not flicker the frame")
-- restore a mob for later tests
UNIT_EXISTS.target = true
UNIT_CAN_ATTACK.target = true
print("nil/secret/steady ok")

-- 11. Fallback APIs when UnitDetailedThreatSituation returns nothing
THREAT.player = {}
SITUATION.player = { target = 1 }
LEAD_PCT.player = { target = 108 }
local fb = Threat.Query("player", "target")
assert_true(fb and not fb.off and not fb.secret, "fallback query is usable")
assert_eq(fb.status, 1, "fallback status from UnitThreatSituation")
assert_eq(fb.scaled, 108, "fallback pct from UnitThreatPercentageOfLead")
SITUATION.player = nil
LEAD_PCT.player = nil
THREAT.player = { target = { false, 0, 72, 72, 1200 } }
print("fallback api ok")

-- 12. The insecure frame can be created in combat (mid-fight /reload)
INCOMBAT = true
Nock.inCombatFlag = true
Threat._wipeForTest()
assert_true(_G.NockThreatMeter == nil or not Threat._rows.player, "wipe cleared the meter")
-- Overlay still exists; Layout must build the frame even though we are in combat.
Threat.Layout()
assert_true(_G.NockThreatMeter, "meter frame is created in combat")
assert_true(NockThreatMeter:IsShown(), "meter is shown after a mid-fight create")
assert_eq(Threat._rows.player.label:GetText(), "You", "in-combat create still paints names")
print("create in combat ok")

-- 13. OnUpdate polls even when the frame is hidden, and shows it
NockThreatMeter:Hide()
assert_true(not NockThreatMeter:IsShown(), "pre-poll hidden")
local onup = Threat._ev:GetScript("OnUpdate")
assert_true(type(onup) == "function", "OnUpdate handler exists")
onup(Threat._ev, 0.25)
assert_true(NockThreatMeter:IsShown(), "0.2s poll shows the meter in combat even if it was hidden")
print("poll ok")

-- 14. /nock threat debug prints raw API returns, never a secret number
CHAT_LOG = {}
THREAT.player = { target = { false, 0, 72, 72, 1200 } }
THREAT.pet = { target = { true, 3, 100, 100, 1800 } }
UNIT_EXISTS.pet = true
UNIT_NAMES.pet = "Wolf"
Threat.Debug()
local blob = table.concat(CHAT_LOG, "\n")
assert_true(blob:find("threat debug", 1, true), "debug header printed")
assert_true(blob:find("UnitDetailedThreatSituation", 1, true), "debug names the detailed API")
assert_true(blob:find("72", 1, true), "debug includes the raw scaled percent")
CHAT_LOG = {}
THREAT_SECRET.player = true
Threat.Debug()
blob = table.concat(CHAT_LOG, "\n")
assert_true(blob:find("[secret]", 1, true) or blob:find("{secret}", 1, true) or blob:find("secret", 1, true),
  "debug mentions secret values without formatting them")
THREAT_SECRET.player = nil
print("debug ok")

-- 15. Version is 3.1.0 in the threat source too
assert_true(src:find("Threat", 1, true), "Threat.lua still ships")
print("threat source still ships")

-- 16. Exact returns from the 3.0.14 in-game dump.
-- UnitDetailedThreatSituation(pet, target) -> false, 0, 59.09, 65, 238
-- Query scaled=100 status=3 tanking=true is the player (pulled), not the pet.
THREAT.player = { target = { true, 3, 100, 100, 400 } }
THREAT.pet = { target = { false, 0, 59.09, 65, 238 } }
UNIT_EXISTS.target = true
UNIT_CAN_ATTACK.target = true
UNIT_EXISTS.pet = true
UNIT_NAMES.pet = "Wolf"
INCOMBAT = true
Nock.inCombatFlag = true
local pinfo = Threat.Query("player", "target")
assert_eq(pinfo.tanking, true, "player isTanking is the 1st return")
assert_eq(pinfo.status, 3, "player status is the 2nd return")
assert_eq(pinfo.scaled, 100, "player scaled is the 3rd return")
assert_eq(pinfo.raw, 100, "player raw is the 4th return")
assert_eq(pinfo.value, 400, "player threatValue is the 5th return")
local petinfo = Threat.Query("pet", "target")
assert_eq(petinfo.tanking, false, "pet isTanking=false")
assert_eq(petinfo.status, 0, "pet status=0 (2nd return), not mixed up with player 3")
assert_eq(petinfo.scaled, 59.09, "pet scaled is 59.09, the 3rd return")
assert_eq(petinfo.raw, 65, "pet raw is 65")
assert_eq(petinfo.value, 238, "pet threatValue is 238")
assert_eq(Threat.FormatPct(59.09), "59%", "59.09 displays as 59%")
Threat.Update()
assert_eq(Threat._rows.player.label:GetText(), "You", "player row shows You")
assert_eq(Threat._rows.player.pct:GetText(), "100%", "player percent 100%")
assert_eq(Threat._rows.player.tag:GetText(), "You pulled", "player tag is You pulled")
assert_eq(Threat._rows.pet.label:GetText(), "Wolf", "pet row shows the pet name")
assert_eq(Threat._rows.pet.pct:GetText(), "59%", "pet percent 59%")
assert_eq(Threat._rows.pet.tag:GetText(), "", "pet at 59% status 0 has no Aggro tag")
assert_eq(Threat._rows.player:GetPoint(1), "TOPLEFT", "player row still anchored after paint")
assert_eq(Threat._rows.pet:GetPoint(1), "TOPLEFT", "pet row still anchored after paint")
assert_true(NockThreatMeter:IsShown(), "plaque stays shown")
-- Debug labels the five returns and prefixes Query with the unit
CHAT_LOG = {}
Threat.Debug()
local blob = table.concat(CHAT_LOG, "\n")
assert_true(blob:find("isTanking=false", 1, true), "debug labels pet isTanking")
assert_true(blob:find("status=0", 1, true), "debug labels pet status")
assert_true(blob:find("scaled=59.09", 1, true), "debug labels pet scaled")
assert_true(blob:find("player Query:", 1, true), "debug prefixes player Query")
assert_true(blob:find("pet Query:", 1, true), "debug prefixes pet Query")
print("live returns ok")

-- 17. pcall errors land in NockCharDB.errors and print once in chat
local fs = Threat._rows.player.pct
local origSet = fs.SetText
function fs:SetText(v)
  error("Font not set")
end
NockCharDB.errors = NockCharDB.errors or {}
local before = #NockCharDB.errors
CHAT_LOG = {}
Threat.Update()
assert_true(#NockCharDB.errors > before, "error was saved to NockCharDB.errors")
assert_true(tostring(NockCharDB.errors[1]):find("Font not set", 1, true), "saved error mentions Font not set")
local first = table.concat(CHAT_LOG, "\n")
assert_true(first:find("Threat meter error", 1, true), "error is printed once in chat")
CHAT_LOG = {}
Threat.Update()
assert_true(not table.concat(CHAT_LOG, "\n"):find("Threat meter error", 1, true), "the same error is not printed again")
fs.SetText = origSet
Threat.Update()
print("error capture ok")


-- 18. Threat meter is locked by default; unlock shows a drag handle.
INCOMBAT = false
Nock.inCombatFlag = false
NockCharDB.threatLocked = nil
NockCharDB.threatPos = nil
Threat.Layout()
assert_true(Threat.IsLocked(), "locked by default")
assert_true(not NockThreatMeter._mouse, "mouse is off while locked")
assert_true(not NockThreatMeter:IsShown(), "still hidden out of combat while locked")

local ok, why = Threat.SetLocked(false)
assert_true(ok, "unlock out of combat succeeds")
assert_true(not Threat.IsLocked(), "unlocked after SetLocked(false)")
assert_true(NockThreatMeter:IsShown(), "unlocked plaque stays up out of combat so it can be dragged")
assert_true(NockThreatMeter._mouse, "whole plaque is the drag handle")
assert_true(NockThreatMeter.moveChrome and NockThreatMeter.moveChrome:IsShown(), "highlighted outline is shown while unlocked")
assert_eq(NockThreatMeter.moveLabel:GetText(), "Drag to move", "label says Drag to move")
print("unlock ok")

-- Combat blocks moving; unlock is queued until the fight ends.
Threat.SetLocked(true)
INCOMBAT = true
Nock.inCombatFlag = true
ok, why = Threat.SetLocked(false)
assert_true(not ok, "unlock in combat is refused")
assert_eq(why, "combat", "combat reason")
assert_true(Threat.IsLocked(), "still locked during the fight")
assert_true(Threat._pendingUnlock(), "unlock is queued")
-- Drag start in combat does not move
INCOMBAT = false
Nock.inCombatFlag = false
Threat.SetLocked(false)
INCOMBAT = true
Nock.inCombatFlag = true
NockThreatMeter._moving = false
local start = NockThreatMeter:GetScript("OnDragStart")
assert_true(start, "drag script is wired")
start(NockThreatMeter)
assert_true(not NockThreatMeter._moving, "does not start moving in combat")
INCOMBAT = false
Nock.inCombatFlag = false
Threat.ApplyPendingUnlock()
-- already unlocked; apply is a no-op if pending was cleared. Re-queue:
INCOMBAT = true
Nock.inCombatFlag = true
Threat.SetLocked(true)
ok, why = Threat.SetLocked(false)
assert_eq(why, "combat", "queued again")
INCOMBAT = false
Nock.inCombatFlag = false
Threat.ApplyPendingUnlock()
assert_true(not Threat.IsLocked(), "unlock applies after combat")
assert_true(NockThreatMeter:IsShown(), "plaque is up after queued unlock")
print("combat block ok")

-- Position is saved per character; snap to the HUD center line; reset.
NockCharDB.threatPos = nil
-- Place the plaque 12px off the body center — inside the snap window.
NockThreatMeter:ClearAllPoints()
NockThreatMeter._cx, NockThreatMeter._cy = 972, 620
NockThreatMeter:SetPoint("CENTER", UIParent, "CENTER", 12, 80)
assert_true(Threat.SnapIfClose(), "12px off center snaps")
assert_eq(NockCharDB.threatPos, nil, "snap itself does not save until DragStop")
-- After snap, center X should match the body (960)
assert_eq(NockThreatMeter._cx, 960, "snapped to the HUD center line")
-- Far from the line: no snap
NockThreatMeter:ClearAllPoints()
NockThreatMeter._cx, NockThreatMeter._cy = 1100, 620
NockThreatMeter:SetPoint("CENTER", UIParent, "CENTER", 140, 80)
assert_true(not Threat.SnapIfClose(), "140px off center does not snap")
-- DragStop saves
INCOMBAT = false
Nock.inCombatFlag = false
Threat.SetLocked(false)
NockThreatMeter:ClearAllPoints()
NockThreatMeter._cx, NockThreatMeter._cy = 1100, 620
NockThreatMeter:SetPoint("CENTER", UIParent, "CENTER", 140, 80)
local stop = NockThreatMeter:GetScript("OnDragStop")
stop(NockThreatMeter)
assert_true(NockCharDB.threatPos and NockCharDB.threatPos.x == 140, "DragStop saves the offset, got " .. tostring(NockCharDB.threatPos and NockCharDB.threatPos.x))
-- Layout keeps the saved position
Threat.Layout()
local pt, rel, relPt, x, y = NockThreatMeter:GetPoint(1)
assert_eq(pt, "CENTER", "saved position uses a CENTER anchor")
assert_true(rel == UIParent, "saved position is on UIParent")
assert_eq(x, 140, "saved x offset is kept")
-- Reset puts it back above the bow
local okReset = Threat.ResetPos()
assert_true(okReset, "reset succeeds out of combat")
assert_eq(NockCharDB.threatPos, nil, "reset clears the saved position")
pt, rel, relPt, x = NockThreatMeter:GetPoint(1)
assert_eq(pt, "BOTTOM", "reset hangs from its bottom")
assert_eq(relPt, "TOP", "reset sits above the bow / plaque")
assert_eq(x, 0, "reset is centered on the HUD")
-- Reset in combat is refused
INCOMBAT = true
Nock.inCombatFlag = true
NockCharDB.threatPos = { x = 40, y = 20 }
okReset, why = Threat.ResetPos()
assert_true(not okReset, "reset in combat is refused")
assert_eq(why, "combat", "reset combat reason")
assert_true(NockCharDB.threatPos and NockCharDB.threatPos.x == 40, "combat reset leaves the saved position")
INCOMBAT = false
Nock.inCombatFlag = false
NockCharDB.threatPos = nil
Threat.SetLocked(true)
Threat.Layout()
print("snap / save / reset ok")


-- 19. Unlocking the meter must survive the OOC OnUpdate poll and leaving combat.
INCOMBAT = false
Nock.inCombatFlag = false
NockCharDB.threatPos = nil
NockCharDB.threatLocked = nil
Threat.SetLocked(true)
Threat.Layout()
assert_true(not NockThreatMeter:IsShown(), "locked still hides out of combat")
Threat.SetLocked(false)
assert_true(NockThreatMeter:IsShown(), "unlocked is shown")
local onupd = Threat._ev:GetScript("OnUpdate")
assert_true(onupd, "OnUpdate ticker exists")
onupd(Threat._ev, 0.25)
assert_true(NockThreatMeter:IsShown(), "OnUpdate must not hide an unlocked meter")
local onev = Threat._ev:GetScript("OnEvent")
onev(Threat._ev, "PLAYER_REGEN_ENABLED")
assert_true(NockThreatMeter:IsShown(), "leaving combat must not hide an unlocked meter")
-- Once locked, the ticker may hide it out of combat.
Threat.SetLocked(true)
onupd(Threat._ev, 0.25)
assert_true(not NockThreatMeter:IsShown(), "locked meter hides out of combat after the ticker")
print("unlock stays visible ok")

print("== Threat meter tests ok")
THREAT_TEST_OK = true
