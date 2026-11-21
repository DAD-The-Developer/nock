--[[
  Nock 3.3.0: quiver counter.

  A movable quiver (Emerald) or ammo pouch (Gunsmith) that shows how much
  ammo you have left in big numbers. The ring is green when the quiver is
  well stocked, yellow at medium, and red when you are running low.

  "Full" is your quiver or ammo pouch capacity (its slots times the ammo's
  stack size). With no quiver or pouch equipped, 1000 counts as full.

  Hold Shift and drag to move it, or /nock quiver unlock to drag it freely.
  /nock quiver            on or off
  /nock quiver lock       stop plain dragging (Shift-drag still works)
  /nock quiver unlock     drag without Shift
  /nock quiver reset      put it back in the default spot
]]

local Nock = _G.Nock
if not Nock then
  return
end

local Q = {}
Nock.Quiver = Q

local TEX = "Interface\\AddOns\\Nock\\Media\\Textures\\pins\\"
local BASE = 58
local EMERALD_SIZE = 84
-- The count sits low in the arch between the quiver's legs (256 px art,
-- gap centred near x 121). Tuned against the 3.3.1 preview.
local COUNT_X = -2
local COUNT_Y = -35
local DEFAULT_FULL = 1000
local GREEN = { 0.25, 0.90, 0.35 }
local YELLOW = { 1.00, 0.82, 0.15 }
local RED = { 1.00, 0.25, 0.20 }
local HIGH, LOW = 0.66, 0.33

local frame
local pending = false
local inCombat = false
local state = { count = 0, full = DEFAULT_FULL, name = nil, hasBag = false }

local function DB()
  _G.NockCharDB = _G.NockCharDB or {}
  return _G.NockCharDB
end

function Q.IsOn()
  local db = _G.NockCharDB
  return not (db and db.quiver == false)
end

local function Say(msg)
  if Nock.Print then
    Nock.Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Nock: " .. tostring(msg))
  end
end

-- Ammo math -----------------------------------------------------------------

local AMMO_SLOT
local function AmmoSlot()
  if AMMO_SLOT then
    return AMMO_SLOT
  end
  if GetInventorySlotInfo then
    local ok, id = pcall(GetInventorySlotInfo, "AmmoSlot")
    if ok and type(id) == "number" then
      AMMO_SLOT = id
      return id
    end
  end
  AMMO_SLOT = _G.INVSLOT_AMMO or 0
  return AMMO_SLOT
end

local function ItemName(id)
  if C_Item and C_Item.GetItemNameByID then
    local ok, n = pcall(C_Item.GetItemNameByID, id)
    if ok and n then
      return n
    end
  end
  if GetItemInfo then
    local ok, n = pcall(GetItemInfo, id)
    if ok and n then
      return n
    end
  end
end

local function StackSize(id)
  if C_Item and C_Item.GetItemMaxStackSizeByID then
    local ok, n = pcall(C_Item.GetItemMaxStackSizeByID, id)
    if ok and type(n) == "number" and n > 0 then
      return n
    end
  end
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if info then
    local ok, _, _, _, _, _, _, _, stack = pcall(info, id)
    if ok and type(stack) == "number" and stack > 0 then
      return stack
    end
  end
  return 200
end

local function NumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag) or 0
  elseif GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function BagFamily(bag)
  local fam
  if C_Container and C_Container.GetContainerNumFreeSlots then
    local _, f = C_Container.GetContainerNumFreeSlots(bag)
    fam = f
  elseif GetContainerNumFreeSlots then
    local _, f = GetContainerNumFreeSlots(bag)
    fam = f
  end
  return fam or 0
end

local QUIVER, POUCH = 1, 2 -- bag family bits

local function Scan()
  local slot = AmmoSlot()
  local id = GetInventoryItemID and GetInventoryItemID("player", slot)
  local count = 0
  if id then
    count = GetInventoryItemCount("player", slot) or 0
  end
  local stack = id and StackSize(id) or 200
  local slots = 0
  local bags = _G.NUM_BAG_SLOTS or 4
  for bag = 1, bags do
    local fam = BagFamily(bag)
    if bit and bit.band then
      if bit.band(fam, QUIVER + POUCH) ~= 0 then
        slots = slots + NumSlots(bag)
      end
    elseif fam == QUIVER or fam == POUCH then
      slots = slots + NumSlots(bag)
    end
  end
  state.count = count
  state.id = id
  state.name = id and ItemName(id) or nil
  state.hasBag = slots > 0
  state.slots = slots
  state.full = slots > 0 and (slots * stack) or DEFAULT_FULL
end

local function FillColor(pct)
  if pct > HIGH then
    return GREEN
  elseif pct >= LOW then
    return YELLOW
  end
  return RED
end

-- Frame -----------------------------------------------------------------------

local function Scale()
  local size = Nock.BarSize and Nock.BarSize() or "large"
  if size == "small" then
    return 0.8
  elseif size == "normal" then
    return 1.0
  end
  return 1.2
end

local function DefaultPoint()
  return "BOTTOM", UIParent, "BOTTOM", 330, 150
end

local function SavePos()
  local point, _, rel, x, y = frame:GetPoint(1)
  if point then
    DB().quiverPos = { point, rel, x, y }
  end
end

local function RestorePos()
  frame:ClearAllPoints()
  local pos = DB().quiverPos
  if type(pos) == "table" and pos[1] then
    frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
  else
    frame:SetPoint(DefaultPoint())
  end
end

local function CanDrag()
  if IsShiftKeyDown and IsShiftKeyDown() then
    return true
  end
  return DB().quiverLocked == false
end

local function Font(fs, size)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(fs, size, "THICKOUTLINE")
  else
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "THICKOUTLINE")
  end
end

local function Create()
  if frame then
    return frame
  end
  local f = CreateFrame("Frame", "NockQuiverFrame", UIParent)
  f:SetSize(BASE, BASE)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(70)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")

  f.glow = f:CreateTexture(nil, "BACKGROUND")
  f.glow:SetTexture(TEX .. "q_glow")
  f.glow:SetBlendMode("ADD")

  f.disc = f:CreateTexture(nil, "BORDER", nil, 0)
  f.disc:SetTexture(TEX .. "q_disc")

  f.art = f:CreateTexture(nil, "ARTWORK")

  -- The ring sits behind the art so the painted quiver is never covered.
  f.ring = f:CreateTexture(nil, "BORDER", nil, 1)
  f.ring:SetTexture(TEX .. "q_ring")

  f.count = f:CreateFontString(nil, "OVERLAY")
  f.count:SetShadowColor(0, 0, 0, 1)
  f.count:SetShadowOffset(2, -2)
  f.count:SetJustifyH("CENTER")

  -- Low ammo: the glow breathes.
  local ag = f.glow:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(0.35)
  a:SetToAlpha(1)
  a:SetDuration(0.7)
  f.pulse = ag

  f:SetScript("OnDragStart", function(self)
    if CanDrag() then
      self:StartMoving()
      self._dragging = true
    end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if self._dragging then
      SavePos()
    end
    self._dragging = nil
  end)
  f:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if state.id then
      GameTooltip:SetText(state.name or "Ammo", 1, 1, 1)
      GameTooltip:AddLine(string.format("%d in your bags", state.count), 0.95, 0.88, 0.55)
      if state.hasBag then
        GameTooltip:AddLine(string.format("Quiver holds %d (%d slots)", state.full, state.slots or 0), 0.8, 0.8, 0.8)
      end
    else
      GameTooltip:SetText("No ammo in your ammo slot", 1, 0.3, 0.25)
      GameTooltip:AddLine("Right-click arrows or bullets in your bags to load them.", 0.9, 0.9, 0.9, true)
    end
    GameTooltip:AddLine("Shift-drag to move. /nock quiver to hide.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  local acc = 0
  f:SetScript("OnUpdate", function(_, elapsed)
    if not inCombat then
      return
    end
    acc = acc + (elapsed or 0)
    if acc >= 0.5 then
      acc = 0
      Q.Update()
    end
  end)

  frame = f
  Q.frame = f
  RestorePos()
  return f
end

function Q.Restyle()
  if not frame then
    return
  end
  local style = Nock.StyleId and Nock.StyleId() or "emerald"
  local f = frame
  f.glow:ClearAllPoints()
  f.disc:ClearAllPoints()
  f.ring:ClearAllPoints()
  f.art:ClearAllPoints()
  f.count:ClearAllPoints()
  if style == "gunsmith" then
    -- Ammo pouch: art inside the ring, count under it.
    f:SetSize(BASE, BASE)
    f.art:SetTexture(TEX .. "q_pouch")
    f.glow:SetPoint("TOPLEFT", -12, 12)
    f.glow:SetPoint("BOTTOMRIGHT", 12, -12)
    f.disc:SetAllPoints()
    f.ring:SetAllPoints()
    f.art:SetPoint("TOPLEFT", 5, -3)
    f.art:SetPoint("BOTTOMRIGHT", -5, 7)
    f.count:SetPoint("TOP", f, "BOTTOM", 0, 4)
    Font(f.count, 22)
  else
    -- Emerald (3.3.1): Ben's painted quiver, large, over the ring. The count
    -- sits in the arch between the quiver's legs.
    f:SetSize(EMERALD_SIZE, EMERALD_SIZE)
    f.art:SetTexture(TEX .. "q_quiver")
    f.art:SetAllPoints()
    f.glow:SetPoint("TOPLEFT", -8, 8)
    f.glow:SetPoint("BOTTOMRIGHT", 8, -8)
    f.disc:SetPoint("TOPLEFT", 8, -8)
    f.disc:SetPoint("BOTTOMRIGHT", -8, 8)
    f.ring:SetPoint("TOPLEFT", 4, -4)
    f.ring:SetPoint("BOTTOMRIGHT", -4, 4)
    f.count:SetPoint("CENTER", f, "CENTER", COUNT_X, COUNT_Y)
    Font(f.count, 17)
  end
  f:SetScale(Scale())
end

local function Paint()
  local pct = state.full > 0 and math.min(1, state.count / state.full) or 0
  local c = state.id and FillColor(pct) or RED
  frame.ring:SetVertexColor(c[1], c[2], c[3], 1)
  frame.glow:SetVertexColor(c[1], c[2], c[3], 1)
  frame.count:SetTextColor(c[1] * 0.35 + 0.65, c[2] * 0.35 + 0.65, c[3] * 0.35 + 0.65)
  frame.count:SetText(state.id and tostring(state.count) or "0")
  local low = (not state.id) or pct < LOW
  if low then
    if not frame.pulse:IsPlaying() then
      frame.pulse:Play()
    end
  else
    if frame.pulse:IsPlaying() then
      frame.pulse:Stop()
    end
    frame.glow:SetAlpha(0.45)
  end
end

function Q.Update()
  local isHunter = (not Nock.IsHunter) or Nock.IsHunter()
  if not (Q.IsOn() and isHunter) then
    if frame then
      frame:Hide()
    end
    return
  end
  Create()
  Q.Restyle()
  local ok, err = pcall(Scan)
  if not ok then
    Q.lastError = err
  end
  Paint()
  frame:Show()
end

local function Soon()
  if pending then
    return
  end
  pending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0.2, function()
      pending = false
      Q.Update()
    end)
  else
    pending = false
    Q.Update()
  end
end

function Q.SetOn(on)
  DB().quiver = on and true or false
  Q.Update()
  local UI = Nock.UI
  if UI and UI.Refresh then
    pcall(UI.Refresh)
  end
end

function Q.Toggle()
  Q.SetOn(not Q.IsOn())
  Say("Quiver counter " .. (Q.IsOn() and "on." or "off."))
end
_G.Nock_ToggleQuiver = Q.Toggle

function Q.Reset()
  DB().quiverPos = nil
  if frame then
    RestorePos()
  end
  Say("Quiver counter moved back to the default spot (right of the bar).")
end

function Q.Slash(rest)
  rest = rest or ""
  if rest == "" then
    return Q.Toggle()
  elseif rest == "on" or rest == "off" then
    Q.SetOn(rest == "on")
    return Say("Quiver counter " .. rest .. ".")
  elseif rest == "lock" then
    DB().quiverLocked = nil
    return Say("Quiver counter locked. Shift-drag still moves it.")
  elseif rest == "unlock" then
    DB().quiverLocked = false
    return Say("Quiver counter unlocked: drag it anywhere, then /nock quiver lock.")
  elseif rest == "reset" then
    return Q.Reset()
  end
  Say("/nock quiver — on or off.  /nock quiver unlock | lock | reset")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
  end
  Soon()
end)

-- /nock pins and /nock quiver ride on the main /nock command.
local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg)
    local m = string.lower(strtrim(msg or ""))
    local cmd, rest = m:match("^(%S+)%s*(.*)$")
    if cmd == "pins" or cmd == "pin" then
      if Nock.Pins then
        return Nock.Pins.Slash(rest)
      end
    elseif cmd == "quiver" or cmd == "ammo" then
      return Q.Slash(rest)
    end
    baseSlash(msg)
    if m == "help" then
      Say("/nock pins — hunter trainer, pet trainer, stable and ammo pins on the maps, on or off")
      Say("/nock pins trainer | pet | stable | ammo | minimap | map | hostile — one part on or off")
      Say("/nock quiver — the ammo counter on or off   /nock quiver unlock | lock | reset")
    end
  end
end

if hooksecurefunc and Nock.SetBarSize then
  hooksecurefunc(Nock, "SetBarSize", function()
    if frame then
      frame:SetScale(Scale())
    end
  end)
end
