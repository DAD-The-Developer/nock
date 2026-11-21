--[[
  Nock 3.4.0 hunter tool: kill and XP tracker.

  A small movable readout (Shift-drag; /nock tracker reset):
    Leveling:  "14 kills to 25  ·  18.2k XP/h  ·  42m to level"
    Level 60:  "Session 1h 05m  ·  38g 12s/h  ·  212 kills"
  Mobs-to-level uses your last 10 kills' XP (rested bonus included), XP per
  hour counts the session since login or /nock tracker reset. Kills come
  from "You have slain" messages, so group kills you tag count too.

  Endgame mode switches to gold per hour and kills, or hides the readout
  (/nock tracker hide60). Positions and the choice persist.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "tracker",
  name = "Kill and XP tracker",
  desc = "Mobs to level, XP per hour, time to level; gold per hour and kills at 60.",
  cmd = { "tracker", "kills", "xph" },
  pvpQuiet = true,
  defaults = { on = true, show = true, hide60 = false },
  options = {
    { key = "show", label = "Show the tracker readout on screen" },
    { key = "hide60", label = "Hide the readout at level 60 (no gold per hour)" },
  },
  help = { "/nock tracker — kills to level, XP/hour; gold/hour at 60   /nock tracker unlock | lock | reset | hide60" },
})

local S = { start = nil, xp = 0, kills = 0, money0 = nil, recent = {}, lastXP = nil, lastMax = nil }
M.session = S

local function Reset()
  S.start = Core.Now()
  S.xp, S.kills, S.xpKills = 0, 0, 0
  S.money0 = Core.Number(GetMoney and GetMoney())
  S.recent = {}
  S.lastXP = Core.Number(UnitXP and UnitXP("player"))
  S.lastMax = Core.Number(UnitXPMax and UnitXPMax("player"))
end
M.Reset = Reset

-- Average of the recent kill XP list (pure).
function M.Average(list)
  if not list or #list == 0 then
    return nil
  end
  local sum = 0
  for _, v in ipairs(list) do
    sum = sum + v
  end
  return sum / #list
end

-- Leveling numbers (pure, tested).
function M.Leveling(cur, max, avgKill, xpGained, seconds)
  local left = math.max(0, (max or 0) - (cur or 0))
  local kills = (avgKill and avgKill > 0) and math.ceil(left / avgKill) or nil
  local perHour = (seconds and seconds >= 60) and (xpGained / seconds * 3600) or nil
  local tolevel = (perHour and perHour > 0) and (left / perHour * 3600) or nil
  return kills, perHour, tolevel
end

function M.GoldPerHour(copper, seconds)
  if not seconds or seconds < 60 then
    return nil
  end
  return copper / seconds * 3600
end

local function NoteKillXP(amount)
  table.insert(S.recent, amount)
  while #S.recent > 10 do
    table.remove(S.recent, 1)
  end
end

Core.On("CHAT_MSG_COMBAT_XP_GAIN", "tracker", function(_, msg)
  if type(msg) ~= "string" or Core.IsSecret(msg) then
    return
  end
  -- "Kobold Vermin dies, you gain 45 experience. (+22 exp Rested bonus)"
  local amount = tonumber(msg:match("you gain (%d+) experience"))
  if amount and msg:find("dies", 1, true) then
    NoteKillXP(amount) -- already includes any rested bonus
    S.xpKills = (S.xpKills or 0) + 1
  end
end)

Core.On("CHAT_MSG_COMBAT_HOSTILE_DEATH", "tracker", function(_, msg)
  if type(msg) ~= "string" or Core.IsSecret(msg) then
    return
  end
  if msg:find("You have slain", 1, true) then
    S.kills = S.kills + 1
  end
end)

Core.On("PLAYER_XP_UPDATE", "tracker", function()
  local cur = Core.Number(UnitXP and UnitXP("player"))
  local max = Core.Number(UnitXPMax and UnitXPMax("player"))
  if not (cur and max) then
    return
  end
  if S.lastXP then
    local delta = cur - S.lastXP
    if delta < 0 and S.lastMax then
      delta = (S.lastMax - S.lastXP) + cur -- levelled up
    end
    if delta > 0 then
      S.xp = S.xp + delta
    end
  end
  S.lastXP, S.lastMax = cur, max
end)

-- Readout ---------------------------------------------------------------------------

local frame
local function Pos()
  _G.NockCharDB = _G.NockCharDB or {}
  return _G.NockCharDB
end

-- 3.4.1: top centre by default, well away from the bow bar and its rows.
local DEFAULT = { "TOP", "TOP", 0, -34 }

local function Make()
  if frame then
    return frame
  end
  -- The 3.4.0 spot sat on top of the bar stack; forget it.
  Pos().trackerPos = nil
  local f = CreateFrame("Frame", "NockTrackerFrame", UIParent)
  f:SetSize(380, 30)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.03, 0.07, 0.06, 0.72)
  local top = f:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(2)
  top:SetColorTexture(0.25, 0.89, 0.60, 0.8)
  -- Grip on the left: the visible handle for dragging.
  local grip = f:CreateFontString(nil, "OVERLAY")
  local T = _G.NockTheme
  local function font(fs, size)
    if T and T.EnsureFont then
      T.EnsureFont(fs, size, "OUTLINE")
    else
      pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
  end
  font(grip, 15)
  grip:SetPoint("LEFT", 8, 0)
  grip:SetText("::")
  grip:SetTextColor(0.40, 0.75, 0.58)
  f.text = f:CreateFontString(nil, "OVERLAY")
  font(f.text, 15)
  f.text:SetPoint("LEFT", 24, 0)
  f.text:SetJustifyH("LEFT")
  if f.text.SetWordWrap then
    f.text:SetWordWrap(false)
  end
  f.text:SetTextColor(0.92, 0.97, 0.94)
  local mk = Core.MakeMovable or function() end
  mk(f, "tracker", "Kill / XP tracker", DEFAULT, {
    mouse = true, strata = "HIGH", level = 20,
    free = function() return Core.Get("tracker", "unlocked") == true end,
  })
  f:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText("Nock tracker", 1, 1, 1)
      for _, line in ipairs(M:Report()) do
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
      end
      GameTooltip:AddLine("Shift-drag to move (or /nock tracker unlock).  /nock tracker reset", 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  frame = f
  M.frame = f
  return f
end

-- XP from one same-level mob (Classic formula 45 + 5 x level), doubled
-- while rested. Used until you have real kills to average.
function M.EstimateKillXP(level, rested)
  local xp = 45 + 5 * (level or 1)
  if rested and rested > 0 then
    xp = xp * 2
  end
  return xp
end

local function Kills()
  return math.max(S.kills or 0, S.xpKills or 0)
end
M.Kills = Kills

function M.Line()
  local secs = Core.Now() - (S.start or Core.Now())
  if Core.IsEndgame() then
    local money = Core.Number(GetMoney and GetMoney()) or 0
    local gph = M.GoldPerHour(money - (S.money0 or money), secs)
    local k = Kills()
    return string.format("Session %s  ·  %s  ·  %d kill%s", Core.Duration(secs),
      gph and (Core.Money(math.max(0, gph)) .. "/h") or "gold/h after a minute", k, k == 1 and "" or "s")
  end
  local cur = Core.Number(UnitXP and UnitXP("player")) or 0
  local max = Core.Number(UnitXPMax and UnitXPMax("player")) or 0
  local avg = M.Average(S.recent)
  local estimated = false
  if not avg then
    avg = M.EstimateKillXP(Core.P.level, Core.Number(GetXPExhaustion and GetXPExhaustion()))
    estimated = true
  end
  local kills, perHour, tolevel = M.Leveling(cur, max, avg, S.xp, secs)
  return string.format("%s%s kills to %d  ·  %s  ·  %s",
    estimated and "about " or "", kills and tostring(kills) or "?", Core.P.level + 1,
    perHour and (Core.Short(perHour) .. " XP/h") or "XP/h and time to level",
    tolevel and (Core.Duration(tolevel) .. " to level") or "after a few minutes")
end

function M.Paint()
  local want = Core.Enabled("tracker") and Core.Get("tracker", "show") ~= false
    and not (Core.IsEndgame() and Core.Get("tracker", "hide60") == true)
  if not want then
    if frame then
      frame:Hide()
    end
    return
  end
  local f = Make()
  f.text:SetText(M.Line())
  local w = f.text.GetStringWidth and tonumber((f.text:GetStringWidth())) or nil
  if not w or w < 50 then
    w = string.len(f.text:GetText() or "") * 8
  end
  f:SetWidth(math.max(260, w + 40))
  f:Show()
end

function M:Init()
  Reset()
  M.Paint()
end

function M:Refresh()
  M.Paint()
end

function M:OnProfile()
  M.Paint()
end

Core.Every("tracker", 2, function()
  M.Paint()
end)

function M:Slash(rest)
  if rest == "reset" then
    Reset()
    Pos().trackerPos = nil
    if Pos().positions then
      Pos().positions.tracker = nil
    end
    Core.Set("tracker", "unlocked", false)
    Core.PlaceMover("tracker")
    Core.ShowMoverOutline("tracker", false)
    M.Paint()
    return Core.Say("Tracker session reset and moved back to the top centre.")
  elseif rest == "unlock" then
    Core.Set("tracker", "unlocked", true)
    M.Paint()
    Core.ShowMoverOutline("tracker", true)
    return Core.Say("Tracker unlocked: drag it anywhere, then /nock tracker lock.")
  elseif rest == "lock" then
    Core.Set("tracker", "unlocked", false)
    Core.ShowMoverOutline("tracker", false)
    return Core.Say("Tracker locked. Shift-drag still moves it.")
  elseif rest == "hide60" then
    Core.Set("tracker", "hide60", not (Core.Get("tracker", "hide60") == true))
    return Core.Say("Tracker at 60: " .. (Core.Get("tracker", "hide60") and "hidden" or "gold per hour"))
  elseif rest == "show" or rest == "hide" then
    Core.Set("tracker", "show", rest == "show")
    return Core.Say("Tracker readout " .. (rest == "show" and "shown." or "hidden."))
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local secs = Core.Now() - (S.start or Core.Now())
  local out = { M.Line() }
  if not Core.IsEndgame() then
    local avg = M.Average(S.recent)
    out[#out + 1] = string.format("Session %s: %s XP, %d kills%s", Core.Duration(secs), Core.Short(S.xp), Kills(),
      avg and string.format(", about %s XP a kill", Core.Short(avg)) or "")
    local rested = Core.Number(GetXPExhaustion and GetXPExhaustion())
    if rested and rested > 0 then
      out[#out + 1] = string.format("Rested: %s bonus XP left", Core.Short(rested))
    end
  end
  return out
end

function _G.Nock_ToggleTracker()
  M:Slash(Core.Get("tracker", "show") == false and "show" or "hide")
end
