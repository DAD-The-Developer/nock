# Changelog

All notable changes to Nock from 3.0.11 onward. The addon folder's `Nock/README.txt` also has older notes.

## 3.13.0

Make gold while you level, and see the rank of every spell on your bars.

### New

- Rank badges. Every Nock bar tile and pet bar tile shows the rank it casts (R6) in its bottom-left corner, clear of the key, count and cooldown. Spells without ranks show nothing. /nock ranks on | off, or Options > Rank badges on bar tiles.
- Always the highest rank. When you log in or learn a new rank, any Nock slot (yours or your pet's) still holding an older rank is upgraded in place, out of combat, and announced: Arcane Shot on bar slot 2 upgraded from Rank 1 to Rank 3. Slots that hold someone else's spell or an item are never touched.
- Item values. Bag tooltips show the vendor price (each and for the stack) and, with Auctionator installed, the auction price. Items worth more than 1g, any green or better and every recipe say Keep — worth selling. Greys say Nock sells them at the next vendor. /nock gold threshold <gold> changes the 1g.
- Valuable loot alert. A calm toast when you loot something over the keep value, a green or better, or a recipe or pattern, with what it is worth.
- Skinning and coin camps on the maps. Groups of skinnable beasts and of mobs that drop coin near your level, from real spawn data. Hover a pin for the spawn count, levels, names and coin per kill.
- Gold on the dashboard: earned this session, gold per hour, what your bags are worth (vendor, and auction with Auctionator) and a mount fund meter toward 100g for riding and your first mount.
- Profession tips: a nudge toward Skinning plus Mining or Herbalism when a slot is free, a reminder when Journeyman, Expert or Artisan can be trained, and which leather, ore, herb and cloth stacks are worth holding.
- Don't waste gold: the best arrows or bullets for your level at any vendor, and at the hunter trainer which new ranks can wait because they are not on your Nock bars. Advice only.
- /nock gold shows it all. /nock gold value | drops | pins | dash | prof | fund on | off, /nock gold mount <gold> | auto, /nock gold reset. Each part also has a switch in Options > Tools.

### Improved

- The junk seller checks each slot again right before selling it, so if your bags shift mid-sale nothing but a grey is ever sold.

## 3.12.0

The best-reward pick now follows your spec and your talents, live.

### New

- Spec-aware reward picks. Nock reads your talent points and blends the Beast Mastery, Marksmanship and Survival weights by how many points are in each tree. With no talents yet it uses the generic hunter weights. The card and tooltip name the spec: Nock pick (Marksmanship): Sharpshooter Vest.
- Key talents count directly: Mortal Shots makes crit worth more, Lightning Reflexes makes Agility worth more, Survivalist Stamina, Ranged Weapon Specialization your bow or gun.
- Override the spec in Options (Reward spec: Auto, BM, MM, SV) or with /nock rewards spec auto | bm | mm | sv. /nock rewards shows the spec and weights in use.

### Improved

- If you change talents, level up or the talent setup changes while a quest reward window is open, the tags, border and card are scored again right away.
- Marksmanship counts ranged attack power, crit and ranged DPS higher. Survival counts crit, Stamina and Strength higher. Beast Mastery counts Stamina, Intellect and mana higher (your pet's uptime).

## 3.11.0

Quest turn-ins show the best reward for a hunter, and how big an upgrade each one is.

### New

- Best reward for a hunter. When you turn a quest in, the best choice gets a gold border and a small Nock pick tag. A short reason is in its tooltip and under the quest window, for example: +5 Agility, +14% upgrade over your Hunting Bow.
- Every choice shows how much of an upgrade it is over what you wear in that slot: +12%, same, downgrade, new slot (nothing worn there yet), or - when a hunter can't use it. The same shows in the quest preview and the quest log.
- No upgrade in the list? Nock marks the reward that sells for the most: No upgrade, best to sell (1g 20s).
- /nock rewards on | off, or Options > Best quest reward for a hunter. Nock only marks; it never picks a reward or turns the quest in for you.

### Improved

- Scores like a hunter: Agility first, then attack power, crit and hit, then Stamina, Intellect, Spirit and Strength. Bows, guns and crossbows count their DPS heavily. Rings and trinkets replace the weaker of your two, and a two-hander is weighed against both hands.
- Plate, shields, maces, wands, other classes' gear, mail before level 40 and anything above your level are never picked. Items the game hasn't loaded yet are requested and checked again by themselves.

## 3.10.2

New spells, new ranks, pet skills and new pets are placed and announced by themselves.

### New

- Nock tells you what changed. When you learn a spell or a new rank, one chat line says what was added and where, for example: Added Feign Death to E, or Arcane Shot upgraded to Rank 6. After a trainer visit you get one grouped message, not a line per spell.
- Pets too. When your pet learns something you get a line like: Pet Rex learned Bite (Rank 4), on pet bar slot 5. A new rank says upgraded. A pet you have not had before gets one line listing its abilities and their pet bar slots.
- /nock announce off turns the chat lines off (keys are still filled). /nock announce on brings them back.

### Improved

- Nothing waits for a Rebuild click any more. A short moment after the last learn event Nock places the new spell on its planned empty key, repaints the bar and says so. In a fight it waits until the fight ends.
- A pet ability that is learned but not on the pet bar goes on the first empty pet slot. If the pet bar is full Nock says it is in the pet spellbook and changes nothing.
- Keys you set yourself are never replaced. If a spell's key is yours, Nock says so instead of claiming it.

## 3.10.1

Rebuild now really rebuilds, and Feign Death always has a tile.

### New

- A report after Rebuild. Click Rebuild on My Rotation (or type /nock check) and Nock tells you in chat what it read from your spellbook, which spells are on a tile, which are on a key only, which are not on anything, and what your trainer still has for you.
- /nock check feign death (any spell name) shows exactly how Nock sees that one spell: its spell id, the spellbook entry, the rank, and whether it has a tile.

### Improved

- Nock now reads your spellbook first to decide what you know, and always uses your highest rank. Before, it asked the game by spell name, which could pick the wrong rank or miss a spell you had just trained.
- Rebuild rescans your spellbook, puts anything newly trained on its planned empty key, then repaints the bar. It never replaces a key you set yourself, and it waits for the end of a fight.
- If a spell cannot be picked up by its id, Nock now falls back to its spellbook slot.

### Fixed

- Feign Death had no tile when the mouse wheel click was already yours. The bar now shows it on E in that case, like Wing Clip does on Shift-Z.
- Spells you have not learned yet that the spellbook lists ahead of time are no longer counted as known.

## 3.10.0

Every flight path on your maps, with the routes between them.

### New

- Flight paths. Every flight point for your faction, plus neutral ones, is a pin on the zone maps and the minimap. Hover one for the flight point, its flight master, the zone, whether you have discovered it and where it flies.
- Routes. On the Kalimdor and Eastern Kingdoms maps, small square markers joined by thin lines show who flies where. Hover a point to light up its routes.

### Improved

- Discovered or not: Nock remembers the flight points you know each time you open a flight master's map. Ones you have not found yet are quieter on the map. Until you open a flight map once, the tooltip says so instead of guessing.
- 61 flight points and 133 routes from the WoW Forever client data, each matched to its flight master. Options > Maps and ammo > Flight paths (routes, other faction), or /nock flights on | off.

## 3.9.0

Quest item drop chances on mobs and in the Dashboard.

### New

- Quest item drop chances. Hover a mob (or your target frame) that drops an item your quest still needs and its tooltip says so, e.g. Quest: Tough Wolf Meat 4/8, drop 80%. The Dashboard shows the best mob (your zone first) under the objective, with the range when several mobs drop it. Finished objectives show nothing.

### Improved

- Real numbers only: CMaNGOS Classic loot chances for 1,053 quest items, matched to the mobs QuestieDB Forever lists. Where no source has a chance (38 items) it just says which mob drops it. A small grey line notes Classic data; Forever may differ.
- Options > On screen > Quest item drop chances, or /nock drops on | off.

## 3.8.1

Clearer words for the two key choices.

### Fixed

- Clearer keybind layout description: Nock's left-hand keys (e.g. Ctrl-G, Ctrl-Z, C, Z, X, V) take priority while Nock layout is on; your saved keybinds are never overwritten and come back when you switch to My own keybinds. 3.8.0 wrongly said "free keys only". How keys work did not change.

## 3.8.0

Your keybinds are backed up, your own keys are a first-class choice, and every button reads range and cooldowns.

### New

- Keybind backup. The first time 3.8.0 loads, Nock saves a copy of every keybind you have (both keys of each action, and whether you use account or character keybinds). That first copy is kept for good. /nock binds restore or Options > Keybind backup puts them back, after you confirm.
- Use my own keybinds. Nock sets no keys at all, and every Nock button shows the key you already use for that spell. Pick it in Setup (Keys: Nock layout or My own keybinds), in Options, or with /nock binds own on.
- A What's New window that opens once after an update (a short welcome on a new install). /nock new or Options > What's new opens it again.

### Improved

- Range on every button. Shots turn a calm red when the target is out of range or inside the dead zone; melee skills light up only in melee range; Mend Pet and Intimidation dim when your pet can't use them. Aspects, traps and Feign Death are never shaded.
- Wing Clip button: lit in melee, a slow soft pulse in melee or the dead zone until the target is slowed, then the seconds left in the corner. Concussive Shot and Frost Trap count as slowed. Options can turn the pulse off.
- Cooldowns: clean sweep with whole-second numbers, a faint sweep for the global cooldown, and one brief soft highlight when a long cooldown is ready and you can use it. Numbers and the highlight each have a switch in Options.
- Range reads run on one shared timer and only while you have a target.

### Details

- Backup: GetNumBindings / GetBinding for every action plus GetBindingAction on every key and modifier (for direct spell / macro / item / click binds), GetCurrentBindingSet for the set. Stored in NockCharDB.keyBackup with date and character; the first copy is never overwritten, manual copies keep the newest 5. Taken at login and before any Nock key or override is set.
- /nock binds list | backup | restore [n] | own on|off. Restore is out of combat only, asks with a StaticPopup, then SetBinding (or SetBindingSpell / Macro / Item / Click) and SaveBindings on the copy's set, and switches to "Use my own keybinds".
- "Use my own keybinds" (NockCharDB.ownBinds) turns off Nock's override keys, the dedicated Caps Lock / ` suggestions, keep-up filling, old-key cleanup, the 2.1 key move and Set me up's binds. Switching never calls SetBinding or SaveBindings. Button badges come from the Nock Key Bindings entry, a SPELL / MACRO bind, or the action bar slot that holds the spell.
- Range: C_Spell.IsSpellInRange, then C_ActionBar.IsActionInRange on the slot holding the spell, plus CheckInteractDistance for the dead zone. Wing Clip and slows from C_UnitAuras, with UnitDebuff as the fallback.
- Options: Keybind backup section; "Countdown numbers on cooldowns", "Soft highlight when a cooldown is ready", "Range shading on every button"; range tool option "Soft pulse on the Wing Clip button".
- GitHub release notes and the CurseForge changelog come from RELEASE_NOTES.md (tools/release_notes.py writes it from Nock/Changelog.lua).
- New tests: tests/run_binds.py, tests/run_news.py.

## 3.7.1

Rare tameable beasts on the map, and Tame Beast on the pet bar.
- Rare beast pins now say **Rare spawn** or **Rare elite spawn**, the respawn range after it dies, and how many spawn spots it has. When only one can be up and the spot is random with equal weight, the tooltip gives the share per spot (for example Lupos: 16 spots, about 6% at each). The chance a rare is up right now is not in any source, so it says "unknown".
- Hover a rare's pin on the world map to mark every spawn spot and draw its patrol path. Click the pin to keep them shown; click again to clear. One pin per rare per map (at its most central spot), so the map stays clean.
- Data: spawn points, paths and rank from QuestieDB Forever; respawn times and spawn pools from CMaNGOS classic-db. Generated by tools/tame/gen_tame370.py into Nock/Data_TameSpawns.lua; nothing is estimated. 16 of the 63 rares get a per-spot share; 14 have patrol paths.
- Pet bar: new Tame Beast tile next to Call / Revive (Revive Pet when the pet is dead, Call Pet when none is out). It shows only once you know Tame Beast, with the key that casts it: Ctrl-Z from Nock's left-hand layout if that key was free, or your own key. New unbound keybind "Tame Beast (pet bar tile)". No keybind of yours is changed.
- The pet bar stays up for Tame Beast too when you have no pet.
- Field Kit rare list shows the respawn range.

## 3.7.0

New: the Dashboard, one compact panel for a corner of the screen or a second monitor.
- **Bags:** free general bag slots and how many are used (your quiver or ammo pouch is not counted). Amber at 4 free or fewer, red when full.
- **Ammo:** arrows or bullets left and about how many minutes of Auto Shot that is at your current ranged speed. Amber under 5 minutes, red when empty. Updates every second in combat.
- **Quests:** your tracked quests with objective progress ("Tough Wolf Meat 4/8"). Finished objectives turn green, finished quests say "(done)". With nothing tracked it shows the top of your quest log. Up to 5 quests and 16 lines, then "+N more".
- Matches the alert card look in Emerald and Gunsmith. Fixed row heights, square edges, nothing shifts or overlaps as numbers change.
- Off by default. Turn it on with /nock dash or Options > On screen > "Dashboard". Same section: unlock to drag, solid background (for mirroring), Small / Normal / Large (Large is the default).
- /nock dash, /nock dash unlock | lock | reset | small | normal | large | solid. /nock unlock and /nock reset positions include it. Locked, clicks pass straight through it.
- New unbound keybind "Show or hide the dashboard" in Key Bindings > AddOns > Nock. Nothing is bound for you.
- Uses the Forever quest API (C_QuestLog watches and objectives) and C_Container bag families. Settings in NockCharDB.dash, position in NockCharDB.positions.dash.
- New test: tests/run_dash.py.

## 3.6.3

- Wing Clip is a full-size tile on the bow bar, right after Q in the "it's on me" group. Root cause: with mouse buttons on but Mouse 4 holding your own bind, Nock moves Wing Clip to Shift-Z, and the bow bar only had a Mouse 4 slot, so Wing Clip got no bow tile. The bar now shows the Shift-Z tile in that place.
- Main bar tiles show the dedicated key as a second badge: Caps on Wing Clip, ` on Hunter's Mark.
- The small 3.6.2 Wing Clip tile on the extra row is gone (no duplicate; its "Caps" badge covered the icon).
- tests/run_petbar.py also checks the Wing Clip bow tile with Mouse 4 free and with Mouse 4 yours.

## 3.6.2

- Pet bar: Attack, Follow, Stay and the stances were drawn at about 40% brightness on a dark tile, so they looked missing. Commands are now full colour, off stances and skills stay clearly visible, and "on" is still the green border. Attack / Follow / Stay show the key that does the same thing (Shift-T, Ctrl-T, Alt-T from the extra row).
- Wing Clip has its own tile at the start of the extra row, showing the key that casts it (Caps Lock from the dedicated keys, otherwise Shift-Z or Mouse 4). Before, Wing Clip had a key but no tile anywhere.
- New test: tests/run_petbar.py (live, dead and missing pet; Wing Clip tile).

## 3.6.1

Pet bar fixes.
- The pet bar now has Call / Revive and Mend Pet tiles (next to Train and Feed), with the key that does the same job shown on the tile (Ctrl-G and Shift-G from the extra row, or your own key). Both are also in Key Bindings > AddOns > Nock.
- When your pet is dead or not called, the pet bar stays up with Call / Revive instead of leaving only Train and Feed. (The game gives no pet commands while the pet is dead, so Attack / Follow / Stay and pet skills come back once it is revived.)
- Call / Revive also revives a dead pet that is no longer in the world (Call Pet fails, then Revive Pet casts). Ctrl-G uses the same fix.
- The dedicated Wing Clip / Hunter's Mark keys no longer re-set their key every time key bindings update (it could loop).

## 3.6.0

Dedicated Wing Clip and Hunter's Mark keys.
- Two new entries in Key Bindings > AddOns > Nock: "Wing Clip (highest rank you know)" and "Hunter's Mark (highest rank you know)". One press casts the top rank you have learned.
- Left-hand suggestions: Caps Lock for Wing Clip (pinky, next to A) and ` (above Tab) for Hunter's Mark. Nock only uses a suggested key when that key is empty in your own bindings and you have not bound the entry yourself. It uses an override binding, so nothing is saved over your keybinds.
- Options > Extras: "Dedicated Wing Clip and Hunter's Mark keys" switch, plus a line showing which key each one is on.
- Mouse 4 Wing Clip and R Hunter's Mark from the keymap stay as they were.

## 3.5.1

Packaging: first CurseForge release via BigWigs packager; GPL-3.0 license.

## 3.5.0

Pro polish across the board: one notification system, a rebuilt Nock window, and complete hunter map pins.

**Alerts**
- One alert manager for every reminder: a single movable stack (`/nock unlock`), at most two toasts on screen (one if you prefer), critical first and the rest queued. Duplicates refresh instead of stacking; each alert has its own cooldown; toasts fade and slide in, and leave on their own (critical 4 s, warning 5 s, info 6 s).
- Clean toasts styled to match your Nock style: Emerald (dark wood, thin silver-gold trim, emerald accent) or Gunsmith (gunmetal, brass). Real spell or item icon on the left, a short title, one line of detail and a thin red / amber / emerald accent. No more all-caps shouting or walls of text.
- Critical: Feign Death resisted, Wing Clip fell off in melee, dead zone in PvP. Warning: wrong aspect in combat, no aspect, leaving town or a battleground queue popping with low supplies, unhappy pet, no pet food, enemy PvP trinket. Info: content pet, pet food too low, low supplies in town, trainer and pet trainer ranks on level up, rare tameable beast within 150 yards (new), junk sold / repaired, where to level next, entering a battleground.
- No chat spam for anything shown on screen (trainer list, vendor summary, level-up route, PvP mode). Sound only for critical alerts, and it can be turned off. Edge flashes are softer.
- Options > Alerts: size, how many at once, quiet mode (critical only), sound, edge flashes, a Test alerts button, and a switch for every category and every alert. Also `/nock alerts test | quiet | sound | size | max | list | <category> on|off | <id> on|off` and an unbound "Show test alerts" keybind.
- The Wing Clip / dead zone cue under your character is now a slim themed plate: icon, a few words and a 2 px Wing Clip timer ("Wing Clip, then step back", "Step back", "Dead zone", "Out of range"). The PvP readout is a compact themed plate too.
- Built to grow: alerts are declared in `Data_Alerts.lua` (id, category, priority, icon, title / detail templates, cooldown, contexts, level range, spec, condition) and fired with `Nock.Alerts:Fire(id, vars)`; options and slash switches are generated from the registry; styles are pluggable theme tables. See README "Adding an alert".

**Nock window**
- Rebuilt on one layout grid for every tab: header (page title, one-line subtitle, profile selector with its label), content area, a dedicated action bar row (help text left, page buttons right-aligned at one size) and tabs attached to the bottom edge. Page buttons no longer sit on the tabs, the help text no longer collides with them, and the scrollbar sits in its own lane inside the frame.
- Sizes come from the bar size (Small / Normal / Large) and the window scales itself down to fit smaller screens or large UI scales. Tabs shrink their labels or share the width evenly if they would not fit.
- My Rotation key list: labels line up on one column whatever the key badge width, and the two columns stay row-aligned. Options rows grow with their text so long labels never overlap.
- Fixed: the window sizing code never ran (it looked up the window before it existed), which is why the 3.x Large layout values were not applied.

**Map pins**
- New pin kinds, each with its own switch: bowyers and gunsmiths, quiver and ammo pouch vendors, pet food vendors (only those selling what your pet eats, or all), hunter class quest givers near your level, and flight masters (off by default). Weapon masters join the trainer pins.
- Vendor tooltips list what each vendor sells by category (arrows, bullets, quivers, ammo pouches, bows, guns, crossbows, thrown, pet food by diet, drinks) with item icons and the best item for your level, from QuestieDB vendor data. Ammo for your ranged weapon (arrows for bow / crossbow, bullets for gun) and food your pet eats are marked green. A small dot on the pin shows a second category.
- Clutter control: the minimap shows the nearest 3 of each kind (1, 3 or all in Options), folds overlapping pins into one with a count, and only trainers, stables and hunter vendors stay on the minimap rim when out of range (not pet food, quests or flight masters). City and zone maps show each other's nearby pins (a city's NPCs on its zone map), and crowded spots cluster with a combined tooltip.
- New pin icons: restart the game fully once.

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
