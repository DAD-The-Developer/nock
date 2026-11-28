#!/usr/bin/env python3
"""Nock 3.13.0: gold-while-levelling data (facts only, no invented spots or numbers).

Sources
  * QuestieDB Forever (data/Forever/foreverNpcDB.lua): every NPC's spawn spots
    per zone (field 7), level range (4, 5), rank (6, 0 = normal) and which
    faction it is friendly to (13; nil = hostile to both). Zones map to world
    map ids with support/Forever/Zones/areaIdToUiMapId.lua.
  * CMaNGOS classic-db (Full_DB + Updates, loaded in MariaDB `cm`):
      creature_template.CreatureType (1 = beast), SkinningLootId (> 0 = can
      be skinned), MinLootGold / MaxLootGold (coin dropped per kill, copper);
      npc_trainer (riding skill and profession ranks: cost, required level,
      required skill); npc_vendor + item_template (mount prices, which arrows
      and bullets a vendor sells, their required level and damage).
  These are Classic numbers; Forever may differ, and the addon says so.

Camps
  A camp is a tight group of spawn spots on one map (greedy: the spot with
  the most neighbours within RADIUS map-percent seeds a camp, every spot
  within RADIUS of it joins, repeat). Only real spawn spots are used.
    skin  hostile, normal (not elite) beasts that can be skinned
    coin  hostile, normal mobs of any type that drop coin
  A camp needs MIN_SPAWNS spots; each map keeps its best camps by count.

Run: python3 tools/gold/gen_gold.py  (needs /tmp/QuestieDB and the `cm`
MariaDB database; see tools/gold/README.md). Writes Nock/Data_Gold.lua.
"""
import re, subprocess
from collections import defaultdict, Counter
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
Q = Path('/tmp/QuestieDB')
lua = LuaRuntime(unpack_returned_tuples=True)
RADIUS = 6.0       # map percent
MIN_SPAWNS = 8
PER_MAP = {'skin': 4, 'coin': 3}

def load(path, var):
    s = open(path, encoding='utf-8').read()
    i = s.index(var + ' = [[') + len(var + ' = [[')
    j = s.index(']]', i)
    while True:
        try:
            return lua.execute(s[i:j])
        except Exception:
            j = s.index(']]', j + 2)

def L(t):
    return [t[k] for k in sorted(t.keys())] if t else []

def sql(q):
    out = subprocess.run(['mysql', 'cm', '-N', '-B', '-e', q], capture_output=True, text=True, check=True).stdout
    return [l.split('\t') for l in out.splitlines() if l]

npcs = load(Q / 'data/Forever/foreverNpcDB.lua', 'QuestieDB.npcData')
a2u = {}
for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),', (Q / 'support/Forever/Zones/areaIdToUiMapId.lua').read_text()):
    a2u.setdefault(int(m.group(1)), int(m.group(2)))

ct = {}
for e, ty, sk, mn, mx in sql('select Entry, CreatureType, SkinningLootId, MinLootGold, MaxLootGold from creature_template'):
    ct[int(e)] = (int(ty), int(sk), int(mn), int(mx))

# ---- camps -------------------------------------------------------------------------------------------------------
pts = {'skin': defaultdict(list), 'coin': defaultdict(list)}   # map -> [(x, y, npcid)]
for nid, n in npcs.items():
    nid = int(nid)
    c = ct.get(nid)
    if not c or not n[7] or (n[6] or 0) != 0 or n[13]:
        continue
    lo, hi = int(n[4] or 0), int(n[5] or n[4] or 0)
    if lo <= 0:
        continue
    kinds = []
    if c[0] == 1 and c[1] > 0:
        kinds.append('skin')
    if c[3] > 0:
        kinds.append('coin')
    for z in n[7].keys():
        ui = a2u.get(int(z))
        if not ui:
            continue
        for p in L(n[7][z]):
            if p[1] and p[1] > 0:
                for k in kinds:
                    pts[k][ui].append((float(p[1]), float(p[2]), nid))

def camps(points):
    left = list(points)
    out = []
    r2 = RADIUS * RADIUS
    while len(left) >= MIN_SPAWNS:
        best, bi = -1, None
        for i, (x, y, _) in enumerate(left):
            n = sum(1 for (a, b, _) in left if (a - x) ** 2 + (b - y) ** 2 <= r2)
            if n > best:
                best, bi = n, i
        if best < MIN_SPAWNS:
            break
        x, y, _ = left[bi]
        member = [p for p in left if (p[0] - x) ** 2 + (p[1] - y) ** 2 <= r2]
        left = [p for p in left if (p[0] - x) ** 2 + (p[1] - y) ** 2 > r2]
        # pin on the member nearest the centre of the group (a real spawn spot)
        cx = sum(p[0] for p in member) / len(member)
        cy = sum(p[1] for p in member) / len(member)
        px, py, _ = min(member, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
        out.append((px, py, member))
    return out

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

rows = []
stats = Counter()
for kind in ('skin', 'coin'):
    for ui in sorted(pts[kind]):
        found = camps(pts[kind][ui])[:PER_MAP[kind]]
        for px, py, member in found:
            ids = Counter(p[2] for p in member)
            lo = min(int(npcs[i][4]) for i in ids)
            hi = max(int(npcs[i][5] or npcs[i][4]) for i in ids)
            names = [str(npcs[i][1]) for i, _ in ids.most_common(3)]
            coin = None
            if kind == 'coin' or any(ct[i][3] > 0 for i in ids):
                tot = sum(cnt * (ct[i][2] + ct[i][3]) / 2 for i, cnt in ids.items())
                coin = round(tot / len(member))
            rows.append(f'    {{ {q(kind)}, {ui}, {px:.1f}, {py:.1f}, {lo}, {hi}, {len(member)}, {{ {", ".join(q(n) for n in names)} }}, {coin if coin else "nil"} }},')
            stats[kind] += 1

# ---- riding and level-40 mount -----------------------------------------------------------------------------------
riding = sql('select spellcost, reqlevel, count(*) from npc_trainer where entry in (3690,4732,4752,4753,4772,4773,7953,7954) and reqlevel=40 group by spellcost, reqlevel')
assert len(riding) == 1, riding
ride_cost = int(riding[0][0])
mounts = sql('select distinct i.BuyPrice from npc_vendor v join item_template i on i.entry=v.item where v.entry in (384,1261,3685,4730,4731,7952,7955,1460,2357,4885) and i.RequiredLevel=40 and i.RequiredSkill=762')
assert len(mounts) == 1, mounts
mount_cost = int(mounts[0][0])

# ---- profession ranks (the cost and the rule the most trainers use) ---------------------------------------------------
PROF = {'Skinning': 393, 'Mining': 186, 'Herbalism': 182, 'First Aid': 129, 'Cooking': 185, 'Fishing': 356,
        'Leatherworking': 165, 'Blacksmithing': 164, 'Engineering': 202, 'Alchemy': 171, 'Enchanting': 333, 'Tailoring': 197}
RANKS = [('Journeyman', 50, 150), ('Expert', 125, 225), ('Artisan', 200, 300)]
# The level each rank needs: the level the trainer rows for that rank state most often
# across every profession (some gathering rows in CMaNGOS leave it at 0; the trainer
# in game enforces the real rule either way).
RULE = {}
for rk, need, cap in RANKS:
    r = sql(f'select reqlevel, count(*) c from npc_trainer where reqskillvalue={need} and reqlevel > 0 and spellcost >= 500 '
            f'and reqskill in ({",".join(str(v) for v in PROF.values())}) group by reqlevel order by c desc limit 1')
    RULE[rk] = int(r[0][0])
prof_rows = []
for name, skill in PROF.items():
    parts = []
    for rk, need, cap in RANKS:
        r = sql(f'select spellcost, count(*) c from npc_trainer where reqskill={skill} and reqskillvalue={need} '
                f'and reqlevel={RULE[rk]} group by spellcost order by c desc limit 1')
        if not r:   # rank row without the level: the dearest row at that skill is the rank itself
            r = sql(f'select spellcost from npc_trainer where reqskill={skill} and reqskillvalue={need} order by spellcost desc limit 1')
        parts.append(f'{{ {q(rk)}, {need}, {RULE[rk]}, {int(r[0][0])}, {cap} }}' if r else 'nil')
    prof_rows.append(f'    [{q(name)}] = {{ {", ".join(parts)} }},')
print('rank levels', RULE)

# ---- vendor arrows and bullets ---------------------------------------------------------------------------------------
ammo = sql('select i.entry, i.name, i.subclass, i.RequiredLevel, i.BuyPrice, i.BuyCount, i.dmg_min1, i.dmg_max1 from item_template i '
           'where i.class=6 and i.subclass in (2,3) and i.name not like "Deprecated%" and i.name not like "Depricated%" '
           'and (exists (select 1 from npc_vendor v where v.item=i.entry and v.maxcount=0) or exists (select 1 from npc_vendor_template t where t.item=i.entry and t.maxcount=0)) '
           'order by i.subclass, i.RequiredLevel')
ammo_rows = [f'    {{ {e}, {q(n)}, {q("Arrow" if s == "2" else "Bullet")}, {lv}, {bp}, {bc}, {(float(a) + float(b)) / 2:g} }},'
             for e, n, s, lv, bp, bc, a, b in ammo]

out = ['--[[',
 '  Nock 3.13.0: gold while levelling. Generated by tools/gold/gen_gold.py; do not edit.',
 '  Sources: QuestieDB Forever spawns + CMaNGOS classic-db (Classic numbers; Forever may differ).',
 '',
 '  Camps     { kind ("skin"|"coin"), uiMapID, x, y (0-100, a real spawn spot near the',
 '              middle of the group), minLevel, maxLevel, spawn spots, { top names },',
 '              average coin per kill in copper or nil }',
 '  Mount     riding skill and level-40 mount cost in copper (trainer / vendor price,',
 '            before any reputation discount)',
 '  ProfRanks [profession] = { { rank, skill needed, level needed, cost, new cap } x3 }',
 '            (level: what most trainer rows state for that rank; the cost: that profession\'s row)',
 '  Ammo      { itemID, name, "Arrow"|"Bullet", required level, price, per stack, damage }',
 ']]',
 'local Nock = _G.Nock',
 'if not Nock then',
 '  return',
 'end',
 'Nock.Data = Nock.Data or {}',
 'Nock.Data.Gold = {',
 '  Camps = {', *rows, '  },',
 f'  Mount = {{ riding = {ride_cost}, mount = {mount_cost}, level = 40 }},',
 '  ProfRanks = {', *prof_rows, '  },',
 '  Ammo = {', *ammo_rows, '  },',
 '}', '']
(ROOT / 'Nock/Data_Gold.lua').write_text('\n'.join(out))
print(f"camps: skin {stats['skin']}, coin {stats['coin']}; riding {ride_cost}c + mount {mount_cost}c; {len(ammo_rows)} ammo; {len(prof_rows)} professions")
