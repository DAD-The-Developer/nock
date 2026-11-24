#!/usr/bin/env python3
"""Nock 3.10.0: flight paths (facts only, nothing guessed).

Sources
  * WoW Forever client data, build 1.60.1.71037, DB2 tables exported as CSV
    from wago.tools (https://wago.tools/db2/<Table>/csv?build=1.60.1.71037),
    kept next to this script:
      TaxiNodes.csv        node ID, name, continent, world position, Flags
                           (0x1 Alliance, 0x2 Horde, both = neutral)
      TaxiPath.csv         FromTaxiNode -> ToTaxiNode (direct flights)
      UiMapAssignment.csv  world -> map coordinates for every zone/continent
      UiMap.csv            map names and types
  * QuestieDB Forever (data/Forever/foreverNpcDB.lua): flight master NPCs
    (npcFlags 0x08, the Classic UNIT_NPC_FLAG_FLIGHTMASTER), their names and where they stand.

A node is kept only when it is a player flight point (a faction flag, on
Kalimdor or the Eastern Kingdoms, not a quest/transport/test path) AND a
QuestieDB Forever flight master stands within MATCH_YD yards of it. Nodes
without a matching flight master are left out, never guessed. Routes are
TaxiPath pairs whose two ends are both kept (drawn once per pair).

Run: python3 tools/flights/gen_flights.py  (needs /tmp/QuestieDB)
Writes Nock/Data_Flights.lua.
"""
import csv, json, math, re
from pathlib import Path
from lupa.lua51 import LuaRuntime

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
Q = Path('/tmp/QuestieDB')
MATCH_YD = 60
CONTINENT_UI = {0: 1415, 1: 1414}
lua = LuaRuntime(unpack_returned_tuples=True)

def load(path, var):
    s = open(path, encoding='utf-8').read()
    i = s.index(var + ' = [[') + len(var + ' = [[')
    j = s.index(']]', i)
    while True:
        try:
            return lua.execute(s[i:j])
        except Exception:
            j = s.index(']]', j + 2)

def rows(name):
    return list(csv.DictReader(open(HERE / name, encoding='utf-8')))

uimap = {int(r['ID']): r for r in rows('UiMap.csv')}
assign = {}
for r in rows('UiMapAssignment.csv'):
    m = int(r['UiMapID'])
    if r['OrderIndex'] != '0' or m in assign:
        continue
    assign[m] = {k: float(r[k]) for k in ('UiMin_0', 'UiMin_1', 'UiMax_0', 'UiMax_1', 'Region_0', 'Region_1', 'Region_3', 'Region_4')}
    assign[m]['MapID'] = int(r['MapID'])

def to_map(m, wx, wy):
    a = assign[m]
    u = (a['Region_4'] - wy) / (a['Region_4'] - a['Region_1'])
    v = (a['Region_3'] - wx) / (a['Region_3'] - a['Region_0'])
    return a['UiMin_0'] + u * (a['UiMax_0'] - a['UiMin_0']), a['UiMin_1'] + v * (a['UiMax_1'] - a['UiMin_1'])

def to_world(m, x, y):
    a = assign[m]
    u = (x - a['UiMin_0']) / (a['UiMax_0'] - a['UiMin_0'])
    v = (y - a['UiMin_1']) / (a['UiMax_1'] - a['UiMin_1'])
    return a['Region_3'] - v * (a['Region_3'] - a['Region_0']), a['Region_4'] - u * (a['Region_4'] - a['Region_1'])

# Flight masters from QuestieDB Forever, in world coordinates.
npcs = load(Q / 'data/Forever/foreverNpcDB.lua', 'QuestieDB.npcData')
a2u = {}
for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),', (Q / 'support/Forever/Zones/areaIdToUiMapId.lua').read_text()):
    a2u.setdefault(int(m.group(1)), int(m.group(2)))
fms = []
for nid in list(npcs.keys()):
    n = npcs[nid]
    if not n[15] or not (int(n[15]) & 0x08) or not n[7]:
        continue
    for area in list(n[7].keys()):
        ui = a2u.get(int(area))
        if ui not in assign or uimap.get(ui, {}).get('Type') != '3':
            continue
        for pt in [n[7][area][k] for k in sorted(n[7][area].keys())]:
            x, y = pt[1] / 100, pt[2] / 100
            wx, wy = to_world(ui, x, y)
            fms.append({'id': int(nid), 'name': n[1], 'fac': n[13] or '', 'ui': ui, 'x': x, 'y': y,
                        'wx': wx, 'wy': wy, 'cont': assign[ui]['MapID']})

SKIP = re.compile(r'^(zz|Quest Path|Transport|Generic|Programmer)', re.I)
nodes, omitted = {}, []
for r in rows('TaxiNodes.csv'):
    nid, cont, flags, name = int(r['ID']), int(r['ContinentID']), int(r['Flags']), r['Name_lang']
    fac = ('A' if flags & 1 else '') + ('H' if flags & 2 else '')
    if cont not in CONTINENT_UI or not fac or SKIP.match(name):
        continue
    wx, wy = float(r['Pos_0']), float(r['Pos_1'])
    best, bd = None, None
    for f in fms:
        if f['cont'] != cont:
            continue
        # A faction-only node needs a flight master friendly to that faction.
        if fac != 'AH' and f['fac'] and fac not in f['fac']:
            continue
        d = math.hypot(f['wx'] - wx, f['wy'] - wy)
        if bd is None or d < bd:
            best, bd = f, d
    if not best or bd > MATCH_YD:
        omitted.append((nid, name, None if bd is None else round(bd)))
        continue
    cx, cy = to_map(CONTINENT_UI[cont], wx, wy)
    nodes[nid] = {'name': name, 'fac': fac, 'ui': best['ui'], 'x': best['x'], 'y': best['y'],
                  'cmap': CONTINENT_UI[cont], 'cx': cx, 'cy': cy, 'npc': best['name'], 'npcId': best['id'], 'yd': round(bd)}

routes = set()
for r in rows('TaxiPath.csv'):
    a, b = int(r['FromTaxiNode']), int(r['ToTaxiNode'])
    if a in nodes and b in nodes and a != b:
        routes.add((min(a, b), max(a, b)))
routes = sorted(routes)

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

L = [
    '-- AUTO-GENERATED by tools/flights/gen_flights.py. Do not edit.',
    '-- Flight points from the WoW Forever 1.60.1 client data (TaxiNodes, TaxiPath,',
    '-- UiMapAssignment via wago.tools), each matched to its flight master in',
    '-- QuestieDB Forever. Nodes without a matching flight master are left out.',
    '-- nodes[taxiNodeID] = { "Name", faction "A"|"H"|"AH", uiMapID, x, y (0-100, where',
    '--   the flight master stands), continent uiMapID, cx, cy (0-100 on the continent map),',
    '--   "Flight master name", npcID }',
    '-- routes = { a, b, a, b, ... } direct flights, one entry per pair.',
    'local Nock = _G.Nock',
    'if not Nock then return end',
    'Nock.FlightData = {',
    '  nodes = {',
]
for nid in sorted(nodes):
    n = nodes[nid]
    L.append('    [%d] = { %s, "%s", %d, %.1f, %.1f, %d, %.2f, %.2f, %s, %d },' % (
        nid, q(n['name']), n['fac'], n['ui'], n['x'] * 100, n['y'] * 100, n['cmap'], n['cx'] * 100, n['cy'] * 100, q(n['npc']), n['npcId']))
L.append('  },')
L.append('  routes = { ' + ', '.join('%d, %d' % r for r in routes) + ' },')
L.append('}')
L.append('')
(ROOT / 'Nock/Data_Flights.lua').write_text('\n'.join(L))
fc = {}
for n in nodes.values():
    fc[n['fac']] = fc.get(n['fac'], 0) + 1
print(json.dumps({'nodes': len(nodes), 'byFaction': fc, 'routes': len(routes), 'omitted': omitted,
                  'maxMatchYd': max(n['yd'] for n in nodes.values())}))
