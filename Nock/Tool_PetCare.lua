--[[
  Nock 3.4.0 hunter tool: pet happiness and one-key feeding.

  * Big warning when your pet drops to content (yellow) or unhappy (red).
  * One key, "Feed pet (best food)", runs Feed Pet on the best food in your
    bags that your pet eats. The button is a secure macro Nock rewrites out
    of combat whenever your bags or pet change, so it never taints.
  * Warns when you carry nothing your pet will eat, or only food too low
    level for it to help.

  Scales by data: diets come from GetPetFoodTypes() and Data_Food.lua (add
  item IDs or name words there). Beast Mastery builds get louder content
  warnings because the pet is most of their damage.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "pet",
  name = "Pet happiness and feeding",
  desc = "Big warning when your pet is not happy. One key feeds it the best food it eats.",
  cmd = { "pet", "feed" },
  defaults = { on = true, content = true, nofood = true },
  options = {
    { key = "content", label = "Warn at content (yellow), not just unhappy", tip = "Content pets do less damage. Feed them before they turn red." },
    { key = "nofood", label = "Warn when you carry no food your pet eats" },
  },
  help = { "/nock pet — pet happiness, diet and the food the Feed key will use. Key: Feed pet (best food)" },
})

local HAPPY_TEXT = { [1] = "unhappy", [2] = "content", [3] = "happy" }

local function HasPet()
  return Core.UnitFlag(UnitExists, "pet") == true and Core.UnitFlag(UnitIsDead, "pet") ~= true
end

local function Happiness()
  if not GetPetHappiness then
    return nil
  end
  local ok, h = pcall(GetPetHappiness)
  if not ok then
    return nil
  end
  return Core.Number(h)
end

function M.Diets()
  local out = {}
  if GetPetFoodTypes then
    local res = { pcall(GetPetFoodTypes) }
    if res[1] then
      for i = 2, #res do
        local d = res[i]
        if type(d) == "string" and not Core.IsSecret(d) then
          out[d] = true
          -- Raw meat / fish read as "Meat" / "Fish" in the food table.
          if d:find("Meat", 1, true) then
            out.Meat = true
          end
          if d:find("Fish", 1, true) then
            out.Fish = true
          end
        end
      end
    end
  end
  if next(out) == nil and UnitCreatureFamily then
    local fam = Core.Call(UnitCreatureFamily, "pet")
    local data = fam and Nock.Data and Nock.Data.PetFamilies and Nock.Data.PetFamilies[fam]
    for _, d in ipairs(data and data.diet or {}) do
      out[d] = true
      if d == "Raw Meat" then
        out.Meat = true
      elseif d == "Raw Fish" then
        out.Fish = true
      end
    end
  end
  return out
end

-- Food quality for a pet level: 3 = full happiness, 2 = some, 1 = a little,
-- 0 = too low to help (Classic rules: within 5 / 10 / 15 levels).
function M.FoodGrade(foodLevel, petLevel)
  local gap = (petLevel or 1) - (foodLevel or 0)
  if gap <= 5 then
    return 3
  elseif gap <= 10 then
    return 2
  elseif gap <= 15 then
    return 1
  end
  return 0
end

-- Best food: the best grade first, then the lowest level within that grade
-- (save the good stuff), then the biggest stack.
function M.PickFood(bags, diets, petLevel)
  local best, bestKey
  local any = false
  for _, it in ipairs(bags or {}) do
    local diet = Core.FoodDiet(it)
    if diet and diets[diet] and not it.locked then
      any = true
      local lvl = math.max(it.minLevel or 0, it.ilvl or 0)
      local grade = M.FoodGrade(lvl, petLevel)
      local key = grade * 1e6 - lvl * 1e3 + math.min(it.count or 1, 999)
      if not bestKey or key > bestKey then
        best, bestKey = it, key
        best.grade = grade
      end
    end
  end
  return best, any
end

function M.Count(bags, diets)
  local n = 0
  for _, it in ipairs(bags or {}) do
    local diet = Core.FoodDiet(it)
    if diet and diets[diet] then
      n = n + (it.count or 1)
    end
  end
  return n
end

-- Secure feed button ------------------------------------------------------------

local button
local wantMacro
local function KeyDown()
  local v = GetCVar and GetCVar("ActionButtonUseKeyDown")
  return v == "1"
end

local function MakeButton()
  if button or not CreateFrame then
    return button
  end
  local ok, b = pcall(CreateFrame, "Button", "NockFeedButton", UIParent, "SecureActionButtonTemplate")
  if not ok or not b or not b.SetAttribute then
    return nil
  end
  button = b
  b:SetSize(1, 1)
  b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
  if b.RegisterForClicks then
    b:RegisterForClicks(KeyDown() and "AnyDown" or "AnyUp")
  end
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "/cast Feed Pet")
  return b
end

function M.DietText(diets)
  local list = {}
  for d in pairs(diets or {}) do
    if d ~= "Raw Meat" and d ~= "Raw Fish" then
      list[#list + 1] = d:lower()
    end
  end
  table.sort(list)
  if #list == 0 then
    return "unknown food"
  end
  return table.concat(list, ", ")
end

local function PetName()
  local n = Core.Call(UnitName, "pet")
  if type(n) ~= "string" or Core.IsSecret(n) then
    return "Your pet"
  end
  return n
end

function M.MacroText()
  local feed = select(3, Core.Call(Nock.PlayerKnows, "Feed Pet")) or "Feed Pet"
  if not HasPet() then
    local call = select(3, Core.Call(Nock.PlayerKnows, "Call Pet")) or "Call Pet"
    return "/cast " .. call, nil
  end
  local diets = M.Diets()
  local food = M.PickFood(Core.Bags(), diets, Core.Number(UnitLevel and UnitLevel("pet")) or Core.P.level)
  if not food then
    return string.format("/run Nock.Alerts:Fire('pet.nofood',{diet='%s'},{force=true})", M.DietText(diets)), nil
  end
  return string.format("/cast %s\n/use item:%d", feed, food.id), food
end

function M.UpdateButton()
  if not button then
    MakeButton()
  end
  if not button then
    return
  end
  local text, food = M.MacroText()
  M.food = food
  if InCombatLockdown and InCombatLockdown() then
    wantMacro = text
    return
  end
  wantMacro = nil
  if button:GetAttribute("macrotext") ~= text then
    button:SetAttribute("macrotext", text)
  end
  if button.RegisterForClicks then
    button:RegisterForClicks(KeyDown() and "AnyDown" or "AnyUp")
  end
end

-- Warnings ----------------------------------------------------------------------

local lastH
local function PvPQuiet()
  return Core.PvPMode() and Core.Get("pet", "inPvP") ~= true
end

local function Warn(h, force)
  if not HasPet() or PvPQuiet() then
    return
  end
  local A = Nock.Alerts
  if h == 1 then
    A:Fire("pet.unhappy", { pet = PetName() }, { force = force })
  elseif h == 2 and Core.Get("pet", "content") ~= false and not Core.InCombat() then
    A:Fire("pet.content", { pet = PetName() }, { force = force })
  end
end

local function CheckFood()
  if Core.Get("pet", "nofood") == false or not HasPet() or Core.InCombat() or PvPQuiet() then
    return
  end
  local diets = M.Diets()
  if next(diets) == nil then
    return
  end
  local petLevel = Core.Number(UnitLevel and UnitLevel("pet")) or Core.P.level
  local food, any = M.PickFood(Core.Bags(), diets, petLevel)
  if not any then
    Nock.Alerts:Fire("pet.nofood", { diet = M.DietText(diets) })
  elseif food and food.grade == 0 then
    Nock.Alerts:Fire("pet.lowfood", { food = food.name or "Your food", level = petLevel })
  end
end

function M:Init()
  MakeButton()
  M.UpdateButton()
  lastH = Happiness()
end

function M:Refresh()
  M.UpdateButton()
end

function M:OnProfile()
  M.UpdateButton()
end

local function OnHappiness(_, unit)
  if unit and unit ~= "pet" then
    return
  end
  local h = Happiness()
  if h and h ~= lastH then
    if lastH == nil or h < lastH then
      Warn(h, true)
    end
    lastH = h
  end
end

Core.On("UNIT_HAPPINESS", "pet", OnHappiness)
Core.On("UNIT_PET", "pet", function(_, unit)
  if unit == "player" then
    lastH = Happiness()
    M.UpdateButton()
  end
end)
Core.On("PET_UI_UPDATE", "pet", function()
  M.UpdateButton()
end)
Core.On("BAG_UPDATE_DELAYED", "pet", function()
  Core.BagsDirty()
  if Core.Throttle("pet:bags", 1) then
    M.UpdateButton()
  elseif C_Timer and C_Timer.After then
    C_Timer.After(1.1, function()
      pcall(M.UpdateButton)
    end)
  end
end)
Core.On("PLAYER_REGEN_ENABLED", "pet", function()
  M.UpdateButton()
  local h = Happiness()
  if h and h < 3 then
    Warn(h)
  end
end)
-- Gentle repeat while out of combat and not happy, plus the food check.
Core.Every("pet", 20, function()
  if Core.InCombat() then
    return
  end
  local h = Happiness()
  if h and h < 3 then
    Warn(h)
  end
  CheckFood()
end)

function M:Slash(rest)
  if rest == "feed" then
    return Core.Say("Bind 'Feed pet (best food)' in Key Bindings > AddOns > Nock. Slash commands cannot feed (Blizzard protects it).")
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local out = {}
  if not HasPet() then
    out[1] = "No pet out. The Feed key calls your pet when none is out."
    return out
  end
  local name = Core.Call(UnitName, "pet") or "Pet"
  local fam = Core.Call(UnitCreatureFamily, "pet") or "?"
  local h = Happiness()
  out[#out + 1] = string.format("%s (%s, level %s): %s", tostring(name), tostring(fam),
    tostring(Core.Number(UnitLevel and UnitLevel("pet")) or "?"), h and HAPPY_TEXT[h] or "unknown")
  local diets, list = M.Diets(), {}
  for d in pairs(diets) do
    list[#list + 1] = d
  end
  table.sort(list)
  out[#out + 1] = "Eats: " .. (#list > 0 and table.concat(list, ", ") or "unknown")
  local food = M.food or (M.PickFood(Core.Bags(), diets, Core.Number(UnitLevel and UnitLevel("pet")) or 1))
  out[#out + 1] = food and string.format("Feed key uses: %s (%d in bags of this diet)", food.name or ("item " .. food.id), M.Count(Core.Bags(), diets))
    or "Feed key: no suitable food in your bags"
  return out
end
