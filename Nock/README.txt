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
