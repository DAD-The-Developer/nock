--[[
  Nock 3.4.0 hunter tool: pre-departure supply check.

  Counts ammo (from the quiver counter), pet food your pet eats, and your own
  food and water. When something is low it tells you:
    * while you are in town or within ~150 yards of an ammo vendor (from the
      built-in map pin list), and
    * loudly the moment you leave a town (rested area) still short.

  Endgame mode raises the targets to raid-night amounts (/nock supplies raid
  shows the full consumable checklist). Thresholds are settings, so you can
  tune them as content grows: /nock supplies ammo 2000.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "supplies",
  name = "Supply warnings",
  desc = "Low ammo, pet food, food or water: told in town and when you leave.",
  cmd = { "supplies", "supply" },
  defaults = {
    on = true, leave = true, vendor = true, water = true,
    ammo = 600, petfood = 10, food = 5, drink = 5,
    raidAmmo = 2000, raidPetfood = 30, raidFood = 20, raidDrink = 20,
  },
  options = {
    { key = "leave", label = "Big warning when you leave town short on supplies" },
    { key = "vendor", label = "Remind me near ammo vendors and in town" },
    { key = "water", label = "Count my food and water too" },
  },
  help = { "/nock supplies — what you carry vs. what you need   /nock supplies ammo|petfood|food|drink <number>   /nock supplies raid" },
})

local NEAR_VENDOR_YARDS = 150

local function Targets()
  local raid = Core.IsEndgame()
  local g = function(k)
    return tonumber(Core.Get("supplies", k)) or 0
  end
  if raid then
    return { ammo = g("raidAmmo"), petfood = g("raidPetfood"), food = g("raidFood"), drink = g("raidDrink") }, true
  end
  return { ammo = g("ammo"), petfood = g("petfood"), food = g("food"), drink = g("drink") }, false
end

-- Stock now. Pure function of the bag list and ammo state (tested).
function M.Stock(bags, ammoCount, diets)
  local s = { ammo = ammoCount or 0, petfood = 0, food = 0, drink = 0 }
  for _, it in ipairs(bags or {}) do
    if Core.IsDrink(it) then
      s.drink = s.drink + (it.count or 1)
    end
    if Core.IsFood(it) then
      s.food = s.food + (it.count or 1)
    end
    local diet = diets and Core.FoodDiet(it)
    if diet and diets[diet] then
      s.petfood = s.petfood + (it.count or 1)
    end
  end
  return s
end

function M.Short(stock, targets, opts)
  opts = opts or {}
  local out = {}
  if stock.ammo < targets.ammo then
    out[#out + 1] = string.format("ammo %d/%d", stock.ammo, targets.ammo)
  end
  if opts.hasPet and stock.petfood < targets.petfood then
    out[#out + 1] = string.format("pet food %d/%d", stock.petfood, targets.petfood)
  end
  if opts.own then
    if stock.food < targets.food then
      out[#out + 1] = string.format("food %d/%d", stock.food, targets.food)
    end
    if opts.drink and stock.drink < targets.drink then
      out[#out + 1] = string.format("water %d/%d", stock.drink, targets.drink)
    end
  end
  return out
end

local function Current()
  local ammo = 0
  if Nock.Quiver and Nock.Quiver.State then
    local ok, st = pcall(Nock.Quiver.State)
    if ok and st then
      ammo = st.count or 0
    end
  end
  local pet = Core.Module("pet")
  local hasPet = Core.UnitFlag(UnitExists, "pet") == true
  local diets = (pet and pet.Diets and hasPet) and pet.Diets() or nil
  local stock = M.Stock(Core.Bags(), ammo, diets)
  local targets, raid = Targets()
  -- Water matters once you have a mana pool worth refilling.
  local short = M.Short(stock, targets, {
    hasPet = hasPet, own = Core.Get("supplies", "water") ~= false, drink = Core.P.level >= 10,
  })
  return stock, targets, short, raid
end

local function Tell(loud, why)
  local _, _, short, raid = Current()
  if #short == 0 then
    return false
  end
  local text = (loud and "Leaving town short: " or "Low supplies: ") .. table.concat(short, ", ")
  local sub
  local e, yd = Core.NearestPin(4)
  if e then
    sub = "Nearest ammo vendor: " .. Core.PinText(e, yd)
  end
  if raid then
    sub = (sub and (sub .. ". ") or "") .. "Raid-night targets (endgame mode)."
  end
  Core.Alert(text, { color = loud and "bad" or "warn", key = "supplies", priority = loud and 3 or 1,
    sub = sub, sound = loud and true or nil, duration = loud and 6 or 4 })
  return true
end
M.Tell = Tell

local wasResting
function M:Init()
  wasResting = Core.P.resting
end

Core.On("PLAYER_UPDATE_RESTING", "supplies", function()
  local now = Core.UnitFlag(IsResting) == true
  if wasResting and not now and Core.Get("supplies", "leave") ~= false then
    Tell(true, "leave")
  elseif now and not wasResting and Core.Get("supplies", "vendor") ~= false and Core.Throttle("supplies:town", 300) then
    Tell(false, "town")
  end
  wasResting = now
end)

-- Near an ammo vendor outside town: a quiet reminder every 5 minutes at most.
Core.Every("supplies", 5, function()
  if Core.Get("supplies", "vendor") == false or Core.InCombat() or Core.P.instance ~= "none" then
    return
  end
  local _, yd = Core.NearestPin(4)
  if yd and yd < NEAR_VENDOR_YARDS and Core.Throttle("supplies:vendor", 300) then
    if not Tell(false, "vendor") then
      Core.ResetThrottle("supplies:vendor")
    end
  end
end)

-- Battleground queue popped: check ammo before you click Enter.
function M:OnProfile(what)
  if what == "queuepop" then
    local _, _, short = Current()
    if #short > 0 then
      Core.Alert("Queue popped — low: " .. table.concat(short, ", "), { color = "bad", key = "supplies", priority = 3,
        sub = "Restock before you enter if a vendor is close.", sound = true, duration = 6 })
    end
  end
end

local KEYS = { ammo = "ammo", petfood = "petfood", pet = "petfood", food = "food", drink = "drink", water = "drink" }

function M:Slash(rest)
  local word, num = rest:match("^(%S+)%s+(%d+)$")
  if word and KEYS[word] then
    local key = KEYS[word]
    if Core.IsEndgame() then
      key = "raid" .. key:sub(1, 1):upper() .. key:sub(2)
    end
    Core.Set("supplies", key, tonumber(num))
    return Core.Say(string.format("Supply target %s: %s", key, num))
  end
  if rest == "raid" or rest == "checklist" then
    local ctx = Core.P.context
    local key = (ctx == "raidinstance" or ctx == "raid") and "raid" or (ctx == "dungeon" and "dungeon" or (ctx == "pvp" and "pvp" or "raid"))
    Core.Say("Checklist (" .. key .. "):")
    for _, line in ipairs((Nock.Data.Checklists or {})[key] or {}) do
      Core.Say("  [ ] " .. line)
    end
    return
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local stock, targets, short, raid = Current()
  local out = {}
  out[#out + 1] = string.format("Ammo %d / %d   Pet food %d / %d   Food %d / %d   Water %d / %d%s",
    stock.ammo, targets.ammo, stock.petfood, targets.petfood, stock.food, targets.food, stock.drink, targets.drink,
    raid and "   (raid-night targets)" or "")
  out[#out + 1] = #short == 0 and "Stocked. Good hunting." or ("Short: " .. table.concat(short, ", "))
  local e, yd = Core.NearestPin(4)
  if e then
    out[#out + 1] = "Nearest ammo vendor: " .. Core.PinText(e, yd)
  end
  return out
end

function _G.Nock_SupplyCheck()
  if not Core.Enabled("supplies") then
    return Core.Say("Supply warnings are off. /nock supplies on")
  end
  if not M.Tell(false, "key") then
    Core.Alert("Supplies look good", { color = "good", key = "supplies", priority = 1, sub = M:Report()[1], duration = 3 })
  end
end
