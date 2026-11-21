--[[
  Nock 3.4.1: one place to move every Nock frame.

  /nock unlock       every movable Nock frame shows a green outline and its
                     name; drag any of them anywhere (out of combat)
  /nock lock         back to normal
  /nock reset positions   every frame back to its default spot
  Also: Options > Hunter tools > "Unlock frames", and the unbound keybind
  "Unlock or lock all Nock frames".

  Frames register with Core.MakeMovable(frame, key, label, default, opts).
  Positions are saved per character in NockCharDB.positions[key]. Readouts
  that sit over the game world (range, PvP, alerts) only take the mouse
  while unlocked, so they never block clicks or camera turning. The tracker
  can also be Shift-dragged any time. The quiver counter and the threat
  meter keep their own systems; unlock / lock / reset drive those too.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local movers = {}
local order = {}
Core.movers = movers

local function DB()
  _G.NockCharDB = _G.NockCharDB or {}
  local db = _G.NockCharDB
  if type(db.positions) ~= "table" then
    db.positions = {}
  end
  return db
end

function Core.Unlocked()
  local db = _G.NockCharDB
  return db and db.framesUnlocked == true or false
end

local function Combat()
  return InCombatLockdown and InCombatLockdown() or false
end

local function Place(m)
  local f = m.frame
  local p = DB().positions[m.key]
  f:ClearAllPoints()
  if type(p) == "table" and p[1] then
    f:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
  else
    local d = m.default
    f:SetPoint(d[1], UIParent, d[2] or d[1], d[3] or 0, d[4] or 0)
  end
end
Core.PlaceMover = function(key)
  if movers[key] then
    Place(movers[key])
  end
end

local function Save(m)
  local f = m.frame
  local a, _, b, x, y = f:GetPoint(1)
  if a then
    DB().positions[m.key] = { a, b or a, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
  end
end

local function Font(fs, size)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(fs, size, "OUTLINE")
  elseif fs.SetFont then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
  end
end

-- Green outline plus a name tag, shown only while unlocked.
local function Highlight(f, label)
  if f.nockMoverHL then
    return f.nockMoverHL
  end
  local hl = {}
  hl.fill = f:CreateTexture(nil, "OVERLAY")
  hl.fill:SetAllPoints()
  hl.fill:SetColorTexture(0.25, 0.89, 0.60, 0.18)
  local edges = {}
  for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0.30, 1.00, 0.62, 0.95)
    t:SetPoint(spec[1])
    t:SetPoint(spec[2])
    if spec[3] then
      t:SetHeight(2)
    else
      t:SetWidth(2)
    end
    edges[i] = t
  end
  hl.edges = edges
  hl.text = f:CreateFontString(nil, "OVERLAY")
  Font(hl.text, 13)
  hl.text:SetPoint("BOTTOM", f, "TOP", 0, 3)
  hl.text:SetText(label .. " — drag to move")
  hl.text:SetTextColor(0.79, 1.00, 0.88)
  function hl:SetShown(on)
    for _, t in ipairs({ self.fill, self.text, unpack(self.edges) }) do
      if on then
        t:Show()
      else
        t:Hide()
      end
    end
  end
  hl:SetShown(false)
  f.nockMoverHL = hl
  return hl
end

local function MouseFor(m)
  local want = m.opts.mouse or Core.Unlocked()
  if m.frame.EnableMouse then
    m.frame:EnableMouse(want and true or false)
  end
end

--[[ opts: mouse = true (always takes the mouse; Shift-drag works when locked),
  strata, level, preview = function(on) shows sample content while unlocked. ]]
function Core.MakeMovable(f, key, label, default, opts)
  opts = opts or {}
  local m = { frame = f, key = key, label = label, default = default, opts = opts }
  if not movers[key] then
    order[#order + 1] = key
  end
  movers[key] = m
  if f.SetMovable then
    f:SetMovable(true)
  end
  if f.SetClampedToScreen then
    f:SetClampedToScreen(true)
  end
  if opts.strata and f.SetFrameStrata then
    f:SetFrameStrata(opts.strata)
  end
  if opts.level and f.SetFrameLevel then
    f:SetFrameLevel(opts.level)
  end
  if f.RegisterForDrag then
    f:RegisterForDrag("LeftButton")
  end
  f:SetScript("OnDragStart", function(self)
    if Combat() then
      return
    end
    local free = opts.free and opts.free()
    if Core.Unlocked() or free or (opts.mouse and IsShiftKeyDown and IsShiftKeyDown()) then
      self.nockMoving = true
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    if self.nockMoving then
      self.nockMoving = nil
      self:StopMovingOrSizing()
      Save(m)
    end
  end)
  Highlight(f, label)
  Place(m)
  MouseFor(m)
  if Core.Unlocked() then
    f.nockMoverHL:SetShown(true)
    if opts.preview then
      pcall(opts.preview, true)
    end
  end
  return m
end

-- Frames Nock does not own here: quiver and threat meter.
local function QuiverFrame()
  return _G.NockQuiverFrame
end

local function SetOthers(unlocked)
  local db = DB()
  if unlocked then
    db.quiverLocked = false
  else
    db.quiverLocked = nil
  end
  local q = QuiverFrame()
  if q then
    Highlight(q, "Quiver"):SetShown(unlocked)
  end
  local T = Nock.Threat
  if T and T.SetLocked then
    pcall(T.SetLocked, not unlocked)
  end
end

function Core.SetUnlocked(on)
  on = on and true or false
  if on and Combat() then
    Core.Say("Leave combat first, then /nock unlock.")
    return false
  end
  DB().framesUnlocked = on
  for _, key in ipairs(order) do
    local m = movers[key]
    m.frame.nockMoverHL:SetShown(on)
    MouseFor(m)
    if m.opts.preview then
      pcall(m.opts.preview, on)
    end
  end
  SetOthers(on)
  Core.Say(on and "Nock frames unlocked: drag any outlined frame. /nock lock when done, /nock reset positions to undo."
    or "Nock frames locked. (The tracker and quiver still move with Shift-drag.)")
  if Nock.UI and Nock.UI.Refresh then
    pcall(Nock.UI.Refresh)
  end
  return true
end

function Core.ResetPositions()
  if Combat() then
    Core.Say("Leave combat first.")
    return false
  end
  DB().positions = {}
  for _, key in ipairs(order) do
    Place(movers[key])
  end
  if Nock.Quiver and Nock.Quiver.Reset then
    pcall(Nock.Quiver.Reset)
  end
  if Nock.Threat and Nock.Threat.ResetPos then
    pcall(Nock.Threat.ResetPos)
  end
  Core.Say("All Nock frames are back in their default spots.")
  return true
end

-- Show or hide one frame's outline (for per-frame unlock, e.g. the tracker).
function Core.ShowMoverOutline(key, on)
  local m = movers[key]
  if m and m.frame.nockMoverHL then
    m.frame.nockMoverHL:SetShown((on or Core.Unlocked()) and true or false)
  end
end

function _G.Nock_ToggleUnlock()
  Core.SetUnlocked(not Core.Unlocked())
end

-- Locked again on every login, so a forgotten unlock never leaves readouts
-- grabbing the mouse.
Core.On("PLAYER_LOGIN", "core", function()
  if Core.Unlocked() then
    DB().framesUnlocked = false
  end
  if Nock.Alerts and Nock.Alerts.EnsureStack then
    pcall(Nock.Alerts.EnsureStack)
  end
end)
-- Combat: stop drag mode for the world readouts (they must not take clicks).
Core.On("PLAYER_REGEN_DISABLED", "core", function()
  if Core.Unlocked() then
    Core.SetUnlocked(false)
  end
end)

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg)
    local m = string.lower(strtrim and strtrim(msg or "") or (msg or ""))
    if m == "unlock" or m == "move" then
      return Core.SetUnlocked(true)
    elseif m == "lock" then
      return Core.SetUnlocked(false)
    elseif m == "reset positions" or m == "resetpositions" or m == "reset frames" then
      return Core.ResetPositions()
    end
    baseSlash(msg)
    if m == "help" then
      Core.Say("/nock unlock | lock — move every Nock frame   /nock reset positions — put them all back")
    end
  end
end
