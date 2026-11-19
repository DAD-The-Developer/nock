# Nock 2.1 keymap proposal (design only, nothing changed or installed)

For a WoW Forever 1.60.1 hunter, BM and MM, levels 1 to 60. Left hand on WASD
(pinky on Shift/Ctrl, thumb on Space/Alt), mouse in the right hand.
Pictures: `keymap-2.1.png` (keyboard + mouse) and `mockup-2.1-mouse.png` (key bar badges, Hunting Notes,
migration popup). Data source: `keymap/keymap.py`.

**Revised 13 Nov, 9:51 PM CST (Benjamin):** Wing Clip on Shift-Z felt wrong, and he wants to use his mouse
(2 side buttons + clickable wheel). Mouse bindings are now **on by default** (Options checkbox to turn them off):
Mouse 4 = Wing Clip, Mouse 5 = Concussive Shot, wheel click = Feign Death, Shift-Mouse 4 = Strider Kick,
Shift-Mouse 5 = Scatter Shot. Shift-Z is now empty. Q stays Concussive and E stays Feign Death.

## Forever facts this is built on (checked 13 Nov 2026)

Sources: wowforeverbuilder.com hunter spellbook (client 1.60.1.70753), talentsforever / warcraftmaps racials.

- **Disengage exists in Forever** (level 20, ranks 34 and 48), but it is *not* a leap. It is a melee-range
  threat drop that also stops auto-attack. So it is a group defensive (Ctrl-E), not a kiting key. Nothing here invents a leap.
- **No Aspect of the Viper and no Kill Command.** The mana aspect Nock 2.0.1 puts on Z falls back to Monkey.
- **Aspect of the Beast is changed in Forever**: untrackable plus melee attack power (30). Aspect of the Wild at 46.
- **Talent-only**: Summon Hawk (25), Trueshot Aura (25), Intimidation (30), Bestial Wrath (40), Sniper Shot (40),
  Deterrence (20), Counterattack (25), Strider Kick (30), Scatter Shot (30). Keys for these stay empty until you have them.
- **New in Forever**: Strider Kick (melee kick + 30% speed for 3 sec), Lacerate (30, melee bleed), Enchanted Flare (32).
- **Feign Death** at 30, 30 sec cooldown. **Rapid Fire** at 26, 5 min.
- **Traps**: Freezing (20) and Frost (28) are both Frost traps; Immolation (16) and Explosive (34) are both Fire traps.
  Only one trap of each school can be out at once, and each has a 30 sec cooldown. That is why the F key is split by
  school: bare and Shift = Frost, Alt and Ctrl = Fire.
  **Combat placement:** in Classic, traps needed you out of combat, so the trick was Feign Death, then trap.
  Forever marks the traps as changed and Nock's notes say Immolation works in combat. **Check in your client:** if a trap says
  you're in combat, use Feign Death (E), then the trap.

## Principles

1. **Most-pressed keys closest.** 1-5, Q, E, R, F, T, G carry everything you press every fight. Rare things (tracking,
   Eagle Eye, Beast Lore, Tame) sit on modifiers and the far keys H and C.
2. **Kite on W, not A/D.** You kite by running forward on W and steering with the mouse. That leaves the ring finger
   free for Q (Concussive) and 1/2, and the index for R, F, T, G, 4 and 5. Jump shot: W, Space (thumb),
   flick the mouse 180°, press Q or 2 (ring finger), flick back. Every instant shot you need for it is under the ring finger.
3. **One key = one family**, with Shift/Alt/Ctrl as layers. 5 = stings, F = traps, T and G = pet, X = aspects,
   E = "oh no", Q = "stop it coming", 1 + modifier = big cooldowns.
4. **Shift is the easy modifier** (pinky stays on it while running), so it gets the kiting and cooldown variants:
   Shift-F Frost Trap, Shift-X Cheetah, Shift-1 Rapid Fire, Shift-Mouse 4/5.
5. **Alt is the thumb modifier**: racials (Alt-1 burst, Alt-E defense, kept from 2.0.1) and the utility shots (Alt-2/3/4).
6. **Ctrl is the stretch modifier** (pinky slides down): things you press calmly. Ctrl-F Explosive Trap,
   Ctrl-G Call/Revive, Ctrl-T Feed, Ctrl-X Pack, Ctrl-E Disengage. Ctrl-1..0 stays Blizzard's pet bar.
7. **Don't fight Blizzard's defaults that matter**: Tab, Space, B, C, V, M, N, P, Ctrl-R and Ctrl-1..0 keep their default
   jobs. Nock 2.0.1 took C (Cheetah) and V (Feed Pet); 2.1 gives them back.
8. **Never take a key you set yourself.** Same rule as now: Nock only moves a key that still holds exactly what Nock put
   there, and asks once with a clear "here's what moves" list.
9. **The mouse thumb takes the "it's on me" buttons.** Wing Clip, Concussive and Feign Death are exactly the presses
   you need while every left-hand finger is busy moving. A side button costs no finger at all.

## Mouse (on by default)

| Button | WoW binding name | Ability | Unlock |
| --- | --- | --- | --- |
| Mouse 4 (side, back) | `BUTTON4` | Wing Clip | 12 |
| Mouse 5 (side, front) | `BUTTON5` | Concussive Shot (Q too) | 8 |
| Wheel click | `BUTTON3` | Feign Death (E too) | 30 |
| Shift + Mouse 4 | `SHIFT-BUTTON4` | Strider Kick (Survival talent) | 30 |
| Shift + Mouse 5 | `SHIFT-BUTTON5` | Scatter Shot | 30 |
| Left / right click, wheel scroll | `BUTTON1`, `BUTTON2`, `MOUSEWHEELUP/DOWN` | **never touched** (targeting, camera, zoom) | |

Rules:
- **Only empty buttons.** Before binding, Nock reads what the button does now (`GetBindingAction(button, true)`). If it holds
  anything, a Blizzard default or something of his, Nock leaves it and says so once. Blizzard ships BUTTON3 unbound; BUTTON4 and
  BUTTON5 are normally unbound too, but some clients and mouse software use them, so Nock checks instead of assuming.
- **Not learned yet = not bound yet.** Like keyboard keys, a mouse button is bound by auto keep-up the moment the spell is
  in the spellbook (Feign Death at 30, Strider Kick / Scatter Shot only if he has them), out of combat, one chat line.
- **Off switch:** Options > "Mouse buttons for Wing Clip, Concussive and Feign Death". Turning it off clears only the mouse
  buttons that still hold Nock's spell. Restore Keys covers them too.
- **Wheel-click caution:** a hard scroll can click the wheel. Feign Death has a 30 sec cooldown and drops your target's
  attention, so a stray click mid-fight hurts. The Options tooltip says this, and the popup offers "Keep mouse off".

## Full keymap

Unlock = trainer level (talent where noted). "Now" = what Nock 2.0.1 has on that key today.

| Key | Ability | Group | Unlock | Why here | Now (2.0.1) |
| --- | --- | --- | --- | --- | --- |
| `1` | Open Fire (Auto Shot + pet attack) | Damage | 1 | The pull. Never toggles Auto Shot off on a double press. Every fight starts here. | same |
| `Shift-1` | Rapid Fire (+ on-use trinkets) | Damage | 26 | Big cooldowns live on 1 + modifier: 'start the fight harder'. | same |
| `Alt-1` | Damage racial (Elune's Light / Blood Fury / Berserking) | Damage | 1 | Pressed with Rapid Fire at the start of a tough fight. Thumb on Alt, ring on 1. | same (2.0.1) |
| `2` | Arcane Shot (BM 60: Summon Hawk) | Damage | 6 (Hawk 25) | Most-pressed instant. Ring finger: reachable mid-run and in a jump shot. | same |
| `Shift-2` | Arcane Shot when Hawk is on 2 / Trueshot Aura (MM) | Damage | 25 | Keeps Arcane one modifier away when Hawk takes 2. | same |
| `Alt-2` | Distracting Shot | Utility | 12 | Taunt-style threat shot: pull a mob off a healer or set up a trap pull. | new |
| `3` | Aimed Shot | Damage | 20 | MM's main hit, BM's 'mana is high' shot. Stand still: you're not running when you press 3. | same |
| `Shift-3` | Sniper Shot (MM) | Damage | 40 (talent) | Setup shot while the pet runs in. BM: Bestial Wrath moves to the pet key (Shift-G). | BM: was Bestial Wrath |
| `Alt-3` | Tranquilizing Shot | Utility | 60 | Rare, boss frenzy only. Far from the fingers on purpose. | was Shift-G |
| `4` | Multi-Shot | Damage | 18 | Packs. Same 6 sec cooldown as Aimed, so it sits next to it. | same |
| `Shift-4` | Volley | Damage | 40 | Ground-target AoE next to Multi-Shot. | same |
| `Alt-4` | Flare | Utility | 32 | Ground-target like Volley. Stealthed rogues/druids. | was Shift-T |
| `5` | Serpent Sting | Damage | 4 | Once per mob, right after the first auto shot. All stings on 5. | same |
| `Shift-5` | Scorpid Sting | Damage | 22 | Same key family: only one sting per target, so they belong together. | new |
| `Alt-5` | Viper Sting | Damage | 36 | Casters: drains mana. Still the sting key. | was Shift-R |
| `6` | Melee: Counterattack > Mongoose Bite > Raptor Strike | Melee | 1 (MB 16, CA 25 talent) | One macro: the best melee hit that's lit. You're standing still in melee, so the reach is fine. | Counterattack added |
| `Shift-6` | Lacerate | Melee | 30 | Forever's melee bleed. Survival / melee builds only. | new |
| `Q` | Concussive Shot | Kiting | 8 | Ring finger, free while you run forward with W. The #1 kiting key. | same |
| `Shift-Q` | Scatter Shot (keyboard copy of Shift-Mouse5) | Defensive | 30 | 4 sec disorient at 15 yd: 'stop it coming' next to the slow. Also an interrupt. | was Pet attack |
| `Alt-Q` | Strider Kick (keyboard copy of Shift-Mouse4) | Kiting | 30 (Survival talent) | Melee kick + 30% speed for 3 sec: hit and run out of the dead zone. | was Pet follow |
| `Ctrl-Q` | Scare Beast | Defensive | 14 | Beast CC (adds, druids in forms, enemy pets). | was Shift-V |
| `E` | Feign Death (stops cast/attack, recalls pet) | Defensive | 30 | The 'oh no' key. Middle finger: you stop moving to press it anyway. | same |
| `Shift-E` | Deterrence | Defensive | 20 (Survival talent) | +25% dodge/parry 10 sec when melee is on you. | was Intimidation |
| `Alt-E` | Defensive racial (Stoneform / Will to Survive / War Stomp...) | Defensive | 1 | Same 'oh no' key family. | same (2.0.1) |
| `Ctrl-E` | Disengage (threat drop, not a leap) | Defensive | 20 | Forever's Disengage only lowers threat. Group button, so it's a defensive, not a kite. | was ` |
| `R` | Hunter's Mark (+ send pet while leveling) | Damage | 6 | First press of every fight, before 1. Index finger. | same |
| `Shift-R` | Beast Lore | Utility | 24 | Read a beast before taming it. Out of combat. | was Viper Sting |
| `Alt-R` | Eagle Eye | Utility | 14 | Scouting, out of combat. (Ctrl-R stays Blizzard's framerate.) | new |
| `T` | Pet: attack (mouseover, else target) | Pet | 10 | Index stretch, usable mid-run: point at a mob, press T. Second mob in packs. | was Call/Revive |
| `Shift-T` | Pet: follow (come back) | Pet | 10 | Recall before you feign or reset. | was Flare |
| `Alt-T` | Pet: stay | Pet | 10 | Park the pet before a trap pull. | new |
| `Ctrl-T` | Feed Pet | Pet | 10 | Out of combat. Frees V for Blizzard's nameplates. | was V |
| `F` | Freezing Trap | Trap | 20 | Frost school on F / Shift-F. Index finger. | same |
| `Shift-F` | Frost Trap | Trap | 28 | Kiting field. Shift-F is easy while W is held. | was Alt-F |
| `Alt-F` | Immolation Trap | Trap | 16 | Fire school on Alt-F / Ctrl-F. | was Shift-F |
| `Ctrl-F` | Explosive Trap | Trap | 34 | Packs. Same Fire slot as Immolation. | was Shift-X |
| `G` | Mend Pet | Pet | 12 | Most-used pet spell gets the bare key. | same |
| `Shift-G` | Bestial Wrath | Pet | 40 (BM talent) | Pet cooldown on the pet key. Pair it with Shift-1. | was Tranquilizing Shot |
| `Alt-G` | Intimidation | Pet | 30 (BM talent) | Pet stun + threat to peel a mob off you, or to interrupt a cast. | was Shift-E |
| `Ctrl-G` | Call Pet / Revive Pet (one macro) | Pet | 10 | Call if none, Revive if dead. Out of combat mostly. | was T |
| `H` | Eyes of the Beast | Utility | 14 | Rare scouting. Index stretch. | new |
| `Shift-H` | Tame Beast | Utility | 10 | Rare. | new |
| `Shift-Z` | (nothing: freed) | Utility | - | Benjamin: Shift-Z felt wrong. Wing Clip moves to Mouse4. Nock clears Shift-Z only if it still holds Nock's Wing Clip. | was Wing Clip |
| `Z` | Aspect of the Wild | Aspect | 46 | Raid nature resistance. Z stays near the other aspects. | was mana aspect |
| `Ctrl-Z` | Aspect of the Beast | Aspect | 30 | Forever: untrackable + melee AP. Rare. | new |
| `X` | Aspect of the Hawk (Monkey until 10) | Aspect | 10 | Your fight aspect. One key family for all aspects. | same |
| `Shift-X` | Aspect of the Cheetah | Aspect | 20 | Travel/escape. Shift + X with W held. You get dazed if hit. | was C |
| `Alt-X` | Aspect of the Monkey | Aspect | 4 | Stuck in melee: +dodge. | was Z |
| `Ctrl-X` | Aspect of the Pack | Aspect | 40 | Group travel. Turn it off before pulls. | was Shift-C |
| `Shift-C` | Track Beasts | Utility | 1 | Plain C stays your character pane. | was Aspect of the Pack |
| `Alt-C` | Track Humanoids | Utility | 10 |  | new |
| `Ctrl-C` | Track Hidden | Utility | 24 | Other tracking from the minimap tracking button. | new |
| `Ctrl-1..7` | Pet bar: Growl, Cower and family skills (Blizzard default) | Pet | 1 | Kept: right-click for autocast. Growl on solo, off in groups. | Blizzard default |
| `Ctrl-8 / 9 / 0` | Pet: Aggressive / Defensive / Passive (Blizzard default) | Pet | 10 | Kept. Defensive for leveling, Passive for trap pulls. | Blizzard default |
| `Mouse4 (BUTTON4)` | Wing Clip | Kiting | 12 | Thumb on the side button: clip it without lifting a finger off WASD, then walk out. Replaces Shift-Z. | new (was Shift-Z) |
| `Mouse5 (BUTTON5)` | Concussive Shot (Q too) | Kiting | 8 | Slow it while every left-hand finger is busy running or strafing. | new |
| `Middle click (BUTTON3)` | Feign Death (E too) | Defensive | 30 | Panic button with no finger move. Click the wheel, don't scroll it. | new |
| `Shift-Mouse4` | Strider Kick (if you have it) | Kiting | 30 (Survival talent) | Pinky already on Shift while kiting: kick and sprint out. | new |
| `Shift-Mouse5` | Scatter Shot (if you have it) | Defensive | 30 | 'Stop it coming', the big brother of Mouse5. | new |
| `Mouse wheel` | Never bound: camera zoom | Utility | - | Scrolling stays Blizzard's camera zoom. | untouched |

Untouched Blizzard keys: W A S D, Space (jump), Tab (target), B (bags), C (character), V (nameplates), M, N, P, L,
Ctrl-R, and Ctrl-1..0 (pet bar).

## How your hands flow

**Solo leveling, one mob.** Out of combat: X (Hawk). Then R (Mark, sends the pet), 1 (Open Fire), 5 (Serpent Sting)
right after the first auto shot, 2 (Arcane) every time it's ready. MM: 3 (Aimed) is the main hit; BM: 3 only when
mana is high. G (Mend Pet) early if the pet drops below half. Fingers barely move: index R, ring 1 and 2, index 5.

**Two or three mobs.** R Mark the one you kill first. Point at the second mob and press T (pet attacks it). 4 (Multi-Shot)
each time it's ready instead of 3. Alt-F (Immolation) or, from 34, Ctrl-F (Explosive) where they're standing. One extra,
before the pull: F (Freezing Trap) at your feet, then let it walk in. Bad pack: Shift-F (Frost Trap) and back up through it.

**A runner or a caster.** Runner: Mouse 5 or Q (Concussive) as soon as it turns, then 2 to finish. Caster: Shift-Mouse 5 or Shift-Q (Scatter Shot,
from 30) or Alt-G (Intimidation, BM) to stop the cast, T to put the pet on it, Alt-5 (Viper Sting, 36) to drain its mana.

**A melee mob reaches you.** Mouse 4 (Wing Clip), walk out on W to 8 yards, turn, Mouse 5 or Q (Concussive), back to 2 and 1.
If it's nearly dead: 6 (the melee macro fires Counterattack, then Mongoose Bite, then Raptor Strike, whichever is lit).
Survival: Shift-Mouse 4 (Strider Kick) kicks and speeds you out. Lots of melee on you: Shift-E (Deterrence) or Alt-X (Monkey).

**A pull gone wrong.** Wheel click or E (Feign Death: stops your cast, stops attacking, recalls the pet). Wait for the mobs to walk
off. Then F (Freezing Trap) under you and pick one fight, or Shift-X (Cheetah) and leave. Cheetah dazes you if you're hit,
so only once nothing is on you. Not hunter-only: Alt-E (your defensive racial) first if you're about to die.

**Dungeon trap pull.** Out of combat: Alt-T (pet stay) or Ctrl-0 (Passive), then F (Freezing Trap) between you and the
group. Mark the trap target (R), pull it with Alt-2 (Distracting Shot) or 2, step back so it runs over the trap. Once it's frozen,
put the pet back on Defensive (Ctrl-9) and help the tank with 1 and 4. If the trap breaks and it comes for the healer:
E (Feign) to drop threat, then F again as soon as the cooldown is up. Ctrl-E (Disengage) drops some threat in melee.

## What changes from Nock 2.0.1

Stays: 1, 2, Shift-2, 3, 4, Shift-4, 5, 6, Q, E, R, F, G, X, Shift-1, Alt-1, Alt-E.

| Key | 2.0.1 | 2.1 proposal |
| --- | --- | --- |
| Shift-Z | Wing Clip | (empty: cleared only if it still holds Nock's Wing Clip) |
| Mouse 4 | (none) | Wing Clip |
| Mouse 5 | (none) | Concussive Shot (Q stays) |
| Wheel click | (none) | Feign Death (E stays) |
| Shift-Mouse 4 / 5 | (none) | Strider Kick / Scatter Shot |
| T | Call / Revive Pet | Pet attack (mouseover) |
| Shift-Q | Pet attack (mouseover) | Scatter Shot |
| Alt-Q | Pet follow | Strider Kick |
| Shift-T | Flare | Pet follow |
| Alt-T | (none) | Pet stay |
| Ctrl-T | (none) | Feed Pet |
| Ctrl-G | (none) | Call / Revive Pet |
| V | Feed Pet | Blizzard nameplates again |
| C | Aspect of the Cheetah | Blizzard character pane again |
| Shift-X | Explosive Trap | Aspect of the Cheetah |
| Ctrl-F | (none) | Explosive Trap |
| Shift-F | Immolation Trap | Frost Trap |
| Alt-F | Frost Trap | Immolation Trap |
| Z | Mana aspect (Monkey) | Aspect of the Wild |
| Alt-X | (none) | Aspect of the Monkey |
| Shift-C | Aspect of the Pack | Track Beasts |
| Ctrl-X | (none) | Aspect of the Pack |
| Shift-E | Intimidation (BM) | Deterrence |
| Alt-G | (none) | Intimidation |
| Shift-3 | Bestial Wrath (BM) / Sniper (MM) | Sniper (MM) only |
| Shift-G | Tranquilizing Shot | Bestial Wrath |
| Alt-3 | (none) | Tranquilizing Shot |
| Shift-R | Viper Sting | Beast Lore |
| Alt-5 | (none) | Viper Sting |
| Alt-4 | (none) | Flare |
| Shift-V | Scare Beast | (freed, Blizzard friendly nameplates) |
| Ctrl-Q | (none) | Scare Beast |
| ` | Disengage | (freed) |
| Ctrl-E | (none) | Disengage |
| 6 (macro) | Mongoose > Raptor | Counterattack > Mongoose > Raptor |
| New | | Alt-2 Distracting, Shift-5 Scorpid, Shift-6 Lacerate, Alt-R Eagle Eye, Alt-C/Ctrl-C tracking, Ctrl-Z Aspect of the Beast, H Eyes of the Beast, Shift-H Tame Beast |

## Key bar, Hunting Notes and popup (see mockup-2.1-mouse.png)

**Key bar tiles.** The key badge stays top-left; a mouse badge (M4, M5, MMB) sits bottom-left in kiting teal.
- Concussive: `Q` + `M5`. Feign Death: `E` + `MMB`. Wing Clip has no keyboard key now, so its top badge is `M4`.
- Strider Kick / Scatter Shot don't get tiles (they live on Shift-mouse and Shift/Alt-Q); their tooltips name the button.
- If a mouse button isn't Nock's (his, or a default), no mouse badge is drawn and the tooltip says which key works.
- Bar order: R 1 2 3 4 5 6 | Q, M4 (Wing Clip), E, racials. Same "only what you've learned" rule as 2.0.1.

**Hunting Notes lines** (keys come from the live bindings, so they show whatever actually works):
- "It's running at me: slow it" → `Q / M5`, hint "Concussive Shot. Q or mouse button 5."
- "It reached me: clip it, walk away" → `M4`, hint "Wing Clip on mouse button 4. Walk out past 8 yards."
- "Oh no: play dead" (30+) → `E / MMB`, hint "Feign Death. E or click the mouse wheel."
- The badge widget needs a second short label per key (`Q / M5`), and M-badges in teal like the bar.

**Migration popup (shown once, out of combat, when 2.1 first loads):**

> **Nock 2.1: new keys**
> Nock moves a few keys to make kiting easier and puts three spells on your mouse. Only keys that still hold Nock's own
> spell move. Keys you set yourself stay yours.
> - Mouse button 4: Wing Clip (was Shift-Z, which is now empty)
> - Mouse button 5: Concussive Shot (Q still works)
> - Wheel click: Feign Death (E still works)
> - Shift + mouse 4 / 5: Strider Kick / Scatter Shot, once you have them
> - *(only if it applies)* Mouse button 5 already does something of yours, so Nock left it alone.
> - Also moving: T Pet attack, Ctrl-G Call/Revive, Shift-X Cheetah, C and V back to Blizzard, traps on F (full list: /nock keys)
>
> Mouse scrolling stays camera zoom. Turn the mouse keys off any time in Options.
> **[Move my keys]  [Not now]  [Keep mouse off]**   ("Restore my old keys" in Options undoes all of it.)

"Keep mouse off" applies the keyboard moves and sets the mouse option off. "Not now" changes nothing and the red "!"
stays until he chooses.

## Built in Nock 2.1.0 (13 Nov 2026)

- Shipped as designed. One addition: if Mouse 4 already does something of yours (or a Blizzard default), or you turn
  the mouse off, Wing Clip stays on (or goes back to) Shift-Z, so it always has a key.
- A mouse button you clear yourself after Nock bound it counts as yours (left empty) until you switch the mouse
  option off and on again.
- Tracking, Eyes of the Beast, Tame Beast, Lacerate, Strider Kick, Deterrence and the rest get their key only once
  your spellbook has them.

## Design notes

- **One binding per key and modifier**, not `[mod:shift]` macros. Nock's "never take your key" check and Restore Keys work
  per key, and a `[mod:]` macro silently breaks the moment you bind Shift-X to anything.
- **Migration:** a key moves only if it still holds exactly what Nock put there. Anything you rebound stays yours. One
  popup lists every move, with Restore Keys as the undo. It bumps Nock's layout version, so this is the one time 2.1 asks.
- Shift-1..6 are Blizzard's bar-page keys by default; Nock already uses Shift-1..4 and this adds Shift-5 and Shift-6.
  Anyone who pages bars with Shift-number loses that, so the popup says it.
- Ctrl-8/9/0 (pet stances) are Blizzard's defaults: Nock doesn't bind them, it just teaches them.
- Mouse buttons are on by default with an Options checkbox; binding names BUTTON3/4/5 and SHIFT-BUTTON4/5, never
  BUTTON1/2 or MOUSEWHEEL*. Shift-Z joins Nock's retired-keys list (cleared only if it still holds Nock's Wing Clip).
- The key bar would show R 1 2 3 4 5 6 | Q, M4, E plus the racials, with mouse badges.
