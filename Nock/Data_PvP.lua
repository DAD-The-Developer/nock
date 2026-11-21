--[[
  Nock 3.4.0: PvP data for the hunter tools (extend by adding rows).

  Classes: role, the sting to open with (only suggested if you know it) and
  a one-line matchup note. Buffs: enemy buffs worth a shout. Slows: debuffs
  that already slow a target (no need to Wing Clip). Trinkets: spells that
  mean "they just used their PvP escape". Guide: the PvP field notes.
  Names are enUS spell names as the client shows them.
]]

local Nock = _G.Nock
if not Nock then
  return
end

Nock.Data = Nock.Data or {}

Nock.Data.PvPClasses = {
  MAGE = { role = "caster", sting = "Viper Sting", note = "Viper Sting drains Blink and Ice Block mana. Stay at max range; Frost Nova then Blink: Concussive and keep shooting." },
  PRIEST = { role = "caster", sting = "Viper Sting", note = "Viper Sting, then Aimed Shot through the shield. Psychic Scream: break it with distance, not Feign." },
  WARLOCK = { role = "caster", sting = "Viper Sting", note = "Kill or trap the pet first if it is a Felhunter. Viper on the warlock, Scatter Shot its Fear cast." },
  DRUID = { role = "hybrid", sting = "Viper Sting", note = "Viper Sting stops heals and shapeshifts. Freezing Trap on bear or cat; they can shift out of slows." },
  SHAMAN = { role = "hybrid", sting = "Viper Sting", note = "Kill Grounding Totem with Auto Shot before Scatter or Viper. Watch for Frost Shock range." },
  PALADIN = { role = "hybrid", sting = "Viper Sting", note = "Kite forever: Viper Sting, Concussive, Wing Clip, step back. Blessing of Freedom ends slows — trap instead." },
  WARRIOR = { role = "melee", sting = "Scorpid Sting", note = "Never let them stick: Wing Clip, step back, Concussive, Frost Trap. Feign Death drops Charge targeting." },
  ROGUE = { role = "melee", sting = "Scorpid Sting", note = "Flare and Hunter's Mark for stealth. Scorpid Sting, Wing Clip, step back. Save Feign Death for Blind / Gouge." },
  HUNTER = { role = "ranged", sting = "Viper Sting", note = "Get into their dead zone or out of range. Viper Sting their mana; Scatter Shot their pet's attack." },
}

-- Enemy buffs worth calling out: name -> short advice.
Nock.Data.PvPBuffs = {
  ["Divine Shield"] = "immune — switch target or trap later",
  ["Blessing of Protection"] = "immune to physical — Viper Sting, wait it out",
  ["Ice Block"] = "immune — set a trap and wait",
  ["Blessing of Freedom"] = "slows will not stick — trap or Scatter",
  ["Evasion"] = "dodging — step back and shoot (ranged ignores it)",
  ["Sprint"] = "running — Concussive Shot",
  ["Power Word: Shield"] = "absorb — Viper or Arcane Shot through it",
  ["Barkskin"] = "less damage — Viper Sting",
  ["Nature's Swiftness"] = "instant heal coming",
  ["Berserker Rage"] = "fear immune",
  ["Will of the Forsaken"] = "fear/charm immune",
  ["Bestial Wrath"] = "enemy pet immune to CC — Feign or kite",
  ["Deterrence"] = "parrying — shoot from range",
  ["Arcane Power"] = "mage burst — break line of sight",
}

-- Debuffs that already slow a target.
Nock.Data.PvPSlows = {
  "Wing Clip", "Improved Wing Clip", "Concussive Shot", "Frost Trap Aura", "Hamstring", "Crippling Poison", "Frostbolt",
  "Cone of Cold", "Frost Shock", "Mind Flay", "Curse of Exhaustion", "Entangling Roots", "Frost Nova", "Piercing Howl",
}

-- Enemy casts that mean an escape / trinket was used.
Nock.Data.PvPTrinkets = {
  ["PvP Trinket"] = true, ["Insignia of the Alliance"] = true, ["Insignia of the Horde"] = true,
  ["Medallion of the Alliance"] = true, ["Medallion of the Horde"] = true, ["Will of the Forsaken"] = true,
  ["Escape Artist"] = true, ["Every Man for Himself"] = true, ["Perception"] = true,
}

-- Your PvP tools, shown as ready / on cooldown in the PvP readout.
Nock.Data.PvPTools = {
  { "Concussive Shot", "Conc" }, { "Scatter Shot", "Scatter" }, { "Freezing Trap", "Freeze" }, { "Frost Trap", "Frost" },
  { "Wing Clip", "Clip" }, { "Feign Death", "Feign" }, { "Intimidation", "Intim" }, { "Deterrence", "Deter" },
}

Nock.Data.PvPGuide = {
  { "Kiting", {
    "Concussive Shot, then run straight away (never backpedal) and turn to shoot when it lands.",
    "Frost Trap at your feet before they reach you; walk them through it.",
    "Stay at 20-35 yards. Line of sight around pillars beats casters.",
  } },
  { "Dead zone (inside 8 yards)", {
    "Auto Shot and Aimed Shot do nothing inside 8 yards. Nock's readout says DEAD ZONE.",
    "Wing Clip, then step back out past 8 yards. Then Concussive Shot and shoot.",
    "If Wing Clip falls off while they are still on you, Nock warns: clip again.",
  } },
  { "Trap juggling", {
    "Feign Death drops combat so you can lay a new Freezing Trap mid-fight.",
    "Scatter Shot (talent) into Freezing Trap: walk back, drop the trap, let Scatter end.",
    "Freezing Trap breaks on damage: stop Serpent Sting and pet attacks on that target.",
  } },
  { "Feign Death", {
    "Feign drops targeting on you; casters lose their spell. Nock shouts if it is resisted.",
    "Do not Feign with DoTs ticking on you if you need the drop to stick.",
  } },
  { "Aspects", {
    "Never fight in Cheetah or Pack: one hit dazes you. Nock warns loudly.",
    "Hawk for damage; Monkey vs. a rogue or warrior before Hawk matters more.",
  } },
}
