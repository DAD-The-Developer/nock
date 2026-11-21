--[[
  Nock 3.4.0 hunter tool: Feign Death resisted alert.

  When your Feign Death goes off but you are not actually feigning a moment
  later (resisted, or broken at once), Nock shows a big red RESISTED alert,
  plays a warning sound and flashes the screen edge, so you can react
  (Freezing Trap, run, or feign again when it is back).

  How: Forever gives addons no combat log, so Nock watches your own Feign
  Death cast and then asks UnitIsFeignDeath("player"). If the client hides
  that answer, Nock stays silent rather than guess.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "feign",
  name = "Feign Death resisted alert",
  desc = "Big alert and sound when Feign Death is resisted.",
  cmd = { "feign", "fd" },
  defaults = { on = true, flash = true },
  options = {
    { key = "flash", label = "Soft red edge flash on a resist" },
  },
  help = { "/nock feign — Feign Death resisted alert on or off   /nock feign test" },
})

local DELAY = 0.3
local fdName = "Feign Death"

-- Decide from the follow-up check (pure, tested): true = resisted,
-- false = worked, nil = cannot tell.
function M.Resisted(isFeigning, isDead)
  if isDead == true then
    return false
  end
  if isFeigning == true then
    return false
  end
  if isFeigning == false then
    return true
  end
  return nil
end

function M.Fire()
  Nock.Alerts:Fire("feign.resisted", nil, { force = true })
  if Core.Get("feign", "flash") ~= false then
    Core.Flash(0.9, 0.15, 0.12, 0.6)
  end
end

local function Check()
  local feigning = Core.UnitFlag(UnitIsFeignDeath, "player")
  local dead = Core.UnitFlag(UnitIsDead, "player")
  local r = M.Resisted(feigning, dead)
  M.last = r
  if r == true then
    M.Fire()
  end
end

Core.On("UNIT_SPELLCAST_SUCCEEDED", "feign", function(_, unit, _, spellID)
  if unit ~= "player" or not spellID or Core.IsSecret(spellID) then
    return
  end
  local n = C_Spell and C_Spell.GetSpellName and Core.Call(C_Spell.GetSpellName, spellID)
  if not n and GetSpellInfo then
    n = Core.Call(GetSpellInfo, spellID)
  end
  if n ~= fdName then
    return
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(DELAY, function()
      if Core.Enabled("feign") then
        pcall(Check)
      end
    end)
  else
    Check()
  end
end)

function M:Init()
  local _, _, name = Core.Call(Nock.PlayerKnows, "Feign Death")
  if type(name) == "string" and name ~= "" then
    fdName = name
  end
end

function M:Slash(rest)
  if rest == "test" then
    return M.Fire()
  end
  Core.Say(Core.Knows("Feign Death") and "Feign Death watch is on: a resisted feign gives a big alert and sound. /nock feign test"
    or "Feign Death comes at level 30. The resisted alert switches itself on then.")
end

function M:Report()
  return { Core.Knows("Feign Death") and "Watching your Feign Death for resists." or "Feign Death at level 30." }
end
