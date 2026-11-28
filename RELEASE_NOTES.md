## Nock 3.11.0 (2026-11-27)

Quest turn-ins show the best reward for a hunter, and how big an upgrade each one is.

### New

- Best reward for a hunter. When you turn a quest in, the best choice gets a gold border and a small Nock pick tag. A short reason is in its tooltip and under the quest window, for example: +5 Agility, +14% upgrade over your Hunting Bow.
- Every choice shows how much of an upgrade it is over what you wear in that slot: +12%, same, downgrade, new slot (nothing worn there yet), or - when a hunter can't use it. The same shows in the quest preview and the quest log.
- No upgrade in the list? Nock marks the reward that sells for the most: No upgrade, best to sell (1g 20s).
- /nock rewards on | off, or Options > Best quest reward for a hunter. Nock only marks; it never picks a reward or turns the quest in for you.

### Improved

- Scores like a hunter: Agility first, then attack power, crit and hit, then Stamina, Intellect, Spirit and Strength. Bows, guns and crossbows count their DPS heavily. Rings and trinkets replace the weaker of your two, and a two-hander is weighed against both hands.
- Plate, shields, maces, wands, other classes' gear, mail before level 40 and anything above your level are never picked. Items the game hasn't loaded yet are requested and checked again by themselves.

