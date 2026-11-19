--[[
  Nock 3.2: ways to open the window without typing /nock.
  - Escape (Game Menu) button, added taint-safe
  - A small movable launcher button (Shift-drag)
  The existing Open Nock keybind is renamed in Theme.lua.
]]

local Nock = _G.Nock
local UI = Nock and Nock.UI
if not Nock then
  return
end

local Launcher = {}
Nock.Launcher = Launcher

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function OpenWindow()
  if Nock.UI and Nock.UI.Show then
    Nock.UI.Show()
  elseif Nock_ToggleWindow then
    Nock_ToggleWindow()
  elseif Nock.Open then
    Nock:Open()
  end
end

-- Game Menu (Escape) -----------------------------------------------------------
-- Hook OnShow only. Do not hooksecurefunc protected functions, do not
-- replace other buttons' scripts, and do not call HideUIPanel from our
-- click — Hide the menu ourselves, then open Nock on the next tick so
-- the taint path is broken.

local menuButton
local menuBaseHeight
local menuExtra = 0

local function MenuButtonNamed(...)
  for i = 1, select("#", ...) do
    local b = _G[select(i, ...)]
    if b then
      return b
    end
  end
end

local function LayoutGameMenu()
  local menu = _G.GameMenuFrame
  local btn = menuButton
  if not (menu and btn) then
    return
  end
  -- Moving official buttons while locked down can taint logout. Skip
  -- the layout in combat; our button still exists and can be clicked
  -- if the menu is already up.
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  local after = MenuButtonNamed("GameMenuButtonAddons", "GameMenuButtonAddOns", "GameMenuButtonMacros", "GameMenuButtonOptions")
  local logout = MenuButtonNamed("GameMenuButtonLogout")
  if not after then
    return
  end
  btn:ClearAllPoints()
  btn:SetPoint("TOP", after, "BOTTOM", 0, -1)
  btn:SetWidth(after:GetWidth() or 144)
  btn:Show()
  if logout and logout ~= after then
    logout:ClearAllPoints()
    logout:SetPoint("TOP", btn, "BOTTOM", 0, -1)
  end
  if not menuBaseHeight then
    menuBaseHeight = menu:GetHeight() or 0
  end
  if menuExtra == 0 then
    menuExtra = (btn:GetHeight() or 24) + 2
  end
  if menuBaseHeight > 0 then
    menu:SetHeight(menuBaseHeight + menuExtra)
  end
end

local function CreateGameMenuButton()
  local menu = _G.GameMenuFrame
  if not menu or menuButton then
    return menuButton
  end
  local template = "GameMenuButtonTemplate"
  local ok, btn = pcall(CreateFrame, "Button", "GameMenuButtonNock", menu, template)
  if not ok or not btn then
    btn = CreateFrame("Button", "GameMenuButtonNock", menu, "UIPanelButtonTemplate")
  end
  menuButton = btn
  btn:SetText("Nock")
  btn:SetScript("OnClick", function()
    if PlaySound then
      pcall(PlaySound, "igMainMenuOption")
    end
    if menu.Hide then
      menu:Hide()
    end
    local function go()
      OpenWindow()
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, go)
    else
      go()
    end
  end)
  if menu.HookScript then
    menu:HookScript("OnShow", LayoutGameMenu)
  else
    local prev = menu:GetScript("OnShow")
    menu:SetScript("OnShow", function(self, ...)
      if prev then
        prev(self, ...)
      end
      LayoutGameMenu()
    end)
  end
  if menu:IsShown() then
    LayoutGameMenu()
  end
  return btn
end

Launcher.LayoutGameMenu = LayoutGameMenu

-- Movable launcher button ------------------------------------------------------

local launcher

local function DefaultPoint()
  return "TOPRIGHT", UIParent, "TOPRIGHT", -36, -200
end

local function SavePos()
  if not launcher then
    return
  end
  local point, _, rel, x, y = launcher:GetPoint(1)
  if point then
    DB().launcherPos = { point, rel, x, y }
  end
end

local function RestorePos()
  if not launcher then
    return
  end
  launcher:ClearAllPoints()
  local pos = DB().launcherPos
  if type(pos) == "table" and pos[1] then
    launcher:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
  else
    launcher:SetPoint(DefaultPoint())
  end
end

local function SkinLauncher()
  if not launcher then
    return
  end
  local T = _G.NockTheme
  if T and T.SetTex then
    -- Hollow style ring around the crest, same art as the XP badge.
    if launcher.ring then
      if not T.SetTex(launcher.ring, "xp_badge") then
        T.SetTex(launcher.ring, "badge")
      end
    end
    if launcher.icon and T.tex and T.tex.crest then
      launcher.icon:SetTexture(T.tex.crest)
    end
  end
end

local function CanDrag()
  if IsShiftKeyDown and IsShiftKeyDown() then
    return true
  end
  return DB().launcherLocked == false
end

local function CreateLauncher()
  if launcher then
    return launcher
  end
  local b = CreateFrame("Button", "NockLauncherButton", UIParent)
  b:SetSize(36, 36)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(80)
  b:SetClampedToScreen(true)
  b:SetMovable(true)
  b:EnableMouse(true)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 6, -6)
  icon:SetPoint("BOTTOMRIGHT", -6, 6)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.icon = icon

  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetPoint("TOPLEFT", -2, 2)
  ring:SetPoint("BOTTOMRIGHT", 2, -2)
  b.ring = ring

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(ring)
  hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  hl:SetBlendMode("ADD")

  b:SetScript("OnClick", function(self, button)
    if button ~= "LeftButton" then
      return
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
      return
    end
    if PlaySound then
      pcall(PlaySound, "igMainMenuOption")
    end
    OpenWindow()
  end)
  b:SetScript("OnDragStart", function(self)
    if CanDrag() then
      self:StartMoving()
      self._dragging = true
    end
  end)
  b:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if self._dragging then
      SavePos()
    end
    self._dragging = nil
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    if GameTooltip.SetClampedToScreen then
      pcall(GameTooltip.SetClampedToScreen, GameTooltip, true)
    end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Nock", 1, 0.82, 0, 1)
    GameTooltip:AddLine("Left-click to open. Hold Shift and drag to move.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  launcher = b
  Launcher.frame = b
  SkinLauncher()
  RestorePos()
  return b
end

function Launcher.Update()
  CreateLauncher()
  SkinLauncher()
  if not launcher then
    return
  end
  if DB().showLauncher == false then
    launcher:Hide()
  else
    launcher:Show()
    RestorePos()
  end
end

function Launcher.Reset()
  DB().launcherPos = nil
  CreateLauncher()
  RestorePos()
  if launcher and DB().showLauncher ~= false then
    launcher:Show()
  end
  if Nock.Print then
    Nock.Print("Nock button moved back to the default spot (top right).")
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Nock button moved back to the default spot (top right).")
  end
end

function Launcher.Restyle()
  SkinLauncher()
end

function Launcher.Init()
  CreateGameMenuButton()
  Launcher.Update()
end

-- Init once the UI is up (ADDON_LOADED in Nock.lua also calls Init).
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  Launcher.Init()
end)

if Nock.UI and Nock.UI.Show == nil and UI and UI.Toggle then
  -- keep going; OpenWindow already falls back
end
