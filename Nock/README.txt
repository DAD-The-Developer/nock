Nock — keyboard hunter hands for WoW Forever
=============================================

A free, readable UI addon for Beast Mastery and Marksmanship hunters.
It sets a keyboard-friendly layout and teaches Forever-specific hunter
rules. It does not read the fight or tell you which shot to press next.

Install
-------
1. Close World of Warcraft: Forever if it is running.
2. Copy the Nock folder (the one that contains Nock.toc) into:

   World of Warcraft\_forever_\Interface\AddOns\Nock

   On Mac: /Applications/World of Warcraft/_forever_/Interface/AddOns/Nock

3. Start Forever, open the AddOns list at the character screen, and
   make sure Nock is enabled.
4. Log in on a Hunter and type /nock

If the game says it is out of date, enable "Load out of date AddOns"
once, then tell me the interface number from /dump select(4, GetBuildInfo()).


New in 3.13.0
Gold while you level, and rank badges. Every bar and pet tile shows the rank
it casts (R6), and Nock keeps its slots on your highest rank (/nock ranks).
Bag tooltips show vendor and Auctionator prices with a "Keep — worth selling"
tag over 1g, greens and recipes; valuable loot gets a calm toast; skinning
and coin camps near your level on the maps; session gold, gold per hour, bag
value and a 100g mount fund meter on the dashboard; profession rank
reminders; best ammo at vendors. /nock gold. Never buys, posts or sells
anything but greys.

New in 3.12.0
The best-reward pick follows your spec. Nock reads your talent points live
and blends the Beast Mastery, Marksmanship and Survival weights by points
spent (generic hunter weights with no talents), and counts Mortal Shots,
Lightning Reflexes, Survivalist and Ranged Weapon Specialization directly.
The card names the spec ("Nock pick (Marksmanship): ..."). It re-scores if
your talents or level change with the quest window open. Override with
/nock rewards spec auto | bm | mm | sv or in Options.

New in 3.11.0
Turning a quest in now shows the best reward for a hunter: a gold border and
a small "Nock pick" tag on that choice, plus a short reason in its tooltip
and under the quest window ("+5 Agility, +14% upgrade over your Hunting
Bow"). Every choice shows its upgrade over what you wear: +12%, same,
downgrade, new slot, or - when you can't use it. No upgrade at all: the one
that sells for the most. Nock only marks, it never picks for you.
/nock rewards on | off.

New in 3.10.2
New spells, new ranks, pet skills and new pets update the bar by
themselves and say so in chat, grouped after a trainer visit: "Added
Feign Death to E", "Arcane Shot upgraded to Rank 6", "Pet Rex learned Bite
(Rank 4), on pet bar slot 5", "New pet Whiskers (Cat): ...". Out of combat
only, never over a key you set yourself. /nock announce off | on.

New in 3.10.1
Rebuild really rebuilds. Click Rebuild on My Rotation (or type /nock check)
and Nock rescans your spellbook (highest rank of everything), fills newly
trained spells onto their planned empty keys, repaints the bar and prints a
short report: what is on a tile, on a key only, on nothing, and what your
trainer still has for you. /nock check feign death (any spell) shows how
Nock sees that one spell. Fixed: Feign Death had no tile when the mouse wheel
click was already yours; it now shows on E.

New in 3.10.0
Flight paths. Every flight point for your faction (and neutral ones) on
the zone maps and minimap, and the routes between them on the continent
maps. Hover for the flight master, zone, where it flies and whether you
have discovered it. /nock flights on | off.

New in 3.9.0
Quest item drop chances. A mob that drops an item your quest still needs
shows it on its tooltip (Quest: Tough Wolf Meat 4/8, drop 80%), and the
Dashboard shows the best mob under the objective. Classic loot data;
Forever may differ. Options > On screen, or /nock drops on | off.

New in 3.8.1
Clearer key wording. Nock layout: Nock's left-hand keys (e.g. Ctrl-G,
Ctrl-Z, C, Z, X, V) take priority while it's on. Your own saved keybinds
are never overwritten and come back when you switch to My own keybinds.

New in 3.8.0
Your keybinds are backed up the first time 3.8.0 loads (/nock binds,
Options > Keybind backup). "Use my own keybinds" makes Nock set no keys
and show the keys you already use. Every button reads range and
cooldowns; Wing Clip pulses softly when you should clip. /nock new shows
what changed.

New in 3.7.1
Rare beast pins say rare / rare elite, respawn time and spawn spots (with
the share per spot where the data has one). Hover a pin on the world map
to see every spot and its patrol path; click to keep it. Tame Beast is
on the pet bar next to Call / Revive.

New in 3.7.0
The Dashboard: free bag slots, ammo left (and minutes of Auto Shot) and
your tracked quests with progress, in one panel. /nock dash to show it,
/nock dash unlock to move it. Options > On screen has size and a solid
background for mirroring to a second monitor.

New in 3.6.3
Wing Clip is a full-size tile on the bow bar, right after Q, with its
key (S-Z or M4) and a second Caps badge for the dedicated key.

New in 3.6.2
Pet commands (Attack, Follow, Stay) and stances are bright and easy to
see on the pet bar, with their keys. Wing Clip has its own tile at the
start of the extra row showing its key (Caps Lock).

New in 3.6.1
Call / Revive and Mend Pet are on the pet bar, and the pet bar stays up
with Call / Revive when your pet is dead, so you can bring it back from
the bar. Pet commands return once the pet is alive.

New in 3.6.0
Dedicated Wing Clip and Hunter's Mark keys that always cast your
highest rank. Suggested: Caps Lock (Wing Clip) and ` (Hunter's Mark),
used only when those keys are empty. Set your own in Key Bindings >
AddOns > Nock; switch in Options > Extras.

New in 3.5.1
Packaging: first CurseForge release via BigWigs packager; GPL-3.0 license.

New in 3.5.0
One clean alert system for every reminder: a small movable stack with
the real spell or item icon, a short title and one line of detail,
styled to match Emerald or Gunsmith. At most two at once, critical
first; sound only for critical. Options > Alerts has size, quiet mode,
a Test alerts button and a switch for every alert (/nock alerts test).
The Nock window is rebuilt: page buttons have their own row above the
tabs, nothing overlaps at any size, and it fits smaller screens.
More hunter map pins: bowyers and gunsmiths, quiver and pouch vendors,
pet food vendors for your pet's diet, hunter quests and (optional)
flight masters. Hover a vendor to see what it sells and the best item
for your level. Restart the game fully once for the new pin icons.

New in 3.4.1
Move any Nock frame: /nock unlock outlines every movable frame
(tracker, quiver, threat meter, range and PvP readouts, alerts) so you
can drag it; /nock lock when done; /nock reset positions puts them all
back. Also Options > Hunter tools > Unlock frames, and a keybind.
The kill / XP tracker now sits at the top centre, clear of the bow bar,
moves with Shift-drag (or /nock tracker unlock | lock | reset), and
shows an estimate before your first kill instead of "?".

New in 3.4.0
Hunter tools, all on by default, each with its own switch in Options >
Hunter tools and a page section on the new Tools tab (/nock kit):
pet happiness and a Feed pet key, supply warnings when you leave town,
auto sell junk and repair, a dead zone / Wing Clip readout (Wing Clip,
then step back; timer; fall-off alert; Wing Clip key glows), rare beast
pins and your pet's missing ranks, aspect reminders, a Feign Death
resisted alert, a leveling route and field notes, a trainer reminder,
a kill / XP tracker, and PvP mode in battlegrounds and arenas (enemy
class, sting, slows, big buffs, your CC cooldowns, trinket alerts).
/nock tools lists them. At 60 they switch to endgame mode.
New keys in Key Bindings > AddOns > Nock (none bound for you).
Restart the game fully once so the new pin icon loads.

New in 3.3.1
New Emerald quiver counter art: a painted elven quiver, larger, sitting
over the coloured ring, with the ammo count in the arch between its
legs. Gunsmith keeps the ammo pouch. Restart the game fully once.

New in 3.3.0
Hunter map pins: hunter trainers, pet trainers, stable masters and
ammo vendors on your minimap and world map, for your faction, in every
major city and town. Hover a pin for the name, role and zone. The
nearest one of each kind waits on the minimap edge when it is out of
range. /nock pins turns them on or off; /nock pins trainer | pet |
stable | ammo hides one kind; /nock pins hostile also shows the other
faction. Toggles are in Options under "Maps and ammo".
Quiver counter: a quiver (or ammo pouch in Gunsmith) with your ammo
count in big numbers. Green is stocked, yellow is half, red means buy
more. Shift-drag to move it. /nock quiver turns it off;
/nock quiver unlock | lock | reset.
Restart the game fully once so the new icons load.

New in 3.2.0
The Gunsmith options window no longer shows a tan slab or a floating
title bar: the panel background is a solid dark wood, and the header
sits on the top edge with matching corners. The settings window in
both styles is larger, easier to read (16–18 pt at Large), and uses
plain toggle rows and segmented size/style buttons. The Cheat Sheet
lists every key in two columns with the full name, never cut off.
Open Nock without a slash command: a Nock button on the Escape menu,
a small movable button (left-click to open, Shift-drag to move;
/nock button reset puts it back; turn it off in Options), and the
"Open Nock" keybind in Key Bindings > AddOns > Nock.

New in 3.1.1
Gunsmith spell tiles are no longer cut off or stretched: each icon is
square, and the carved frame sits around it instead of over it. The
plaque wood is solid, and the barrel caps sit behind the buttons. The
threat meter stays up while it is unlocked, even out of combat, until
you lock it. Style, threat position, bar size and the other settings
now persist across /reload and relog. /nock save confirms this
character's UI is remembered. /nock profile save <name> and
/nock profile load <name> store a whole setup account-wide
(/nock profile list to see them).

New in 3.1.0
Two looks for the HUD: Emerald (the default bow) and Gunsmith (dwarven
rifle, from custom art). Layout, spacing and size stay the same when you
swap. Pick one in /nock settings (Style), type /nock style gun or
/nock style emerald, or bind "Switch HUD style" in Key Bindings. The
choice is saved per character and applies live; new textures need a full
game restart the first time they are installed.

The threat meter can be moved. Type /nock threat unlock (or bind
"Unlock or lock the threat meter") to show a highlighted outline and a
"Drag to move" label — the whole plaque is the handle, no fiddly
clicking. It snaps to the middle of the bar. /nock threat lock holds it
there; /nock threat reset puts it back above the bow. The position is
saved per character. It stays locked by default and will not move in a
fight (unlock waits until combat ends).

New in 3.0.15
The threat meter rows (You and your pet, with bars and percents) now
draw inside the carved plaque. A layout helper had been clearing their
anchors, which left an empty wood frame. Errors are saved and printed
once in chat. /nock threat debug labels each API return.

New in 3.0.14
The threat meter still works after a /reload in a fight. It polls every
fraction of a second while you are in combat so a missed event cannot
leave it blank, and it shows an em dash when Forever will not give a
number. Type /nock threat debug in a fight to print the raw API values.

New in 3.0.13
The threat meter is rebuilt on a consistent grid: even padding, equal-height
bars, names on the left and percents on the right, all vertically centered.
Its width matches the bow plaque. The frame is carved wood with silver-gold
trim and corner filigree, and the fill has a light gloss.

New in 3.0.12
A carved threat meter sits above the bow: one bar for you, one for your
pet, against your current target (or the pet's target if you have none).
It shows threat percent and who has aggro, in emerald when you are safe,
amber when you are close to pulling, and red if you pull off the pet.
It hides out of combat, turns on by itself, and has a toggle in /nock.

New in 3.0.11
The Hearth tile is icon-only, so the label can no longer clip to "earth".
Key letters on the extra and utility bars sit fully inside the top-left
corner of each tile, bold and outlined like the main bar. Main bow tiles
keep even spacing and the same top-left key tabs. Cooldown numbers stay
centered on the icon, in whole seconds.

New in 3.0.10
Extra hunter skills sit in carved wood bars, the same size as the utility
tiles, centered under the bow. If they cannot fit on one bar they split
into two equal bars, with no wrapping. Key letters are inside the tiles.
Rarely used skills keep their keys but hide their tiles. Cooldowns are
whole seconds (never 15.42), and the experience bar is the full Large
bow width again. The pet bar stays under the XP bar.

New in 3.0.9
Every hunter skill is on a left-hand key. No click-only flyouts. F is a
smart melee key (Mongoose Bite when it will go, otherwise Raptor Strike).
C cycles tracking, Shift-C goes back. New rows of tiles show the key
letter big and bold. Uninstalling Nock restores your own keybinds
(Nock does not write these extra keys into the game's saved binds).

New in 3.0.8
------------
Every hunter skill you know shows up on Nock's bars, with a cooldown
sweep and number. Melee abilities sit in a cluster under the utility
row and glow when the target is in melee range. Tracking is one button
with a flyout that shows the active track. Anything else you learn
goes to a More flyout instead of disappearing. The list updates when
you learn a spell, or after combat if you were fighting.

New in 3.0.7
------------
The pet bar (Train, Feed, and the happiness / loyalty strip) sits
under the experience bar instead of above the bow. The whole bar
moves up so it still fits, and the gap goes away when you have no pet.

New in 3.0.6
------------
A missing font on the experience bar no longer stops the whole bar
from loading. Every label gets a font before its text is set, and
if the experience bar or pet bar hits a problem, the bow and your
shot buttons still appear.

New in 3.0.5
------------
The experience bar is a taller, carved wood and emerald piece that
matches the rest of the bar, with a round level badge on the left
showing your level. A wavy green fill and a teal rested stretch sit
inside the frame; gold ticks mark progress, and a leaf-arrow spark
sits at the leading edge. Hover the bar for the same XP tooltip as
before, plus a small centered percent. It still hides at max level,
scales with the Bar size setting (Small / Normal / Large), and stays
taint-safe: Nock does not move Blizzard's XP, bags, or micro menu.

A Nock pet bar sits above the bow whenever you have a pet out. It
reads the pet action slots, so new skills show up on their own.
The active stance and command stay bright; autocast-on abilities
(Growl, Claw) get an emerald glow and a shine; off ones are dim
with a dull border. Right-click toggles autocast. Cooldown sweeps
and numbers work like the main bar. Train Pet (Beast Training)
opens the training window, and Feed Pet is there if you know it.
A short strip shows happiness, loyalty, level and training points
when the game provides them. Turn it off with "Nock pet bar" in
/nock. New textures need a full game restart, not just /reload.

New in 3.0.4
------------
The bow and the row under it are bigger, so the keys and countdown numbers
are easier to read. A Bar size control in /nock (Small, Normal, Large;
Large is the default) lets you pick the scale. Key badges and cooldown
numbers are big, bold and outlined.

Nock now draws its own slim experience bar under the utility row, with an
emerald fill, a lighter rested section and a hover that shows
XP: cur / max (pct%)  Rested: n. It hides at max level, and can be
turned off. Blizzard's XP bar is hidden without being moved, which was
what put a thin bar at the top of the screen in 3.0.3 and caused
"Interface action failed because of an AddOn". Bags and the menu buttons
stay where Blizzard put them.

New in 3.0.3
------------
Buttons stay their normal colour until you have a hostile target that is
out of range (then they go red). Out of mana is still blue. The XP bar sits full-width at the very bottom, under the utility row,
with its fill, rested bonus and hover text intact, and it stays there
after a reload, zoning or a level-up. The bags and menu buttons sit in
the bottom-right corner, not on top of Nock. Spell
icons fill the tiles more; the key labels stay in the corner so they do
not cover the countdown.

New in 3.0.2
------------
Hiding the default bars no longer crashes the game on login. 3.0.1 asked
the client to hide those bars again from inside their own hide path, which
overflowed the stack. Each bar is now hidden once, and that request is
never made from a hook.

New in 3.0.1
------------
The default bars really hide on WoW Forever. 3.0.0 looked for the older
MainMenuBar names; this client draws the gryphon bar, extra bars, the pet
bar and the aspect bar as MainActionBar, MultiBar*, PetActionBar and
StanceBar, and it would show them again after a hide. Those are hidden
now, and kept hidden after zoning or a fight. The XP bar, bags and menu
buttons stay usable. The bow bar sits at the bottom center, sized to the
buttons you actually have.

New in 3.0
----------
Works on first login: the bar appears, fills empty keys from your
spellbook, and leaves keys you already bound alone. No setup window and
no dragging needed.

The 2.3 bow-and-arrow bar is now your main action bar. A small row under
it shows pet controls, Aspects, traps, racials, food and the Hearthstone,
only for spells and items you actually have. Blizzard's main and multi
bars are hidden; the XP bar, bags and menu buttons are moved, not
deleted. Options has a few on/off toggles plus "Restore Blizzard bars".

Ready buttons stay bright. A button on cooldown is dimmed and shows a
big countdown. The little pause after each shot still gets a sweep, but
no number. The next shot glows. Too far away tints the icon red; not
enough mana tints it blue. Shared trap cooldowns share one timer.

Newly learned spells appear when the fight ends, with a short
"New: <spell>" toast.

If textures changed, restart the game once. After that, /reload is
enough for Lua-only updates.


New in 2.3
----------
The key bar uses Benjamin's longbow (green bowstring just above the tiles)
and arrow caps: fletching on the left, arrowhead on the right, shaft stubs
on the bar's center line. New textures are in Media\\Textures (bow.tga,
cap_fletch.tga, cap_head.tga) and need a full game restart to load;
/reload is not enough. Everything else is unchanged from 2.2.


New in 2.2
----------
Custom carved moonwood UI art (window border, bark backdrop, title plaque,
close button, key-tile frames, priority glow, opener badges and a vine
divider). New textures live in Media\\Textures and need a full game restart
to load; /reload is not enough.


New in 2.1
----------
An ergonomic WASD keymap (traps on F, pet on T and G, aspects on X and Z)
and three spells on your mouse, on by default: Mouse 4 Wing Clip, Mouse 5
Concussive Shot, wheel click Feign Death (Shift + Mouse 4 / 5: Strider Kick
/ Scatter Shot). Only empty mouse buttons are used; scrolling stays camera
zoom. On first login a window asks once: Move my keys / Not now / Keep
mouse off. Only keys that still hold Nock's own spell move. /nock keys
lists everything; "Restore my old keys" in Options undoes it.


Using Nock (short version)
--------------------------
Type /nock in chat (or pick Nock from the addon button by the minimap).
A Blizzard-style window opens on My Rotation, with Talents and More
next to it (/nock advanced shows all tabs: Profiles, Rotation, Macros,
Field Manual).

On Profiles, click BM Leveling, BM 60, MM Leveling or MM 60, check the
keyboard preview, and click Apply Profile while you are out of combat.
A keyboard card appears so you can see what each key does, and your
action buttons get small gold keycaps. As you train spells, empty
reserved keys fill in.

Talents shows the plan with what you have learned and your next point;
Learn Next and Learn All spend points only when you click them.
Type /nock next to see what talent to take at your current level.
When you ding from level 10 on, Nock also prints that next talent in chat.

My Rotation (new in 1.6, /nock myrotation) is your own guide: what to
press at your level, using the spells you know and the keys they are on
right now, with a Bind it button for anything that has no key.
/nock card shows the same thing as a small on-screen card. It is rebuilt
only out of combat.

New in 2.0.1:
- The key bar is built from your spellbook: R, 1, 2, 3 (Aimed Shot), 4, 5 (Serpent
  Sting), 6 (Raptor Strike), Q, Shift-Z and E (Feign Death). A tile shows only once
  you know the spell, so the bar grows as you level.
- Racials: Nock reads your race's abilities (WoW Forever hunter races). A damage
  racial (Elune's Light, Blood Fury, Berserking) goes on Alt-1; a defensive one
  (Stoneform, Will to Survive, War Stomp, Rapid Regeneration, Shatter Curse) on
  Alt-E. Only if the key is free: a key you use is never taken; the tile still
  casts it. They're in Hunting Notes, the opener and My Rotation too. Utility
  racials (Shadowmeld, Perception, Find Treasure...) get a tip.
- Rotation: Mark, Open Fire, Serpent Sting, then Arcane Shot.
- Cooldowns on every tile: a swipe, the time left (5, 1:20), an emerald flash when
  ready. Red = out of range, blue = not enough mana. Both can be turned off in Options.

New in 2.0 (Emerald Dream look):
- Slim key bar with your six core keys (R, 1, 2, 4, Q, Shift-Z) on moonwood under
  an ancient green-and-gold longbow. Click a tile or press its key. Unlearned
  spells stay dimmed with their level until you learn them, then light up.
- Fades to 40% out of combat; full in combat or with the mouse on it.
- Hunting Notes: hold Alt over the key bar to peek, /nock notes to pin, or bind a
  key in Key Bindings > AddOns > Nock (Options > Use Ctrl-N binds Ctrl-N only if free).
- Emerald glow with a crosshair on the top shot, moon tokens for opener numbers.
- New Options tab: key bar, glow, crosshair, opener numbers, fade, lock, badges,
  auto keep-up, talent reminder. The old "More" tab is now "Guide".
- Leveling stays automatic: new spells go on their keys out of combat with one
  line in chat. Keys you rebind yourself are never touched.
- Minimap button: left = Nock window (or Set me up if needed), right = Hunting Notes.

New in 1.9 ("brain dead" cheat sheet):
- The minimap card and the top of My Rotation are now a Cheat Sheet: up to
  6 big plain-English lines with big keycaps, only spells you know, e.g.
  "R then 1 - Mark it, then start the fight", "2 - Press every time it's
  off cooldown", "4 - 2+ mobs: press this one instead", "Q - It's running
  at me: slow it", "Shift-Z - It reached me: clip it, walk away",
  "E - Oh no: play dead". Full lists sit behind "More detail".
- Wing Clip moved from Shift-6 to Shift-Z (C stays Aspect of the Cheetah).
  Set me up / keep-up clear Shift-6 only if it still holds Nock's Wing Clip.
- The key strip tiles are real buttons (SecureActionButtonTemplate): click
  one to cast the spell or Nock macro its key casts. Tooltip shows the spell
  and "Click or press <key>". Grey (not learned) tiles do nothing. A red "!"
  marks a key bound to something else; the footer then says "Some keys
  aren't set - click Set me up" with a small Set me up button. Wing Clip's
  Shift-Z tile appears once learned. Attributes, size, position, show/hide
  and dragging only change out of combat (queued to the end of combat).
- Static only, like everything else in Nock: it never reads the fight.

New in 1.8 ("stupid simple"):
- Setup popup on login when this character isn't set up, the setup is from
  an older Nock version or another character, or Nock's keys are missing.
  One click applies the auto-picked profile (BM Leveling below 60; BM 60 or
  MM 60 at 60 by your talent points). "change" picks another. /nock setup.
- Auto keep-up: after level-ups, new spells and talent changes, Nock binds
  newly available spells/macros to their keys and empty bar slots, out of
  combat, with one chat line each. Keys you rebound yourself are never
  touched (told once). /nock keepup turns it off.
- Gold "Spend talent point" button by the minimap/card (/nock remind).
- Simple view: My Rotation, Talents and More. The gear toggles all tabs
  (/nock simple, /nock advanced). Minimap left-click = rotation card,
  right-click = window (advanced view keeps the 1.7 clicks).
- Setup state is saved per character and version, so it can't go stale
  silently.

New in 1.7: a soft gold priority glow on the buttons for your top 5
single-target spells (brightest = first) and small 1, 2, 3 opener numbers.
They are set out of combat and stay still during fights. /nock glow and
/nock numbers turn them off; style and intensity are on the Profiles tab.

Read HOWTO.txt in this folder for a dummy-style walkthrough.
