--[[
  Nock field manual — static Beast Mastery and Marksmanship talent guides.

  Written advice only. Nothing here reads the fight, compares secret values,
  or tells you which shot to press in combat.
]]

local VERSION_NOTE = "Community talent advice as of early November 2026, shortly after Forever launched. It can change. This is not an official Blizzard build."

local BM_ORDER = {
  [10] = "Endurance Training (Beast Mastery)",
  [11] = "Endurance Training (Beast Mastery)",
  [12] = "Endurance Training (Beast Mastery)",
  [13] = "Endurance Training (Beast Mastery)",
  [14] = "Endurance Training (Beast Mastery)",
  [15] = "Focused Fire (Beast Mastery)",
  [16] = "Focused Fire (Beast Mastery)",
  [17] = "Improved Aspect of the Monkey (Beast Mastery)",
  [18] = "Improved Aspect of the Monkey (Beast Mastery)",
  [19] = "Improved Aspect of the Monkey (Beast Mastery)",
  [20] = "Unleashed Fury (Beast Mastery)",
  [21] = "Unleashed Fury (Beast Mastery)",
  [22] = "Unleashed Fury (Beast Mastery)",
  [23] = "Unleashed Fury (Beast Mastery)",
  [24] = "Unleashed Fury (Beast Mastery)",
  [25] = "Bestial Swiftness (Beast Mastery)",
  [26] = "Ferocity (Beast Mastery)",
  [27] = "Ferocity (Beast Mastery)",
  [28] = "Ferocity (Beast Mastery)",
  [29] = "Ferocity (Beast Mastery)",
  [30] = "Ferocity (Beast Mastery)",
  [31] = "Intimidation (Beast Mastery)",
  [32] = "Spirit Bond (Beast Mastery)",
  [33] = "Spirit Bond (Beast Mastery)",
  [34] = "Improved Mend Pet (Beast Mastery)",
  [35] = "Frenzy (Beast Mastery)",
  [36] = "Frenzy (Beast Mastery)",
  [37] = "Frenzy (Beast Mastery)",
  [38] = "Frenzy (Beast Mastery)",
  [39] = "Frenzy (Beast Mastery)",
  [40] = "Bestial Wrath (Beast Mastery)",
  [41] = "Bestial Discipline (Beast Mastery)",
  [42] = "Bestial Discipline (Beast Mastery)",
  [43] = "Lethal Attacks (Marksmanship)",
  [44] = "Lethal Attacks (Marksmanship)",
  [45] = "Lethal Attacks (Marksmanship)",
  [46] = "Lethal Attacks (Marksmanship)",
  [47] = "Lethal Attacks (Marksmanship)",
  [48] = "Efficiency (Marksmanship)",
  [49] = "Efficiency (Marksmanship)",
  [50] = "Efficiency (Marksmanship)",
  [51] = "Efficiency (Marksmanship)",
  [52] = "Efficiency (Marksmanship)",
  [53] = "Careful Aim (Marksmanship)",
  [54] = "Careful Aim (Marksmanship)",
  [55] = "Careful Aim (Marksmanship)",
  [56] = "Careful Aim (Marksmanship)",
  [57] = "Careful Aim (Marksmanship)",
  [58] = "Improved Arcane Shot (Marksmanship)",
  [59] = "Improved Arcane Shot (Marksmanship)",
  [60] = "Improved Arcane Shot (Marksmanship)",
}

-- Path that finishes as the 20/31/0 max-damage Marksmanship build.
local MM_ORDER = {
  [10] = "Lethal Attacks (Marksmanship)",
  [11] = "Lethal Attacks (Marksmanship)",
  [12] = "Lethal Attacks (Marksmanship)",
  [13] = "Lethal Attacks (Marksmanship)",
  [14] = "Lethal Attacks (Marksmanship)",
  [15] = "Improved Stings (Marksmanship)",
  [16] = "Improved Stings (Marksmanship)",
  [17] = "Efficiency (Marksmanship)",
  [18] = "Efficiency (Marksmanship)",
  [19] = "Careful Aim (Marksmanship)",
  [20] = "Careful Aim (Marksmanship)",
  [21] = "Deadly Aspects (Beast Mastery)",
  [22] = "Careful Aim (Marksmanship)",
  [23] = "Deadly Aspects (Beast Mastery)",
  [24] = "Careful Aim (Marksmanship)",
  [25] = "Endurance Training (Beast Mastery)",
  [26] = "Careful Aim (Marksmanship)",
  [27] = "Endurance Training (Beast Mastery)",
  [28] = "Rapid Killing (Marksmanship)",
  [29] = "Endurance Training (Beast Mastery)",
  [30] = "Rapid Killing (Marksmanship)",
  [31] = "Endurance Training (Beast Mastery)",
  [32] = "Trueshot Aura (Marksmanship)",
  [33] = "Endurance Training (Beast Mastery)",
  [34] = "Mortal Shots (Marksmanship)",
  [35] = "Focused Fire (Beast Mastery)",
  [36] = "Mortal Shots (Marksmanship)",
  [37] = "Focused Fire (Beast Mastery)",
  [38] = "Mortal Shots (Marksmanship)",
  [39] = "Improved Aspect of the Monkey (Beast Mastery)",
  [40] = "Mortal Shots (Marksmanship)",
  [41] = "Bestial Swiftness (Beast Mastery)",
  [42] = "Mortal Shots (Marksmanship)",
  [43] = "Unleashed Fury (Beast Mastery)",
  [44] = "Barrage (Marksmanship)",
  [45] = "Unleashed Fury (Beast Mastery)",
  [46] = "Barrage (Marksmanship)",
  [47] = "Unleashed Fury (Beast Mastery)",
  [48] = "Barrage (Marksmanship)",
  [49] = "Unleashed Fury (Beast Mastery)",
  [50] = "Ranged Weapon Specialization (Marksmanship)",
  [51] = "Unleashed Fury (Beast Mastery)",
  [52] = "Ranged Weapon Specialization (Marksmanship)",
  [53] = "Ferocity (Beast Mastery)",
  [54] = "Ranged Weapon Specialization (Marksmanship)",
  [55] = "Ferocity (Beast Mastery)",
  [56] = "Ranged Weapon Specialization (Marksmanship)",
  [57] = "Ferocity (Beast Mastery)",
  [58] = "Ranged Weapon Specialization (Marksmanship)",
  [59] = "Ferocity (Beast Mastery)",
  [60] = "Sniper Shot (Marksmanship)",
}

local function OrderFor(spec)
  if spec == "bm" then
    return BM_ORDER
  end
  return MM_ORDER
end

local function PlayerLevel()
  return UnitLevel("player") or 1
end

function Nock.NextTalentLine(spec, level)
  spec = spec or "marks"
  level = tonumber(level) or PlayerLevel()
  if level < 10 then
    return "You do not get talent points until level 10. Until then, just shoot, keep your pet happy, and use Open Fire on 1."
  end
  if level > 60 then
    level = 60
  end
  local order = OrderFor(spec)
  local now = order[level]
  local specName = spec == "bm" and "Beast Mastery" or "Marksmanship"
  if not now then
    return "No talent note for this level."
  end
  if level == 60 then
    if spec == "bm" then
      return "Level 60 Beast Mastery: your last leveling point is " .. now .. ". For dungeon and raid damage, respec to the 31/20/0 max-damage build in this manual."
    end
    return "Level 60 Marksmanship: take " .. now .. ". That finishes the 20/31/0 max-damage build."
  end
  local upcoming = {}
  for i = level + 1, math.min(level + 3, 60) do
    upcoming[#upcoming + 1] = "L" .. i .. " " .. order[i]
  end
  local more = ""
  if #upcoming > 0 then
    more = " After that: " .. table.concat(upcoming, "; ") .. "."
  end
  return "Level " .. level .. " " .. specName .. " — spend your point on " .. now .. "." .. more
end

local function GuideBody(spec)
  local level = PlayerLevel()
  local nextLine = Nock.NextTalentLine(spec, level)
  if spec == "bm" then
    return table.concat({
      "BEAST MASTERY FIELD MANUAL",
      VERSION_NOTE,
      "",
      "RIGHT NOW",
      nextLine,
      "",
      "WHAT THIS SPEC IS",
      "Your pet does a lot of the work. The pet tanks, you shoot. Hunters usually level fastest this way. Pets in Forever scale with your gear, so a better bow also makes your pet hit harder.",
      "",
      "LEVELING BUILD  33 Beast Mastery / 18 Marksmanship / 0 Survival",
      "This is the easy, fast leveling path. Take these points in this order.",
      "10-14  Endurance Training x5  — your pet survives the early game.",
      "15-16  Focused Fire x2  — you and your pet both deal a little more damage.",
      "17-19  Improved Aspect of the Monkey x3  — extra dodge for you, and your pet gets some of it.",
      "20-24  Unleashed Fury x5  — big pet and hawk damage.",
      "25     Bestial Swiftness  — a faster pet.",
      "26-30  Ferocity x5  — more pet and hawk crits.",
      "31     Intimidation  — pet stun and a hard crit. Generates a lot of threat.",
      "32-33  Spirit Bond x2  — you and your pet heal a little between pulls, so you sit less.",
      "34     Improved Mend Pet x1  — cheaper mend, sometimes cleanses the pet.",
      "35-39  Frenzy x5  — after a pet crit, the pet swings faster.",
      "40     Bestial Wrath  — your pet goes berserk. Pair it with Rapid Fire later.",
      "41-42  Bestial Discipline x2  — faster pet focus, and some of your mana still regen while you cast.",
      "43-47  Lethal Attacks x5  — 5% crit for you.",
      "48-52  Efficiency x5  — cheaper shots, so you drink less.",
      "53-57  Careful Aim x5  — your Intellect turns into Attack Power.",
      "58-60  Improved Arcane Shot x3  — a bit more Arcane Shot. Does not change Summon Hawk's cooldown.",
      "",
      "MAX DAMAGE AT 60  — RESPEC TO 31 / 20 / 0",
      "When you hit 60 and want dungeon or raid damage, pay for a respec and take this instead of staying 33/18/0.",
      "Beast Mastery (31): Deadly Aspects 5, Endurance Training 3, Focused Fire 2, Bestial Swiftness 1, Unleashed Fury 5, Ferocity 5, Summon Hawk 1, Intimidation 1, Bestial Discipline 2, Frenzy 5, Bestial Wrath 1.",
      "Marksmanship (20): Lethal Attacks 5, Efficiency 3, Careful Aim 5, Rapid Killing 2, Trueshot Aura 1, Mortal Shots 4.",
      "If another hunter already has Trueshot Aura for the group, put that point into the 5th rank of Mortal Shots instead.",
      "Some guides prefer a few points of Improved Tracking in Survival instead of the last Mortal Shots ranks. Both are used; Improved Tracking only helps while you are tracking the creature type you are fighting.",
      "",
      "HOW YOU PLAY (READ THIS, THEN YOU DECIDE IN THE FIGHT)",
      "Send the pet first. Use Open Fire (1) to start Auto Shot and send the pet. Keep the pet fed and happy — a happy pet does more damage. Mend it when it gets hurt.",
      "On one enemy, Aimed Shot (3) is your heavy shot once you learn it at 20. On a pack, use Multi-Shot (4) instead. They share a cooldown, so you pick one.",
      "If you have Summon Hawk: Hawk, Hawk, then Arcane Shot. They share a cooldown.",
      "Stay 8 to 35 yards away. Inside 8 yards you are in the dead zone — Raptor Strike, Wing Clip, and step out.",
      "Fox, Wolf, and Cat are strong early pet families. Upgrade your weapon; the pet gets stronger with you.",
      "",
      "Sources: WoW Forever Builder Beast Mastery leveling 33/18/0 (updated Nov 4, 2026); 31/20/0 raid shape from Forever class guides (ForeverSpec, WoW Forever DB, community PvE writeups, early Nov 2026); Wowhead BM talent notes (updated Nov 7, 2026).",
    }, "\n")
  end

  return table.concat({
    "MARKSMANSHIP FIELD MANUAL",
    VERSION_NOTE,
    "",
    "RIGHT NOW",
    nextLine,
    "",
    "WHAT THIS SPEC IS",
    "You are the shooter. Marksmanship is the highest ranged damage once you have talents and a slow bow or gun. Hunters usually level faster as Beast Mastery, but you can level as Marks if you want to practice this spec the whole way.",
    "",
    "LEVELING INTO MAX DAMAGE  20 Beast Mastery / 31 Marksmanship / 0 Survival",
    "Follow this order and you finish at 60 with the max-damage Marks build. You get Sniper Shot with your last point.",
    "10-14  Lethal Attacks x5  — 5% crit.",
    "15-16  Improved Stings x2  — stronger Serpent Sting.",
    "17-18  Efficiency x2  — cheaper shots.",
    "19-20  Careful Aim  (keep ranking this through the 20s)  — Intellect becomes Attack Power.",
    "Then mix in Beast Mastery pet points with the rest of Marks, like this:",
    "21, 23           Deadly Aspects  — while Hawk is up, Auto Shot can proc extra attack speed.",
    "22, 24, 26       Careful Aim (finish 5/5).",
    "25, 27, 29, 31, 33  Endurance Training 5  — a tougher pet.",
    "28, 30           Rapid Killing  — shorter Rapid Fire, and a stronger next shot after a kill.",
    "32               Trueshot Aura  — ranged attack power for your party or raid.",
    "34, 36, 38, 40, 42  Mortal Shots 5  — much bigger ranged crits.",
    "35, 37           Focused Fire  — you and your pet deal more while the pet is out.",
    "39               Improved Aspect of the Monkey x1  — just enough to keep moving down the Beast Mastery tree.",
    "41               Bestial Swiftness.",
    "43, 45, 47, 49, 51  Unleashed Fury 5  — pet and hawk damage.",
    "44, 46, 48       Barrage 3  — Multi-Shot, Aimed Shot, and Volley hit harder.",
    "50, 52, 54, 56, 58  Ranged Weapon Specialization 5  — all ranged damage up.",
    "53, 55, 57, 59   Ferocity 4  — more pet and hawk crit.",
    "60               Sniper Shot  — your capstone. Long cast, long cooldown. A setup shot, not a weave filler.",
    "",
    "FINISHED 60 BUILD  20 / 31 / 0",
    "Beast Mastery (20): Deadly Aspects 2, Endurance Training 5, Focused Fire 2, Improved Aspect of the Monkey 1, Bestial Swiftness 1, Unleashed Fury 5, Ferocity 4.",
    "Marksmanship (31): Lethal Attacks 5, Improved Stings 2, Efficiency 2, Careful Aim 5, Rapid Killing 2, Trueshot Aura 1, Mortal Shots 5, Barrage 3, Ranged Weapon Specialization 5, Sniper Shot 1.",
    "",
    "PETLESS OPTION",
    "The Lone Wolf talent gives you 20% more damage with no pet out. Some Marks guides go that way and pick Deadly Aspects plus Improved Tracking instead of pet talents. Lone Wolf does not stack with Focused Fire. Try it if you would rather not manage a pet in dungeons.",
    "",
    "STATS AND WEAPON",
    "Agility first, then Hit up to about 9%, then Crit, Ranged Attack Power, Intellect, Stamina. Use a slow bow or gun — Aimed Shot and Sniper Shot hit harder with a slow weapon.",
    "",
    "HOW YOU PLAY (READ THIS, THEN YOU DECIDE IN THE FIGHT)",
    "Keep Hunter's Mark on the target and Trueshot Aura up. On a long fight, apply Serpent Sting.",
    "When you have Sniper Shot, it is your big setup button (long cast). Aimed Shot is your heavy single-target shot. Multi-Shot is for packs. They share cooldowns with each other in the ways the spell notes describe, so you pick; you do not mash everything.",
    "Arcane Shot fills empty windows. Do not clip Auto Shot — let it fire between your casts. Stay 8 to 35 yards out.",
    "",
    "Sources: WoW Forever Builder Marksmanship endgame PvE 20/31/0 (updated Nov 4, 2026); Wowhead Marks talent notes (updated Nov 4, 2026).",
  }, "\n")
end

function Nock.PrintNextTalent(spec)
  spec = spec or (NockCharDB and NockCharDB.spec) or "marks"
  if Nock.DetectSpec and (not NockCharDB or not NockCharDB.spec) then
    spec = Nock.DetectSpec()
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Nock|r: " .. Nock.NextTalentLine(spec, PlayerLevel()))
end

function Nock.OnLevelUp(newLevel)
  if NockCharDB and NockCharDB.notes == false then
    return
  end
  local spec = (NockCharDB and NockCharDB.spec) or "marks"
  if Nock.DetectSpec and (not NockCharDB or not NockCharDB.spec) then
    spec = select(1, Nock.DetectSpec())
  end
  local level = tonumber(newLevel) or PlayerLevel()
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Nock|r: " .. Nock.NextTalentLine(spec, level))
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Nock|r: Type |cfff0e2b6/nock guide|r to read the full talent path.")
end

function Nock.GuideText(spec)
  return GuideBody(spec or "marks")
end

function Nock.OpenGuide(spec)
  if Nock.ShowPanel then
    Nock.ShowPanel("guide", spec)
    return
  end
end
