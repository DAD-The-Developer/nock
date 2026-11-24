#!/usr/bin/env python3
"""Nock 3.9.0 quest item drop chances (Lua 5.1 via lupa).

Loads the whole addon like run_dash.py, then checks the generated data
against its sources (CMaNGOS in MariaDB when available), the tooltip lines,
the Dashboard rows and the option.
"""
import re, subprocess, sys
from pathlib import Path

src = Path("/workspace/nock/tests/run_dash.py").read_text()
head = src[: src.index("\nrun(r\"\"\"\n  local results")]
exec(compile(head, "run_dash_head", "exec"))

# Data checks (Python side) -----------------------------------------------------
data = (ROOT / "Data_QuestDrops.lua").read_text()
size = len(data.encode())
assert size < 400_000, "data file too big: %d" % size
print("ok  data file %d KB" % (size // 1024))
rows = re.findall(r"^    \[(\d+)\] = \{ (\".*?\"),(.*) \},$", data.split("npcs = {")[0], re.M)
assert len(rows) > 1000, "too few items"
bad = []
for iid, name, rest in rows:
    vals = [v.strip() for v in rest.split(",")]
    for i in range(0, len(vals), 2):
        p = vals[i + 1]
        if p != "false" and not (0 < float(p) <= 100):
            bad.append((iid, vals[i], p))
assert not bad, "chances out of range: %r" % bad[:5]
print("ok  every chance is in (0, 100] or false (%d items)" % len(rows))

def mysql(q):
    try:
        out = subprocess.run(["mysql", "cm", "-N", "-B", "-e", q], capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    return out.stdout if out.returncode == 0 else None

probe = mysql("select abs(l.ChanceOrQuestChance) from creature_template c join creature_loot_template l on l.entry=c.LootId where c.Entry=69 and l.item=750")
if probe:
    ok_n = 0
    for iid, name, rest in rows[::37]:
        vals = [v.strip() for v in rest.split(",")]
        npc, p = vals[0], vals[1]
        if p == "false":
            continue
        got = mysql("select abs(l.ChanceOrQuestChance), l.groupid from creature_template c join creature_loot_template l on l.entry=c.LootId where c.Entry=%s and l.item=%s" % (npc, iid))
        if got and got.split("\t")[1].strip() == "0" and float(got.split("\t")[0]) != 0:
            assert abs(float(got.split("\t")[0]) - float(p)) < 0.06, (iid, npc, p, got)
            ok_n += 1
    print("ok  %d sampled chances match CMaNGOS creature_loot_template" % ok_n)
else:
    print("ok  (MariaDB not available: source cross-check skipped)")

run(r'''
  local function ok(cond, msg)
    if not cond then error("QD_FAIL: " .. msg, 0) end
    print("ok  " .. msg)
  end
  local QD = Nock.QuestDrops
  ok(QD ~= nil and Nock.QuestDropsData ~= nil, "module and data loaded")
  ok(QD.Enabled(), "on by default")
  ok(QD.Pct(80) == "80%" and QD.Pct(4.5) == "4.5%" and QD.Pct(4) == "4%" and QD.Pct(0.04) == "<0.1%" and QD.Pct(37.6) == "38%", "percent format")
  ok(QD.ItemID("Tough Wolf Meat") == 750, "item by name")
  ok(QD.NpcFromGUID("Creature-0-4170-0-12-299-0000ABCDEF") == 299, "npc id from a Creature GUID")
  ok(QD.NpcFromGUID("Player-4170-01234567") == nil, "players are not npcs")
  local name, a, b = QD.ParseObjective("Tough Wolf Meat: 4/8")
  ok(name == "Tough Wolf Meat" and a == 4 and b == 8, "objective parse")

  local OBJ = { { type = "item", text = "Tough Wolf Meat: 4/8", finished = false, numFulfilled = 4, numRequired = 8 } }
  local LOG = { { title = "Elwynn Forest", isHeader = true }, { title = "Wolves Across the Border", questID = 33 } }
  C_QuestLog = {
    GetNumQuestLogEntries = function() return #LOG end,
    GetInfo = function(i) return LOG[i] end,
    GetQuestObjectives = function() return OBJ end,
    GetNumQuestWatches = function() return 1 end,
    GetQuestIDForQuestWatchIndex = function() return 33 end,
    GetTitleForQuestID = function() return "Wolves Across the Border" end,
    IsComplete = function() return false end,
    IsFailed = function() return false end,
  }
  C_Map = { GetBestMapForUnit = function() return 1429 end }
  IsInInstance = function() return false end
  UnitIsPlayer = function() return false end
  QD.dirty = true
  local needs = QD.Needs()
  ok(#needs == 1 and needs[1].item == 750 and needs[1].have == 4, "needs: Tough Wolf Meat 4/8")

  -- tooltip by GUID
  local lines = {}
  local tt = { AddLine = function(_, t) lines[#lines + 1] = t end,
    AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " | " .. r end, Show = function() end }
  UnitGUID = function() return "Creature-0-1-0-1-299-00001" end
  UnitName = function() return "Young Wolf" end
  QD.AddToTooltip(tt, "mouseover")
  ok(lines[1] and lines[1]:find("^Quest: Tough Wolf Meat 4/8 | drop %d+%%$"), "tooltip line: " .. tostring(lines[1]))
  ok(lines[2] == "Classic data; Forever may differ", "subtle note line")

  -- by name + zone when the GUID is not readable
  lines = {}
  UnitGUID = function() return nil end
  QD.AddToTooltip(tt, "mouseover")
  ok(lines[1] and lines[1]:find("Tough Wolf Meat"), "name match without GUID")

  -- a mob that does not drop it
  lines = {}
  UnitGUID = function() return "Creature-0-1-0-1-6-00001" end -- Kobold Vermin
  QD.AddToTooltip(tt, "mouseover")
  ok(#lines == 0, "nothing on a mob that does not drop a needed item")

  -- finished objective: nothing
  OBJ[1].finished, OBJ[1].numFulfilled, OBJ[1].text = true, 8, "Tough Wolf Meat: 8/8"
  QD.dirty = true
  lines = {}
  UnitGUID = function() return "Creature-0-1-0-1-299-00001" end
  QD.AddToTooltip(tt, "mouseover")
  ok(#lines == 0, "objective complete: tooltip line gone")
  local D = Nock.Dash
  local rows = D.QuestRows(D.ReadQuests(), 16)
  local drop = false
  for _, r in ipairs(rows) do if r.kind == "drop" or r.kind == "note" then drop = true end end
  ok(not drop, "objective complete: no drop row on the Dashboard")

  -- Dashboard summary
  OBJ[1].finished, OBJ[1].numFulfilled, OBJ[1].text = false, 4, "Tough Wolf Meat: 4/8"
  QD.dirty = true
  rows = D.QuestRows(D.ReadQuests(), 16)
  ok(rows[3] and rows[3].kind == "drop" and rows[3].pct, "Dashboard drop row with a %: " .. tostring(rows[3] and rows[3].text))

  -- an item no source gives a % for: "drops from", no number
  local nopct
  for id, row in pairs(Nock.QuestDropsData.items) do
    if row[3] == false and #row == 3 then nopct = id break end
  end
  ok(nopct ~= nil, "data has items with no known chance")
  local s = QD.Summary(nopct)
  ok(s and s.pct == nil and s.text:find("^Drops from ") and not s.text:find("%%"), "no %: '" .. tostring(s and s.text) .. "'")

  -- option off
  QD.SetEnabled(false)
  lines = {}
  QD.AddToTooltip(tt, "mouseover")
  ok(#lines == 0 and NockCharDB.questDrops == false, "option off: no tooltip line")
  rows = D.QuestRows(D.ReadQuests(), 16)
  ok(rows[3] == nil or rows[3].kind ~= "drop", "option off: no Dashboard drop row")
  SlashCmdList.NOCK("drops on")
  ok(QD.Enabled(), "/nock drops on")
''', "questdrops tests")
print("QUESTDROPS_TEST_OK")
