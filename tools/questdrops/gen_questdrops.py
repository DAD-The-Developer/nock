#!/usr/bin/env python3
"""Nock 3.9.0: quest item drop chances (facts only, no invented numbers).

Sources
  * QuestieDB Forever (data/Forever/foreverQuestDB.lua, foreverItemDB.lua,
    foreverNpcDB.lua): which quests need which items (itemObjective) and which
    NPCs drop each item (npcDrops), from the WoW Forever client data.
  * CMaNGOS classic-db (Full_DB + Updates, Nov 2026, loaded in MariaDB `cm`):
    creature_template.LootId -> creature_loot_template.ChanceOrQuestChance.
      - A negative value is a quest chance (drops only while you need it);
        the absolute value is the chance.
      - Grouped rows with chance 0 share what is left of the group equally
        (100 - explicit chances in that group) / number of equal rows; that is
        how the CMaNGOS loot code rolls a group, so it is derived, not guessed.
      - One level of reference_loot_template is followed only when the
        reference row and the item row are both ungrouped with explicit
        chances (chance = ref% x item%). Anything else stays "no %".
  An NPC that QuestieDB Forever lists as a source but CMaNGOS has no chance
  for is kept with no chance: the addon says "drops from" without a %.
  These are Classic numbers; Forever may differ (the addon says so).

Run: python3 tools/questdrops/gen_questdrops.py  (needs /tmp/QuestieDB and
the `cm` MariaDB database). Writes Nock/Data_QuestDrops.lua.
"""
import subprocess, json
from collections import defaultdict
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
Q = Path('/tmp/QuestieDB/data/Forever')
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

def L(t):
    return [t[k] for k in sorted(t.keys())] if t else []

quests = load(Q / 'foreverQuestDB.lua', 'QuestieDB.questData')
items = load(Q / 'foreverItemDB.lua', 'QuestieDB.itemData')
npcs = load(Q / 'foreverNpcDB.lua', 'QuestieDB.npcData')

import re
a2u = {}
for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),', Path('/tmp/QuestieDB/support/Forever/Zones/areaIdToUiMapId.lua').read_text()):
    a2u.setdefault(int(m.group(1)), int(m.group(2)))

def sql(q):
    out = subprocess.run(['mysql', 'cm', '-N', '-B', '-e', q], capture_output=True, text=True, check=True).stdout
    return [l.split('\t') for l in out.splitlines() if l]

# Quest-objective items (Forever quests only).
need = set()
for qid, q in quests.items():
    obj = q[10]
    if obj and obj[3]:
        for row in L(obj[3]):
            need.add(int(row[1]))

lootid = {int(e): int(l) for e, l in sql('select Entry, LootId from creature_template')}
rows = defaultdict(list)   # loot entry -> [(item, chance, group, mincountOrRef)]
for e, it, ch, g, mc in sql('select entry, item, ChanceOrQuestChance, groupid, mincountOrRef from creature_loot_template'):
    rows[int(e)].append((int(it), float(ch), int(g), int(mc)))
refs = defaultdict(list)
for e, it, ch, g, mc in sql('select entry, item, ChanceOrQuestChance, groupid, mincountOrRef from reference_loot_template'):
    refs[int(e)].append((int(it), float(ch), int(g), int(mc)))

def chance_in(table_rows, item):
    """Chance (%) of `item` in one loot table, or None when not derivable."""
    for it, ch, g, mc in table_rows:
        if it != item or mc < 0:
            continue
        c = abs(ch)
        if g == 0:
            return c if c > 0 else None
        if c > 0:
            return c
        grp = [r for r in table_rows if r[2] == g and r[3] >= 0]
        explicit = sum(abs(r[1]) for r in grp if r[1] != 0)
        equal = [r for r in grp if r[1] == 0]
        left = 100 - explicit
        return left / len(equal) if equal and left > 0 else None
    return None

def chance(npc, item):
    t = rows.get(lootid.get(npc, 0), [])
    c = chance_in(t, item)
    if c is not None:
        return c
    for it, ch, g, mc in t:
        if mc < 0 and g == 0 and ch != 0:
            for rit, rch, rg, rmc in refs.get(-mc, []):
                if rit == item and rg == 0 and rch != 0 and rmc >= 0:
                    return abs(ch) * abs(rch) / 100
    return None

MAX_SOURCES = 40
skipped = []
out_items, used_npcs = {}, {}
with_pct = without_pct = 0
for iid in sorted(need):
    it = items[iid]
    if not it or not it[2]:
        continue
    srcs = []
    for n in L(it[2]):
        n = int(n)
        if npcs[n] is None:
            continue
        c = chance(n, iid)
        srcs.append((n, None if c is None else (round(min(c, 100.0), 1) if c >= 0.1 else float('%.2g' % c))))
    if not srcs:
        continue
    # Size: general world drops (cloth, gems, potions, herbs) that a few
    # turn-in quests ask for drop from hundreds of NPCs as random loot. They
    # are left out unless they are real quest items (item class 12).
    if len(srcs) > MAX_SOURCES and it[12] != 12:
        skipped.append((iid, it[1], len(srcs)))
        continue
    srcs.sort(key=lambda s: (-(s[1] or -1), s[0]))
    out_items[iid] = (it[1], srcs)
    for n, _ in srcs:
        used_npcs[n] = (npcs[n][1], a2u.get(int(npcs[n][9] or 0), 0))
    if any(c is not None for _, c in srcs):
        with_pct += 1
    else:
        without_pct += 1

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

lines = [
    '-- AUTO-GENERATED by tools/questdrops/gen_questdrops.py. Do not edit.',
    '-- Quest items that drop from NPCs: which NPCs (QuestieDB Forever) and the',
    '-- loot chance in % (CMaNGOS classic-db creature_loot_template; quest chances',
    '-- stored as negatives are shown as their absolute value). false = this NPC',
    '-- drops it but no source gives a chance. Classic data; Forever may differ.',
    '-- items[itemID] = { "Item name", npcID, pct|false, npcID, pct|false, ... }',
    '-- (sources sorted best chance first)',
    '-- npcs[npcID] = { "Name", uiMapID of the zone it is most common in (0 = unknown) }',
    'local Nock = _G.Nock',
    'if not Nock then return end',
    'Nock.QuestDropsData = {',
    '  stats = { items = %d, withPct = %d, withoutPct = %d, npcs = %d },' % (len(out_items), with_pct, without_pct, len(used_npcs)),
    '  items = {',
]
for iid, (name, srcs) in out_items.items():
    parts = [q(name)]
    for n, c in srcs:
        parts += [str(n), 'false' if c is None else ('%g' % c)]
    lines.append('    [%d] = { %s },' % (iid, ', '.join(parts)))
lines += ['  },', '  npcs = {']
for n in sorted(used_npcs):
    lines.append('    [%d] = { %s, %d },' % (n, q(used_npcs[n][0]), used_npcs[n][1]))
lines += ['  },', '}', '']
(ROOT / 'Nock/Data_QuestDrops.lua').write_text('\n'.join(lines))
print(json.dumps({'items': len(out_items), 'withPct': with_pct, 'withoutPct': without_pct, 'npcs': len(used_npcs),
                  'pairs': sum(len(s) for _, s in out_items.values()),
                  'skippedWorldDrops': len(skipped), 'pairsPct': sum(1 for _, s in out_items.values() for _, c in s if c is not None)}))
