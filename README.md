# Nock

Nock is a no-click, keybind-first Hunter HUD addon for [World of Warcraft: Forever](https://wowforever.com/). It shows your shots, pet, traps, experience, and threat in one readable bar, fills empty keys with a hunter layout, and includes a written rotation and talent plan. It does not play the game for you: you still aim and press the keys.

Two looks are included: **Emerald** (the default bow) and **Gunsmith** (a dwarven rifle). Layout and size stay the same when you swap.

This repository has no license yet. All rights are reserved until one is added. If you want to use or share the code or art beyond installing the addon for yourself, wait for a license or ask first.

## Install (WoW Forever)

The addon lives in the `Nock/` folder at the root of this repo. That folder is what you copy into AddOns.

1. Close World of Warcraft: Forever if it is open.
2. Copy the `Nock` folder into:

       World of Warcraft\_forever_\Interface\AddOns

   When you are done, this file should exist:

       World of Warcraft\_forever_\Interface\AddOns\Nock\Nock.toc

   On a Mac that folder is usually:

       /Applications/World of Warcraft/_forever_/Interface/AddOns

   Do not copy it into the regular (non-Forever) AddOns folder.

3. Start Forever. At the character screen, open AddOns and make sure Nock is enabled. If the game says it is out of date, also enable "Load out of date AddOns".
4. Log in on a Hunter. The first time you install Nock (or after new textures), fully restart the game — quit and open it again, not just `/reload` — so the art loads.

Then open Nock in any of these ways:

- type `/nock`
- press Escape and click **Nock**
- click the small Nock button on the screen (Shift-drag to move it; `/nock button reset` puts it back)
- set the **Open Nock** key in Key Bindings > AddOns > Nock

A short install note also ships inside the addon as `Nock/INSTALL.txt`.

## Map pins and quiver counter (3.3.0)

Hunter trainers, pet trainers, stable masters and ammo vendors show on the minimap and the world map for your faction, in every major city and town in Kalimdor and the Eastern Kingdoms. The nearest one of each kind stays on the minimap edge when it is out of range. `/nock pins` turns them on or off; `/nock pins trainer | pet | stable | ammo | minimap | map | hostile` toggles one part. The client has no NPC location API, so the spots are a built-in list (`Nock/PinsData.lua`) of Classic-era spawn points taken from the community [QuestieDB](https://github.com/Questie/QuestieDB) Forever data.

A movable quiver counter (an ammo pouch in Gunsmith) shows your ammo in big numbers: green when stocked, yellow at half, red when low. Shift-drag to move; `/nock quiver`, `/nock quiver unlock | lock | reset`.

## Hunter tools (3.4.0)

Eleven small tools on one core (`Nock/Core.lua`): each is on by default, with its own switch in Options > Hunter tools, a `/nock` word, and a section on the **Tools** tab (`/nock kit`). They all read one profile layer: level, spellbook ranks, spec from talents, and context (solo, group, dungeon, raid, battleground, arena). At 60 they switch to endgame mode; in battlegrounds and arenas to PvP mode.

| Command | Tool |
| --- | --- |
| `/nock pet` | Pet happiness warnings; "Feed pet" keybind feeds the best food |
| `/nock supplies` | Ammo, pet food, food and water warnings in town and when you leave |
| `/nock vendor` | Auto sell junk and repair (own gold) |
| `/nock range` | Melee / dead zone / too far readout, Wing Clip prompt, timer and fall-off alert |
| `/nock tame` | Rare tameable beast pins, your pet's missing ability ranks |
| `/nock aspects` | Hawk in combat, no Cheetah/Pack in a fight, Cheetah when travelling |
| `/nock feign` | Feign Death resisted alert |
| `/nock route` | Leveling route and hunter milestones; endgame checklist at 60; `/nock route pvp` |
| `/nock train` | New trainer ranks on level up and the nearest trainer |
| `/nock tracker` | Kills to level, XP/hour; gold/hour at 60 |
| `/nock pvp` | Enemy player readout, trinket alerts, PvP field notes |
| `/nock tools` | List, `mute`, `endgame auto/on/off`, `pvp on/off` |
| `/nock unlock` / `lock` / `reset positions` | Move every Nock frame (3.4.1) |

Data lives in `Data_Spells.lua` (Forever trainer list, from wowforever.one, CC BY 4.0), `Data_Pets.lua` (families, diets and ranks from warcraftmaps.com; rare beasts and teachers are Classic data; spawn points from QuestieDB), `Data_Food.lua`, `Data_Route.lua` and `Data_PvP.lua`. Add rows to grow them.

## Switching styles

Nock starts with the Emerald bow. To use the Gunsmith rifle look, open Nock, go to Options, and choose Style: Gunsmith. You can also type:

```
/nock style gun
/nock style emerald
```

The choice is saved for that character. After you first install a new style's textures, do a full game restart.

## Slash commands

Type `/nock help` in game for the full list. The ones you will use most:

| Command | What it does |
| --- | --- |
| `/nock` | Open the Nock window |
| `/nock style gun` / `/nock style emerald` | Swap the HUD look |
| `/nock size small` / `normal` / `large` | Bar and window size (default Large) |
| `/nock button reset` | Put the movable Nock button back |
| `/nock mouse on` / `off` | Side mouse buttons for Wing Clip, Concussive, and Feign Death |
| `/nock threat` | Show or hide the threat meter |
| `/nock threat unlock` / `lock` / `reset` | Move, lock, or restore the threat meter |
| `/nock overlay` | Show or hide the key bar |
| `/nock restore` | Put your old keys back |
| `/nock save` | Remember this character's UI |
| `/nock profile save` / `load` / `list` | Account-wide UI setups |

Nock fills empty keys with a hunter layout the first time you log in. Keys you already set are left alone. Mouse 4, Mouse 5, and a wheel click are used only if those buttons are free.

This addon is for Hunter characters, especially Beast Mastery and Marksmanship.

## What's in this repo

```
Nock/            The addon. Copy this folder into Interface\AddOns.
art/             PNG masters and packing scripts for the custom art.
gun-assets/      Original Gunsmith source paintings.
tests/           Lua 5.1 harness (style, threat, and a fresh empty-DB load).
tools/           pack_release.py builds the shareable zip.
CHANGELOG.md     Changes from 3.0.11 through the current release.
RELEASING.md     How to version, tag, and publish a GitHub Release.
```

## Tests

From the repo root, with Python 3 and [lupa](https://pypi.org/project/lupa/) (Lua 5.1):

```
python3 tests/run_style.py
python3 tests/run_threat.py
python3 tests/run_fresh_load.py
python3 tests/run_pins.py
python3 tests/run_tools.py
```

## Build a release zip

```
python3 tools/pack_release.py
```

That writes `share/Nock-<version>.zip` with one top-level `Nock` folder, ready to extract into `_forever_\Interface\AddOns`. It does not include tests, art masters, or SavedVariables.

Released zips are also attached to [GitHub Releases](https://github.com/DAD-The-Developer/nock/releases).

## License

No license is set yet. All rights reserved until one is added.
