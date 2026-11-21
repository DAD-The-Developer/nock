--[[
  Nock 3.4.0 hunter tool: hunter route and field notes.

  Leveling (1-59): where to level now and next for your faction (Forever
  zones incl. Zephras Isle, Riverglades, Mount Hyjal), dungeons in range,
  and the hunter milestones around your level (training, the level 10 pet
  quest, Wing Clip and kiting, Feign Death, Tranquilizing Shot). On level up
  a one-line "next step" goes to chat.

  Endgame (60, or /nock tools endgame on): the readout switches to the
  checklist for where you are (raid, dungeon, battleground, solo), what is
  open in Forever right now, and the Rhok'delar note.

  Scales by data: route bands, milestones (optionally per spec), checklists
  and content phases are rows in Data_Route.lua.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "route",
  name = "Hunter route and field notes",
  desc = "Where to level next, hunter milestones, and the endgame checklist at 60.",
  cmd = { "route", "leveling" },
  defaults = { on = true, levelup = true },
  options = {
    { key = "levelup", label = "Print the next step in chat when I level up" },
  },
  help = { "/nock route — where to level now, next, and hunter milestones (endgame checklist at 60)   /nock route pvp" },
})

local function D()
  return Nock.Data or {}
end

-- Route band for a level and faction (pure, tested). Returns row, nextRow.
function M.Band(faction, level)
  local list = (D().Route or {})[faction] or {}
  for i, row in ipairs(list) do
    if level >= row[1] and level < row[2] then
      return row, list[i + 1]
    end
  end
  local last = list[#list]
  if last and level >= last[1] then
    return last, nil
  end
  return list[1], list[2]
end

-- Milestones from (level - back) to (level + ahead), filtered by spec (pure).
function M.Milestones(level, spec, back, ahead)
  local out = {}
  for _, row in ipairs(D().Milestones or {}) do
    local okSpec = (row[3] == nil) or row[3] == spec or (spec == "hybrid")
    if okSpec and row[1] >= level - (back or 0) and row[1] <= level + (ahead or 4) then
      out[#out + 1] = row
    end
  end
  return out
end

function M.ChecklistKey(context)
  if context == "raidinstance" or context == "raid" then
    return "raid"
  elseif context == "dungeon" or context == "party" then
    return "dungeon"
  elseif context == "pvp" then
    return "pvp"
  end
  return "raid" -- at 60 solo, the next thing to prepare for is raid night
end

function M:Report()
  local P = Core.P
  local out = {}
  local pvp = Core.Module("pvp")
  if Core.PvPMode() and pvp and pvp.GuideLines then
    out[#out + 1] = "PvP field notes (battleground / arena):"
    for _, line in ipairs(pvp.GuideLines()) do
      out[#out + 1] = "  " .. line
    end
    return out
  end
  if Core.IsEndgame() then
    local key = M.ChecklistKey(P.context)
    out[#out + 1] = string.format("Endgame (%s). Checklist for %s:", P.spec, key == "raid" and "raid night" or key)
    for _, line in ipairs((D().Checklists or {})[key] or {}) do
      out[#out + 1] = "  [ ] " .. line
    end
    out[#out + 1] = "What is open in Forever:"
    for _, ph in ipairs(D().Phases or {}) do
      out[#out + 1] = string.format("  %s — %s", ph[1], ph[2])
    end
    for _, row in ipairs(M.Milestones(60, P.spec, 0, 0)) do
      out[#out + 1] = "  " .. row[2]
    end
    return out
  end
  local now, nxt = M.Band(P.faction, P.level)
  if now then
    out[#out + 1] = string.format("Level %d %s: %s", P.level, P.faction, now[3])
    if now[4] and now[4] ~= "" then
      out[#out + 1] = "  Flight points: " .. now[4]
    end
    if now[5] and now[5] ~= "" then
      out[#out + 1] = "  Dungeons: " .. now[5]
    end
  end
  if nxt then
    out[#out + 1] = string.format("Next (%d-%d): %s", nxt[1], nxt[2], nxt[3])
  end
  local ms = M.Milestones(P.level, P.spec, 1, 4)
  if #ms > 0 then
    out[#out + 1] = "Hunter notes:"
    for _, row in ipairs(ms) do
      out[#out + 1] = string.format("  %d: %s", row[1], row[2])
    end
  end
  if P.level % 2 == 0 and P.level >= 2 then
    out[#out + 1] = "Even level: new hunter ranks at your trainer (/nock train)."
  end
  return out
end

function M:OnProfile(what)
  if what ~= "level" or Core.Get("route", "levelup") == false or Core.PvPMode() then
    return
  end
  local P = Core.P
  if Core.IsEndgame() then
    Core.Say("Level 60: endgame mode. /nock route for the raid-night checklist, /nock kit for the Field Kit.")
    return
  end
  local now = M.Band(P.faction, P.level)
  local ms = M.Milestones(P.level, P.spec, 0, 0)
  if now then
    Core.Say(string.format("Level %d: %s", P.level, now[3]))
  end
  for _, row in ipairs(ms) do
    Core.Say("  " .. row[2])
  end
end

function M:Slash(rest)
  local pvp = Core.Module("pvp")
  if rest == "pvp" and pvp then
    for _, line in ipairs(pvp.GuideLines()) do
      Core.Say(line)
    end
    return
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end
