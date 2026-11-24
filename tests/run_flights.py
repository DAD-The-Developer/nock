#!/usr/bin/env python3
"""Nock 3.10.0 flight paths (Lua 5.1 via lupa).

Checks the generated data against its sources (the Forever client CSVs in
tools/flights), then loads the whole addon like run_dash.py and checks pins,
discovery, the continent-map layout and drawing, the options and /nock flights.
"""
import csv, re, sys
from pathlib import Path

src = Path("/workspace/nock/tests/run_dash.py").read_text()
head = src[: src.index("\nrun(r\"\"\"\n  local results")]
exec(compile(head, "run_dash_head", "exec"))

TOOLS = Path("/workspace/nock/tools/flights")
data = (ROOT / "Data_Flights.lua").read_text()
taxi = {int(r["ID"]): r for r in csv.DictReader(open(TOOLS / "TaxiNodes.csv", encoding="utf-8"))}
paths = {(int(r["FromTaxiNode"]), int(r["ToTaxiNode"])) for r in csv.DictReader(open(TOOLS / "TaxiPath.csv"))}
nodes = re.findall(r'^    \[(\d+)\] = \{ "(.*?)", "(A|H|AH)", (\d+), ([\d.]+), ([\d.]+), (\d+), ([\d.]+), ([\d.]+), "(.*?)", (\d+) \},$', data, re.M)
assert len(nodes) >= 55, "too few nodes: %d" % len(nodes)
for nid, name, fac, ui, x, y, cmap, cx, cy, npc, npcid in nodes:
    t = taxi[int(nid)]
    assert t["Name_lang"].replace('"', '\\"') == name, (nid, name)
    flags = int(t["Flags"])
    want = ("A" if flags & 1 else "") + ("H" if flags & 2 else "")
    assert want == fac, (nid, fac, want)
    assert 0 <= float(x) <= 100 and 0 <= float(y) <= 100 and 0 <= float(cx) <= 100 and 0 <= float(cy) <= 100, nid
    assert int(cmap) == {0: 1415, 1: 1414}[int(t["ContinentID"])], nid
    assert npc, nid
print("ok  %d flight points match the Forever TaxiNodes data (name, faction, continent)" % len(nodes))
ids = {int(n[0]) for n in nodes}
rt = [int(v) for v in re.search(r"^  routes = \{ (.*) \},$", data, re.M).group(1).split(", ")]
pairs = list(zip(rt[0::2], rt[1::2]))
for a, b in pairs:
    assert a in ids and b in ids and a < b, (a, b)
    assert (a, b) in paths or (b, a) in paths, ("route not in TaxiPath", a, b)
assert len(set(pairs)) == len(pairs)
print("ok  %d routes, every one a TaxiPath pair between kept points" % len(pairs))

run(r'''
  local function ok(cond, msg)
    if not cond then error("FLIGHTS_FAIL: " .. msg, 0) end
    print("ok  " .. msg)
  end
  local F, P = Nock.Flights, Nock.Pins
  ok(F ~= nil and Nock.FlightData ~= nil, "module and data loaded")
  for _, row in ipairs(Nock.PinData) do
    ok(row[1] ~= 9, "old flight master rows replaced")
    break
  end
  local old = 0
  for _, row in ipairs(Nock.PinData) do if row[1] == 9 then old = old + 1 end end
  ok(old == 0, "no old flight master rows left in PinData")
  ok(P.KindOn("flight") and F.RoutesOn() and not F.OtherOn(), "pins and routes on, other faction off by default")

  UnitFactionGroup = function() return "Alliance" end
  local sw = F.Nodes()[2]
  ok(sw and sw.name == "Stormwind, Elwynn" and sw.npc == "Dungar Longdrink" and sw.map == 1453, "Stormwind: Dungar Longdrink, Stormwind City")
  ok(F.ShowsNode(sw) and not F.ShowsNode(F.Nodes()[23]), "Alliance sees Stormwind, not Orgrimmar")
  local neutral
  for _, n in pairs(F.Nodes()) do if n.fac == "AH" then neutral = n end end
  ok(neutral and F.ShowsNode(neutral), "neutral points show for both")

  -- Not synced yet: says so, does not guess.
  local tip = F.TipLines(sw)
  local joined = ""
  for _, l in ipairs(tip) do joined = joined .. l[1] .. "\n" end
  ok(joined:find("Flight master: Dungar Longdrink", 1, true) and joined:find("open any flight master", 1, true), "before the first flight map: no guess")
  ok(joined:find("Flies to ", 1, true) ~= nil, "lists where it flies")

  -- Discovery from the flight map (Forever C_TaxiMap) ...
  Enum = Enum or {}
  Enum.FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 }
  GetTaxiMapID = function() return 1415 end
  C_TaxiMap = { GetAllTaxiNodes = function() return {
    { nodeID = 2, name = "Stormwind, Elwynn", state = 0 },
    { nodeID = 4, name = "Sentinel Hill, Westfall", state = 1 },
    { nodeID = 5, name = "Lakeshire, Redridge", state = 2 } } end }
  -- ... and the classic taxi functions.
  local TN = { { "Darkshire, Duskwood", "REACHABLE" }, { "Thelsamar, Loch Modan", "NONE" } }
  NumTaxiNodes = function() return #TN end
  TaxiNodeName = function(i) return TN[i][1] end
  TaxiNodeGetType = function(i) return TN[i][2] end
  local seen = F.Sync()
  ok(seen == 3, "sync saw 3 known points (got " .. tostring(seen) .. ")")
  ok(F.Synced() and F.Known(2) and F.Known(4) and F.Known(12), "Stormwind, Sentinel Hill, Darkshire known")
  ok(not F.Known(5) and not F.Known(8), "unreachable / NONE stay undiscovered")
  ok(NockCharDB.flights.known[2] == true, "kept in NockCharDB.flights.known")
  tip = F.TipLines(F.Nodes()[8])
  ok(tip[3][1] == "Not discovered yet", "undiscovered tooltip line")
  ok(F.TipLines(sw)[3][1] == "Discovered", "discovered tooltip line")
  TN = {}
  C_TaxiMap = { GetAllTaxiNodes = function() return {} end }
  F.Sync()
  ok(F.Known(2), "known points are never forgotten")

  -- Zone map pin filter: undiscovered pins are quieter.
  local kdef = P.KINDS[9]
  local e = { flight = F.Nodes()[8] }
  ok(kdef.filter(e) == true and e.dim == true, "undiscovered pin is dimmed")
  e = { flight = sw }
  ok(kdef.filter(e) == true and not e.dim, "discovered pin is full colour")
  ok(kdef.filter({ flight = F.Nodes()[23] }) == false, "Horde pin hidden for Alliance")

  -- Continent layout.
  local pts, segs = F.Layout(1415)
  ok(#pts > 10 and #segs > 10, "Eastern Kingdoms: " .. #pts .. " points, " .. #segs .. " routes")
  local inPts = {}
  for _, n in ipairs(pts) do inPts[n] = true; ok(n.cmap == 1415 and F.ShowsNode(n), "point " .. n.name) end
  for _, s in ipairs(segs) do
    if not (inPts[s[1]] and inPts[s[2]]) then error("FLIGHTS_FAIL: route end not shown") end
  end
  print("ok  every route joins two shown points")
  local p2 = F.Layout(1429)
  ok(#p2 == 0, "nothing extra on a zone map (pins cover those)")
  F.SetOther(true)
  local pts3 = F.Layout(1415)
  ok(#pts3 > #pts, "other faction on: more points")
  F.SetOther(false)
  F.SetRoutes(false)
  local _, s0 = F.Layout(1415)
  ok(#s0 == 0, "routes off: no lines")
  F.SetRoutes(true)

  -- Drawing on a fake continent map.
  local function Fake()
    local o = { _shown = false, _lvl = 5, _w = 0, _h = 0 }
    local mt = {}
    mt.__index = function(t, k)
      if type(k) ~= "string" or k:sub(1, 1) == "_" then return nil end
      return function(self, ...)
        local a = { ... }
        if k == "GetWidth" then return 1000 elseif k == "GetHeight" then return 700
        elseif k == "GetFrameLevel" then return self._lvl elseif k == "SetFrameLevel" then self._lvl = a[1]
        elseif k == "Show" then self._shown = true elseif k == "Hide" then self._shown = false
        elseif k == "IsShown" then return self._shown
        elseif k == "GetParent" then return self._parent elseif k == "SetParent" then self._parent = a[1]
        elseif k == "CreateTexture" or k == "CreateLine" or k == "CreateFontString" then
          local c = Fake(); c._kind = k; self._kids = self._kids or {}; table.insert(self._kids, c); return c
        elseif k == "SetColorTexture" then self._color = a
        elseif k == "SetStartPoint" then self._s = a elseif k == "SetEndPoint" then self._e = a
        elseif k == "SetScript" then self._scripts = self._scripts or {}; self._scripts[a[1]] = a[2]
        elseif k == "GetScript" then return self._scripts and self._scripts[a[1]] end
      end
    end
    return setmetatable(o, mt)
  end
  local canvas = Fake()
  local realCF = CreateFrame
  HOSTS = {}
  CreateFrame = function(kind, name, parent) local f = Fake(); f._parent = parent; table.insert(HOSTS, f); return f end
  MapCanvasDataProviderMixin = { GetMap = function(self) return self._map end }
  CreateFromMixins = function(m) local o = {}; for k, v in pairs(m) do o[k] = v end; return o end
  WorldMapFrame = { _id = 1415, GetMapID = function(s) return s._id end, GetCanvas = function() return canvas end,
    GetCanvasScale = function() return 1 end, IsShown = function() return true end,
    AddDataProvider = function(s, p) p._map = s; s._p = p end }
  F.HookWorldMap()
  WorldMapFrame._p:RefreshAllData()
  ok(F.lastError == nil, "draw ran clean: " .. tostring(F.lastError))
  local nl = 0
  for _, l in ipairs(HOSTS) do
    for _, c in ipairs(l._kids or {}) do
      if c._kind == "CreateLine" and c._shown then nl = nl + 1 end
    end
  end
  local _, segsNow = F.Layout(1415)
  ok(nl == #segsNow, "continent map: " .. nl .. " route lines drawn")
  local nm = 0
  for _, l in ipairs(HOSTS) do
    if l._parent ~= canvas and l._shown and l._scripts and l._scripts.OnEnter then nm = nm + 1 end
  end
  local ptsNow = F.Layout(1415)
  ok(nm == #ptsNow, "continent map: " .. nm .. " point markers with tooltips")
  CreateFrame = realCF
  WorldMapFrame._id = 1429
  WorldMapFrame._p:RefreshAllData()
  ok(F.lastError == nil, "zone map: nothing drawn, no error")

  -- Slash
  SlashCmdList.NOCK("flights off")
  ok(not P.KindOn("flight") and not F.RoutesOn(), "/nock flights off")
  SlashCmdList.NOCK("flights on")
  ok(P.KindOn("flight") and F.RoutesOn(), "/nock flights on")
  SlashCmdList.NOCK("flights other on")
  ok(F.OtherOn(), "/nock flights other on")
  SlashCmdList.NOCK("flights other off")
  ok(F.Status():find("discovered", 1, true) ~= nil, "status: " .. F.Status())
''', "flights tests")
print("FLIGHTS_TEST_OK")
