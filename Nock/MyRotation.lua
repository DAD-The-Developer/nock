--[[
  Nock 1.6.0 — My Rotation (1.9.0: cheat sheet on top)

  Builds a plain-language guide for YOUR hunter right now: the active
  profile, your level, the spells you actually know and the keys they are
  bound to. It is generated out of combat only, from the spellbook, your
  keybindings and your action bars. It never looks at a target, health,
  auras, cooldowns, mana or the combat log, and it never presses anything.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local function Print(msg)
  if Nock.Print then
    Nock.Print(msg)
  end
end

-- Trainer levels, WoW Forever 1.60.1. Sources: conquestcapped.com "WoW
-- Forever Hunter Abilities by Level" (updated Nov 7, 2026), cross-checked
-- with wowfdb.com and wowcalc.net for the shots (Serpent 4, Arcane 6,
-- Multi-Shot 18, Aimed Shot 20 baseline). Talent spells (Summon Hawk,
-- Trueshot Aura, Intimidation, Bestial Wrath, Sniper Shot, Lone Wolf) use
-- the level the active profile's talent order buys them.
local TRAINER = {
  { 1, "Raptor Strike" }, { 4, "Serpent Sting" }, { 4, "Aspect of the Monkey" },
  { 6, "Arcane Shot" }, { 6, "Hunter's Mark" }, { 8, "Concussive Shot" },
  { 10, "Aspect of the Hawk" }, { 10, "Call Pet" }, { 10, "Feed Pet" }, { 10, "Revive Pet" }, { 10, "Beast Training" },
  { 12, "Mend Pet" }, { 12, "Wing Clip" }, { 14, "Scare Beast" },
  { 16, "Immolation Trap" }, { 16, "Mongoose Bite" }, { 18, "Multi-Shot" },
  { 20, "Aimed Shot" }, { 20, "Freezing Trap" }, { 20, "Disengage" }, { 20, "Aspect of the Cheetah" },
  { 22, "Scorpid Sting" }, { 26, "Rapid Fire" }, { 28, "Frost Trap" }, { 30, "Feign Death" },
  { 32, "Flare" }, { 34, "Explosive Trap" }, { 36, "Viper Sting" },
  { 40, "Volley" }, { 40, "Aspect of the Pack" }, { 60, "Tranquilizing Shot" },
}
local TRAINER_LEVEL = {}
for _, t in ipairs(TRAINER) do
  TRAINER_LEVEL[t[2]] = t[1]
end
Nock.TrainerLevel = TRAINER_LEVEL

local TALENT_SPELLS = { "Summon Hawk", "Intimidation", "Bestial Wrath", "Trueshot Aura", "Sniper Shot", "Lone Wolf", "Scatter Shot" }

-- What changes in your rotation when you get each one ("Coming soon" and the
-- level-up chat line). Only spells that change what you press.
local NEWS = {
  ["Serpent Sting"] = "a damage-over-time shot. Use it on mobs that will live a while",
  ["Arcane Shot"] = "an instant shot. Fire it on cooldown, right after an auto shot",
  ["Hunter's Mark"] = "mark every target first; it adds ranged attack power",
  ["Concussive Shot"] = "a slow. Use it to kite anything that runs at you",
  ["Aspect of the Hawk"] = "turn it on for every fight. Do the pet taming quest too",
  ["Call Pet"] = "your pet. Send it in before you shoot",
  ["Mend Pet"] = "heal your pet early, before it gets low",
  ["Wing Clip"] = "a melee slow: clip, then walk back out to 8 yards",
  ["Immolation Trap"] = "a Fire trap that works in combat. Drop it where mobs walk",
  ["Mongoose Bite"] = "lights up after you dodge; your melee key uses it",
  ["Multi-Shot"] = "use it on 2+ mobs instead of Aimed Shot",
  ["Aimed Shot"] = "your big hit: 2 sec cast, stand still, use it each time it's ready",
  ["Freezing Trap"] = "freezes one add. Feign Death, then let it walk in",
  ["Disengage"] = "dumps threat in melee (not a leap in Forever)",
  ["Rapid Fire"] = "your haste cooldown. Save it for elites, bosses and bad pulls",
  ["Frost Trap"] = "a slow field. Kite mobs through it",
  ["Feign Death"] = "drops all threat. Your 'oh no' button",
  ["Explosive Trap"] = "Fire trap for packs: drop it under 2+ mobs",
  ["Viper Sting"] = "drains mana from casters",
  ["Volley"] = "4+ mobs held by the pet or tank. No cooldown, costs a lot of mana",
  ["Summon Hawk"] = "keep two hawks out; it shares Arcane Shot's cooldown",
  ["Intimidation"] = "pet stun and big threat. Use it to peel a mob off you",
  ["Bestial Wrath"] = "your big pet cooldown. Pop it with Rapid Fire on elites",
  ["Trueshot Aura"] = "turn it on and leave it up",
  ["Sniper Shot"] = "a 4 sec setup shot. Cast it while the pet runs in",
  ["Lone Wolf"] = "20% more damage with no pet out. Dismiss the pet in groups",
}

-- "Coming soon" lists only what adds damage or changes the damage rotation.
local DAMAGE = {
  ["Serpent Sting"] = true, ["Arcane Shot"] = true, ["Hunter's Mark"] = true, ["Aspect of the Hawk"] = true,
  ["Call Pet"] = true, ["Immolation Trap"] = true, ["Mongoose Bite"] = true, ["Multi-Shot"] = true,
  ["Aimed Shot"] = true, ["Rapid Fire"] = true, ["Explosive Trap"] = true, ["Volley"] = true,
  ["Summon Hawk"] = true, ["Bestial Wrath"] = true, ["Trueshot Aura"] = true, ["Sniper Shot"] = true, ["Lone Wolf"] = true,
}

-- Helpers ------------------------------------------------------------------------

local function Known(name)
  if name == "Auto Shot" then
    return true
  end
  if name == "PET_ATTACK" or name == "PET_FOLLOW" then
    return (Nock.PlayerKnows and Nock.PlayerKnows("Call Pet")) and true or false
  end
  return (Nock.PlayerKnows and Nock.PlayerKnows(name)) and true or false
end

local function LayoutForProfile(p)
  if not (p and Nock.LayoutFor) then
    return {}
  end
  local saved = NockCharDB.profile
  NockCharDB.profile = p.key
  local ok, layout = pcall(Nock.LayoutFor, p.spec)
  NockCharDB.profile = saved
  return ok and layout or {}
end

local ALIASES = {
  ["Call Pet"] = { "Call / Revive", "Call Pet" },
  ["PET_ATTACK"] = { "Pet: attack", "Pet: attack MO" },
  ["PET_FOLLOW"] = { "Pet: follow" },
  ["Raptor Strike"] = { "Raptor / Bite" },
}

local DISPLAY = { PET_ATTACK = "Pet attack", PET_FOLLOW = "Pet follow", ["Auto Shot"] = "Open Fire (Auto Shot)" }

local function EntryCasts(e)
  if e.kind == "macro" then
    return e.requires or (Nock.MacroSpell and Nock.MacroSpell(e))
  end
  return e.name
end

-- The Nock key that is meant to hold this action, and its layout entry.
local function FindEntry(layout, name)
  local rank = {}
  for i, k in ipairs(Nock.KeycapOrder or {}) do
    rank[k] = i
  end
  local bestKey, best
  for key, e in pairs(layout) do
    local hit = EntryCasts(e) == name
    if not hit and ALIASES[name] then
      for _, a in ipairs(ALIASES[name]) do
        if e.label == a then
          hit = true
        end
      end
    end
    if hit and (not bestKey or (rank[key] or 99) < (rank[bestKey] or 99)) then
      bestKey, best = key, e
    end
  end
  return bestKey, best
end

-- Binding names Blizzard uses for each action bar (page -> slots).
local function SlotCommand(slot)
  if slot >= 1 and slot <= 12 then
    return "ACTIONBUTTON" .. slot
  elseif slot >= 61 and slot <= 72 then
    return "MULTIACTIONBAR1BUTTON" .. (slot - 60)
  elseif slot >= 49 and slot <= 60 then
    return "MULTIACTIONBAR2BUTTON" .. (slot - 48)
  elseif slot >= 25 and slot <= 36 then
    return "MULTIACTIONBAR3BUTTON" .. (slot - 24)
  elseif slot >= 37 and slot <= 48 then
    return "MULTIACTIONBAR4BUTTON" .. (slot - 36)
  elseif slot >= 145 and slot <= 156 then
    return "MULTIACTIONBAR5BUTTON" .. (slot - 144)
  elseif slot >= 157 and slot <= 168 then
    return "MULTIACTIONBAR6BUTTON" .. (slot - 156)
  elseif slot >= 169 and slot <= 180 then
    return "MULTIACTIONBAR7BUTTON" .. (slot - 168)
  end
  return nil
end
Nock.SlotBindingCommand = SlotCommand

-- 2.1: a keyboard key first, a mouse button second. Returns key, mouseAlt.
local function BoundKey(command)
  if not (GetBindingKey and command) then
    return nil
  end
  local res = { pcall(GetBindingKey, command) }
  if not res[1] then
    return nil
  end
  local board, mouse
  for i = 2, #res do
    local k = res[i]
    if type(k) == "string" and k ~= "" then
      if k:find("BUTTON", 1, true) then
        mouse = mouse or k
      else
        board = board or k
      end
    end
  end
  if board then
    return board, mouse
  end
  return mouse, nil
end
Nock.BoundKey = BoundKey

-- How a key is said in a hint: "Q", "Shift-Q", "mouse button 5".
local SPOKEN_MOUSE = {
  BUTTON3 = "click the mouse wheel", BUTTON4 = "mouse button 4", BUTTON5 = "mouse button 5",
  ["SHIFT-BUTTON4"] = "Shift + mouse button 4", ["SHIFT-BUTTON5"] = "Shift + mouse button 5",
}
local function Spoken(key)
  if not key then
    return "?"
  end
  if SPOKEN_MOUSE[key] then
    return SPOKEN_MOUSE[key]
  end
  return (key:gsub("SHIFT%-", "Shift-"):gsub("ALT%-", "Alt-"):gsub("CTRL%-", "Ctrl-"))
end
Nock.SpokenKey = Spoken

-- Which spell or macro sits on each action slot (out of combat).
local function ScanBars()
  local index = {}
  if not GetActionInfo then
    return index
  end
  local slots = {}
  for s = 1, 72 do
    slots[#slots + 1] = s
  end
  for s = 145, 180 do
    slots[#slots + 1] = s
  end
  for _, slot in ipairs(slots) do
    local ok, kind, id = pcall(GetActionInfo, slot)
    if ok and kind and id then
      local name
      if kind == "spell" then
        name = Nock.SpellData and Nock.SpellData(id)
      elseif kind == "macro" and GetMacroInfo then
        name = GetMacroInfo(id)
      end
      if name then
        index[name] = index[name] or {}
        table.insert(index[name], slot)
      end
    end
  end
  return index
end

local function RankText(name)
  if not (Nock.PlayerKnows and C_Spell and C_Spell.GetSpellSubtext) then
    return nil
  end
  local known, spellID = Nock.PlayerKnows(name)
  if not (known and spellID) then
    return nil
  end
  local ok, sub = pcall(C_Spell.GetSpellSubtext, spellID)
  if ok and type(sub) == "string" and sub:find("%d") then
    return sub
  end
  return nil
end

-- Where this action is on your keyboard right now:
--   how = "nock" (the Nock key), "spell" (another key bound to the spell),
--   "bar" (a key on the action bar slot that holds it), or nil (not bound).
local function Resolve(name, layout, bars)
  local layoutKey, entry = FindEntry(layout, name)
  local r = {
    action = name,
    label = DISPLAY[name] or (entry and entry.kind == "macro" and Nock.EntryLabel and Nock.EntryLabel(entry)) or name,
    layoutKey = layoutKey,
    entry = entry,
    rank = RankText(name),
    icon = Nock.IconFor and Nock.IconFor(entry or name),
  }
  if entry then
    local cmd = entry.kind == "macro" and ("MACRO " .. entry.name) or ("SPELL " .. entry.name)
    local k, alt = BoundKey(cmd)
    if k then
      r.key, r.alt, r.how = k, alt, "nock"
      -- 2.1: Q / M5. The mouse copy of a macro key casts the same macro.
      return r
    end
  end
  if name ~= "PET_ATTACK" and name ~= "PET_FOLLOW" then
    local k, alt = BoundKey("SPELL " .. name)
    if k then
      r.key, r.alt, r.how = k, alt, "spell"
      return r
    end
  end
  local candidates = {}
  for _, slot in ipairs(bars[name] or {}) do
    candidates[#candidates + 1] = slot
  end
  if entry and entry.kind == "macro" then
    for _, slot in ipairs(bars[entry.name] or {}) do
      candidates[#candidates + 1] = slot
    end
  end
  for _, slot in ipairs(candidates) do
    local k = BoundKey(SlotCommand(slot))
    if k then
      r.key, r.how, r.slot = k, "bar", slot
      return r
    end
  end
  r.onBar = candidates[1]
  r.unbound = true
  return r
end

-- Builder --------------------------------------------------------------------------

local function TalentLevel(p, name)
  for _, step in ipairs(p.order or {}) do
    if step.name == name then
      return step.level
    end
  end
  return nil
end

function Nock.BuildMyRotation(p, level)
  p = p or (Nock.ActiveProfile and Nock.ActiveProfile()) or (Nock.Profiles and Nock.Profiles.bmlvl)
  level = tonumber(level) or (Nock.PlayerLevel and Nock.PlayerLevel()) or 1
  local layout = LayoutForProfile(p)
  local bars = ScanBars()
  local bm = p.spec == "bm"
  local lone = p.loneWolf and true or false
  -- 2.0.1: your race's buttons, from the spellbook (General tab).
  local rac = (Nock.Racials and Nock.Racials()) or { utility = {}, all = {} }
  local racialKnown = {}
  for _, r in ipairs(rac.all or {}) do
    racialKnown[r.name] = true
  end
  local function K(name)
    return Known(name) or racialKnown[name] or false
  end
  local burst, defense = rac.burst, rac.defense
  local petOK = level >= 10 and not lone and K("Call Pet")
  local data = { profile = p, level = level, spec = p.spec, unbound = 0, sections = {} }
  local seenUnbound = {}
  data.racials = rac

  local function item(list, name, why)
    if not K(name) then
      return
    end
    local r = Resolve(name, layout, bars)
    r.why = why
    if r.unbound and not seenUnbound[name] then
      seenUnbound[name] = true
      data.unbound = data.unbound + 1
    end
    list[#list + 1] = r
  end
  local function note(list, text)
    list[#list + 1] = { text = text }
  end
  local function section(key, title, sub, list, numbered)
    data.sections[#data.sections + 1] = { key = key, title = title, sub = sub, items = list, numbered = numbered }
  end

  -- Opener -------------------------------------------------------------------
  local op = {}
  if K("Aspect of the Hawk") then
    item(op, "Aspect of the Hawk", "On before the pull.")
  end
  local auraNote = false
  if K("Trueshot Aura") then
    -- Only in the opener when it has (or can get) a key; BM layouts don't
    -- plan one, so it becomes a tip instead.
    local r = Resolve("Trueshot Aura", layout, bars)
    if r.key or r.layoutKey then
      item(op, "Trueshot Aura", "Turn it on and leave it up.")
    else
      auraNote = true
    end
  end
  if K("Hunter's Mark") then
    local why = "Mark the target first."
    local _, e = FindEntry(layout, "Hunter's Mark")
    if e and e.kind == "macro" and petOK then
      why = "Marks the target and sends your pet."
    end
    item(op, "Hunter's Mark", why)
  end
  if not bm and not lone and K("Sniper Shot") then
    item(op, "Sniper Shot", "4 sec cast while the pet runs in.")
  end
  if burst then
    item(op, burst.name, "Your racial: press it at the start of a tough fight.")
  end
  item(op, "Auto Shot", petOK and "Sends the pet and starts Auto Shot." or "Starts Auto Shot.")
  if bm then
    if p.key == "bm60" and K("Bestial Wrath") then
      item(op, "Bestial Wrath", "Bosses and elites only.")
    end
    if p.key == "bm60" and K("Rapid Fire") then
      item(op, "Rapid Fire", "Same time as Bestial Wrath.")
    end
    if p.key == "bm60" and K("Summon Hawk") then
      item(op, "Summon Hawk", "Then a second hawk.")
    else
      -- 2.0.1: Mark, Serpent Sting, then Arcane.
      if K("Serpent Sting") then
        item(op, "Serpent Sting", "Sting it right after the first auto shot.")
      end
      if K("Arcane Shot") then
        item(op, "Arcane Shot", "Then Arcane Shot.")
      end
    end
    if p.key == "bm60" and K("Aimed Shot") then
      item(op, "Aimed Shot", "Stand still for the 2 sec cast.")
    end
  else
    if lone and K("Rapid Fire") then
      item(op, "Rapid Fire", "On the pull. Also uses your trinkets.")
    end
    if K("Aimed Shot") then
      item(op, "Aimed Shot", "Your big hit. Stand still 2 sec.")
    end
    if K("Serpent Sting") then
      item(op, "Serpent Sting", lone and "Keep it up all fight." or "Only if the mob will live a while.")
    end
    if not K("Aimed Shot") and K("Arcane Shot") then
      item(op, "Arcane Shot", "Instant, right after an auto shot.")
    end
  end
  if level < 6 and K("Raptor Strike") then
    item(op, "Raptor Strike", "Finish it if it reaches you.")
  end
  while #op > 6 do
    table.remove(op)
  end
  data.opener = op

  -- Single target ------------------------------------------------------------
  local st = {}
  item(st, "Auto Shot", "Keep it going all fight. It's most of your damage, so don't stop it to do something else.")
  if bm then
    if p.key ~= "bmlvl" and K("Summon Hawk") then
      item(st, "Summon Hawk", "Keep two hawks out. Recast as the older one runs out, not before.")
    end
    if p.key == "bmlvl" and K("Serpent Sting") then
      item(st, "Serpent Sting", "Keep it on every mob that lives more than a few shots. Put it back when it falls off.")
    end
    if K("Arcane Shot") then
      item(st, "Arcane Shot", (p.key ~= "bmlvl" and K("Summon Hawk")) and "On the shared Hawk/Arcane cooldown when both hawks still have time left."
        or "Each time it's ready, right after an auto shot leaves.")
    end
    if K("Aimed Shot") then
      item(st, "Aimed Shot", p.key == "bmlvl" and "Only when you can stand still and your mana is high. It's expensive while leveling."
        or "Each time it's ready. Stand still for the 2 sec cast.")
    end
    if p.key ~= "bmlvl" and K("Serpent Sting") then
      item(st, "Serpent Sting", "On mobs that will live 10+ seconds: elites, bosses, tough mobs.")
    end
    if K("Bestial Wrath") then
      item(st, "Bestial Wrath", "Elites, bosses and bad pulls, together with Rapid Fire.")
    end
    if K("Rapid Fire") then
      item(st, "Rapid Fire", "Save it for elites, bosses and hard pulls.")
    end
  else
    if K("Aimed Shot") then
      item(st, "Aimed Shot", "Each time it's ready. Stand still for the 2 sec cast.")
    end
    if K("Serpent Sting") then
      item(st, "Serpent Sting", lone and "Keep it up. It also keeps Rapid Recuperation's mana coming."
        or "Only on mobs with a lot of health. On quick trash it's wasted mana.")
    end
    if K("Arcane Shot") then
      item(st, "Arcane Shot", "Fill with it, right after an auto shot leaves.")
    end
    if K("Rapid Fire") then
      item(st, "Rapid Fire", lone and "On the pull, with your racial. It also uses your trinkets."
        or "Save it for elites, bosses and hard pulls.")
    end
  end
  if burst then
    item(st, burst.name, K("Rapid Fire") and "Tough mobs and elites: press it with Rapid Fire at the start." or "Tough mobs and elites: press it at the start of the fight.")
  end
  if K("Raptor Strike") then
    item(st, "Raptor Strike", K("Mongoose Bite") and "If a mob reaches you: your melee key (Raptor, or Mongoose Bite after a dodge), then step back out to 8 yards."
      or "If a mob reaches you: Raptor Strike, then step back out to 8 yards.")
  end
  section("single", "Single target", "Top to bottom: press the highest one that's ready.", st, true)

  -- AoE ----------------------------------------------------------------------
  local a2 = {}
  if K("Multi-Shot") then
    item(a2, "Multi-Shot", "Use it instead of Aimed Shot when 2 or more mobs are on you. Same 6 sec cooldown.")
  end
  if petOK and bm then
    item(a2, "PET_ATTACK", "Send the pet to the second mob so your shots and Multi-Shot hit both.")
  end
  if K("Explosive Trap") then
    item(a2, "Explosive Trap", "Under 2+ mobs if your mana allows. It uses the one Fire-trap slot.")
  elseif K("Immolation Trap") then
    item(a2, "Immolation Trap", "Drop it where the mobs will walk.")
  end
  if not K("Multi-Shot") then
    note(a2, "Until Multi-Shot at 18, pull one mob at a time and kill them one by one.")
  end
  section("aoe2", "Two or three mobs", nil, a2)

  local a4 = {}
  if K("Explosive Trap") then
    item(a4, "Explosive Trap", "Drop it under the pack first.")
  end
  if K("Volley") then
    item(a4, "Volley", "While the pet or tank holds them. No cooldown, but a lot of mana.")
  end
  if K("Multi-Shot") then
    item(a4, "Multi-Shot", "Each time it's ready, between Volleys.")
  end
  if not K("Volley") then
    note(a4, "Avoid pulling 4 or more until Volley at 40. If it happens, Feign Death or run.")
  end
  section("aoe4", "Four or more mobs", nil, a4)

  -- Moving -------------------------------------------------------------------
  local mv = {}
  if K("Concussive Shot") then
    item(mv, "Concussive Shot", "Slow anything running at you, then back off.")
  end
  if K("Arcane Shot") then
    item(mv, "Arcane Shot", "Instant: fire it while you move.")
  end
  if K("Serpent Sting") then
    item(mv, "Serpent Sting", "Also instant.")
  end
  if K("Wing Clip") then
    item(mv, "Wing Clip", "In melee: clip it, then walk out to 8 yards.")
  end
  if K("Frost Trap") then
    item(mv, "Frost Trap", "Drop it and kite the mob through it.")
  end
  if K("Aspect of the Cheetah") then
    item(mv, "Aspect of the Cheetah", "Travel only: a hit dazes you. Switch back to Hawk before you fight.")
  end
  note(mv, "Turn and run, don't backpedal. Shoot while the mob walks back to you.")
  section("move", "Moving and kiting", nil, mv)

  -- Oh no --------------------------------------------------------------------
  local oh = {}
  if K("Feign Death") then
    item(oh, "Feign Death", "Drops all threat. Then trap, bandage or reset.")
  end
  if K("Freezing Trap") then
    item(oh, "Freezing Trap", "Feign, then let the extra mob walk into it.")
  end
  if K("Intimidation") then
    item(oh, "Intimidation", "Pet stun plus big threat to peel a mob off you.")
  end
  if defense then
    item(oh, defense.name, defense.why)
  end
  if K("Concussive Shot") and not K("Feign Death") then
    item(oh, "Concussive Shot", "Slow it and get distance.")
  end
  if K("Disengage") then
    item(oh, "Disengage", "Dumps threat in melee. In Forever it isn't a leap.")
  end
  if K("Scare Beast") then
    item(oh, "Scare Beast", "Fears a beast for a few seconds.")
  end
  if K("Aspect of the Monkey") and level < 20 then
    item(oh, "Aspect of the Monkey", "Stuck in melee: more dodge.")
  end
  if #oh == 0 then
    note(oh, "Run back toward where you came from. Feign Death arrives at 30.")
  end
  section("ohno", "Oh no", "When a pull goes wrong.", oh)

  -- Pet ----------------------------------------------------------------------
  local pet = {}
  if lone then
    note(pet, "Lone Wolf: dismiss your pet in groups for 20% more damage. Open Fire still starts Auto Shot; the pet line does nothing.")
    if K("Call Pet") then
      item(pet, "Call Pet", "Solo you can still bring it out.")
    end
  elseif level < 10 or not K("Call Pet") then
    note(pet, "Your pet comes at level 10: do the hunter taming quest at your trainer, then Call Pet.")
  else
    item(pet, "Call Pet", "Call Pet when none is out, Revive Pet when it died.")
    item(pet, "Mend Pet", "Heal it early, before it gets low.")
    item(pet, "Feed Pet", "Keep it happy (green) for more damage.")
    item(pet, "PET_ATTACK", "The pet attacks the mob under your cursor.")
    item(pet, "PET_FOLLOW", "Calls the pet back to you.")
    note(pet, "Solo: Growl on autocast. In a dungeon group: Growl off, so the tank keeps threat.")
  end
  section("pet", "Pet", nil, pet)

  -- Coming soon --------------------------------------------------------------
  local soon = {}
  local seen = {}
  for _, t in ipairs(TRAINER) do
    local lvl, name = t[1], t[2]
    if NEWS[name] and DAMAGE[name] and lvl > level and not seen[name] and not Known(name) then
      seen[name] = true
      soon[#soon + 1] = { level = lvl, name = name, how = "trainer" }
    end
  end
  for _, name in ipairs(TALENT_SPELLS) do
    local lvl = TalentLevel(p, name)
    if lvl and NEWS[name] and DAMAGE[name] and not K(name) and lvl >= level then
      soon[#soon + 1] = { level = lvl, name = name, how = "talent" }
    end
  end
  -- Lone Wolf makes no sense for non-lone profiles even if a plan has it.
  table.sort(soon, function(a, b)
    if a.level == b.level then
      return a.name < b.name
    end
    return a.level < b.level
  end)
  local next3 = {}
  for _, s in ipairs(soon) do
    if #next3 >= 3 then
      break
    end
    local key = FindEntry(layout, s.name)
    s.key = key
    s.icon = Nock.IconFor and Nock.IconFor(s.name)
    s.change = NEWS[s.name]
    next3[#next3 + 1] = s
  end
  data.soon = next3

  -- Tips ---------------------------------------------------------------------
  local tips = {}
  tips[#tips + 1] = "Stand still for the last half second of each Auto Shot (its wind-up). You can move during the rest of the swing."
  if K("Arcane Shot") or K("Serpent Sting") or K("Multi-Shot") then
    tips[#tips + 1] = "Fire your other shots right after an auto shot leaves, so you never push the next one back (that's 'clipping')."
  end
  if K("Aspect of the Hawk") then
    tips[#tips + 1] = "Aspect of the Hawk on for every fight. Cheetah only for travel."
  elseif K("Aspect of the Monkey") then
    tips[#tips + 1] = "Use Aspect of the Monkey until you get Aspect of the Hawk at 10."
  end
  if auraNote then
    tips[#tips + 1] = "Trueshot Aura: click it once in your spellbook before you pull. It stays on until you die."
  end
  if K("Hunter's Mark") then
    tips[#tips + 1] = "Hunter's Mark on every mob that will live more than a few seconds. It's free ranged attack power."
  end
  if K("Serpent Sting") and not lone and not bm then
    tips[#tips + 1] = "Serpent Sting only on longer fights. On trash that dies in a few shots it wastes mana."
  end
  for _, r in ipairs(rac.utility or {}) do
    table.insert(tips, 2, r.name .. " (racial): " .. r.why)
    break
  end
  if bm and level < 60 then
    tips[#tips + 1] = "Mana: try never to sit at 0% or 100%. Your pet keeps fighting while you drink."
  elseif lone then
    tips[#tips + 1] = "Lone Wolf only works with no pet out. Time your first big shot just after the tank's first hit."
  else
    tips[#tips + 1] = "Mana: let Auto Shot carry easy mobs and save your shots for tough ones."
  end
  tips[#tips + 1] = "Stay 8 to 35 yards away. Inside 8 yards Auto Shot stops (the dead zone)."
  while #tips > 5 do
    table.remove(tips)
  end
  data.tips = tips

  -- Cheat sheet (1.9.0) --------------------------------------------------------
  -- At most 6 big plain-English lines, only spells you know, each with the key
  -- it is on right now. Static: it never looks at the fight.
  local cheat = {}
  local function cheatLine(names, text, hint)
    local rs = {}
    for _, name in ipairs(names) do
      if K(name) then
        rs[#rs + 1] = Resolve(name, layout, bars)
      end
    end
    if #rs == 0 then
      return
    end
    if type(hint) == "function" then
      hint = hint(rs[#rs])
    end
    cheat[#cheat + 1] = { rs = rs, text = text, hint = hint, action = rs[#rs].action }
  end
  -- 1. Start the fight (Mark first if you have it).
  local startHint = petOK and "Shoots and sends your pet." or "Starts shooting."
  if K("Hunter's Mark") then
    cheatLine({ "Hunter's Mark", "Auto Shot" }, "Mark it, then start the fight", "Hunter's Mark, then Open Fire. " .. startHint)
  else
    cheatLine({ "Auto Shot" }, "Start the fight", "Open Fire. " .. startHint)
  end
  -- 1b. Racial burst (2.0.1).
  if burst then
    cheatLine({ burst.name }, "Tough mob: " .. burst.name .. " first", burst.why)
  end
  -- 2. The one shot you press over and over.
  local main
  if bm and p.key ~= "bmlvl" and K("Summon Hawk") then
    main = "Summon Hawk"
  elseif not bm and K("Aimed Shot") then
    main = "Aimed Shot"
  elseif K("Arcane Shot") then
    main = "Arcane Shot"
  elseif K("Serpent Sting") then
    main = "Serpent Sting"
  end
  if main == "Arcane Shot" and K("Serpent Sting") and not (not bm and K("Aimed Shot")) then
    -- 2.0.1: Mark, Serpent Sting, then Arcane.
    cheatLine({ "Serpent Sting", "Arcane Shot" }, "Sting it, then Arcane on cooldown", "Serpent Sting once per mob, then Arcane Shot on cooldown.")
    main = nil
  end
  if main then
    local why = {
      ["Summon Hawk"] = "Summon Hawk. Keep two hawks out.",
      ["Aimed Shot"] = "Aimed Shot. Stand still while it casts.",
      ["Arcane Shot"] = "Arcane Shot.",
      ["Serpent Sting"] = "Serpent Sting. Arcane Shot comes at 6.",
    }
    cheatLine({ main }, main == "Serpent Sting" and "Press once on each tough mob" or "Press every time it's off cooldown", why[main])
  end
  -- 3. Packs.
  if K("Multi-Shot") then
    cheatLine({ "Multi-Shot" }, "2+ mobs: press this one instead", "Multi-Shot hits 3 mobs.")
  end
  -- 4. Kiting: always shown when known (these are the ones that get missed).
  if K("Concussive Shot") then
    cheatLine({ "Concussive Shot" }, "It's running at me: slow it", function(r)
      if r.alt then
        return "Concussive Shot. " .. Spoken(r.key) .. " or " .. Spoken(r.alt) .. "."
      end
      return "Concussive Shot. Then back up and keep shooting."
    end)
  end
  if K("Wing Clip") then
    cheatLine({ "Wing Clip" }, "It reached me: clip it, walk away", function(r)
      if r.key and SPOKEN_MOUSE[r.key] then
        return "Wing Clip on " .. Spoken(r.key) .. ". Walk out past 8 yards."
      end
      return "Wing Clip. Walk out past 8 yards so Auto Shot starts again."
    end)
  elseif K("Raptor Strike") then
    cheatLine({ "Raptor Strike" }, "It reached me: hit it back", "Raptor Strike. Wing Clip comes at 12.")
  end
  -- 5. Oh no.
  if K("Feign Death") then
    cheatLine({ "Feign Death" }, "Oh no: play dead", function(r)
      if r.alt then
        return "Feign Death. " .. Spoken(r.key) .. " or " .. Spoken(r.alt) .. "."
      end
      return "Feign Death. Mobs forget about you."
    end)
  end
  -- Never more than 6. Drop the pack line first, then the main shot, so the
  -- start line and the slows always stay.
  local function drop(action)
    for i, c in ipairs(cheat) do
      if c.action == action then
        table.remove(cheat, i)
        return true
      end
    end
  end
  if #cheat > 6 then
    drop("Multi-Shot")
  end
  if #cheat > 6 and burst then
    drop(burst.name)
  end
  while #cheat > 6 do
    table.remove(cheat)
  end
  for _, c in ipairs(cheat) do
    for _, r in ipairs(c.rs) do
      if r.unbound and not seenUnbound[r.action] then
        seenUnbound[r.action] = true
        data.unbound = data.unbound + 1
      end
    end
  end
  data.cheat = cheat
  return data
end

-- Bind it ------------------------------------------------------------------------

function Nock.BindAction(r)
  if InCombatLockdown() then
    Print("Leave combat first — Nock only changes keys out of combat.")
    return false
  end
  if not (r and r.layoutKey and r.entry and Nock.BindEntry) then
    Print("Nock has no key planned for " .. tostring(r and r.label) .. ". Bind it in Key Bindings or put it on a bar.")
    return false
  end
  local ok, msg = Nock.BindEntry(r.layoutKey, r.entry)
  Print(msg)
  return ok
end

-- Check (3.10.1) ---------------------------------------------------------------------
-- "Is Nock really picking up what I trained and putting it somewhere?" Reads the
-- spellbook (never the fight) and answers for every hunter ability in the trainer
-- list: known or not, a visible tile or only a key, nothing at all, or still
-- waiting at the trainer. Used by Rebuild and /nock check.
local CHECK_SKIP = { ["Auto Shot"] = true, ["Beast Training"] = true, ["Raptor Strike"] = false }

local function Rankless(name)
  return name:gsub("%s*%(.*%)$", "")
end

function Nock.CheckAbilities()
  local level = (Nock.PlayerLevel and Nock.PlayerLevel()) or 1
  local p = (Nock.ActiveProfile and Nock.ActiveProfile()) or (Nock.Profiles and Nock.Profiles.bmlvl)
  local layout = p and LayoutForProfile(p) or {}
  local bars = ScanBars()
  local index = (Nock.SpellbookIndex and Nock.SpellbookIndex(true)) or {}
  local rep = {
    level = level, spells = 0, via = (Nock.SpellbookState and Nock.SpellbookState().via) or "?",
    onBar = {}, keyOnly = {}, noKey = {}, train = {}, higher = {}, soon = 0,
  }
  for _ in pairs(index) do
    rep.spells = rep.spells + 1
  end
  local ranked = false
  for _, v in pairs(index) do
    if (v.rank or 1) > 1 then
      ranked = true
      break
    end
  end
  -- Highest rank of each name the trainer offers at this level (talent spells only count once known).
  local best, order = {}, {}
  for _, row in ipairs((Nock.Data and Nock.Data.TrainerSpells) or {}) do
    local lvl, name, rank, talent = row[1], row[2], row[3] or 0, row[4]
    local b = best[name]
    if not b then
      b = { name = name, talent = talent, firstLevel = lvl, soonLevel = lvl }
      best[name] = b
      order[#order + 1] = name
    end
    if lvl < b.firstLevel then
      b.firstLevel = lvl
    end
    if lvl <= level and rank >= (b.rank or -1) then
      b.rank, b.rankLevel = rank, lvl
    end
  end
  for _, name in ipairs(order) do
    local b = best[name]
    if not CHECK_SKIP[name] then
      local sb = index[name] or (Nock.PlayerKnows and Nock.PlayerKnows(name) and { rank = 1 }) or nil
      if sb then
        local tileKey = Nock.TileFor and (Nock.TileFor(name))
        local r = Resolve(name, layout, bars)
        local key = r.key
        if not key and Nock.Book and Nock.Book.KeyForSpell then
          key = Nock.Book.KeyForSpell(name)
          if not key and (name == "Call Pet" or name == "Revive Pet") then
            key = Nock.Book.KeyForSpell("pet-call")
          end
        end
        if tileKey then
          rep.onBar[#rep.onBar + 1] = { name = name, key = tileKey }
        elseif key then
          rep.keyOnly[#rep.keyOnly + 1] = { name = name, key = key }
        else
          rep.noKey[#rep.noKey + 1] = { name = name, planned = r.layoutKey }
        end
        if ranked and b.rank and b.rank > 0 and (sb.rank or 1) < b.rank then
          rep.higher[#rep.higher + 1] = { name = name, have = sb.rank or 1, want = b.rank, level = b.rankLevel }
        end
      elseif b.rank ~= nil and not b.talent then
        rep.train[#rep.train + 1] = { name = name, level = b.firstLevel, rank = b.rank }
      elseif b.firstLevel > level then
        rep.soon = rep.soon + 1
      end
    end
  end
  return rep
end

local function KeyName(k)
  return (Nock.KeyLabel and Nock.KeyLabel(k)) or tostring(k)
end

local function JoinList(list, fmt, max)
  local out = {}
  for i, v in ipairs(list) do
    if i > max then
      out[#out + 1] = string.format("+%d more", #list - max)
      break
    end
    out[#out + 1] = fmt(v)
  end
  return table.concat(out, ", ")
end

function Nock.PrintCheck(rep, heading)
  rep = rep or Nock.CheckAbilities()
  Print(string.format("%sLevel %d. Read %d spells from your spellbook (%s). %d on a tile, %d on a key only, %d with nothing.",
    heading and (heading .. " ") or "", rep.level, rep.spells, rep.via, #rep.onBar, #rep.keyOnly, #rep.noKey))
  if #rep.keyOnly > 0 then
    Print("On a key but no tile: " .. JoinList(rep.keyOnly, function(v) return v.name .. " (" .. KeyName(v.key) .. ")" end, 12) .. ".")
  end
  if #rep.noKey > 0 then
    Print("Known but not on any key or bar: " .. JoinList(rep.noKey, function(v)
      return v.name .. (v.planned and (" (planned " .. KeyName(v.planned) .. ")") or "")
    end, 12) .. ". Bind Missing on the My Rotation page fixes the ones with a plan.")
  end
  if #rep.train > 0 then
    Print("Not in your spellbook yet, your trainer teaches them: " .. JoinList(rep.train, function(v)
      return v.name .. " (level " .. v.level .. ")"
    end, 14) .. ".")
  end
  if #rep.higher > 0 then
    Print("A higher rank is waiting at the trainer: " .. JoinList(rep.higher, function(v)
      return v.name .. " " .. v.have .. " to " .. v.want
    end, 10) .. ".")
  end
  if #rep.keyOnly == 0 and #rep.noKey == 0 and #rep.train == 0 and #rep.higher == 0 then
    Print("Everything you know has a tile and nothing is waiting at the trainer.")
  end
end

-- /nock check <spell>: every way Nock can tell whether you know one spell.
function Nock.CheckSpell(name)
  local function yn(v)
    return v and "yes" or "no"
  end
  local spellName, icon, id = Nock.SpellData and Nock.SpellData(name)
  Print(string.format("%s: name lookup -> id %s.", name, tostring(id)))
  if id then
    local a = IsPlayerSpell and IsPlayerSpell(id)
    local b = IsSpellKnown and IsSpellKnown(id)
    local c = C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(id)
    Print(string.format("IsPlayerSpell %s, IsSpellKnown %s, IsSpellInSpellBook %s.", yn(a), yn(b), yn(c)))
  end
  local sb = Nock.SpellbookFind and Nock.SpellbookFind(name)
  if sb then
    Print(string.format("Spellbook: yes, rank %s, id %s, book slot %s.", tostring(sb.rank), tostring(sb.id), tostring(sb.index)))
  else
    Print("Spellbook: not listed (not learned yet).")
  end
  local known = Nock.PlayerKnows and Nock.PlayerKnows(name)
  Print("Nock counts it as known: " .. yn(known) .. ".")
  local tile, kind
  if Nock.TileFor then
    tile, kind = Nock.TileFor(name)
  end
  Print("Tile on the bar: " .. (tile and (KeyName(tile) .. " (" .. kind .. ")") or "none") .. ".")
end

-- Level-up summary -----------------------------------------------------------------

function Nock.LevelNews(level, p)
  level = tonumber(level)
  if not level then
    return {}
  end
  p = p or (Nock.ActiveProfile and Nock.ActiveProfile()) or (Nock.DefaultProfileFor and Nock.DefaultProfileFor(NockCharDB.spec or "marks", level))
  if not p then
    return {}
  end
  local layout = LayoutForProfile(p)
  local lines = {}
  local function KeyText(name)
    local key = FindEntry(layout, name)
    return key and (" on " .. (Nock.KeyLabel and Nock.KeyLabel(key) or key)) or ""
  end
  for _, t in ipairs(TRAINER) do
    if t[1] == level and NEWS[t[2]] then
      lines[#lines + 1] = string.format("New at %d (trainer): %s%s — %s.", level, t[2], KeyText(t[2]), NEWS[t[2]])
    end
  end
  for _, name in ipairs(TALENT_SPELLS) do
    if TalentLevel(p, name) == level and NEWS[name] then
      lines[#lines + 1] = string.format("New at %d (talent in %s): %s%s — %s.", level, p.label, name, KeyText(name), NEWS[name])
    end
  end
  return lines
end

local baseLevelUp = Nock.OnLevelUp
function Nock.OnLevelUp(newLevel)
  if baseLevelUp then
    baseLevelUp(newLevel)
  end
  for _, line in ipairs(Nock.LevelNews(newLevel)) do
    Print(line)
  end
end
