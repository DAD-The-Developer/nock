# Changelog

All notable changes to Nock from 3.0.11 onward. The addon folder's `Nock/README.txt` also has older notes.

## 3.4.1

- The kill / XP tracker sat on top of the bar stack under the bow, where the pet / extra row covered it and took the mouse, so Shift-drag did nothing. It now starts at the top centre, sits above the bars (HIGH strata) with a dark backdrop, an emerald edge and a `::` grip, sizes itself to its text, and stays on screen. Shift-drag moves it; `/nock tracker unlock | lock | reset` too. Old 3.4.0 positions are dropped.
- Before your first kill the tracker shows an estimate from the same-level mob XP formula ("about 26 kills to 29") instead of "?". At 60 it reads "1 kill" / "12 kills" and no longer shows a bare dash.
- `/nock unlock` and `/nock lock` toggle drag mode for every movable Nock frame (tracker, quiver counter, threat meter, range / Wing Clip readout, PvP readout, alert banner), each with a green outline and its name while unlocked; readouts show a sample so you can place them. `/nock reset positions` puts every frame back. Also Options > Hunter tools > "Unlock frames" and the unbound keybind "Unlock or lock all Nock frames". Frames lock again in combat and on login.
- The range and PvP readouts and the alert banner only take the mouse while unlocked, so they never block clicks or camera turning. The range readout now defaults a little higher (centre, 90 px down) to stay clear of the bar stack.

## 3.4.0

Hunter tools: eleven small tools that share one core (module registry, one event frame, throttled ticker, per-tool settings in `NockCharDB.mods`). Each is on by default, has its own switch and settings in Options > Hunter tools, a `/nock` word, and a section on the new **Tools** tab (`/nock kit`). `/nock tools` lists them; `/nock tools mute` silences their alerts.

A shared profile layer every tool reads: your level, every spell and rank in your spellbook (rescanned when you learn something), your spec from talent points (Beast Mastery, Marksmanship, Survival or hybrid) and where you are (solo, party, raid, dungeon, raid instance, battleground or arena). At level 60 the tools switch to endgame mode (`/nock tools endgame auto | on | off`).

- **Pet happiness and feeding** (`/nock pet`): big warning when your pet turns content or unhappy (louder for Beast Mastery). New keybind "Feed pet (best food in your bags)" feeds the best food your pet's diet allows, saving higher-level food. Warns when you carry nothing it eats, or only food too low level to help.
- **Supply warnings** (`/nock supplies`): ammo, pet food, food and water against targets you can set. Reminds you in town and near ammo vendors; big warning the moment you leave town short. Raid-night targets at 60 (`/nock supplies raid` for the checklist).
- **Sell junk and repair** (`/nock vendor`): sells greys and repairs from your own gold (never the guild bank) at any vendor, with a one-line chat summary. Hold Shift to skip once.
- **Dead zone, range and Wing Clip** (`/nock range`): readout under your character for MELEE, DEAD ZONE and TOO FAR. In melee it says "WING CLIP, then step back" when the target is not slowed, then "STEP BACK" with the Wing Clip time left; alerts when Wing Clip falls off something still in melee; the Wing Clip key on Nock's bar (Mouse 4) glows while it is wanted. Edge flash in the dead zone. Survival builds see the Improved Wing Clip note.
- **Taming helper** (`/nock tame`): 63 rare tameable beasts as paw pins on the maps (your level band, or all), with family, level, abilities and attack speed; your pet's missing ability ranks and which beasts teach them.
- **Aspect reminder** (`/nock aspects`): fighting without Hawk (Monkey before Hawk), a loud warning when Cheetah or Pack is on in a fight, and a quiet Cheetah nudge when you travel on foot outdoors.
- **Feign Death resisted alert** (`/nock feign`): big red alert, raid warning sound and edge flash.
- **Hunter route and field notes** (`/nock route`): where to level now and next for your faction (Forever zones incl. Zephras Isle, Riverglades, Mount Hyjal), dungeons in range, hunter milestones. At 60: the raid-night checklist and what is open in Forever.
- **Trainer reminder** (`/nock train`): on level up, the hunter and pet trainer ranks waiting for you (from the 136-rank Forever trainer list, checked against your spellbook) and the nearest hunter trainer.
- **Kill and XP tracker** (`/nock tracker`): kills to level, XP per hour and time to level; gold per hour and kills at 60. Shift-drag to move.
- **PvP** (`/nock pvp`): in battlegrounds and arenas (if the client has them) PvP mode quiets the PvE nags (pet feeding, route, trainer, tracker), makes dead-zone and Wing Clip cues louder, and shows an enemy-player readout: class, role and the sting to use (Viper vs casters, Scorpid vs melee, only if known), whether the target is slowed, big enemy buffs (Ice Block, Divine Shield, Freedom ...), and your Concussive / Scatter / trap / Feign cooldowns. Alerts on enemy PvP trinkets and low ammo when the queue pops. `/nock pvp guide` and the route in PvP show the PvP field notes (kiting, dead zone, trap juggling, Wing Clip + step back, class matchups). `/nock tools pvp off` turns PvP mode off.

New keybinds (Key Bindings > AddOns > Nock, all unbound): Feed pet, Open Hunter Tools, Check supplies, What is waiting at the trainer, Rare beast pins, Kill / XP tracker, Mute hunter tool alerts. Content lives in data files (`Data_Spells`, `Data_Pets`, `Data_Food`, `Data_Route`, `Data_PvP`) so it can grow without new code. New pin icon: restart the game fully once.

## 3.3.1

New Emerald quiver counter art: Ben's painted elven quiver (green and white fletching, gold filigree, emerald gems) replaces the code-drawn one. It is larger (84 px before bar-size scaling), drawn over the green / yellow / red ring so the ring never covers it, and the ammo count sits low in the arch between the quiver's legs with a heavy black outline and drop shadow. Gunsmith keeps the ammo pouch. The new texture needs a full game restart the first time.

## 3.3.0

Hunter map pins: hunter trainers, pet trainers, stable masters and ammo vendors (arrows, bullets, quivers and ammo pouches) show on the minimap and the world map, for your faction, in every major city and town in Kalimdor and the Eastern Kingdoms. On by default. Each kind has its own icon (bow, pawprint, horseshoe, arrow bundle) and a tooltip with the NPC's name, role, zone and coordinates. On the minimap the nearest one of each kind stays on the edge, dimmed, when it is out of range, so you always know which way to go. `/nock pins` turns them all on or off; `/nock pins trainer | pet | stable | ammo` hides one kind; `/nock pins minimap | map` picks where; `/nock pins hostile` also shows the other faction's NPCs. The same toggles are in Options under "Maps and ammo", and "Show or hide hunter map pins" is in Key Bindings > AddOns > Nock.

Quiver counter: a quiver (Emerald) or ammo pouch (Gunsmith) on screen with your ammo count in big numbers. The ring is green when stocked (over 66% of what your quiver or pouch holds, or of 1000 with none equipped), yellow at 33–66%, and red below that, with a slow pulse. Hover for the ammo name and count. Shift-drag to move it; `/nock quiver unlock` lets you drag it freely, `/nock quiver lock` and `/nock quiver reset` put it back. `/nock quiver` or the "Show or hide the quiver counter" keybind turns it off. New textures need a full game restart the first time.

## 3.2.0

The Gunsmith options window no longer shows a tan slab or a floating title bar: the panel background is a solid dark wood, and the header sits on the top edge with matching corners. The settings window in both styles is larger, easier to read (16–18 pt at Large), and uses plain toggle rows and segmented size/style buttons. The Cheat Sheet lists every key in two columns with the full name, never cut off.

Open Nock without a slash command: a Nock button on the Escape menu, a small movable button (left-click to open, Shift-drag to move; `/nock button reset` puts it back; turn it off in Options), and the "Open Nock" keybind in Key Bindings > AddOns > Nock.

## 3.1.1

Gunsmith spell tiles are no longer cut off or stretched: each icon is square, and the carved frame sits around it instead of over it. The plaque wood is solid, and the barrel caps sit behind the buttons. The threat meter stays up while it is unlocked, even out of combat, until you lock it. Style, threat position, bar size and the other settings now persist across `/reload` and relog. `/nock save` confirms this character's UI is remembered. `/nock profile save <name>` and `/nock profile load <name>` store a whole setup account-wide (`/nock profile list` to see them).

## 3.1.0

Two looks for the HUD: Emerald (the default bow) and Gunsmith (dwarven rifle, from custom art). Layout, spacing and size stay the same when you swap. Pick one in `/nock` settings (Style), type `/nock style gun` or `/nock style emerald`, or bind "Switch HUD style" in Key Bindings. The choice is saved per character and applies live; new textures need a full game restart the first time they are installed.

The threat meter can be moved. Type `/nock threat unlock` (or bind "Unlock or lock the threat meter") to show a highlighted outline and a "Drag to move" label — the whole plaque is the handle. It snaps to the middle of the bar. `/nock threat lock` holds it there; `/nock threat reset` puts it back above the bow. The position is saved per character. It stays locked by default and will not move in a fight (unlock waits until combat ends).

## 3.0.15

The threat meter rows (You and your pet, with bars and percents) now draw inside the carved plaque. A layout helper had been clearing their anchors, which left an empty wood frame. Errors are saved and printed once in chat. `/nock threat debug` labels each API return.

## 3.0.14

The threat meter still works after a `/reload` in a fight. It polls every fraction of a second while you are in combat so a missed event cannot leave it blank, and it shows an em dash when Forever will not give a number. Type `/nock threat debug` in a fight to print the raw API values.

## 3.0.13

The threat meter is rebuilt on a consistent grid: even padding, equal-height bars, names on the left and percents on the right, all vertically centered. Its width matches the bow plaque. The frame is carved wood with silver-gold trim and corner filigree, and the fill has a light gloss.

## 3.0.12

A carved threat meter sits above the bow: one bar for you, one for your pet, against your current target (or the pet's target if you have none). It shows threat percent and who has aggro, in emerald when you are safe, amber when you are close to pulling, and red if you pull off the pet. It hides out of combat, turns on by itself, and has a toggle in `/nock`.

## 3.0.11

The Hearth tile is icon-only, so the label can no longer clip to "earth". Key letters on the extra and utility bars sit fully inside the top-left corner of each tile, bold and outlined like the main bar. Main bow tiles keep even spacing and the same top-left key tabs. Cooldown numbers stay centered on the icon, in whole seconds.
