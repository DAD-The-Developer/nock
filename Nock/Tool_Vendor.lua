--[[
  Nock 3.4.0 hunter tool: sell junk and repair at vendors.

  When you open a merchant Nock sells every grey item and repairs all gear
  from your own gold (never the guild bank), then prints one line:
    Nock: Sold 6 junk items for 1g 12s 40c. Repaired for 3g 2s 0c.
  Hold Shift while opening the vendor to skip it once. Each half has its own
  switch. Selling goes in small batches so the server keeps up.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "vendor",
  name = "Sell junk and repair",
  desc = "At any vendor: sell greys and repair from your own gold, with a one-line summary.",
  cmd = { "vendor", "junk", "repair" },
  defaults = { on = true, sell = true, repair = true },
  options = {
    { key = "sell", label = "Sell grey (junk) items automatically" },
    { key = "repair", label = "Repair automatically (your gold, never guild)" },
  },
  help = { "/nock vendor — auto sell junk and auto repair on or off   /nock vendor sell | repair — one half" },
})

local BATCH = 10
local queue, sold, soldCount = {}, 0, 0
local atVendor = false

-- Items to sell: greys with a vendor price, not locked. Pure (tested).
function M.JunkList(bags)
  local out = {}
  for _, it in ipairs(bags or {}) do
    if it.quality == 0 and (it.price or 0) > 0 and not it.locked and not it.noValue then
      out[#out + 1] = it
    end
  end
  return out
end

local function Use(bag, slot)
  local f = (C_Container and C_Container.UseContainerItem) or UseContainerItem
  if f then
    pcall(f, bag, slot)
  end
end

local function Summary(repaired)
  local parts = {}
  if soldCount > 0 then
    parts[#parts + 1] = string.format("Sold %d junk item%s for %s.", soldCount, soldCount == 1 and "" or "s", Core.Money(sold))
  end
  if repaired and repaired > 0 then
    parts[#parts + 1] = string.format("Repaired for %s.", Core.Money(repaired))
  elseif repaired == false then
    parts[#parts + 1] = "Not enough gold to repair everything."
  end
  if #parts > 0 then
    Core.Say(table.concat(parts, " "))
  end
end

local pendingRepair
local function SellBatch()
  if not atVendor then
    queue = {}
    return
  end
  local n = 0
  while #queue > 0 and n < BATCH do
    local it = table.remove(queue, 1)
    Use(it.bag, it.slot)
    sold = sold + (it.price or 0) * (it.count or 1)
    soldCount = soldCount + 1
    n = n + 1
  end
  if #queue > 0 and C_Timer and C_Timer.After then
    C_Timer.After(0.3, SellBatch)
  else
    Summary(pendingRepair)
    pendingRepair = nil
  end
end

local function Repair()
  if Core.Get("vendor", "repair") == false or not (CanMerchantRepair and RepairAllItems and GetRepairAllCost) then
    return nil
  end
  if not Core.Call(CanMerchantRepair) then
    return nil
  end
  local cost, can = Core.Call(GetRepairAllCost)
  cost = Core.Number(cost) or 0
  if cost <= 0 or not can then
    return nil
  end
  local money = Core.Number(GetMoney and GetMoney()) or 0
  if money < cost then
    return false
  end
  pcall(RepairAllItems, false) -- false = own gold, never the guild bank
  return cost
end

Core.On("MERCHANT_SHOW", "vendor", function()
  atVendor = true
  if IsShiftKeyDown and IsShiftKeyDown() then
    Core.Say("Shift held: no auto sell or repair this time.")
    return
  end
  sold, soldCount = 0, 0
  pendingRepair = Repair()
  if Core.Get("vendor", "sell") ~= false then
    queue = M.JunkList(Core.ScanBags())
  else
    queue = {}
  end
  SellBatch()
end)

Core.On("MERCHANT_CLOSED", "vendor", function()
  atVendor = false
  queue = {}
end)

function M:Slash(rest)
  if rest == "sell" or rest == "junk" then
    Core.Set("vendor", "sell", Core.Get("vendor", "sell") == false)
    return Core.Say("Auto sell junk: " .. (Core.Get("vendor", "sell") ~= false and "on" or "off"))
  elseif rest == "repair" then
    Core.Set("vendor", "repair", Core.Get("vendor", "repair") == false)
    return Core.Say("Auto repair: " .. (Core.Get("vendor", "repair") ~= false and "on" or "off"))
  end
  Core.Say(string.format("Auto sell junk: %s   Auto repair: %s   (hold Shift at a vendor to skip once)",
    Core.Get("vendor", "sell") ~= false and "on" or "off", Core.Get("vendor", "repair") ~= false and "on" or "off"))
end

function M:Report()
  local junk, value = M.JunkList(Core.Bags()), 0
  for _, it in ipairs(junk) do
    value = value + (it.price or 0) * (it.count or 1)
  end
  return { string.format("%d junk item%s in your bags (%s). Sold automatically at the next vendor.", #junk, #junk == 1 and "" or "s", Core.Money(value)) }
end
