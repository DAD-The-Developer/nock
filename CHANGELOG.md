# Changelog

All notable changes to Nock from 3.0.11 onward. The addon folder's `Nock/README.txt` also has older notes.

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
