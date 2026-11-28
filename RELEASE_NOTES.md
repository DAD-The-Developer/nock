## Nock 3.12.0 (2026-11-27)

The best-reward pick now follows your spec and your talents, live.

### New

- Spec-aware reward picks. Nock reads your talent points and blends the Beast Mastery, Marksmanship and Survival weights by how many points are in each tree. With no talents yet it uses the generic hunter weights. The card and tooltip name the spec: Nock pick (Marksmanship): Sharpshooter Vest.
- Key talents count directly: Mortal Shots makes crit worth more, Lightning Reflexes makes Agility worth more, Survivalist Stamina, Ranged Weapon Specialization your bow or gun.
- Override the spec in Options (Reward spec: Auto, BM, MM, SV) or with /nock rewards spec auto | bm | mm | sv. /nock rewards shows the spec and weights in use.

### Improved

- If you change talents, level up or the talent setup changes while a quest reward window is open, the tags, border and card are scored again right away.
- Marksmanship counts ranged attack power, crit and ranged DPS higher. Survival counts crit, Stamina and Strength higher. Beast Mastery counts Stamina, Intellect and mana higher (your pet's uptime).

