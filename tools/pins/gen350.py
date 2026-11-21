"""Nock 3.5.0 pins: hunter-relevant NPCs from QuestieDB Forever (facts only)."""
import re, json, collections
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
D='/tmp/QuestieDB/'
def load(path, var):
    s=open(path,encoding='utf-8').read()
    i=s.index(var+' = [[')+len(var+' = [[')
    j=s.index(']]', i)
    while True:
        try: return lua.execute(s[i:j])
        except Exception: j=s.index(']]', j+2)
npcs=load(D+'data/Forever/foreverNpcDB.lua','QuestieDB.npcData')
items=load(D+'data/Forever/foreverItemDB.lua','QuestieDB.itemData')
quests=load(D+'data/Forever/foreverQuestDB.lua','QuestieDB.questData')
zs=open(D+'support/Forever/Zones/areaIdToUiMapId.lua').read()
a2u={}
for m in re.finditer(r'\[(\d+)\]\s*=\s*(\d+),\s*--\s*(.*)', zs):
    a2u.setdefault(int(m.group(1)), (int(m.group(2)), m.group(3).strip()))
def L(t): return [t[k] for k in sorted(t.keys())] if t else []

# Pet food ids from Nock's own Data_Food.lua plus name words.
food_src=open('/workspace/nock/Nock/Data_Food.lua').read()
petfood={int(a):b for a,b in re.findall(r'\[(\d+)\]\s*=\s*"(\w+)"', food_src)}
words=re.findall(r'\{\s*"([^"]+)",\s*"(\w+)"\s*\}', food_src)
DIET_CODE={'Meat':'M','Fish':'F','Bread':'B','Cheese':'C','Fruit':'R','Fungus':'U'}
DRINK_WORDS=('Water','Milk','Juice','Nectar','Dew','Tea','Cider')
def diet_of(iid,name):
    if iid in petfood: return petfood[iid]
    for w,d in words:
        if w in name: return d
    return None

ITEM={}   # iid -> (code, reqLevel, name)
for iid in items.keys():
    it=items[iid]; cls=it[12]; sub=it[13]; name=it[1] or ''
    if not it[14]: continue
    code=None
    if cls==6 and sub==2: code='a'
    elif cls==6 and sub==3: code='b'
    elif cls==11 and sub==2: code='q'
    elif cls==11 and sub==3: code='p'
    elif cls==2 and sub==2: code='w'
    elif cls==2 and sub==3: code='g'
    elif cls==2 and sub==18: code='c'
    elif cls==2 and sub==16: code='t'
    elif cls==0:
        d=diet_of(iid,name)
        if d: code=DIET_CODE[d]
        elif any(w in name for w in DRINK_WORDS): code='d'
    if code: ITEM[iid]=(code, it[10] or 0, name)
stock=collections.defaultdict(set)
for iid,(code,lv,name) in ITEM.items():
    for n in L(items[iid][14]): stock[n].add(iid)

# Hunter-only quests by starter NPC.
hq=collections.defaultdict(list)
for qid in quests.keys():
    q=quests[qid]
    if q[7]==4 and q[2] and q[2][1]:
        for n in L(q[2][1]): hq[n].append((q[1], q[5] or q[4] or 0))

TRAINER_RE=re.compile(r'^(Hunter Trainer|Hunter Beast Trainer|Bow Trainer|Gun Trainer|Crossbow Trainer|Weapon Master)$')
PET_RE=re.compile(r'Pet Trainer$')
STABLE_RE=re.compile(r'^(Stable Master|Stablehand)$')
FLIGHT_RE=re.compile(r'^(Flight Master|Gryphon Master|Wind Rider Master|Hippogryph Master|Bat Handler)$')
KIND={'trainer':1,'pet':2,'stable':3,'ammo':4,'ranged':5,'quiver':6,'petfood':7,'quest':8,'flight':9}
rows=[]; zones={}
seen=set()
for nid in npcs.keys():
    n=npcs[nid]; sub=n[14] or ''; fac=n[13]; flags=n[15] or 0
    if fac not in ('A','H','AH'): continue
    goods=set(ITEM[i][0] for i in stock.get(nid,()))
    kinds=[]
    if TRAINER_RE.match(sub): kinds.append('trainer')
    if PET_RE.search(sub): kinds.append('pet')
    if STABLE_RE.match(sub): kinds.append('stable')
    if goods & set('ab'): kinds.append('ammo')
    if goods & set('wgct'): kinds.append('ranged')
    if goods & set('qp'): kinds.append('quiver')
    if goods & set('MFBCRU'): kinds.append('petfood')
    if nid in hq: kinds.append('quest')
    if FLIGHT_RE.match(sub) or (flags & 8 and 'Master' in sub): kinds.append('flight')
    if not kinds: continue
    primary=kinds[0]
    hunter_items=sorted(stock.get(nid,()), key=lambda i:(ITEM[i][0], ITEM[i][1]))
    qs=sorted(set(hq.get(nid,[])), key=lambda x:x[1])
    for z in (n[7].keys() if n[7] else []):
        if z not in a2u: continue
        um,zname=a2u[z]
        if um==0: continue
        for c in L(n[7][z]):
            x,y=c[1],c[2]
            if x is None or x<0: continue
            k=(nid,um,round(x,1),round(y,1))
            if k in seen: continue
            seen.add(k); zones[um]=zname
            rows.append(dict(id=nid,kind=KIND[primary],kinds=[KIND[k] for k in kinds],fac=fac,map=um,x=round(x,1),y=round(y,1),
                name=n[1],sub=sub,goods=''.join(sorted(goods)),items=hunter_items,quests=qs))
json.dump(rows,open('/tmp/pins350.json','w'))
json.dump({str(k):v for k,v in ITEM.items()},open('/tmp/items350.json','w'))
c=collections.Counter()
for r in rows:
    for k in r['kinds']: c[(k,r['fac'])]+=1
print(len(rows),'rows'); print(sorted(c.items()))
