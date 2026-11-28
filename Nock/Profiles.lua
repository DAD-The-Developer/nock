--[[
  Nock profiles — one-click setups for World of Warcraft: Forever (1.60.1, interface 16001).

  A profile is a bundle of:
    * a keyboard layout (the BM or Marks layout from Nock.lua),
    * Nock macros that replace some plain spell keys (one GCD spell per press),
    * a written talent order you can learn one point at a time with a click,
    * a static field-manual page (rotation as written priority, not live advice).

  Rules Nock keeps:
    * Everything that writes binds, bars, macros or talents runs only out of combat
      (InCombatLockdown) and only from a click or slash command you type.
    * Nothing reads the fight, health, auras, cooldowns or the combat log.
    * Nothing presses keys, picks targets or picks your next shot.
    * Macros are plain Blizzard macros: each press casts at most one spell on the
      global cooldown. No /castsequence is used.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local function Print(msg)
  if Nock.Print then
    Nock.Print(msg)
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Nock|r: " .. tostring(msg))
  end
end

local function Knows(name)
  if Nock.PlayerKnows then
    return (Nock.PlayerKnows(name))
  end
  return false
end

local function Level()
  return UnitLevel("player") or 1
end

-- Talent orders ------------------------------------------------------------
-- Compact form: { talent, tree, points }. Points are spent in list order, one
-- per level from level 10. Expand() turns this into 51 numbered steps.

local function Expand(compact)
  local steps, level = {}, 10
  for _, row in ipairs(compact) do
    local name, tree, points = row[1], row[2], row[3]
    for _ = 1, points do
      steps[#steps + 1] = { level = level, name = name, tree = tree }
      level = level + 1
    end
  end
  return steps
end

Nock.ExpandTalentOrder = Expand

local MANUAL_NOTE = "Builds are copied from WoW Forever community guides as of Nov 11, 2026 (client 1.60.1). The Nov 3 and Nov 10 class changes are included. Guides disagree, and the meta will keep moving."

local AUTO_SHOT_RULES = {
  "AUTO SHOT, THE FOREVER WAY",
  "- Auto Shot has a 0.5 sec wind-up at the end of each swing. Stand still for that part. You can move during the rest of the swing.",
  "- Fire instants (Arcane Shot, Multi-Shot, stings) right after an auto shot leaves, so they never push the next one back.",
  "- Aimed Shot is a 2 sec cast. Auto Shot keeps firing in the background while you cast it.",
  "- Ranged and melee swing timers are separate, so a Raptor Strike or melee swing between shots does not reset Auto Shot.",
  "- Dead zone: melee reaches 5 yards and ranged starts at 8. Stay 8 to 35 yards out (41 with Hawk Eye).",
  "- Aimed Shot and Multi-Shot share a 6 sec cooldown. Summon Hawk shares Arcane Shot's 6 sec cooldown.",
  "- All traps share one 30 sec cooldown. They work in combat, and you can have one Fire trap and one Frost trap down at once.",
}

local PROFILES = {}
local PROFILE_ORDER = { "bmlvl", "bm60", "mmlvl", "mm60" }

PROFILES.bmlvl = {
  key = "bmlvl",
  label = "BM Leveling",
  spec = "bm",
  build = "31 / 20 / 0",
  markSendsPet = true,
  source = "Sanctum, \"Hunter Leveling Guide 1-60\", Mobalytics (updated Nov 4, 2026): mobalytics.gg/wow-forever/classes/hunter-leveling-guide-sanctum",
  why = "The single leveling path that guide uses, with no respec. It skips Summon Hawk because the Nov 3 Arcane Shot buff made Arcane Shot better than Hawk for leveling. Take Summon Hawk instead of one Frenzy point if you PvP while leveling.",
  order = Expand({
    { "Deadly Aspects", "bm", 5 },
    { "Focused Fire", "bm", 2 },
    { "Improved Revive Pet", "bm", 2 },
    { "Endurance Training", "bm", 1 },
    { "Bestial Swiftness", "bm", 1 },
    { "Pathfinding", "bm", 2 },
    { "Unleashed Fury", "bm", 5 },
    { "Ferocity", "bm", 2 },
    { "Bestial Discipline", "bm", 2 },
    { "Ferocity", "bm", 3 },
    { "Frenzy", "bm", 4 },
    { "Intimidation", "bm", 1 },
    { "Bestial Wrath", "bm", 1 },
    { "Lethal Attacks", "mm", 5 },
    { "Careful Aim", "mm", 5 },
    { "Improved Stings", "mm", 3 },
    { "Rapid Killing", "mm", 2 },
    { "Trueshot Aura", "mm", 1 },
    { "Mortal Shots", "mm", 4 },
  }),
  rotation = {
    "HOW TO PLAY: BEAST MASTERY WHILE LEVELING",
    "Written priority. You read it before the fight and decide in the fight. Nock never watches the fight.",
    "",
    "Levels 1-3: Auto Shot (1), then finish with Raptor Strike (6).",
    "Levels 4-5: add Serpent Sting (5) on mobs that will live through most of it.",
    "Levels 6-17: Hunter's Mark (R), Auto Shot, then Arcane Shot (2). Serpent Sting only if you have spare mana or the mob is tough. Raptor Strike to finish. At 8-9, before you have a pet, Concussive Shot (Q) lets you kite.",
    "Level 10: do the taming quest, then switch to Aspect of the Hawk (X). Send the pet in before you shoot, because it has to run there.",
    "Level 18+: Multi-Shot (4) on 2 or more targets. When the pet holds one mob, send it at a second one so Multi-Shot hits both.",
    "Level 20+: Aimed Shot (3) only when you won't need to move for 2 sec. For mana it ranks low while leveling.",
    "Level 40+: Bestial Wrath (Shift-G) with Rapid Fire (Shift-1) on elites and bad pulls.",
    "",
    "MANA ORDER (from the guide, best damage for the mana first)",
    "Volley at 4+ targets > Hunter's Mark on the main target > Explosive Trap at 2+ > Multi-Shot at 3 > Immolation Trap > Multi-Shot at 2 > Mongoose Bite > Serpent Sting > Arcane Shot > Raptor Strike > Aimed Shot > Multi-Shot on 1.",
    "Try never to sit at 0% or 100% mana. Your pet keeps fighting while you drink.",
    "",
    "PET",
    "Solo: Growl on autocast, Bite off. In a dungeon group: Growl off, Bite on.",
    "Use Assist or Defensive as your normal mode, and Passive in caves and dungeons.",
    "Mend Pet early, before it gets low. Feed it to keep it happy.",
  },
}

PROFILES.bm60 = {
  key = "bm60",
  label = "BM 60",
  spec = "bm",
  build = "31 / 20 / 0",
  markSendsPet = false,
  source = "WoW Forever Builds and Tools, Beast Mastery \"Raids and dungeons\" 31/20/0 with level order (updated Nov 5, 2026): wow-forever.gg/classes/hunter/beast-mastery/",
  why = "The leading endgame BM build there. It trades Pathfinding and Bestial Discipline points for Summon Hawk, a full Frenzy and Hawk Eye. Coming from BM Leveling, you respec at a trainer and then click Learn all.",
  order = Expand({
    { "Deadly Aspects", "bm", 5 },
    { "Focused Fire", "bm", 2 },
    { "Improved Revive Pet", "bm", 2 },
    { "Endurance Training", "bm", 1 },
    { "Bestial Swiftness", "bm", 1 },
    { "Unleashed Fury", "bm", 4 },
    { "Summon Hawk", "bm", 1 },
    { "Unleashed Fury", "bm", 1 },
    { "Ferocity", "bm", 3 },
    { "Intimidation", "bm", 1 },
    { "Ferocity", "bm", 2 },
    { "Bestial Discipline", "bm", 2 },
    { "Frenzy", "bm", 5 },
    { "Bestial Wrath", "bm", 1 },
    { "Lethal Attacks", "mm", 5 },
    { "Careful Aim", "mm", 5 },
    { "Hawk Eye", "mm", 3 },
    { "Rapid Killing", "mm", 2 },
    { "Trueshot Aura", "mm", 1 },
    { "Mortal Shots", "mm", 4 },
  }),
  rotation = {
    "HOW TO PLAY: BEAST MASTERY AT 60 (DUNGEONS AND RAIDS)",
    "Written priority, not live advice.",
    "",
    "BEFORE THE PULL",
    "Aspect of the Hawk (X) on, Trueshot Aura up, pet fed. Hunter's Mark (R) on the target, then send the pet with Open Fire (1).",
    "",
    "OPENER",
    "Bestial Wrath (Shift-G) and Rapid Fire (Shift-1) together, with your racial or trinket. Then Summon Hawk (2), then Aimed Shot (3).",
    "",
    "SINGLE TARGET, REPEAT",
    "1. Keep two hawks out. Recast Summon Hawk as the older one runs out, not before.",
    "2. Arcane Shot (Shift-2) on the shared Hawk/Arcane cooldown when both hawks still have time left. That's about one press in three.",
    "3. Aimed Shot (3) each time it's ready.",
    "4. Serpent Sting (5) on bosses and long fights. Skip it on trash that dies fast.",
    "5. Bestial Wrath and Rapid Fire again as soon as they're back.",
    "",
    "THREE OR MORE",
    "Mark the kill target. Multi-Shot (4) on cooldown. Explosive Trap (Ctrl-F) under the pack if your mana and threat allow it. Volley (Shift-4) while the tank or pet holds them. Keep hawks on the main target between Multi-Shots.",
    "",
    "STATS: Agility > Hit > Intellect (with Careful Aim) > Crit > Stamina > Spirit.",
    "Tip: In a group, let the tank or pet land two or three hits before you open.",
  },
}

PROFILES.mmlvl = {
  key = "mmlvl",
  label = "MM Leveling",
  spec = "marks",
  build = "7 / 31 / 13",
  markSendsPet = true,
  source = "LudiDeo, \"Marksmanship Hunter Guide (1-60)\", Mobalytics (updated Nov 11, 2026): mobalytics.gg/wow-forever/classes/marksmanship-hunter-guide-ludideo",
  why = "A complete level-by-level Marksmanship path that keeps the pet and has Sniper Shot at 40. Another option is WoW Forever Builds' 5/36/0 leveling build, which gives up Survival for Efficiency and Rapid Recuperation.",
  order = Expand({
    { "Lethal Attacks", "mm", 5 },
    { "Careful Aim", "mm", 5 },
    { "Rapid Killing", "mm", 2 },
    { "Hawk Eye", "mm", 3 },
    { "Trueshot Aura", "mm", 1 },
    { "Mortal Shots", "mm", 5 },
    { "Barrage", "mm", 3 },
    { "Rapid Recuperation", "mm", 1 },
    { "Ranged Weapon Specialization", "mm", 5 },
    { "Sniper Shot", "mm", 1 },
    { "Improved Tracking", "sv", 5 },
    { "Deadly Aspects", "bm", 5 },
    { "Focused Fire", "bm", 2 },
    { "Survivalist", "sv", 5 },
    { "Surefooted", "sv", 3 },
  }),
  rotation = {
    "HOW TO PLAY: MARKSMANSHIP WHILE LEVELING",
    "Written priority, not live advice.",
    "",
    "Levels 1-9: Hunter's Mark (R) at 6, pull with Auto Shot (1), Concussive Shot (Q) at 8, Serpent Sting (5), Arcane Shot (2) on cooldown. In melee, use Raptor Strike (6).",
    "Levels 10-18: get your pet from the trainer quest and switch to Aspect of the Hawk (X). Mark, send the pet, let it build threat for a few seconds, then Auto Shot > Serpent Sting > Arcane Shot. If something reaches you, Wing Clip (mouse button 4) and walk away.",
    "Levels 18-40, one target: Mark > pet in > Auto Shot > Aimed Shot (3) > Serpent Sting > Arcane Shot.",
    "Levels 18-40, 2+ targets: the same, but Multi-Shot (4) instead of Aimed Shot.",
    "At 25, turn on Trueshot Aura (Shift-2) and leave it up. At 26, save Rapid Fire (Shift-1) for bosses, elites and hard pulls.",
    "Levels 40+: Mark > pet in > Sniper Shot (Shift-3) while the pet runs in > Auto Shot > Aimed Shot > Serpent Sting > Arcane Shot.",
    "Big pull at 40+: pet in, drop Explosive Trap (Ctrl-F), then Auto Shot, Multi-Shot and Volley (Shift-4).",
    "Always track the creature type you're fighting (Improved Tracking adds 5%). Only Serpent Sting mobs with a lot of health.",
    "",
    "KITING: Turn and run, don't backpedal. Slow the mob (Concussive, Wing Clip or Frost Trap), get out of the dead zone, shoot while it walks back, and repeat. Feign Death (E) drops a bad pull.",
    "",
    "MANA: Let Auto Shot carry easy mobs. Rapid Recuperation keeps your regen ticking while Serpent Sting is on the target.",
  },
}

PROFILES.mm60 = {
  key = "mm60",
  label = "MM 60",
  spec = "marks",
  build = "5 / 41 / 5",
  markSendsPet = false,
  loneWolf = true,
  source = "Staedt, \"Marksmanship Hunter\" endgame ranged build 5/41/5, Mobalytics (updated Nov 6, 2026): mobalytics.gg/wow-forever/classes/marksmanship-hunter-guide-progress. WoW Forever Builds counts 5/41/5 as the most published MM build (24 of 28).",
  why = "Lone Wolf, no pet in groups. That guide published only the finished tree, so Nock picked a point order that meets each row's requirement for a respec at 60. Other options: wow-forever.gg 16/35/0, which keeps the pet and takes Sniper Shot, and foreversixty.gg's 5/33/13 Lone Wolf raid build with Sniper Shot and Surefooted.",
  order = Expand({
    { "Deadly Aspects", "bm", 5 },
    { "Lethal Attacks", "mm", 5 },
    { "Efficiency", "mm", 5 },
    { "Careful Aim", "mm", 5 },
    { "Improved Stings", "mm", 3 },
    { "Rapid Killing", "mm", 2 },
    { "Lone Wolf", "mm", 1 },
    { "Improved Arcane Shot", "mm", 5 },
    { "Trueshot Aura", "mm", 1 },
    { "Mortal Shots", "mm", 5 },
    { "Rapid Recuperation", "mm", 2 },
    { "Barrage", "mm", 2 },
    { "Ranged Weapon Specialization", "mm", 5 },
    { "Improved Tracking", "sv", 5 },
  }),
  rotation = {
    "HOW TO PLAY: MARKSMANSHIP AT 60 (LONE WOLF, RANGED)",
    "Written priority, not live advice.",
    "",
    "BEFORE THE PULL",
    "Dismiss your pet, because Lone Wolf only works with no pet out. Aspect of the Hawk (X) on. Under Falcon, Deadly Aspects procs only from melee. Trueshot Aura (Shift-2) up. Track the boss's creature type for Improved Tracking. Hunter's Mark (R) on the target before the pull, so the mana comes back.",
    "",
    "PRIORITY",
    "Keep Serpent Sting (5) up, because it also keeps Rapid Recuperation's mana going.",
    "1. Aimed Shot (3) each time it's ready.",
    "2. Arcane Shot (2) to fill.",
    "Use Multi-Shot (4) instead of Aimed Shot on packs, or when you must move and need an instant.",
    "Rapid Fire (Shift-1, also uses your trinkets) on the pull, with your racial: Blood Fury, Berserking or Elune's Light.",
    "",
    "THREAT: Time your first big shot to land just after the tank's first hit. Feign Death (E) drops threat.",
    "",
    "OPTIONAL MELEE WEAVE (advanced): ranged and melee timers are separate, so you can step in for Raptor Strike (6) between Auto Shots and cooldowns. Most of your damage is still Auto Shot, so don't lose shots doing it.",
    "",
    "STATS: Hit to cap (9% for shots), then Agility, Intellect (Careful Aim), Stamina, Spirit. Strength only if you weave.",
  },
}

Nock.Profiles = PROFILES
Nock.ProfileOrder = PROFILE_ORDER

local function ActiveProfile()
  local key = NockCharDB and NockCharDB.profile
  return key and PROFILES[key] or nil
end

Nock.ActiveProfile = ActiveProfile

local function DefaultProfileFor(spec, level)
  local active = ActiveProfile()
  if active and active.spec == spec then
    return active
  end
  local sixty = (tonumber(level) or Level()) >= 60
  if spec == "bm" then
    return sixty and PROFILES.bm60 or PROFILES.bmlvl
  end
  return sixty and PROFILES.mm60 or PROFILES.mmlvl
end

-- Macros ---------------------------------------------------------------------
-- Every macro: at most one spell on the global cooldown per press. Lines like
-- /petattack, /startattack, /stopattack, /petfollow, /stopcasting, /use <trinket>
-- and "/cast !Auto Shot" (the ! keeps it from toggling off) are the standard
-- off-GCD companions Forever's macro guides use.

local Q = "INV_Misc_QuestionMark"

local MACROS = {
  OpenFire = {
    name = "Nock:OpenFire", label = "Open Fire",
    body = "#showtooltip Auto Shot\n/petattack\n/cast !Auto Shot",
    desc = "Sends the pet and starts Auto Shot without toggling it off on a second press.",
  },
  Arcane = {
    name = "Nock:Arcane", label = "Arcane Shot", requires = "Arcane Shot",
    body = "#showtooltip Arcane Shot\n/cast Arcane Shot\n/cast !Auto Shot",
    desc = "Arcane Shot, then makes sure Auto Shot keeps running.",
  },
  Hawk = {
    name = "Nock:Hawk", label = "Summon Hawk", requires = "Summon Hawk",
    body = "#showtooltip Summon Hawk\n/cast Summon Hawk\n/cast !Auto Shot",
    desc = "Summon Hawk, which shares Arcane Shot's cooldown, and keeps Auto Shot running.",
  },
  Aimed = {
    name = "Nock:Aimed", label = "Aimed Shot", requires = "Aimed Shot",
    body = "#showtooltip Aimed Shot\n/cast Aimed Shot\n/cast !Auto Shot",
    desc = "Aimed Shot (2 sec cast, 6 sec cooldown shared with Multi-Shot) and keeps Auto Shot on.",
  },
  Multi = {
    name = "Nock:Multi", label = "Multi-Shot", requires = "Multi-Shot",
    body = "#showtooltip Multi-Shot\n/cast Multi-Shot\n/cast !Auto Shot",
    desc = "Multi-Shot and keeps Auto Shot on.",
  },
  Serpent = {
    name = "Nock:Serpent", label = "Serpent Sting", requires = "Serpent Sting",
    body = "#showtooltip Serpent Sting\n/cast Serpent Sting\n/cast !Auto Shot",
    desc = "Serpent Sting and keeps Auto Shot on.",
  },
  Sniper = {
    name = "Nock:Sniper", label = "Sniper Shot", requires = "Sniper Shot",
    body = "#showtooltip Sniper Shot\n/cast Sniper Shot\n/cast !Auto Shot",
    desc = "Sniper Shot (4 sec cast, 15 sec cooldown) and keeps Auto Shot on.",
  },
  Melee = {
    name = "Nock:Melee", label = "Raptor / Bite", requires = "Raptor Strike",
    body = "#showtooltip Raptor Strike\n/startattack\n/cast Counterattack\n/cast Mongoose Bite\n/cast Raptor Strike",
    desc = "Starts melee, uses Counterattack after a parry and Mongoose Bite after a dodge when they light up, and queues Raptor Strike (no global cooldown in Forever).",
  },
  Feign = {
    name = "Nock:Feign", label = "Feign Death", requires = "Feign Death",
    body = "#showtooltip Feign Death\n/stopcasting\n/stopattack\n/petfollow\n/cast Feign Death",
    desc = "Stops your cast and attack and calls the pet back, then Feign Death, so nothing keeps you in combat.",
  },
  Mark = {
    name = "Nock:Mark", label = "Mark + pet", requires = "Hunter's Mark",
    body = "#showtooltip Hunter's Mark\n/cast Hunter's Mark\n/petattack",
    desc = "Hunter's Mark and sends the pet. Used in the leveling profiles only.",
  },
  Pet = {
    name = "Nock:Pet", label = "Call / Revive",
    body = "#showtooltip\n/cast [@pet,dead][nopet,mod:shift] Revive Pet; [nopet] Call Pet",
    desc = "Call Pet when none is out and Revive Pet when it lies dead. If the body is gone and Call Pet fails, press Shift-Ctrl-G for Revive Pet.",
  },
  Rapid = {
    name = "Nock:Rapid", label = "Rapid Fire", requires = "Rapid Fire",
    body = "#showtooltip Rapid Fire\n/cast Rapid Fire\n/use 13\n/use 14",
    desc = "Rapid Fire plus both on-use trinkets. A trinket with no on-use effect is skipped.",
  },
  Wrath = {
    name = "Nock:Wrath", label = "Bestial Wrath", requires = "Bestial Wrath",
    body = "#showtooltip Bestial Wrath\n/petattack\n/cast Bestial Wrath",
    desc = "Sends the pet and pops Bestial Wrath.",
  },
  Intim = {
    name = "Nock:Intim", label = "Intimidation", requires = "Intimidation",
    body = "#showtooltip Intimidation\n/petattack\n/cast Intimidation",
    desc = "Sends the pet and uses Intimidation (3 sec stun, big threat).",
  },
  PetGo = {
    name = "Nock:PetGo", label = "Pet: attack",
    body = "/petattack [@mouseover,harm,nodead][]",
    desc = "The pet attacks the enemy under your cursor, or your target if the cursor is on nothing.",
  },
  PetBack = {
    name = "Nock:PetBack", label = "Pet: follow",
    body = "/petfollow",
    desc = "Calls the pet back to you.",
  },
  PetStay = {
    name = "Nock:PetStay", label = "Pet: stay",
    body = "/petstay",
    desc = "The pet stays where it is. Use it before a dungeon trap pull.",
  },
}

Nock.ProfileMacros = MACROS

-- Extra macros shown in the manual for copy/paste only (not created or bound).
local LIBRARY = {
  { "Mark, pet and Auto Shot", "#showtooltip Hunter's Mark\n/cast Hunter's Mark\n/petattack\n/cast !Auto Shot" },
  { "Aspects on one key", "#showtooltip\n/cast [mod:shift] !Aspect of the Monkey; [combat] !Aspect of the Hawk; !Aspect of the Cheetah" },
  { "Three stings on one key", "#showtooltip\n/cast [mod:shift] Viper Sting; [mod:ctrl] Scorpid Sting; Serpent Sting" },
  { "Sting on mouseover", "#showtooltip\n/cast [@mouseover,harm,nodead][] Serpent Sting" },
  { "Concussive, Shift for Wing Clip (Nock already has Q / Mouse 5 and Mouse 4)", "#showtooltip\n/cast [mod:shift] Wing Clip; Concussive Shot" },
  { "Pet attack, Shift to recall", "/petattack [nomod,@mouseover,harm,nodead][nomod]\n/petfollow [mod:shift]" },
  { "Call, revive or mend", "#showtooltip\n/cast [@pet,dead][mod:shift] Revive Pet; [nopet] Call Pet; Mend Pet" },
  { "Tracking on one key", "#showtooltip\n/cast [mod:shift] Track Hidden; [mod:ctrl] Track Beasts; Track Humanoids" },
}

local function Entry(m, slot)
  return {
    kind = "macro",
    name = m.name,
    label = m.label,
    macro = m.body,
    icon = Q,
    slot = slot,
    requires = m.requires,
    note = m.desc,
  }
end

-- Keys a profile turns into Nock macros. Everything else stays as Nock.lua's
-- spell layout (Q Concussive, F/Shift-F/Alt-F/Ctrl-F traps, G Mend, etc.).
-- No macro uses [mod:shift] on a key whose Shift version is also bound,
-- because the Shift binding would swallow that half of the macro.
function Nock.ProfileOverrides(spec)
  local p = ActiveProfile()
  if not p or p.spec ~= spec then
    return nil
  end
  local o = {}
  if spec == "bm" then
    if Knows("Summon Hawk") then
      o["2"] = Entry(MACROS.Hawk, 2)
      o["SHIFT-2"] = Entry(MACROS.Arcane)
    else
      o["2"] = Entry(MACROS.Arcane, 2)
    end
    o["SHIFT-G"] = Entry(MACROS.Wrath)
    o["ALT-G"] = Entry(MACROS.Intim)
  else
    o["2"] = Entry(MACROS.Arcane, 2)
    o["SHIFT-3"] = Entry(MACROS.Sniper)
  end
  o["3"] = Entry(MACROS.Aimed, 3)
  o["4"] = Entry(MACROS.Multi, 4)
  o["5"] = Entry(MACROS.Serpent, 5)
  o["6"] = Entry(MACROS.Melee, 6)
  o["E"] = Entry(MACROS.Feign)
  if p.markSendsPet then
    o["R"] = Entry(MACROS.Mark)
  end
  -- 2.1 pet cluster: T attack, Shift-T follow, Alt-T stay, Ctrl-G call/revive.
  o["T"] = Entry(MACROS.PetGo)
  o["SHIFT-T"] = Entry(MACROS.PetBack)
  o["ALT-T"] = Entry(MACROS.PetStay)
  o["CTRL-G"] = Entry(MACROS.Pet)
  o["SHIFT-1"] = Entry(MACROS.Rapid)
  return o
end

local MAX_CHAR_MACROS = 30

local function PreflightMacros(layout)
  local needed = 0
  for _, entry in pairs(layout) do
    if entry.kind == "macro" and GetMacroIndexByName(entry.name) == 0 then
      needed = needed + 1
    end
  end
  if needed == 0 then
    return true
  end
  local limit = _G.MAX_CHARACTER_MACROS or MAX_CHAR_MACROS
  local _, perChar = GetNumMacros()
  perChar = tonumber(perChar) or 0
  if perChar + needed > limit then
    return false, string.format(
      "Nock needs %d new character macros but you have %d of %d slots used. Delete a few in /macro, then apply again.",
      needed, perChar, limit
    )
  end
  return true
end

-- Talents (C_Traits) ---------------------------------------------------------
-- Forever keeps Classic-style trees on the modern trait system: one
-- CamelotCombat config, one tree per class, and the three tabs as trait groups.
-- PurchaseRank stages a point and CommitConfig learns it, the same calls the
-- Forever talent window's Apply Changes uses.

local function SpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok and name then
      return name
    end
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and type(info) == "table" then
      return info.name
    end
  end
  return nil
end

local function TraitsReady()
  return C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits
    and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
    and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo
end

local function TalentIndex()
  if not TraitsReady() then
    return nil, "This client has no trait talent API that Nock can read."
  end
  local configID = C_ClassTalents.GetActiveConfigID()
  if not configID then
    return nil, "No active talent setup yet. Talents open at level 10 (or 5 with the Legacy Talented node)."
  end
  local cfg = C_Traits.GetConfigInfo(configID)
  local treeID = cfg and cfg.treeIDs and cfg.treeIDs[1]
  if not treeID then
    return nil, "Could not find your talent tree."
  end
  local idx = { configID = configID, treeID = treeID, byName = {}, spellByName = {}, maxByName = {} }
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
    local node = C_Traits.GetNodeInfo(configID, nodeID)
    if node and node.ID and node.ID ~= 0 and node.entryIDs and node.entryIDs[1] then
      local entry = C_Traits.GetEntryInfo(configID, node.entryIDs[1])
      local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
      local name = def and def.overrideName
      if (not name or name == "") and def and def.spellID then
        name = SpellName(def.spellID)
      end
      if name and name ~= "" then
        local key = string.lower(name)
        idx.byName[key] = nodeID
        idx.spellByName[key] = def and def.spellID
        idx.maxByName[key] = tonumber(node.maxRanks)
      end
    end
  end
  return idx
end

local function NodeRank(idx, nodeID)
  local node = C_Traits.GetNodeInfo(idx.configID, nodeID)
  if not node then
    return 0
  end
  return tonumber(node.currentRank or node.ranksPurchased or node.activeRank) or 0
end

local function UnspentPoints(idx)
  if not (C_Traits.GetTreeCurrencyInfo and idx) then
    return nil
  end
  local ok, list = pcall(C_Traits.GetTreeCurrencyInfo, idx.configID, idx.treeID, false)
  if ok and type(list) == "table" and list[1] then
    return tonumber(list[1].quantity)
  end
  return nil
end

function Nock.UnspentTalentPoints()
  local ok, idx = pcall(TalentIndex)
  if not ok or not idx then
    return nil
  end
  return UnspentPoints(idx)
end

-- Ranks of named talents ({ "lightning reflexes", ... } lowercase) read from the trait tree, for
-- Nock.Rewards. Returns { [name] = rank } (0 when the talent isn't in the tree), or nil with no trait API.
function Nock.TalentRanks(names)
  local ok, idx = pcall(TalentIndex)
  if not ok or not idx then
    return nil
  end
  local out = {}
  for _, name in ipairs(names or {}) do
    local key = string.lower(name)
    local nodeID = idx.byName[key]
    out[key] = nodeID and NodeRank(idx, nodeID) or 0
  end
  return out
end

-- Points per tab, for Nock's spec detection (the old GetTalentTabInfo is gone).
function Nock.TraitPointsByTab()
  if not (TraitsReady() and C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetGroupCurrencyInfo) then
    return nil
  end
  local configID = C_ClassTalents.GetActiveConfigID()
  local cfg = configID and C_Traits.GetConfigInfo(configID)
  local treeID = cfg and cfg.treeIDs and cfg.treeIDs[1]
  if not treeID then
    return nil
  end
  local okG, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
  if not okG or type(groups) ~= "table" then
    return nil
  end
  local ids, names = {}, {}
  for _, g in ipairs(groups) do
    if g.groupID then
      ids[#ids + 1] = g.groupID
      names[g.groupID] = string.lower(g.displayName or "")
    end
  end
  local okC, spent = pcall(C_Traits.GetGroupCurrencyInfo, configID, ids)
  if not okC or type(spent) ~= "table" then
    return nil
  end
  local bm, mm, sv = 0, 0, 0
  for _, row in ipairs(spent) do
    local n = names[row.traitNodeGroupID] or ""
    local s = row.currencyInfos and row.currencyInfos[1] and tonumber(row.currencyInfos[1].spent) or 0
    if n:find("beast", 1, true) then
      bm = s
    elseif n:find("mark", 1, true) then
      mm = s
    elseif n:find("surv", 1, true) then
      sv = s
    end
  end
  return bm, mm, sv
end

-- Walk the order: step i for talent X is done once X's rank >= how many times
-- X has appeared up to i. Out-of-order points are fine.
local function PlanState(profile, idx, staged, base)
  local seen, ranks, missing = {}, base or {}, {}
  local done, nextStep, nextIndex = 0, nil, nil
  for i, step in ipairs(profile.order) do
    local key = string.lower(step.name)
    seen[key] = (seen[key] or 0) + 1
    local nodeID = idx and idx.byName[key]
    local rank = 0
    if nodeID then
      if ranks[key] == nil then
        ranks[key] = NodeRank(idx, nodeID)
      end
      rank = ranks[key] + ((staged and staged[key]) or 0)
    else
      missing[step.name] = true
    end
    if nodeID and rank >= seen[key] then
      done = done + 1
    elseif not nextStep then
      nextStep, nextIndex = step, i
    end
  end
  return done, nextStep, nextIndex, missing
end

-- Rows for the Talents tab: consecutive points in the same talent become one
-- row, each with a state (learned, next, available, locked, missing).
function Nock.PlanRows(profile)
  profile = profile or ActiveProfile() or PROFILES.bmlvl
  local idx, err = TalentIndex()
  local level = Level()
  local order = profile.order
  local seen, ranks, stepDone = {}, {}, {}
  local done, nextIndex = 0, nil
  for i, step in ipairs(order) do
    local key = string.lower(step.name)
    seen[key] = (seen[key] or 0) + 1
    local nodeID = idx and idx.byName[key]
    local rank = 0
    if nodeID then
      if ranks[key] == nil then
        ranks[key] = NodeRank(idx, nodeID)
      end
      rank = ranks[key]
    end
    stepDone[i] = (nodeID and rank >= seen[key]) and true or false
    if stepDone[i] then
      done = done + 1
    elseif not nextIndex and (not idx or nodeID) then
      nextIndex = i
    end
  end
  if not idx then
    nextIndex = nil
  end
  local rows, cumulative = {}, {}
  local s = 1
  while s <= #order do
    local e = s
    while e + 1 <= #order and order[e + 1].name == order[s].name do
      e = e + 1
    end
    local key = string.lower(order[s].name)
    cumulative[key] = (cumulative[key] or 0) + (e - s + 1)
    local doneHere, firstOpen = 0, nil
    for k = s, e do
      if stepDone[k] then
        doneHere = doneHere + 1
      elseif not firstOpen then
        firstOpen = k
      end
    end
    local missing = idx and not idx.byName[key] or false
    local state
    if missing then
      state = "missing"
    elseif doneHere == e - s + 1 then
      state = "learned"
    elseif nextIndex and nextIndex >= s and nextIndex <= e then
      state = "next"
    elseif order[firstOpen or s].level > level then
      state = "locked"
    else
      state = "available"
    end
    rows[#rows + 1] = {
      first = s,
      last = e,
      count = e - s + 1,
      done = doneHere,
      name = order[s].name,
      tree = order[s].tree,
      levelFrom = order[s].level,
      levelTo = order[e].level,
      rank = idx and (ranks[key] or 0) or nil,
      target = cumulative[key],
      max = idx and idx.maxByName[key] or nil,
      spellID = idx and idx.spellByName[key] or nil,
      state = state,
    }
    s = e + 1
  end
  return {
    rows = rows,
    done = done,
    total = #order,
    nextIndex = nextIndex,
    nextStep = nextIndex and order[nextIndex] or nil,
    unspent = idx and UnspentPoints(idx) or nil,
    hasTraits = idx ~= nil,
    canLearn = idx ~= nil and C_Traits.PurchaseRank ~= nil and C_Traits.CommitConfig ~= nil,
    err = err,
    level = level,
  }
end

local function CommitOrExplain(idx, count)
  local okCommit, committed = pcall(C_Traits.CommitConfig, idx.configID)
  if okCommit and committed then
    Print(string.format("Learned %d talent point%s.", count, count == 1 and "" or "s"))
    return true
  end
  Print("The point is staged but not learned. Press N to open your talents, then click Apply Changes.")
  return false
end

local function TryPurchase(idx, nodeID)
  local ok, res = pcall(C_Traits.PurchaseRank, idx.configID, nodeID)
  return ok and res
end

function Nock.LearnNextTalent(profile)
  profile = profile or ActiveProfile()
  if not profile then
    return Print("Pick a profile first.")
  end
  if InCombatLockdown() then
    return Print("Leave combat first.")
  end
  local idx, err = TalentIndex()
  if not idx then
    return Print(err)
  end
  if not C_Traits.PurchaseRank or not C_Traits.CommitConfig then
    return Print("This client doesn't let Nock learn talents. Use the talent window (N); the plan below tells you what to pick.")
  end
  local points = UnspentPoints(idx)
  if points ~= nil and points <= 0 then
    return Print("You have no unspent talent points.")
  end
  local _, step, i = PlanState(profile, idx)
  if not step then
    return Print(profile.label .. " is complete.")
  end
  local nodeID = idx.byName[string.lower(step.name)]
  if not nodeID then
    return Print("Can't find the talent \"" .. step.name .. "\" in your tree. Its name may differ in your client language. Pick it by hand in the talent window (N).")
  end
  if not TryPurchase(idx, nodeID) then
    return Print("The game would not take " .. step.name .. " yet. Its row may need more points in that tree, or it may need a talent above it. Check the talent window (N).")
  end
  Print(string.format("Step %d/51: %s.", i, step.name))
  CommitOrExplain(idx, 1)
end

function Nock.LearnAllTalents(profile)
  profile = profile or ActiveProfile()
  if not profile then
    return Print("Pick a profile first.")
  end
  if InCombatLockdown() then
    return Print("Leave combat first.")
  end
  local idx, err = TalentIndex()
  if not idx then
    return Print(err)
  end
  if not C_Traits.PurchaseRank or not C_Traits.CommitConfig then
    return Print("This client doesn't let Nock learn talents. Use the talent window (N).")
  end
  local points = UnspentPoints(idx) or 51
  -- Read every rank once before buying anything, then count our own purchases.
  -- Clients may or may not include staged points in currentRank, and this way
  -- nothing is counted twice.
  local base = {}
  for key, nodeID in pairs(idx.byName) do
    base[key] = NodeRank(idx, nodeID)
  end
  local staged, count = {}, 0
  while points > 0 do
    local _, step = PlanState(profile, idx, staged, base)
    if not step then
      break
    end
    local key = string.lower(step.name)
    local nodeID = idx.byName[key]
    if not nodeID then
      Print("Stopped: can't find \"" .. step.name .. "\" in your tree.")
      break
    end
    if not TryPurchase(idx, nodeID) then
      Print("Stopped before " .. step.name .. ": the game would not take it yet.")
      break
    end
    staged[key] = (staged[key] or 0) + 1
    count = count + 1
    points = points - 1
  end
  if count == 0 then
    return Print("Nothing to learn right now.")
  end
  CommitOrExplain(idx, count)
end

local function OpenTalentWindow()
  if InCombatLockdown() then
    return Print("Leave combat first.")
  end
  local ok = false
  if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then
    ok = pcall(PlayerSpellsUtil.ToggleClassTalentFrame)
  elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentOrSpecFrame then
    ok = pcall(PlayerSpellsUtil.ToggleClassTalentOrSpecFrame)
  end
  if not ok then
    Print("Press N to open your talents.")
  end
end

-- Text -----------------------------------------------------------------------

local function PlanLines(profile)
  local idx = TalentIndex()
  local done, step, i, missing = PlanState(profile, idx)
  local lines = {}
  local points = idx and UnspentPoints(idx)
  if idx then
    lines[#lines + 1] = string.format("Progress: %d of 51 points in this plan. Unspent points: %s.", done, points and tostring(points) or "?")
    if step then
      lines[#lines + 1] = string.format("Next: step %d (level %d) — %s.", i, step.level, step.name)
    else
      lines[#lines + 1] = "This plan is complete."
    end
  else
    lines[#lines + 1] = "Talent progress unavailable here. The full order is below."
  end
  lines[#lines + 1] = ""
  -- Group consecutive points into "10-14 Deadly Aspects x5" lines.
  local order = profile.order
  local s = 1
  while s <= #order do
    local e = s
    while e + 1 <= #order and order[e + 1].name == order[s].name do
      e = e + 1
    end
    local lv = order[s].level == order[e].level and tostring(order[s].level)
      or (order[s].level .. "-" .. order[e].level)
    local tree = order[s].tree == "bm" and "BM" or (order[s].tree == "mm" and "MM" or "SV")
    local mark = ""
    if missing[order[s].name] and idx then
      mark = "  (not found in your tree)"
    end
    lines[#lines + 1] = string.format("%-6s %s x%d  [%s]%s", lv, order[s].name, e - s + 1, tree, mark)
    s = e + 1
  end
  return lines
end

local function MacroLines(profile)
  local lines = {
    "MACROS NOCK CREATES AND BINDS (character macros, one global-cooldown spell per press)",
  }
  local layout = Nock.LayoutFor and Nock.LayoutFor(profile.spec) or {}
  local keys = {}
  for key, entry in pairs(layout) do
    if entry.kind == "macro" then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local entry = layout[key]
    lines[#lines + 1] = ""
    lines[#lines + 1] = key .. "  " .. entry.name .. " — " .. (entry.note or "")
    lines[#lines + 1] = "    " .. entry.macro:gsub("\n", "\n    ")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "MORE MACROS TO PASTE YOURSELF (/macro). Nock doesn't create these."
  for _, item in ipairs(LIBRARY) do
    lines[#lines + 1] = ""
    lines[#lines + 1] = item[1]
    lines[#lines + 1] = "    " .. item[2]:gsub("\n", "\n    ")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "About /castsequence: Forever uses the modern macro system, so /castsequence works. It moves to the next spell only when a cast succeeds, and one press still casts one spell. Nock leaves it out because a failed step stalls the whole sequence."
  return lines
end

function Nock.ProfileText(profile, page)
  profile = profile or ActiveProfile() or PROFILES.bmlvl
  page = page or "plan"
  local lines = {
    string.upper(profile.label) .. "   " .. profile.build,
    MANUAL_NOTE,
    "",
  }
  if page == "rotation" then
    for _, l in ipairs(profile.rotation) do
      lines[#lines + 1] = l
    end
    lines[#lines + 1] = ""
    for _, l in ipairs(AUTO_SHOT_RULES) do
      lines[#lines + 1] = l
    end
  elseif page == "macros" then
    for _, l in ipairs(MacroLines(profile)) do
      lines[#lines + 1] = l
    end
  else
    lines[#lines + 1] = "TALENT ORDER"
    lines[#lines + 1] = profile.why
    lines[#lines + 1] = ""
    for _, l in ipairs(PlanLines(profile)) do
      lines[#lines + 1] = l
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Source: " .. profile.source
  return table.concat(lines, "\n")
end

-- Guides.lua hooks: /nock next, level-up hints and the Field Manual tab use the
-- profile plan (or the default profile for your spec and level).
function Nock.NextTalentLine(spec, level)
  spec = spec or "marks"
  level = tonumber(level) or Level()
  if level < 10 then
    return "Talent points start at level 10. Until then, just shoot, keep your pet happy, and use Open Fire on 1."
  end
  local p = DefaultProfileFor(spec, level)
  local idx = TalentIndex()
  local _, step, i = PlanState(p, idx)
  if idx and step then
    local after = {}
    for k = i + 1, math.min(i + 3, #p.order) do
      after[#after + 1] = "L" .. p.order[k].level .. " " .. p.order[k].name
    end
    local tail = #after > 0 and (" After that: " .. table.concat(after, "; ") .. ".") or ""
    return string.format("%s: next point is %s (step %d, level %d).%s", p.label, step.name, i, step.level, tail)
  end
  if idx and not step then
    return p.label .. " is complete."
  end
  local lv = math.min(level, 60)
  local s = p.order[lv - 9]
  return string.format("%s, level %d: %s.", p.label, lv, s and s.name or "?")
end

function Nock.GuideText(spec)
  local p = DefaultProfileFor(spec or "marks")
  return Nock.ProfileText(p, "rotation") .. "\n\n" .. Nock.ProfileText(p, "plan")
end

-- Apply ----------------------------------------------------------------------

function Nock.ApplyProfile(key)
  local p = PROFILES[key]
  if not p then
    return Print("Unknown profile. Use: bmlvl, bm60, mmlvl, mm60.")
  end
  if not (Nock.IsHunter and Nock.IsHunter()) then
    return Print("This is a hunter addon.")
  end
  if InCombatLockdown() then
    return Print("Leave combat first — Nock only writes bars, binds and macros out of combat.")
  end
  local previous = NockCharDB.profile
  NockCharDB.profile = key
  local layout = Nock.LayoutFor(p.spec)
  local okMacros, why = PreflightMacros(layout)
  if not okMacros then
    NockCharDB.profile = previous
    return Print(why)
  end
  -- Make sure Restore can undo keys this profile adds after an older apply.
  local snap = NockCharDB.snapshot
  if snap and snap.keys then
    for k in pairs(layout) do
      if snap.keys[k] == nil then
        snap.keys[k] = GetBindingAction(k, true) or ""
      end
    end
  end
  local ok, text = Nock.ApplyLayout(p.spec)
  if not ok then
    NockCharDB.profile = previous
    return Print(text)
  end
  Print(p.label .. ": " .. text)
  if p.loneWolf then
    Print("Lone Wolf build: dismiss your pet in groups. Open Fire still starts Auto Shot, and the pet line does nothing.")
  end
  Print("Talents are not spent automatically. Open the Talents tab (/nock talents) and click Learn Next or Learn All.")
  if Nock.UpdateOverlay then
    Nock.UpdateOverlay()
  end
  if NockCharDB.overlay ~= false and Nock.SetOverlayShown then
    Nock.SetOverlayShown(true)
  end
  if Nock.RefreshProfilesFrame then
    Nock.RefreshProfilesFrame()
  end
end

-- Window -----------------------------------------------------------------------
-- UI.lua (1.5.0) draws the Profiles, Talents, Rotation and Macros tabs. These
-- stay as safe fallbacks in case UI.lua is missing.

Nock.MacroLibrary = LIBRARY
Nock.AutoShotRules = AUTO_SHOT_RULES
Nock.ManualNote = MANUAL_NOTE
Nock.OpenTalentWindow = OpenTalentWindow
Nock.DefaultProfileFor = DefaultProfileFor
Nock.PlayerLevel = Level

function Nock.RefreshProfilesFrame()
  if Nock.RefreshUI then
    Nock.RefreshUI()
  end
end

function Nock.OpenProfiles(key)
  if Nock.ShowPanel then
    Nock.ShowPanel("profiles")
  end
end

-- Refresh after talent changes or level ups.
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP", "SPELLS_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function()
  if C_Timer then
    C_Timer.After(0.3, Nock.RefreshProfilesFrame)
  end
end)

-- Slash: /nock profiles | /nock profile <bmlvl|bm60|mmlvl|mm60> | /nock learn | /nock learnall
local baseSlash = SlashCmdList.NOCK
local ALIASES = {
  bmlvl = "bmlvl", bmleveling = "bmlvl", bmlevel = "bmlvl",
  bm60 = "bm60",
  mmlvl = "mmlvl", mmleveling = "mmlvl", mmlevel = "mmlvl", markslvl = "mmlvl",
  mm60 = "mm60", marks60 = "mm60",
}
SlashCmdList.NOCK = function(msg)
  local m = string.lower(strtrim(msg or ""))
  local cmd, arg = m:match("^(%S+)%s*(.*)$")
  if cmd == "profiles" or cmd == "profile" then
    local key = ALIASES[(arg or ""):gsub("%s", "")]
    if cmd == "profile" and key then
      Nock.ApplyProfile(key)
    else
      Nock.OpenProfiles(key)
    end
    return
  elseif cmd == "learn" then
    return Nock.LearnNextTalent(ActiveProfile() or DefaultProfileFor(NockCharDB.spec or "marks"))
  elseif cmd == "learnall" then
    return Nock.LearnAllTalents(ActiveProfile() or DefaultProfileFor(NockCharDB.spec or "marks"))
  elseif cmd == "help" then
    baseSlash(msg)
    Print("/nock profiles — open the Profiles tab (BM Leveling, BM 60, MM Leveling, MM 60)")
    Print("/nock profile bmlvl|bm60|mmlvl|mm60 — apply that profile's keys, bars and macros")
    Print("/nock learn — learn the next talent in your profile   /nock learnall — learn every point you can")
    return
  end
  return baseSlash(msg)
end
