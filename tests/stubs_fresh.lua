-- Extra WoW stubs for a full fresh-load of Nock (Lua 5.1). Generic hunter.
-- No character names from a real realm.

UNIT_NAMES = { player = "TestHunter" }
UNIT_EXISTS = { player = true }
UNIT_GUIDS = { player = "Player-1-0001" }

function UnitClass(u)
  if u == "player" then
    return "Hunter", "HUNTER"
  end
end
function UnitLevel() return 25 end
function UnitName(u) return UNIT_NAMES[u] or u end
function UnitGUID(u) return UNIT_GUIDS[u] end
function UnitExists(u) return UNIT_EXISTS[u] and true or false end
function GetBuildInfo() return "1.60.1", "16001", "Nov 18 2026", 16001 end
function GetLocale() return "enUS" end
function GetTime() return 100 end
function date() return "2026-01-01 00:00:00" end
function time() return 0 end
function hooksecurefunc() end
SlashCmdList = SlashCmdList or {}
UISpecialFrames = UISpecialFrames or {}
function tinsert(t, v) t[#t + 1] = v end
function tremove(t, i)
  i = i or #t
  local v = t[i]
  table.remove(t, i)
  return v
end
function wipe(t)
  for k in pairs(t) do t[k] = nil end
  return t
end
function strtrim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
function GetBindingKey() return nil end
function GetBindingAction() return "" end
function SetBinding() return true end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
function GetBindingText(k) return k end
function PlaySound() end
function PlaySoundFile() end
function GetCursorPosition() return 0, 0 end
function MouseIsOver() return false end
function IsShiftKeyDown() return false end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
function IsModifierKeyDown() return false end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetAddOnMetadata(a, k)
  if k == "Version" then return "3.10.0" end
  if k == "Title" then return "Nock" end
end
C_Timer = { After = function(_, fn) end }
GameTooltip = {
  SetOwner = function() end,
  SetText = function() end,
  AddLine = function() end,
  Show = function() end,
  Hide = function() end,
  SetClampedToScreen = function() end,
}
-- Game menu (Escape), unused until PLAYER_LOGIN creates the button.
if CreateFrame then
  GameMenuFrame = CreateFrame("Frame", "GameMenuFrame", UIParent)
  GameMenuButtonAddons = CreateFrame("Button", "GameMenuButtonAddons", GameMenuFrame)
  GameMenuButtonLogout = CreateFrame("Button", "GameMenuButtonLogout", GameMenuFrame)
end
StaticPopupDialogs = {}
function StaticPopup_Show() end
function HideUIPanel() end
function ShowUIPanel() end
function PanelTemplates_SetNumTabs() end
function PanelTemplates_SetTab() end
function SetPortraitToTexture() end
function GetMacroInfo() end
function GetActionInfo() end
function GetSpellInfo(idOrName)
  return tostring(idOrName), nil, "Interface\\Icons\\INV_Misc_QuestionMark"
end
function GetSpellLink() return "" end
function IsSpellKnown() return false end
function IsUsableSpell() return false, false end
function GetSpellCooldown() return 0, 0, 1 end
function GetInventoryItemCooldown() return 0, 0, 0 end
function GetItemCooldown() return 0, 0, 0 end
function UnitCastingInfo() end
function UnitChannelInfo() end
function UnitIsDeadOrGhost() return false end
function UnitIsDead() return false end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function UnitPower() return 100 end
function UnitPowerMax() return 100 end
function UnitIsUnit() return false end
function GetNumTalentTabs() return 3 end
function GetNumTalents() return 0 end
function GetTalentInfo() return nil end
function GetUnspentTalentPoints() return 0 end
function LearnTalent() end
function GetNumMacros() return 0, 0 end
function GetMaxNumMacros() return 18, 120 end
function GetNumBindings() return 0 end
function GetBinding() end
function ClearOverrideBindings() end
function SetOverrideBindingClick() end
function GetTalentTabInfo(i)
  return "Beast Mastery", "Interface\\Icons\\Ability_Hunter_BeastTaming", 0, "HunterBeastMastery"
end
ChatFrame1 = DEFAULT_CHAT_FRAME
SELECTED_CHAT_FRAME = DEFAULT_CHAT_FRAME
Minimap = CreateFrame and CreateFrame("Frame", "Minimap", UIParent) or nil
AddonCompartmentFrame = nil
function GetMouseFocus() return nil end
function GetCVar() return nil end
function SetCVar() end
function IsLoggedIn() return true end
function UnitAffectingCombat() return false end
function GetNumTrackingTypes() return 0 end
function GetTrackingInfo() end
function GetItemCount() return 0 end
function GetItemInfo() end
function HasAction() return false end
function IsInInstance() return false end
function UnitInRaid() return false end
function UnitInParty() return false end
function GetNumGroupMembers() return 0 end
function IsMounted() return false end
function GetUnitName(u) return UnitName(u) end
function format(...) return string.format(...) end
bit = bit or {
  band = function() return 0 end,
  bor = function() return 0 end,
  bxor = function() return 0 end,
  rshift = function() return 0 end,
  lshift = function() return 0 end,
}


-- Methods used during ADDON_LOADED / PLAYER_LOGIN
local function patch(f)
  if not f then return end
  function f:UnregisterAllEvents() end
  function f:UnregisterEvent() end
  function f:RegisterForClicks() end
  function f:SetToplevel() end
  function f:EnableKeyboard() end
  function f:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
  function f:GetAttribute(k) return self._attr and self._attr[k] end
  function f:SetScript(name, fn)
    self._scripts = self._scripts or {}
    self._scripts[name] = fn
  end
  function f:HookScript(name, fn)
    self._scripts = self._scripts or {}
    self._hooks = self._hooks or {}
    self._hooks[name] = self._hooks[name] or {}
    self._hooks[name][#self._hooks[name]+1] = fn
  end
  function f:GetHeight() return self._h or 24 end
  function f:GetWidth() return self._w or 144 end
  function f:SetHeight(h) self._h = h end
  function f:SetWidth(w) self._w = w end
  function f:SetText(s) self._text = s end
  function f:GetText() return self._text end
  function f:SetNormalTexture() end
  function f:SetPushedTexture() end
  function f:SetHighlightTexture() end
  function f:SetDisabledTexture() end
  function f:GetNormalTexture() end
  function f:GetPushedTexture() end
  function f:GetHighlightTexture() end
  function f:GetDisabledTexture() end
  function f:SetID() end
  function f:GetID() return self._id end
  function f:SetAlpha() end
  function f:GetAlpha() return 1 end
  function f:SetScale() end
  function f:GetScale() return 1 end
  function f:IsVisible() return self._shown end
  function f:Raise() end
  function f:Lower() end
  function f:GetRegions() return end
  function f:GetChildren() return end
  local origCT = f.CreateTexture
  if origCT then
    function f:CreateTexture(...)
      local tex = origCT(self, ...)
      function tex:SetBlendMode() end
      function tex:SetRotation() end
      function tex:SetDesaturated() end
      function tex:SetAlpha() end
      function tex:SetShown() end
      function tex:IsShown() return tex._shown ~= false end
      function tex:GetTexture() return tex._path end
      function tex:SetAtlas() return false end
      return tex
    end
  end
  local origFS = f.CreateFontString
  if origFS then
    function f:CreateFontString(...)
      local fs = origFS(self, ...)
      function fs:SetWordWrap() end
      function fs:SetNonSpaceWrap() end
      function fs:GetStringWidth() return fs._w or 80 end
      function fs:GetStringHeight() return fs._h or 16 end
      function fs:SetFontObject() end
      function fs:SetShown() end
      function fs:IsShown() return fs._shown ~= false end
      function fs:SetParent() end
      return fs
    end
  end
end
if UIParent then patch(UIParent) end
if GameMenuFrame then patch(GameMenuFrame) end
if GameMenuButtonAddons then patch(GameMenuButtonAddons) end
if GameMenuButtonLogout then patch(GameMenuButtonLogout) end
if Minimap then patch(Minimap) end

-- Patch CreateFrame so later frames also get these methods.
local _orig = CreateFrame
function CreateFrame(kind, name, parent, ...)
  local f = _orig(kind, name, parent, ...)
  patch(f)
  return f
end
-- And patch frames already created
for _, f in ipairs(FRAMES or {}) do
  patch(f)
end

-- Empty saved variables: a brand-new install, no prior Nock use.
NockDB = {}
NockCharDB = {}
NockTheme = nil
Nock = nil
