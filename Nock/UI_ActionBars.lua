--[[
  Nock 3.0.4: hide and restore the default action bars on WoW Forever (1.60.1).

  Forever's bars are the modern Edit Mode frames (MainActionBar, PetActionBar,
  StanceBar, MultiBar*), not only the old MainMenuBar names. Calling :Hide()
  from addon code, hooking Show / OnShow / UpdateVisibility, or re-parenting
  a bar taints its buttons. On this client a tainted ActionButton OnEvent then
  throws when Blizzard passes secret start/duration values to SetCooldown.

  We hide only with RegisterStateDriver(frame, "visibility", "hide"), out of
  combat, each driver registered exactly once. 3.0.1 called RegisterStateDriver
  again from Rehide, which ran inside MultiActionBar_Update / Edit Mode hooks
  when a bar's Hide snapped frames, and overflowed the C stack
  (BreakSnappedFrames). Hooks never call RegisterStateDriver; they schedule a
  deferred ensure. A re-entrancy guard blocks any hide that re-enters itself.
  PossessActionBar is left alone (its Hide was the first overflow). Never
  touch OverrideActionBar or VehicleActionBar.

  3.0.4 does not move or reparent StatusTrackingBarManager, BagsBar or
  MicroMenu. Those SetParent / SetPoint / EnableMouse / SetPoint hooks in
  3.0.3 tainted protected paths ("Interface action failed because of an
  AddOn") and left the XP manager as a thin bar at the top of the screen.
  Blizzard's XP bar is hidden with the same register-once state driver.
  Nock draws its own experience bar under the utility row. Bags and the
  micro menu stay at Blizzard's default position. Every change is pcall'd,
  runs only out of combat, and can be undone from Options.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local A = {}
Nock.ActionBars = A

-- Forever (Camelot / Edit Mode) names first; older names kept as fallbacks.
-- Do not list OverrideActionBar or VehicleActionBar: hiding or hooking them
-- taints their cooldown updates (OverrideActionBarButton*Cooldown).
local BAR_NAMES = {
  "MainActionBar", "MainMenuBar", "MainMenuBarArtFrame", "MainMenuBarOverlayFrame",
  "MainMenuBarMaxLevelBar", "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
  "MainMenuBarEndCaps",
  "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
  "MultiBar5", "MultiBar6", "MultiBar7",
  "PetActionBar", "PetActionBarFrame",
  "StanceBar", "ShapeshiftBarFrame",
  "BonusActionBarFrame",
  -- PossessActionBar is an Edit Mode bar whose Hide runs BreakSnappedFrames
  -- and, in 3.0.1, re-entered our RegisterStateDriver (C stack overflow).
}

-- Other bar addons that would otherwise leave a second row on the screen.
local ADDON_BAR_NAMES = {
  "BT4Bar1", "BT4Bar2", "BT4Bar3", "BT4Bar4", "BT4Bar5",
  "BT4Bar6", "BT4Bar7", "BT4Bar8", "BT4Bar9", "BT4Bar10",
  "BT4BarPet", "BT4BarStance", "BT4BarBagBar",
  "DominosFrame1", "DominosFrame2", "DominosFrame3", "DominosFrame4", "DominosFrame5",
  "DominosFrame6", "DominosFrame7", "DominosFrame8", "DominosFrame9", "DominosFrame10",
  "DominosFramepet", "DominosFramestance",
  "ElvUI_Bar1", "ElvUI_Bar2", "ElvUI_Bar3", "ElvUI_Bar4", "ElvUI_Bar5",
  "ElvUI_Bar6", "ElvUI_BarPet", "ElvUI_StanceBar",
}

-- Hide Blizzard's XP / rep bar with the same taint-safe driver. Never
-- SetParent, SetPoint or EnableMouse on these (or on BagsBar / MicroMenu).
local XP_NAMES = {
  "StatusTrackingBarManager",
  "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
  "MainMenuExpBar", "ReputationWatchBar",
}

local applied = false
local pending = nil -- true = hide, false = restore
local hookedManager = false
local hookedMulti = false
local driven = {} -- [frame] = true after we register a visibility driver
local hiding = false -- re-entrancy: a bar's Hide must not call us again
local ensureQueued = false
local ClearDriver

local function InCombat()
  return InCombatLockdown and InCombatLockdown() or false
end

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

function A.Enabled()
  return DB().hideBlizzardBars ~= false
end

function A.IsApplied()
  return applied and true or false
end

-- Nock draws its own XP bar inside the overlay, so the bow only needs a
-- small gap from the bottom edge of the screen.
function A.XPHeight()
  return 0
end

function A.BottomOffset()
  return 10
end

local function F(name)
  return name and _G[name]
end

local function SecureHide(frame)
  if not frame or driven[frame] then
    return
  end
  if InCombat() then
    pending = true
    return
  end
  pcall(function()
    frame.isShownExternal = false
    if RegisterStateDriver then
      -- Mark first so a Hide -> hook -> Rehide during this call is a no-op.
      driven[frame] = true
      RegisterStateDriver(frame, "visibility", "hide")
    elseif frame.Hide then
      -- Hide() is enough as a last resort when the state-driver API is missing.
      -- Do not probe HideBase: some environments invent methods for unknown keys.
      driven[frame] = true
      frame:Hide()
    end
  end)
end

function ClearDriver(frame)
  if not frame then
    return
  end
  driven[frame] = nil
  if UnregisterStateDriver then
    pcall(UnregisterStateDriver, frame, "visibility")
  end
end

-- Hooks must not call RegisterStateDriver. If a bar is later shown or a
-- driver is missing, schedule a next-tick ensure that no-ops while a hide
-- is already in progress (C_Timer.After is immediate in our tests).
local function ScheduleEnsure()
  if ensureQueued or hiding or not applied or not A.Enabled() or InCombat() then
    return
  end
  ensureQueued = true
  local function run()
    ensureQueued = false
    if hiding or not applied or not A.Enabled() or InCombat() then
      return
    end
    A.Rehide()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, run)
  else
    run()
  end
end

local function HideBar(frame)
  SecureHide(frame)
end

local function HookManager()
  if hookedManager or not hooksecurefunc then
    return
  end
  hookedManager = true
  local edm = F("EditModeManagerFrame")
  if edm and edm.UpdateActionBarLayout then
    pcall(hooksecurefunc, edm, "UpdateActionBarLayout", function()
      -- Do not RegisterStateDriver from this hook: Hide of an Edit Mode
      -- bar can run this while a driver is still being registered.
      ScheduleEnsure()
    end)
  end
end

local function HookMulti()
  if hookedMulti or not hooksecurefunc or not MultiActionBar_Update then
    return
  end
  hookedMulti = true
  pcall(hooksecurefunc, "MultiActionBar_Update", function()
    -- Deferred and guarded: a synchronous Rehide here is what overflowed
    -- the C stack in 3.0.1 when RegisterStateDriver called Hide.
    ScheduleEnsure()
  end)
end

local function EachBar(fn)
  for _, name in ipairs(BAR_NAMES) do
    local frame = F(name)
    if frame then
      fn(frame)
    end
  end
  for _, name in ipairs(ADDON_BAR_NAMES) do
    local frame = F(name)
    if frame then
      fn(frame)
    end
  end
end

local function EachXP(fn)
  for _, name in ipairs(XP_NAMES) do
    local frame = F(name)
    if frame then
      fn(frame)
    end
  end
end

local function ShowFrame(frame)
  pcall(function()
    frame._nockRestoring = true
    frame.isShownExternal = true
    ClearDriver(frame)
    if frame.SetAlpha then
      frame:SetAlpha(1)
    end
    if frame.Show then
      frame:Show()
    end
    frame._nockRestoring = nil
  end)
end

function A.Rehide()
  if not A.Enabled() or not applied or InCombat() or hiding then
    return
  end
  hiding = true
  pcall(EachBar, SecureHide)
  pcall(EachXP, SecureHide)
  hiding = false
end

local function ApplyHide()
  if InCombat() then
    pending = true
    return false
  end
  if hiding then
    return false
  end
  hiding = true
  local ok, err = pcall(function()
    EachBar(HideBar)
    EachXP(SecureHide)
    HookManager()
    HookMulti()
    if UIParent_ManageFramePositions then
      pcall(UIParent_ManageFramePositions)
    end
    applied = true
    pending = nil
    -- Fill in any bar that was not driven on the first pass. Already-driven
    -- frames are skipped, so this cannot re-enter RegisterStateDriver.
    EachBar(SecureHide)
    EachXP(SecureHide)
  end)
  hiding = false
  if not ok then
    if Nock.NoteError then
      Nock.NoteError("ActionBars.ApplyHide", err)
    end
    return false
  end
  return true
end

local function ApplyRestore()
  if InCombat() then
    pending = false
    return false
  end
  applied = false
  EachBar(ShowFrame)
  EachXP(ShowFrame)
  if UIParent_ManageFramePositions then
    pcall(UIParent_ManageFramePositions)
  end
  pending = nil
  return true
end

local function Redock()
  if InCombat() or DB().barPos then
    return
  end
  if Nock.ResetBarPosition then
    Nock.ResetBarPosition()
  end
end

function A.Apply()
  if A.Enabled() then
    local ok = ApplyHide()
    if ok then
      Redock()
    end
    return ok
  end
  if applied then
    local ok = ApplyRestore()
    if ok then
      Redock()
    end
    return ok
  end
  return true
end

function A.SetEnabled(on)
  DB().hideBlizzardBars = on and true or false
  if InCombat() then
    pending = on and true or false
    return false, "queued"
  end
  A.Apply()
  return true
end

function A.FlushPending()
  if pending == nil or InCombat() then
    return
  end
  if pending then
    ApplyHide()
    Redock()
  else
    ApplyRestore()
    Redock()
  end
end

-- Re-apply after zoning, combat, or anything that tends to bring the bars back.
-- Rehide only re-registers the state driver; it does not hook or Hide() a bar.
local ev = CreateFrame("Frame", "NockActionBarsEvent")
for _, e in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
  "PET_BAR_UPDATE", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED",
  "SETTINGS_LOADED",
}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    A.FlushPending()
    if A.Enabled() then
      A.Rehide()
    end
    return
  end
  if InCombat() then
    if A.Enabled() then
      pending = true
    end
    return
  end
  if A.Enabled() then
    if applied then
      A.Rehide()
      if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" or event == "SETTINGS_LOADED" then
        ApplyHide()
        Redock()
      end
    else
      ApplyHide()
      Redock()
    end
  end
end)
