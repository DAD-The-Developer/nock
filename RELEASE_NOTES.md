## Nock 3.10.1 (2026-11-27)

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

