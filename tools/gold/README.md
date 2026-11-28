# Nock gold data (3.13.0)

`gen_gold.py` writes `Nock/Data_Gold.lua`: skinning and coin camps, the riding
and level-40 mount cost, profession rank rules and vendor arrows / bullets.
Facts only — every camp is a real group of spawn spots, every number comes
from a database row. Nothing is invented.

## Sources

* **QuestieDB Forever** — `data/Forever/foreverNpcDB.lua` (spawn spots per
  zone, level range, rank, friendly faction) and
  `support/Forever/Zones/areaIdToUiMapId.lua` (zone → world map id).
* **CMaNGOS classic-db** (Full_DB + Updates) loaded in MariaDB as `cm`:
  * `creature_template` — `CreatureType` (1 = beast), `SkinningLootId`
    (> 0 = skinnable), `MinLootGold` / `MaxLootGold` (coin per kill).
  * `npc_trainer` — riding (spell cost at level 40, every riding
    instructor) and profession ranks (skill / level / cost).
  * `npc_vendor` + `item_template` — level-40 mount price, vendor ammo
    (required level, price per stack, damage).

These are **Classic** numbers. WoW Forever may differ; the addon labels them.

## Rebuild the inputs (the box gets replaced now and then)

```sh
sudo apt-get install -y mariadb-server && sudo service mariadb start
git clone --depth 1 https://github.com/Questie/QuestieDB /tmp/QuestieDB   # needs data/Forever
git clone --depth 1 https://github.com/cmangos/classic-db /tmp/classic-db
sudo mysql -e "CREATE DATABASE cm; CREATE USER IF NOT EXISTS '$USER'@'localhost' IDENTIFIED VIA unix_socket; GRANT ALL ON cm.* TO '$USER'@'localhost';"
# load the newest Full_DB/*.sql.gz, then every Updates/*.sql newer than it, into `cm`
pip install lupa
python3 tools/gold/gen_gold.py
```

## Rules

* **Camps**: hostile (not friendly to either faction), normal rank (not
  elite). `skin` = skinnable beasts; `coin` = any mob that drops coin. Greedy
  clustering inside a 6 map-percent radius; a camp needs 8+ spawn spots; each
  map keeps its 4 best skinning and 3 best coin camps. The pin sits on the
  real spawn spot nearest the middle of the group.
* **Mount**: the one riding cost every riding instructor charges at level 40
  plus the one price every level-40 mount vendor charges (before reputation
  discounts). The script stops if the data disagrees.
* **Profession ranks**: the level for each rank is the level most trainer
  rows state for it across all professions (10 / 20 / 35); the cost is that
  profession's rank row.
* **Ammo**: arrows and bullets a vendor sells without a stock limit.
