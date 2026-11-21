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
  help = { "/nock tracker — kills to level, XP/hour; gold/hour at 60   /nock tracker reset | hide60" },
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

local function Make()
  if frame then
    return frame
  end
  local f = CreateFrame("Frame", "NockTrackerFrame", UIParent)
  f:SetSize(360, 26)
  f:SetFrameStrata("LOW")
  local p = Pos().trackerPos
  if type(p) == "table" and p[1] then
    f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
  else
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
  end
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.03, 0.07, 0.06, 0.55)
  f.text = f:CreateFontString(nil, "OVERLAY")
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(f.text, 15, "OUTLINE")
  else
    pcall(f.text.SetFont, f.text, "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
  end
  f.text:SetPoint("CENTER")
  f.text:SetTextColor(0.92, 0.97, 0.94)
  if f.SetMovable then
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
      if IsShiftKeyDown and IsShiftKeyDown() and not (InCombatLockdown and InCombatLockdown()) then
        self:StartMoving()
      end
    end)
    f:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local a, _, b, x, y = self:GetPoint(1)
      Pos().trackerPos = { a, b, math.floor(x or 0), math.floor(y or 0) }
    end)
    f:SetScript("OnEnter", function(self)
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Nock tracker", 1, 1, 1)
        for _, line in ipairs(M:Report()) do
          GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
        end
        GameTooltip:AddLine("Shift-drag to move. /nock tracker reset", 0.6, 0.6, 0.6)
        GameTooltip:Show()
      end
    end)
    f:SetScript("OnLeave", function()
      if GameTooltip then
        GameTooltip:Hide()
      end
    end)
  end
  frame = f
  return f
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
    return string.format("Session %s  ·  %s/h  ·  %d kills", Core.Duration(secs), gph and Core.Money(math.max(0, gph)) or "—", Kills())
  end
  local cur = Core.Number(UnitXP and UnitXP("player")) or 0
  local max = Core.Number(UnitXPMax and UnitXPMax("player")) or 0
  local kills, perHour, tolevel = M.Leveling(cur, max, M.Average(S.recent), S.xp, secs)
  return string.format("%s kills to %d  ·  %s XP/h  ·  %s to level",
    kills and tostring(kills) or "?", Core.P.level + 1, perHour and Core.Short(perHour) or "—", tolevel and Core.Duration(tolevel) or "—")
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
  f:SetWidth(math.max(220, (f.text.GetStringWidth and f.text:GetStringWidth() or 300) + 24))
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
    if frame then
      frame:ClearAllPoints()
      frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    end
    M.Paint()
    return Core.Say("Tracker session and position reset.")
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
