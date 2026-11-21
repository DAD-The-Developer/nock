--[[
  Nock 3.4.0 hunter tool: trainer reminder.

  On level up (and on /nock train) Nock compares the Forever hunter trainer
  list (Data_Spells.lua, 136 ranks) with your spellbook and tells you what
  is waiting, e.g. "At the trainer: Serpent Sting 3, Aspect of the Hawk 2",
  plus new pet trainer ranks (Growl, Great Stamina, Natural Armor ...) for
  your pet's level, and points to the nearest hunter trainer from the map
  pin list. Talent spells (Counterattack, Trueshot Aura ...) are only listed
  once you have taken the talent.

  Rank-aware when the spellbook shows ranks; if the client hides ranks,
  Nock only lists spells you do not have at all plus ranks new this level,
  so it never nags about something you already bought.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "train",
  name = "Trainer reminder",
  desc = "On level up: new hunter and pet ranks you can buy, and the nearest trainer.",
  cmd = { "train", "trainer" },
  pvpQuiet = true,
  defaults = { on = true, alert = true, pet = true },
  options = {
    { key = "alert", label = "Big alert on level up when new ranks are waiting" },
    { key = "pet", label = "Include pet trainer ranks" },
  },
  help = { "/nock train — what is waiting at your hunter trainer, and where the nearest one is" },
})

--[[ Missing ranks (pure, tested).
  rows: Data.TrainerSpells; level: player level; rank(name) -> known rank;
  rankInfo: spellbook shows ranks; newOnly: list only rows for exactly `level`.
  Returns { { level, name, rank }, ... } sorted by level. ]]
function M.Missing(rows, level, rank, rankInfo, newOnly)
  local out = {}
  local best = {}
  for _, row in ipairs(rows or {}) do
    local lvl, name, r, talent = row[1], row[2], row[3], row[4]
    if lvl <= level and not (newOnly and lvl ~= level) then
      local have = rank(name)
      local isNew = lvl == level
      local wanted
      if talent then
        -- Talent ranks: only once you have the talent (rank 1 known).
        wanted = have >= 1 and (r or 1) > have and (rankInfo or isNew)
      elseif (r or 0) <= 1 then
        wanted = have == 0
      else
        wanted = have < r and (rankInfo or isNew or have == 0)
      end
      if wanted then
        -- Keep only the highest missing rank per spell.
        local cur = best[name]
        if not cur or (r or 0) > (cur[3] or 0) then
          best[name] = { lvl, name, r or 0 }
        end
      end
    end
  end
  for _, v in pairs(best) do
    out[#out + 1] = v
  end
  table.sort(out, function(a, b)
    if a[1] ~= b[1] then
      return a[1] < b[1]
    end
    return a[2] < b[2]
  end)
  return out
end

-- Pet trainer ranks that open at exactly this pet level (pure).
function M.PetNew(level)
  local out = {}
  for name, ranks in pairs((Nock.Data or {}).PetAbilityRanks or {}) do
    for _, row in ipairs(ranks) do
      if row[3] == "Pet trainer" and row[2] == level then
        out[#out + 1] = string.format("%s %d", name, row[1])
      end
    end
  end
  table.sort(out)
  return out
end

local function Label(row)
  return row[3] and row[3] > 0 and string.format("%s %d", row[2], row[3]) or row[2]
end

local function Lists(newOnly)
  local rows = (Nock.Data or {}).TrainerSpells or {}
  return M.Missing(rows, Core.P.level, Core.Rank, Core.P.rankInfo, newOnly)
end

local function TrainerLine()
  local e, yd = Core.NearestPin(1)
  if e then
    return "Nearest hunter trainer: " .. Core.PinText(e, yd)
  end
  return nil
end

local lastLevel
function M:OnProfile(what)
  if what == "all" then
    lastLevel = Core.P.level
    return
  end
  if what ~= "level" or Core.P.level == lastLevel then
    return
  end
  lastLevel = Core.P.level
  -- Ranks show in the book only after the scan; give it a moment.
  local function tell()
    local miss = Lists(false)
    local petNew = Core.Get("train", "pet") ~= false and M.PetNew(Core.P.level) or {}
    if #miss == 0 and #petNew == 0 then
      return
    end
    local names = {}
    for i = 1, math.min(4, #miss) do
      names[#names + 1] = Label(miss[i])
    end
    local text = "At the trainer: " .. table.concat(names, ", ") .. (#miss > 4 and string.format(" (+%d more)", #miss - 4) or "")
    if #miss == 0 then
      text = "Pet trainer: " .. table.concat(petNew, ", ")
    end
    if Core.Get("train", "alert") ~= false then
      Core.Alert(text, { color = "good", key = "train", priority = 1, sub = TrainerLine(), sound = "soft", duration = 6 })
    end
    Core.Say(text)
    if #petNew > 0 and #miss > 0 then
      Core.Say("Pet trainer: " .. table.concat(petNew, ", "))
    end
    local t = TrainerLine()
    if t then
      Core.Say(t)
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(2, function()
      if Core.Enabled("train") then
        pcall(tell)
      end
    end)
  else
    tell()
  end
end

function M:Slash()
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local miss = Lists(false)
  local out = {}
  if #miss == 0 then
    out[#out + 1] = "Nothing waiting at the hunter trainer."
  else
    local names = {}
    for _, row in ipairs(miss) do
      names[#names + 1] = Label(row)
    end
    out[#out + 1] = "At the trainer: " .. table.concat(names, ", ")
  end
  if not Core.P.rankInfo then
    out[#out + 1] = "(Your spellbook shows no ranks, so only missing spells and this level's new ranks are listed.)"
  end
  -- What comes next.
  local rows = (Nock.Data or {}).TrainerSpells or {}
  local nextLvl
  for _, row in ipairs(rows) do
    if row[1] > Core.P.level and not row[4] then
      nextLvl = row[1]
      break
    end
  end
  if nextLvl then
    local names = {}
    for _, row in ipairs(rows) do
      if row[1] == nextLvl and not row[4] then
        names[#names + 1] = Label({ row[1], row[2], row[3] })
      end
    end
    out[#out + 1] = string.format("At level %d: %s", nextLvl, table.concat(names, ", "))
  end
  local t = TrainerLine()
  if t then
    out[#out + 1] = t
  end
  return out
end

function _G.Nock_TrainCheck()
  local lines = M:Report()
  Core.Alert(lines[1] or "Trainer", { color = "good", key = "train", priority = 1, sub = lines[#lines], duration = 5 })
  for _, line in ipairs(lines) do
    Core.Say(line)
  end
end
