--[[
  Nock 3.13.0 hunter tool: gold while levelling.

  Six small helpers, each with its own switch (Options > Tools, or
  /nock gold <part> on|off):

    value   Bag item tooltips show what the item sells for at a vendor (each
            and for the stack) and, when Auctionator is installed, its last
            auction price. Items worth more than the keep threshold (1g by
            default, /nock gold threshold <gold>), any green or better, and
            every recipe get a quiet "Keep — worth selling" line. Greys say
            Nock sells them at the next vendor. Selling stays with the junk
            seller (Tool_Vendor): greys only, never anything else.
    drops   A calm toast when you loot something over the threshold, a green
            or better, or a recipe / pattern.
    pins    Skinning camps (skinnable beasts) and coin camps (mobs that drop
            coin) near your level on the world map and minimap. Every camp is
            a real group of spawn spots from QuestieDB Forever; skinnable,
            beast and coin per kill come from CMaNGOS classic-db (Data_Gold).
    dash    A gold block on the dashboard: earned this session, gold per hour,
            what your bags are worth (vendor, and auction with Auctionator)
            and the mount fund meter.
    prof    Which gathering professions you have, a nudge toward Skinning plus
            Mining or Herbalism when a slot is free, a reminder when the next
            rank can be trained (Journeyman 50 skill + level 10, Expert 125 +
            20, Artisan 200 + 35) and which leather / herb / ore / cloth stacks
            are worth holding.
    fund    Mount fund toward level 40 (riding 90g + mount 10g = 100g in the
            Classic data, before reputation discounts; /nock gold mount <gold>
            sets your own target), the best value arrows or bullets at a
            vendor for your level, and at the hunter trainer which new ranks
            can wait because they are not on your Nock bars. Advice only.

  Nothing is ever bought, posted or sold by this tool. Auctionator is read
  through its public API (Auctionator.API.v1) inside pcall; without it every
  value is the vendor price and says so.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "gold",
  name = "Gold while levelling",
  desc = "Item values and a keep tag, valuable loot alerts, skinning and coin camps, session gold, profession and mount fund tips.",
  cmd = { "gold", "money" },
  defaults = { on = true, value = true, drops = true, pins = true, dash = true, prof = true, fund = true, threshold = 10000 },
  options = {
    { key = "value", label = "Vendor and auction value in bag tooltips, with a keep tag on valuable items" },
    { key = "drops", label = "Tell me when I loot something valuable (over the threshold, green+, recipes)" },
    { key = "pins", label = "Skinning and coin camps near my level on the maps" },
    { key = "dash", label = "Gold on the dashboard (session, gold per hour, bag value, mount fund)" },
    { key = "prof", label = "Profession tips (what to take, when to train the next rank)" },
    { key = "fund", label = "Mount fund, best ammo at vendors, trainer ranks that can wait" },
  },
  help = {
    "/nock gold — session gold, bag value, mount fund   /nock gold value | drops | pins | dash | prof | fund [on|off]",
    "/nock gold threshold <gold> — keep tag and loot alert value   /nock gold mount <gold> | auto — mount fund target   /nock gold reset — new session",
  },
})
Nock.Gold = M

local PARTS = { value = "Bag tooltips and keep tag", drops = "Valuable loot alerts", pins = "Skinning and coin camps",
  dash = "Gold on the dashboard", prof = "Profession tips", fund = "Mount fund, ammo and trainer tips" }
M.PARTS = PARTS
local GOLDC = "|cffffd34d"

function M.On(part)
  return Core.Enabled("gold") and Core.Get("gold", part) ~= false
end

function M.Threshold()
  local t = tonumber(Core.Get("gold", "threshold"))
  return (t and t >= 0) and t or 10000
end

-- Items ------------------------------------------------------------------------------

-- Everything about one item: { id, name, link, quality, price (vendor, each), classID, subclassID, subType, stack }
function M.Info(item)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not f or not item then
    return nil
  end
  local ok, name, link, quality, _, _, _, subType, stack, _, _, price, classID, subclassID = pcall(f, item)
  if not ok or not name then
    return nil
  end
  local id = tonumber(item) or tonumber(tostring(link or item):match("item:(%d+)"))
  return { id = id, name = name, link = link, quality = tonumber(quality) or 1, price = tonumber(price) or 0,
    classID = tonumber(classID), subclassID = tonumber(subclassID), subType = subType, stack = tonumber(stack) or 1 }
end

-- Auctionator's last scanned price for one, in copper, or nil (not installed / never seen).
function M.HasAuctionator()
  local A = _G.Auctionator
  return type(A) == "table" and type(A.API) == "table" and type(A.API.v1) == "table" and true or false
end

function M.AHPrice(link, id)
  if not M.HasAuctionator() then
    return nil
  end
  local api = _G.Auctionator.API.v1
  local v
  if link and type(api.GetAuctionPriceByItemLink) == "function" then
    local ok, p = pcall(api.GetAuctionPriceByItemLink, "Nock", link)
    v = ok and tonumber(p) or nil
  end
  if not v and id and type(api.GetAuctionPriceByItemID) == "function" then
    local ok, p = pcall(api.GetAuctionPriceByItemID, "Nock", id)
    v = ok and tonumber(p) or nil
  end
  return (v and v > 0) and v or nil
end

-- Value of a stack: { vendor = each, ah = each or nil, count, best = the larger total }
function M.Value(info, count)
  if not info then
    return nil
  end
  count = tonumber(count) or 1
  local ah = M.AHPrice(info.link, info.id)
  local vendor = info.price or 0
  local each = math.max(vendor, ah or 0)
  return { vendor = vendor, ah = ah, count = count, each = each, best = each * count, source = (ah and ah > vendor) and "auction" or "vendor" }
end

M.RECIPE_CLASS = 9
M.QUEST_CLASS = 12

-- Should this be kept (sold on the auction house or to a vendor later, not
-- thrown away)? Greys never: the junk seller handles them. Pure (tested).
function M.IsKeep(info, value)
  if not info or (info.quality or 1) == 0 or info.classID == M.QUEST_CLASS then
    return false
  end
  if info.classID == M.RECIPE_CLASS then
    return true, "recipe"
  end
  if (info.quality or 1) >= 2 then
    return true, "quality"
  end
  if value and value.best >= M.Threshold() and M.Threshold() > 0 then
    return true, "value"
  end
  return false
end

-- Tooltip lines for one bag stack (pure apart from the price lookups).
function M.TipLines(info, count)
  local v = M.Value(info, count)
  if not v then
    return {}
  end
  local out = {}
  if (info.quality or 1) == 0 and v.vendor > 0 then
    local sells = Core.Enabled("vendor") and Core.Get("vendor", "sell") ~= false
    out[#out + 1] = { (v.count > 1 and string.format("Vendor  %s each, %s for %d", Core.Money(v.vendor), Core.Money(v.vendor * v.count), v.count)
      or ("Vendor  " .. Core.Money(v.vendor))), sells and "junk — Nock sells it at the next vendor" or "junk" }
    return out
  end
  if v.vendor > 0 then
    out[#out + 1] = { v.count > 1 and string.format("Vendor  %s each, %s for %d", Core.Money(v.vendor), Core.Money(v.vendor * v.count), v.count)
      or ("Vendor  " .. Core.Money(v.vendor)) }
  elseif not v.ah then
    out[#out + 1] = { "No vendor price" }
  end
  if v.ah then
    out[#out + 1] = { v.count > 1 and string.format("Auction  %s each, %s for %d", Core.Money(v.ah), Core.Money(v.ah * v.count), v.count)
      or ("Auction  " .. Core.Money(v.ah)), "Auctionator" }
  end
  local keep, why = M.IsKeep(info, v)
  if keep then
    out[#out + 1] = { "Keep — worth selling", why == "recipe" and "recipe" or (why == "quality" and "green or better" or ("over " .. M.Short(M.Threshold()))), keep = true }
  end
  return out
end

local function OnBagTip(tt, bag, slot)
  if not M.On("value") or not (tt and tt.AddLine) then
    return
  end
  local id, count
  if C_Container and C_Container.GetContainerItemInfo then
    local ok, ci = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(ci) == "table" then
      id, count = ci.hyperlink or ci.itemID, ci.stackCount
    end
  end
  local info = id and M.Info(id)
  if not info then
    return
  end
  local lines = M.TipLines(info, count or 1)
  for _, l in ipairs(lines) do
    if l.keep then
      tt:AddDoubleLine(GOLDC .. l[1] .. "|r", l[2], 1, 0.83, 0.3, 0.6, 0.6, 0.6)
    elseif l[2] then
      tt:AddDoubleLine(l[1], l[2], 0.85, 0.85, 0.85, 0.6, 0.6, 0.6)
    else
      tt:AddLine(l[1], 0.85, 0.85, 0.85)
    end
  end
  if #lines > 0 and tt.Show then
    tt:Show()
  end
end
M.OnBagTip = OnBagTip

if hooksecurefunc and GameTooltip and type(GameTooltip) == "table" then
  pcall(hooksecurefunc, GameTooltip, "SetBagItem", OnBagTip)
end

-- Bag totals: { vendor = copper, ah = copper (auction where known, else vendor) or nil, keep = { items } }
function M.BagValue(bags)
  local vendor, ah, anyAH, keep = 0, 0, false, {}
  for _, it in ipairs(bags or Core.Bags() or {}) do
    if not it.noValue then
      local info = M.Info(it.id) or { id = it.id, price = it.price, quality = it.quality, classID = it.classID, name = it.name }
      local v = M.Value(info, it.count)
      vendor = vendor + v.vendor * v.count
      if v.ah then
        anyAH = true
        ah = ah + v.ah * v.count
      else
        ah = ah + v.vendor * v.count
      end
      if M.IsKeep(info, v) then
        keep[#keep + 1] = { name = info.name or it.name, count = v.count, best = v.best, source = v.source }
      end
    end
  end
  table.sort(keep, function(a, b) return a.best > b.best end)
  return { vendor = vendor, ah = anyAH and ah or nil, keep = keep }
end

-- Session gold -------------------------------------------------------------------------

M.session = { start = nil, at = nil, earned = 0, spent = 0, last = nil }

local function Money()
  return tonumber(GetMoney and GetMoney()) or 0
end

function M.ResetSession()
  local s = M.session
  s.start, s.at, s.earned, s.spent, s.last = Money(), Core.Now(), 0, 0, Money()
end

function M.OnMoney(now)
  local s = M.session
  if not s.last then
    M.ResetSession()
    return
  end
  now = now or Money()
  local d = now - s.last
  if d > 0 then
    s.earned = s.earned + d
  elseif d < 0 then
    s.spent = s.spent - d
  end
  s.last = now
end

-- Copper per hour; nil for the first minute (too early to say). Pure (tested).
function M.PerHour(copper, seconds)
  seconds = tonumber(seconds) or 0
  if seconds < 60 then
    return nil
  end
  return math.floor((tonumber(copper) or 0) * 3600 / seconds + 0.5)
end

function M.Session()
  local s = M.session
  if not s.at then
    M.ResetSession()
  end
  local secs = Core.Now() - s.at
  return { earned = s.earned, spent = s.spent, net = s.earned - s.spent, seconds = secs, perHour = M.PerHour(s.earned, secs) }
end

-- Mount fund ----------------------------------------------------------------------------

function M.MountTarget()
  local own = tonumber(Core.Get("gold", "mount"))
  if own and own > 0 then
    return own, "your target"
  end
  local d = (Nock.Data and Nock.Data.Gold and Nock.Data.Gold.Mount) or {}
  if d.riding and d.mount then
    return d.riding + d.mount, "riding + mount, Classic data"
  end
  return nil, "set one with /nock gold mount <gold>"
end

-- { target, have, left, pct (0-1), source }. Pure apart from settings (tested).
function M.Fund(money, target)
  local src
  if not target then
    target, src = M.MountTarget()
  end
  money = tonumber(money) or Money()
  if not target or target <= 0 then
    return { have = money, source = src }
  end
  return { target = target, have = money, left = math.max(0, target - money), pct = math.min(1, money / target), source = src }
end

-- Dashboard rows (Dashboard.lua paints them). nil when the part is off.
function M.DashInfo()
  if not M.On("dash") then
    return nil
  end
  local s = M.Session()
  local b = M.BagValue()
  local fund = M.On("fund") and (Core.P.level or 1) < 60 and M.Fund() or nil
  local sub = "Bags " .. M.Short(b.vendor) .. " vendor"
  if b.ah then
    sub = sub .. "  ·  " .. M.Short(b.ah) .. " auction"
  end
  if fund and fund.target then
    sub = sub .. string.format("  ·  Mount %d%%", math.floor(fund.pct * 100))
  end
  return {
    value = (s.earned > 0 and "+" or "") .. M.Short(s.earned),
    note = s.perHour and (M.Short(s.perHour) .. " / hr") or "",
    sub = sub,
    meter = fund and fund.pct or nil,
    session = s, bags = b, fund = fund,
  }
end

-- "12g 30s" style without the copper once there is gold.
function M.Short(copper)
  copper = math.floor(tonumber(copper) or 0)
  if copper >= 10000 then
    local g, s = math.floor(copper / 10000), math.floor((copper % 10000) / 100)
    return s > 0 and string.format("%dg %ds", g, s) or string.format("%dg", g)
  end
  if copper >= 100 and copper % 100 == 0 then
    return string.format("%ds", copper / 100)
  end
  return Core.Money(copper)
end

-- Valuable loot alerts ----------------------------------------------------------------------

local function LootPattern(fmt)
  if type(fmt) ~= "string" then
    return nil
  end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
  return "^" .. p .. "$"
end
M.LootPattern = LootPattern

-- Your own loot line -> link, count (nil for other players' loot and pushed items).
function M.ParseLoot(msg)
  if type(msg) ~= "string" then
    return nil
  end
  local multi = LootPattern(_G.LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.")
  local one = LootPattern(_G.LOOT_ITEM_SELF or "You receive loot: %s.")
  local link, n = msg:match(multi)
  if link then
    return link, tonumber(n) or 1
  end
  link = msg:match(one)
  if link then
    return link, 1
  end
  return nil
end

-- Is this loot worth a toast? -> true, reason. Pure apart from prices (tested).
function M.DropWorth(info, count)
  if not info or (info.quality or 1) == 0 and (info.price or 0) * (count or 1) < M.Threshold() then
    return false
  end
  if info.classID == M.QUEST_CLASS then
    return false
  end
  if info.classID == M.RECIPE_CLASS then
    return true, "Recipe"
  end
  if (info.quality or 1) >= 2 then
    return true, ({ [2] = "Green", [3] = "Blue", [4] = "Epic", [5] = "Legendary" })[info.quality] or "Rare"
  end
  local v = M.Value(info, count)
  if v and M.Threshold() > 0 and v.best >= M.Threshold() then
    return true, "Worth " .. M.Short(v.best)
  end
  return false
end

local waiting = {}
function M.OnLoot(msg)
  if not M.On("drops") then
    return
  end
  local link, count = M.ParseLoot(msg)
  if not link then
    return
  end
  local info = M.Info(link)
  if not info then
    waiting[#waiting + 1] = { link = link, count = count, at = Core.Now() }
    return
  end
  local ok, why = M.DropWorth(info, count)
  if not ok then
    return
  end
  local v = M.Value(info, count)
  local worth = v.ah and string.format("Auction %s  ·  vendor %s", M.Short(v.ah * v.count), M.Short(v.vendor * v.count))
    or (v.vendor > 0 and ("Vendor " .. M.Short(v.vendor * v.count)) or "No vendor price")
  local title = (info.link or info.name) .. (count > 1 and (" x" .. count) or "")
  M.lastDrop = { title = title, why = why, worth = worth }
  if not (Nock.Alerts and Nock.Alerts:Fire("gold.drop", { item = title, why = why, worth = worth },
    { key = "gold.drop." .. tostring(info.id or info.name), icon = info.id and ("item:" .. info.id) or nil })) then
    Core.Say(string.format("%s — %s, %s", title, why, worth))
  end
end

Core.On("CHAT_MSG_LOOT", "gold", function(_, msg)
  M.OnLoot(msg)
end)

Core.On("GET_ITEM_INFO_RECEIVED", "gold", function()
  if #waiting == 0 then
    return
  end
  local list = waiting
  waiting = {}
  for _, w in ipairs(list) do
    if Core.Now() - w.at < 30 then
      if M.Info(w.link) then
        M.OnLoot(string.format(_G.LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", w.link, w.count))
      else
        waiting[#waiting + 1] = w
      end
    end
  end
end)

-- Professions -----------------------------------------------------------------------------

M.GATHER = { Skinning = true, Mining = true, Herbalism = true }
M.PRIMARY = { Skinning = true, Mining = true, Herbalism = true, Leatherworking = true, Blacksmithing = true,
  Engineering = true, Alchemy = true, Enchanting = true, Tailoring = true }

-- { [name] = { rank, max } } from the skills window.
function M.Professions()
  local out = {}
  if not (GetNumSkillLines and GetSkillLineInfo) then
    return out
  end
  local n = tonumber(Core.Call(GetNumSkillLines)) or 0
  for i = 1, n do
    local ok, name, header, _, rank, _, _, max = pcall(GetSkillLineInfo, i)
    if ok and name and not header and (M.PRIMARY[name] or name == "First Aid" or name == "Cooking" or name == "Fishing") then
      out[name] = { rank = tonumber(rank) or 0, max = tonumber(max) or 0 }
    end
  end
  return out
end

-- The next rank for one profession -> { rank, skill, level, cost, cap, ready, why }. Pure (tested).
function M.NextRank(name, skill, max, level)
  local rows = Nock.Data and Nock.Data.Gold and Nock.Data.Gold.ProfRanks and Nock.Data.Gold.ProfRanks[name]
  if not rows then
    return nil
  end
  for i = 1, 3 do
    local r = rows[i]
    if r and r[5] > (max or 0) then
      local ready = (skill or 0) >= r[2] and (level or 1) >= r[3]
      local why
      if not ready then
        if (skill or 0) < r[2] then
          why = string.format("needs %d skill (you have %d)", r[2], skill or 0)
        else
          why = string.format("needs level %d", r[3])
        end
      end
      return { rank = r[1], skill = r[2], level = r[3], cost = r[4], cap = r[5], ready = ready, why = why }
    end
  end
  return nil
end

-- Profession advice lines. Pure apart from data (tested).
function M.ProfTips(profs, level)
  local lines = {}
  local primaries, gather = 0, 0
  for name in pairs(profs) do
    if M.PRIMARY[name] then
      primaries = primaries + 1
    end
    if M.GATHER[name] then
      gather = gather + 1
    end
  end
  if primaries < 2 then
    local want = {}
    if not profs.Skinning then
      want[#want + 1] = "Skinning"
    end
    if not (profs.Mining or profs.Herbalism) and #want < 2 - primaries then
      want[#want + 1] = "Mining or Herbalism"
    end
    while #want > 2 - primaries do
      table.remove(want)
    end
    if #want > 0 then
      lines[#lines + 1] = "Free profession slot: " .. table.concat(want, " + ") ..
        " pays while you level (you kill beasts anyway; leather, ore and herbs sell on the auction house)."
    end
  end
  local names = {}
  for name in pairs(profs) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local p = profs[name]
    local nx = M.NextRank(name, p.rank, p.max, level)
    if nx and nx.ready then
      lines[#lines + 1] = string.format("Train %s %s now (%s): %d/%d, it raises the cap to %d.", nx.rank, name, M.Short(nx.cost), p.rank, p.max, nx.cap)
    elseif nx and p.rank >= p.max and p.max > 0 then
      lines[#lines + 1] = string.format("%s is capped at %d; %s %s.", name, p.max, nx.rank, nx.why)
    end
  end
  return lines
end

M.HOLD = { Leather = true, Herb = true, ["Metal & Stone"] = true, Cloth = true }
M.HOLD_SUB = { [6] = "Leather", [9] = "Herb", [7] = "Metal & Stone", [5] = "Cloth" }

-- Leather / herb / ore / cloth stacks in your bags, dearest first.
function M.HoldList(bags)
  local out = {}
  for _, it in ipairs(bags or Core.Bags() or {}) do
    local info = M.Info(it.id) or { id = it.id, price = it.price, classID = it.classID, subType = it.subType, name = it.name, quality = it.quality }
    local kind = (info.classID == 7) and (M.HOLD[info.subType] and info.subType or M.HOLD_SUB[info.subclassID or -1]) or nil
    if kind then
      local v = M.Value(info, it.count)
      out[#out + 1] = { name = info.name or it.name, count = v.count, kind = kind, ah = v.ah, vendor = v.vendor, best = v.best }
    end
  end
  table.sort(out, function(a, b) return a.best > b.best end)
  return out
end

local told = {}
function M.CheckProfs(quiet)
  if not M.On("prof") then
    return {}
  end
  local lines = M.ProfTips(M.Professions(), Core.P.level or 1)
  if quiet then
    return lines
  end
  for _, l in ipairs(lines) do
    local key = l:match("^Train (%a+ %a+)") or (l:match("^Free profession") and ((Core.P.level or 1) >= 5) and "free")
    if key and not told[key] then
      told[key] = true
      if key == "free" then
        Core.Say(GOLDC .. "Gold tip|r: " .. l)
      elseif not (Nock.Alerts and Nock.Alerts:Fire("gold.train", { text = l }, { key = "gold.train." .. key })) then
        Core.Say(l)
      end
    end
  end
  return lines
end
M.told = told

Core.On("SKILL_LINES_CHANGED", "gold", function()
  if Core.Throttle("gold.skills", 5) then
    M.CheckProfs()
  end
end)
Core.On("PLAYER_LEVEL_UP", "gold", function()
  if C_Timer and C_Timer.After then
    C_Timer.After(2, function() M.CheckProfs() end)
  end
end)

-- Vendor ammo ------------------------------------------------------------------------------

function M.AmmoType()
  local link = GetInventoryItemLink and Core.Call(GetInventoryItemLink, "player", 18)
  local info = link and M.Info(link)
  local sub = info and info.subType or ""
  if sub:find("Gun") then
    return "Bullet"
  elseif sub:find("Bow") or sub:find("Crossbow") then
    return "Arrow"
  end
  return nil
end

-- Best ammo among what this vendor sells: offers = { { id, price (per stack), qty } }.
-- -> best (most damage you can use), cheaper (cheaper but weaker, if any). Pure (tested).
function M.PickAmmo(offers, kind, level)
  local data = {}
  for _, a in ipairs((Nock.Data and Nock.Data.Gold and Nock.Data.Gold.Ammo) or {}) do
    data[a[1]] = a
  end
  local usable = {}
  for _, o in ipairs(offers or {}) do
    local a = data[o.id]
    if a and a[3] == kind and a[4] <= (level or 1) then
      usable[#usable + 1] = { id = o.id, name = a[2], level = a[4], price = o.price or a[5], qty = o.qty or a[6], dmg = a[7] }
    end
  end
  if #usable == 0 then
    return nil
  end
  table.sort(usable, function(x, y)
    if x.dmg ~= y.dmg then return x.dmg > y.dmg end
    return x.price < y.price
  end)
  local best = usable[1]
  local cheaper
  for i = 2, #usable do
    if usable[i].price < best.price then
      cheaper = usable[i]
      break
    end
  end
  return best, cheaper
end

function M.MerchantOffers()
  local out = {}
  local n = GetMerchantNumItems and tonumber(Core.Call(GetMerchantNumItems)) or 0
  for i = 1, n do
    local id = GetMerchantItemID and Core.Call(GetMerchantItemID, i)
    if not id and GetMerchantItemLink then
      local l = Core.Call(GetMerchantItemLink, i)
      id = l and tonumber(tostring(l):match("item:(%d+)"))
    end
    local ok, _, _, price, qty = pcall(GetMerchantItemInfo or function() end, i)
    if id then
      out[#out + 1] = { id = tonumber(id), price = ok and tonumber(price) or nil, qty = ok and tonumber(qty) or nil }
    end
  end
  return out
end

function M.AmmoTip()
  local kind = M.AmmoType()
  if not kind then
    return nil
  end
  local best, cheaper = M.PickAmmo(M.MerchantOffers(), kind, Core.P.level or 1)
  if not best then
    return nil
  end
  local line = string.format("Best %s here for you: %s, %s per %d (%g damage).", kind:lower() .. "s", best.name, M.Short(best.price), best.qty, best.dmg)
  if cheaper then
    line = line .. string.format(" %s is cheaper (%s) but weaker (%g).", cheaper.name, M.Short(cheaper.price), cheaper.dmg)
  end
  return line
end

Core.On("MERCHANT_SHOW", "gold", function()
  if not M.On("fund") then
    return
  end
  local line = M.AmmoTip()
  if line then
    M.lastAmmo = line
    Core.Say(line)
  end
end)

-- Hunter trainer: ranks that can wait --------------------------------------------------------

-- services = { { name, rank (number), cost } } available now. A rank above 1 of
-- a hunter spell that is on none of your Nock tiles can wait. Pure (tested).
function M.CanWait(services, onBar)
  local hunter = {}
  for _, r in ipairs((Nock.Data and Nock.Data.TrainerSpells) or {}) do
    hunter[r[2]] = true
  end
  local out = {}
  for _, s in ipairs(services or {}) do
    if hunter[s.name] and (s.rank or 1) > 1 and not onBar(s.name) then
      out[#out + 1] = s
    end
  end
  return out
end

function M.TrainerServices()
  local out = {}
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then
    return out
  end
  local n = tonumber(Core.Call(GetNumTrainerServices)) or 0
  for i = 1, n do
    local ok, name, sub, cat = pcall(GetTrainerServiceInfo, i)
    if ok and name and cat == "available" then
      local cost = GetTrainerServiceCost and Core.Call(GetTrainerServiceCost, i)
      out[#out + 1] = { name = name, rank = tonumber(tostring(sub or ""):match("(%d+)")) or 1, cost = tonumber(cost) or 0 }
    end
  end
  return out
end

Core.On("TRAINER_SHOW", "gold", function()
  if not M.On("fund") or (IsTradeskillTrainer and Core.Call(IsTradeskillTrainer)) then
    return
  end
  local wait = M.CanWait(M.TrainerServices(), function(n) return Nock.TileFor and Nock.TileFor(n) ~= nil end)
  if #wait == 0 then
    return
  end
  local parts, total = {}, 0
  for _, s in ipairs(wait) do
    parts[#parts + 1] = string.format("%s R%d (%s)", s.name, s.rank, M.Short(s.cost))
    total = total + s.cost
  end
  M.lastTrainer = "Can wait if gold is tight (not on your Nock bars): " .. table.concat(parts, ", ") .. " — " .. M.Short(total) .. "."
  Core.Say(M.lastTrainer)
end)

-- Skinning and coin camps on the maps ------------------------------------------------------------

M.BAND_DOWN, M.BAND_UP = 3, 2
function M.CampInBand(lo, hi, level)
  return hi >= level - M.BAND_DOWN and lo <= level + M.BAND_UP
end

local kinds = {}
local function CampTip(e)
  local c = e.data
  local lines = {}
  lines[#lines + 1] = string.format("%d spawn spots, level %d-%d", c[7], c[5], c[6])
  lines[#lines + 1] = table.concat(c[8], ", ")
  if c[1] == "skin" then
    lines[#lines + 1] = "Skinnable beasts (Skinning: leather and hides)"
  end
  if c[9] then
    lines[#lines + 1] = "About " .. Core.Money(c[9]) .. " coin per kill"
  end
  lines[#lines + 1] = "|cff8a8a8aClassic data (QuestieDB / CMaNGOS); Forever may differ|r"
  return lines
end

function M.AddPins()
  if kinds.skin or not (Nock.Pins and Nock.Pins.AddKind) then
    return
  end
  local TEX = "Interface\\AddOns\\Nock\\Media\\Textures\\pins\\"
  local function filter(e)
    if not M.On("pins") then
      return false
    end
    return M.CampInBand(e.data[5], e.data[6], Core.P.level or 1)
  end
  kinds.skin = Nock.Pins.AddKind({ id = "goldskin", label = "Skinning camps", role = "Skinning camp", tex = TEX .. "pin_skin",
    color = { 0.80, 0.62, 0.40 }, filter = filter, tip = CampTip })
  kinds.coin = Nock.Pins.AddKind({ id = "goldcoin", label = "Coin camps", role = "Coin camp", tex = TEX .. "pin_coin",
    color = { 1.00, 0.83, 0.30 }, filter = filter, tip = CampTip })
  local rows = {}
  for _, c in ipairs((Nock.Data and Nock.Data.Gold and Nock.Data.Gold.Camps) or {}) do
    rows[#rows + 1] = { kind = kinds[c[1]], fac = "AH", map = c[2], x = c[3] / 100, y = c[4] / 100,
      name = (c[1] == "skin" and "Skinning camp" or "Coin camp"), title = c[8][1], data = c }
  end
  Nock.Pins.AddEntries(rows)
end
M.kinds = kinds

Core.On("PLAYER_LOGIN", "gold", function()
  M.AddPins()
end)
Core.On("PLAYER_ENTERING_WORLD", "gold", function()
  M.AddPins()
  if not M.session.at then
    M.ResetSession()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(8, function() M.CheckProfs() end)
  end
end)
Core.On("PLAYER_MONEY", "gold", function()
  M.OnMoney()
  if Nock.Dash and Nock.Dash.Soon then
    Nock.Dash.Soon()
  end
end)

-- Slash and Field Kit ------------------------------------------------------------------------------

local function OnOff(v)
  return v and "on" or "off"
end

function M.StatusLines()
  local s = M.Session()
  local out = {}
  out[#out + 1] = string.format("This session: earned %s, spent %s (net %s%s)%s.", M.Short(s.earned), M.Short(s.spent),
    s.net >= 0 and "+" or "-", M.Short(math.abs(s.net)), s.perHour and (", " .. M.Short(s.perHour) .. " per hour") or "")
  local b = M.BagValue()
  out[#out + 1] = string.format("Bags: %s at a vendor%s.", M.Short(b.vendor),
    b.ah and (", " .. M.Short(b.ah) .. " at auction (Auctionator)") or (M.HasAuctionator() and "" or " (install Auctionator for auction prices)"))
  if #b.keep > 0 then
    local parts = {}
    for i = 1, math.min(5, #b.keep) do
      local k = b.keep[i]
      parts[#parts + 1] = string.format("%s%s %s", k.name or "?", k.count > 1 and (" x" .. k.count) or "", M.Short(k.best))
    end
    out[#out + 1] = "Keep and sell: " .. table.concat(parts, ", ") .. (#b.keep > 5 and string.format(" (+%d more)", #b.keep - 5) or "")
  end
  local f = M.Fund()
  if f.target then
    out[#out + 1] = string.format("Mount fund: %s of %s (%d%%), %s to go — %s.", M.Short(f.have), M.Short(f.target), math.floor(f.pct * 100), M.Short(f.left), f.source)
  end
  for _, l in ipairs(M.CheckProfs(true)) do
    out[#out + 1] = l
  end
  local hold = M.HoldList()
  if #hold > 0 then
    local parts = {}
    for i = 1, math.min(4, #hold) do
      local h = hold[i]
      parts[#parts + 1] = string.format("%s x%d %s %s", h.name or "?", h.count, M.Short(h.best), h.ah and "auction" or "vendor")
    end
    out[#out + 1] = "Worth holding: " .. table.concat(parts, ", ")
  end
  return out
end

function M:Slash(rest)
  rest = strtrim and strtrim(rest or "") or (rest or "")
  local word, arg = rest:match("^(%S+)%s*(.-)$")
  word = word and word:lower()
  if word and PARTS[word] then
    local v
    if arg == "on" then v = true elseif arg == "off" then v = false else v = Core.Get("gold", word) == false end
    Core.Set("gold", word, v)
    if Nock.Dash and Nock.Dash.Soon then Nock.Dash.Soon() end
    return Core.Say(PARTS[word] .. ": " .. OnOff(v))
  elseif word == "threshold" then
    local g = tonumber(arg)
    if not g or g < 0 then
      return Core.Say("Keep tag and loot alert at " .. M.Short(M.Threshold()) .. ". Change it with /nock gold threshold <gold>, e.g. 0.5.")
    end
    Core.Set("gold", "threshold", math.floor(g * 10000 + 0.5))
    return Core.Say("Keep tag and loot alert at " .. M.Short(M.Threshold()) .. ".")
  elseif word == "mount" then
    local g = tonumber(arg)
    if arg == "auto" or arg == "reset" then
      Core.Set("gold", "mount", nil)
    elseif g and g > 0 then
      Core.Set("gold", "mount", math.floor(g * 10000 + 0.5))
    end
    local t, src = M.MountTarget()
    return Core.Say("Mount fund target: " .. (t and M.Short(t) or "none") .. " (" .. src .. ").")
  elseif word == "reset" then
    M.ResetSession()
    return Core.Say("Gold session restarted.")
  end
  for _, l in ipairs(M.StatusLines()) do
    Core.Say(l)
  end
  local parts = {}
  for _, k in ipairs({ "value", "drops", "pins", "dash", "prof", "fund" }) do
    parts[#parts + 1] = k .. " " .. OnOff(Core.Get("gold", k) ~= false)
  end
  Core.Say(table.concat(parts, "  ·  ") .. "  ·  keep at " .. M.Short(M.Threshold()))
end

function M:Report()
  return M.StatusLines()
end
