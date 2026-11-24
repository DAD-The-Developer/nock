#!/usr/bin/env python3
"""Nock 3.7.0 Dashboard: bags, ammo and tracked quests (Lua 5.1 via lupa)."""
import sys
from pathlib import Path

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

ROOT = Path("/workspace/nock/Nock")
TESTS = Path("/workspace/nock/tests")

toc = (ROOT / "Nock.toc").read_text()
if "## Interface: 16001" not in toc:
    sys.exit("TOC Interface is not 16001")
if "## Version: 3." not in toc:
    sys.exit("TOC Version missing")

lua_files = [
    line.strip()
    for line in toc.splitlines()
    if line.strip() and not line.strip().startswith("#") and line.strip().endswith(".lua")
]
if lua_files[0] != "Theme.lua" or lua_files[-1] != "UI_Launcher.lua":
    sys.exit("unexpected TOC file list: " + ",".join(lua_files))

stubs = (TESTS / "stubs_threat.lua").read_text()
cut = stubs.find("NockCharDB = {}")
if cut < 0:
    sys.exit("could not trim stub Nock tables")
stubs = stubs[:cut]
extra = (TESTS / "stubs_fresh.lua").read_text()

lua = LuaRuntime(unpack_returned_tuples=True)

def run(src, name, addon_name=None):
    try:
        if addon_name:
            g = lua.globals()
            g._SRC = src
            g._NAME = name
            g._ADDON = addon_name
            lua.execute('assert(loadstring(_SRC, _NAME))(_ADDON)')
        else:
            lua.execute(src)
    except Exception as e:
        print("LUA ERROR in", name, ":", e)
        sys.exit(1)

run(stubs, "stubs_threat.lua (trimmed)")
run(extra, "stubs_fresh.lua")

for name in lua_files:
    path = ROOT / name
    if not path.exists():
        sys.exit("missing toc file: " + name)
    # WoW passes the addon name as the file's vararg (...).
    run(path.read_text(), name, addon_name="Nock")

# Drive ADDON_LOADED and PLAYER_LOGIN like a first login on a hunter.
run(r'''
  for _, f in ipairs(FRAMES or {}) do
    local fn = f.GetScript and f:GetScript("OnEvent")
    if fn then
      pcall(fn, f, "ADDON_LOADED", "Nock")
    end
  end
  for _, f in ipairs(FRAMES or {}) do
    local fn = f.GetScript and f:GetScript("OnEvent")
    if fn then
      pcall(fn, f, "PLAYER_LOGIN")
    end
  end
''', "events")


run(r"""
  local results = {}
  local function ok(cond, msg)
    if not cond then error("DASH_FAIL: " .. msg, 0) end
    print("ok  " .. msg)
  end
  local D = Nock.Dash
  bit = { band = function(a, b) local r, p = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end; a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2 end; return r end }
  ok(D ~= nil, "Nock.Dash exists")
  ok(D.IsShown() == false, "off by default (no surprise panel for other players)")
  ok(D.Size() == "large", "Large is the default size")
  ok(BINDING_NAME_NOCK_DASH ~= nil, "unbound keybind entry has a name")

  -- pure helpers
  ok(D.MinutesLeft(1200, 3.0) == 60, "1200 arrows at 3.0 s = 60 min")
  ok(D.MinutesLeft(0, 3.0) == 0, "no ammo = 0 min")
  ok(D.MinutesLeft(500, nil) == nil, "unknown speed = no estimate")
  ok(D.IsAmmoBag(1) and D.IsAmmoBag(2) and not D.IsAmmoBag(0), "quiver and pouch are ammo bags")
  ok(D.ObjectiveText({ text = "Kobold Candle: 4/8" }) == "Kobold Candle 4/8", "objective 'Name: 4/8'")
  ok(D.ObjectiveText({ text = "4/8 Kobold Candle" }) == "Kobold Candle 4/8", "objective '4/8 Name'")
  ok(D.ObjectiveText({ text = "Find the camp" }) == "Find the camp", "plain objective text")
  ok(D.ObjectiveText({ text = "", numFulfilled = 2, numRequired = 5 }) == "2/5", "numbers when no text")

  -- game state
  C_Timer = { After = function(_, fn) fn() end }
  NUM_BAG_SLOTS = 4
  local SLOTS = { [0] = 16, [1] = 14, [2] = 14, [3] = 18, [4] = 16 }
  local FREE = { [0] = 2, [1] = 1, [2] = 0, [3] = 0, [4] = 10 }
  local FAM = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 1 } -- bag 4 is a quiver
  C_Container = C_Container or {}
  C_Container.GetContainerNumSlots = function(b) return SLOTS[b] or 0 end
  C_Container.GetContainerNumFreeSlots = function(b) return FREE[b] or 0, FAM[b] or 0 end
  local free, total = D.ReadBags()
  ok(free == 3 and total == 62, "bags: 3 free of 62, quiver not counted (got " .. tostring(free) .. "/" .. tostring(total) .. ")")

  UnitRangedDamage = function() return 3.0, 10, 20, 0, 0, 1 end
  GetInventoryItemID = function(u, slot) if slot == 0 then return 2515 end end
  GetInventoryItemCount = function() return 1200 end
  C_Item = C_Item or {}
  C_Item.GetItemNameByID = function() return "Sharp Arrow" end
  local am = D.ReadAmmo()
  ok(am.count == 1200 and am.minutes == 60 and am.kind == "Arrows", "ammo: 1200 arrows, about 60 min")

  local QUESTS = {
    [101] = { title = "The Collector", objs = { { text = "Gold Pickup Schedule: 0/1", finished = false, numFulfilled = 0, numRequired = 1 } } },
    [102] = { title = "Kobold Candles", objs = { { text = "Large Candle: 8/8", finished = true, numFulfilled = 8, numRequired = 8 } }, done = true },
    [103] = { title = "Wolves Across the Border", objs = {
      { text = "Tough Wolf Meat: 4/8", finished = false, numFulfilled = 4, numRequired = 8 },
      { text = "Diseased Wolf Pelt: 3/3", finished = true, numFulfilled = 3, numRequired = 3 } } },
  }
  local WATCH = { 103, 102 }
  C_QuestLog = {
    GetNumQuestWatches = function() return #WATCH end,
    GetQuestIDForQuestWatchIndex = function(i) return WATCH[i] end,
    GetTitleForQuestID = function(id) return QUESTS[id] and QUESTS[id].title end,
    GetQuestObjectives = function(id) return QUESTS[id] and QUESTS[id].objs or {} end,
    IsComplete = function(id) return QUESTS[id] and QUESTS[id].done or false end,
    IsFailed = function() return false end,
    GetNumQuestLogEntries = function() return 4, 3 end,
    GetInfo = function(i)
      local list = { { title = "Elwynn Forest", isHeader = true }, { title = "The Collector", questID = 101 },
        { title = "Kobold Candles", questID = 102 }, { title = "Wolves Across the Border", questID = 103 } }
      return list[i]
    end,
  }
  local q = D.ReadQuests()
  ok(q.source == "tracked" and #q.quests == 2, "tracked quests first")
  ok(q.quests[1].title == "Wolves Across the Border" and not q.quests[1].complete, "wolves in progress")
  ok(q.quests[2].complete, "kobold candles done")
  local rows = D.QuestRows(q, 16)
  ok(#rows == 4, "rows: title, 2 objectives, done title (got " .. #rows .. ")")
  ok(rows[2].text == "Tough Wolf Meat 4/8" and rows[3].done, "objective text and done flag")

  WATCH = {}
  q = D.ReadQuests()
  ok(q.source == "log" and #q.quests == 3, "no tracked quests: top of the log, headers skipped")

  -- line cap
  local many = { quests = {}, more = 0 }
  for i = 1, 5 do
    many.quests[i] = { title = "Q" .. i, objectives = { { text = "a" }, { text = "b" }, { text = "c" }, { text = "d" }, { text = "e" } } }
  end
  rows = D.QuestRows(many, 16)
  ok(#rows <= 17 and rows[#rows].kind == "more", "line budget respected, '+N more' shown")

  WATCH = { 103, 102 }
  D.SetShown(true)
  ok(NockCharDB.dash.show == true, "show saved in NockCharDB.dash")
  local f = NockDashFrame
  ok(f ~= nil and f:IsShown(), "dashboard frame shown")
  ok(not (Nock.Core.errors and Nock.Core.errors.dash), "no paint error: " .. tostring(Nock.Core.errors and Nock.Core.errors.dash))
  ok(f.bags.value:GetText() == "3 free", "bags value painted: " .. tostring(f.bags.value:GetText()))
  ok(f.ammo.value:GetText() == "1200", "ammo value painted")
  ok(f.ammo.label:GetText() == "ARROWS", "ammo label says ARROWS")
  ok(f.rows[1]:GetText() == "Wolves Across the Border", "first quest row")
  ok(f._mouse == false, "locked: clicks pass through")
  D.SetUnlocked(true)
  ok(f._mouse == true, "unlocked: draggable")
  D.SetUnlocked(false)
  D.SetSize("small")
  ok(NockCharDB.dash.size == "small", "size saved")
  D.SetSize("bogus")
  ok(NockCharDB.dash.size == "small", "bad size ignored")
  SlashCmdList.NOCK("dash")
  ok(not D.IsShown(), "/nock dash toggles off")
  SlashCmdList.NOCK("dash")
  ok(D.IsShown(), "/nock dash toggles on")
  SlashCmdList.NOCK("dash solid")
  ok(D.IsSolid(), "/nock dash solid")
  ok(NockCharDB.positions == nil or type(NockCharDB.positions) == "table", "positions table intact")
""", "dash tests")
print("DASH_TEST_OK")
