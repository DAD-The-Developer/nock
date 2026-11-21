--[[
  Nock — keyboard hunter hands for World of Warcraft: Forever

  This addon sets keybinds and action-bar slots out of combat, shows a
  label overlay of what each key does, teaches Forever hunter facts when
  you learn spells, and shows written Beast Mastery and Marksmanship
  talent guides. It does not press keys for you, pick targets, or choose
  your next shot. 2.0.1: key bar tiles show cooldown swipes and red/blue
  out-of-range / no-mana tints, exactly like Blizzard's own action buttons.
  That is display only: nothing is decided from it.
  2.1.0: the ergonomic WASD keymap (KEYMAP-2.1.md) plus Wing Clip,
  Concussive Shot and Feign Death on mouse buttons 4, 5 and the wheel
  click, only on buttons that are empty. Nock.Keymap21 moves an older setup
  once, after asking, and only keys that still hold Nock's own spell
  (the Keymap21 block at the end of Setup.lua).
  3.1.1: Gunsmith tiles are hollow frames so spell icons stay square and
  unobstructed; the plaque wood is opaque; caps sit behind the buttons.
  The threat meter stays visible while unlocked (including out of combat).
  Style and the rest of the UI now persist across /reload. /nock save
  confirms, and /nock profile save|load <name> stores a whole setup
  account-wide.
  3.1.0: Emerald and Gunsmith HUD styles (art and accents only).
  /nock style gun|emerald, a Style picker, and a keybindable toggle.
  The threat meter can be unlocked and dragged; it snaps to the HUD
  center line. /nock threat unlock|lock|reset. Position is saved
  per character; moving is blocked in combat.
  3.0.15: the You / Pet rows actually draw inside the plaque (a grid
  helper had been clearing their anchors). Errors are saved and printed
  once. /nock threat debug labels isTanking, status, scaled, raw, value.
  3.0.14: the threat meter stays up after a mid-fight /reload, polls
  every 0.2s in combat, shows an em dash when Forever hides the value,
  and /nock threat debug prints the raw API returns.
  3.0.13: the threat meter is redesigned to a consistent padding grid,
  with names left, percents right, equal-height bars and a carved frame.
  3.0.12: a carved player + pet threat meter sits above the bow, hidden
  out of combat. It uses Forever's native UnitDetailedThreatSituation.
  3.0.11: Hearth is an icon-only tile (no clipped Hearth / A-HEARTH label).
  Extra and utility key letters sit fully inside the top-left of each tile.
  Main bow tiles keep even 60px + 7px gaps and the same top-left key tabs.
  3.0.10: every skill has a left-hand key (no click-only flyouts). F is
  a smart melee key (Mongoose Bite when it's usable, otherwise Raptor).
  C cycles tracking. New binds use SetOverrideBindingClick, never
  SaveBindings, so uninstalling Nock gives your keys back.
  3.0.8: every hunter skill you know shows up on Nock's bars. Melee
  tiles (Raptor, Mongoose, Counterattack and the rest) sit in a cluster;
  tracking is one button with a flyout; anything else lands in More.
  The list updates when you learn a spell (after combat if you're in one).
  3.0.7: the pet bar (with Train / Feed and the info strip) sits under
  the experience bar, not above the bow. The stack shifts up so it fits,
  and the gap collapses when you have no pet.
  3.0.6: FontStrings always get a font before SetText, so a missing font
  can't stop the bar from loading; XP and pet builds are isolated.
  3.0.5: the XP bar uses Ben's carved wood/emerald art (frame, trough,
  wavy fill and rested, gold ticks, leaf-arrow spark, round level badge).
  It is taller, scales with Bar size, and stays taint-safe like 3.0.4.
  A Nock pet bar sits above the bow: secure pet-action tiles (active vs
  off is obvious), Train Pet / Feed Pet, and a short strip for happiness,
  loyalty, level and training points. Hidden when you have no pet.
  3.0.4: Nock draws its own XP bar (no longer moves Blizzard's); a Bar
  size control (Small / Normal / Large, default Large) with bigger tiles,
  bold outlined key badges and countdown numbers. Bags and the micro menu
  stay at Blizzard's default spot.
  3.0.3: range tint only with a hostile target and a clear out-of-range
  result; XP under the utility row; bags and micro in the bottom-right
  corner; larger tile icons and badges that do not cover the countdown.
  3.0.2: register each bar's visibility state driver once, never from a
  Hide hook, so Edit Mode BreakSnappedFrames cannot overflow the C stack.
  3.0.1: hide Forever's real action-bar frames (MainActionBar, PetActionBar,
  StanceBar, MultiBar*), not only the old MainMenuBar names, and stop
  Edit Mode from showing them again.
  3.0.0: the 2.3 bow bar becomes the main action bar (Blizzard bars hidden,
  with a toggle to restore). A small utility row shows pet, aspects, traps,
  food and Hearthstone only when you have them. Newly learned catalog spells
  appear out of combat, with a short "New: <spell>" toast.
]]

local ADDON_NAME = ...
local VERSION = "3.3.1"
-- Keys, bars and macros last changed in 1.9.0; 2.0 is a new look only, so a
-- character set up on 1.9.0 is not asked to set up again. 2.0.1's racial keys
-- (Alt-1, Alt-E) are added by auto keep-up, only on keys that are free.
-- 2.1.0 moves keys (the 2.1 keymap + mouse buttons). That move is NOT a full
-- re-setup: Setup.lua's Keymap21 block asks once and moves only keys that still hold Nock's
-- own spell, so LAYOUT_VERSION stays and Keymap21 tracks NockCharDB.km.
local LAYOUT_VERSION = "1.9.0"
local KEYMAP = "2.1"

NockDB = NockDB or {}
NockCharDB = NockCharDB or {}

local Nock = {}
_G.Nock = Nock

local KEYCAP_ORDER = {
  "1", "2", "3", "4", "5", "6",
  "Q", "E", "R", "F", "G", "T", "X", "Z", "H",
  "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5", "SHIFT-6",
  "SHIFT-Q", "SHIFT-E", "SHIFT-R", "SHIFT-T", "SHIFT-F", "SHIFT-G", "SHIFT-H",
  "SHIFT-X", "SHIFT-C", "SHIFT-Z",
  "ALT-1", "ALT-2", "ALT-3", "ALT-4", "ALT-5",
  "ALT-Q", "ALT-E", "ALT-R", "ALT-T", "ALT-F", "ALT-G", "ALT-X", "ALT-C",
  "CTRL-Q", "CTRL-E", "CTRL-T", "CTRL-F", "CTRL-G", "CTRL-Z", "CTRL-X", "CTRL-C",
  "BUTTON4", "BUTTON5", "BUTTON3", "SHIFT-BUTTON4", "SHIFT-BUTTON5",
}

-- 2.1: mouse buttons Nock may use. Never BUTTON1/2 (targeting, camera) or
-- MOUSEWHEELUP/DOWN (zoom). Each copies a keyboard key's spell.
local MOUSE_KEYS = {
  { key = "BUTTON4", from = "WINGCLIP" },
  { key = "BUTTON5", from = "Q" },
  { key = "BUTTON3", from = "E" },
  { key = "SHIFT-BUTTON4", from = "ALT-Q" },
  { key = "SHIFT-BUTTON5", from = "SHIFT-Q" },
}
local MOUSE_TWIN = { Q = "BUTTON5", E = "BUTTON3", BUTTON3 = "E" } -- shared-bind badges
local MOUSE_NAME = {
  BUTTON3 = "the mouse wheel click", BUTTON4 = "mouse button 4", BUTTON5 = "mouse button 5",
  ["SHIFT-BUTTON4"] = "Shift + mouse button 4", ["SHIFT-BUTTON5"] = "Shift + mouse button 5",
}

local function MouseOn()
  return not (NockCharDB and NockCharDB.mouse == false)
end

local function Print(msg)
  if Nock.capture then
    table.insert(Nock.capture, tostring(msg))
    return
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Nock|r: " .. tostring(msg))
end

local function IsHunter()
  local _, classFile = UnitClass("player")
  return classFile == "HUNTER"
end

local function SpellData(name)
  if name == nil or name == "" then
    return nil, nil, nil
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(name)
    if type(info) == "table" then
      return info.name or name, info.iconID, info.spellID
    end
  end
  if GetSpellInfo then
    local spellName, _, icon, _, _, _, spellID = GetSpellInfo(name)
    if spellName or spellID then
      return spellName or name, icon, spellID
    end
  end
  return name, nil, nil
end

local function PlayerKnows(name)
  local spellName, icon, spellID = SpellData(name)
  if not spellID then
    return false, nil, spellName or name, icon
  end
  if IsPlayerSpell and IsPlayerSpell(spellID) then
    return true, spellID, spellName, icon
  end
  if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
    local ok = C_SpellBook.IsSpellInSpellBook(spellID)
    if ok then
      return true, spellID, spellName, icon
    end
  end
  if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
    return true, spellID, spellName, icon
  end
  if IsSpellKnown and IsSpellKnown(spellID) then
    return true, spellID, spellName, icon
  end
  return false, spellID, spellName, icon
end

local function FirstKnown(names)
  for _, name in ipairs(names) do
    local known, spellID, spellName, icon = PlayerKnows(name)
    if known then
      return name, spellID, spellName, icon
    end
  end
  return names[1], nil, names[1], nil
end


-- Racials (2.0.1) -------------------------------------------------------------
-- WoW Forever 1.60.1 hunter races only (Orc, Tauren, Troll, Windshaper
-- Skyborne; Human, Dwarf, Night Elf, High Order Skyborne). Sources:
-- talentsforever.com/hunter/races and warcraftmaps.com, checked 11 Nov 2026.
-- No Draenei, Gnome or Undead hunters in Forever, so no Gift of the Naaru etc.
--   burst   = a damage cooldown: press it at the start of a tough fight
--   defense = an emergency button
--   utility = useful, but not a fight button: no key, just a note
-- Passives (Quickness, Command, Ruthless...) need no button and are skipped.
local RACIALS = {
  { name = "Elune's Light", race = "NightElf", kind = "burst",
    why = "+10% crit for 15 sec (3 min cooldown). Press it at the start of a tough fight." },
  { name = "Blood Fury", race = "Orc", kind = "burst",
    why = "+10% attack power for 15 sec (2 min cooldown). Press it at the start of a tough fight." },
  { name = "Berserking", race = "Troll", kind = "burst",
    why = "+10% attack and casting speed for 15 sec (3 min cooldown). Press it at the start of a tough fight." },
  { name = "Stoneform", race = "Dwarf", kind = "defense",
    why = "Removes bleeds, poisons and diseases and cuts physical damage taken by 10% for 8 sec." },
  { name = "Will to Survive", race = "Human", kind = "defense", why = "Breaks a stun." },
  { name = "War Stomp", race = "Tauren", kind = "defense", why = "Stuns mobs next to you for 2 sec. Then walk out to 8 yards." },
  { name = "Rapid Regeneration", race = "Troll", kind = "defense", why = "Heals 50% of your health over 6 sec when you're low." },
  { name = "Shatter Curse", race = "Orc", kind = "defense", why = "Removes curses and cuts magic damage taken by 5% for 8 sec." },
  { name = "Shadowmeld", race = "NightElf", kind = "utility",
    why = "Stand still to stealth: drink unseen or let a patrol walk past." },
  { name = "Perception", race = "Human", kind = "utility", why = "Shows stealthed enemies for 20 sec." },
  { name = "Find Treasure", race = "Dwarf", kind = "utility", why = "Tracks treasure chests on the minimap." },
  { name = "Read Leyline", race = "Skyborne", kind = "utility", why = "+50% health and mana regen for 15 sec: use it while you drink." },
  { name = "Skysight", race = "Skyborne", kind = "utility", why = "+15% speed for 15 sec." },
  { name = "Walk on Air", race = "Skyborne", kind = "utility", why = "Glide down safely for 10 sec." },
  { name = "Cultivation", race = "Tauren", kind = "utility", why = "Gathers herbs." },
}
local RACIAL_KEYS = { burst = "ALT-1", defense = "ALT-E" } -- Shift-Q / Alt-Q are the pet keys

-- Names in the spellbook's first (General) tab. Classic and modern APIs, all guarded.
local function GeneralTabNames()
  local names = {}
  local function add(n)
    if type(n) == "string" and n ~= "" then
      names[n] = true
    end
  end
  local ok = pcall(function()
    if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemName then
      local info = C_SpellBook.GetSpellBookSkillLineInfo(1)
      if type(info) == "table" and info.numSpellBookItems then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local off = info.itemIndexOffset or 0
        for i = off + 1, off + info.numSpellBookItems do
          add((C_SpellBook.GetSpellBookItemName(i, bank)))
        end
        return
      end
    end
    if GetSpellTabInfo then
      local _, _, off, num = GetSpellTabInfo(1)
      off, num = tonumber(off) or 0, tonumber(num) or 0
      local getName = GetSpellBookItemName or GetSpellName
      if getName then
        for i = off + 1, off + num do
          add((getName(i, BOOKTYPE_SPELL or "spell")))
        end
      end
    end
  end)
  return names
end

-- What this character really has: { burst = r, defense = r, utility = { r, ... }, all = { r... } }
local function Racials()
  local out = { utility = {}, all = {} }
  local race = UnitRace and select(2, UnitRace("player")) or nil
  race = type(race) == "string" and race or ""
  local general = GeneralTabNames()
  local function has(r)
    return PlayerKnows(r.name) or general[r.name] or false
  end
  -- Your own race's racials first, then anything else the spellbook has.
  for pass = 1, 2 do
    for _, r in ipairs(RACIALS) do
      local mine = race ~= "" and race:find(r.race, 1, true) ~= nil
      if ((pass == 1) == mine) and has(r) then
        out.all[#out.all + 1] = r
        if r.kind == "utility" then
          out.utility[#out.utility + 1] = r
        elseif not out[r.kind] then
          out[r.kind] = r
        end
      end
    end
  end
  out.race = race
  return out
end
Nock.Racials = Racials
Nock.RacialList = RACIALS
Nock.RacialKeys = RACIAL_KEYS

-- Static teaching notes. Shown when you learn the spell or open the manual.
-- No live combat checks.
local NOTES = {
  ["Auto Shot"] = "Auto Shot works from about 8 to 35 yards. Inside 8 yards you are in the dead zone — use Raptor Strike and Wing Clip and step back out.",
  ["Aimed Shot"] = "Baseline at 20 in Forever (it used to be a talent). 2-second cast, 6-second cooldown shared with Multi-Shot. Your auto shots keep firing during the cast. On a single target this is your heavy shot; on a pack, use Multi-Shot instead — you cannot fire both in the same window.",
  ["Multi-Shot"] = "Hits 3 targets and shares a 6-second cooldown with Aimed Shot. Use this instead of Aimed Shot on packs, or when you need an instant shot while moving. Forever gave it a single rank that costs a percentage of your mana.",
  ["Arcane Shot"] = "Instant filler on a 6-second cooldown, shared with Summon Hawk. Arcane Shot got about 30% stronger on Nov 3. Leveling guides now rate it above Summon Hawk, while endgame BM keeps two hawks up and fits Arcane Shot in between.",
  ["Summon Hawk"] = "Beast Mastery talent. Shares a cooldown with Arcane Shot. You can have two hawks out at once — summon twice, then use Arcane Shot.",
  ["Serpent Sting"] = "Apply it and let it tick. It scales with attack power in Forever, and Marksmanship talents make it even better. Only one of your stings can be on a target at a time.",
  ["Hunter's Mark"] = "Put this on the target you and your group should shoot. It boosts ranged attack power on that target and keeps stealthed enemies visible to you.",
  ["Rapid Fire"] = "Your big haste cooldown. In Forever it speeds up melee swings as well as Auto Shot. Pair it with Bestial Wrath if you have that talent.",
  ["Bestial Wrath"] = "Beast Mastery capstone. Your pet hits much harder and cannot be stopped for a short window. Pop it with Rapid Fire.",
  ["Intimidation"] = "Beast Mastery talent. Your pet's next hit stuns and critically strikes, and it generates a lot of threat — a semi-taunt in a pinch.",
  ["Trueshot Aura"] = "Marksmanship talent. A group ranged-attack-power aura. Keep it up for you and your party. It does not buff melee attack power in Forever.",
  ["Sniper Shot"] = "Marksmanship capstone. A long 4-second cast on a 15-second cooldown — a setup shot, not something you weave like Aimed Shot.",
  ["Volley"] = "Ground-targeted ranged AoE with no cooldown in Forever. Use it on clumped packs after you have moved out of the dead zone.",
  ["Feign Death"] = "Drops combat and threat in PvE, and drops targeting in PvP. One of the most important hunter buttons. Use it to reset, bandage, or swap gear.",
  ["Freezing Trap"] = "Single-target freeze. In Forever you can have one Fire trap and one Frost trap active at the same time, so Freezing Trap plus Immolation Trap is legal.",
  ["Frost Trap"] = "Drops a 60% slow field. Strong for kiting. It is a Frost trap, so it can sit out alongside a Fire trap.",
  ["Immolation Trap"] = "Fire trap that burns the first enemy that walks in. Usable in combat in Forever. Shares the 'one Fire trap' slot with Explosive Trap.",
  ["Explosive Trap"] = "Fire trap with an AoE burst and a burning patch. Use this instead of Immolation Trap when several mobs will stand in it.",
  ["Concussive Shot"] = "Ranged slow. Your kite button when something is running at you or fleeing.",
  ["Raptor Strike"] = "Your melee hit when something is inside 8 yards. Do not sit in the dead zone and keep trying to Aimed Shot.",
  ["Wing Clip"] = "Melee slow. Clip and step out to 8 yards so Auto Shot starts again.",
  ["Disengage"] = "Dumps threat against your current target. In Forever this is not a leap — it is a threat dump you use in melee range.",
  ["Mend Pet"] = "Channeled heal on your pet. Beast Mastery especially: a dead pet is a huge damage loss.",
  ["Feed Pet"] = "Keep happiness in the green — a happy pet does more damage. Each family eats different food.",
  ["Call Pet"] = "Brings your active pet out. Dismissing lowers happiness, so feed after you summon again.",
  ["Revive Pet"] = "Use this when your pet has died. It shares Ctrl-G with Call Pet.",
  ["Aspect of the Hawk"] = "Your main ranged damage aspect. Switch back to this after running or drinking mana.",
  ["Aspect of the Falcon"] = "A high-level ranged damage aspect. Use it the same way as Aspect of the Hawk if you have it.",
  ["Aspect of the Viper"] = "Mana regen aspect. Use it to recover mana, then switch back to Hawk or Falcon before you care about damage again.",
  ["Aspect of the Cheetah"] = "Run speed. You (and only you) get dazed if you take a hit. Do not leave this on in a fight.",
  ["Aspect of the Pack"] = "Group run speed. Anyone who gets hit is dazed, so turn it off before pulls.",
  ["Aspect of the Monkey"] = "Dodge aspect. Useful if you are stuck in melee.",
  ["Tranquilizing Shot"] = "Removes a Frenzy/enrage effect. Some bosses and PvP targets need this — that is why it has a key.",
  ["Flare"] = "Reveals stealthed enemies in an area. Drop it on rogues, druids, or sneaky PvE packs.",
  ["Viper Sting"] = "Drains mana. Excellent on enemy casters.",
  ["Scare Beast"] = "Fears beasts — enemy hunter pets and druids in animal forms.",
  ["Lone Wolf"] = "Marksmanship talent: you deal 20% more damage with no pet active. Open Fire still works; the pet-attack line simply does nothing.",
}

local function DamageAspectName()
  local name = FirstKnown({ "Aspect of the Hawk", "Aspect of the Falcon" })
  return name
end

local function ManaAspectName()
  local name = FirstKnown({ "Aspect of the Viper", "Aspect of the Monkey" })
  return name
end

local function BindingCommand(entry)
  if entry.kind == "macro" then
    return "MACRO " .. entry.name
  end
  return "SPELL " .. entry.name
end

local function LayoutFor(spec)
  local damageAspect = DamageAspectName()
    local row = {}

  local function bind(key, entry)
    row[key] = entry
  end

  bind("1", {
    kind = "macro",
    name = "Nock:OpenFire",
    label = "Open Fire",
    slot = 1,
    macro = "#showtooltip Auto Shot\n/petattack\n/cast !Auto Shot",
    icon = "ABILITY_WHIRLWIND",
    note = "Starts Auto Shot without toggling it off if you press the key twice, and sends your pet. Your pull button from level 1.",
  })

  -- 2.1 keymap (KEYMAP-2.1.md). One binding per key and modifier.
  if spec == "bm" then
    local hawkKnown = PlayerKnows("Summon Hawk")
    if hawkKnown then
      bind("2", { kind = "spell", name = "Summon Hawk", slot = 2 })
      bind("SHIFT-2", { kind = "spell", name = "Arcane Shot" })
    else
      bind("2", { kind = "spell", name = "Arcane Shot", slot = 2 })
    end
  else
    bind("2", { kind = "spell", name = "Arcane Shot", slot = 2 })
    bind("SHIFT-2", { kind = "spell", name = "Trueshot Aura" })
    bind("SHIFT-3", { kind = "spell", name = "Sniper Shot" })
  end
  -- Pet talents live on the pet key (G) for both specs; unlearned = unbound.
  bind("SHIFT-G", { kind = "spell", name = "Bestial Wrath" })
  bind("ALT-G", { kind = "spell", name = "Intimidation" })

  -- Number row: damage, Shift = bigger, Alt = utility shots.
  bind("SHIFT-1", { kind = "spell", name = "Rapid Fire" })
  bind("ALT-2", { kind = "spell", name = "Distracting Shot" })
  bind("3", { kind = "spell", name = "Aimed Shot", slot = 3, learnAt = 20 })
  bind("ALT-3", { kind = "spell", name = "Tranquilizing Shot" })
  bind("4", { kind = "spell", name = "Multi-Shot", slot = 4, learnAt = 18 })
  bind("SHIFT-4", { kind = "spell", name = "Volley" })
  bind("ALT-4", { kind = "spell", name = "Flare" })
  bind("5", { kind = "spell", name = "Serpent Sting", slot = 5, learnAt = 4 })
  bind("SHIFT-5", { kind = "spell", name = "Scorpid Sting" })
  bind("ALT-5", { kind = "spell", name = "Viper Sting" })
  bind("6", { kind = "spell", name = "Raptor Strike", slot = 6 })
  bind("SHIFT-6", { kind = "spell", name = "Lacerate" })

  -- Q / E: "it's on me" keys.
  bind("Q", { kind = "spell", name = "Concussive Shot" })
  bind("SHIFT-Q", { kind = "spell", name = "Scatter Shot" })
  bind("ALT-Q", { kind = "spell", name = "Strider Kick" })
  bind("CTRL-Q", { kind = "spell", name = "Scare Beast" })
  bind("E", { kind = "spell", name = "Feign Death" })
  bind("SHIFT-E", { kind = "spell", name = "Deterrence" })
  bind("CTRL-E", { kind = "spell", name = "Disengage" })
  bind("R", { kind = "spell", name = "Hunter's Mark", learnAt = 6 })
  bind("SHIFT-R", { kind = "spell", name = "Beast Lore" })
  bind("ALT-R", { kind = "spell", name = "Eagle Eye" })

  -- Traps on F.
  bind("F", { kind = "spell", name = "Freezing Trap", learnAt = 20 })
  bind("SHIFT-F", { kind = "spell", name = "Frost Trap" })
  bind("ALT-F", { kind = "spell", name = "Immolation Trap", learnAt = 16 })
  bind("CTRL-F", { kind = "spell", name = "Explosive Trap" })

  -- Pet cluster on T and G.
  bind("T", {
    kind = "macro", name = "Nock:PetGo", label = "Pet: attack",
    macro = "/petattack [@mouseover,harm,nodead][]", icon = "ABILITY_GHOULFRENZY",
    note = "The pet attacks the enemy under your cursor, or your target if the cursor is on nothing.",
  })
  bind("SHIFT-T", {
    kind = "macro", name = "Nock:PetBack", label = "Pet: follow",
    macro = "/petfollow", icon = "ABILITY_TRACKING", note = "Calls the pet back to you.",
  })
  bind("ALT-T", {
    kind = "macro", name = "Nock:PetStay", label = "Pet: stay",
    macro = "/petstay", icon = "SPELL_NATURE_TIMESTOP", note = "The pet stays where it is (dungeon trap pulls).",
  })
  bind("CTRL-T", { kind = "spell", name = "Feed Pet" })
  bind("G", { kind = "spell", name = "Mend Pet" })
  bind("CTRL-G", {
    kind = "macro",
    name = "Nock:Pet",
    label = "Call / Revive",
    macro = "#showtooltip Call Pet\n/cast [nopet] Call Pet\n/cast [@pet,dead] Revive Pet",
    icon = "ABILITY_HUNTER_BEASTCALL",
    note = "Call Pet if you have no pet out; Revive Pet if your pet is dead.",
  })
  bind("H", { kind = "spell", name = "Eyes of the Beast" })
  bind("SHIFT-H", { kind = "spell", name = "Tame Beast" })

  -- Aspects on X and Z. X is Hawk once you have it (Monkey until 10).
  bind("X", { kind = "spell", name = PlayerKnows(damageAspect) and damageAspect or "Aspect of the Monkey" })
  bind("SHIFT-X", { kind = "spell", name = "Aspect of the Cheetah" })
  bind("ALT-X", { kind = "spell", name = "Aspect of the Monkey" })
  bind("CTRL-X", { kind = "spell", name = "Aspect of the Pack" })
  bind("Z", { kind = "spell", name = "Aspect of the Wild" })
  bind("CTRL-Z", { kind = "spell", name = "Aspect of the Beast" })

  -- Tracking on Shift/Alt/Ctrl-C (plain C stays Blizzard's character pane).
  bind("SHIFT-C", { kind = "spell", name = "Track Beasts" })
  bind("ALT-C", { kind = "spell", name = "Track Humanoids" })
  bind("CTRL-C", { kind = "spell", name = "Track Hidden" })

  -- 2.0.1: your race's fight buttons, only if you have them. ifFree = Nock
  -- binds the key only while nothing else is on it; it never takes a key of yours.
  local rac = Racials()
  for kind, key in pairs(RACIAL_KEYS) do
    local r = rac[kind]
    if r then
      bind(key, { kind = "spell", name = r.name, ifFree = true, racial = kind, note = r.why })
    end
  end

  -- Profiles.lua (1.4.0) can swap some keys to Nock macros for the active profile.
  if Nock.ProfileOverrides then
    local over = Nock.ProfileOverrides(spec)
    if over then
      for key, entry in pairs(over) do
        row[key] = entry
      end
    end
  end

  -- 2.1: Wing Clip and copies of Q / E / Shift-Q / Alt-Q on the mouse, on by
  -- default. A button joins the layout only while it is empty or already
  -- Nock's; one that holds a Blizzard default or something of yours (or that
  -- you cleared yourself) is left out entirely. Wing Clip falls back to Shift-Z when Mouse 4 can't have it.
  local wing = { kind = "spell", name = "Wing Clip" }
  local wingOnMouse = false
  if MouseOn() then
    local track = NockCharDB and NockCharDB.nockKeys or {}
    for _, m in ipairs(MOUSE_KEYS) do
      local src = m.from == "WINGCLIP" and wing or row[m.from]
      if src then
        local e = {}
        for k, v in pairs(src) do
          e[k] = v
        end
        e.slot, e.learnAt = nil, src.learnAt
        e.ifFree, e.mouse = true, true
        local cur = GetBindingAction(m.key, true) or ""
        local yours = NockCharDB and NockCharDB.userKeys and NockCharDB.userKeys[m.key] ~= nil
        if not yours and (cur == "" or cur == BindingCommand(e) or (track[m.key] and cur == track[m.key])) then
          row[m.key] = e
          if m.key == "BUTTON4" then
            wingOnMouse = true
          end
        end
      end
    end
  end
  if not wingOnMouse then
    row["SHIFT-Z"] = wing
  end

  return row
end

local function EntryLabel(entry)
  if not entry then
    return ""
  end
  if entry.label then
    return entry.label
  end
  return entry.name or ""
end


local function EnsureMacro(entry)
  if entry.kind ~= "macro" then
    return true
  end
  local index = GetMacroIndexByName(entry.name)
  local perChar = true
  if index == 0 then
    local ok, id = pcall(CreateMacro, entry.name, entry.icon or "INV_MISC_QUESTIONMARK", entry.macro, perChar)
    return ok and id and id > 0
  end
  local ok = pcall(EditMacro, index, entry.name, entry.icon or nil, entry.macro)
  return ok
end

local function PickupEntry(entry)
  if entry.kind == "macro" then
    if not EnsureMacro(entry) then
      return false
    end
    PickupMacro(entry.name)
    return true
  end
  local known, spellID = PlayerKnows(entry.name)
  if not known or not spellID then
    return false
  end
  if C_Spell and C_Spell.PickupSpell then
    C_Spell.PickupSpell(spellID)
  elseif PickupSpell then
    PickupSpell(spellID)
  else
    return false
  end
  return true
end

local function ClearCursorSafe()
  if GetCursorInfo() then
    ClearCursor()
  end
end

local function SnapshotBindings(layout)
  local snap = { keys = {}, slots = {}, time = time() }
  for key in pairs(layout) do
    snap.keys[key] = GetBindingAction(key, true) or ""
  end
  for _, entry in pairs(layout) do
    if entry.slot then
      local actionType, id, subType = GetActionInfo(entry.slot)
      snap.slots[tostring(entry.slot)] = { actionType or "", id or 0, subType or "" }
    end
  end
  return snap
end

local function RestoreSnapshot(snap)
  if not snap or not snap.keys then
    return false, "Nothing to restore."
  end
  if InCombatLockdown() then
    return false, "Leave combat first."
  end
  for key, action in pairs(snap.keys) do
    SetBinding(key)
    if action and action ~= "" then
      SetBinding(key, action)
    end
  end
  SaveBindings(GetCurrentBindingSet())
  return true
end

-- Keys older Nock versions used and no longer do. If the key still holds
-- exactly what Nock put there, clear it (out of combat only). Anything else
-- on it is yours and stays.
local RETIRED_KEYS = {
  ["SHIFT-6"] = "SPELL Wing Clip", -- 1.8 Wing Clip (Shift-6 is Lacerate since 2.1)
  -- 2.1 keymap: keys Nock 2.0.1 used that 2.1 hands back.
  ["SHIFT-Z"] = "SPELL Wing Clip", -- Wing Clip is on Mouse 4 (Shift-Z only when the mouse is off)
  ["V"] = "SPELL Feed Pet", -- Feed Pet is Ctrl-T; V is Blizzard's nameplates again
  ["C"] = "SPELL Aspect of the Cheetah", -- Cheetah is Shift-X; C is the character pane again
  ["SHIFT-V"] = "SPELL Scare Beast", -- Scare Beast is Ctrl-Q
  ["`"] = "SPELL Disengage", -- Disengage is Ctrl-E
}

local function RetireOldKeys()
  if InCombatLockdown() then
    return 0
  end
  local cleared = 0
  local track = NockCharDB.nockKeys
  local ok, layout = pcall(LayoutFor, NockCharDB.spec or "bm")
  layout = ok and layout or {}
  for key, old in pairs(RETIRED_KEYS) do
    local cur = GetBindingAction(key, true) or ""
    local userOwned = NockCharDB.userKeys and NockCharDB.userKeys[key] ~= nil
    local want = layout[key] and BindingCommand(layout[key])
    if cur == old and want ~= old and not userOwned then
      SetBinding(key)
      cleared = cleared + 1
      if track then
        track[key] = nil
      end
      if NockCharDB.readyKeys then
        NockCharDB.readyKeys[key] = nil
      end
    end
  end
  return cleared
end

local function ApplyLayout(spec)
  if InCombatLockdown() then
    return false, "Leave combat first — Nock only writes bars and binds when you are out of combat."
  end
  if GetCursorInfo() then
    return false, "Clear whatever is on your cursor first."
  end

  local layout = LayoutFor(spec)
  -- So Book.IsCoreKey sees the spec being applied (Shift-3 Sniper on MM, etc.).
  NockCharDB.spec = spec
  if not NockCharDB.snapshot then
    NockCharDB.snapshot = SnapshotBindings(layout)
  elseif NockCharDB.snapshot.keys then
    -- Keys added in a newer Nock (1.9: Shift-Z) join the Restore Keys snapshot.
    for key in pairs(layout) do
      if NockCharDB.snapshot.keys[key] == nil then
        NockCharDB.snapshot.keys[key] = GetBindingAction(key, true) or ""
      end
    end
  end

  local placed, reserved, skipped = 0, 0, 0

  for key, entry in pairs(layout) do
    if Book.OwnsKey and Book.OwnsKey(key) then
      -- 3.0.9: these keys are SetOverrideBindingClick only; never SaveBindings.
    else
    local curBind = GetBindingAction(key, true) or ""
    if entry.ifFree and curBind ~= "" and curBind ~= BindingCommand(entry) then
      skipped = skipped -- 2.0.1/2.1: racial and mouse keys never take a key of yours
    elseif entry.kind == "macro" and not EnsureMacro(entry) then
      skipped = skipped + 1
    elseif entry.kind == "macro" then
      SetBinding(key)
      SetBindingMacro(key, entry.name)
      if entry.slot then
        ClearCursorSafe()
        if PickupEntry(entry) then
          PlaceAction(entry.slot)
          ClearCursorSafe()
        end
      end
      placed = placed + 1
    else
      local known = PlayerKnows(entry.name)
      if known then
        SetBinding(key)
        SetBindingSpell(key, entry.name)
        if entry.slot then
          ClearCursorSafe()
          if PickupEntry(entry) then
            PlaceAction(entry.slot)
            ClearCursorSafe()
          end
        end
        placed = placed + 1
      else
        reserved = reserved + 1
      end
    end
    end
  end

  RetireOldKeys()
  SaveBindings(GetCurrentBindingSet())
  NockCharDB.applied = true
  NockCharDB.spec = spec
  NockCharDB.version = VERSION
  NockCharDB.km = KEYMAP -- a full setup is already the 2.1 keymap

  return true, string.format(
    "Bound %d keys for %s. %d reserved for spells you have not learned yet.%s",
    placed,
    spec == "bm" and "Beast Mastery" or "Marksmanship",
    reserved,
    skipped > 0 and (" " .. skipped .. " macro(s) could not be created — check /macro for free character slots.") or ""
  )
end

local function DetectSpec()
  local bm, marks, survival = 0, 0, 0
  local tb, tm, ts
  if Nock.TraitPointsByTab then
    tb, tm, ts = Nock.TraitPointsByTab()
  end
  if tb then
    -- Forever 1.60.1: talents live in C_Traits (GetTalentTabInfo is gone).
    bm, marks, survival = tb, tm or 0, ts or 0
  elseif GetNumTalentTabs and GetTalentTabInfo then
    for i = 1, GetNumTalentTabs() do
      local a, b, c = GetTalentTabInfo(i)
      -- Classic-style: name, icon, points. Some clients swap the first fields.
      local name, points
      if type(a) == "string" then
        name, points = a, c
      else
        name, points = b, c
      end
      name = type(name) == "string" and name:lower() or ""
      points = tonumber(points) or 0
      if name:find("beast", 1, true) then
        bm = points
      elseif name:find("mark", 1, true) then
        marks = points
      elseif name:find("surviv", 1, true) then
        survival = points
      end
    end
  end
  if PlayerKnows("Bestial Wrath") or PlayerKnows("Summon Hawk") or PlayerKnows("Intimidation") then
    bm = bm + 1
  end
  if PlayerKnows("Sniper Shot") or PlayerKnows("Trueshot Aura") then
    marks = marks + 1
  end
  if bm == 0 and marks == 0 and survival == 0 then
    return "marks", "Not enough talent info yet — defaulting to Marksmanship. You can pick another profile on the Profiles tab."
  end
  if bm >= marks then
    return "bm", survival > bm and "More points in Survival; applying Beast Mastery as the closer match." or nil
  end
  return "marks", survival > marks and "More points in Survival; applying Marksmanship as the closer match." or nil
end

Nock.DetectSpec = DetectSpec

local function ShowNote(spellName, quiet)
  NockCharDB.seenNotes = NockCharDB.seenNotes or {}
  local text = NOTES[spellName]
  if not text then
    return
  end
  if quiet and NockCharDB.seenNotes[spellName] then
    return
  end
  NockCharDB.seenNotes[spellName] = true
  Print("|cfff0e2b6" .. spellName .. "|r — " .. text)
end

local function NoteForSpellID(spellID)
  if not IsHunter() or NockCharDB.notes == false or not spellID then
    return
  end
  local spellName = SpellData(spellID)
  if spellName and NOTES[spellName] then
    ShowNote(spellName, true)
  end
end

local function TryAutoFill()
  if not IsHunter() or not NockCharDB.applied or NockCharDB.autofill == false then
    return
  end
  -- 1.8: Setup.lua's auto keep-up does this (and respects keys you rebound).
  if Nock.KeepUpHandles and Nock.KeepUpHandles() then
    return
  end
  if InCombatLockdown() then
    return
  end
  local spec = NockCharDB.spec or "marks"
  local layout = LayoutFor(spec)
  local added = 0
  for key, entry in pairs(layout) do
    if Book.OwnsKey and Book.OwnsKey(key) then
      -- override-bound by Book; do not SaveBindings
    elseif entry.kind == "spell" and PlayerKnows(entry.name) then
      local current = GetBindingAction(key, true) or ""
      if current == "" then
        SetBindingSpell(key, entry.name)
        added = added + 1
        ShowNote(entry.name, true)
        if entry.slot and not HasAction(entry.slot) then
          ClearCursorSafe()
          if PickupEntry(entry) then
            PlaceAction(entry.slot)
            ClearCursorSafe()
          end
        end
      end
    end
  end
  if added > 0 then
    SaveBindings(GetCurrentBindingSet())
    Print("Added " .. added .. " newly trained spell(s) to your keyboard.")
  end
end

-- Overlay -----------------------------------------------------------------

local overlay

local CORE_ROWS = {
  { "1", "2", "3", "4", "5", "6" },
  { "Q", "E", "R", "F", "G", "T" },
}

local EXTRA_KEYS = {
  "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-F", "ALT-F",
  "CTRL-F", "SHIFT-X", "X", "Z", "SHIFT-E", "SHIFT-Q", "BUTTON4", "BUTTON5", "BUTTON3",
}

local function OverlayKeyLabel(key)
  if not key then
    return ""
  end
  -- Item tiles have no keybind of their own. Leave the icon clean;
  -- a word like "Hearth" is wider than the tile and clips.
  if key == "HEARTH" or key == "FOOD" then
    return ""
  end
  if key == "`" then
    return "`"
  end
  -- The game fonts have no modifier glyphs, so use Blizzard's own short form.
  -- 2.1: mouse buttons read M4, M5 and MMB (the wheel click).
  key = key:gsub("BUTTON3$", "MMB"):gsub("BUTTON(%d)$", "M%1")
  return (key:gsub("SHIFT%-", "S-"):gsub("ALT%-", "A-"):gsub("CTRL%-", "C-"))
end

-- Icon files the client keeps for every hunter spell. Used when a spell isn't
-- learned yet, because the spell API only returns icons for known spells.
local ICON_FALLBACK = {
  ["Auto Shot"] = "Ability_Whirlwind",
  ["Arcane Shot"] = "Ability_ImpalingBolt",
  ["Aimed Shot"] = "INV_Spear_07",
  ["Multi-Shot"] = "Ability_UpgradeMoonGlaive",
  ["Serpent Sting"] = "Ability_Hunter_Quickshot",
  ["Raptor Strike"] = "Ability_MeleeDamage",
  ["Mongoose Bite"] = "Ability_Hunter_SwiftStrike",
  ["Concussive Shot"] = "Spell_Frost_Stun",
  ["Feign Death"] = "Ability_Rogue_FeignDeath",
  ["Hunter's Mark"] = "Ability_Hunter_SniperShot",
  ["Freezing Trap"] = "Spell_Frost_ChainsOfIce",
  ["Frost Trap"] = "Spell_Frost_FreezingBreath",
  ["Immolation Trap"] = "Spell_Fire_FlameShock",
  ["Explosive Trap"] = "Spell_Fire_SelfDestruct",
  ["Mend Pet"] = "Ability_Hunter_MendPet",
  ["Call Pet"] = "Ability_Hunter_BeastCall",
  ["Revive Pet"] = "Ability_Hunter_BeastSoothe",
  ["Feed Pet"] = "Ability_Hunter_BeastTraining",
  ["Beast Training"] = "Ability_Hunter_BeastTraining",
  ["Rapid Fire"] = "Ability_Hunter_RunningShot",
  ["Bestial Wrath"] = "Ability_Druid_FerociousBite",
  ["Intimidation"] = "Ability_Devour",
  ["Trueshot Aura"] = "Ability_TrueShot",
  ["Aspect of the Hawk"] = "Spell_Nature_RavenForm",
  ["Aspect of the Cheetah"] = "Ability_Mount_JungleTiger",
  ["Aspect of the Viper"] = "Ability_Hunter_AspectoftheViper",
  ["Aspect of the Monkey"] = "Ability_Hunter_AspectOfTheMonkey",
  ["Aspect of the Pack"] = "Ability_Mount_WhiteTiger",
  ["Wing Clip"] = "Ability_Rogue_Trip",
  ["Hearthstone"] = "INV_Misc_Rune_01",
  ["Volley"] = "Ability_Marksmanship",
  ["Disengage"] = "Ability_Rogue_Feint",
  ["Tranquilizing Shot"] = "Spell_Nature_Drowsy",
  ["Flare"] = "Spell_Fire_Flare",
  ["Viper Sting"] = "Ability_Hunter_AimedShot",
  ["Scare Beast"] = "Ability_Druid_Cower",
  ["Mongoose Bite"] = "Ability_Hunter_SwiftStrike",
  ["Counterattack"] = "Ability_Warrior_Challange",
  ["Lacerate"] = "Ability_Druid_Lacerate",
  ["Strider Kick"] = "Ability_Hunter_SwiftStrike",
  ["Distracting Shot"] = "Spell_Arcane_Blink",
  ["Scatter Shot"] = "Ability_GolemStormBolt",
  ["Wyvern Sting"] = "INV_Spear_02",
  ["Scorpid Sting"] = "Ability_Hunter_CriticalShot",
  ["Eyes of the Beast"] = "Ability_EyeOfTheOwl",
  ["Eagle Eye"] = "Ability_Hunter_EagleEye",
  ["Beast Lore"] = "Ability_Physical_Taunt",
  ["Tame Beast"] = "Ability_Hunter_BeastTaming",
  ["Dismiss Pet"] = "Spell_Nature_SpiritWolf",
  ["Deterrence"] = "Ability_Whirlwind",
  ["Sniper Shot"] = "Ability_Hunter_SniperShot",
  ["Summon Hawk"] = "Spell_Nature_RavenForm",
  ["Lone Wolf"] = "Spell_Nature_SpiritWolf",
  ["Enchanted Flare"] = "Spell_Fire_Flare",
  ["Aspect of the Beast"] = "Ability_Mount_PinkTiger",
  ["Aspect of the Wild"] = "Spell_Nature_ProtectionformNature",
  ["Track Beasts"] = "Ability_Tracking",
  ["Track Humanoids"] = "Spell_Holy_PrayerOfHealing",
  ["Track Undead"] = "Spell_Shadow_DarkSummoning",
  ["Track Hidden"] = "Ability_Stealth",
  ["Track Elementals"] = "Spell_Frost_SummonWaterElemental",
  ["Track Demons"] = "Spell_Shadow_SummonFelHunter",
  ["Track Giants"] = "Ability_Racial_Avatar",
  ["Track Dragonkin"] = "INV_Misc_Head_Dragon_Red",
  ["Find Herbs"] = "INV_Misc_Flower_02",
  ["Find Minerals"] = "Spell_Nature_Earthquake",
}

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Spell a macro shows: its "requires" spell, else the #showtooltip line.
local function MacroSpell(entry)
  if entry.requires then
    return entry.requires
  end
  local body = entry.macro or entry.body or ""
  local spell = body:match("^#showtooltip ([^\n]+)")
  if spell and spell ~= "" then
    return spell
  end
  return body:match("/cast !?([^\n;%[]+)")
end

local function IconFor(nameOrEntry)
  local name = nameOrEntry
  if type(nameOrEntry) == "table" then
    if nameOrEntry.kind == "item" then
      name = nameOrEntry.name
      if GetItemIcon then
        local ok, icon = pcall(GetItemIcon, name)
        if ok and icon then
          return icon
        end
      end
      if GetItemInfo then
        local ok, _, _, _, _, _, _, _, _, icon = pcall(GetItemInfo, name)
        if ok and icon then
          return icon
        end
      end
    elseif nameOrEntry.kind == "macro" or nameOrEntry.macro or nameOrEntry.body then
      name = MacroSpell(nameOrEntry)
    else
      name = nameOrEntry.name
    end
  end
  if not name then
    return QUESTION_ICON
  end
  name = strtrim and strtrim(name) or name
  local _, icon = SpellData(name)
  if icon then
    return icon
  end
  if ICON_FALLBACK[name] then
    return "Interface\\Icons\\" .. ICON_FALLBACK[name]
  end
  return QUESTION_ICON
end

local function HasItem(name)
  if not name then
    return false
  end
  if GetItemCount then
    local ok, n = pcall(GetItemCount, name)
    if ok and type(n) == "number" and n > 0 then
      return true
    end
  end
  if C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, name)
    if ok and type(n) == "number" and n > 0 then
      return true
    end
  end
  return false
end

local function FindFoodName()
  if GetContainerNumSlots and GetContainerItemLink and GetItemInfo then
    for bag = 0, 4 do
      local ok, slots = pcall(GetContainerNumSlots, bag)
      if ok and type(slots) == "number" then
        for slot = 1, slots do
          local okL, link = pcall(GetContainerItemLink, bag, slot)
          if okL and type(link) == "string" then
            local okI, iname, _, _, _, _, itype, isub = pcall(GetItemInfo, link)
            if okI and iname and itype == "Consumable" then
              isub = isub or ""
              if isub == "Food & Drink" or isub == "Food" or isub:find("Food") or isub:find("Drink") then
                -- Skip water-only if we can tell; a food item is fine either way.
                return iname
              end
            end
          end
        end
      end
    end
  end
  return nil
end

local function ItemEntry(name, label)
  return { kind = "item", name = name, label = label or name }
end

local function EntryKnown(entry)
  if not entry then
    return false
  end
  if entry.kind == "item" then
    return HasItem(entry.name)
  end
  if entry.kind == "macro" then
    return (not entry.requires) or PlayerKnows(entry.requires)
  end
  if entry.racial then
    return true -- only in the layout when your spellbook has it
  end
  return PlayerKnows(entry.name) and true or false
end

-- Pet utility tiles only once Call Pet (or Mend / Feed) is in the book.
local function UtilKeyKnown(key, entry)
  if key == "HEARTH" or key == "FOOD" then
    return entry and EntryKnown(entry)
  end
  if key == "T" or key == "SHIFT-T" or key == "ALT-T" or key == "CTRL-G" then
    return PlayerKnows("Call Pet")
  end
  if not entry then
    return false
  end
  return EntryKnown(entry)
end

local function TipFor(spec)
  if spec == "bm" then
    return "Press 1 to start the fight (it sends your pet). Q slows. E plays dead. Aimed on one target, Multi on a pack."
  end
  return "Press 1 to start the fight (it sends your pet). Q slows. E plays dead. Aimed on one target, Multi on a pack. Keep Mark up."
end

local function ExtraLine(layout)
  local parts = {}
  for _, key in ipairs(EXTRA_KEYS) do
    local entry = layout[key]
    if entry then
      parts[#parts + 1] = "|cffffd100" .. OverlayKeyLabel(key) .. "|r " .. EntryLabel(entry)
    end
  end
  return table.concat(parts, "   ")
end

-- Tooltip-style art: the same border and background files GameTooltip uses.
local TOOLTIP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local CHIP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 10,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function SafeBackdrop(f, backdrop)
  if f.SetBackdrop then
    f:SetBackdrop(backdrop)
  end
end

-- 1.9: every tile is a real button. Clicking it casts what its key casts, via
-- Blizzard's SecureActionButtonTemplate (type = "spell" or "macro"). That is
-- the same as clicking an action-bar button: you press, the game casts.
-- Attributes, size, position and visibility change ONLY out of combat; in
-- combat the strip stays exactly as it was and repaints when combat ends.

local function InCombat()
  return InCombatLockdown and InCombatLockdown() or false
end

local function SpellIDFor(entry)
  local name = entry.kind == "macro" and MacroSpell(entry) or entry.name
  if not name then
    return nil
  end
  name = strtrim and strtrim(name) or name
  local _, _, id = SpellData(name)
  return id
end

-- Is this key bound to what the tile says?
local function KeyMatches(key, entry)
  return (GetBindingAction(key, true) or "") == BindingCommand(entry)
end

local function LearnLevel(entry)
  return entry.learnAt or (Nock.TrainerLevel and Nock.TrainerLevel[entry.requires or entry.name])
end

local function ChipTooltip(cap)
  if not GameTooltip then
    return
  end
  local entry, key = cap.entry, cap.key
  if not entry then
    return
  end
  GameTooltip:SetOwner(cap, "ANCHOR_TOP")
  local id = SpellIDFor(entry)
  if cap.known and id and GameTooltip.SetSpellByID then
    GameTooltip:SetSpellByID(id)
  else
    GameTooltip:SetText(EntryLabel(entry), 1, 0.82, 0)
  end
  if cap.known and cap.yours then
    GameTooltip:AddLine("Click to use. " .. OverlayKeyLabel(key) .. " already does something of yours, so Nock left it alone.", 0.25, 1, 0.25, true)
  elseif cap.known then
    if MOUSE_NAME[key] then
      GameTooltip:AddLine("Click, or press " .. MOUSE_NAME[key] .. " (" .. OverlayKeyLabel(key) .. ")", 0.25, 1, 0.25)
    elseif cap.twin then
      GameTooltip:AddLine("Click or press " .. OverlayKeyLabel(key) .. ", or " .. MOUSE_NAME[cap.twin], 0.25, 1, 0.25)
    else
      GameTooltip:AddLine("Click or press " .. OverlayKeyLabel(key), 0.25, 1, 0.25)
    end
    if entry.racial and entry.note then
      GameTooltip:AddLine("Racial: " .. entry.note, 0.79, 1, 0.88, true)
    end
    if entry.kind == "macro" then
      GameTooltip:AddLine("Nock macro: " .. entry.name, 0.62, 0.82, 1)
    end
    if cap.mismatch then
      GameTooltip:AddLine(OverlayKeyLabel(key) .. " already does something else, so Nock left that key alone.", 0.7, 0.7, 0.65, true)
    end
  elseif LearnLevel(entry) then
    GameTooltip:AddLine("Not learned yet. Trainer at level " .. LearnLevel(entry) .. ".", 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine("Not learned yet.", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- 2.0: the key bar. One slim moonwood strip docked above the action bars with
-- your core keys as square icons (no text). 2.0.1: built from your spellbook:
-- a tile shows only once you know its spell, plus your race's fight buttons. Each tile is a real button:
-- Blizzard's SecureActionButtonTemplate (type = "spell" or "macro"), the same
-- as clicking an action-bar button. Attributes, size, position and visibility
-- change ONLY out of combat; in combat the bar stays exactly as it was and
-- repaints when combat ends. The fade only changes alpha (allowed in combat).
-- 3.0 main bar: shots R and 1-5, then "it's on me" keys. Key 6 (Raptor family)
-- stays bound but is not on this bar (see PLAN-3.0). Mouse on: M4 / MMB.
-- Mouse off: Shift-Z (Wing Clip) and E (Feign). Wheel scrolling is never bound.
-- Racials (Alt-1 / Alt-E) sit on the utility row when you have them.
local BAR_KEYS_MOUSE = { "R", "1", "2", "3", "4", "5", "Q", "BUTTON4", "BUTTON3" }
local BAR_KEYS_KB = { "R", "1", "2", "3", "4", "5", "Q", "SHIFT-Z", "E" }
local BAR_KEYS_ALL = { "R", "1", "2", "3", "4", "5", "Q", "BUTTON4", "BUTTON3", "SHIFT-Z", "E" }
local BAR_KEYS = BAR_KEYS_MOUSE
local DIVIDER_BEFORE = "Q" -- small arrow divider: the "it's on me" keys follow

local function MainBarKeys()
  if MouseOn() then
    return BAR_KEYS_MOUSE
  end
  return BAR_KEYS_KB
end
-- Utility row groups (only known spells/items are shown).
-- 3.0.9: pet / aspects / traps live on the keyed extra rows (left-hand
-- binds). The utility tray only keeps racials and bag items.
local UTIL_GROUPS = {
  { "ALT-1", "ALT-E" }, -- racials, only if the layout has them
  { "HEARTH", "FOOD" },
}
local UTIL_KEYS = {}
for _, g in ipairs(UTIL_GROUPS) do
  for _, k in ipairs(g) do
    UTIL_KEYS[#UTIL_KEYS + 1] = k
  end
end
-- 3.0.4: Small is the old 40/32 tile size. Normal is in between. Large
-- (the default) is about 1.5x on the bow (~60 UI px, ~48-52 on a 1440p
-- screen at a typical UI scale) and about 1.3x on the utility row (42).
local UTIL_TILE, UTIL_GAP, UTIL_GRP, UTIL_PAD, UTIL_H = 42, 4, 18, 13, 56
local UTIL_GAP_Y = 12 -- space between the plaque and the utility tray
local TILE, GAP, PAD_X, BODY_H, DIV_W = 60, 7, 16, 84, 18
-- Caps keep the art's proportions and scale with the bar.
local CAP_H, FLETCH_W, HEAD_W, CAP_OVERLAP = 144, 280, 230, 12
-- Bow content in the 2048x512 TGA is 2035x384. Width is the plaque plus a
-- short overhang; height follows the art. The string is 34/384 of that
-- height above the texture bottom.
local BOW_OVERHANG = 24
local BOW_ASPECT = 384 / 2035
local BOW_STRING_FROM_BOTTOM = 34 / 384
-- 2px above the tiles (tiles sit 8px below the plaque top).
local BOW_STRING_OFFSET = -9
-- 3.0.5 packed XP textures (2048x256 frame/bg/ticks, 2048x128 fill/rested).
-- Insets are fractions of the on-screen frame (the full 2048x256 texture).
local XP_WIN_L, XP_WIN_R = 0.071495, 0.928505
local XP_WIN_T, XP_WIN_B = 0.431788, 0.636059
local XP_FILL_T, XP_FILL_B = 0.398361, 0.665771
local XP_FILL_U, XP_FILL_V = 0.901367, 0.562500
local XP_REST_U, XP_REST_V = 0.901367, 0.578125
local XP_SPARK_U0, XP_SPARK_V0 = 0.000000, 0.173828
local XP_SPARK_U1, XP_SPARK_V1 = 1.000000, 0.826172
local XP_BADGE_U0, XP_BADGE_V0 = 0.000000, 0.007812
local XP_BADGE_U1, XP_BADGE_V1 = 1.000000, 0.992188

-- Style-aware XP window / fill UVs. Emerald keeps the 3.0.5 packing;
-- Gunsmith uses the narrower lantern-ended barrel measured in uv.json.
-- On-screen widget size is unchanged; only the texture crop moves.
function Nock.XPUv()
  local T = _G.NockTheme
  local uv = T and T.XP and T.XP()
  if type(uv) == "table" and uv.winL then
    return uv
  end
  return {
    winL = XP_WIN_L, winR = XP_WIN_R, winT = XP_WIN_T, winB = XP_WIN_B,
    fillT = XP_FILL_T, fillB = XP_FILL_B, fillU = XP_FILL_U, fillV = XP_FILL_V,
    restU = XP_REST_U, restV = XP_REST_V,
  }
end
-- On-screen sizes; ApplySizeConstants overwrites these (defaults = Large).
local XP_FRAME_H, XP_BADGE, XP_GAP = 62, 78, 12
local XP_LEVEL_FONT, XP_PCT_FONT = 26, 12
local PET_TILE, PET_GAP, PET_GRP, PET_PAD, PET_H, PET_GAP_Y = 36, 5, 14, 10, 50, 8
local PET_CD_FONT, PET_TAG_FONT, NUM_PET_SLOTS = 18, 9, 10
local pendingSize = false

local function SizeKey()
  NockCharDB = NockCharDB or {}
  local k = NockCharDB.barSize
  if k == "small" or k == "normal" then
    return k
  end
  return "large"
end

local function ApplySizeConstants()
  local k = SizeKey()
  if k == "small" then
    TILE, GAP, PAD_X, BODY_H, DIV_W = 40, 5, 12, 56, 12
    UTIL_TILE, UTIL_GAP, UTIL_GRP, UTIL_PAD, UTIL_H = 32, 3, 14, 10, 44
    UTIL_GAP_Y, CAP_H, FLETCH_W, HEAD_W, CAP_OVERLAP = 10, 96, 195, 161, 8
    BOW_OVERHANG, BOW_STRING_OFFSET = 16, -6
    XP_FRAME_H, XP_BADGE, XP_GAP = 40, 52, 8
    XP_LEVEL_FONT, XP_PCT_FONT = 18, 10
    PET_TILE, PET_GAP, PET_GRP, PET_PAD, PET_H, PET_GAP_Y = 28, 3, 10, 8, 40, 6
    PET_CD_FONT, PET_TAG_FONT = 14, 8
  elseif k == "normal" then
    TILE, GAP, PAD_X, BODY_H, DIV_W = 50, 6, 14, 70, 15
    UTIL_TILE, UTIL_GAP, UTIL_GRP, UTIL_PAD, UTIL_H = 36, 4, 16, 12, 50
    UTIL_GAP_Y, CAP_H, FLETCH_W, HEAD_W, CAP_OVERLAP = 11, 120, 244, 201, 10
    BOW_OVERHANG, BOW_STRING_OFFSET = 20, -7
    XP_FRAME_H, XP_BADGE, XP_GAP = 50, 64, 10
    XP_LEVEL_FONT, XP_PCT_FONT = 22, 11
    PET_TILE, PET_GAP, PET_GRP, PET_PAD, PET_H, PET_GAP_Y = 32, 4, 12, 9, 44, 7
    PET_CD_FONT, PET_TAG_FONT = 16, 8
  else
    TILE, GAP, PAD_X, BODY_H, DIV_W = 60, 7, 16, 84, 18
    UTIL_TILE, UTIL_GAP, UTIL_GRP, UTIL_PAD, UTIL_H = 42, 4, 18, 13, 56
    UTIL_GAP_Y, CAP_H, FLETCH_W, HEAD_W, CAP_OVERLAP = 12, 144, 280, 230, 12
    BOW_OVERHANG, BOW_STRING_OFFSET = 24, -9
    XP_FRAME_H, XP_BADGE, XP_GAP = 62, 78, 12
    XP_LEVEL_FONT, XP_PCT_FONT = 26, 12
    PET_TILE, PET_GAP, PET_GRP, PET_PAD, PET_H, PET_GAP_Y = 36, 5, 14, 10, 50, 8
    PET_CD_FONT, PET_TAG_FONT = 18, 9
  end
end

local function TypeScale()
  local k = SizeKey()
  if k == "small" then
    return {
      insetM = 3, insetU = 2,
      badgeMW = 20, badgeMH = 15, badgeUW = 18, badgeUH = 14,
      badgeFontM = 13, badgeFontU = 12,
      cdM = 20, cdU = 16,
      mbadgeMW = 22, mbadgeUW = 20, paw = 16,
    }
  elseif k == "normal" then
    return {
      insetM = 3, insetU = 3,
      badgeMW = 24, badgeMH = 17, badgeUW = 22, badgeUH = 16,
      badgeFontM = 15, badgeFontU = 14,
      cdM = 24, cdU = 18,
      mbadgeMW = 25, mbadgeUW = 22, paw = 18,
    }
  end
  return {
    insetM = 4, insetU = 3,
    badgeMW = 28, badgeMH = 20, badgeUW = 24, badgeUH = 17,
    badgeFontM = 17, badgeFontU = 15,
    cdM = 28, cdU = 21,
    mbadgeMW = 28, mbadgeUW = 24, paw = 20,
  }
end

local FADE_ALPHA = 0.4

local function Theme()
  return _G.NockTheme
end

local function EnsureFont(fs, sizeOrObject, flags)
  local T = Theme()
  if T and T.EnsureFont then
    return T.EnsureFont(fs, sizeOrObject, flags)
  end
  if not fs or not fs.SetFont then
    return false
  end
  local path = (type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
  local size = type(sizeOrObject) == "number" and sizeOrObject or 12
  local ok, res = pcall(fs.SetFont, fs, path, size, flags or "OUTLINE")
  return ok and res ~= false
end

local function SetTex(tex, key, r, g, b, a)
  local T = Theme()
  if T then
    return T.SetTex(tex, key, r, g, b, a)
  end
  tex:SetColorTexture(r or 0.07, g or 0.12, b or 0.1, a or 0.9)
  return false
end

-- Crop unused padding out of a power-of-two TGA (left, right, top, bottom in 0-1).
local function SetCrop(tex, left, right, top, bottom)
  if tex and tex.SetTexCoord then
    pcall(tex.SetTexCoord, tex, left, right, top, bottom)
  end
end

local function BarDB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function IsPetKey(entry)
  if not entry or entry.kind ~= "macro" then
    return false
  end
  local body = entry.macro or entry.body or ""
  return body:find("/petattack", 1, true) and MacroSpell(entry) == "Auto Shot" and true or false
end

local chipN = 0
local hoverCheck -- forward
local Pet = {} -- filled in the 3.0.5 pet-bar section; keeps the 200-local cap
local buildWarned = {}
local function WarnOnce(key, msg)
  if buildWarned[key] then
    return
  end
  buildWarned[key] = true
  Print(msg)
end

-- One failed piece (XP, pet bar) must not stop the bow and tiles from loading.
local function SafeBuild(key, label, fn, ...)
  if not fn then
    return
  end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then
    WarnOnce(key, "The " .. label .. " couldn't load. The rest of the bar is still up.")
    if Nock.NoteError then
      Nock.NoteError(key, a)
    end
    return nil
  end
  return a, b, c
end

-- Big, bold, outlined labels with high contrast. Applied at create time
-- and again when the Bar size setting changes.
local function StyleChip(cap, isMain)
  if not cap then
    return
  end
  if isMain == nil then
    isMain = cap.isMain
  end
  cap.isMain = isMain and true or false
  local sc = TypeScale()
  local size = isMain and TILE or UTIL_TILE
  local inset = isMain and sc.insetM or sc.insetU
  cap:SetSize(size, size)
  cap.tileSize = size
  if cap.icon then
    cap.icon:ClearAllPoints()
    cap.icon:SetPoint("TOPLEFT", inset, -inset)
    cap.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    -- Keep the icon square and crop the default WoW icon border. Frame
    -- art (the tile ring) sits around this inset, never over the spell.
    if cap.icon.SetTexCoord then
      pcall(cap.icon.SetTexCoord, cap.icon, 0.07, 0.93, 0.07, 0.93)
    end
  end
  if cap.cd and cap.icon then
    cap.cd:ClearAllPoints()
    cap.cd:SetAllPoints(cap.icon)
  end
  local bw = isMain and sc.badgeMW or sc.badgeUW
  local bh = isMain and sc.badgeMH or sc.badgeUH
  if cap.badge then
    cap.badge:ClearAllPoints()
    if isMain then
      -- Tab on the bow tile's top-left corner, same for R / 1 / 2 / ....
      cap.badge:SetPoint("TOPLEFT", cap, "TOPLEFT", -2, 8)
    else
      -- Fully inside the tile, top-left, so the letter never sits as a tab.
      cap.badge:SetPoint("TOPLEFT", cap, "TOPLEFT", 3, -3)
    end
    cap.badge:SetSize(bw, bh)
  end
  if cap.cd then
    if cap.cd.SetHideCountdownNumbers then
      pcall(cap.cd.SetHideCountdownNumbers, cap.cd, true)
    end
    cap.cd.noCooldownCount = true
    cap.noCooldownCount = true
  end
  local font = (STANDARD_TEXT_FONT and type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT)
    or "Fonts\\FRIZQT__.TTF"
  local badgeFont = isMain and sc.badgeFontM or sc.badgeFontU
  local function Outline(fs, px, r, g, b)
    if not fs then
      return
    end
    if fs.SetFont then
      pcall(fs.SetFont, fs, font, px, "THICKOUTLINE")
    end
    fs:SetTextColor(r, g, b)
    if fs.SetShadowColor then
      fs:SetShadowColor(0, 0, 0, 1)
    end
    if fs.SetShadowOffset then
      fs:SetShadowOffset(1, -1)
    end
  end
  -- Cream on a dark badge, thick black outline: readable at 1440p.
  Outline(cap.label, badgeFont, 1, 0.98, 0.82)
  if cap.mbadge then
    cap.mbadge:ClearAllPoints()
    cap.mbadge:SetPoint("BOTTOMLEFT", cap, "BOTTOMLEFT", -2, -6)
    cap.mbadge:SetSize(isMain and sc.mbadgeMW or sc.mbadgeUW, bh - 1)
  end
  Outline(cap.mlabel, badgeFont, 0.55, 1, 0.92)
  if cap.paw then
    cap.paw:SetSize(sc.paw, sc.paw)
  end
  local cdFont = isMain and sc.cdM or sc.cdU
  -- Near-white countdown, thick black outline, high contrast on a dim icon.
  Outline(cap.cdText, cdFont, 1, 1, 0.92)
end

local function MakeChip(parent, size)
  chipN = chipN + 1
  -- Created only out of combat (CreateOverlay checks).
  local isMain = (size == nil)
  size = size or TILE
  local inset = isMain and 4 or 3
  local cap = CreateFrame("Button", "NockOverlayKey" .. chipN, parent, "SecureActionButtonTemplate")
  cap.isMain = isMain
  cap:SetSize(size, size)
  cap.tileSize = size
  if cap.RegisterForClicks then
    cap:RegisterForClicks("AnyUp", "AnyDown")
  end
  local back = cap:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.02, 0.05, 0.04, 1)
  local icon = cap:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", inset, -inset)
  icon:SetPoint("BOTTOMRIGHT", -inset, inset)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  cap.icon = icon
  local ring = cap:CreateTexture(nil, "OVERLAY", nil, 1)
  ring:SetPoint("TOPLEFT", -1, 1)
  ring:SetPoint("BOTTOMRIGHT", 1, -1)
  if not SetTex(ring, "tile") then
    ring:SetColorTexture(0, 0, 0, 0)
  end
  cap.ring = ring
  -- Main tiles: a tab on the top-left corner, outside the icon, so the
  -- letter does not cover the spell or the centered countdown.
  -- Utility / extra tiles: the same cream outlined letter, fully inside.
  local badge = cap:CreateTexture(nil, "OVERLAY", nil, 3)
  if isMain then
    badge:SetPoint("TOPLEFT", cap, "TOPLEFT", -2, 8)
  else
    badge:SetPoint("TOPLEFT", cap, "TOPLEFT", 3, -3)
  end
  badge:SetSize(18, 13)
  SetTex(badge, "keybadge", 0.05, 0.09, 0.07, 0.95)
  cap.badge = badge
  local kl = cap:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  EnsureFont(kl, "NumberFontNormalSmall")
  kl:SetDrawLayer("OVERLAY", 7)
  kl:SetPoint("CENTER", badge, "CENTER", 0, 0)
  cap.label = kl
  -- 2.1: mouse badge (M5 / MMB), bottom left, in kiting teal.
  local mbadge = cap:CreateTexture(nil, "OVERLAY", nil, 3)
  mbadge:SetPoint("BOTTOMLEFT", cap, "BOTTOMLEFT", -2, -6)
  mbadge:SetSize(22, 12)
  SetTex(mbadge, "keybadge", 0.03, 0.14, 0.13, 0.95)
  if mbadge.SetVertexColor then mbadge:SetVertexColor(0.55, 1, 0.95) end
  mbadge:Hide()
  cap.mbadge = mbadge
  local ml = cap:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  EnsureFont(ml, "NumberFontNormalSmall")
  ml:SetDrawLayer("OVERLAY", 7)
  ml:SetPoint("CENTER", mbadge, "CENTER", 0, 0)
  ml:SetText("")
  ml:Hide()
  cap.mlabel = ml
  local paw = cap:CreateTexture(nil, "OVERLAY", nil, 4)
  paw:SetSize(16, 16)
  paw:SetPoint("BOTTOMRIGHT", 6, -6)
  if not SetTex(paw, "paw") then
    paw:SetColorTexture(0, 0, 0, 0)
  end
  paw:Hide()
  cap.paw = paw
  local lvl = cap:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(lvl, "GameFontDisableSmall")
  lvl:SetPoint("BOTTOM", 0, 3)
  lvl:SetTextColor(0.61, 0.77, 0.69)
  cap.lvl = lvl
  local bang = cap:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(bang, "GameFontNormalLarge")
  bang:SetPoint("TOPRIGHT", -2, -1)
  bang:SetTextColor(1, 0.25, 0.2)
  bang:SetText("!")
  bang:Hide()
  cap.bang = bang
  -- 2.0.1: cooldown swipe, big countdown number and an emerald "ready" flash.
  local okCd, cd = pcall(CreateFrame, "Cooldown", "NockOverlayKey" .. chipN .. "Cooldown", cap, "CooldownFrameTemplate")
  if not okCd or not cd then
    okCd, cd = pcall(CreateFrame, "Cooldown", nil, cap)
  end
  if okCd and cd then
    cd:SetAllPoints(icon)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0.06, 0.03, 0.72) end
    -- Our own number below; Blizzard's is the fallback if ours can't be read.
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    -- OmniCC and similar skip tiles that set this.
    cd.noCooldownCount = true
    cap.noCooldownCount = true
    cap.cd = cd
  end
  local cdText = cap:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  EnsureFont(cdText, "GameFontHighlightLarge")
  -- Above the key-badge art (layer 3) and label (layer 7 is only the
  -- corner letters, which stay in the corner). Centered on the icon.
  cdText:SetDrawLayer("OVERLAY", 8)
  cdText:SetPoint("CENTER", icon, "CENTER", 0, -1)
  cdText:SetText("")
  cap.cdText = cdText
  local flash = cap:CreateTexture(nil, "OVERLAY", nil, 5)
  flash:SetPoint("TOPLEFT", -7, 7)
  flash:SetPoint("BOTTOMRIGHT", 7, -7)
  if not SetTex(flash, "glow") then
    flash:SetColorTexture(0.3, 1, 0.6, 0.35)
  end
  flash:SetVertexColor(0.3, 1, 0.62)
  if flash.SetBlendMode then flash:SetBlendMode("ADD") end
  flash:SetAlpha(0)
  flash:Hide()
  cap.flash = flash
  local hl = cap:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(icon)
  hl:SetColorTexture(0.5, 1, 0.75, 0.15)
  cap.hl = hl
  cap.spell = { SetText = function() end, SetTextColor = function() end } -- 1.x field, kept for callers
  cap:SetScript("OnEnter", function(self)
    ChipTooltip(self)
    hoverCheck(true)
  end)
  cap:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
    hoverCheck()
  end)
  StyleChip(cap, isMain)
  return cap
end

-- Secure attributes. Out of combat only.
local function SetChipAction(cap, entry, known)
  if InCombat() then
    return false
  end
  if entry and known then
    if entry.kind == "macro" then
      cap:SetAttribute("type", "macro")
      cap:SetAttribute("macro", entry.name)
      cap:SetAttribute("spell", nil)
      cap:SetAttribute("item", nil)
    elseif entry.kind == "item" then
      cap:SetAttribute("type", "item")
      cap:SetAttribute("item", entry.name)
      cap:SetAttribute("spell", nil)
      cap:SetAttribute("macro", nil)
    else
      -- The rank-free name casts the highest rank you know.
      cap:SetAttribute("type", "spell")
      cap:SetAttribute("spell", entry.name)
      cap:SetAttribute("macro", nil)
      cap:SetAttribute("item", nil)
    end
  else
    -- Not learned yet: dimmed and not clickable until it is.
    cap:SetAttribute("type", nil)
    cap:SetAttribute("spell", nil)
    cap:SetAttribute("macro", nil)
    cap:SetAttribute("item", nil)
  end
  return true
end

-- Returns true if the tile's key holds something else.
local function PaintChip(cap, key, entry)
  if not cap then
    return false
  end
  cap.key, cap.entry = key, entry
  if not entry then
    SetChipAction(cap, nil, false)
    cap.known, cap.mismatch = false, false
    cap:Hide()
    return false
  end
  local known = EntryKnown(entry)
  local macroMissing = false
  if entry.kind == "macro" and known and GetMacroIndexByName(entry.name) == 0 then
    known = false -- the macro doesn't exist yet: Set me up makes it
    macroMissing = true
  end
  if not known and not macroMissing then
    -- 2.0.1: not in your spellbook yet, so no tile. It appears when you learn it.
    SetChipAction(cap, nil, false)
    cap.known, cap.mismatch, cap.yours = false, false, false
    cap:Hide()
    return false
  end
  -- A racial on a key that already holds something of yours: the tile still
  -- casts it, the key stays yours, and nothing asks you to set up again.
  local cur = GetBindingAction(key, true) or ""
  local userOwned = NockCharDB.userKeys and NockCharDB.userKeys[key] ~= nil
  local yours = known and cur ~= BindingCommand(entry) and ((entry.ifFree and cur ~= "") or userOwned) or false
  local mismatch = known and not yours and not KeyMatches(key, entry)
  cap.known, cap.mismatch, cap.yours = known, mismatch, yours
  SetChipAction(cap, entry, known)
  cap:Show()
  local label = yours and "" or OverlayKeyLabel(key)
  cap.label:SetText(label)
  if not label or label == "" then
    cap.badge:Hide()
    if cap.label.Hide then cap.label:Hide() end
  else
    local w = (cap.label.GetStringWidth and cap.label:GetStringWidth()) or 10
    if type(w) ~= "number" or w <= 0 or w > 60 then
      w = 10
    end
    -- Keep the badge inside the tile on util / extra chips.
    local tileW = cap.tileSize or (cap.isMain and TILE or UTIL_TILE) or 42
    local maxW = math.max(16, tileW - 6)
    cap.badge:SetWidth(math.min(maxW, math.max(16, w + 9)))
    cap.badge:Show()
    if cap.label.Show then cap.label:Show() end
  end
  local lvl = not known and LearnLevel(entry)
  cap.lvl:SetText(lvl and ("Lv" .. lvl) or "")
  cap.bang:Hide() -- 3.0: no ! marks; his keys stay his, no setup nag
  if IsPetKey(entry) then cap.paw:Show() else cap.paw:Hide() end
  -- 2.1: a second, mouse badge when the mouse button really casts this too.
  local twin = MOUSE_TWIN[key]
  local twinEntry = twin and cap.layout and cap.layout[twin]
  cap.twin = nil
  if known and twinEntry and KeyMatches(twin, twinEntry) then
    cap.twin = twin
    cap.mlabel:SetText(OverlayKeyLabel(twin))
    local mw = (cap.mlabel.GetStringWidth and cap.mlabel:GetStringWidth()) or 14
    if type(mw) ~= "number" or mw <= 0 or mw > 60 then
      mw = 14
    end
    cap.mbadge:SetWidth(math.max(18, mw + 8))
    cap.mbadge:Show()
    cap.mlabel:Show()
  else
    cap.mbadge:Hide()
    cap.mlabel:Hide()
  end
  cap.icon:SetTexture(IconFor(entry))
  cap.icon:SetDesaturated(not known)
  cap.icon:SetAlpha(known and 1 or 0.45)
  if mismatch then
    cap.ring:SetVertexColor(1, 0.35, 0.3)
  elseif known then
    cap.ring:SetVertexColor(1, 1, 1)
  else
    cap.ring:SetVertexColor(0.55, 0.6, 0.58)
  end
  if known then
    cap.label:SetTextColor(0.79, 1, 0.88)
    cap.hl:Show()
  else
    cap.label:SetTextColor(0.5, 0.58, 0.54)
    cap.hl:Hide()
  end
  return mismatch
end


-- Cooldowns, range and mana (2.0.1) ----------------------------------------------
-- The same things Blizzard's action buttons show: a swipe while a spell is on
-- cooldown (GCD still gets a sweep, but no countdown number), the time left, red when the
-- target is out of range and blue when you lack the mana. Display only.
-- Everything is pcall-guarded: if the client hides a value, the tile just
-- shows Blizzard's own swipe and numbers instead.
local GCD_MAX = 1.5
local cdTicker

local function CooldownOpt()
  return BarDB().barCooldowns ~= false
end

local function TintOpt()
  return BarDB().barTint ~= false
end

local function ChipSpell(cap)
  local e = cap and cap.entry
  if not e then
    return nil
  end
  if e.kind == "item" then
    return nil
  end
  -- Secure macro tiles (F melee, track cycle) stash the shown spell here.
  if cap.spellName and cap.spellName ~= "" then
    return (strtrim and strtrim(cap.spellName) or cap.spellName)
  end
  local name = e.kind == "macro" and MacroSpell(e) or e.name
  return name and (strtrim and strtrim(name) or name) or nil
end

local function SpellCooldown(name)
  if not name then
    return nil
  end
  -- Duration object first: Forever rejects secret numbers in SetCooldown
  -- from addon code, but accepts this object on SetCooldownFromDurationObject.
  local obj
  if C_Spell and C_Spell.GetSpellCooldownDuration then
    local ok, o = pcall(C_Spell.GetSpellCooldownDuration, name)
    if ok and o then
      obj = o
    end
  end
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, name)
    if ok and type(info) == "table" then
      return info.startTime, info.duration, info.isEnabled, info.modRate, info.isOnGCD, obj or info
    end
  end
  if GetSpellCooldown then
    local ok, s, d, en, mod = pcall(GetSpellCooldown, name)
    if ok then
      return s, d, en, mod, nil, obj
    end
  end
  if obj then
    return nil, nil, nil, nil, nil, obj
  end
  return nil
end

-- Item cooldowns (Hearthstone, food) — Forever-safe fallbacks, no OmniCC.
local function ItemIDFor(name)
  if not name then
    return nil
  end
  if GetItemInfoInstant then
    local ok, id = pcall(GetItemInfoInstant, name)
    if ok and type(id) == "number" then
      return id
    end
  end
  if C_Item and C_Item.GetItemIDForItemInfo then
    local ok, id = pcall(C_Item.GetItemIDForItemInfo, name)
    if ok and type(id) == "number" then
      return id
    end
  end
  if GetItemInfo then
    local ok, itemName, link = pcall(GetItemInfo, name)
    if ok and type(link) == "string" then
      local id = link:match("item:(%d+)")
      if id then
        return tonumber(id)
      end
    end
  end
  return nil
end

local function ItemCooldown(name)
  if not name then
    return nil
  end
  local id = ItemIDFor(name)
  local function unpackCD(ok, a, b, c, d)
    if not ok then
      return nil
    end
    if type(a) == "table" then
      return a.startTime or a.start, a.duration, a.isEnabled or a.enable, a.modRate
    end
    return a, b, c, d
  end
  local function hasCD(s, d, en, mer)
    local ok, ss, dd = pcall(function()
      return tonumber(s) or 0, tonumber(d) or 0
    end)
    if not ok then
      -- Secret values: keep the originals so the swipe path can use a duration object.
      return s, d, en, mer
    end
    if dd > 0 then
      return ss, dd, en, mer
    end
  end
  if GetItemCooldown then
    local s, d, en, mer = hasCD(unpackCD(pcall(GetItemCooldown, name)))
    if d then
      return s, d, en, mer
    end
    if id then
      s, d, en, mer = hasCD(unpackCD(pcall(GetItemCooldown, id)))
      if d then
        return s, d, en, mer
      end
    end
  end
  if C_Item and C_Item.GetItemCooldown and id then
    local s, d, en, mod = unpackCD(pcall(C_Item.GetItemCooldown, id))
    if s then
      return s, d, en, mod
    end
  end
  if C_Container and C_Container.GetItemCooldown and id then
    local s, d, en, mod = unpackCD(pcall(C_Container.GetItemCooldown, id))
    if s then
      return s, d, en, mod
    end
  end
  return nil
end

-- Same-school traps share a 30s cooldown in Forever (Frost: Freezing + Frost;
-- Fire: Immolation + Explosive). Show that shared CD on both tiles.
local TRAP_SCHOOL = {
  ["Freezing Trap"] = { "Freezing Trap", "Frost Trap" },
  ["Frost Trap"] = { "Freezing Trap", "Frost Trap" },
  ["Immolation Trap"] = { "Immolation Trap", "Explosive Trap" },
  ["Explosive Trap"] = { "Immolation Trap", "Explosive Trap" },
}

local function LongestCooldown(names)
  local bestS, bestD, bestE, bestM, bestG, bestLeft, bestObj
  local now = GetTime and GetTime() or 0
  local fallbackObj
  for _, name in ipairs(names) do
    local s, d, en, mod, g, obj = SpellCooldown(name)
    if obj and not fallbackObj then
      fallbackObj = obj
    end
    local ok, left, ss, dd = pcall(function()
      local a, b = tonumber(s) or 0, tonumber(d) or 0
      if a > 0 and b > 0 then
        return a + b - now, a, b
      end
    end)
    if ok and left then
      if not bestLeft or left > bestLeft then
        bestS, bestD, bestE, bestM, bestG, bestLeft, bestObj = ss, dd, en, mod, g, left, obj
      end
    end
  end
  if bestS then
    return bestS, bestD, bestE, bestM, bestG, bestObj
  end
  return nil, nil, nil, nil, nil, fallbackObj
end

-- Start/duration for whatever the tile casts: a spell, a macro's spell
-- (Call/Revive checks both), a shared trap school, or an item.
local function ChipCooldown(cap)
  local e = cap and cap.entry
  if not e then
    return nil
  end
  if e.kind == "item" then
    return ItemCooldown(e.name)
  end
  local names = {}
  local spell = ChipSpell(cap)
  if spell then
    names[#names + 1] = spell
  end
  if spell and TRAP_SCHOOL[spell] then
    names = TRAP_SCHOOL[spell]
  end
  -- Call / Revive shares a tile: include Revive Pet so its longer CD shows.
  if e.kind == "macro" and e.name == "Nock:Pet" then
    names[#names + 1] = "Call Pet"
    names[#names + 1] = "Revive Pet"
  end
  -- F melee: show the longer of Mongoose Bite / Raptor Strike.
  if cap.rec and cap.rec.id == "melee" then
    names[#names + 1] = "Mongoose Bite"
    names[#names + 1] = "Raptor Strike"
  end
  if #names == 0 then
    return nil
  end
  if #names == 1 then
    return SpellCooldown(names[1])
  end
  return LongestCooldown(names)
end

local function FormatLeft(left)
  left = tonumber(left)
  if not left or left <= 0 then
    return ""
  end
  -- Whole seconds only. Never "15.42".
  if left >= 60 then
    return string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
  end
  return string.format("%d", math.ceil(left))
end

local function ClearCooldown(cap)
  if cap.cd then
    if cap.cd.Clear then
      cap.cd:Clear()
    else
      cap.cd:SetCooldown(0, 0)
    end
  end
  cap.cdEnd = nil
  cap.cdText:SetText("")
end

local function ReadyFlash(cap)
  local f = cap.flash
  if not f then
    return
  end
  cap.flashT = 0.6
  f:Show()
  f:SetAlpha(0.8)
end

-- Only pass numbers we can prove aren't secret into SetCooldown. Forever
-- rejects secret start/duration from addon (tainted) code.
local function ReadableNumber(v)
  if v == nil then
    return nil
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then
      return nil
    end
  end
  local ok, n = pcall(tonumber, v)
  if ok and type(n) == "number" then
    return n
  end
  return nil
end

local function ApplyChipSwipe(cap, start, dur, mod, obj)
  if not cap or not cap.cd then
    return false
  end
  if cap.cd.SetCooldownFromDurationObject then
    if obj and pcall(cap.cd.SetCooldownFromDurationObject, cap.cd, obj) then
      return true
    end
    local name = ChipSpell(cap) or (cap.entry and cap.entry.name)
    if C_Spell and C_Spell.GetSpellCooldownDuration and name then
      local ok, durObj = pcall(C_Spell.GetSpellCooldownDuration, name)
      if ok and durObj and pcall(cap.cd.SetCooldownFromDurationObject, cap.cd, durObj) then
        return true
      end
    end
  end
  local s, d = ReadableNumber(start), ReadableNumber(dur)
  if s and d then
    local m = ReadableNumber(mod)
    return pcall(cap.cd.SetCooldown, cap.cd, s, d, m or 1)
  end
  -- Never pass a secret number into SetCooldown from this addon.
  return false
end

local function UpdateChipCooldown(cap)
  if not cap or not cap.cdText then
    return
  end
  if not (cap.known and CooldownOpt() and cap.entry) then
    ClearCooldown(cap)
    return
  end
  local start, dur, enabled, mod, onGCD, obj = ChipCooldown(cap)
  if start == nil and dur == nil and obj == nil then
    ClearCooldown(cap)
    return
  end
  -- Classify: "real" = long cooldown (swipe + our countdown), "gcd" = GCD
  -- only (swipe is fine, no number), nil = nothing running.
  local readable, kind, finish = pcall(function()
    local s, d = tonumber(start) or 0, tonumber(dur) or 0
    if s <= 0 or d <= 0 then
      return nil
    end
    if d > GCD_MAX then
      return "real", s + d
    end
    -- GCD (or a 1s aspect swap): sweep only, never a countdown number.
    return "gcd", s + d
  end)
  if not readable then
    -- Secret values: swipe via the duration-object API (never SetCooldown
    -- with the secret numbers). Let the cooldown frame draw its own numbers
    -- because we cannot safely format a countdown ourselves.
    ApplyChipSwipe(cap, start, dur, mod, obj)
    if cap.cd and cap.cd.SetHideCountdownNumbers then
      pcall(cap.cd.SetHideCountdownNumbers, cap.cd, false)
    end
    cap.cdEnd = nil
    cap.cdText:SetText("")
    return
  end
  if cap.cd and cap.cd.SetHideCountdownNumbers then
    pcall(cap.cd.SetHideCountdownNumbers, cap.cd, true)
  end
  if kind == "real" then
    ApplyChipSwipe(cap, start, dur, mod, obj)
    cap.cdEnd = finish
    cap.cdGcd = nil
  elseif kind == "gcd" then
    ApplyChipSwipe(cap, start, dur, mod, obj)
    -- Sweep only: do not tick a number, and don't flash when the GCD ends.
    cap.cdEnd = nil
    cap.cdGcd = true
    cap.cdText:SetText("")
  else
    if cap.cdEnd then
      ReadyFlash(cap) -- a real cooldown just finished
    end
    cap.cdGcd = nil
    ClearCooldown(cap)
  end
end

local function SpellUsable(name)
  local usable, noMana
  if C_Spell and C_Spell.IsSpellUsable then
    local ok, u, n = pcall(C_Spell.IsSpellUsable, name)
    if ok then
      usable, noMana = u, n
    end
  elseif IsUsableSpell then
    local ok, u, n = pcall(IsUsableSpell, name)
    if ok then
      usable, noMana = u, n
    end
  end
  return usable, noMana
end

-- Forever may return secret values for unit and range APIs. A secret is
-- truthy, so "if UnitExists('target')" would pass even with no target and
-- then a false/0 from IsSpellInRange painted every tile red.
local function ReadableFlag(v)
  if v == nil then
    return nil
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then
      return nil
    end
  end
  local ok, out = pcall(function()
    if v == true or v == 1 then
      return true
    end
    if v == false or v == 0 then
      return false
    end
    return nil
  end)
  if not ok then
    return nil
  end
  return out
end

local function HasHostileTarget()
  if not UnitExists then
    return false
  end
  local ok, exists = pcall(UnitExists, "target")
  if not ok or ReadableFlag(exists) ~= true then
    return false
  end
  if UnitIsDead then
    local okd, dead = pcall(UnitIsDead, "target")
    if okd and ReadableFlag(dead) == true then
      return false
    end
  end
  if UnitCanAttack then
    local oka, atk = pcall(UnitCanAttack, "player", "target")
    return oka and ReadableFlag(atk) == true
  end
  if UnitIsEnemy then
    local oke, en = pcall(UnitIsEnemy, "player", "target")
    return oke and ReadableFlag(en) == true
  end
  -- Target exists but we cannot prove it is hostile: do not tint red.
  return false
end

local function SpellOutOfRange(name)
  if not name or not HasHostileTarget() then
    return false
  end
  local r
  if C_Spell and C_Spell.IsSpellInRange then
    local ok, v = pcall(C_Spell.IsSpellInRange, name, "target")
    if ok then
      r = v
    end
  elseif IsSpellInRange then
    local ok, v = pcall(IsSpellInRange, name, "target")
    if ok then
      r = v
    end
  end
  -- Only a clear out-of-range result counts. nil / secret / errors: no tint.
  return ReadableFlag(r) == false
end

-- Ready = bright. On a real cooldown = dimmed (range/mana tints still show
-- through, just darker). GCD swipe does not dim.
local CD_DIM = 0.38

local function UpdateChipTint(cap)
  if not cap or not cap.icon then
    return
  end
  if not cap.known then
    cap.icon:SetVertexColor(1, 1, 1)
    return
  end
  local name = TintOpt() and ChipSpell(cap)
  local r, g, b = 1, 1, 1
  -- Items (hearth, food) have no spell range. Never paint them red.
  local kind = cap.entry and cap.entry.kind
  if name and kind ~= "item" then
    local ok, which = pcall(function()
      if SpellOutOfRange(name) then
        return "range"
      end
      local usable, noMana = SpellUsable(name)
      -- Blue only when the API clearly says "not enough mana".
      if ReadableFlag(noMana) == true then
        return "mana"
      end
      return nil
    end)
    if ok and which == "range" then
      r, g, b = 0.9, 0.25, 0.25
    elseif ok and which == "mana" then
      r, g, b = 0.35, 0.45, 1
    end
  end
  if cap.cdEnd then
    r, g, b = r * CD_DIM, g * CD_DIM, b * CD_DIM
  end
  cap.icon:SetVertexColor(r, g, b)
end

local function ForEachChip(fn)
  if not overlay then
    return
  end
  if overlay.caps then
    for _, key in ipairs(BAR_KEYS_ALL) do
      local cap = overlay.caps[key]
      if cap and cap:IsShown() then
        fn(cap)
      end
    end
  end
  if overlay.utilCaps then
    for _, key in ipairs(UTIL_KEYS) do
      local cap = overlay.utilCaps[key]
      if cap and cap:IsShown() then
        fn(cap)
      end
    end
  end
  if Book.ForEachChip then
    Book.ForEachChip(fn)
  end
end

local function UpdateCooldowns()
  ForEachChip(UpdateChipCooldown)
  ForEachChip(UpdateChipTint)
  SafeBuild("pet", "pet bar", Pet.UpdatePetCooldowns)
end

local function UpdateTints()
  ForEachChip(UpdateChipTint)
  if Book.UpdateMeleeGlow then
    Book.UpdateMeleeGlow()
  end
  if Book.UpdateTrackVisuals then
    Book.UpdateTrackVisuals()
  end
end

-- One light ticker for the numbers, the flash fade and range (5x a second).
local function TickBar(_, elapsed)
  if not overlay or not overlay:IsShown() then
    return
  end
  elapsed = tonumber(elapsed) or 0
  local now = GetTime and GetTime() or 0
  overlay.tintT = (overlay.tintT or 0) - elapsed
  local doTint = overlay.tintT <= 0
  if doTint then
    overlay.tintT = 0.2
  end
  ForEachChip(function(cap)
    if cap.cdEnd then
      local left = cap.cdEnd - now
      if left > 0 then
        cap.cdText:SetText(FormatLeft(left))
        if left < 5 then
          cap.cdText:SetTextColor(0.55, 1, 0.7)
        else
          cap.cdText:SetTextColor(0.79, 1, 0.88)
        end
      else
        ReadyFlash(cap)
        ClearCooldown(cap)
      end
    end
    if cap.flashT then
      cap.flashT = cap.flashT - elapsed
      if cap.flashT <= 0 then
        cap.flashT = nil
        cap.flash:SetAlpha(0)
        cap.flash:Hide()
      else
        cap.flash:SetAlpha(0.8 * cap.flashT / 0.6)
      end
    end
    if doTint then
      UpdateChipTint(cap)
    end
  end)
  Pet.ForEachPetChip(function(cap)
    if cap.cdEnd then
      local left = cap.cdEnd - now
      if left > 0 then
        cap.cdText:SetText(FormatLeft(left))
        if left < 5 then
          cap.cdText:SetTextColor(0.55, 1, 0.7)
        else
          cap.cdText:SetTextColor(0.79, 1, 0.88)
        end
      else
        ReadyFlash(cap)
        ClearCooldown(cap)
      end
    end
    if cap.flashT and cap.flash then
      cap.flashT = cap.flashT - elapsed
      if cap.flashT <= 0 then
        cap.flashT = nil
        cap.flash:SetAlpha(0)
        cap.flash:Hide()
      else
        cap.flash:SetAlpha(0.8 * cap.flashT / 0.6)
      end
    end
  end)
end

function Nock.SetBarCooldowns(on)
  BarDB().barCooldowns = on and true or false
  UpdateCooldowns()
end

function Nock.SetBarTint(on)
  BarDB().barTint = on and true or false
  if not on then
    ForEachChip(function(cap)
      cap.icon:SetVertexColor(1, 1, 1)
    end)
  end
  UpdateTints()
end
Nock.UpdateBarCooldowns = UpdateCooldowns
Nock.UpdateBarTints = UpdateTints
Nock.FormatCooldown = FormatLeft

local function ProfileLabel()
  local p = Nock.ActiveProfile and Nock.ActiveProfile()
  if p then
    return p.label
  end
  local spec = NockCharDB.spec
  if spec == "bm" then
    return "Beast Mastery"
  elseif spec == "marks" then
    return "Marksmanship"
  end
  return "Not applied yet"
end


-- Nock's own experience bar. We never move Blizzard's StatusTrackingBarManager.
local function ReadableNumber(v)
  if type(v) ~= "number" then
    return nil
  end
  if issecretvalue and issecretvalue(v) then
    return nil
  end
  if canaccessvalue and not canaccessvalue(v) then
    return nil
  end
  return v
end

local function IsMaxLevel()
  local lvl, max
  pcall(function()
    lvl = UnitLevel and UnitLevel("player")
    max = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 60
  end)
  return type(lvl) == "number" and type(max) == "number" and lvl >= max
end

local function NockXPWanted()
  NockCharDB = NockCharDB or {}
  if NockCharDB.nockXP == false then
    return false
  end
  return not IsMaxLevel()
end

local function XPTipText(cur, maxv, rest)
  cur = cur or 0
  maxv = maxv or 1
  rest = rest or 0
  local pct = 0
  if maxv > 0 then
    pct = math.floor((cur / maxv) * 100 + 0.5)
  end
  return string.format("XP: %d / %d (%d%%)  Rested: %d", cur, maxv, pct, rest)
end

local function UpdateXPBar()
  local wrap = overlay and overlay.xp
  if not wrap then
    return
  end
  if not NockXPWanted() then
    wrap:Hide()
    wrap.tipText = nil
    return
  end
  local cur, maxv, rest, level
  pcall(function()
    cur = UnitXP and UnitXP("player")
    maxv = UnitXPMax and UnitXPMax("player")
    rest = GetXPExhaustion and GetXPExhaustion()
    level = UnitLevel and UnitLevel("player")
  end)
  cur = ReadableNumber(cur) or wrap.cur or 0
  maxv = ReadableNumber(maxv) or wrap.maxv or 1
  rest = ReadableNumber(rest)
  if rest == nil then
    rest = wrap.rest or 0
  end
  level = ReadableNumber(level) or wrap.level or 1
  if maxv <= 0 then
    maxv = 1
  end
  wrap.cur, wrap.maxv, wrap.rest, wrap.level = cur, maxv, rest, level
  wrap.tipText = XPTipText(cur, maxv, rest)
  local frac = math.min(1, cur / maxv)
  local rfrac = math.min(1, (cur + rest) / maxv)
  wrap.frac = frac
  wrap.pctText = string.format("%d%%", math.floor(frac * 100 + 0.5))
  if wrap.levelFS then
    wrap.levelFS:SetText(tostring(level))
  end
  if wrap.pctFS then
    wrap.pctFS:SetText(wrap.pctText)
  end

  local bar = wrap.bar or wrap
  local barW = wrap.barW or 0
  local frameH = wrap.frameH or XP_FRAME_H
  local uv = Nock.XPUv()
  local winX = barW * uv.winL
  local winW = barW * (uv.winR - uv.winL)
  local fillY = frameH * uv.fillT
  local fillH = frameH * (uv.fillB - uv.fillT)
  if fillH < 1 then
    fillH = 1
  end

  local function placeStrip(tex, amount, uMax, vMax)
    if not tex then
      return
    end
    if amount <= 0 or winW <= 0 then
      tex:Hide()
      return
    end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", bar, "TOPLEFT", winX, -fillY)
    tex:SetSize(math.max(1, winW * amount), fillH)
    if tex.SetTexCoord then
      pcall(tex.SetTexCoord, tex, 0, uMax * amount, 0, vMax)
    end
    tex:Show()
  end

  if rest and rest > 0 and rfrac > 0 then
    placeStrip(wrap.restTex, rfrac, uv.restU, uv.restV)
  elseif wrap.restTex then
    wrap.restTex:Hide()
  end
  if frac > 0 then
    placeStrip(wrap.fillTex, frac, uv.fillU, uv.fillV)
    if wrap.spark then
      local sparkH = fillH * 2.4
      local sparkW = sparkH * ((XP_SPARK_U1 - XP_SPARK_U0) / math.max(0.01, XP_SPARK_V1 - XP_SPARK_V0))
      local fillRight = winX + winW * frac
      wrap.spark:ClearAllPoints()
      wrap.spark:SetSize(sparkW, sparkH)
      wrap.spark:SetPoint("RIGHT", bar, "TOPLEFT", fillRight + sparkW * 0.02, -(fillY + fillH / 2))
      wrap.spark:Show()
    end
  else
    if wrap.fillTex then
      wrap.fillTex:Hide()
    end
    if wrap.spark then
      wrap.spark:Hide()
    end
  end
  if wrap.pctFS then
    wrap.pctFS:ClearAllPoints()
    wrap.pctFS:SetPoint("CENTER", bar, "TOPLEFT", winX + winW / 2, -(frameH * (uv.winT + uv.winB) / 2))
  end
  wrap:Show()
end

local function StyleXP(wrap)
  if not wrap then
    return
  end
  local badgeH = XP_BADGE
  local frameH = XP_FRAME_H
  wrap.badgeH = badgeH
  wrap.frameH = frameH
  wrap.overlap = math.floor(badgeH * 0.28 + 0.5)
  wrap:SetHeight(math.max(badgeH, frameH))
  if wrap.badge and wrap.badge.SetSize then
    wrap.badge:SetSize(badgeH, badgeH)
  end
  if wrap.bar then
    wrap.bar:SetHeight(frameH)
  end
  local font = (STANDARD_TEXT_FONT and type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT)
    or "Fonts\\FRIZQT__.TTF"
  local function Outline(fs, px, r, g, b)
    if not fs then
      return
    end
    if fs.SetFont then
      pcall(fs.SetFont, fs, font, px, "THICKOUTLINE")
    end
    if fs.SetTextColor then
      fs:SetTextColor(r, g, b)
    end
    if fs.SetShadowColor then
      fs:SetShadowColor(0, 0, 0, 1)
    end
    if fs.SetShadowOffset then
      fs:SetShadowOffset(1, -1)
    end
  end
  Outline(wrap.levelFS, XP_LEVEL_FONT, 1, 0.98, 0.82)
  Outline(wrap.pctFS, XP_PCT_FONT, 1, 0.98, 0.86)
end

local function XPHoverOn(self)
  if self.pctFS and self.pctText then
    self.pctFS:SetText(self.pctText)
    self.pctFS:Show()
  end
  if not GameTooltip or not self.tipText then
    return
  end
  pcall(function()
    if GameTooltip.SetOwner then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
    end
    if GameTooltip.SetText then
      GameTooltip:SetText(self.tipText)
    elseif GameTooltip.AddLine then
      GameTooltip:ClearLines()
      GameTooltip:AddLine(self.tipText)
    end
    GameTooltip:Show()
  end)
end

local function XPHoverOff(self)
  if self and self.pctFS then
    self.pctFS:Hide()
  end
  if GameTooltip then
    GameTooltip:Hide()
  end
end

local function MakeXPBar(parent)
  local wrap = CreateFrame("Frame", "NockXPBar", parent)
  wrap:EnableMouse(true)

  local badge = CreateFrame("Frame", "NockXPBadge", wrap)
  badge:EnableMouse(true)
  local badgeTex = badge:CreateTexture(nil, "OVERLAY")
  badgeTex:SetAllPoints()
  SetTex(badgeTex, "xp_badge", 0.18, 0.11, 0.06, 1)
  SetCrop(badgeTex, XP_BADGE_U0, XP_BADGE_U1, XP_BADGE_V0, XP_BADGE_V1)
  wrap.badge = badge
  wrap.badgeTex = badgeTex

  local levelFS = badge:CreateFontString(nil, "OVERLAY")
  EnsureFont(levelFS, XP_LEVEL_FONT, "THICKOUTLINE")
  levelFS:SetPoint("CENTER", badge, "CENTER", 0, 1)
  levelFS:SetText("")
  wrap.levelFS = levelFS

  local bar = CreateFrame("Frame", "NockXPTrack", wrap)
  wrap.bar = bar

  local function layerTex(owner, drawLayer, sub, key, r, g, b)
    local t = owner:CreateTexture(nil, drawLayer)
    if t.SetDrawLayer and sub then
      pcall(t.SetDrawLayer, t, drawLayer, sub)
    end
    t:SetAllPoints(bar)
    SetTex(t, key, r, g, b, 1)
    return t
  end

  wrap.bg = layerTex(bar, "BACKGROUND", 0, "xp_bg", 0.05, 0.10, 0.06)
  wrap.restTex = bar:CreateTexture(nil, "ARTWORK")
  if wrap.restTex.SetDrawLayer then
    pcall(wrap.restTex.SetDrawLayer, wrap.restTex, "ARTWORK", 0)
  end
  SetTex(wrap.restTex, "xp_rested", 0.45, 0.95, 0.70, 1)
  wrap.fillTex = bar:CreateTexture(nil, "ARTWORK")
  if wrap.fillTex.SetDrawLayer then
    pcall(wrap.fillTex.SetDrawLayer, wrap.fillTex, "ARTWORK", 1)
  end
  SetTex(wrap.fillTex, "xp_fill", 0.20, 0.72, 0.45, 1)
  wrap.ticks = layerTex(bar, "ARTWORK", 2, "xp_ticks", 0.95, 0.86, 0.40)
  wrap.frameTex = layerTex(bar, "OVERLAY", 0, "xp_frame", 0.18, 0.11, 0.06)

  local spark = bar:CreateTexture(nil, "OVERLAY")
  if spark.SetDrawLayer then
    pcall(spark.SetDrawLayer, spark, "OVERLAY", 1)
  end
  SetTex(spark, "xp_spark", 0.6, 1, 0.5, 1)
  SetCrop(spark, XP_SPARK_U0, XP_SPARK_U1, XP_SPARK_V0, XP_SPARK_V1)
  if spark.SetBlendMode then
    pcall(spark.SetBlendMode, spark, "ADD")
  end
  spark:Hide()
  wrap.spark = spark

  local pctFS = bar:CreateFontString(nil, "OVERLAY")
  EnsureFont(pctFS, XP_PCT_FONT, "THICKOUTLINE")
  pctFS:SetPoint("CENTER", bar, "CENTER", 0, 0)
  pctFS:Hide()
  wrap.pctFS = pctFS

  wrap:SetScript("OnEnter", XPHoverOn)
  wrap:SetScript("OnLeave", XPHoverOff)
  badge:SetScript("OnEnter", function()
    XPHoverOn(wrap)
  end)
  badge:SetScript("OnLeave", function()
    XPHoverOff(wrap)
  end)
  StyleXP(wrap)
  wrap:Hide()
  return wrap
end

local function LayoutXP(utilW, bodyW)
  local wrap = overlay and overlay.xp
  if not wrap then
    return 0
  end
  if not NockXPWanted() then
    wrap:Hide()
    return 0
  end
  StyleXP(wrap)
  -- Always the full Large bow width. Do not shrink to the util tray
  -- (which may be a single Hearth tile).
  local bowW = (tonumber(bodyW) or 0) + FLETCH_W + HEAD_W - 2 * CAP_OVERLAP
  local barW = math.max(bowW, tonumber(bodyW) or 0)
  if barW < 200 then
    barW = 200
  end
  wrap.barW = barW
  wrap:SetWidth(barW)
  wrap:SetHeight(math.max(XP_BADGE, XP_FRAME_H))
  if wrap.bar then
    wrap.bar:SetWidth(barW)
    wrap.bar:SetHeight(XP_FRAME_H)
    wrap.bar:ClearAllPoints()
    wrap.bar:SetPoint("CENTER", wrap, "CENTER", 0, 0)
  end
  if wrap.badge then
    wrap.badge:ClearAllPoints()
    wrap.badge:SetPoint("RIGHT", wrap.bar or wrap, "LEFT", wrap.overlap or 0, 0)
  end
  wrap:ClearAllPoints()
  if overlay.extra and overlay.extra:IsShown() then
    wrap:SetPoint("TOP", overlay.extra, "BOTTOM", 0, -XP_GAP)
  elseif overlay.util and overlay.util:IsShown() then
    wrap:SetPoint("TOP", overlay.util, "BOTTOM", 0, -XP_GAP)
  else
    wrap:SetPoint("TOP", overlay.body, "BOTTOM", 0, -XP_GAP)
  end
  UpdateXPBar()
  if wrap:IsShown() then
    return math.max(XP_BADGE, XP_FRAME_H) + XP_GAP
  end
  return 0
end

-- Lays the visible tiles out left to right and sizes the bar around them.
local function LayoutUtil(shown)
  local tray = overlay.util
  if not tray then
    return 0
  end
  local groups, any = {}, false
  for _, keys in ipairs(UTIL_GROUPS) do
    local g = {}
    for _, key in ipairs(keys) do
      if shown[key] then
        g[#g + 1] = key
        any = true
      end
    end
    if #g > 0 then
      groups[#groups + 1] = g
    end
  end
  if not any then
    tray:Hide()
    return 0
  end
  local inner = 0
  for i, g in ipairs(groups) do
    if i > 1 then
      inner = inner + UTIL_GRP
    end
    inner = inner + #g * UTIL_TILE + (#g - 1) * UTIL_GAP
  end
  local trayW = inner + 2 * UTIL_PAD
  tray:SetWidth(trayW)
  tray:Show()
  local x = UTIL_PAD
  for gi, g in ipairs(groups) do
    if gi > 1 then
      local div = tray.divs and tray.divs[gi - 1]
      if div then
        div:ClearAllPoints()
        div:SetPoint("LEFT", tray, "LEFT", x + UTIL_GRP / 2 - 1, 0)
        div:Show()
      end
      x = x + UTIL_GRP
    end
    for _, key in ipairs(g) do
      local cap = overlay.utilCaps[key]
      cap:ClearAllPoints()
      cap:SetPoint("LEFT", tray, "LEFT", x, 0)
      x = x + UTIL_TILE + UTIL_GAP
    end
  end
  if tray.divs then
    for i = #groups, #tray.divs do
      tray.divs[i]:Hide()
    end
  end
  return trayW
end

-- 3.0.5: Nock's own pet bar (secure pet-action buttons). Blizzard's
-- PetActionBar stays hidden while Nock is hiding the default bars.
-- Packed into one table so the file stays under Lua 5.1's 200-local cap.

-- Pet table is declared earlier (200-local cap).
Pet.TRAIN_NAMES = { "Beast Training", "Train Pet", "Pet Training" }
Pet.TRAIN_IDS = { 5149 }
Pet.FEED_NAMES = { "Feed Pet" }
Pet.FEED_IDS = { 6991 }

Pet.TOKEN_ICON = {
  PET_ACTION_ATTACK = "Ability_GhoulFrenzy",
  PET_ACTION_FOLLOW = "Ability_Tracking",
  PET_ACTION_WAIT = "Spell_Nature_TimeStop",
  PET_ACTION_MOVE_TO = "Ability_Hunter_Pet_Goto",
  PET_MODE_AGGRESSIVE = "Ability_Racial_BloodRage",
  PET_MODE_DEFENSIVE = "Ability_Defend",
  PET_MODE_PASSIVE = "Ability_Seal",
  PET_MODE_ASSIST = "Ability_Hunter_Pet_Assist",
  PET_ATTACK_TEXTURE = "Ability_GhoulFrenzy",
  PET_FOLLOW_TEXTURE = "Ability_Tracking",
  PET_WAIT_TEXTURE = "Spell_Nature_TimeStop",
  PET_AGGRESSIVE_TEXTURE = "Ability_Racial_BloodRage",
  PET_DEFENSIVE_TEXTURE = "Ability_Defend",
  PET_PASSIVE_TEXTURE = "Ability_Seal",
}

function Pet.NockPetWanted()
  if BarDB().nockPet == false then
    return false
  end
  if BarDB().overlay == false then
    return false
  end
  -- Avoid a second pet bar when the default bars have been restored.
  if Nock.ActionBars and Nock.ActionBars.Enabled and not Nock.ActionBars.Enabled() then
    return false
  end
  return true
end

function Pet.PlayerHasPet()
  local exists, hasBar, hasUI
  pcall(function()
    if UnitExists then
      exists = UnitExists("pet")
    end
  end)
  pcall(function()
    if PetHasActionBar then
      hasBar = PetHasActionBar()
    end
  end)
  pcall(function()
    if HasPetUI then
      hasUI = HasPetUI()
    end
  end)
  if ReadableFlag(exists) == false then
    return false
  end
  if ReadableFlag(exists) == true then
    return true
  end
  if ReadableFlag(hasBar) == true or ReadableFlag(hasUI) == true then
    return true
  end
  return false
end

function Pet.KnownHunterSpell(names, ids)
  names = names or {}
  for _, name in ipairs(names) do
    local ok, known, spellID, spellName, icon = pcall(PlayerKnows, name)
    if ok and known then
      return spellName or name, spellID, icon
    end
  end
  for _, sid in ipairs(ids or {}) do
    local known
    pcall(function()
      if IsPlayerSpell then
        known = IsPlayerSpell(sid)
      end
    end)
    if ReadableFlag(known) ~= true then
      pcall(function()
        if IsSpellKnown then
          known = IsSpellKnown(sid)
        end
      end)
    end
    if ReadableFlag(known) == true then
      local spellName, icon, spellID = SpellData(sid)
      return spellName or names[1], spellID or sid, icon
    end
    local spellName, icon, spellID = SpellData(sid)
    if spellName then
      local ok, isKnown, id, resolved, ic = pcall(PlayerKnows, spellName)
      if ok and isKnown then
        return resolved or spellName, id or spellID or sid, ic or icon
      end
    end
  end
end

function Pet.IconPath(texture)
  if type(texture) == "number" then
    return texture
  end
  if type(texture) ~= "string" or texture == "" then
    return nil
  end
  local g = _G[texture]
  if type(g) == "string" then
    texture = g
  elseif Pet.TOKEN_ICON[texture] then
    texture = Pet.TOKEN_ICON[texture]
  end
  if type(texture) == "string" and not texture:find("\\") and not texture:find("/") then
    return "Interface\\Icons\\" .. texture
  end
  return texture
end

function Pet.PrettyToken(name)
  if type(name) ~= "string" then
    return name
  end
  local g = _G[name]
  if type(g) == "string" and g ~= "" then
    return g
  end
  if name == "PET_ACTION_WAIT" then
    return "Stay"
  end
  local s = name:gsub("^PET_ACTION_", ""):gsub("^PET_MODE_", ""):gsub("_", " ")
  s = s:lower()
  return s:sub(1, 1):upper() .. s:sub(2)
end

function Pet.GetPetSlot(i)
  if type(GetPetActionInfo) ~= "function" then
    return nil
  end
  local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID
  local ok = pcall(function()
    name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(i)
  end)
  if not ok then
    return nil
  end
  if (name == nil or name == "") and (texture == nil or texture == "") then
    return nil
  end
  local token = ReadableFlag(isToken) == true
  local display = name
  if token then
    display = Pet.PrettyToken(name)
  end
  local usable = true
  if type(GetPetActionSlotUsable) == "function" then
    local u
    pcall(function()
      u = GetPetActionSlotUsable(i)
    end)
    local f = ReadableFlag(u)
    if f == false then
      usable = false
    end
  end
  return {
    slot = i,
    name = name,
    display = display or name or ("Pet " .. i),
    texture = texture,
    isToken = token,
    isActive = ReadableFlag(isActive) == true,
    autoCastAllowed = ReadableFlag(autoCastAllowed) == true,
    autoCastEnabled = ReadableFlag(autoCastEnabled) == true,
    spellID = ReadableNumber(spellID),
    usable = usable,
  }
end

function Pet.PetGroup(info)
  local n = (info and info.name) or ""
  if info and (info.isToken or (type(n) == "string" and n:find("^PET_"))) then
    if n:find("MODE", 1, true) or n:find("AGGRESSIVE", 1, true) or n:find("DEFENSIVE", 1, true)
        or n:find("PASSIVE", 1, true) or n:find("ASSIST", 1, true) then
      return "stance"
    end
    return "command"
  end
  return "ability"
end

function Pet.StylePetChip(cap)
  if not cap then
    return
  end
  local size = cap.isSpell and PET_TILE or PET_TILE
  cap:SetSize(size, size)
  cap.tileSize = size
  local inset = 3
  if cap.icon then
    cap.icon:ClearAllPoints()
    cap.icon:SetPoint("TOPLEFT", inset, -inset)
    cap.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
  end
  if cap.cd and cap.icon then
    cap.cd:ClearAllPoints()
    cap.cd:SetAllPoints(cap.icon)
  end
  if cap.shine then
    local s = 6
    if cap.shine[1] then cap.shine[1]:SetPoint("TOPLEFT", cap, "TOPLEFT", 1, -1); cap.shine[1]:SetSize(s, s) end
    if cap.shine[2] then cap.shine[2]:SetPoint("TOPRIGHT", cap, "TOPRIGHT", -1, -1); cap.shine[2]:SetSize(s, s) end
    if cap.shine[3] then cap.shine[3]:SetPoint("BOTTOMLEFT", cap, "BOTTOMLEFT", 1, 1); cap.shine[3]:SetSize(s, s) end
    if cap.shine[4] then cap.shine[4]:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", -1, 1); cap.shine[4]:SetSize(s, s) end
  end
  local font = (STANDARD_TEXT_FONT and type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT)
    or "Fonts\\FRIZQT__.TTF"
  if cap.cdText and cap.cdText.SetFont then
    pcall(cap.cdText.SetFont, cap.cdText, font, PET_CD_FONT, "THICKOUTLINE")
  end
  if cap.cdText and cap.cdText.SetTextColor then
    cap.cdText:SetTextColor(1, 1, 0.92)
  end
  if cap.tag and cap.tag.SetFont then
    pcall(cap.tag.SetFont, cap.tag, font, PET_TAG_FONT, "OUTLINE")
  end
end

function Pet.PaintPetVisual(cap)
  if not cap or not cap.icon then
    return
  end
  local info = cap.petInfo
  local bright = false
  local autoOn, autoAllow = false, false
  if cap.isSpell then
    bright = true
  elseif info then
    autoOn = info.autoCastEnabled
    autoAllow = info.autoCastAllowed
    bright = info.isActive or autoOn
  end
  if cap.icon.SetVertexColor then
    if cap.isSpell then
      cap.icon:SetVertexColor(1, 1, 1)
    elseif not info then
      cap.icon:SetVertexColor(0.35, 0.35, 0.35)
    elseif not info.usable and not bright then
      cap.icon:SetVertexColor(0.32, 0.32, 0.32)
    elseif bright then
      cap.icon:SetVertexColor(1, 1, 1)
    else
      cap.icon:SetVertexColor(0.42, 0.42, 0.42)
    end
  end
  if cap.icon.SetAlpha then
    cap.icon:SetAlpha((bright or cap.isSpell) and 1 or 0.72)
  end
  -- Emerald border when on; dull wood when off.
  if cap.border then
    for _, t in ipairs(cap.border) do
      if bright or cap.isSpell then
        t:SetColorTexture(0.25, 0.95, 0.55, 0.95)
      else
        t:SetColorTexture(0.32, 0.28, 0.16, 0.85)
      end
      t:Show()
    end
  end
  if cap.glow then
    if bright and not cap.isSpell then
      cap.glow:SetAlpha(0.55)
      cap.glow:Show()
    else
      cap.glow:SetAlpha(0)
      cap.glow:Hide()
    end
  end
  if cap.shine then
    if autoOn then
      for _, t in ipairs(cap.shine) do
        t:SetColorTexture(1, 0.95, 0.35, 1)
        t:Show()
      end
    elseif autoAllow then
      for _, t in ipairs(cap.shine) do
        t:SetColorTexture(0.55, 0.5, 0.28, 0.8)
        t:Show()
      end
    else
      for _, t in ipairs(cap.shine) do
        t:Hide()
      end
    end
  end
  cap.bright = bright and true or false
  cap.autoOn = autoOn and true or false
end

function Pet.PetTooltip(cap)
  if not GameTooltip or not cap then
    return
  end
  pcall(function()
    if GameTooltip.SetOwner then
      GameTooltip:SetOwner(cap, "ANCHOR_TOP")
    end
    local info = cap.petInfo
    if cap.spellName then
      if GameTooltip.SetSpellByID and cap.spellID then
        GameTooltip:SetSpellByID(cap.spellID)
      elseif GameTooltip.SetText then
        GameTooltip:SetText(cap.spellName)
        if GameTooltip.AddLine then
          if cap.role == "train" then
            GameTooltip:AddLine("Opens the pet training window.", 0.8, 1, 0.85)
          elseif cap.role == "feed" then
            GameTooltip:AddLine("Feed your pet to keep it happy.", 0.8, 1, 0.85)
          end
        end
      end
    elseif info and GameTooltip.SetPetAction then
      GameTooltip:SetPetAction(info.slot)
    elseif info and GameTooltip.SetText then
      GameTooltip:SetText(info.display or info.name or "")
      if GameTooltip.AddLine then
        if info.isActive then
          GameTooltip:AddLine("Active", 0.4, 1, 0.6)
        end
        if info.autoCastAllowed then
          if info.autoCastEnabled then
            GameTooltip:AddLine("Autocast is on. Right-click to turn it off.", 1, 0.95, 0.6)
          else
            GameTooltip:AddLine("Autocast is off. Right-click to turn it on.", 0.75, 0.75, 0.6)
          end
        end
      end
    end
    GameTooltip:Show()
  end)
end

function Pet.MakePetChip(parent, name, isSpell)
  local cap = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  cap.isSpell = isSpell and true or false
  cap:SetSize(PET_TILE, PET_TILE)
  cap.tileSize = PET_TILE
  if cap.RegisterForClicks then
    cap:RegisterForClicks("AnyUp", "AnyDown")
  end
  local back = cap:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.02, 0.05, 0.04, 1)
  local icon = cap:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", -3, 3)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  cap.icon = icon
  local ring = cap:CreateTexture(nil, "OVERLAY", nil, 1)
  ring:SetPoint("TOPLEFT", -1, 1)
  ring:SetPoint("BOTTOMRIGHT", 1, -1)
  if not SetTex(ring, "tile") then
    ring:SetColorTexture(0, 0, 0, 0)
  end
  cap.ring = ring
  cap.border = {}
  local function edge(p1, rp1, x1, y1, p2, rp2, x2, y2, w, h)
    local t = cap:CreateTexture(nil, "OVERLAY", nil, 4)
    t:SetColorTexture(0.32, 0.28, 0.16, 0.85)
    t:SetPoint(p1, cap, rp1, x1, y1)
    t:SetPoint(p2, cap, rp2, x2, y2)
    if w then t:SetWidth(w) end
    if h then t:SetHeight(h) end
    cap.border[#cap.border + 1] = t
  end
  edge("TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, 0, nil, 2)
  edge("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, nil, 2)
  edge("TOPLEFT", "TOPLEFT", 0, 0, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, 2, nil)
  edge("TOPRIGHT", "TOPRIGHT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, 2, nil)
  local glow = cap:CreateTexture(nil, "OVERLAY", nil, 2)
  glow:SetPoint("TOPLEFT", -6, 6)
  glow:SetPoint("BOTTOMRIGHT", 6, -6)
  if not SetTex(glow, "glow") then
    glow:SetColorTexture(0.25, 1, 0.5, 0.35)
  end
  glow:SetVertexColor(0.3, 1, 0.55)
  if glow.SetBlendMode then
    glow:SetBlendMode("ADD")
  end
  glow:SetAlpha(0)
  glow:Hide()
  cap.glow = glow
  cap.shine = {}
  for i = 1, 4 do
    local t = cap:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetSize(6, 6)
    t:SetColorTexture(1, 0.95, 0.35, 1)
    t:Hide()
    cap.shine[i] = t
  end
  local okCd, cd = pcall(CreateFrame, "Cooldown", name and (name .. "Cooldown") or nil, cap, "CooldownFrameTemplate")
  if not okCd or not cd then
    okCd, cd = pcall(CreateFrame, "Cooldown", nil, cap)
  end
  if okCd and cd then
    cd:SetAllPoints(icon)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0.06, 0.03, 0.72) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    cap.cd = cd
  end
  local cdText = cap:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  EnsureFont(cdText, PET_CD_FONT, "THICKOUTLINE")
  if cdText.SetDrawLayer then
    cdText:SetDrawLayer("OVERLAY", 8)
  end
  cdText:SetPoint("CENTER", icon, "CENTER", 0, -1)
  cdText:SetText("")
  cap.cdText = cdText
  local tag = cap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(tag, PET_TAG_FONT, "OUTLINE")
  tag:SetPoint("BOTTOM", cap, "BOTTOM", 0, 1)
  tag:SetText("")
  tag:Hide()
  cap.tag = tag
  local hl = cap:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(icon)
  hl:SetColorTexture(0.5, 1, 0.75, 0.15)
  cap:SetScript("OnEnter", function(self)
    Pet.PetTooltip(self)
    hoverCheck(true)
  end)
  cap:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
    hoverCheck()
  end)
  Pet.StylePetChip(cap)
  cap:Hide()
  return cap
end

function Pet.MakePetBar(parent)
  local wrap = CreateFrame("Frame", "NockPetBar", parent)
  wrap:EnableMouse(true)
  wrap:SetScript("OnEnter", function()
    hoverCheck(true)
  end)
  wrap:SetScript("OnLeave", function()
    hoverCheck()
  end)
  local wood = wrap:CreateTexture(nil, "BACKGROUND")
  wood:SetAllPoints()
  if not SetTex(wood, "barwood", 0.16, 0.10, 0.05, 0.96) then
    wood:SetColorTexture(0.10, 0.07, 0.04, 0.94)
  end
  if wood.SetVertexColor then
    wood:SetVertexColor(0.82, 0.82, 0.82)
  end
  wrap.wood = wood

  local info = CreateFrame("Frame", "NockPetInfo", wrap)
  wrap.info = info
  local happ = info:CreateTexture(nil, "OVERLAY")
  happ:SetSize(16, 16)
  happ:SetPoint("LEFT", info, "LEFT", 6, 0)
  if not SetTex(happ, "paw") then
    happ:SetColorTexture(0.3, 0.9, 0.4, 1)
  end
  wrap.happIcon = happ
  -- Invisible hover target on the happiness icon.
  local happHot = CreateFrame("Frame", nil, info)
  happHot:SetPoint("TOPLEFT", happ, "TOPLEFT", -2, 2)
  happHot:SetPoint("BOTTOMRIGHT", happ, "BOTTOMRIGHT", 2, -2)
  happHot:EnableMouse(true)
  happHot:SetScript("OnEnter", function()
    if not GameTooltip or not wrap.happTip then
      return
    end
    pcall(function()
      if GameTooltip.SetOwner then
        GameTooltip:SetOwner(happHot, "ANCHOR_TOP")
      end
      if GameTooltip.SetText then
        GameTooltip:SetText(wrap.happTip)
      end
      GameTooltip:Show()
    end)
    hoverCheck(true)
  end)
  happHot:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
    hoverCheck()
  end)
  wrap.happHot = happHot
  local infoText = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(infoText, 11, "OUTLINE")
  infoText:SetPoint("LEFT", happ, "RIGHT", 5, 0)
  infoText:SetPoint("RIGHT", info, "RIGHT", -4, 0)
  infoText:SetJustifyH("LEFT")
  infoText:SetTextColor(0.85, 0.95, 0.86)
  wrap.infoText = infoText

  wrap.caps = {}
  for i = 1, NUM_PET_SLOTS do
    local cap = Pet.MakePetChip(wrap, "NockPetBtn" .. i, false)
    cap.slot = i
    wrap.caps[i] = cap
  end
  wrap.divs = {}
  for i = 1, 3 do
    local d = wrap:CreateTexture(nil, "ARTWORK")
    d:SetWidth(1)
    d:SetColorTexture(0.55, 0.75, 0.6, 0.6)
    d:Hide()
    wrap.divs[i] = d
  end
  wrap.train = Pet.MakePetChip(wrap, "NockPetTrain", true)
  wrap.train.role = "train"
  wrap.train.tag:SetText("Train")
  wrap.feed = Pet.MakePetChip(wrap, "NockPetFeed", true)
  wrap.feed.role = "feed"
  wrap.feed.tag:SetText("Feed")
  wrap:Hide()
  return wrap
end

function Pet.SetSpellChip(cap, spellName, spellID, icon, role)
  cap.spellName = spellName
  cap.spellID = spellID
  cap.role = role
  cap.known = spellName and true or false
  cap.entry = spellName and { kind = "spell", name = spellName } or nil
  if not InCombat() then
    if spellName then
      cap:SetAttribute("type", "spell")
      cap:SetAttribute("spell", spellName)
      cap:SetAttribute("type1", "spell")
      cap:SetAttribute("spell1", spellName)
    else
      cap:SetAttribute("type", nil)
      cap:SetAttribute("spell", nil)
      cap:SetAttribute("type1", nil)
      cap:SetAttribute("spell1", nil)
    end
  end
  if spellName then
    local path = Pet.IconPath(icon) or (ICON_FALLBACK[spellName] and ("Interface\\Icons\\" .. ICON_FALLBACK[spellName]))
    if path and cap.icon.SetTexture then
      cap.icon:SetTexture(path)
    elseif cap.icon.SetColorTexture then
      cap.icon:SetColorTexture(0.15, 0.35, 0.2, 1)
    end
    if cap.tag then
      cap.tag:SetText(role == "feed" and "Feed" or "Train")
      cap.tag:Show()
    end
    Pet.PaintPetVisual(cap)
    if not InCombat() then
      cap:Show()
    end
  else
    if cap.tag then
      cap.tag:Hide()
    end
    if not InCombat() then
      cap:Hide()
    end
  end
end

function Pet.SetPetChipAction(cap, info)
  if InCombat() then
    cap.petInfo = info
    if info then
      Pet.PaintPetVisual(cap)
    end
    return
  end
  cap.petInfo = info
  cap.slot = info and info.slot or cap.slot
  if not info then
    cap:SetAttribute("type", nil)
    cap:SetAttribute("type1", nil)
    cap:SetAttribute("action", nil)
    cap:SetAttribute("action1", nil)
    cap:SetAttribute("type2", nil)
    cap:SetAttribute("macrotext2", nil)
    cap:Hide()
    return
  end
  cap:SetAttribute("type", "pet")
  cap:SetAttribute("action", info.slot)
  cap:SetAttribute("type1", "pet")
  cap:SetAttribute("action1", info.slot)
  if info.autoCastAllowed and info.display and info.display ~= "" then
    cap:SetAttribute("type2", "macro")
    cap:SetAttribute("macrotext2", "/petautocasttoggle " .. info.display)
  else
    cap:SetAttribute("type2", nil)
    cap:SetAttribute("macrotext2", nil)
  end
  local path = Pet.IconPath(info.texture)
  if (not path) and info.name and Pet.TOKEN_ICON[info.name] then
    path = Pet.IconPath(Pet.TOKEN_ICON[info.name])
  end
  if path and cap.icon.SetTexture then
    cap.icon:SetTexture(path)
  elseif cap.icon.SetColorTexture then
    cap.icon:SetColorTexture(0.2, 0.25, 0.18, 1)
  end
  Pet.PaintPetVisual(cap)
  cap:Show()
end

function Pet.UpdatePetInfoStrip(wrap)
  if not wrap or not wrap.info then
    return
  end
  local name, level, loyalty, happ, dmg, unspent, total, spent
  pcall(function()
    if UnitName then
      name = UnitName("pet")
    end
  end)
  pcall(function()
    if UnitLevel then
      level = UnitLevel("pet")
    end
  end)
  level = ReadableNumber(level)
  pcall(function()
    if GetPetLoyalty then
      loyalty = GetPetLoyalty()
    end
  end)
  pcall(function()
    if GetPetHappiness then
      happ, dmg = GetPetHappiness()
    end
  end)
  happ = ReadableNumber(happ)
  dmg = ReadableNumber(dmg)
  pcall(function()
    if GetPetTrainingPoints then
      total, spent = GetPetTrainingPoints()
    end
  end)
  total, spent = ReadableNumber(total), ReadableNumber(spent)
  if total and spent then
    unspent = total - spent
    if unspent < 0 then
      -- If the client returns spent, total instead, swap.
      unspent = spent - total
      total, spent = spent, total
    end
  end
  wrap.petName = (type(name) == "string" and name ~= "") and name or nil
  wrap.petLevel = level
  wrap.loyalty = loyalty
  wrap.happ = happ
  wrap.unspent = unspent
  wrap.tpTotal = total
  wrap.tpSpent = spent

  if happ == 3 then
    wrap.happTip = "Happy" .. (dmg and string.format("  (%d%% damage)", dmg) or "  (more damage)")
    if wrap.happIcon.SetVertexColor then
      wrap.happIcon:SetVertexColor(0.3, 1, 0.4)
    end
    wrap.happIcon:Show()
  elseif happ == 2 then
    wrap.happTip = "Content" .. (dmg and string.format("  (%d%% damage)", dmg) or "  (normal damage)")
    if wrap.happIcon.SetVertexColor then
      wrap.happIcon:SetVertexColor(1, 0.88, 0.25)
    end
    wrap.happIcon:Show()
  elseif happ == 1 then
    wrap.happTip = "Unhappy" .. (dmg and string.format("  (%d%% damage)", dmg) or "  (less damage)") .. ". Feed it."
    if wrap.happIcon.SetVertexColor then
      wrap.happIcon:SetVertexColor(1, 0.28, 0.22)
    end
    wrap.happIcon:Show()
  else
    wrap.happTip = nil
    wrap.happIcon:Hide()
  end

  local parts = {}
  if wrap.petName then
    parts[#parts + 1] = wrap.petName
  end
  if level then
    parts[#parts + 1] = "Lv " .. tostring(level)
  end
  if type(loyalty) == "number" then
    parts[#parts + 1] = "Loyalty " .. tostring(loyalty)
  elseif type(loyalty) == "string" and loyalty ~= "" then
    parts[#parts + 1] = loyalty
  end
  if unspent then
    if total then
      parts[#parts + 1] = "TP " .. tostring(unspent) .. "/" .. tostring(total)
    else
      parts[#parts + 1] = "TP " .. tostring(unspent)
    end
  end
  local text = table.concat(parts, "   ")
  wrap.infoLine = text
  if wrap.infoText then
    wrap.infoText:SetText(text)
  end
  if text == "" and not wrap.happTip then
    wrap.info:Hide()
    wrap.infoW = 0
  else
    wrap.info:Show()
    -- Width is set in LayoutPet.
    wrap.infoW = 1
  end
end

function Pet.UpdatePetSpellButtons(wrap)
  local trainName, trainID, trainIcon = Pet.KnownHunterSpell(Pet.TRAIN_NAMES, Pet.TRAIN_IDS)
  local feedName, feedID, feedIcon = Pet.KnownHunterSpell(Pet.FEED_NAMES, Pet.FEED_IDS)
  wrap.trainName, wrap.feedName = trainName, feedName
  Pet.SetSpellChip(wrap.train, trainName, trainID, trainIcon, "train")
  Pet.SetSpellChip(wrap.feed, feedName, feedID, feedIcon, "feed")
end

function Pet.UpdatePetButtonCooldown(cap)
  if not cap or not cap.cdText then
    return
  end
  if not CooldownOpt() then
    ClearCooldown(cap)
    return
  end
  local start, dur, en, obj
  if cap.spellName then
    start, dur, en = SpellCooldown(cap.spellName)
  elseif cap.slot and type(GetPetActionCooldown) == "function" then
    pcall(function()
      start, dur, en = GetPetActionCooldown(cap.slot)
    end)
  else
    ClearCooldown(cap)
    return
  end
  if start == nil and dur == nil then
    ClearCooldown(cap)
    return
  end
  local readable, kind, finish = pcall(function()
    local s, d = tonumber(start) or 0, tonumber(dur) or 0
    if s <= 0 or d <= 0 then
      return nil
    end
    if d > (GCD_MAX or 1.6) then
      return "real", s + d
    end
    return "gcd", s + d
  end)
  if not readable then
    ApplyChipSwipe(cap, start, dur, nil, obj)
    cap.cdEnd = nil
    cap.cdText:SetText("")
    return
  end
  if kind == "real" then
    ApplyChipSwipe(cap, start, dur, nil, obj)
    cap.cdEnd = finish
  elseif kind == "gcd" then
    ApplyChipSwipe(cap, start, dur, nil, obj)
    cap.cdEnd = nil
    cap.cdText:SetText("")
  else
    if cap.cdEnd then
      ReadyFlash(cap)
    end
    ClearCooldown(cap)
  end
end

function Pet.ForEachPetChip(fn)
  local wrap = overlay and overlay.pet
  if not wrap then
    return
  end
  for i = 1, NUM_PET_SLOTS do
    local cap = wrap.caps and wrap.caps[i]
    if cap and cap:IsShown() then
      fn(cap)
    end
  end
  if wrap.train and wrap.train:IsShown() then
    fn(wrap.train)
  end
  if wrap.feed and wrap.feed:IsShown() then
    fn(wrap.feed)
  end
end

function Pet.UpdatePetCooldowns()
  Pet.ForEachPetChip(Pet.UpdatePetButtonCooldown)
end

function Pet.UpdatePetVisuals()
  local wrap = overlay and overlay.pet
  if not wrap then
    return
  end
  for i = 1, NUM_PET_SLOTS do
    local cap = wrap.caps and wrap.caps[i]
    if cap and cap:IsShown() and cap.slot then
      cap.petInfo = Pet.GetPetSlot(cap.slot) or cap.petInfo
      Pet.PaintPetVisual(cap)
    end
  end
  Pet.UpdatePetInfoStrip(wrap)
  Pet.UpdatePetCooldowns()
end

function Pet.LayoutPet()
  local wrap = overlay and overlay.pet
  if not wrap then
    return 0
  end
  if not Pet.NockPetWanted() or not Pet.PlayerHasPet() then
    if not InCombat() then
      wrap:Hide()
      Pet.FitOverlayToStack()
    end
    return 0
  end
  -- Collect occupied slots, grouped, hiding empty ones so new skills appear.
  local groups = { command = {}, stance = {}, ability = {} }
  local order = { "command", "stance", "ability" }
  for i = 1, NUM_PET_SLOTS do
    local info = Pet.GetPetSlot(i)
    local cap = wrap.caps[i]
    if info then
      local g = Pet.PetGroup(info)
      groups[g][#groups[g] + 1] = { cap = cap, info = info }
      Pet.SetPetChipAction(cap, info)
    else
      Pet.SetPetChipAction(cap, nil)
    end
    Pet.StylePetChip(cap)
  end
  Pet.UpdatePetSpellButtons(wrap)
  Pet.StylePetChip(wrap.train)
  Pet.StylePetChip(wrap.feed)
  SafeBuild("petinfo", "pet info", Pet.UpdatePetInfoStrip, wrap)

  local x = PET_PAD
  local shownAny = false
  local divI = 0
  if wrap.divs then
    for _, d in ipairs(wrap.divs) do
      d:Hide()
    end
  end
  -- Info plaque on the left of the tiles.
  local infoW = 0
  if wrap.info and wrap.info:IsShown() then
    infoW = math.max(90, PET_TILE * 3 + 10)
    wrap.info:ClearAllPoints()
    wrap.info:SetPoint("LEFT", wrap, "LEFT", 4, 0)
    wrap.info:SetSize(infoW, PET_H)
    wrap.infoW = infoW
    x = 4 + infoW + 6
  end
  for gi, key in ipairs(order) do
    local g = groups[key]
    if #g > 0 then
      if shownAny then
        divI = divI + 1
        local div = wrap.divs and wrap.divs[divI]
        if div then
          div:ClearAllPoints()
          div:SetPoint("LEFT", wrap, "LEFT", x + PET_GRP / 2 - 1, 0)
          div:SetHeight(PET_TILE - 8)
          div:Show()
        end
        x = x + PET_GRP
      end
      for _, rec in ipairs(g) do
        rec.cap:ClearAllPoints()
        rec.cap:SetPoint("LEFT", wrap, "LEFT", x, 0)
        x = x + PET_TILE + PET_GAP
      end
      shownAny = true
    end
  end
  -- Train / Feed at the right, after a small gap, only if known.
  local extras = {}
  if wrap.train and wrap.train:IsShown() then
    extras[#extras + 1] = wrap.train
  end
  if wrap.feed and wrap.feed:IsShown() then
    extras[#extras + 1] = wrap.feed
  end
  if #extras > 0 then
    if shownAny or infoW > 0 then
      divI = divI + 1
      local div = wrap.divs and wrap.divs[divI]
      if div then
        div:ClearAllPoints()
        div:SetPoint("LEFT", wrap, "LEFT", x + PET_GRP / 2 - 1, 0)
        div:SetHeight(PET_TILE - 8)
        div:Show()
      end
      x = x + PET_GRP
    end
    for _, cap in ipairs(extras) do
      cap:ClearAllPoints()
      cap:SetPoint("LEFT", wrap, "LEFT", x, 0)
      x = x + PET_TILE + PET_GAP
    end
    shownAny = true
  end
  if not shownAny and infoW == 0 then
    if not InCombat() then
      wrap:Hide()
      Pet.FitOverlayToStack()
    end
    return 0
  end
  local trayW = x - PET_GAP + PET_PAD
  wrap:SetWidth(math.max(trayW, infoW + 8))
  wrap:SetHeight(PET_H)
  wrap.barW = trayW
  -- Under the XP bar (or the utility tray / plaque if XP is hidden),
  -- centered. Anchor once; do not re-point a secure parent in combat.
  Pet.AnchorPetBar(wrap)
  wrap:Show()
  Pet.FitOverlayToStack()
  Pet.UpdatePetCooldowns()
  return PET_H + PET_GAP_Y
end

-- Resize the overlay around whatever is actually showing so a dismissed
-- pet does not leave a hole under the experience bar. Out of combat only.
function Pet.FitOverlayToStack()
  if not overlay or InCombat() or not overlay.SetHeight then
    return
  end
  local h = BODY_H
  if overlay.util and overlay.util.IsShown and overlay.util:IsShown() then
    h = h + UTIL_GAP_Y + UTIL_H
  end
  if overlay.extra and overlay.extra.IsShown and overlay.extra:IsShown() then
    h = h + (overlay.extra.rowH or (UTIL_H + UTIL_GAP_Y))
  end
  if overlay.xp and overlay.xp.IsShown and overlay.xp:IsShown() then
    h = h + math.max(XP_BADGE, XP_FRAME_H) + XP_GAP
  end
  if overlay.pet and overlay.pet.IsShown and overlay.pet:IsShown() then
    h = h + PET_H + PET_GAP_Y
  end
  overlay:SetHeight(h)
end

-- Pick the frame the pet bar hangs from, and only SetPoint when it changes
-- and we are out of combat (the wrap holds secure Train / Feed / pet buttons).
function Pet.AnchorPetBar(wrap)
  wrap = wrap or (overlay and overlay.pet)
  if not wrap or InCombat() then
    return
  end
  local rel
  if overlay.xp and overlay.xp.IsShown and overlay.xp:IsShown() then
    rel = overlay.xp
  elseif overlay.util and overlay.util.IsShown and overlay.util:IsShown() then
    rel = overlay.util
  else
    rel = overlay.body
  end
  if not rel then
    return
  end
  local x, y = 0, -PET_GAP_Y
  local last = wrap._nockAnchor
  if last and last[1] == "TOP" and last[2] == rel and last[3] == "BOTTOM" and last[4] == x and last[5] == y then
    return
  end
  wrap:ClearAllPoints()
  wrap:SetPoint("TOP", rel, "BOTTOM", x, y)
  wrap._nockAnchor = { "TOP", rel, "BOTTOM", x, y }
end

function Pet.UpdatePetBar()
  local wrap = overlay and overlay.pet
  if not wrap then
    return
  end
  if InCombat() then
    -- Show/Hide and attributes wait; visuals and numbers can still change.
    if wrap:IsShown() then
      SafeBuild("pet", "pet bar", Pet.UpdatePetVisuals)
    end
    return
  end
  Pet.LayoutPet()
end


-- 3.0.8: every hunter skill he knows appears on Nock's bars.
Book = Book or {}
-- Packed into Book so the file stays under Lua 5.1's 200-local cap.
-- Melee tiles stay visible. Tracking and leftover spells sit on one
-- Every known hunter skill gets a left-hand key. Layout is out of combat only.

Book.MELEE = {
  "Counterattack", "Mongoose Bite", "Raptor Strike", "Lacerate", "Strider Kick", "Disengage",
}
Book.TRACKS = {
  "Track Beasts", "Track Humanoids", "Track Undead", "Track Hidden",
  "Track Elementals", "Track Demons", "Track Giants", "Track Dragonkin",
  "Find Herbs", "Find Minerals",
}
Book.UTILITY = {
  "Distracting Shot", "Scatter Shot", "Tranquilizing Shot", "Scare Beast",
  "Flare", "Enchanted Flare", "Viper Sting", "Scorpid Sting", "Wyvern Sting",
  "Volley", "Rapid Fire", "Intimidation", "Bestial Wrath", "Eyes of the Beast",
  "Eagle Eye", "Beast Lore", "Tame Beast", "Dismiss Pet", "Deterrence",
  "Trueshot Aura", "Sniper Shot", "Summon Hawk", "Aspect of the Viper",
  "Aspect of the Beast", "Aspect of the Wild",
}
Book.SKIP = {
  ["Auto Shot"] = true, ["Attack"] = true, ["Shoot"] = true,
  ["Beast Training"] = true, ["Train Pet"] = true, ["Pet Training"] = true,
  ["Feed Pet"] = true, ["Call Pet"] = true, ["Revive Pet"] = true,
  ["Mend Pet"] = true,
}
Book.MELEE_SET, Book.TRACK_SET, Book.CATALOG = {}, {}, {}
do
  local function add(list, set)
    for _, n in ipairs(list) do
      set[n] = true
      Book.CATALOG[n] = true
    end
  end
  add(Book.MELEE, Book.MELEE_SET)
  add(Book.TRACKS, Book.TRACK_SET)
  add(Book.UTILITY, {})
  -- Already-mapped shots and tools still belong in the catalog (for
  -- "is this a hunter skill?" and so a late-learned one is recognized).
  for _, n in ipairs({
    "Arcane Shot", "Aimed Shot", "Multi-Shot", "Serpent Sting", "Concussive Shot",
    "Feign Death", "Hunter's Mark", "Wing Clip", "Freezing Trap", "Frost Trap",
    "Immolation Trap", "Explosive Trap", "Aspect of the Hawk", "Aspect of the Monkey",
    "Aspect of the Cheetah", "Aspect of the Pack", "Mend Pet", "Call Pet",
    "Revive Pet", "Feed Pet", "Beast Training",
  }) do
    Book.CATALOG[n] = true
  end
end
Book.MELEE_MAX, Book.TRACK_MAX, Book.MORE_MAX = 8, 12, 40
Book.FLY_COLS = 6

function Book.IsCatalog(name)
  return name and Book.CATALOG[name] and true or false
end

function Book.IsTrackName(name)
  if not name or type(name) ~= "string" then
    return false
  end
  if Book.TRACK_SET[name] then
    return true
  end
  if name:find("^Track ") then
    return true
  end
  if name:find("^Find ") then
    return true
  end
  return false
end

function Book.KnownName(name)
  if not name or name == "" then
    return false
  end
  local ok, known = pcall(PlayerKnows, name)
  return ok and known and true or false
end

function Book.SpellEntry(name)
  return { kind = "spell", name = name }
end

-- Walk Forever's spellbook (C_SpellBook) or the classic tab APIs.
-- fn(name, spellID, isPassive) for each player spell we can read.
function Book.EachSpellbookSpell(fn)
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo then
    local okN, n = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if okN and type(n) == "number" then
      local bank = 0
      if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
        bank = Enum.SpellBookSpellBank.Player
      end
      for i = 1, n do
        local okI, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, i)
        if okI and type(info) == "table" and not info.shouldHide and not (info.offSpecID and info.offSpecID ~= 0) then
          local off = info.itemIndexOffset or 0
          local count = info.numSpellBookItems or 0
          for j = 1, count do
            local slot = off + j
            local name, spellID, isPassive
            if C_SpellBook.GetSpellBookItemInfo then
              local okS, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
              if okS and type(item) == "table" then
                name = item.name
                spellID = item.spellID
                isPassive = item.isPassive
              end
            end
            if (not name) and C_SpellBook.GetSpellBookItemName then
              local ok2, n2 = pcall(C_SpellBook.GetSpellBookItemName, slot, bank)
              if ok2 then
                name = n2
              end
            end
            if name and isPassive == nil and C_SpellBook.IsSpellBookItemPassive then
              local okP, p = pcall(C_SpellBook.IsSpellBookItemPassive, slot, bank)
              if okP then
                isPassive = p
              end
            end
            if name then
              fn(name, spellID, isPassive)
            end
          end
        end
      end
      return
    end
  end
  if GetNumSpellTabs and GetSpellTabInfo then
    local okT, tabs = pcall(GetNumSpellTabs)
    if okT and type(tabs) == "number" then
      for t = 1, tabs do
        local okI, name, _, offset, num, _, offSpec = pcall(GetSpellTabInfo, t)
        if okI and not (offSpec and offSpec ~= 0) then
          offset = offset or 0
          num = num or 0
          for j = 1, num do
            local slot = offset + j
            local sName, isPassive, spellID
            if GetSpellBookItemName then
              local okN, n1 = pcall(GetSpellBookItemName, slot, "spell")
              if okN then
                sName = n1
              end
            end
            if GetSpellBookItemInfo then
              local okB, kind, id = pcall(GetSpellBookItemInfo, slot, "spell")
              if okB then
                isPassive = (kind == "FUTURESPELL" or kind == "PET")
                if kind == "SPELL" or kind == "PETACTION" then
                  spellID = id
                end
                if kind == "PETACTION" then
                  sName = nil
                end
              end
            end
            if IsPassiveSpell and sName then
              local okP, p = pcall(IsPassiveSpell, slot, "spell")
              if okP and p then
                isPassive = true
              end
            end
            if sName then
              fn(sName, spellID, isPassive)
            end
          end
        end
      end
    end
  end
end

function Book.PlacedNames()
  local have = {}
  for n in pairs(Book.SKIP) do
    have[n] = true
  end
  local layout = LayoutFor(NockCharDB and NockCharDB.spec or "marks") or {}
  local function noteEntry(e)
    if not e or e.kind == "item" then
      return
    end
    local n = e.name
    if e.kind == "macro" or e.macro then
      n = MacroSpell(e) or n
    end
    if n then
      have[n] = true
    end
  end
  -- Tiles already painted on the main bar or the utility row.
  if overlay then
    for _, key in ipairs(BAR_KEYS_ALL) do
      local cap = overlay.caps and overlay.caps[key]
      if cap and cap:IsShown() then
        noteEntry(cap.entry or layout[key])
      end
    end
    for _, key in ipairs(UTIL_KEYS) do
      local cap = overlay.utilCaps and overlay.utilCaps[key]
      if cap and cap:IsShown() then
        noteEntry(cap.entry or layout[key])
      end
    end
  end
  -- Also treat known spells that belong on those rows as placed, so we
  -- don't duplicate a tile while UpdateOverlay is mid-paint.
  for _, key in ipairs(MainBarKeys()) do
    local e = layout[key]
    if e then
      local n = e.name
      if e.kind == "macro" or e.macro then
        n = MacroSpell(e) or n
      end
      if e.kind ~= "item" and n and (e.kind == "macro" or Book.KnownName(n)) then
        have[n] = true
      end
    end
  end
  for _, key in ipairs(UTIL_KEYS) do
    local e = layout[key]
    if e and e.kind ~= "item" then
      local n = e.name
      if e.kind == "macro" or e.macro then
        n = MacroSpell(e) or n
      end
      if n and (e.kind == "macro" or Book.KnownName(n)) then
        have[n] = true
      end
    end
  end
  return have
end

function Book.ScanKnown()
  local known = {}
  local function remember(name, isPassive)
    if not name or name == "" or isPassive then
      return
    end
    -- Rank text ("Raptor Strike(Rank 4)") — keep the bare name.
    name = (name:gsub("%s*%(.*%)$", ""))
    if known[name] then
      return
    end
    known[name] = true
  end
  for name in pairs(Book.CATALOG) do
    if Book.KnownName(name) then
      remember(name)
    end
  end
  Book.EachSpellbookSpell(function(name, _, isPassive)
    if isPassive then
      return
    end
    if Book.CATALOG[name] or Book.IsTrackName(name) or Book.IsCatalog(name) then
      remember(name, isPassive)
    elseif type(name) == "string" and (name:find("^Track ") or name:find("^Find ")) then
      remember(name, isPassive)
    end
  end)
  -- Mini-map tracking list (Find Herbs / Minerals and any extra types).
  if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
    local okN, n = pcall(C_Minimap.GetNumTrackingTypes)
    if okN and type(n) == "number" then
      for i = 1, n do
        local okI, info = pcall(C_Minimap.GetTrackingInfo, i)
        if okI and type(info) == "table" and info.name then
          -- Only include types that are spells we can cast, or that are active
          -- (we at least know them).
          if Book.IsTrackName(info.name) or Book.KnownName(info.name) then
            remember(info.name)
          end
        elseif okI and type(info) == "string" then
          if Book.IsTrackName(info) or Book.KnownName(info) then
            remember(info)
          end
        end
      end
    end
  end
  return known
end

function Book.SplitKnown()
  local known = Book.ScanKnown()
  local placed = Book.PlacedNames()
  local melee, tracks, more = {}, {}, {}
  -- Melee first, catalog order, skip anything already on the main bar
  -- (Wing Clip lives on M4 / Shift-Z).
  for _, name in ipairs(Book.MELEE) do
    if known[name] and not placed[name] then
      melee[#melee + 1] = name
    end
  end
  local trackSeen = {}
  for _, name in ipairs(Book.TRACKS) do
    if known[name] then
      tracks[#tracks + 1] = name
      trackSeen[name] = true
    end
  end
  for name in pairs(known) do
    if Book.IsTrackName(name) and not trackSeen[name] then
      tracks[#tracks + 1] = name
      trackSeen[name] = true
    end
  end
  -- Overflow: every other known hunter skill that has no tile yet.
  local moreSeen = {}
  local function addMore(name)
    if not name or moreSeen[name] or placed[name] or Book.MELEE_SET[name] or trackSeen[name] then
      return
    end
    -- Melee already listed (even if somehow not in MELEE_SET typo)
    for _, m in ipairs(melee) do
      if m == name then
        return
      end
    end
    moreSeen[name] = true
    more[#more + 1] = name
  end
  for _, name in ipairs(Book.UTILITY) do
    if known[name] then
      addMore(name)
    end
  end
  local extra = {}
  for name in pairs(known) do
    if not moreSeen[name] and not placed[name] and not Book.MELEE_SET[name] and not trackSeen[name] then
      extra[#extra + 1] = name
    end
  end
  table.sort(extra)
  for _, name in ipairs(extra) do
    addMore(name)
  end
  return melee, tracks, more
end

function Book.ActiveTrack()
  if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
    local okN, n = pcall(C_Minimap.GetNumTrackingTypes)
    if okN and type(n) == "number" then
      for i = 1, n do
        local okI, info = pcall(C_Minimap.GetTrackingInfo, i)
        if okI and type(info) == "table" and info.active and info.name then
          return info.name, info.texture or info.icon, info.spellID
        end
      end
    end
  end
  if GetTrackingTexture then
    local ok, tex = pcall(GetTrackingTexture)
    if ok and tex then
      return nil, tex
    end
  end
  return nil
end

function Book.SpellInMeleeRange()
  if not HasHostileTarget() then
    return false
  end
  local function clearlyIn(name)
    if not name then
      return nil
    end
    local r
    if C_Spell and C_Spell.IsSpellInRange then
      local ok, v = pcall(C_Spell.IsSpellInRange, name, "target")
      if ok then
        r = v
      end
    elseif IsSpellInRange then
      local ok, v = pcall(IsSpellInRange, name, "target")
      if ok then
        r = v
      end
    end
    local f = ReadableFlag(r)
    if f == true then
      return true
    end
    if f == false then
      return false
    end
    return nil
  end
  for _, name in ipairs({ "Raptor Strike", "Wing Clip", "Mongoose Bite", "Counterattack", "Lacerate", "Strider Kick" }) do
    if Book.KnownName(name) then
      local v = clearlyIn(name)
      if v ~= nil then
        return v
      end
    end
  end
  if CheckInteractDistance then
    local ok, v = pcall(CheckInteractDistance, "target", 3)
    if ok and ReadableFlag(v) == true then
      return true
    end
  end
  return false
end

-- 3.0.9: every skill has a left-hand key. No click-only flyouts.
-- Binds use SetOverrideBindingClick on NockBindOwner and never SaveBindings.

-- Fixed left-hand layout (only applied when the skill is known).
-- id: "melee", "track-next", "track-prev", "pet-go", "pet-back", "pet-stay",
--     "pet-call", or a spell name.
Book.FIXED = {
  -- Combat, left hand on WASD.
  { key = "F",       id = "melee",           label = "Melee",           group = "combat" },
  { key = "SHIFT-F", id = "Disengage",       label = "Disengage",       group = "combat" },
  { key = "G",       id = "Counterattack",   label = "Counterattack",   group = "combat" },
  { key = "T",       id = "Distracting Shot",label = "Distracting Shot",group = "combat" },
  { key = "Z",       id = "Scatter Shot",    label = "Scatter Shot",    group = "combat" },
  { key = "X",       id = "Tranquilizing Shot", label = "Tranq Shot",   group = "combat" },
  { key = "C",       id = "track-next",      label = "Track",           group = "combat" },
  { key = "SHIFT-C", id = "track-prev",      label = "Track back",      group = "combat", hidden = true },
  -- Traps (V is next to C).
  { key = "V",       id = "Freezing Trap",   label = "Freezing Trap",   group = "traps" },
  { key = "SHIFT-V", id = "Frost Trap",      label = "Frost Trap",      group = "traps" },
  { key = "CTRL-V",  id = "Immolation Trap", label = "Immolation Trap", group = "traps" },
  { key = "ALT-V",   id = "Explosive Trap",  label = "Explosive Trap",  group = "traps" },
  -- Cooldowns and extra shots.
  { key = "SHIFT-1", id = "Rapid Fire",      label = "Rapid Fire",      group = "cds" },
  { key = "CTRL-2",  id = "Intimidation",    label = "Intimidation",    group = "cds" },
  { key = "CTRL-3",  id = "Bestial Wrath",   label = "Bestial Wrath",   group = "cds" },
  { key = "SHIFT-3", id = "Volley",          label = "Volley",          group = "cds" },
  { key = "SHIFT-4", id = "Viper Sting",     label = "Viper Sting",     group = "cds" },
  { key = "SHIFT-5", id = "Scorpid Sting",   label = "Scorpid Sting",   group = "cds" },
  { key = "CTRL-5",  id = "Wyvern Sting",    label = "Wyvern Sting",    group = "cds" },
  { key = "SHIFT-Q", id = "Scare Beast", quiet = true,     label = "Scare Beast",     group = "cds" },
  { key = "SHIFT-E", id = "Deterrence",      label = "Deterrence",      group = "cds" },
  { key = "SHIFT-X", id = "Flare",           label = "Flare",           group = "cds" },
  { key = "SHIFT-Z", id = "Strider Kick", quiet = true,    label = "Strider Kick",    group = "cds" },
  { key = "CTRL-F",  id = "Lacerate",        label = "Lacerate",        group = "cds" },
  { key = "CTRL-X",  id = "Enchanted Flare", quiet = true, label = "Enchanted Flare", group = "cds" },
  -- Aspects (Alt + nearby keys).
  { key = "ALT-X",   id = "aspect-damage",   label = "Hawk",            group = "aspects" },
  { key = "ALT-Z",   id = "Aspect of the Cheetah", label = "Cheetah",  group = "aspects" },
  { key = "ALT-C",   id = "Aspect of the Monkey",  label = "Monkey",   group = "aspects" },
  { key = "ALT-F",   id = "Aspect of the Pack", quiet = true,    label = "Pack",     group = "aspects" },
  { key = "ALT-G",   id = "Aspect of the Wild", quiet = true,    label = "Wild",     group = "aspects" },
  { key = "ALT-Q",   id = "Aspect of the Beast", quiet = true,   label = "Beast",    group = "aspects" },
  { key = "SHIFT-2", id = "Trueshot Aura", quiet = true,   label = "Trueshot Aura",   group = "aspects" },
  -- Pet.
  { key = "SHIFT-T", id = "pet-go",          label = "Pet: attack",     group = "pet" },
  { key = "CTRL-T",  id = "pet-back",        label = "Pet: follow",     group = "pet" },
  { key = "ALT-T",   id = "pet-stay",        label = "Pet: stay",       group = "pet" },
  { key = "SHIFT-G", id = "Mend Pet",        label = "Mend Pet",        group = "pet" },
  { key = "CTRL-G",  id = "pet-call",        label = "Call / Revive",   group = "pet" },
  { key = "SHIFT-R", id = "Feed Pet", quiet = true,        label = "Feed Pet",        group = "pet" },
  { key = "ALT-R",   id = "Eagle Eye", quiet = true,       label = "Eagle Eye",       group = "pet" },
  { key = "CTRL-R",  id = "Beast Lore", quiet = true,      label = "Beast Lore",      group = "pet" },
  { key = "CTRL-Q",  id = "Eyes of the Beast", quiet = true, label = "Eyes of the Beast", group = "pet" },
  { key = "CTRL-E",  id = "Dismiss Pet", quiet = true,     label = "Dismiss Pet",     group = "pet" },
  { key = "CTRL-Z",  id = "Tame Beast", quiet = true,      label = "Tame Beast",      group = "pet" },
}

-- Next free left-hand keys for anything learned later.
Book.OVERFLOW_KEYS = {
  "CTRL-1", "CTRL-4", "ALT-2", "ALT-3", "ALT-4", "ALT-5",
  "CTRL-Q", "SHIFT-Q", "ALT-R", "CTRL-R", "SHIFT-4", "SHIFT-5",
  "ALT-E", -- only if no racial sits here
}

-- Keys the main bar / racials / BM Arcane already use. Book never takes these.
Book.CORE_KEYS = {
  ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true,
  ["R"] = true, ["Q"] = true, ["E"] = true,
  ["BUTTON3"] = true, ["BUTTON4"] = true, ["BUTTON5"] = true,
  ["6"] = true, -- his existing Nock:Melee macro; we do not touch it
}

function Book.IsCoreKey(key)
  if not key then
    return false
  end
  if Book.CORE_KEYS[key] then
    return true
  end
  -- BM: 2 is Summon Hawk, SHIFT-2 is Arcane Shot — leave them alone.
  if key == "SHIFT-2" then
    local layout = LayoutFor(NockCharDB and NockCharDB.spec or "marks") or {}
    local s2 = layout["SHIFT-2"]
    local n = s2 and s2.name
    if n == "Arcane Shot" or n == "Summon Hawk" or n == "Nock:Arcane" or n == "Nock:Hawk" then
      return true
    end
  end
  -- Shift-Z is reserved whenever the layout puts Wing Clip there
  -- (mouse off, or mouse on but Mouse 4 already belongs to you).
  if key == "SHIFT-Z" then
    local layout = LayoutFor(NockCharDB and NockCharDB.spec or "marks") or {}
    local e = layout["SHIFT-Z"]
    if e and e.name == "Wing Clip" then
      return true
    end
  end
  -- MM: Shift-3 is Sniper Shot — leave it on the saved keymap.
  if key == "SHIFT-3" then
    local layout = LayoutFor(NockCharDB and NockCharDB.spec or "marks") or {}
    local s3 = layout["SHIFT-3"]
    if s3 and (s3.name == "Sniper Shot" or s3.name == "Nock:Sniper") then
      return true
    end
  end
  -- Racial keys, only while the layout has them.
  local layout = LayoutFor(NockCharDB and NockCharDB.spec or "marks") or {}
  if key == "ALT-1" or key == "ALT-E" then
    if layout[key] and layout[key].racial then
      return true
    end
  end
  return false
end

function Book.OwnsKey(key)
  -- Keys Book assigns with SetOverrideBindingClick; ApplyLayout must not SaveBindings them.
  if not key or Book.IsCoreKey(key) then
    return false
  end
  if key == "HEARTH" or key == "FOOD" then
    return false
  end
  -- Main bar keys are never Book's.
  for _, k in ipairs(MainBarKeys()) do
    if k == key then
      return false
    end
  end
  return true
end

function Book.DamageAspect()
  return (DamageAspectName and DamageAspectName()) or "Aspect of the Hawk"
end

function Book.MeleeMacro()
  return "#showtooltip\n/startattack\n/cast Mongoose Bite\n/cast Raptor Strike"
end

function Book.PetMacro(which)
  if which == "pet-go" then
    return "/petattack [@mouseover,harm,nodead][]"
  end
  if which == "pet-back" then
    return "/petfollow"
  end
  if which == "pet-stay" then
    return "/petstay"
  end
  if which == "pet-call" then
    return "#showtooltip Call Pet\n/cast [nopet] Call Pet\n/cast [@pet,dead] Revive Pet"
  end
end

function Book.TrackList()
  local list, seen = {}, {}
  for _, name in ipairs(Book.TRACKS) do
    if Book.KnownName(name) or (Book.ScanCache and Book.ScanCache[name]) then
      list[#list + 1] = name
      seen[name] = true
    end
  end
  local known = Book.ScanCache or Book.ScanKnown()
  for name in pairs(known) do
    if Book.IsTrackName(name) and not seen[name] then
      list[#list + 1] = name
      seen[name] = true
    end
  end
  return list
end

function Book.ResolveFixed(item, known)
  local id = item.id
  if id == "melee" then
    if known["Raptor Strike"] or known["Mongoose Bite"] then
      return "melee", item.label
    end
    return nil
  end
  if id == "track-next" or id == "track-prev" then
    local tracks = Book.TrackList()
    if #tracks > 0 then
      return id, item.label
    end
    return nil
  end
  if id == "pet-go" or id == "pet-back" or id == "pet-stay" then
    -- Pet commands are useful once Call Pet exists (level 10).
    if known["Call Pet"] or known["Revive Pet"] or known["Mend Pet"] then
      return id, item.label
    end
    return nil
  end
  if id == "pet-call" then
    if known["Call Pet"] or known["Revive Pet"] then
      return id, item.label
    end
    return nil
  end
  if id == "aspect-damage" then
    local name = Book.DamageAspect()
    if known[name] or Book.KnownName(name) then
      return name, name
    end
    return nil
  end
  if id == "Trueshot Aura" then
    -- SHIFT-2 is reserved on BM (Arcane Shot). Only use it for Trueshot on MM.
    if Book.IsCoreKey(item.key) then
      return nil
    end
  end
  if id == "Strider Kick" and Book.IsCoreKey(item.key) then
    return nil
  end
  if known[id] then
    return id, item.label
  end
  return nil
end

function Book.ShouldShowTile(rec)
  if not rec or rec.hidden then
    return false
  end
  if rec.quiet then
    return false
  end
  if rec.group == "more" then
    return false
  end
  return true
end

function Book.Assign()
  local known = Book.ScanKnown()
  Book.ScanCache = known
  -- Spells already on the main bar (or Open Fire / Feign macros) are placed.
  local placed = Book.PlacedNames() or {}
  local usedKeys, usedNames, rows = {}, {}, {}

  local function take(key, id, label, group, hidden, quiet)
    if not key or usedKeys[key] or Book.IsCoreKey(key) then
      return false
    end
    if usedNames[id] and id ~= "track-next" and id ~= "track-prev" then
      return false
    end
    usedKeys[key] = true
    if id ~= "melee" and id ~= "track-next" and id ~= "track-prev"
        and id ~= "pet-go" and id ~= "pet-back" and id ~= "pet-stay" and id ~= "pet-call" then
      usedNames[id] = key
      placed[id] = true
    end
    if id == "melee" then
      usedNames["Raptor Strike"] = key
      usedNames["Mongoose Bite"] = key
      placed["Raptor Strike"] = true
      placed["Mongoose Bite"] = true
    end
    if id == "track-next" or id == "track-prev" then
      for _, n in ipairs(Book.TrackList()) do
        placed[n] = true
        usedNames[n] = usedNames[n] or key
      end
    end
    if id == "pet-go" or id == "pet-back" or id == "pet-stay" or id == "pet-call" then
      usedNames[id] = key
    end
    rows[#rows + 1] = { key = key, id = id, label = label, group = group, hidden = hidden, quiet = quiet }
    return true
  end

  for _, item in ipairs(Book.FIXED) do
    if not Book.IsCoreKey(item.key) then
      local id, label = Book.ResolveFixed(item, known)
      if id then
        take(item.key, id, label, item.group, item.hidden, item.quiet)
      end
    end
  end

  -- Everything else he knows, next free left-hand key.
  local leftover = {}
  for name in pairs(known) do
    if not placed[name] and not Book.SKIP[name] and not Book.IsTrackName(name) then
      leftover[#leftover + 1] = name
    end
  end
  table.sort(leftover)
  local oi = 1
  for _, name in ipairs(leftover) do
    while oi <= #Book.OVERFLOW_KEYS do
      local ok = Book.OVERFLOW_KEYS[oi]
      local occupied = usedKeys[ok] or Book.IsCoreKey(ok)
      if not occupied and NockCharDB and NockCharDB.userKeys and NockCharDB.userKeys[ok] ~= nil then
        occupied = true
      end
      if not occupied and GetBindingAction then
        local cur = GetBindingAction(ok, true) or ""
        if cur ~= "" then
          occupied = true
        end
      end
      if not occupied then
        break
      end
      oi = oi + 1
    end
    if oi <= #Book.OVERFLOW_KEYS then
      take(Book.OVERFLOW_KEYS[oi], name, name, "more", false)
      oi = oi + 1
    end
  end

  Book.assignment = rows
  Book.byKey = usedKeys
  Book.byName = usedNames
  Book.leftoverUnbound = {}
  for _, name in ipairs(leftover) do
    if not usedNames[name] then
      Book.leftoverUnbound[#Book.leftoverUnbound + 1] = name
    end
  end
  return rows
end

function Book.KeyForSpell(name)
  if not name then
    return nil
  end
  if not Book.byName then
    Book.Assign()
  end
  return Book.byName and Book.byName[name]
end

function Book.CheatMap()
  -- Plain list for the cheat-sheet card: visible keys only, in group order.
  if not Book.assignment then
    Book.Assign()
  end
  local out = {}
  for _, a in ipairs(Book.assignment or {}) do
    if not a.hidden then
      out[#out + 1] = { key = a.key, label = a.label or a.id }
    end
  end
  return out
end

function Book.Owner()
  if not Book.owner then
    Book.owner = CreateFrame("Frame", "NockBindOwner", UIParent)
  end
  return Book.owner
end

function Book.ClearBinds()
  if InCombat() then
    return
  end
  local owner = Book.owner
  if owner and ClearOverrideBindings then
    pcall(ClearOverrideBindings, owner)
  end
end

function Book.BindClick(key, buttonName)
  if InCombat() or not key or not buttonName or not SetOverrideBindingClick then
    return
  end
  pcall(SetOverrideBindingClick, Book.Owner(), true, key, buttonName)
end

function Book.SetAction(cap, rec)
  if InCombat() or not cap then
    return
  end
  cap.rec = rec
  cap.known = rec and true or false
  cap.spellName = rec and rec.id or nil
  cap.key = rec and rec.key or nil
  if not rec then
    cap:SetAttribute("type", nil)
    cap:SetAttribute("spell", nil)
    cap:SetAttribute("macrotext", nil)
    cap:SetAttribute("macro", nil)
    cap:SetAttribute("item", nil)
    return
  end
  local id = rec.id
  if id == "melee" then
    cap:SetAttribute("type", "macro")
    cap:SetAttribute("macrotext", Book.MeleeMacro())
    cap:SetAttribute("spell", nil)
    cap:SetAttribute("macro", nil)
    cap.spellName = "Raptor Strike"
  elseif id == "pet-go" or id == "pet-back" or id == "pet-stay" or id == "pet-call" then
    cap:SetAttribute("type", "macro")
    cap:SetAttribute("macrotext", Book.PetMacro(id))
    cap:SetAttribute("spell", nil)
    cap:SetAttribute("macro", nil)
  elseif id == "track-next" or id == "track-prev" then
    local tracks = Book.TrackList()
    local active = Book.ActiveTrack()
    local pick
    if #tracks == 0 then
      pick = nil
    elseif #tracks == 1 then
      pick = tracks[1]
    else
      local idx = 1
      for i, n in ipairs(tracks) do
        if n == active then
          idx = i
          break
        end
      end
      if id == "track-next" then
        pick = tracks[(idx % #tracks) + 1]
        if active and pick == active then
          pick = tracks[(idx % #tracks) + 1]
        end
        -- If something is already on, next is the following entry.
        if active then
          pick = tracks[(idx % #tracks) + 1]
        else
          pick = tracks[1]
        end
      else
        if active then
          pick = tracks[((idx - 2) % #tracks) + 1]
        else
          pick = tracks[#tracks]
        end
      end
    end
    cap.spellName = pick
    cap:SetAttribute("type", pick and "spell" or nil)
    cap:SetAttribute("spell", pick)
    cap:SetAttribute("macrotext", nil)
  else
    cap:SetAttribute("type", "spell")
    cap:SetAttribute("spell", id)
    cap:SetAttribute("macrotext", nil)
    cap:SetAttribute("macro", nil)
    cap.spellName = id
  end
end

function Book.PaintKey(cap, key)
  if not cap then
    return
  end
  cap.key = key
  if cap.label then
    if key and key ~= "" then
      cap.label:SetText(OverlayKeyLabel(key))
      if cap.badge then
        cap.badge:Show()
      end
    else
      cap.label:SetText("")
      if cap.badge then
        cap.badge:Hide()
      end
    end
  end
  if cap.lvl then
    cap.lvl:SetText("")
  end
  if cap.tag then
    cap.tag:SetText("")
    cap.tag:Hide()
  end
end

function Book.IconForRec(rec)
  if not rec then
    return QUESTION_ICON
  end
  if rec.id == "melee" then
    return IconFor("Raptor Strike")
  end
  if rec.id == "track-next" or rec.id == "track-prev" then
    local active = Book.ActiveTrack()
    if active then
      return IconFor(active)
    end
    local tracks = Book.TrackList()
    return IconFor(tracks[1] or "Track Beasts")
  end
  if rec.id == "pet-go" then
    return IconFor({ kind = "macro", name = "Nock:PetGo", macro = Book.PetMacro("pet-go") }) or "Interface\\Icons\\ABILITY_GHOULFRENZY"
  end
  if rec.id == "pet-back" then
    return "Interface\\Icons\\ABILITY_TRACKING"
  end
  if rec.id == "pet-stay" then
    return "Interface\\Icons\\SPELL_NATURE_TIMESTOP"
  end
  if rec.id == "pet-call" then
    return IconFor("Call Pet")
  end
  return IconFor(rec.id)
end

function Book.ForEachChip(fn)
  local wrap = overlay and overlay.extra
  if not wrap then
    return
  end
  for _, cap in ipairs(wrap.caps or {}) do
    if cap:IsShown() then
      fn(cap)
    end
  end
  if wrap.trackPrev and wrap.trackPrev:IsShown() then
    fn(wrap.trackPrev)
  end
end

function Book.SetGlow(cap, on)
  if not cap then
    return
  end
  if cap.flash then
    if on then
      cap.flash:SetAlpha(0.7)
      cap.flash:Show()
    else
      cap.flash:SetAlpha(0)
      cap.flash:Hide()
    end
  end
  if cap.ring and cap.ring.SetVertexColor then
    if on then
      cap.ring:SetVertexColor(0.35, 1, 0.55)
    else
      cap.ring:SetVertexColor(1, 1, 1)
    end
  end
end

function Book.UpdateMeleeGlow()
  local wrap = overlay and overlay.extra
  if not wrap then
    return
  end
  local on = Book.SpellInMeleeRange()
  wrap.inMelee = on
  for _, cap in ipairs(wrap.caps or {}) do
    if cap:IsShown() and cap.rec and cap.rec.id == "melee" then
      Book.SetGlow(cap, on)
    end
  end
end

function Book.UpdateTrackVisuals()
  local wrap = overlay and overlay.extra
  if not wrap then
    return
  end
  local name = Book.ActiveTrack()
  wrap.activeTrack = name
  for _, cap in ipairs(wrap.caps or {}) do
    if cap:IsShown() and cap.rec and (cap.rec.id == "track-next") then
      if cap.icon then
        cap.icon:SetTexture(Book.IconForRec(cap.rec))
      end
      Book.SetGlow(cap, name and true or false)
      if not InCombat() then
        Book.SetAction(cap, cap.rec)
        if wrap.trackPrev then
          Book.SetAction(wrap.trackPrev, wrap.trackPrev.rec)
        end
      end
    end
  end
end

Book.CAP_MAX = 56

function Book.MakeExtra(parent)
  local wrap = CreateFrame("Frame", "NockExtraBar", parent)
  wrap:Hide()
  wrap.caps = {}
  for i = 1, Book.CAP_MAX do
    local cap = MakeChip(wrap, UTIL_TILE)
    cap.bindName = (cap.GetName and cap:GetName()) or ("NockBind" .. i)
    cap:Hide()
    wrap.caps[i] = cap
  end
  -- Hidden previous-track button (Shift-C). Same parent, off the row.
  local prev = MakeChip(wrap, UTIL_TILE)
  prev.bindName = prev.GetName and prev:GetName() or "NockBindTrackPrev"
  prev:Hide()
  wrap.trackPrev = prev
  wrap.rows = {}
  wrap.bars = {}
  for i = 1, 2 do
    local bar = CreateFrame("Frame", "NockExtraBar" .. i, wrap)
    bar:SetHeight(UTIL_H)
    bar:Hide()
    local wood = bar:CreateTexture(nil, "BACKGROUND")
    wood:SetAllPoints()
    if not SetTex(wood, "barwood", 0.14, 0.09, 0.05, 0.96) then
      SetTex(wood, "bar", 0.07, 0.12, 0.10, 0.92)
    end
    if wood.SetVertexColor then
      wood:SetVertexColor(0.78, 0.78, 0.78)
    end
    bar.wood = wood
    wrap.bars[i] = bar
  end
  if parent then
    parent.extra = wrap
  end
  return wrap
end

function Book.ApplyBinds()
  if InCombat() then
    return
  end
  Book.ClearBinds()
  local wrap = overlay and overlay.extra
  if not wrap then
    return
  end
  for _, cap in ipairs(wrap.caps or {}) do
    if cap.key and cap.bindName and cap.rec then
      Book.BindClick(cap.key, cap.bindName)
    end
  end
  if wrap.trackPrev and wrap.trackPrev.key and wrap.trackPrev.bindName then
    Book.BindClick(wrap.trackPrev.key, wrap.trackPrev.bindName)
  end
end

function Book.LayoutExtra()
  local wrap = overlay and overlay.extra
  if not wrap then
    return 0, 0
  end
  if InCombat() then
    if wrap:IsShown() then
      return wrap.barW or 0, wrap.rowH or 0
    end
    return 0, 0
  end
  local recs = Book.Assign()
  local visible, parked, trackPrevRec = {}, {}, nil
  for _, r in ipairs(recs) do
    if r.hidden and r.id == "track-prev" then
      trackPrevRec = r
    elseif Book.ShouldShowTile(r) then
      visible[#visible + 1] = r
    else
      parked[#parked + 1] = r
    end
  end

  local function fillCap(cap, rec)
    cap.rec = rec
    cap.known = rec and true or false
    if not rec then
      Book.SetAction(cap, nil)
      cap.entry = nil
      cap:Hide()
      return
    end
    if rec.id == "melee" then
      cap.entry = { kind = "macro", name = rec.label, macro = Book.MeleeMacro() }
    elseif rec.id and rec.id:find("pet-", 1, true) then
      cap.entry = { kind = "macro", name = rec.label, macro = Book.PetMacro(rec.id) }
    elseif rec.id and rec.id:find("track-", 1, true) then
      cap.entry = Book.SpellEntry(cap.spellName or Book.ActiveTrack() or "Track Beasts")
    else
      cap.entry = Book.SpellEntry(rec.id)
    end
    Book.SetAction(cap, rec)
    Book.PaintKey(cap, rec.key)
    if cap.icon then
      cap.icon:SetTexture(Book.IconForRec(rec))
    end
    StyleChip(cap, false)
    cap:SetSize(UTIL_TILE, UTIL_TILE)
    cap.tileSize = UTIL_TILE
  end

  for i, cap in ipairs(wrap.caps or {}) do
    if i > #visible + #parked then
      fillCap(cap, nil)
    end
  end
  if #visible == 0 and #parked == 0 and not trackPrevRec then
    wrap:Hide()
    if wrap.bars then
      for _, bar in ipairs(wrap.bars) do
        bar:Hide()
      end
    end
    if wrap.trackPrev then
      Book.SetAction(wrap.trackPrev, nil)
      wrap.trackPrev:Hide()
    end
    Book.ClearBinds()
    wrap.barW, wrap.rowH = 0, 0
    return 0, 0
  end

  local maxW = 991
  if overlay and overlay.GetWidth then
    local w = overlay:GetWidth()
    if type(w) == "number" and w > 400 then
      maxW = w
    end
  end
  local tileStep = UTIL_TILE + UTIL_GAP
  local maxPer = math.max(1, math.floor((maxW - 2 * UTIL_PAD + UTIL_GAP) / tileStep))
  local nBar = 1
  if #visible > maxPer then
    nBar = 2
  end
  local per = 0
  if #visible > 0 then
    per = math.ceil(#visible / nBar)
  end
  local barW = 0
  if per > 0 then
    barW = 2 * UTIL_PAD + per * UTIL_TILE + (per - 1) * UTIL_GAP
  end
  local rowH = UTIL_H
  local gapY = UTIL_GAP_Y
  local nRows = nBar
  if #visible == 0 then
    nRows = 0
  end
  local totalH = nRows * rowH + math.max(0, nRows - 1) * gapY

  if wrap.bars then
    for i, bar in ipairs(wrap.bars) do
      if i <= nRows then
        bar:SetHeight(UTIL_H)
        bar:SetWidth(barW)
        bar:ClearAllPoints()
        bar:SetPoint("TOP", wrap, "TOP", 0, -((i - 1) * (rowH + gapY)))
        bar:Show()
      else
        bar:Hide()
      end
    end
  end

  local ci = 0
  for ri = 1, nRows do
    local bar = wrap.bars and wrap.bars[ri] or wrap
    local a = (ri - 1) * per + 1
    local b = math.min(#visible, ri * per)
    local nThis = b - a + 1
    local rowW = 2 * UTIL_PAD + nThis * UTIL_TILE + math.max(0, nThis - 1) * UTIL_GAP
    local x = UTIL_PAD + math.floor((barW - rowW) / 2 + 0.5)
    local y = (rowH - UTIL_TILE) / 2
    for i = a, b do
      ci = ci + 1
      local rec = visible[i]
      local cap = wrap.caps[ci]
      if cap and rec then
        fillCap(cap, rec)
        cap:ClearAllPoints()
        cap:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y)
        cap:SetFrameLevel((bar.GetFrameLevel and bar:GetFrameLevel() or 0) + 2)
        cap:Show()
      end
      x = x + tileStep
    end
  end

  for _, rec in ipairs(parked) do
    ci = ci + 1
    local cap = wrap.caps[ci]
    if cap then
      fillCap(cap, rec)
      cap:ClearAllPoints()
      cap:SetPoint("TOPLEFT", wrap, "TOPLEFT", -200, 0)
      cap:Hide()
    end
  end

  wrap:SetWidth(math.max(barW, UTIL_TILE + 2 * UTIL_PAD))
  wrap:SetHeight(math.max(totalH, 1))
  wrap.barW = barW
  wrap.rowH = (totalH > 0 and (totalH + UTIL_GAP_Y)) or 0
  wrap.nRows = nRows
  wrap:ClearAllPoints()
  if nRows == 0 then
    wrap:Hide()
  else
    if overlay.util and overlay.util:IsShown() then
      wrap:SetPoint("TOP", overlay.util, "BOTTOM", 0, -UTIL_GAP_Y)
    else
      wrap:SetPoint("TOP", overlay.body, "BOTTOM", 0, -UTIL_GAP_Y)
    end
    wrap:Show()
  end

  if wrap.trackPrev then
    if trackPrevRec then
      wrap.trackPrev.rec = trackPrevRec
      Book.SetAction(wrap.trackPrev, trackPrevRec)
      wrap.trackPrev.key = trackPrevRec.key
      wrap.trackPrev:ClearAllPoints()
      wrap.trackPrev:SetPoint("TOPLEFT", wrap, "TOPLEFT", -200, 0)
      wrap.trackPrev:Hide()
    else
      Book.SetAction(wrap.trackPrev, nil)
      wrap.trackPrev:Hide()
    end
  end

  Book.ApplyBinds()
  Book.UpdateMeleeGlow()
  Book.UpdateTrackVisuals()
  return barW, wrap.rowH
end

function Book.StyleAll()
  local wrap = overlay and overlay.extra
  if not wrap then
    return
  end
  for _, cap in ipairs(wrap.caps or {}) do
    StyleChip(cap, false)
    cap:SetSize(UTIL_TILE, UTIL_TILE)
    cap.tileSize = UTIL_TILE
  end
end

function Book.UpdateExtra()
  if InCombat() then
    if overlay then
      overlay.pending = true
    end
    Book.UpdateMeleeGlow()
    Book.UpdateTrackVisuals()
    return
  end
  Book.LayoutExtra()
end


Nock.Book = Book

local function LayoutBar(keys)
  local x = PAD_X
  local order = MainBarKeys()
  BAR_KEYS = order
  -- The divider sits before the first "it's on me" key you have (Q onwards).
  local divAt, after, divShown = nil, false, false
  for _, key in ipairs(order) do
    if key == DIVIDER_BEFORE then
      after = true
    end
    if after and keys[key] and not divAt then
      divAt = key
    end
  end
  for _, key in ipairs(order) do
    local cap = overlay.caps[key]
    if keys[key] and cap then
      if key == divAt and x > PAD_X then
        divShown = true
        overlay.divider:ClearAllPoints()
        overlay.divider:SetPoint("LEFT", overlay.body, "LEFT", x - GAP + (GAP + DIV_W) / 2 - DIV_W / 2, 0)
        overlay.divider:Show()
        x = x + DIV_W
      end
      cap:ClearAllPoints()
      cap:SetPoint("LEFT", overlay.body, "LEFT", x, 0)
      x = x + TILE + GAP
    end
  end
  if not divShown then
    overlay.divider:Hide()
  end
  local bodyW = math.max(TILE + 2 * PAD_X, x - GAP + PAD_X)
  overlay.body:SetWidth(bodyW)
  local utilW = LayoutUtil(keys)
  local extraW, extraH = 0, 0
  do
    local a, b = SafeBuild("extra", "spell list", Book.LayoutExtra)
    if type(a) == "number" then
      extraW = a
    end
    if type(b) == "number" then
      extraH = b
    end
  end
  local xpH = SafeBuild("xp", "experience bar", LayoutXP, utilW, bodyW) or 0
  if type(xpH) ~= "number" then
    xpH = 0
  end
  local petH = SafeBuild("pet", "pet bar", Pet.LayoutPet) or 0
  if type(petH) ~= "number" then
    petH = 0
  end
  local barW = bodyW + FLETCH_W + HEAD_W - 2 * CAP_OVERLAP
  local xpW = (overlay.xp and overlay.xp:IsShown() and overlay.xp.GetWidth and overlay.xp:GetWidth()) or 0
  local petW = (overlay.pet and overlay.pet:IsShown() and overlay.pet.GetWidth and overlay.pet:GetWidth()) or 0
  if type(xpW) ~= "number" then
    xpW = 0
  end
  if type(petW) ~= "number" then
    petW = 0
  end
  if type(extraW) ~= "number" then
    extraW = 0
  end
  overlay:SetWidth(math.max(barW, utilW, xpW, petW, extraW))
  local h = BODY_H
  if overlay.util and overlay.util:IsShown() then
    h = h + UTIL_GAP_Y + UTIL_H
  end
  if extraH and extraH > 0 then
    h = h + extraH
  end
  if xpH > 0 then
    h = h + xpH
  end
  if petH > 0 then
    h = h + petH
  end
  overlay:SetHeight(h)
  local bowW = bodyW + 2 * BOW_OVERHANG
  local bowH = bowW * BOW_ASPECT
  overlay.bow:SetWidth(bowW)
  overlay.bow:SetHeight(bowH)
  overlay.bow:ClearAllPoints()
  overlay.bow:SetPoint("BOTTOM", overlay.body, "TOP", 0, BOW_STRING_OFFSET - bowH * BOW_STRING_FROM_BOTTOM)
end

local function ApplyFade()
  if not overlay then
    return
  end
  local db = BarDB()
  local a = 1
  if db.fade and not Nock.inCombatFlag and not overlay.hovering then
    a = FADE_ALPHA
  end
  overlay:SetAlpha(a)
end

local function UpdateOverlay()
  if not overlay then
    return
  end
  if InCombat() then
    -- Secure tiles can't change in combat. Repaint when it ends.
    overlay.pending = true
    return
  end
  overlay.pending = nil
  local spec = NockCharDB.spec or select(1, DetectSpec())
  local layout = LayoutFor(spec)
  -- Synthetic item tiles (not in the keymap layout).
  layout = layout or {}
  if HasItem("Hearthstone") then
    layout.HEARTH = ItemEntry("Hearthstone")
  end
  local food = FindFoodName()
  if food then
    layout.FOOD = ItemEntry(food, "Food")
  end
  local bad, shown = 0, {}
  local function paint(cap, key, knownCheck)
    if cap then
      cap.layout = layout
    end
    local e = layout[key]
    local ok = true
    if knownCheck and e and not knownCheck(key, e) then
      e = nil
    end
    if PaintChip(cap, key, e) then
      bad = bad + 1
    end
    if e and cap and cap:IsShown() then
      shown[key] = true
    end
  end
  local onBar = {}
  for _, key in ipairs(MainBarKeys()) do
    onBar[key] = true
  end
  for _, key in ipairs(BAR_KEYS_ALL) do
    if onBar[key] then
      paint(overlay.caps[key], key)
    else
      local cap = overlay.caps[key]
      if cap then
        cap:Hide()
      end
    end
  end
  if overlay.utilCaps then
    for _, key in ipairs(UTIL_KEYS) do
      paint(overlay.utilCaps[key], key, UtilKeyKnown)
    end
  end
  LayoutBar(shown)
  Nock.BarKeys = MainBarKeys()
  overlay.bad = bad
  if overlay.fix then
    overlay.fix:Hide()
  end
  overlay.profileLabel = ProfileLabel()
  ApplyFade()
  UpdateCooldowns()
  UpdateTints()
  if Nock.Threat and Nock.Threat.Layout then
    SafeBuild("threat", "threat meter", Nock.Threat.Layout)
  end
end

local function PositionOverlayDefaults(frame)
  frame = frame or overlay
  if not frame or InCombat() then
    return
  end
  frame:ClearAllPoints()
  local y = 190
  if Nock.ActionBars and Nock.ActionBars.Enabled and Nock.ActionBars.Enabled() then
    y = (Nock.ActionBars.BottomOffset and Nock.ActionBars.BottomOffset()) or 28
  end
  frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, y)
end

local SetOverlayShown

-- Hover: full alpha while the mouse is on the bar; Alt + hover peeks the card.
hoverCheck = function(entering)
  if not overlay then
    return
  end
  local function run()
    local over = entering or (overlay.IsMouseOver and overlay:IsMouseOver()) or false
    entering = nil
    overlay.hovering = over and true or false
    ApplyFade()
    local MR = Nock.UI and Nock.UI.MyRot
    if MR and MR.PeekCard then
      if over and IsAltKeyDown and IsAltKeyDown() then
        MR.PeekCard(true)
      elseif not over then
        MR.PeekCard(false)
      end
    end
  end
  if entering or not (C_Timer and C_Timer.After) then
    run()
  else
    C_Timer.After(0.1, run)
  end
end

local function ApplyBarSize()
  if InCombat() then
    pendingSize = true
    return
  end
  pendingSize = false
  ApplySizeConstants()
  if not overlay then
    return
  end
  if overlay.body then
    overlay.body:SetHeight(BODY_H)
  end
  if overlay.fletch then
    overlay.fletch:SetSize(FLETCH_W, CAP_H)
    overlay.fletch:ClearAllPoints()
    overlay.fletch:SetPoint("RIGHT", overlay.body, "LEFT", CAP_OVERLAP, 0)
  end
  if overlay.head then
    overlay.head:SetSize(HEAD_W, CAP_H)
    overlay.head:ClearAllPoints()
    overlay.head:SetPoint("LEFT", overlay.body, "RIGHT", -CAP_OVERLAP, 0)
  end
  if overlay.divider then
    overlay.divider:SetSize(DIV_W, math.floor(BODY_H * 0.78 + 0.5))
  end
  if overlay.util then
    overlay.util:SetHeight(UTIL_H)
    overlay.util:ClearAllPoints()
    overlay.util:SetPoint("TOP", overlay.body, "BOTTOM", 0, -UTIL_GAP_Y)
    if overlay.util.divs then
      for _, d in ipairs(overlay.util.divs) do
        d:SetHeight(UTIL_TILE - 8)
      end
    end
  end
  for _, cap in pairs(overlay.caps or {}) do
    StyleChip(cap, true)
  end
  for _, cap in pairs(overlay.utilCaps or {}) do
    StyleChip(cap, false)
  end
  if Book.StyleAll then
    Book.StyleAll()
  end
  UpdateOverlay()
  if Nock.UI and Nock.UI.ApplyWindowSize then
    Nock.UI.ApplyWindowSize()
  end
end

function Nock.SetBarSize(which)
  if which ~= "small" and which ~= "normal" then
    which = "large"
  end
  BarDB().barSize = which
  if InCombat() then
    pendingSize = true
    Print("Nock will change the bar size when the fight ends.")
    return
  end
  ApplyBarSize()
  if Nock.UI and Nock.UI.ApplyWindowSize then
    Nock.UI.ApplyWindowSize()
  end
end

function Nock.BarSize()
  return SizeKey()
end

function Nock.SetNockXP(on)
  BarDB().nockXP = on and true or false
  if overlay then
    UpdateOverlay()
  end
end

function Nock.SetNockPet(on)
  BarDB().nockPet = on and true or false
  if overlay then
    if InCombat() then
      overlay.pending = true
      SafeBuild("pet", "pet bar", Pet.UpdatePetBar)
    else
      UpdateOverlay()
    end
  end
end

local function CreateOverlay()
  if overlay then
    return overlay
  end
  if InCombat() then
    return nil -- secure tiles are never created in combat
  end
  ApplySizeConstants()
  local frame = CreateFrame("Frame", "NockOverlay", UIParent)
  frame:SetSize(400, BODY_H)
  frame:SetFrameStrata("MEDIUM")
  PositionOverlayDefaults(frame)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  -- It holds secure buttons, so it can't move in combat.
  frame:SetScript("OnDragStart", function(self)
    if not InCombat() and not BarDB().barLocked then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    if point then
      BarDB().barPos = { point, relPoint, x, y }
    end
  end)
  frame:SetScript("OnEnter", function()
    hoverCheck(true)
  end)
  frame:SetScript("OnLeave", function()
    hoverCheck()
  end)
  frame:SetClampedToScreen(true)

  -- Moonwood plaque between an arrow's fletching (left) and broadhead (right).
  local body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOP", 0, 0)
  body:SetHeight(BODY_H)
  body:SetWidth(300)
  frame.body = body
  local wood = body:CreateTexture(nil, "BACKGROUND")
  wood:SetAllPoints()
  if not SetTex(wood, "barwood", 0.18, 0.11, 0.06, 0.96) then
    SetTex(wood, "bar", 0.07, 0.12, 0.10, 0.92)
  end
  frame.wood = wood
  -- Barrel / arrow caps are a child behind the plaque so their art cannot
  -- paint over the key tiles. Layout size stays the same.
  local capHold = CreateFrame("Frame", nil, frame)
  local baseLevel = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
  if capHold.SetFrameLevel then
    capHold:SetFrameLevel(baseLevel + 1)
  end
  if body.SetFrameLevel then
    body:SetFrameLevel(baseLevel + 4)
  end
  frame.capHold = capHold
  local fl = capHold:CreateTexture(nil, "ARTWORK")
  fl:SetSize(FLETCH_W, CAP_H)
  fl:SetPoint("RIGHT", body, "LEFT", CAP_OVERLAP, 0)
  if not SetTex(fl, "fletch") then
    fl:Hide()
  else
    -- Packed 1024x512. Crop comes from the active style (Emerald vs Gunsmith).
    local uv = (_G.NockTheme and _G.NockTheme.CapUV and _G.NockTheme.CapUV("fletch")) or { 2 / 1024, 1019 / 1024, 5 / 512, 505 / 512 }
    SetCrop(fl, uv[1], uv[2], uv[3], uv[4])
  end
  frame.fletch = fl
  local hd = capHold:CreateTexture(nil, "ARTWORK")
  hd:SetSize(HEAD_W, CAP_H)
  hd:SetPoint("LEFT", body, "RIGHT", -CAP_OVERLAP, 0)
  if not SetTex(hd, "head") then
    hd:Hide()
  else
    -- Packed 1024x512. Crop comes from the active style.
    local uv = (_G.NockTheme and _G.NockTheme.CapUV and _G.NockTheme.CapUV("head")) or { 4 / 1024, 851 / 1024, 3 / 512, 509 / 512 }
    SetCrop(hd, uv[1], uv[2], uv[3], uv[4])
  end
  frame.head = hd
  -- The longbow arcs over the plaque; the string sits just above the tiles.
  -- A child frame above the plaque (but below the tiles) lets the string
  -- paint over the wood margin without covering the key icons.
  local bowHold = CreateFrame("Frame", nil, frame)
  bowHold:SetFrameLevel(body:GetFrameLevel() + 1)
  local bow = bowHold:CreateTexture(nil, "ARTWORK")
  bow:SetHeight(80)
  bow:SetWidth(420)
  bow:SetPoint("BOTTOM", body, "TOP", 0, -15)
  if not SetTex(bow, "bow") then
    bow:Hide()
  else
    -- Packed 2048x512, content x=7-2041 y=119-502 (string near the bottom).
    SetCrop(bow, 7 / 2048, 2042 / 2048, 119 / 512, 503 / 512)
  end
  frame.bowHold = bowHold
  frame.bow = bow
  local div = body:CreateTexture(nil, "ARTWORK")
  div:SetSize(DIV_W, 44)
  if not SetTex(div, "divider_v") then
    if not SetTex(div, "divider") then
      div:SetColorTexture(0.5, 0.66, 0.6, 0.6)
      div:SetWidth(1)
    end
  end
  frame.divider = div

  frame.caps = {}
  for _, key in ipairs(BAR_KEYS_ALL) do
    local cap = MakeChip(body)
    cap:SetFrameLevel(body:GetFrameLevel() + 2)
    cap:Hide()
    frame.caps[key] = cap
  end
  -- 3.0 utility tray, under the plaque. Tiles are created now so combat never
  -- has to create a secure button.
  local tray = CreateFrame("Frame", nil, frame)
  if tray.SetFrameLevel and body.GetFrameLevel then
    tray:SetFrameLevel((body:GetFrameLevel() or 5))
  end
  tray:SetPoint("TOP", body, "BOTTOM", 0, -UTIL_GAP_Y)
  tray:SetHeight(UTIL_H)
  tray:SetWidth(200)
  local twood = tray:CreateTexture(nil, "BACKGROUND")
  twood:SetAllPoints()
  if not SetTex(twood, "barwood", 0.14, 0.09, 0.05, 0.96) then
    SetTex(twood, "bar", 0.07, 0.12, 0.10, 0.92)
  end
  if twood.SetVertexColor then
    twood:SetVertexColor(0.78, 0.78, 0.78)
  end
  tray.wood = twood
  tray.divs = {}
  for i = 1, #UTIL_GROUPS - 1 do
    local d = tray:CreateTexture(nil, "ARTWORK")
    d:SetSize(1, UTIL_TILE - 8)
    d:SetColorTexture(0.55, 0.75, 0.6, 0.6)
    d:Hide()
    tray.divs[i] = d
  end
  tray:Hide()
  frame.util = tray
  frame.utilCaps = {}
  for _, key in ipairs(UTIL_KEYS) do
    local cap = MakeChip(tray, UTIL_TILE)
    cap:SetFrameLevel(tray:GetFrameLevel() + 2)
    cap:Hide()
    frame.utilCaps[key] = cap
  end
  frame.xp = SafeBuild("xp", "experience bar", MakeXPBar, frame)
  frame.pet = SafeBuild("pet", "pet bar", Pet.MakePetBar, frame)
  frame.extra = SafeBuild("extra", "spell list", Book.MakeExtra, frame)
  -- Re-assert after the tiles so the string stays above the plaque and below icons.
  if frame.bowHold then
    frame.bowHold:SetFrameLevel(body:GetFrameLevel() + 1)
  end

  -- Non-secure "New: <spell>" toast. Can be shown in combat; the tile itself
  -- only appears out of combat.
  local toast = CreateFrame("Frame", "NockNewSpellToast", UIParent)
  toast:SetFrameStrata("HIGH")
  toast:SetSize(220, 28)
  toast:Hide()
  local toastWood = toast:CreateTexture(nil, "BACKGROUND")
  toastWood:SetAllPoints()
  if not SetTex(toastWood, "barwood", 0.14, 0.09, 0.05, 0.96) then
    toastWood:SetColorTexture(0.07, 0.12, 0.10, 0.92)
  end
  local toastEdge = toast:CreateTexture(nil, "BORDER")
  toastEdge:SetPoint("TOPLEFT", -1, 1)
  toastEdge:SetPoint("BOTTOMRIGHT", 1, -1)
  toastEdge:SetColorTexture(0.31, 0.78, 0.51, 0.7)
  local toastBg = toast:CreateTexture(nil, "ARTWORK")
  toastBg:SetAllPoints()
  if not SetTex(toastBg, "barwood") then
    toastBg:SetColorTexture(0.07, 0.12, 0.10, 0.92)
  end
  local toastText = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  EnsureFont(toastText, "GameFontHighlight")
  toastText:SetPoint("CENTER", 0, 0)
  toastText:SetTextColor(0.82, 1, 0.86)
  toast.text = toastText
  frame.toast = toast

  -- Shown only when a key doesn't hold what its tile says. Runs Nock's setup,
  -- out of combat only (Setup queues it if you're fighting).
  local fix = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  fix:SetSize(90, 20)
  -- Sit above the plaque, not over the (now much wider) arrowhead.
  fix:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 0, 12)
  fix:SetText("Set me up")
  fix:SetScript("OnClick", function()
    -- 2.1: an old setup gets the "move my keys" popup, not a full re-setup.
    if Nock.Keymap21 and Nock.Keymap21.Pending() then
      return Nock.Keymap21.ShowPopup(true)
    end
    if InCombat() then
      Print("Leave combat first. Nock sets up your keys as soon as you can.")
      if Nock.Setup then
        Nock.Setup.applyQueued = Nock.Setup.Pick().key
      end
      return
    end
    if Nock.Setup and Nock.Setup.Apply then
      Nock.Setup.Apply(Nock.Setup.Pick().key)
    else
      local _, text = ApplyLayout(NockCharDB.spec or select(1, DetectSpec()))
      Print(text)
    end
    UpdateOverlay()
  end)
  fix:Hide()
  frame.fix = fix

  overlay = frame
  frame:SetScript("OnUpdate", TickBar)
  local pos = BarDB().barPos
  if type(pos) == "table" and pos[1] then
    frame:ClearAllPoints()
    frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end
  UpdateOverlay()
  return frame
end

-- "New: <spell>" toast. Non-secure; safe to show in combat. The tile still
-- waits for PLAYER_REGEN_ENABLED.
local toastQueue, toastPendingName = {}, nil

local function ShowToast(message, duration)
  duration = duration or 5
  if not overlay then
    -- Remember it; CreateOverlay will not auto-play, but the next Update can.
    toastPendingName = message
    return
  end
  local toast = overlay.toast
  if not toast then
    return
  end
  toast.text:SetText(message or "")
  local w = (toast.text.GetStringWidth and toast.text:GetStringWidth()) or 160
  if type(w) ~= "number" or w < 40 then
    w = 160
  end
  toast:SetWidth(math.max(160, w + 28))
  toast:ClearAllPoints()
  if overlay.util and overlay.util:IsShown() then
    toast:SetPoint("LEFT", overlay.util, "RIGHT", 10, 0)
  else
    toast:SetPoint("TOP", overlay, "BOTTOM", 0, -8)
  end
  toast:Show()
  toast.expires = (GetTime and GetTime() or 0) + duration
  if C_Timer and C_Timer.After then
    C_Timer.After(duration, function()
      if overlay and overlay.toast and overlay.toast.expires and GetTime and GetTime() >= overlay.toast.expires - 0.05 then
        overlay.toast:Hide()
      end
    end)
  end
end

local function QueueLearnedToast(spellName, inCombat)
  if not spellName or spellName == "" then
    return
  end
  -- Debounce the same name for a few seconds (learn + SPELLS_CHANGED + level-up).
  toastPendingName = spellName
  ShowToast("New: " .. spellName, 5)
end

Nock.ShowToast = ShowToast

SetOverlayShown = function(shown)
  NockCharDB.overlay = shown and true or false
  if InCombat() then
    -- Can't create, show or hide secure tiles now; do it when combat ends.
    Nock.overlayShowPending = true
    Print("Nock will " .. (shown and "show" or "hide") .. " the key bar when combat ends.")
    return
  end
  Nock.overlayShowPending = nil
  if shown then
    local f = CreateOverlay()
    if f then
      f:Show()
      UpdateOverlay()
    end
  elseif overlay then
    overlay:Hide()
    if Book.ClearBinds then
      Book.ClearBinds()
    end
    local MR = Nock.UI and Nock.UI.MyRot
    if MR and MR.PeekCard then
      MR.PeekCard(false)
    end
  end
  if Nock.RefreshUI then
    Nock.RefreshUI()
  end
end

function Nock.ResetBarPosition()
  BarDB().barPos = nil
  PositionOverlayDefaults()
end

function Nock.SetFade(on)
  BarDB().fade = on and true or false
  ApplyFade()
end
Nock.ApplyFade = ApplyFade
Nock.UpdateXPBar = UpdateXPBar
Nock.UpdatePetBar = Pet.UpdatePetBar
Nock.ApplyBarSize = ApplyBarSize
Nock.BarKeys = BAR_KEYS_MOUSE
Nock.BarKeysAll = BAR_KEYS_ALL
Nock.UtilKeys = UTIL_KEYS
Nock.MainBarKeys = MainBarKeys

local function OverlayAfterCombat()
  if pendingSize and not InCombat() then
    ApplyBarSize()
  end
  local Theme = _G.NockTheme
  if Theme and Theme.ApplyPendingStyle then
    pcall(Theme.ApplyPendingStyle)
  end
  if Nock.Threat and Nock.Threat.ApplyPendingUnlock then
    pcall(Nock.Threat.ApplyPendingUnlock)
  end
  if Nock.bootPending and Nock.BootQuiet then
    Nock.BootQuiet()
  end
  if Nock.overlayShowPending then
    SetOverlayShown(NockCharDB.overlay)
  elseif overlay and overlay.pending then
    UpdateOverlay()
  end
end

local function IsOverlayShown()
  return overlay and overlay:IsShown() and true or false
end

-- Main window ---------------------------------------------------------------
-- UI.lua (1.5.0) builds the window. These are what it shares from here.

local KEY_GROUPS = {
  { title = "Shots", keys = { "1", "2", "3", "4", "5", "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5", "ALT-2", "ALT-3", "ALT-4", "ALT-5", "R", "ALT-1" } },
  { title = "Close range and escapes", keys = { "6", "SHIFT-6", "Q", "BUTTON5", "BUTTON4", "SHIFT-Z", "SHIFT-Q", "ALT-Q", "SHIFT-BUTTON4", "SHIFT-BUTTON5", "CTRL-Q", "E", "BUTTON3", "SHIFT-E", "ALT-E", "CTRL-E" } },
  { title = "Traps and utility", keys = { "F", "SHIFT-F", "ALT-F", "CTRL-F", "SHIFT-R", "ALT-R", "H", "SHIFT-H", "SHIFT-C", "ALT-C", "CTRL-C" } },
  { title = "Pet and aspects", keys = { "T", "SHIFT-T", "ALT-T", "CTRL-T", "G", "SHIFT-G", "ALT-G", "CTRL-G", "X", "SHIFT-X", "ALT-X", "CTRL-X", "Z", "CTRL-Z" } },
}

local FIELD_ORDER = {
  bm = {
    "Auto Shot", "Aimed Shot", "Multi-Shot", "Arcane Shot", "Summon Hawk", "Bestial Wrath", "Intimidation",
    "Serpent Sting", "Hunter's Mark", "Rapid Fire", "Freezing Trap", "Immolation Trap", "Frost Trap",
    "Feign Death", "Raptor Strike", "Wing Clip", "Aspect of the Hawk", "Aspect of the Cheetah", "Aspect of the Viper",
  },
  marks = {
    "Auto Shot", "Aimed Shot", "Multi-Shot", "Arcane Shot", "Sniper Shot", "Trueshot Aura", "Lone Wolf",
    "Serpent Sting", "Hunter's Mark", "Rapid Fire", "Freezing Trap", "Immolation Trap", "Frost Trap",
    "Feign Death", "Raptor Strike", "Wing Clip", "Aspect of the Hawk", "Aspect of the Cheetah", "Aspect of the Viper",
  },
}

local function RestoreKeys()
  local ok, text = RestoreSnapshot(NockCharDB.snapshot)
  if ok then
    NockCharDB.applied = false
    Print("Restored the keybinds Nock found before your first apply.")
    UpdateOverlay()
  else
    Print(text)
  end
  if Nock.RefreshUI then
    Nock.RefreshUI()
  end
  return ok
end

-- 1.4.0 helpers kept for anything that still calls them; they now make
-- standard Blizzard red panel buttons.
local function PaintBtn(b)
  if b and b.SetNormalFontObject then
    b:SetNormalFontObject((b.primary or b.selected) and "GameFontNormal" or "GameFontHighlight")
  end
end

local function MakeNiceBtn(parent, text, width, height)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 140, height or 22)
  b:SetText(text)
  return b
end

local function ShowPanelFallback()
  Print("Nock's window failed to load. Slash commands still work: /nock help")
end

function Nock.ShowPanel(tab, spec)
  if not IsHunter() then
    Print("This is a hunter addon. Log in on a hunter to use it.")
    return
  end
  ShowPanelFallback()
end

function Nock:Open()
  Nock.ShowPanel("profiles", NockCharDB.spec)
end

-- Shared with Profiles.lua --------------------------------------------------

Nock.Print = Print
Nock.IsHunter = IsHunter

-- Recrop style-specific art after a live style swap (no /reload).
function Nock.ApplyStyleCrops()
  if not overlay then
    return
  end
  local Theme = _G.NockTheme
  local function cap(tex, which, fallback)
    if not tex then
      return
    end
    local uv = (Theme and Theme.CapUV and Theme.CapUV(which)) or fallback
    SetCrop(tex, uv[1], uv[2], uv[3], uv[4])
  end
  cap(overlay.fletch, "fletch", { 2 / 1024, 1019 / 1024, 5 / 512, 505 / 512 })
  cap(overlay.head, "head", { 4 / 1024, 851 / 1024, 3 / 512, 509 / 512 })
  if overlay.xp then
    UpdateXPBar(overlay.xp)
  end
end

function Nock.SetStyle(id)
  local Theme = _G.NockTheme
  if Theme and Theme.SetStyle then
    return Theme.SetStyle(id)
  end
end

function Nock.StyleId()
  local Theme = _G.NockTheme
  if Theme and Theme.StyleId then
    return Theme.StyleId()
  end
  return "emerald"
end

function Nock.ToggleStyle()
  local Theme = _G.NockTheme
  if Theme and Theme.ToggleStyle then
    return Theme.ToggleStyle()
  end
end

function Nock._CopyPos(t)
  if type(t) ~= "table" then
    return nil
  end
  local n = {}
  for k, v in pairs(t) do
    n[k] = v
  end
  return n
end

-- Everything that makes this character's HUD look like itself.
function Nock.SnapshotUI()
  local db = NockCharDB or {}
  return {
    hudStyle = db.hudStyle or "emerald",
    barSize = db.barSize or "large",
    threatPos = Nock._CopyPos(db.threatPos),
    threatLocked = db.threatLocked ~= false,
    nockThreat = db.nockThreat ~= false,
    nockXP = db.nockXP ~= false,
    nockPet = db.nockPet ~= false,
    fade = db.fade and true or false,
    barLocked = db.barLocked ~= false,
    barPos = Nock._CopyPos(db.barPos),
    hideBlizzardBars = db.hideBlizzardBars ~= false,
    overlay = db.overlay ~= false,
    barCooldowns = db.barCooldowns ~= false,
    mouse = db.mouse ~= false,
    crosshair = db.crosshair ~= false,
    talentReminder = db.talentReminder ~= false,
    showLauncher = db.showLauncher ~= false,
    launcherPos = Nock._CopyPos(db.launcherPos),
  }
end

function Nock.SaveUI()
  NockCharDB = NockCharDB or {}
  -- The snapshot already lives in NockCharDB (WoW writes it on /reload and
  -- logout). Touch a timestamp so the table is dirty and confirm in chat.
  local when = (date and date("%Y-%m-%d %H:%M:%S")) or tostring(time and time() or "")
  NockCharDB.uiSavedAt = when
  return Nock.SnapshotUI(), when
end

function Nock.ApplyUISnapshot(snap)
  if type(snap) ~= "table" then
    return false, "missing"
  end
  if InCombat() then
    return false, "combat"
  end
  local db = NockCharDB or {}
  NockCharDB = db
  db.hudStyle = snap.hudStyle or db.hudStyle
  db.barSize = snap.barSize or db.barSize
  db.threatPos = Nock._CopyPos(snap.threatPos)
  db.threatLocked = snap.threatLocked and true or false
  db.nockThreat = snap.nockThreat ~= false
  db.nockXP = snap.nockXP ~= false
  db.nockPet = snap.nockPet ~= false
  db.fade = snap.fade and true or false
  db.barLocked = snap.barLocked and true or false
  db.barPos = Nock._CopyPos(snap.barPos)
  db.hideBlizzardBars = snap.hideBlizzardBars ~= false
  db.overlay = snap.overlay ~= false
  db.barCooldowns = snap.barCooldowns ~= false
  db.mouse = snap.mouse ~= false
  db.crosshair = snap.crosshair ~= false
  db.talentReminder = snap.talentReminder ~= false
  db.showLauncher = snap.showLauncher ~= false
  db.launcherPos = Nock._CopyPos(snap.launcherPos)

  local Theme = _G.NockTheme
  if Theme and Theme.SetStyle then
    Theme.SetStyle(db.hudStyle or "emerald")
  end
  if Nock.SetBarSize then
    Nock.SetBarSize(db.barSize or "large")
  end
  if Nock.SetNockXP then Nock.SetNockXP(db.nockXP) end
  if Nock.SetNockPet then Nock.SetNockPet(db.nockPet) end
  if Nock.SetNockThreat then Nock.SetNockThreat(db.nockThreat) end
  if Nock.Threat and Nock.Threat.SetLocked then
    Nock.Threat.SetLocked(db.threatLocked)
  end
  if Nock.Threat and Nock.Threat.Layout then
    Nock.Threat.Layout()
  end
  if Nock.SetFade then Nock.SetFade(db.fade) end
  if Nock.SetBarCooldowns then Nock.SetBarCooldowns(db.barCooldowns) end
  if Nock.Keymap21 and Nock.Keymap21.SetMouse then
    Nock.Keymap21.SetMouse(db.mouse)
  end
  if Nock.ActionBars and Nock.ActionBars.SetEnabled then
    Nock.ActionBars.SetEnabled(db.hideBlizzardBars)
  end
  if Nock.SetOverlayShown then
    Nock.SetOverlayShown(db.overlay)
  end
  if Nock.Launcher and Nock.Launcher.Update then
    Nock.Launcher.Update()
  end
  UpdateOverlay()
  return true
end

function Nock.ProfileSave(name)
  if type(name) ~= "string" or name == "" then
    return false, "name"
  end
  name = strtrim(name)
  if name == "" then
    return false, "name"
  end
  NockDB = NockDB or {}
  NockDB.uiProfiles = NockDB.uiProfiles or {}
  NockDB.uiProfiles[name] = Nock.SnapshotUI()
  return true, name
end

function Nock.ProfileLoad(name)
  if type(name) ~= "string" or name == "" then
    return false, "name"
  end
  name = strtrim(name)
  local rec = NockDB and NockDB.uiProfiles and NockDB.uiProfiles[name]
  if not rec then
    return false, "missing"
  end
  return Nock.ApplyUISnapshot(rec)
end

function Nock.ProfileList()
  local names = {}
  local recs = NockDB and NockDB.uiProfiles or {}
  for n in pairs(recs) do
    names[#names + 1] = n
  end
  table.sort(names)
  return names
end


Nock.PlayerKnows = PlayerKnows
Nock.LayoutFor = LayoutFor
Nock.ApplyLayout = ApplyLayout
Nock.UpdateOverlay = UpdateOverlay
Nock.SetOverlayShown = SetOverlayShown

-- 3.0: first login just works. Show the bar, fill only empty keys, and leave
-- anything already bound alone. No setup window, no dragging.
function Nock.BootQuiet()
  if not IsHunter() then
    return
  end
  if InCombat() then
    Nock.bootPending = true
    return
  end
  Nock.bootPending = nil
  if NockCharDB.overlay ~= false then
    SetOverlayShown(true)
  end
  if NockCharDB.setupDeclined then
    return
  end
  if Nock.Setup and Nock.Setup.Pick then
    local p = Nock.Setup.Pick()
    if p and not NockCharDB.profile then
      NockCharDB.profile = p.key
      NockCharDB.spec = p.spec
    end
  end
  NockCharDB.quietBoot = true
  if Nock.Setup and Nock.Setup.KeepUp then
    Nock.Setup.KeepUp()
  end
end
Nock.MakeNiceBtn = MakeNiceBtn
Nock.PaintBtn = PaintBtn
Nock.Version = VERSION

function Nock.NoteError(where, err)
  NockCharDB = NockCharDB or {}
  NockCharDB.errors = NockCharDB.errors or {}
  local when = (date and date("%Y-%m-%d %H:%M:%S")) or "?"
  table.insert(NockCharDB.errors, 1, when .. " " .. tostring(where) .. ": " .. tostring(err))
  while #NockCharDB.errors > 20 do
    table.remove(NockCharDB.errors)
  end
end
Nock.LayoutVersion = LAYOUT_VERSION
Nock.Theme = _G.NockTheme
Nock.NOTES = NOTES
Nock.SpellData = SpellData
Nock.EntryLabel = EntryLabel
Nock.EntryKnown = EntryKnown
Nock.KeyLabel = OverlayKeyLabel
Nock.IconFor = IconFor
Nock.MacroSpell = MacroSpell
Nock.TipFor = TipFor
Nock.ExtraLine = ExtraLine
Nock.CoreRows = CORE_ROWS
Nock.ExtraKeys = EXTRA_KEYS
Nock.KeyGroups = KEY_GROUPS
Nock.KeycapOrder = KEYCAP_ORDER
Nock.FieldOrder = FIELD_ORDER
Nock.RestoreKeys = RestoreKeys
Nock.IsOverlayShown = IsOverlayShown
Nock.OverlayAfterCombat = OverlayAfterCombat
Nock.Overlay = function() return overlay end
Nock.ShowNote = ShowNote
Nock.EnsureMacro = EnsureMacro
Nock.PickupEntry = PickupEntry
Nock.BindingCommand = BindingCommand
Nock.ClearCursorSafe = ClearCursorSafe
Nock.RetireOldKeys = RetireOldKeys
Nock.RetiredKeys = RETIRED_KEYS
Nock.MouseOn = MouseOn
Nock.MouseKeys = MOUSE_KEYS
Nock.MouseName = MOUSE_NAME
Nock.MouseTwin = MOUSE_TWIN
Nock.KeymapVersion = KEYMAP

-- One key for one action, out of combat (My Rotation's "Bind it"). The key's
-- old binding goes into the Restore Keys snapshot first.
function Nock.BindEntry(key, entry)
  if InCombatLockdown() then
    return false, "Leave combat first — Nock only changes keys out of combat."
  end
  if not (key and entry) then
    return false, "Nothing to bind."
  end
  if entry.kind ~= "macro" and not PlayerKnows(entry.name) then
    return false, "You haven't learned " .. entry.name .. " yet."
  end
  if entry.kind == "macro" and not EnsureMacro(entry) then
    return false, "Couldn't create the macro " .. entry.name .. " (your macro list may be full)."
  end
  NockCharDB.snapshot = NockCharDB.snapshot or { keys = {}, slots = {}, time = time() }
  NockCharDB.snapshot.keys = NockCharDB.snapshot.keys or {}
  if NockCharDB.snapshot.keys[key] == nil then
    NockCharDB.snapshot.keys[key] = GetBindingAction(key, true) or ""
  end
  SetBinding(key)
  if entry.kind == "macro" then
    SetBindingMacro(key, entry.name)
  else
    SetBindingSpell(key, entry.name)
  end
  SaveBindings(GetCurrentBindingSet())
  return true, "Bound " .. EntryLabel(entry) .. " to " .. OverlayKeyLabel(key) .. ". Restore Keys can undo it."
end

-- Events ------------------------------------------------------------------

local ev = CreateFrame("Frame")
local function SafeRegister(name)
  pcall(ev.RegisterEvent, ev, name)
end
SafeRegister("ADDON_LOADED")
SafeRegister("PLAYER_LOGIN")
SafeRegister("PLAYER_ENTERING_WORLD")
SafeRegister("PLAYER_LEVEL_UP")
SafeRegister("SPELLS_CHANGED")
SafeRegister("LEARNED_SPELL_IN_TAB")
SafeRegister("LEARNED_SPELL_IN_SKILL_LINE")
SafeRegister("MINIMAP_UPDATE_TRACKING")
SafeRegister("PLAYER_REGEN_ENABLED")
SafeRegister("PLAYER_REGEN_DISABLED")
SafeRegister("MODIFIER_STATE_CHANGED")
SafeRegister("PLAYER_TALENT_UPDATE")
SafeRegister("SPELL_UPDATE_COOLDOWN")
SafeRegister("ACTIONBAR_UPDATE_COOLDOWN")
SafeRegister("SPELL_UPDATE_USABLE")
SafeRegister("PLAYER_TARGET_CHANGED")
SafeRegister("PLAYER_XP_UPDATE")
SafeRegister("UPDATE_EXHAUSTION")
SafeRegister("PLAYER_UPDATE_RESTING")
SafeRegister("UNIT_PET")
SafeRegister("PET_BAR_UPDATE")
SafeRegister("PET_BAR_UPDATE_COOLDOWN")
SafeRegister("PET_BAR_UPDATE_USABLE")
SafeRegister("PET_UI_UPDATE")
SafeRegister("UNIT_HAPPINESS")
SafeRegister("UNIT_PET_EXPERIENCE")
SafeRegister("UNIT_PET_TRAINING_POINTS")

ev:SetScript("OnEvent", function(_, event, arg1, ...)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    NockDB = NockDB or {}
    NockCharDB = NockCharDB or {}
    if NockCharDB.overlay == nil then
      NockCharDB.overlay = true
    end
    if NockCharDB.autofill == nil then
      NockCharDB.autofill = true
    end
    if NockCharDB.notes == nil then
      NockCharDB.notes = true
    end
    if NockCharDB.fade == nil then
      NockCharDB.fade = false
    end
    if NockCharDB.crosshair == nil then
      NockCharDB.crosshair = true
    end
    -- 2.0: the cheat sheet card is hidden until you ask for it (Alt over the
    -- key bar, its key binding, or the minimap right-click).
    if not NockCharDB.v2 then
      NockCharDB.v2 = true
      NockCharDB.card = false
    end
    -- 3.0: hide Blizzard bars by default and dock the bow bar at center-bottom
    -- once. A saved barPos from 2.x would sit too high over a now-empty gap.
    if not NockCharDB.v3 then
      NockCharDB.v3 = true
      if NockCharDB.hideBlizzardBars == nil then
        NockCharDB.hideBlizzardBars = true
      end
      NockCharDB.barPos = nil
      NockCharDB.barLocked = true
      NockCharDB.fade = false
    end
    -- SavedVariables are available now. Re-apply the character's style
    -- (and any other art that depends on it) before the HUD is built.
    local Theme = _G.NockTheme
    if Theme and Theme.LoadSavedStyle then
      pcall(Theme.LoadSavedStyle)
    end
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    Nock.inCombatFlag = InCombat()
    if IsHunter() then
      if Nock.ActionBars and Nock.ActionBars.Apply and not InCombat() then
        local ok, err = pcall(Nock.ActionBars.Apply)
        if not ok and Nock.NoteError then
          Nock.NoteError("ActionBars.Apply", err)
        end
      end
      if Nock.BootQuiet then
        local ok, err = pcall(Nock.BootQuiet)
        if not ok and Nock.NoteError then
          Nock.NoteError("BootQuiet", err)
        end
      elseif NockCharDB.overlay ~= false then
        SetOverlayShown(true)
      end
      if event == "PLAYER_LOGIN" then
        Print("Nock is ready. Type |cfff0e2b6/nock|r for options.")
      end
    end
  elseif event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
    C_Timer.After(0.4, function()
      NoteForSpellID(arg1)
      TryAutoFill()
      local spellName = SpellData(arg1)
      local fighting = InCombat()
      if fighting then
        if overlay then
          overlay.pending = true
        end
      end
      UpdateOverlay() -- no-ops (queues) in combat
      if type(spellName) == "string" and spellName ~= "" then
        -- Only toast catalog spells (keymap or items), not random trainer abilities.
        local catalog = Book.IsCatalog(spellName) or Book.IsTrackName(spellName)
        if not catalog then
          local layout = LayoutFor(NockCharDB.spec or select(1, DetectSpec()))
          for _, e in pairs(layout or {}) do
            if e and e.name == spellName then
              catalog = true
              break
            end
          end
        end
        if catalog then
          QueueLearnedToast(spellName, fighting)
        end
      end
      if Nock.RefreshUI then
        Nock.RefreshUI()
      end
    end)
  elseif event == "PLAYER_LEVEL_UP" then
    C_Timer.After(0.4, function()
      if IsHunter() and Nock.OnLevelUp then
        Nock.OnLevelUp(arg1)
      end
      TryAutoFill()
      UpdateOverlay()
      if Nock.RefreshUI then
        Nock.RefreshUI()
      end
    end)
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Only the bar's alpha changes (allowed in combat). Nothing reads the fight.
    Nock.inCombatFlag = true
    ApplyFade()
  elseif event == "MODIFIER_STATE_CHANGED" then
    -- Alt + hover over the key bar peeks the Hunting Notes card.
    if arg1 == "LALT" or arg1 == "RALT" then
      local MR = Nock.UI and Nock.UI.MyRot
      if MR and MR.PeekCard and overlay and overlay:IsShown() then
        local down = select(1, ...) == 1
        if down and overlay.IsMouseOver and overlay:IsMouseOver() then
          MR.PeekCard(true)
        elseif not down then
          MR.PeekCard(false)
        end
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    Nock.inCombatFlag = false
    ApplyFade()
    OverlayAfterCombat()
    if Nock.RefreshUI then
      Nock.RefreshUI()
    end
  elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
    SafeBuild("xp", "experience bar", UpdateXPBar)
  elseif event == "UNIT_PET" or event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" then
    if arg1 and event == "UNIT_PET" and arg1 ~= "player" then
      return
    end
    if InCombat() then
      SafeBuild("pet", "pet bar", Pet.UpdatePetBar)
    else
      UpdateOverlay()
    end
  elseif event == "PET_BAR_UPDATE_COOLDOWN" or event == "PET_BAR_UPDATE_USABLE"
      or event == "UNIT_HAPPINESS" or event == "UNIT_PET_EXPERIENCE"
      or event == "UNIT_PET_TRAINING_POINTS" then
    SafeBuild("pet", "pet bar", Pet.UpdatePetBar)
  elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
    UpdateCooldowns() -- display only, allowed in combat (no secure changes)
  elseif event == "SPELL_UPDATE_USABLE" or event == "PLAYER_TARGET_CHANGED" then
    UpdateTints()
    SafeBuild("pet", "pet bar", Pet.UpdatePetVisuals)
  elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    if event == "SPELLS_CHANGED" and InCombat() and overlay then
      overlay.pending = true
    end
    UpdateOverlay()
    if Nock.RefreshUI then
      Nock.RefreshUI()
    end
  elseif event == "MINIMAP_UPDATE_TRACKING" then
    if Book.UpdateTrackVisuals then
      Book.UpdateTrackVisuals()
    end
  end
end)

SLASH_NOCK1 = "/nock"
SlashCmdList.NOCK = function(msg)
  msg = string.lower(strtrim(msg or ""))
  if msg == "bm" or msg == "beast" or msg == "beast mastery" then
    local ok, text = ApplyLayout("bm")
    Print(text)
    if ok then
      UpdateOverlay()
      if NockCharDB.overlay ~= false then
        SetOverlayShown(true)
      end
    end
  elseif msg == "marks" or msg == "mm" or msg == "marksmanship" then
    local ok, text = ApplyLayout("marks")
    Print(text)
    if ok then
      UpdateOverlay()
      if NockCharDB.overlay ~= false then
        SetOverlayShown(true)
      end
    end
  elseif msg == "restore" then
    RestoreKeys()
  elseif msg == "overlay" or msg == "keys" then
    SetOverlayShown(not IsOverlayShown())
  elseif msg == "notes" or msg == "card" or msg == "hunting notes" then
    _G.Nock_ToggleNotes()
  elseif msg == "fade" then
    Nock.SetFade(not NockCharDB.fade)
    Print("Key bar fade out of combat " .. (NockCharDB.fade and "on (40%)." or "off."))
  elseif msg == "resetbar" then
    if InCombat() then
      Print("Leave combat first.")
    else
      Nock.ResetBarPosition()
      Print("Key bar is back above your action bars.")
    end
  elseif msg == "lockbar" then
    NockCharDB.barLocked = not NockCharDB.barLocked
    Print("Key bar " .. (NockCharDB.barLocked and "locked." or "unlocked: drag it out of combat."))
  elseif msg:match("^size") then
    local arg = strtrim(msg:sub(5) or "")
    if arg == "small" or arg == "normal" or arg == "large" then
      Nock.SetBarSize(arg)
      Print("Bar size: " .. arg .. ".")
    elseif arg == "" then
      local cur = Nock.BarSize and Nock.BarSize() or "large"
      local nxt = (cur == "small" and "normal") or (cur == "normal" and "large") or "small"
      Nock.SetBarSize(nxt)
      Print("Bar size: " .. nxt .. ".")
    else
      Print("Bar size is Small, Normal or Large. Try /nock size large")
    end
  elseif msg == "xp" then
    local on = not (NockCharDB.nockXP == false)
    Nock.SetNockXP(not on)
    Print("Nock XP bar " .. ((NockCharDB.nockXP ~= false) and "on." or "off."))
  elseif msg:match("^button") then
    local arg = strtrim(msg:sub(7) or "")
    if arg == "reset" then
      if Nock.Launcher and Nock.Launcher.Reset then
        Nock.Launcher.Reset()
      else
        Print("The Nock button is not ready yet.")
      end
    elseif arg == "hide" or arg == "off" then
      NockCharDB.showLauncher = false
      if Nock.Launcher and Nock.Launcher.Update then
        Nock.Launcher.Update()
      end
      Print("Nock button hidden. Turn it back on in Options, or /nock button reset.")
    elseif arg == "show" or arg == "on" then
      NockCharDB.showLauncher = true
      if Nock.Launcher and Nock.Launcher.Update then
        Nock.Launcher.Update()
      end
      Print("Nock button shown.")
    else
      Print("Usage: /nock button reset  — put the movable Nock button back in the default spot")
    end
  elseif msg:match("^style") then
    local arg = strtrim(msg:sub(6) or "")
    local Theme = _G.NockTheme
    if arg == "" then
      local cur = (Theme and Theme.StyleName and Theme.StyleName()) or "Emerald"
      Print("Style: " .. cur .. ". Try /nock style gun  or  /nock style emerald")
    elseif Theme and Theme.SetStyle then
      local id, why = Theme.SetStyle(arg)
      local name = (Theme.StyleName and Theme.StyleName()) or id
      if why == "combat" then
        Print("Style will switch to " .. name .. " when the fight ends.")
      else
        Print("Style: " .. name .. ".")
      end
    else
      Print("Styles aren't loaded.")
    end
  elseif msg == "threat unlock" or msg:match("^threat%s+unlock") then
    if Nock.Threat and Nock.Threat.SetLocked then
      local ok, why = Nock.Threat.SetLocked(false)
      if why == "combat" then
        Print("Leave combat first — the threat meter will unlock when the fight ends.")
      else
        Print("Threat meter unlocked: drag it anywhere. It snaps to the middle of the bar. /nock threat lock when you're done.")
      end
    else
      Print("Threat meter isn't loaded.")
    end
  elseif msg == "threat lock" or msg:match("^threat%s+lock") then
    if Nock.Threat and Nock.Threat.SetLocked then
      Nock.Threat.SetLocked(true)
      Print("Threat meter locked.")
    else
      Print("Threat meter isn't loaded.")
    end
  elseif msg == "threat reset" or msg:match("^threat%s+reset") then
    if InCombat() then
      Print("Leave combat first.")
    elseif Nock.Threat and Nock.Threat.ResetPos then
      Nock.Threat.ResetPos()
      Print("Threat meter is back above the bow.")
    else
      Print("Threat meter isn't loaded.")
    end
  elseif msg == "threat debug" or msg:match("^threat%s+debug") then
    if Nock.Threat and Nock.Threat.Debug then
      Nock.Threat.Debug()
    else
      Print("Threat meter isn't loaded.")
    end
  elseif msg == "threat" then
    local on = not (NockCharDB.nockThreat == false)
    if Nock.SetNockThreat then
      Nock.SetNockThreat(not on)
    else
      NockCharDB.nockThreat = not on
    end
    Print("Threat meter " .. ((NockCharDB.nockThreat ~= false) and "on." or "off."))
  elseif msg == "save" then
    local _, when = Nock.SaveUI()
    if when and when ~= "" then
      Print("UI saved for this character at " .. when .. ". Style, threat position, bar size and the other Nock settings will still be here after a /reload or relog.")
    else
      Print("UI saved for this character. Style, threat position, bar size and the other Nock settings will still be here after a /reload or relog.")
    end
  elseif msg:match("^profile") then
    local rest = strtrim(msg:sub(8) or "")
    local verb, name = rest:match("^(%S+)%s*(.*)$")
    verb = verb or ""
    name = strtrim(name or "")
    if verb == "save" then
      local ok, why = Nock.ProfileSave(name)
      if not ok then
        Print("Usage: /nock profile save <name>")
      else
        Print("Saved UI profile \"" .. why .. "\" (account-wide). /nock profile load " .. why .. " to use it on this character.")
      end
    elseif verb == "load" then
      if name == "" then
        Print("Usage: /nock profile load <name>")
      else
        local ok, why = Nock.ProfileLoad(name)
        if why == "combat" then
          Print("Leave combat first.")
        elseif not ok then
          Print("No UI profile named \"" .. name .. "\". /nock profile list to see them.")
        else
          Print("Loaded UI profile \"" .. name .. "\".")
        end
      end
    elseif verb == "list" or rest == "" then
      local names = Nock.ProfileList and Nock.ProfileList() or {}
      if #names == 0 then
        Print("No UI profiles yet. /nock profile save <name> to make one.")
      else
        Print("UI profiles: " .. table.concat(names, ", "))
      end
    else
      Print("Usage: /nock profile save <name>  |  /nock profile load <name>  |  /nock profile list")
    end
  elseif msg == "options" then
    Nock.ShowPanel("options")
  elseif msg == "guide" or msg == "manual" then
    if Nock.OpenGuide then
      Nock.OpenGuide(NockCharDB.spec)
    end
  elseif msg == "talents" or msg == "plan" then
    Nock.ShowPanel("talents", NockCharDB.spec)
  elseif msg == "rotation" then
    Nock.ShowPanel("rotation", NockCharDB.spec)
  elseif msg == "macros" then
    Nock.ShowPanel("macros", NockCharDB.spec)
  elseif msg == "next" then
    if Nock.PrintNextTalent then
      Nock.PrintNextTalent(NockCharDB.spec)
    end
  elseif msg == "help" then
    Print("/nock — open the Nock window (also: Escape menu, the Nock button, or the Open Nock keybind)")
    Print("/nock button reset — put the movable Nock button back in the default spot")
    Print("/nock setup — optional: put Nock's full key layout on empty and Nock keys")
    Print("/nock simple  or  /nock advanced — fewer tabs, or all tabs")
    Print("/nock keepup — auto keep-up on or off   /nock remind — talent point button on or off")
    Print("/nock marks  or  /nock bm — apply that layout")
    Print("/nock restore — put your old keys back")
    Print("/nock overlay — show or hide the key bar   /nock fade — fade out of combat on or off")
    Print("/nock crosshair — crosshair on the top shot   /nock resetbar — put the key bar back above your bars")
    Print("/nock notes — show or hide Hunting Notes (also: hold Alt over the key bar)")
    Print("/nock size small | normal | large — how big the bar is (default Large)")
    Print("/nock xp — show or hide Nock's experience bar")
    Print("/nock style gun | emerald — swap the HUD look (default Emerald)")
    Print("/nock save — remember this character's UI (also happens on /reload and relog)")
    Print("/nock profile save <name>  |  load <name>  |  list — account-wide UI setups")
    Print("/nock threat — show or hide the pet and player threat meter")
    Print("/nock threat unlock | lock — drag the meter, or lock it in place")
    Print("/nock threat reset — put the meter back above the bow")
    Print("/nock threat debug — print raw threat API values (use in a fight)")
    Print("/nock myrotation — open My Rotation (what to press at your level, with your keys)")
        Print("/nock glow — priority glow on or off (also: steady, pulse, low, medium, high)")
    Print("/nock numbers — opener numbers on your buttons on or off")
    Print("/nock talents | rotation | macros | guide — open that tab")
    Print("/nock badges — key badges on your action buttons on or off")
    Print("/nock resetui — move the window back to the middle of the screen")
    Print("/nock next — what talent to take at your level")
    Print("/nock keys — the 2.1 keys;  /nock mouse on/off — mouse buttons;  /nock migrate — move to 2.1")
  else
    Nock:Open()
  end
end
