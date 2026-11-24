# Nock

Nock is a no-click, keybind-first Hunter HUD addon for [World of Warcraft: Forever](https://wowforever.com/). It shows your shots, pet, traps, experience, and threat in one readable bar, fills empty keys with a hunter layout, and includes a written rotation and talent plan. It does not play the game for you: you still aim and press the keys.

Two looks are included: **Emerald** (the default bow) and **Gunsmith** (a dwarven rifle). Layout and size stay the same when you swap.

Nock is licensed under the GNU General Public License, version 3. Copyright (C) 2026 Benjamin Vilina (DAD-The-Developer). See [LICENSE](LICENSE).

It is also listed on CurseForge as [Nock Hunter HUD](https://www.curseforge.com/wow/addons/nock-hunter-hud) (the short name "Nock" was already taken).

## Install (WoW Forever)

The easiest way is the CurseForge app: set the game flavor to **Forever** and install [Nock Hunter HUD](https://www.curseforge.com/wow/addons/nock-hunter-hud). The app should place it in `World of Warcraft\_forever_\Interface\AddOns\Nock`.

For a manual install, the addon lives in the `Nock/` folder at the root of this repo. That folder is what you copy into AddOns.

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

**Quest drops** (3.9.0): while a quest still needs an item that drops from mobs, the mob's tooltip shows the drop chance (`Quest: Tough Wolf Meat 4/8 — drop 80%`) and the Dashboard shows the best mob under the objective. Real CMaNGOS Classic loot chances matched to QuestieDB Forever sources; no % where no source has one (see `tools/questdrops/README.md`). Options > On screen or `/nock drops on|off`.

**Keybinds** (3.8.0): Nock copies all your keybinds the first time 3.8.0 loads and keeps that copy for good. `/nock binds restore` (or Options > Keybind backup) puts them back after a confirm, out of combat. Choose **Nock layout** (Nock's left-hand keys, e.g. Ctrl-G, Ctrl-Z, C, Z, X, V, take priority while it's on; your saved keybinds are never overwritten and come back when you switch) or **My own keybinds** (Nock sets no keys and each button shows the key you already use) in Setup, Options or `/nock binds own on|off`. Every button shows range (calm red out of range or in the dead zone; melee lit only in melee) and cooldowns, and `/nock new` opens the What's New window.

The **Dashboard** (3.7.0) is one compact panel with free bag slots, ammo left (with about how many minutes of Auto Shot that is) and your tracked quests with objective progress. Park it in a corner or mirror it to a second monitor with OBS's Windowed Projector. `/nock dash` shows it; `/nock dash unlock | lock | reset | small | normal | large | solid`.

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
| `/nock dash` | Dashboard: bags, ammo and tracked quests |
| `/nock drops on\|off` | Quest item drop chances on mob tooltips and the Dashboard |
| `/nock binds` | Keybind backup: `list`, `backup`, `restore [n]`, `own on\|off` |
| `/nock new` | What's New in this version |
| `/nock pvp` | Enemy player readout, trinket alerts, PvP field notes |
| `/nock tools` | List, `mute`, `endgame auto/on/off`, `pvp on/off` |
| `/nock unlock` / `lock` / `reset positions` | Move every Nock frame (3.4.1) |
| `/nock alerts` | `test`, `quiet`, `sound`, `size 0.8-1.4`, `max 1|2`, `list`, `<category> on|off`, `<alert id> on|off` (3.5.0) |

Data lives in `Data_Spells.lua` (Forever trainer list, from wowforever.one, CC BY 4.0), `Data_Pets.lua` (families, diets and ranks from warcraftmaps.com; rare beasts and teachers are Classic data; spawn points from QuestieDB), `Data_Food.lua`, `Data_Route.lua` and `Data_PvP.lua`. Add rows to grow them.

## Alerts (3.5.0)

Every Nock reminder goes through one alert manager (`Nock/Alerts.lua`): a single movable stack (`/nock unlock`), at most one or two toasts on screen, critical first and the rest queued, with de-duplication, per-alert cooldowns, a short fade and auto-dismiss (critical 4 s, warning 5 s, info 6 s). Toasts show the real spell or item icon, a short title, one line of detail and a thin accent bar (red critical, amber warning, emerald or brass info). The look comes from a theme table per style (Emerald: dark wood, silver-gold trim; Gunsmith: gunmetal, brass); a new style only lists what differs and inherits the rest. Sound plays only for critical alerts and can be turned off. Options > Alerts has size, how many at once, quiet mode (critical only), sound, edge flashes, a Test alerts button (also `/nock alerts test` and an unbound keybind) and a switch for every category and every alert, generated from the registry.

### Adding an alert

1. Declare it in `Nock/Data_Alerts.lua`:

```lua
{ id = "pet.lowhealth", category = "pet", priority = "warning", icon = "spell:Mend Pet",
  title = "{pet} is low", sub = "Mend Pet or back off", cooldown = 20,
  contexts = { pvp = false }, minLevel = 12, label = "Pet health low" },
```

2. Fire it where the condition happens: `Nock.Alerts:Fire("pet.lowhealth", { pet = name })`.

That's all: Options > Alerts gets its switch, `/nock alerts pet.lowhealth off` works, quiet mode, cooldowns, PvP and level rules apply. `Nock.Alerts:Clear(id)` hides it early. Other fields: `spec = { bm = true }`, `condition = function(vars) ... end`, `contexts = { only = true, pvp = true }` (PvP only), `duration`, `sound = false`. Icons: `"spell:Name"`, `"item:ID"` or a texture path. New categories can be labelled in `Nock.Alerts.CATEGORY_LABELS`. A new style: `Nock.Alerts:RegisterTheme("mystyle", { trim = {...}, accent = { info = {...} } })`.

## Map pins (3.5.0)

Pins now cover hunter trainers and weapon masters, pet trainers, stable masters, ammo vendors, bowyers and gunsmiths, quiver and ammo pouch vendors, pet food vendors (only those selling what your pet eats unless you choose all), hunter class quest givers near your level, and flight masters (off by default). Each kind has its own switch. Hovering a vendor lists what it sells by category with item icons and the best item for your level, marking ammo for your ranged weapon and food your pet eats; a small dot on the pin shows a second category. The minimap shows the nearest few of each kind and folds overlapping pins into one; city and zone maps show each other's pins through world coordinates. Data is generated from QuestieDB Forever (`PinsData.lua`: rows plus `PinStock`, `PinItems`, `PinQuests`). A new kind is one row in `Pins.KINDS` plus a goods code in the generator.

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
LICENSE          GNU General Public License, version 3.
RELEASING.md     How to version, tag, and publish a GitHub and CurseForge release.
```

## Tests

From the repo root, with Python 3 and [lupa](https://pypi.org/project/lupa/) (Lua 5.1):

```
python3 tests/run_style.py
python3 tests/run_threat.py
python3 tests/run_fresh_load.py
python3 tests/run_pins.py
python3 tests/run_tools.py
python3 tests/run_window.py
```

## Build a release zip

```
python3 tools/pack_release.py
```

That writes `share/Nock-<version>.zip` with one top-level `Nock` folder, ready to extract into `_forever_\Interface\AddOns`. It does not include tests, art masters, or SavedVariables.

Released zips are also attached to [GitHub Releases](https://github.com/DAD-The-Developer/nock/releases) and, once a tagged release is published, to [Nock Hunter HUD on CurseForge](https://www.curseforge.com/wow/addons/nock-hunter-hud).

## License

Nock is licensed under the [GNU General Public License, version 3](https://www.gnu.org/licenses/gpl-3.0.html). Copyright (C) 2026 Benjamin Vilina (DAD-The-Developer). See [LICENSE](LICENSE).
