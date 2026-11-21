--[[
  Nock 3.4.0 hunter tool: aspect reminder.

  * Fighting without your damage aspect: Aspect of the Hawk once you know it,
    Aspect of the Monkey before that (picked from your spellbook).
  * Fighting in Cheetah or Pack: you get dazed every hit. Loud warning.
  * Travelling outdoors on foot for a while without Cheetah (or Pack in a
    group): a quiet nudge. Never in cities or rested areas, never mounted,
    never indoors, never in dungeons or raids.

  Your current aspect is tracked from your own casts and, out of combat,
  from your buffs, so it still works when Forever hides auras in combat.
  Endgame mode (60) keeps the combat checks and drops the travel nudge
  unless you turn it back on.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "aspects",
  name = "Aspect reminder",
  desc = "Hawk (or Monkey) in combat, Cheetah or Pack when travelling; warns if Cheetah/Pack is on in a fight.",
  cmd = { "aspects", "aspect" },
  defaults = { on = true, combat = true, daze = true, travel = true, travelAtMax = false, travelDelay = 10 },
  options = {
    { key = "combat", label = "Warn when I fight without Hawk (or Monkey)" },
    { key = "daze", label = "Warn when I fight in Cheetah or Pack" },
    { key = "travel", label = "Nudge me to use Cheetah when travelling on foot" },
    { key = "travelAtMax", label = "Keep the travel nudge at level 60" },
  },
  help = { "/nock aspects — combat and travel aspect reminders on or off   /nock aspects travel" },
})

local ASPECTS = {
  "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack",
  "Aspect of the Wild", "Aspect of the Beast", "Aspect of the Viper",
}
local current -- name of the aspect we believe is on (nil = none / unknown)
local fromCast = false

-- The aspect to fight in, from what you know (pure, tested).
function M.CombatAspect(knows)
  if knows("Aspect of the Hawk") then
    return "Aspect of the Hawk"
  elseif knows("Aspect of the Monkey") then
    return "Aspect of the Monkey"
  end
  return nil
end

-- Is this aspect fine for a fight? (pure, tested)
function M.CombatOK(aspect, want)
  if not want then
    return true
  end
  if aspect == nil then
    return false
  end
  if aspect == "Aspect of the Cheetah" or aspect == "Aspect of the Pack" then
    return false
  end
  -- Viper / Wild / Beast / Monkey are deliberate choices; only "none" and
  -- travel aspects count as wrong.
  return true
end

local function ScanBuffs()
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
    if ok and Core.Flag(v) ~= false then
      return false
    end
  end
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then
    return false
  end
  local found
  for _, name in ipairs(ASPECTS) do
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
    if not ok then
      return false
    end
    if type(data) == "table" then
      found = name
      break
    end
  end
  current = found
  fromCast = false
  return true
end

local localName = {}
local function NameOf(spellID)
  local n = C_Spell and C_Spell.GetSpellName and Core.Call(C_Spell.GetSpellName, spellID)
  if not n and GetSpellInfo then
    n = Core.Call(GetSpellInfo, spellID)
  end
  return n
end

Core.On("UNIT_SPELLCAST_SUCCEEDED", "aspects", function(_, unit, _, spellID)
  if unit ~= "player" or not spellID or Core.IsSecret(spellID) then
    return
  end
  local n = NameOf(spellID)
  if type(n) ~= "string" then
    return
  end
  for _, a in ipairs(ASPECTS) do
    if n == a or n == localName[a] then
      current = a
      fromCast = true
      Core.HideAlert("aspect")
      return
    end
  end
end)

Core.On("PLAYER_DEAD", "aspects", function()
  current = nil
end)

local function Want()
  return M.CombatAspect(function(n)
    return Core.Knows(n)
  end)
end

local function CheckCombat()
  local want = Want()
  if not want then
    return
  end
  if (current == "Aspect of the Cheetah" or current == "Aspect of the Pack") and Core.Get("aspects", "daze") ~= false then
    Core.Alert(current:gsub("Aspect of the ", "") .. " is ON in combat", { color = "bad", key = "aspect", priority = 3,
      sub = "You get dazed when hit. Switch to " .. want:gsub("Aspect of the ", "") .. ".", sound = true, duration = 5 })
  elseif current == nil and Core.Get("aspects", "combat") ~= false then
    Core.Alert("No aspect", { color = "warn", key = "aspect", priority = 2,
      sub = "Turn on " .. want .. " for damage.", sound = "soft", duration = 4 })
  end
end

Core.On("PLAYER_REGEN_DISABLED", "aspects", function()
  if C_Timer and C_Timer.After then
    C_Timer.After(0.5, function()
      if Core.Enabled("aspects") then
        pcall(CheckCombat)
      end
    end)
  else
    CheckCombat()
  end
end)

local moving = 0
local function TravelOK()
  if Core.Get("aspects", "travel") == false then
    return false
  end
  if Core.IsEndgame() and Core.Get("aspects", "travelAtMax") ~= true then
    return false
  end
  if Core.P.instance ~= "none" or Core.P.resting or Core.InCombat() then
    return false
  end
  if Core.UnitFlag(IsMounted) == true or Core.UnitFlag(IsIndoors) == true or Core.UnitFlag(UnitOnTaxi, "player") == true then
    return false
  end
  if Core.UnitFlag(IsSwimming) == true or Core.UnitFlag(UnitIsDeadOrGhost, "player") == true then
    return false
  end
  return Core.Knows("Aspect of the Cheetah")
end

-- Every second: out of combat, refresh from buffs; count travel time.
Core.Every("aspects", 1, function()
  if not Core.InCombat() then
    ScanBuffs()
  elseif Core.PvPMode() and (current == "Aspect of the Cheetah" or current == "Aspect of the Pack") and Core.Throttle("aspects:pvpdaze", 5) then
    CheckCombat()
  end
  if not TravelOK() then
    moving = 0
    return
  end
  local speed = GetUnitSpeed and Core.Number(Core.Call(GetUnitSpeed, "player")) or 0
  if speed and speed > 0 then
    moving = moving + 1
  else
    moving = 0
  end
  local delay = tonumber(Core.Get("aspects", "travelDelay")) or 10
  if moving >= delay and current ~= "Aspect of the Cheetah" and current ~= "Aspect of the Pack" then
    if Core.Throttle("aspects:travel", 120) then
      local pick = (Core.P.context == "party" and Core.Knows("Aspect of the Pack")) and "Aspect of the Pack" or "Aspect of the Cheetah"
      Core.Alert("Travelling? " .. pick, { color = "info", key = "aspect", priority = 1,
        sub = "Switch back to Hawk before you pull.", duration = 3 })
    end
  end
end)

function M:Init()
  for _, a in ipairs(ASPECTS) do
    local _, _, name = Core.Call(Nock.PlayerKnows, a)
    if type(name) == "string" then
      localName[a] = name
    end
  end
  ScanBuffs()
end

function M:Slash(rest)
  if rest == "travel" then
    Core.Set("aspects", "travel", Core.Get("aspects", "travel") == false)
    return Core.Say("Travel nudge: " .. (Core.Get("aspects", "travel") ~= false and "on" or "off"))
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local want = Want()
  return {
    string.format("Current aspect: %s. Fight in: %s.", current or "none", want or "nothing yet (Monkey at 4, Hawk at 10)"),
    Core.Knows("Aspect of the Cheetah") and "Travel: Cheetah (Pack in a group). Never in combat — it dazes you." or "Aspect of the Cheetah comes at level 20.",
  }
end

M.Current = function()
  return current
end
