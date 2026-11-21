--[[
  Nock 3.4.0 hunter tool: taming helper.

  * Rare and notable tameable beasts (Data_Pets.lua TameRares) as paw pins
    on the world map and minimap, filtered to your level band (or all).
    Hover a pin for family, level, abilities and attack speed.
  * Your pet's abilities against its family's list: what it knows, the next
    rank it is old enough for, and which beasts teach it (tame one, use the
    ability until you learn it, then teach your pet at Beast Training).
  * The Field Kit page lists every rare by level, plus your pet report.

  Scales by data: add rows to TameRares / PetAbilityRanks (Data_Pets.lua) as
  Forever adds beasts; the level band follows your level, and at 60 it shows
  the 55-60 rares and top-rank teachers. Beast Mastery builds see pins on by
  default for every band; others see their own band.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "tame",
  name = "Taming helper",
  desc = "Rare beasts on your maps, and the abilities your pet is missing with who teaches them.",
  cmd = { "tame", "taming", "rares" },
  defaults = { on = true, pins = true, all = false, nearby = true },
  options = {
    { key = "nearby", label = "Tell me when a rare near my level is within 150 yards" },
    { key = "pins", label = "Show rare tameable beasts on the maps (paw pins)" },
    { key = "all", label = "Show every rare, not just ones near my level" },
  },
  help = { "/nock tame — your pet's missing abilities and rares near your level   /nock tame all | pins" },
})

local TEX = "Interface\\AddOns\\Nock\\Media\\Textures\\pins\\"
local BAND_DOWN, BAND_UP = 8, 3

local function FirstLevel(s)
  return tonumber(tostring(s or ""):match("(%d+)")) or 0
end
M.FirstLevel = FirstLevel

-- Is a rare worth showing at this player level? (pure, tested)
function M.InBand(rareLevel, playerLevel, all)
  if all then
    return true
  end
  local lvl = FirstLevel(rareLevel)
  return lvl >= playerLevel - BAND_DOWN and lvl <= playerLevel + BAND_UP
end

local function Family(name)
  local D = Nock.Data or {}
  return D.PetFamilies and D.PetFamilies[name]
end

local function AbilityText(fam)
  local f = Family(fam)
  if not f then
    return nil
  end
  local parts = {}
  for _, a in ipairs(f.abilities or {}) do
    parts[#parts + 1] = a[1]
  end
  return table.concat(parts, ", ")
end

local kind
local function AddPins()
  if kind or not (Nock.Pins and Nock.Pins.AddKind) then
    return
  end
  kind = Nock.Pins.AddKind({
    id = "tame", label = "Rare tameable beasts", role = "Rare tameable beast", tex = TEX .. "pin_tame",
    color = { 0.95, 0.62, 0.25 },
    filter = function(e)
      if not (Core.Enabled("tame") and Core.Get("tame", "pins") ~= false) then
        return false
      end
      local all = Core.Get("tame", "all") == true
      return M.InBand(e.data[3], Core.P.level, all)
    end,
    tip = function(e)
      local r = e.data
      local lines = {}
      lines[#lines + 1] = string.format("%s, level %s%s", r[2], r[3], r[5] and " (elite)" or "")
      local ab = AbilityText(r[2])
      if ab then
        lines[#lines + 1] = "Abilities: " .. ab
      end
      if r[6] then
        lines[#lines + 1] = string.format("Attack speed %.1f", r[6])
      end
      return lines
    end,
  })
  local rows = {}
  for _, r in ipairs((Nock.Data or {}).TameRares or {}) do
    for _, c in ipairs(r[7] or {}) do
      rows[#rows + 1] = { kind = kind, fac = "AH", map = c[1], x = c[2] / 100, y = c[3] / 100, name = r[1], title = r[2], data = r }
    end
  end
  Nock.Pins.AddEntries(rows)
end

-- Pet spellbook ---------------------------------------------------------------------

function M.PetKnown()
  local known = {}
  local SB = C_SpellBook
  if SB and SB.HasPetSpells and SB.GetSpellBookItemInfo then
    local ok, num = pcall(SB.HasPetSpells)
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1
    num = ok and Core.Number(num) or 0
    for i = 1, num do
      local okI, it = pcall(SB.GetSpellBookItemInfo, i, bank)
      if okI and type(it) == "table" and type(it.name) == "string" then
        local r = Core.RankOf(it.subName) or 1
        known[it.name] = math.max(known[it.name] or 0, r)
      end
    end
  elseif HasPetSpells and GetSpellBookItemName then
    local num = Core.Number(Core.Call(HasPetSpells)) or 0
    for i = 1, num do
      local name, sub = Core.Call(GetSpellBookItemName, i, _G.BOOKTYPE_PET or "pet")
      if type(name) == "string" then
        known[name] = math.max(known[name] or 0, Core.RankOf(sub) or 1)
      end
    end
  end
  return known
end

--[[ What the pet could learn next (pure, tested).
  family: name; known: { ability = rank }; petLevel: number.
  Returns rows { name, have, nextRank, needLevel, ready, teachers = {...} }. ]]
function M.Missing(family, known, petLevel)
  local out = {}
  local f = Family(family)
  local ranks = (Nock.Data or {}).PetAbilityRanks or {}
  for _, a in ipairs(f and f.abilities or {}) do
    local name, maxRank = a[1], a[2]
    local have = known[name] or 0
    if have < maxRank then
      local list = ranks[name] or {}
      local row = list[have + 1]
      if row then
        out[#out + 1] = {
          name = name, have = have, nextRank = row[1], needLevel = row[2], how = row[3],
          ready = (petLevel or 1) >= row[2], teachers = row[4] or {},
        }
      end
    end
  end
  return out
end

function M.NearRares(level, all)
  local out = {}
  for _, r in ipairs((Nock.Data or {}).TameRares or {}) do
    if M.InBand(r[3], level, all) then
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b)
    return FirstLevel(a[3]) < FirstLevel(b[3])
  end)
  return out
end

local function RareLine(r)
  return string.format("%s — %s %s%s, %s", r[1], r[2], r[3], r[5] and " elite" or "", r[4])
end
M.RareLine = RareLine

-- 3.5.0: a quiet heads-up when a rare you could tame is close by.
local NEAR_RARE_YARDS = 150
Core.Every("tame", 10, function()
  if not kind or Core.Get("tame", "nearby") == false or Core.InCombat() or Core.P.instance ~= "none" then
    return
  end
  local P = Nock.Pins
  if not (P and P.Nearest) then
    return
  end
  local level = Core.P.level
  local e, yd = P.Nearest(kind, function(x) return M.InBand(x.data[3], level, false) end)
  if e and yd and yd < NEAR_RARE_YARDS then
    Nock.Alerts:Fire("tame.nearby", { name = e.name, family = e.title, level = e.data[3], yards = math.floor(yd / 5 + 0.5) * 5 },
      { key = "tame:" .. tostring(e.name), icon = "spell:Tame Beast" })
  end
end)

function M:Init()
  AddPins()
  if Nock.Pins and Nock.Pins.Refresh then
    pcall(Nock.Pins.Refresh)
  end
end

function M:Refresh()
  if Nock.Pins and Nock.Pins.Refresh then
    pcall(Nock.Pins.Refresh)
  end
end

function M:OnProfile(what)
  if what == "level" or what == "all" then
    M:Refresh()
  end
end

function M:Slash(rest)
  if rest == "all" then
    Core.Set("tame", "all", not (Core.Get("tame", "all") == true))
    return Core.Say("Rare beasts: " .. (Core.Get("tame", "all") and "all levels" or "near your level"))
  elseif rest == "pins" then
    Core.Set("tame", "pins", Core.Get("tame", "pins") == false)
    return Core.Say("Rare beast pins: " .. (Core.Get("tame", "pins") ~= false and "on" or "off"))
  elseif rest == "list" then
    for _, r in ipairs(M.NearRares(Core.P.level, true)) do
      Core.Say(RareLine(r))
    end
    return
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local out = {}
  local fam = Core.UnitFlag(UnitExists, "pet") == true and Core.Call(UnitCreatureFamily, "pet") or nil
  if type(fam) == "string" and not Core.IsSecret(fam) then
    local petLevel = Core.Number(UnitLevel and UnitLevel("pet")) or Core.P.level
    local miss = M.Missing(fam, M.PetKnown(), petLevel)
    if #miss == 0 then
      out[#out + 1] = string.format("Your %s knows every family ability rank it can.", fam)
    else
      out[#out + 1] = string.format("Your %s (level %d) can still learn:", fam, petLevel)
      for _, m in ipairs(miss) do
        local who = {}
        for i = 1, math.min(3, #m.teachers) do
          local t = m.teachers[i]
          who[#who + 1] = string.format("%s (%s, %s)", t[1], t[2], t[3])
        end
        out[#out + 1] = string.format("  %s rank %d%s: %s", m.name, m.nextRank,
          m.ready and "" or string.format(" at pet level %d", m.needLevel),
          #who > 0 and ("tame " .. table.concat(who, ", ")) or (m.how or "see Beast Training"))
      end
    end
  else
    out[#out + 1] = "No pet out. Call your pet to see what it can still learn."
  end
  local near = M.NearRares(Core.P.level, false)
  out[#out + 1] = string.format("Rare beasts near level %d: %d (paw pins on your maps)", Core.P.level, #near)
  for i = 1, math.min(6, #near) do
    out[#out + 1] = "  " .. RareLine(near[i])
  end
  return out
end

function _G.Nock_ToggleTamePins()
  M:Slash("pins")
end
