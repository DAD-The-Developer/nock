--[[
  Nock 1.6.0 — main window

  A standard Blizzard portrait panel (ButtonFrameTemplate) with six bottom
  tabs: Profiles, My Rotation (UI_MyRotation.lua), Talents, Rotation, Macros and Field Manual. Also the
  action-button key badges, the addon compartment entry and a minimap
  button fallback.

  Nothing here reads combat state or presses keys. Buttons that write keys,
  bars, macros or talents are greyed out while you are in combat.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local function EnsureFont(fs, sizeOrObject, flags)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    return T.EnsureFont(fs, sizeOrObject, flags)
  end
  if not fs then
    return false
  end
  local path = (type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
  local size = type(sizeOrObject) == "number" and sizeOrObject or 12
  if fs.SetFont then
    local ok, res = pcall(fs.SetFont, fs, path, size, flags or "OUTLINE")
    if ok and res ~= false then
      return true
    end
  end
  return false
end

local UI = { tabs = {}, pages = {}, lockButtons = {}, combat = false }
Nock.UI = UI

-- Helpers ------------------------------------------------------------------------

local function Print(msg)
  if Nock.Print then
    Nock.Print(msg)
  end
end

-- parentKey children from Blizzard templates. Anything that is not a table
-- means the template (or that child) is missing.
local function Field(f, key)
  local v = f and f[key]
  if type(v) == "table" then
    return v
  end
  return nil
end

local function Sound(name)
  if PlaySound and SOUNDKIT and SOUNDKIT[name] then
    pcall(PlaySound, SOUNDKIT[name])
  end
end

local function TryCreate(kind, name, parent, ...)
  for i = 1, select("#", ...) do
    local template = select(i, ...)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then
      return f, template
    end
  end
  return CreateFrame(kind, name, parent), nil
end

local function HasAtlas(atlas)
  if not atlas or not (C_Texture and C_Texture.GetAtlasInfo) then
    return false
  end
  local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
  return ok and info ~= nil
end

local function SetAtlasOr(tex, atlas, file)
  if HasAtlas(atlas) then
    tex:SetAtlas(atlas)
    return true
  end
  tex:SetTexture(file)
  return false
end

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local HUNTER_ICON = "Interface\\Icons\\ClassIcon_Hunter"

local function SetIcon(tex, icon)
  if tex:SetTexture(icon or QUESTION) == false then
    tex:SetTexture(QUESTION)
  end
end

local HUNTER = { 0.67, 0.83, 0.45 }
if RAID_CLASS_COLORS and RAID_CLASS_COLORS.HUNTER then
  local c = RAID_CLASS_COLORS.HUNTER
  HUNTER = { c.r, c.g, c.b }
end
local HUNTER_HEX = string.format("ff%02x%02x%02x", HUNTER[1] * 255, HUNTER[2] * 255, HUNTER[3] * 255)

local TREE = {
  bm = { short = "BM", name = "Beast Mastery", hex = "ffaad372", rgb = { 0.67, 0.83, 0.45 } },
  mm = { short = "MM", name = "Marksmanship", hex = "ff7fb2ff", rgb = { 0.50, 0.70, 1.00 } },
  sv = { short = "SV", name = "Survival", hex = "fff2a040", rgb = { 0.95, 0.63, 0.25 } },
}

local SPEC_NAME = { bm = "Beast Mastery", marks = "Marksmanship" }

local PROFILE_ICONS = {
  bmlvl = "Interface\\Icons\\Ability_Hunter_BeastTaming",
  bm60 = "Interface\\Icons\\Ability_Druid_FerociousBite",
  mmlvl = "Interface\\Icons\\Ability_Marksmanship",
  mm60 = "Interface\\Icons\\Ability_TrueShot",
}

local PROFILE_BLURB = {
  bmlvl = "Levels 10-59",
  bm60 = "Level 60 raids and dungeons",
  mmlvl = "Levels 10-59",
  mm60 = "Level 60, Lone Wolf",
}

local STATE_ART = {
  learned = { atlas = "lootroll-icon-checkmark", file = "Interface\\RaidFrame\\ReadyCheck-Ready" },
  next = { atlas = "bags-greenarrow", file = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
  locked = { atlas = "QuestSharing-Padlock", file = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
  available = { atlas = "common-radiobutton-circle", file = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
  missing = { atlas = nil, file = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}

local TOOLTIP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local BADGE_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = false, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function Backdrop(f, bd, r, g, b, a, br, bg, bb, ba)
  if f.SetBackdrop then
    f:SetBackdrop(bd)
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br, bg, bb, ba)
  end
end

local function Profiles()
  return Nock.Profiles or {}
end

local function ProfileOrder()
  return Nock.ProfileOrder or {}
end

-- The profile whose keys are on the keyboard right now. /nock bm and
-- /nock marks apply the plain layout, so a profile of the other spec (or a
-- restore) means no profile is active.
local function Active()
  local a = Nock.ActiveProfile and Nock.ActiveProfile()
  if a and NockCharDB.applied and (not NockCharDB.spec or NockCharDB.spec == a.spec) then
    return a
  end
  return nil
end

local function Selected()
  if NockCharDB.view ~= "advanced" then
    local a = Active()
    if a then
      UI.sel = a.key
    end
  end
  local p = Profiles()[UI.sel]
  if p then
    return p
  end
  local active = Active()
  if active then
    UI.sel = active.key
    return active
  end
  local level = Nock.PlayerLevel and Nock.PlayerLevel() or 1
  UI.sel = level >= 60 and "bm60" or "bmlvl"
  return Profiles()[UI.sel]
end

local function InCombat()
  return UI.combat or (InCombatLockdown and InCombatLockdown()) or false
end

-- The keys a profile would bind, without changing anything: LayoutFor only
-- adds profile macros for the active profile, so swap it in for the read.
local function LayoutForProfile(p)
  if not (p and Nock.LayoutFor) then
    return {}
  end
  local saved = NockCharDB.profile
  NockCharDB.profile = p.key
  local ok, layout = pcall(Nock.LayoutFor, p.spec)
  NockCharDB.profile = saved
  return ok and layout or {}
end

local function BuildString(build)
  local a, b, c = (build or ""):match("(%d+)%s*/%s*(%d+)%s*/%s*(%d+)")
  if not a then
    return build or ""
  end
  return string.format("|c%s%s|r / |c%s%s|r / |c%s%s|r", TREE.bm.hex, a, TREE.mm.hex, b, TREE.sv.hex, c)
end

local function KeyLabel(key)
  return Nock.KeyLabel and Nock.KeyLabel(key) or key
end

-- Tooltips -----------------------------------------------------------------------

local function ShowTip(owner, title, lines, anchor)
  if not GameTooltip then
    return
  end
  if GameTooltip.SetClampedToScreen then
    pcall(GameTooltip.SetClampedToScreen, GameTooltip, true)
  end
  if not anchor and owner and owner.GetRight and UIParent and UIParent.GetWidth then
    local right = owner:GetRight()
    local pw = UIParent:GetWidth()
    if right and pw and right > (pw - 280) then
      anchor = "ANCHOR_LEFT"
    end
  end
  GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
  GameTooltip:SetText(title or "", 1, 0.82, 0, 1, true)
  for _, line in ipairs(lines or {}) do
    if type(line) == "table" then
      GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 1, line[4] or 1, true)
    elseif line ~= "" then
      GameTooltip:AddLine(line, 1, 1, 1, true)
    end
  end
  GameTooltip:Show()
end

local function HideTip()
  if GameTooltip then
    GameTooltip:Hide()
  end
end

local function AttachTip(f, fn)
  f:SetScript("OnEnter", function(self)
    local title, lines = fn(self)
    if title then
      ShowTip(self, title, lines)
    end
  end)
  f:SetScript("OnLeave", HideTip)
end

-- Buttons ------------------------------------------------------------------------

-- UIPanelButtonTemplate with a tooltip. Buttons marked "lock" turn grey in
-- combat. allowed() can return false, reason to grey them for other reasons.
local function PanelButton(parent, text, width, opts)
  opts = opts or {}
  local b = TryCreate("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 120, opts.height or 22)
  b:SetText(text)
  if b.SetMotionScriptsWhileDisabled then
    b:SetMotionScriptsWhileDisabled(true)
  end
  b.tipTitle = opts.tipTitle or text
  b.tipText = opts.tip
  b.allowed = opts.allowed
  b.lock = opts.lock
  b:SetScript("OnEnter", function(self)
    local lines = {}
    if self.tipText then
      lines[#lines + 1] = self.tipText
    end
    if self.reason then
      lines[#lines + 1] = { self.reason, 1, 0.25, 0.25 }
    end
    ShowTip(self, self.tipTitle, lines)
  end)
  b:SetScript("OnLeave", HideTip)
  if opts.onClick then
    b:SetScript("OnClick", function(self, ...)
      Sound(opts.sound or "IG_MAINMENU_OPTION")
      opts.onClick(self, ...)
    end)
  end
  if opts.lock or opts.allowed then
    UI.lockButtons[#UI.lockButtons + 1] = b
  end
  return b
end

local function UpdateButtonStates()
  local combat = InCombat()
  for _, b in ipairs(UI.lockButtons) do
    local ok, reason = true, nil
    if b.lock and combat then
      ok, reason = false, "Leave combat first. Nock only changes keys, bars, macros and talents out of combat."
    elseif b.allowed then
      local allowedOK, why = b.allowed()
      if not allowedOK then
        ok, reason = false, why
      end
    end
    b:SetEnabled(ok)
    b.reason = reason
  end
end

local function CheckBox(parent, label, tip, get, set)
  local cb = TryCreate("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(30, 30)
  local fs = Field(cb, "Text") or Field(cb, "text")
  if not fs then
    fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 8, 1)
  end
  local body = 16
  if UI.WindowMetrics then
    body = UI.WindowMetrics().body or 16
  end
  EnsureFont(fs, body, "OUTLINE")
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("MIDDLE")
  fs:SetWordWrap(true)
  fs:SetText(label)
  cb.label = fs
  cb:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    Sound(on and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    set(on)
  end)
  cb.Sync = function(self)
    self:SetChecked(get() and true or false)
  end
  AttachTip(cb, function()
    return label, { tip }
  end)
  return cb
end

-- Popups ---------------------------------------------------------------------------

local function Confirm(id, text, onAccept)
  if StaticPopupDialogs and StaticPopup_Show then
    StaticPopupDialogs[id] = StaticPopupDialogs[id] or {
      button1 = (YES or "Yes"),
      button2 = (CANCEL or "Cancel"),
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      showAlert = true,
      preferredIndex = 3,
    }
    local d = StaticPopupDialogs[id]
    d.text = text
    d.OnAccept = function()
      onAccept()
    end
    StaticPopup_Show(id)
  else
    onAccept()
  end
end

local copyFrame

local function ShowCopy(title, body)
  if not copyFrame then
    local f = TryCreate("Frame", "NockCopyFrame", UIParent, "DefaultPanelTemplate", "BackdropTemplate")
    f:SetSize(460, 250)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    if not Field(f, "TitleContainer") and not Field(f, "NineSlice") then
      Backdrop(f, TOOLTIP_BACKDROP, 0.05, 0.05, 0.05, 0.96, 0.7, 0.7, 0.7, 1)
    end
    tinsert(UISpecialFrames, "NockCopyFrame")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 1, 0)
    local titleFS = Field(Field(f, "TitleContainer"), "TitleText")
    if not titleFS then
      titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      EnsureFont(titleFS, "GameFontNormal")
      titleFS:SetPoint("TOP", 0, -6)
    end
    f.titleFS = titleFS
    local inset = TryCreate("Frame", nil, f, "InsetFrameTemplate", "BackdropTemplate")
    inset:SetPoint("TOPLEFT", 12, -30)
    inset:SetPoint("BOTTOMRIGHT", -12, 44)
    if not Field(inset, "NineSlice") then
      Backdrop(inset, TOOLTIP_BACKDROP, 0, 0, 0, 0.6, 0.4, 0.4, 0.4, 1)
    end
    local scroll = TryCreate("ScrollFrame", "NockCopyScroll", inset, "ScrollFrameTemplate", "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", -24, 6)
    local eb = CreateFrame("EditBox", "NockCopyEditBox", scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(390)
    eb:SetScript("OnEscapePressed", function()
      f:Hide()
    end)
    eb:SetScript("OnTextChanged", function(self, user)
      -- Read-only: put the original back if someone types into it.
      if user and self.original and self:GetText() ~= self.original then
        self:SetText(self.original)
        self:HighlightText()
      end
    end)
    eb:SetScript("OnEditFocusGained", function(self)
      self:HighlightText()
    end)
    scroll:SetScrollChild(eb)
    f.eb = eb
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    EnsureFont(hint, "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 18)
    hint:SetText("Press Ctrl+C to copy, then paste it into a new macro in /macro.")
    local done = PanelButton(f, DONE or "Done", 90, {
      onClick = function()
        f:Hide()
      end,
      tip = "Close this window.",
    })
    done:SetPoint("BOTTOMRIGHT", -12, 12)
    f:SetScript("OnShow", function()
      Sound("IG_MAINMENU_OPEN")
    end)
    f:SetScript("OnHide", function()
      Sound("IG_MAINMENU_CLOSE")
    end)
    copyFrame = f
  end
  copyFrame.titleFS:SetText(title)
  copyFrame.eb.original = body
  copyFrame.eb:SetText(body)
  copyFrame:Show()
  copyFrame.eb:SetFocus()
  copyFrame.eb:HighlightText()
end

UI.ShowCopy = ShowCopy

-- Rich text --------------------------------------------------------------------
-- A small pool-based layout for the scrolling pages: headers, paragraphs,
-- bullets, icon rows and spacers stacked top to bottom.

local Flow = {}
Flow.__index = Flow

local function NewFlow(child, width)
  return setmetatable({ child = child, width = width, y = -6, fs = {}, nfs = 0, tex = {}, ntex = 0 }, Flow)
end

function Flow:Reset()
  for i = 1, #self.fs do
    self.fs[i]:Hide()
  end
  for i = 1, #self.tex do
    self.tex[i]:Hide()
  end
  self.nfs, self.ntex, self.y = 0, 0, -6
end

function Flow:FS(font, r, g, b)
  self.nfs = self.nfs + 1
  local fs = self.fs[self.nfs]
  if not fs then
    fs = self.child:CreateFontString(nil, "ARTWORK")
    EnsureFont(fs)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    self.fs[self.nfs] = fs
  end
  fs:SetFontObject(font)
  fs:SetTextColor(r or 1, g or 1, b or 1)
  fs:SetSpacing(2)
  fs:ClearAllPoints()
  fs:Show()
  return fs
end

function Flow:Tex(layer)
  self.ntex = self.ntex + 1
  local t = self.tex[self.ntex]
  if not t then
    t = self.child:CreateTexture(nil, layer or "ARTWORK")
    self.tex[self.ntex] = t
  end
  t:SetTexCoord(0, 1, 0, 1)
  t:SetDesaturated(false)
  t:SetAlpha(1)
  t:SetVertexColor(1, 1, 1, 1)
  if t.SetRotation then
    t:SetRotation(0)
  end
  t:ClearAllPoints()
  t:Show()
  return t
end

local function TextHeight(fs, min)
  local h = fs:GetStringHeight() or min or 12
  if h < (min or 0) then
    h = min
  end
  return h
end

function Flow:Space(h)
  self.y = self.y - (h or 8)
end

function Flow:Header(text, sub, icon)
  self:Space(4)
  local x = 4
  if icon then
    local t = self:Tex()
    t:SetSize(20, 20)
    t:SetPoint("TOPLEFT", 4, self.y)
    SetIcon(t, icon)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    x = 30
  end
  local fs = self:FS("GameFontNormalMed2", 1, 0.82, 0)
  fs:SetPoint("TOPLEFT", x, self.y - 2)
  fs:SetWidth(self.width - x - 4)
  fs:SetText(text)
  local h = math.max(22, TextHeight(fs, 16) + 4)
  if sub and sub ~= "" then
    local s = self:FS("GameFontDisableSmall", 0.6, 0.6, 0.6)
    s:SetPoint("TOPLEFT", x, self.y - h)
    s:SetWidth(self.width - x - 4)
    s:SetText(sub)
    h = h + TextHeight(s, 10) + 2
  end
  self.y = self.y - h - 8
  local line = self:Tex("BORDER")
  line:SetHeight(2)
  line:SetPoint("TOPLEFT", 0, self.y + 2)
  line:SetPoint("TOPRIGHT", 0, self.y + 2)
  local Theme = _G.NockTheme
  if Theme and Theme.SetTex and Theme.SetTex(line, "divider") then
    -- Keep the art short so the ornament never crosses the header text.
    line:SetHeight(8)
  else
    line:SetColorTexture(0.82, 0.70, 0.35, 0.55)
    line:SetHeight(2)
  end
  self.y = self.y - 14
end

function Flow:Para(text, font, color, indent)
  indent = indent or 4
  local c = color or { 1, 1, 1 }
  if font == "GameFontDisableSmall" and not color then
    c = { 0.6, 0.6, 0.6 }
  end
  local fs = self:FS(font or "GameFontHighlight", c[1], c[2], c[3])
  fs:SetPoint("TOPLEFT", indent, self.y)
  fs:SetWidth(self.width - indent - 4)
  fs:SetText(text)
  self.y = self.y - TextHeight(fs, 12) - 6
  return fs
end

function Flow:Bullet(text, font)
  local dot = self:Tex()
  dot:SetSize(5, 5)
  dot:SetColorTexture(1, 0.82, 0, 0.9)
  if dot.SetRotation then
    dot:SetRotation(math.pi / 4)
  end
  dot:SetPoint("TOPLEFT", 12, self.y - 5)
  return self:Para(text, font, nil, 24)
end

function Flow:IconRow(icon, title, text, known, tag)
  local t = self:Tex()
  t:SetSize(30, 30)
  t:SetPoint("TOPLEFT", 4, self.y)
  SetIcon(t, icon)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t:SetDesaturated(not known)
  t:SetAlpha(known and 1 or 0.6)
  local name = self:FS("GameFontNormal", 1, 0.82, 0)
  if not known then
    name:SetTextColor(0.6, 0.6, 0.6)
  end
  name:SetPoint("TOPLEFT", 42, self.y - 1)
  name:SetText(title .. (tag and ("  |cff808080" .. tag .. "|r") or ""))
  local shade = known and 0.92 or 0.6
  local body = self:FS("GameFontHighlightSmall", shade, shade, shade)
  body:SetPoint("TOPLEFT", 42, self.y - 16)
  body:SetWidth(self.width - 46)
  body:SetText(text)
  self.y = self.y - math.max(34, 16 + TextHeight(body, 10)) - 8
end

function Flow:Finish()
  self.child:SetHeight(math.max(20, -self.y + 10))
end

-- Turns the guide text style into formatted sections:
--   ALL CAPS LINE         -> section header (a bracketed part after it is the subtitle)
--   - text                -> bullet
--   Level 18+: text       -> gold level prefix
--   (4), (Shift-3)        -> gold key reference [4], [Shift-3]
--   blank                 -> spacer
local function FormatInline(line)
  line = line:gsub("%((%w[%w%-]-)%)", function(k)
    if #k <= 8 and (k:match("^%d$") or k:match("^%u$") or k:match("^Shift%-%w$") or k:match("^Alt%-%w$")) then
      return "|cffffd100[" .. k .. "]|r"
    end
  end)
  line = line:gsub(" > ", " |cffffd100>|r ")
  local prefix, rest = line:match("^(Levels? [%d%-+]+:)(.*)$")
  if prefix then
    line = "|cffffd100" .. prefix .. "|r" .. rest
  end
  return line
end

local function TitleCase(caps)
  local s = caps:sub(1, 1) .. caps:sub(2):lower()
  s = s:gsub("([%s:/%-])(%l)", function(sep, c)
    return sep .. c:upper()
  end)
  return s
end

local function RenderGuide(flow, lines)
  for _, line in ipairs(lines) do
    local caps, rest = line:match("^(%u[%u%d%s:,%-'/]+[%u%d])%s*(.*)$")
    if line == "" then
      flow:Space(4)
    elseif caps and #caps >= 3 and (rest == "" or rest:sub(1, 1) == "(") then
      local sub = nil
      if rest ~= "" then
        sub = rest:gsub("^%((.*)%)$", "%1")
      end
      flow:Header(TitleCase(caps), sub)
    elseif line:sub(1, 2) == "- " then
      flow:Bullet(FormatInline(line:sub(3)))
    else
      flow:Para(FormatInline(line))
    end
  end
end

UI.RenderGuide = RenderGuide
UI.FormatInline = FormatInline

-- Key badges (small keycaps) ------------------------------------------------------

local function MakeKeyBadge(parent, font)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Backdrop(b, BADGE_BACKDROP, 0, 0, 0, 0.8, 0.85, 0.7, 0.3, 1)
  local fs = b:CreateFontString(nil, "OVERLAY", font or "NumberFontNormalSmall")
  EnsureFont(fs, font or "NumberFontNormalSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetTextColor(1, 0.82, 0)
  b.text = fs
  b.SetKey = function(self, key)
    self.text:SetText(KeyLabel(key))
    local w = (self.text:GetStringWidth() or 10) + 10
    self:SetSize(math.max(18, w), 16)
  end
  return b
end

UI.MakeKeyBadge = MakeKeyBadge

-- Main frame -----------------------------------------------------------------------

local frame -- the main window (declared before the layout code uses it)

-- 3.5.0 layout grid --------------------------------------------------------------
-- One strict grid for every tab: 24 px side gutter (clears the carved border),
-- 16 / 12 / 8 px spacing inside. Regions, top to bottom:
--   title plaque | header (page title + one-line subtitle, profile selector)
--   content (each tab's page, scroll frames inset inside it)
--   action bar (help text left, page buttons right)
--   tab strip (attached to the bottom edge)
-- Sizes come from the bar-size setting and the frame is scaled down to fit
-- the screen, so nothing overlaps at Small, Normal, Large or any UI scale.
local W, H = 960, 760
local CONTENT_W = 866

local GRID = { gutter = 24, l = 16, m = 12, s = 8, plaque = 60, tabH = 30, barH = 32, btnH = 24 }
UI.GRID = GRID

function UI.WindowMetrics()
  local size = "large"
  if Nock and Nock.BarSize then
    size = Nock.BarSize() or "large"
  elseif NockCharDB and NockCharDB.barSize then
    size = NockCharDB.barSize
  end
  local m
  if size == "small" then
    m = { w = 800, h = 640, body = 14, header = 18, title = 18, tabFont = 14, small = 12 }
  elseif size == "normal" then
    m = { w = 880, h = 700, body = 16, header = 20, title = 20, tabFont = 15, small = 13 }
  else
    m = { w = 960, h = 760, body = 18, header = 22, title = 22, tabFont = 16, small = 14 }
  end
  m.size = size
  m.pad = GRID.gutter
  m.tabH = GRID.tabH
  m.barH = GRID.barH
  -- Header: plaque, 8, title line, 4, subtitle line, 12.
  m.headY = GRID.plaque + GRID.s
  m.attic = m.headY + m.header + 4 + m.body + 6 + GRID.m
  -- Bottom: border 16, tabs, 8, action bar, 8.
  m.tabY = 16
  m.barY = m.tabY + m.tabH + GRID.s
  m.bottom = m.barY + m.barH + GRID.s
  -- Scroll child width: content inset minus page inset (4+4), scroll
  -- left inset 8 and the 26 px scrollbar lane.
  m.content = m.w - 2 * m.pad - 8 - 8 - 26 - 4
  return m
end

local function FitToScreen(f, m)
  if not (f and f.SetScale) then
    return
  end
  local sw = UIParent and UIParent.GetWidth and tonumber((UIParent:GetWidth())) or 0
  local sh = UIParent and UIParent.GetHeight and tonumber((UIParent:GetHeight())) or 0
  local scale = 1
  if sw > 0 and sh > 0 then
    scale = math.min(1, (sw * 0.96) / m.w, (sh * 0.94) / m.h)
  end
  scale = math.max(0.6, scale)
  f:SetScale(scale)
end
UI.FitToScreen = FitToScreen

function UI.ApplyWindowSize()
  local m = UI.WindowMetrics()
  W, H = m.w, m.h
  CONTENT_W = m.content
  UI.metrics = m
  if UI.lib then
    UI.lib.CONTENT_W = CONTENT_W
  end
  if not frame then
    return m
  end
  frame:SetSize(m.w, m.h)
  FitToScreen(frame, m)
  if frame.content then
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", m.pad, -m.attic)
    frame.content:SetPoint("BOTTOMRIGHT", -m.pad, m.bottom)
  end
  -- Header: profile selector first (it decides how wide the titles can be).
  local selW = 0
  if frame.switch then
    local order = ProfileOrder()
    local size, gap = (m.size == "small") and 24 or 28, 6
    local prev
    for i = #order, 1, -1 do
      local b = frame.switch[order[i]]
      if b then
        b:SetSize(size, size)
        b:ClearAllPoints()
        if prev then
          b:SetPoint("RIGHT", prev, "LEFT", -gap, 0)
        else
          b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -m.pad, -(m.headY + 2))
        end
        selW = selW + size + (prev and gap or 0)
        prev = b
      end
    end
    if frame.switchLabel and prev then
      EnsureFont(frame.switchLabel, m.small, "")
      frame.switchLabel:ClearAllPoints()
      frame.switchLabel:SetPoint("RIGHT", prev, "LEFT", -GRID.s, 0)
      if frame.switchLabel:IsShown() then
        selW = selW + GRID.s + (tonumber((frame.switchLabel:GetStringWidth())) or 44)
      end
    end
    if NockCharDB and NockCharDB.view ~= "advanced" then
      selW = 0
    end
  end
  local rightLimit = m.pad + (selW > 0 and (selW + GRID.l) or 0)
  if frame.head then
    EnsureFont(frame.head, m.header, "")
    frame.head:ClearAllPoints()
    frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", m.pad + 4, -m.headY)
    frame.head:SetPoint("RIGHT", frame, "RIGHT", -rightLimit, 0)
    frame.head:SetJustifyH("LEFT")
    frame.head:SetWordWrap(false)
    if frame.head.SetShadowOffset then
      frame.head:SetShadowOffset(1, -1)
      frame.head:SetShadowColor(0, 0, 0, 1)
    end
  end
  if frame.sub then
    EnsureFont(frame.sub, m.small, "")
    frame.sub:ClearAllPoints()
    frame.sub:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, -4)
    frame.sub:SetPoint("RIGHT", frame, "RIGHT", -rightLimit, 0)
    frame.sub:SetWordWrap(false)
    if frame.sub.SetMaxLines then
      frame.sub:SetMaxLines(1)
    end
    if frame.sub.SetShadowOffset then
      frame.sub:SetShadowOffset(1, -1)
      frame.sub:SetShadowColor(0, 0, 0, 1)
    end
  end
  if frame.headRule then
    frame.headRule:ClearAllPoints()
    frame.headRule:SetPoint("TOPLEFT", frame, "TOPLEFT", m.pad, -(m.attic - GRID.s + 2))
    frame.headRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -m.pad, -(m.attic - GRID.s + 2))
  end
  -- Action bar: its own row between the content and the tabs.
  if frame.actionBar then
    frame.actionBar:ClearAllPoints()
    frame.actionBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", m.pad, m.barY)
    frame.actionBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -m.pad + 6, m.barY)
    frame.actionBar:SetHeight(m.barH)
  end
  if frame.footer then
    EnsureFont(frame.footer, m.small, "")
  end
  if frame.nockTitlePlate then
    frame.nockTitlePlate:SetSize(math.min(560, m.w - 240), 64)
    frame.nockTitlePlate:ClearAllPoints()
    frame.nockTitlePlate:SetPoint("TOP", frame, "TOP", 0, 4)
  end
  if frame.nockTitleFS then
    EnsureFont(frame.nockTitleFS, m.title, "OUTLINE")
  end
  if frame.viewButton then
    frame.viewButton:ClearAllPoints()
    frame.viewButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -14)
  end
  for _, sc in ipairs(UI.scrolls or {}) do
    if sc.child and sc.child.SetWidth then
      sc.child:SetWidth(CONTENT_W)
    end
  end
  for _, page in pairs(UI.pages) do
    if page.OnResize then
      pcall(page.OnResize, page, m)
    end
  end
  if UI.LayoutTabs then
    UI.LayoutTabs()
  end
  if UI.LayoutActionBar then
    UI.LayoutActionBar()
  end
  if frame.nockCarveLayout then
    pcall(frame.nockCarveLayout)
  end
  return m
end

-- Help text on the left, the visible page's buttons right-aligned. The text
-- gets whatever width the buttons leave and is cut to one line.
function UI.LayoutActionBar()
  local bar = frame and frame.actionBar
  if not bar then
    return
  end
  local used = 0
  local page = UI.pages[UI.tab or ""]
  for _, b in ipairs(page and page.buttons or {}) do
    if b:IsShown() then
      used = used + (tonumber((b:GetWidth())) or 100) + GRID.s
    end
  end
  local w = tonumber((bar:GetWidth())) or (W - 2 * GRID.gutter)
  if frame.footer then
    local x = 4
    if frame.lockIcon and frame.lockIcon:IsShown() then
      frame.lockIcon:ClearAllPoints()
      frame.lockIcon:SetPoint("LEFT", bar, "LEFT", 4, 0)
      x = 4 + 14 + 6
    end
    frame.footer:ClearAllPoints()
    frame.footer:SetPoint("LEFT", bar, "LEFT", x, 0)
    frame.footer:SetWidth(math.max(80, w - used - x - GRID.l))
    frame.footer:SetWordWrap(false)
  end
end

function UI.RestyleChrome()
  if not frame then
    return
  end
  local Theme = _G.NockTheme
  if not Theme then
    return
  end
  if Theme.SolidFill then
    Theme.SolidFill(frame)
  end
  if frame.nockTitleFS and Theme.color and Theme.color.title then
    local c = Theme.color.title
    frame.nockTitleFS:SetTextColor(c[1], c[2], c[3])
  end
  if Theme.SkinClose and frame.CloseButton then
    Theme.SkinClose(frame.CloseButton, 26)
  end
end

local TAB_INFO = {
  { key = "myrot", label = "My Rotation", tip = "What YOU should press at your level, with the keys you have bound right now. Built out of combat." },
  { key = "talents", label = "Talents", tip = "The selected profile's talent order and what you have learned." },
  { key = "profiles", label = "Profiles", tip = "Pick a build, preview its keys, then apply it. Also the options." },
  { key = "rotation", label = "Rotation", tip = "How to play the selected profile, written out." },
  { key = "macros", label = "Macros", tip = "Every macro Nock creates, plus extras you can paste yourself." },
  { key = "manual", label = "Field Manual", tip = "Forever hunter facts, spell by spell, and the Auto Shot rules." },
  { key = "advanced", label = "Guide", tip = "Profiles, the written rotation, macros and the Field Manual." },
  { key = "kit", label = "Tools", tip = "Hunter tools: your pet, supplies, where to level, what to train, rare beasts, Wing Clip and your session." },
  { key = "options", label = "Options", tip = "Key bar, glow, crosshair, opener tokens, fade, Hunting Notes and setup." },
}
-- Simple view (the default since 1.8): only My Rotation, Talents and More.
local SIMPLE_TABS = { myrot = true, talents = true, advanced = true, kit = true, options = true }
local function IsSimple()
  return NockCharDB.view ~= "advanced"
end
UI.IsSimple = IsSimple
local TAB_INDEX = {}
for i, t in ipairs(TAB_INFO) do
  TAB_INDEX[t.key] = i
end
local TAB_ALIAS = { keys = "profiles", guide = "manual", notes = "manual", plan = "talents", myrotation = "myrot", mine = "myrot", more = "advanced", options = "options", settings = "options", tools = "kit", fieldkit = "kit" }

local function SavePosition(f)
  local point, _, relPoint, x, y = f:GetPoint(1)
  if point then
    NockDB.uiPos = { point, relPoint, x, y }
  end
end

local function RestorePosition(f)
  f:ClearAllPoints()
  local pos = NockDB.uiPos
  if type(pos) == "table" and pos[1] then
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
end

local function SetPortrait(f)
  -- 2.0: the Emerald Dream moon crest, then the hunter class icon.
  local T = _G.NockTheme
  if T and f.SetPortraitToAsset and pcall(f.SetPortraitToAsset, f, T.tex.crest) then
    return
  end
  local ptex = Field(Field(f, "PortraitContainer"), "portrait") or Field(f, "portrait")
  if T and ptex and pcall(ptex.SetTexture, ptex, T.tex.crest) then
    return
  end
  if f.SetPortraitToClassIcon and pcall(f.SetPortraitToClassIcon, f, "HUNTER") then
    return
  end
  if f.SetPortraitToAsset and pcall(f.SetPortraitToAsset, f, HUNTER_ICON) then
    return
  end
  local tex = Field(Field(f, "PortraitContainer"), "portrait") or Field(f, "portrait")
  if tex then
    if SetPortraitToTexture then
      pcall(SetPortraitToTexture, tex, HUNTER_ICON)
    else
      tex:SetTexture(HUNTER_ICON)
    end
  end
end

local function SetTitle(f, text)
  if f.SetTitle and pcall(f.SetTitle, f, text) then
    return
  end
  local fs = Field(Field(f, "TitleContainer"), "TitleText") or Field(f, "TitleText")
  if not fs then
    fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    EnsureFont(fs, "GameFontNormal")
    fs:SetPoint("TOP", 0, -5)
    f.nockTitle = fs
  end
  fs:SetText(text)
end

local function MakePage(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetPoint("TOPLEFT", 4, -4)
  p:SetPoint("BOTTOMRIGHT", -4, 4)
  p:Hide()
  return p
end

local scrollCount = 0
local function MakeScroll(parent, top, bottom)
  scrollCount = scrollCount + 1
  local name = "NockScroll" .. scrollCount
  local scroll = TryCreate("ScrollFrame", name, parent, "ScrollFrameTemplate", "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, top or -8)
  scroll:SetPoint("BOTTOMRIGHT", -30, bottom or 8)
  -- 3.5.0: the scrollbar lives in a dark lane inside the content area.
  local lane = parent:CreateTexture(nil, "BACKGROUND")
  lane:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
  lane:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 24, 0)
  lane:SetColorTexture(0, 0, 0, 0.28)
  scroll.lane = lane
  local bar = Field(scroll, "ScrollBar") or _G[name .. "ScrollBar"]
  if bar and bar.ClearAllPoints then
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, -16)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 16)
  end
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(CONTENT_W, 20)
  scroll:SetScrollChild(child)
  scroll.child = child
  UI.scrolls = UI.scrolls or {}
  UI.scrolls[#UI.scrolls + 1] = scroll
  return scroll, child
end

local BuildProfilesPage, BuildTalentsPage, BuildRotationPage, BuildMacrosPage, BuildManualPage
local RefreshPage = {}

local function CreateMain()
  if frame then
    return frame
  end
  local f = TryCreate("Frame", "NockFrame", UIParent, "ButtonFrameTemplate", "PortraitFrameTemplate", "BackdropTemplate")
  local m = UI.WindowMetrics and UI.WindowMetrics() or { w = W, h = H }
  W, H = m.w or W, m.h or H
  CONTENT_W = m.content or CONTENT_W
  f:SetSize(W, H)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)
  f:Hide()
  tinsert(UISpecialFrames, "NockFrame")
  RestorePosition(f)

  -- 2.2: carved moonwood chrome from Benjamin's sheet. Hide the default
  -- portrait-frame border so our bark, corners and title plaque can sit cleanly.
  local Theme = _G.NockTheme
  if Theme and Theme.HideDefaultChrome then
    Theme.HideDefaultChrome(f)
    if Theme.SolidFill then
      Theme.SolidFill(f)
    end
    -- Opaque fill (alpha 1) so no leftover tan can show through the panel.
    Theme.TileFill(f, "bg", 256, 256, "BACKGROUND", -7, 1)
    Theme.CarveBorder(f, { cornerSize = 56, edge = 24, cornerOffset = -1, ornament = true })
    Theme.TitlePlate(f, "Nock", { width = math.min(560, W - 200), height = 64, y = 4, fontSize = (m and m.title) or 22 })
  elseif not Field(f, "NineSlice") and not Field(f, "Bg") then
    Backdrop(f, TOOLTIP_BACKDROP, 0.05, 0.05, 0.05, 0.96, 0.7, 0.7, 0.7, 1)
  end

  SetTitle(f, "Nock")
  -- Portrait stays available as a fallback if chrome hiding failed.
  if not (Theme and f.nockTitlePlate) then
    SetPortrait(f)
  end

  if not Field(f, "CloseButton") then
    local c = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    c:SetPoint("TOPRIGHT", -8, -8)
    f.CloseButton = c
  end
  if Theme and Theme.SkinClose then
    local c = Field(f, "CloseButton")
    Theme.SkinClose(c, 26)
    if c and c.ClearAllPoints then
      c:ClearAllPoints()
      c:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    end
  end

  -- Gear in the title bar: simple view <-> all tabs.
  local gear = CreateFrame("Button", nil, f)
  gear:SetSize(18, 18)
  gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -14)
  local gi = gear:CreateTexture(nil, "ARTWORK")
  gi:SetAllPoints()
  gi:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  gi:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  gear.icon = gi
  gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  gear:SetScript("OnClick", function()
    Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    UI.SetView(IsSimple() and "advanced" or "simple")
  end)
  AttachTip(gear, function()
    if IsSimple() then
      return "Show all tabs", { "Simple view is on: My Rotation, Talents, Guide and Options.", { "Click to show every tab (Profiles, Rotation, Macros, Field Manual). Same as /nock advanced.", 0.6, 0.6, 0.6 } }
    end
    return "Simple view", { "Show only My Rotation, Talents, Guide and Options. Same as /nock simple." }
  end)
  f.viewButton = gear

  local inset = Field(f, "Inset")
  if not inset then
    inset = TryCreate("Frame", nil, f, "InsetFrameTemplate", "BackdropTemplate")
    inset:SetPoint("TOPLEFT", 16, -160)
    inset:SetPoint("BOTTOMRIGHT", -16, 88)
    if not Field(inset, "NineSlice") then
      Backdrop(inset, TOOLTIP_BACKDROP, 0, 0, 0, 0.25, 0.25, 0.22, 0.20, 1)
    end
  else
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 16, -160)
    inset:SetPoint("BOTTOMRIGHT", -16, 88)
  end
  f.content = inset
  -- 2.2: the window itself now has the carved border; the inset is a quieter inner page.
  if inset.NineSlice and inset.NineSlice.Hide then
    pcall(inset.NineSlice.Hide, inset.NineSlice)
  end
  if inset.SetBackdrop then
    pcall(inset.SetBackdrop, inset, nil)
  end
  if Theme then
    if Theme.TintNineSlice then
      Theme.TintNineSlice(inset)
    end
  end

  -- Attic: page title and context on the left, profile switcher on the right.
  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(head, (m and m.header) or 22, "OUTLINE")
  head:SetPoint("TOPLEFT", 24, -72)
  head:SetTextColor(0.95, 0.88, 0.55)
  f.head = head
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  EnsureFont(sub, (m and m.body) or 16, "OUTLINE")
  sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
  sub:SetPoint("RIGHT", f, "RIGHT", -200, 0)
  sub:SetJustifyH("LEFT")
  sub:SetJustifyV("TOP")
  sub:SetWordWrap(true)
  sub:SetTextColor(0.82, 0.86, 0.78)
  f.sub = sub

  f.switch = {}
  local prev
  local order = ProfileOrder()
  for i = #order, 1, -1 do
    local key = order[i]
    local b = CreateFrame("Button", nil, f)
    b:SetSize(26, 26)
    if prev then
      b:SetPoint("RIGHT", prev, "LEFT", -7, 0)
    else
      b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -76)
    end
    local ring = b:CreateTexture(nil, "BACKGROUND")
    ring:SetPoint("TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", 2, -2)
    ring:SetColorTexture(1, 0.82, 0, 1)
    b.ring = ring
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    SetIcon(icon, PROFILE_ICONS[key])
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon
    local check = b:CreateTexture(nil, "OVERLAY")
    check:SetSize(14, 14)
    check:SetPoint("BOTTOMRIGHT", 4, -4)
    SetAtlasOr(check, STATE_ART.learned.atlas, STATE_ART.learned.file)
    b.check = check
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
      Sound("IG_QUEST_LIST_SELECT")
      UI.sel = key
      UI.Refresh()
    end)
    AttachTip(b, function()
      local p = Profiles()[key]
      local active = Active()
      return p.label, {
        BuildString(p.build) .. "  " .. (PROFILE_BLURB[key] or ""),
        (active and active.key == key) and { "Active profile", 0.1, 1, 0.1 } or "",
        { "Click to show this profile on every tab.", 0.6, 0.6, 0.6 },
      }
    end)
    f.switch[key] = b
    prev = b
  end
  if prev then
    local switchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    EnsureFont(switchLabel, "GameFontDisableSmall")
    switchLabel:SetPoint("RIGHT", prev, "LEFT", -8, 0)
    switchLabel:SetText("Profile")
    f.switchLabel = switchLabel
  end

  -- 3.5.0: a dedicated action-bar row (help text + page buttons) above the tabs.
  local actionBar = CreateFrame("Frame", nil, f)
  actionBar:SetHeight(GRID.barH)
  actionBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", GRID.gutter, 54)
  actionBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -GRID.gutter + 6, 54)
  f.actionBar = actionBar
  local headRule = f:CreateTexture(nil, "BORDER")
  headRule:SetHeight(1)
  f.headRule = headRule

  local footer = actionBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  EnsureFont(footer, 14, "")
  footer:SetPoint("LEFT", actionBar, "LEFT", 4, 0)
  footer:SetJustifyH("LEFT")
  footer:SetJustifyV("BOTTOM")
  footer:SetWordWrap(true)
  footer:SetWidth(CONTENT_W - 24)
  footer:SetTextColor(0.72, 0.76, 0.70)
  f.footer = footer
  local lock = actionBar:CreateTexture(nil, "OVERLAY")
  lock:SetSize(14, 14)
  lock:SetPoint("LEFT", actionBar, "LEFT", 4, 0)
  SetAtlasOr(lock, STATE_ART.locked.atlas, STATE_ART.locked.file)
  lock:Hide()
  f.lockIcon = lock

  -- 3.5.0: bottom tabs attached to the frame's lower edge, sized from their
  -- labels and fitted to the frame (UI.LayoutTabs).
  for i, info in ipairs(TAB_INFO) do
    local tab = CreateFrame("Button", "NockFrameTab" .. i, f)
    tab:SetID(i)
    tab.nockKey = info.key
    tab:SetHeight(GRID.tabH)
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    tab.bg = bg
    tab.edges = {}
    for j, spec in ipairs({ { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
      local e = tab:CreateTexture(nil, "BORDER")
      e:SetPoint(spec[1])
      e:SetPoint(spec[2])
      if spec[3] then e:SetHeight(1) else e:SetWidth(1) end
      tab.edges[j] = e
    end
    local ul = tab:CreateTexture(nil, "OVERLAY")
    ul:SetHeight(2)
    ul:SetPoint("TOPLEFT", 1, 0)
    ul:SetPoint("TOPRIGHT", -1, 0)
    tab.underline = ul
    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)
    local fs = tab:CreateFontString(nil, "OVERLAY")
    EnsureFont(fs, 16, "")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetPoint("RIGHT", -6, 0)
    fs:SetWordWrap(false)
    if fs.SetShadowOffset then
      fs:SetShadowOffset(1, -1)
      fs:SetShadowColor(0, 0, 0, 1)
    end
    fs:SetText(info.label)
    tab.label = fs
    tab:SetWidth(100)
    tab:SetScript("OnClick", function()
      Sound("IG_CHARACTER_INFO_TAB")
      UI.SelectTab(info.key)
    end)
    local function TabTip(self)
      ShowTip(self, info.label, { info.tip }, "ANCHOR_BOTTOM")
    end
    if tab.HookScript then
      tab:HookScript("OnEnter", TabTip)
      tab:HookScript("OnLeave", HideTip)
    else
      tab:SetScript("OnEnter", TabTip)
      tab:SetScript("OnLeave", HideTip)
    end
    UI.tabs[i] = tab
  end
  if PanelTemplates_SetNumTabs then
    pcall(PanelTemplates_SetNumTabs, f, #TAB_INFO)
  end

  f:SetScript("OnShow", function()
    Sound("IG_CHARACTER_INFO_OPEN")
    UI.Refresh()
  end)
  f:SetScript("OnHide", function()
    Sound("IG_CHARACTER_INFO_CLOSE")
    if copyFrame then
      copyFrame:Hide()
    end
  end)

  frame = f
  UI.frame = f
  UI.pages.profiles = BuildProfilesPage(MakePage(inset))
  UI.pages.talents = BuildTalentsPage(MakePage(inset))
  UI.pages.rotation = BuildRotationPage(MakePage(inset))
  UI.pages.macros = BuildMacrosPage(MakePage(inset))
  UI.pages.manual = BuildManualPage(MakePage(inset))
  for key, build in pairs(UI.extraPages or {}) do
    UI.pages[key] = build(MakePage(inset))
  end
  if UI.ApplyWindowSize then
    UI.ApplyWindowSize()
  end
  return f
end

local function HeaderFor(tab, p)
  local level = Nock.PlayerLevel and Nock.PlayerLevel() or 1
  if tab == "profiles" then
    local active = Active()
    return "Profiles", active and ("Active: |c" .. HUNTER_HEX .. active.label .. "|r  ·  level " .. level .. " hunter")
      or ("No profile applied yet  ·  level " .. level .. " hunter")
  elseif tab == "talents" then
    return "Talent Plan", p.label .. "  ·  one point per level from 10"
  elseif tab == "rotation" then
    return "Rotation", p.label .. "  ·  read it before the fight, decide in the fight"
  elseif tab == "advanced" then
    return "Guide", "Profiles, the written rotation, macros and the Field Manual"
  elseif tab == "options" then
    return "Options", p.label .. "  ·  everything here can be turned off"
  elseif tab == "myrot" then
    return "My Rotation", p.label .. "  ·  level " .. level .. "  ·  built from your spellbook, keys and bars"
  elseif tab == "macros" then
    return "Macros", p.label .. "  ·  one global-cooldown spell per press"
  elseif tab == "kit" then
    local C = Nock.Core and Nock.Core.P
    local mode = (Nock.Core and Nock.Core.IsEndgame()) and "endgame" or "leveling"
    return "Hunter Tools", string.format("Field Kit  ·  level %d  ·  %s  ·  %s", level, C and C.spec or "hunter", mode)
  end
  return "Field Manual", (SPEC_NAME[p.spec] or "Hunter") .. "  ·  Forever 1.60.1 hunter notes"
end

function UI.Refresh()
  if not frame or not frame:IsShown() then
    return
  end
  local p = Selected()
  if not p then
    return
  end
  local tab = UI.tab or "myrot"
  local head, sub = HeaderFor(tab, p)
  frame.head:SetText(head)
  frame.sub:SetText(sub)
  local active = Active()
  for key, b in pairs(frame.switch) do
    b.ring:SetShown(key == UI.sel)
    b.icon:SetDesaturated(key ~= UI.sel)
    b.check:SetShown(active and active.key == key or false)
  end
  if InCombat() then
    frame.footer:SetText("|cffff4040In combat:|r changes unlock when combat ends.")
    frame.lockIcon:Show()
  else
    frame.footer:SetText(UI.pages[tab] and UI.pages[tab].footer or "")
    frame.lockIcon:Hide()
  end
  UI.LayoutActionBar()
  if RefreshPage[tab] then
    RefreshPage[tab](UI.pages[tab], p)
  end
  UpdateButtonStates()
end

function UI.SelectTab(key)
  key = TAB_ALIAS[key] or key
  if not TAB_INDEX[key] then
    key = "myrot"
  end
  if key == "advanced" and not IsSimple() then
    key = "profiles"
  end
  UI.tab = key
  NockCharDB.uiTab = key
  for k, page in pairs(UI.pages) do
    page:SetShown(k == key)
    if page.buttons then
      for _, b in ipairs(page.buttons) do
        b:SetShown(k == key)
      end
    end
  end
  UI.LayoutTabs()
  local visual = key
  if IsSimple() and not SIMPLE_TABS[key] then
    visual = "advanced"
  end
  if PanelTemplates_SetTab and frame then
    pcall(PanelTemplates_SetTab, frame, TAB_INDEX[visual])
  end
  UI.Refresh()
end

-- Shows the tabs for the current view and fits them to the frame: natural
-- widths if they fit, then a smaller label size, then equal widths.
function UI.LayoutTabs()
  if not frame then
    return
  end
  local m = UI.metrics or UI.WindowMetrics()
  local simple = IsSimple()
  local visual = UI.tab or "myrot"
  if simple and not SIMPLE_TABS[visual] then
    visual = "advanced"
  end
  local shown = {}
  for i, info in ipairs(TAB_INFO) do
    local tab = UI.tabs[i]
    local show
    if simple then
      show = SIMPLE_TABS[info.key] and true or false
    else
      show = info.key ~= "advanced"
    end
    tab:SetShown(show)
    if show then
      shown[#shown + 1] = tab
    end
  end
  local avail = (m.w or W) - 2 * GRID.gutter
  local gap = 4
  local function natural(font)
    local sum = 0
    for _, tab in ipairs(shown) do
      EnsureFont(tab.label, font, "")
      tab.nw = math.max(72, (tonumber((tab.label:GetStringWidth())) or 70) + 2 * GRID.l)
      sum = sum + tab.nw
    end
    return sum + gap * (#shown - 1)
  end
  local font = m.tabFont or 16
  local total = natural(font)
  while total > avail and font > 12 do
    font = font - 1
    total = natural(font)
  end
  local equal = total > avail and math.floor((avail - gap * (#shown - 1)) / math.max(1, #shown)) or nil
  local th = _G.NockTheme
  local c = th and th.color or {}
  local trim = c.trim or { 0.50, 0.66, 0.60 }
  local wood = c.wood or { 0.07, 0.12, 0.10 }
  local accent = c.emerald or { 0.25, 0.89, 0.60 }
  local prev
  for _, tab in ipairs(shown) do
    tab:SetSize(equal or tab.nw, GRID.tabH)
    tab:ClearAllPoints()
    if prev then
      tab:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", gap, 0)
    else
      tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", GRID.gutter, m.tabY or 16)
    end
    prev = tab
    local key = tab.nockKey
    local on = key == visual
    tab.bg:SetColorTexture(wood[1] + (on and 0.08 or 0), wood[2] + (on and 0.08 or 0), wood[3] + (on and 0.06 or 0), on and 1 or 0.85)
    for _, e in ipairs(tab.edges) do
      e:SetColorTexture(trim[1], trim[2], trim[3], on and 0.8 or 0.4)
    end
    tab.underline:SetColorTexture(accent[1], accent[2], accent[3], 1)
    tab.underline:SetShown(on)
    if on then
      tab.label:SetTextColor(0.98, 0.92, 0.62)
    else
      tab.label:SetTextColor(0.74, 0.78, 0.72)
    end
  end
  for _, b in pairs(frame.switch or {}) do
    b:SetShown(not simple)
  end
  if frame.switchLabel then
    frame.switchLabel:SetShown(not simple)
  end
  if frame.viewButton then
    frame.viewButton.icon:SetDesaturated(simple)
  end
  if frame.headRule then
    frame.headRule:SetColorTexture(trim[1], trim[2], trim[3], 0.35)
  end
end

function UI.SetView(view)
  NockCharDB.view = view == "advanced" and "advanced" or "simple"
  if frame then
    local tab = UI.tab or "myrot"
    if IsSimple() and tab == "profiles" then
      tab = "advanced"
    end
    UI.SelectTab(tab)
  end
end

-- Bottom-bar buttons belong to a page and only show with it.
local function BarButton(page, text, width, opts)
  opts = opts or {}
  opts.height = opts.height or GRID.btnH
  local b = PanelButton(frame.actionBar or frame, text, width, opts)
  page.buttons = page.buttons or {}
  page.buttons[#page.buttons + 1] = b
  b:Hide()
  return b
end

local function SectionLabel(parent, text, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(fs, "GameFontNormal")
  fs:SetPoint("TOPLEFT", 14, y)
  fs:SetText(text)
  local line = parent:CreateTexture(nil, "BORDER")
  line:SetHeight(11)
  line:SetPoint("TOPLEFT", 8, y - 12)
  line:SetPoint("TOPRIGHT", -8, y - 12)
  local Theme = _G.NockTheme
  if Theme and Theme.SetTex and Theme.SetTex(line, "divider") then
    line:SetHeight(14)
  elseif not SetAtlasOr(line, "spellbook-divider", nil) then
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
  end
  return fs
end

-- Profiles tab ---------------------------------------------------------------------

local CARD_W, CARD_H = 336, 92

local function MakeCard(page, key)
  local c = CreateFrame("Button", nil, page, "BackdropTemplate")
  c:SetSize(CARD_W, CARD_H)
  Backdrop(c, TOOLTIP_BACKDROP, 0.06, 0.06, 0.06, 0.9, 0.45, 0.45, 0.45, 1)
  c:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  local hl = c:GetHighlightTexture()
  if hl then
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", 4, -4)
    hl:SetPoint("BOTTOMRIGHT", -4, 4)
    hl:SetAlpha(0.35)
  end
  local icon = c:CreateTexture(nil, "ARTWORK")
  icon:SetSize(44, 44)
  icon:SetPoint("TOPLEFT", 12, -12)
  SetIcon(icon, PROFILE_ICONS[key])
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.icon = icon
  local frameArt = c:CreateTexture(nil, "OVERLAY")
  frameArt:SetSize(50, 50)
  frameArt:SetPoint("CENTER", icon, "CENTER", 0, 0)
  if not SetAtlasOr(frameArt, "UI-HUD-ActionBar-IconFrame", nil) then
    frameArt:Hide()
  end
  local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(title, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
  c.title = title
  local build = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  EnsureFont(build, "GameFontHighlight")
  build:SetPoint("TOPRIGHT", -12, -14)
  c.build = build
  local blurb = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(blurb, "GameFontDisableSmall")
  blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  c.blurb = blurb
  local why = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(why, "GameFontHighlightSmall")
  why:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6)
  why:SetPoint("RIGHT", c, "RIGHT", -12, 0)
  why:SetJustifyH("LEFT")
  why:SetJustifyV("TOP")
  if why.SetMaxLines then
    why:SetMaxLines(2)
  end
  why:SetTextColor(0.82, 0.82, 0.82)
  c.why = why
  local activeText = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(activeText, "GameFontNormalSmall")
  activeText:SetPoint("TOPRIGHT", build, "BOTTOMRIGHT", 0, -6)
  activeText:SetTextColor(0.1, 1, 0.1)
  activeText:SetText("Active")
  local check = c:CreateTexture(nil, "OVERLAY")
  check:SetSize(16, 16)
  check:SetPoint("RIGHT", activeText, "LEFT", -2, 0)
  SetAtlasOr(check, STATE_ART.learned.atlas, STATE_ART.learned.file)
  c.check, c.activeText = check, activeText
  c:SetScript("OnClick", function()
    Sound("IG_QUEST_LIST_SELECT")
    UI.sel = key
    UI.Refresh()
  end)
  AttachTip(c, function()
    local p = Profiles()[key]
    return p.label, {
      BuildString(p.build) .. "   " .. (PROFILE_BLURB[key] or ""),
      p.why,
      { "Source: " .. (p.source or ""), 0.6, 0.6, 0.6 },
      { "Click to preview it. Apply Profile sets keys, bars and macros. Talents are only spent when you click Learn.", 0.1, 1, 0.1 },
    }
  end)
  return c
end

local function MakePreviewChip(page, w, h)
  local c = CreateFrame("Frame", nil, page, "BackdropTemplate")
  c:SetSize(w, h)
  Backdrop(c, TOOLTIP_BACKDROP, 0.05, 0.05, 0.05, 0.85, 0.4, 0.4, 0.4, 1)
  c:EnableMouse(true)
  local icon = c:CreateTexture(nil, "ARTWORK")
  icon:SetSize(h - 12, h - 12)
  icon:SetPoint("LEFT", 6, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.icon = icon
  local badge = MakeKeyBadge(c)
  badge:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
  badge:SetFrameLevel((c:GetFrameLevel() or 1) + 2)
  c.badge = badge
  local name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(name, "GameFontHighlightSmall")
  name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
  name:SetPoint("RIGHT", c, "RIGHT", -4, 0)
  name:SetJustifyH("LEFT")
  if name.SetMaxLines then
    name:SetMaxLines(2)
  end
  c.name = name
  AttachTip(c, function(self)
    local e = self.entry
    if not e then
      return nil
    end
    local lines = {}
    local known = Nock.EntryKnown and Nock.EntryKnown(e)
    lines[#lines + 1] = { "Key " .. KeyLabel(self.key) .. (e.kind == "macro" and ("   ·   macro " .. e.name) or ""), 1, 0.82, 0 }
    local note = e.note or (Nock.NOTES and Nock.NOTES[e.name])
    if note then
      lines[#lines + 1] = note
    end
    if e.kind == "macro" and e.macro then
      lines[#lines + 1] = { e.macro, 0.62, 0.82, 1 }
    end
    if not known then
      lines[#lines + 1] = { e.learnAt and ("Not learned yet (level " .. e.learnAt .. "). The key is saved for it.") or "Not learned yet. The key is saved for it.", 0.6, 0.6, 0.6 }
    end
    return Nock.EntryLabel and Nock.EntryLabel(e) or e.name, lines
  end)
  return c
end

local function PaintPreviewChip(c, key, entry)
  c.key, c.entry = key, entry
  if not entry then
    c:Hide()
    return
  end
  c:Show()
  local known = Nock.EntryKnown and Nock.EntryKnown(entry)
  c.badge:SetKey(key)
  SetIcon(c.icon, Nock.IconFor and Nock.IconFor(entry))
  c.icon:SetDesaturated(not known)
  c.icon:SetAlpha(known and 1 or 0.55)
  local label = Nock.EntryLabel and Nock.EntryLabel(entry) or entry.name
  if not known and entry.learnAt then
    label = label .. " |cff808080Lv " .. entry.learnAt .. "|r"
  end
  c.name:SetText(label)
  local shade = known and 1 or 0.55
  c.name:SetTextColor(shade, shade, shade)
  if c.SetBackdropBorderColor then
    if known then
      c:SetBackdropBorderColor(0.75, 0.62, 0.30, 1)
    else
      c:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end
  end
end

function UI.ApplySelected()
  local p = Selected()
  if not p then
    return
  end
  if InCombat() then
    return Print("Leave combat first — Nock only writes bars, binds and macros out of combat.")
  end
  Nock.ApplyProfile(p.key)
  if NockCharDB.profile == p.key and NockCharDB.applied then
    Sound("UI_CLASS_TALENT_LEARN_TALENT")
  end
  UI.Refresh()
  UI.UpdateBadges()
end

BuildProfilesPage = function(page)
  page.footer = "Out of combat only. Apply never spends talents."
  page.cards = {}
  for i, key in ipairs(ProfileOrder()) do
    local c = MakeCard(page, key)
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    c:SetPoint("TOPLEFT", 10 + col * (CARD_W + 10), -8 - row * (CARD_H + 8))
    page.cards[key] = c
  end

  page.previewLabel = SectionLabel(page, "Keyboard preview", -212)
  page.chips = {}
  local chipW, chipH, gap = 108, 40, 6
  for row, list in ipairs(Nock.CoreRows or {}) do
    for col, key in ipairs(list) do
      local c = MakePreviewChip(page, chipW, chipH)
      c:SetPoint("TOPLEFT", 12 + (col - 1) * (chipW + gap), -236 - (row - 1) * (chipH + gap))
      page.chips[key] = c
    end
  end
  local extra = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(extra, "GameFontHighlightSmall")
  extra:SetPoint("TOPLEFT", 14, -330)
  extra:SetPoint("RIGHT", page, "RIGHT", -14, 0)
  extra:SetJustifyH("LEFT")
  extra:SetSpacing(3)
  extra:SetTextColor(0.8, 0.8, 0.8)
  page.extra = extra

  SectionLabel(page, "Options", -382)
  local opts = {
    { "Keyboard card", "The floating card that shows what your number keys and Q-T do. Drag it anywhere.",
      function() return NockCharDB.overlay ~= false end,
      function(on) Nock.SetOverlayShown(on) end },
    { "Key badges on action buttons", "A small keycap on each action button that holds a Nock spell or macro, showing the key that casts it.",
      function() return NockCharDB.badges ~= false end,
      function(on) NockCharDB.badges = on; UI.UpdateBadges() end },
    { "Spell notes in chat", "When you learn a hunter spell, print one Forever tip about it in chat.",
      function() return NockCharDB.notes ~= false end,
      function(on) NockCharDB.notes = on end },
    { "Auto keep-up", "After a level-up, a new spell or a talent, Nock puts newly available spells and macros on their keys and bars (out of combat only) and says so in chat. Keys you rebound yourself are left alone.",
      function() return NockCharDB.autofill ~= false end,
      function(on) NockCharDB.autofill = on end },
  }
  page.checks = {}
  for i, o in ipairs(opts) do
    local cb = CheckBox(page, o[1], o[2], o[3], o[4])
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    cb:SetPoint("TOPLEFT", 12 + col * 340, -404 - row * 28)
    page.checks[#page.checks + 1] = cb
  end
  for _, hook in ipairs(UI.profileOptionHooks or {}) do
    hook(page, CheckBox)
  end

  local apply = BarButton(page, "Apply Profile", 150, {
    lock = true,
    tip = "Binds this profile's keys, puts its spells and macros on your bars and creates its macros. Your old keys are saved first, so Restore Keys can undo it.",
    sound = "GS_TITLE_OPTION_OK",
    onClick = function()
      UI.ApplySelected()
    end,
  })
  apply:SetPoint("BOTTOMRIGHT", -6, 4)
  page.apply = apply
  local glow = apply:CreateTexture(nil, "OVERLAY")
  glow:SetPoint("TOPLEFT", -8, 8)
  glow:SetPoint("BOTTOMRIGHT", 8, -8)
  if SetAtlasOr(glow, "newplayertutorial-yellowGlow-redbutton-middle", nil) then
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.55)
    page.hasGlow = true
  end
  glow:Hide()
  page.applyGlow = glow

  local restore = BarButton(page, "Restore Keys", 120, {
    lock = true,
    tip = "Puts back the keybinds Nock found before your first apply.",
    allowed = function()
      if not NockCharDB.snapshot then
        return false, "Nothing to restore yet. Nock saves your keys the first time you apply."
      end
      return true
    end,
    onClick = function()
      Confirm("NOCK_RESTORE_KEYS", "Put back the keybinds Nock found before your first apply?", function()
        Nock.RestoreKeys()
        UI.UpdateBadges()
      end)
    end,
  })
  restore:SetPoint("RIGHT", apply, "LEFT", -8, 0)

  local detect = BarButton(page, "Detect", 80, {
    tip = "Picks the profile that matches your talent points and level. It only selects; it doesn't apply.",
    onClick = function()
      local spec, why = Nock.DetectSpec()
      local level = Nock.PlayerLevel and Nock.PlayerLevel() or 1
      if spec == "bm" then
        UI.sel = level >= 60 and "bm60" or "bmlvl"
      else
        UI.sel = level >= 60 and "mm60" or "mmlvl"
      end
      Print(why or ("Detected " .. (SPEC_NAME[spec] or spec) .. ": " .. Profiles()[UI.sel].label .. "."))
      UI.Refresh()
    end,
  })
  detect:SetPoint("RIGHT", restore, "LEFT", -8, 0)
  return page
end

RefreshPage.profiles = function(page, p)
  local active = Active()
  for key, c in pairs(page.cards) do
    local cp = Profiles()[key]
    c.title:SetText(cp.label)
    c.build:SetText(BuildString(cp.build))
    c.blurb:SetText((SPEC_NAME[cp.spec] or "") .. "  ·  " .. (PROFILE_BLURB[key] or ""))
    c.why:SetText(cp.why or "")
    local isActive = (active and active.key == key) and true or false
    c.check:SetShown(isActive)
    c.activeText:SetShown(isActive)
    if c.SetBackdropBorderColor then
      if key == UI.sel then
        c:SetBackdropBorderColor(1, 0.82, 0, 1)
        c:SetBackdropColor(0.16, 0.12, 0.03, 0.95)
      else
        c:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
        c:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
      end
    end
    c.icon:SetDesaturated(key ~= UI.sel and not isActive)
  end
  page.previewLabel:SetText("Keyboard preview  |cff808080" .. p.label .. "|r")
  local layout = LayoutForProfile(p)
  for key, c in pairs(page.chips) do
    PaintPreviewChip(c, key, layout[key])
  end
  page.extra:SetText("|cffffd100Also bound|r   " .. (Nock.ExtraLine and Nock.ExtraLine(layout) or ""))
  for _, cb in ipairs(page.checks) do
    cb:Sync()
  end
  local isActive = active and active.key == p.key
  page.applyGlow:SetShown((page.hasGlow and not isActive and not InCombat()) and true or false)
  page.apply:SetText(isActive and "Re-apply Profile" or "Apply Profile")
end

-- Talents tab ------------------------------------------------------------------------

local ROW_H = 26

local STATUS_TIP = {
  missing = "Nock can't find this talent by name. Your client language may differ; pick it by hand in the talent window.",
  next = "This is the point Learn Next buys.",
  learned = "Already learned.",
  available = "You can learn this now.",
}

local function MakeTalentRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(CONTENT_W, ROW_H)
  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  r.bg = bg
  local accent = r:CreateTexture(nil, "BORDER")
  accent:SetPoint("TOPLEFT")
  accent:SetPoint("BOTTOMLEFT")
  accent:SetWidth(2)
  accent:SetColorTexture(1, 0.82, 0, 1)
  r.accent = accent
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  local state = r:CreateTexture(nil, "ARTWORK")
  state:SetSize(16, 16)
  state:SetPoint("LEFT", 8, 0)
  r.state = state
  local lv = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(lv, "GameFontNormalSmall")
  lv:SetPoint("LEFT", 30, 0)
  lv:SetWidth(46)
  lv:SetJustifyH("LEFT")
  r.lv = lv
  local icon = r:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", 78, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.icon = icon
  local name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  EnsureFont(name, "GameFontHighlight")
  name:SetPoint("LEFT", 106, 0)
  name:SetWidth(280)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  r.name = name
  local pts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(pts, "GameFontHighlightSmall")
  pts:SetPoint("LEFT", 392, 0)
  pts:SetWidth(70)
  pts:SetJustifyH("CENTER")
  r.pts = pts
  local tree = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(tree, "GameFontNormalSmall")
  tree:SetPoint("LEFT", 466, 0)
  tree:SetWidth(40)
  tree:SetJustifyH("CENTER")
  r.tree = tree
  local status = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(status, "GameFontDisableSmall")
  status:SetPoint("RIGHT", -10, 0)
  status:SetWidth(140)
  status:SetJustifyH("RIGHT")
  r.status = status
  r:SetScript("OnEnter", function(self)
    local row = self.row
    if not row or not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shown = false
    if row.spellID and GameTooltip.SetSpellByID then
      shown = pcall(GameTooltip.SetSpellByID, GameTooltip, row.spellID)
    end
    if not shown then
      GameTooltip:SetText(row.name, 1, 0.82, 0)
    end
    GameTooltip:AddLine(" ")
    local steps = row.first == row.last and ("Step " .. row.first) or ("Steps " .. row.first .. "-" .. row.last)
    GameTooltip:AddLine(string.format("%s  ·  %d point%s in %s", steps, row.count, row.count == 1 and "" or "s",
      TREE[row.tree] and TREE[row.tree].name or tostring(row.tree)), 1, 1, 1, true)
    GameTooltip:AddLine(self.statusTip or "", 1, 0.82, 0, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", HideTip)
  return r
end

local function TalentIcon(row)
  if row.spellID and C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, row.spellID)
    if ok and tex then
      return tex
    end
  end
  return Nock.IconFor and Nock.IconFor(row.name) or QUESTION
end

local function PaintTalentRow(r, row, i, level)
  r.row = row
  local art = STATE_ART[row.state] or STATE_ART.available
  SetAtlasOr(r.state, art.atlas, art.file)
  r.state:SetDesaturated(row.state == "available")
  r.state:SetAlpha(row.state == "available" and 0.6 or 1)
  r.lv:SetText(row.levelFrom == row.levelTo and tostring(row.levelFrom) or (row.levelFrom .. "-" .. row.levelTo))
  SetIcon(r.icon, TalentIcon(row))
  r.name:SetText(row.name .. (row.count > 1 and ("  |cff808080x" .. row.count .. "|r") or ""))
  local t = TREE[row.tree]
  r.tree:SetText(t and ("|c" .. t.hex .. t.short .. "|r") or "")
  if row.rank then
    r.pts:SetText(string.format("%d / %d", math.min(row.rank, row.target), row.target))
  else
    r.pts:SetText("x" .. row.count)
  end
  local statusText
  if row.state == "learned" then
    statusText = "|cff20ff20Learned|r"
  elseif row.state == "next" then
    statusText = "|cffffd100Next point|r"
  elseif row.state == "locked" then
    statusText = "Level " .. row.levelFrom
  elseif row.state == "missing" then
    statusText = "|cffff4040Not in your tree|r"
  else
    statusText = row.done > 0 and (row.done .. " of " .. row.count .. " learned") or "Open now"
  end
  r.status:SetText(statusText)
  if row.state == "locked" then
    r.statusTip = "Unlocks at level " .. row.levelFrom .. ". You are level " .. level .. "."
  else
    r.statusTip = STATUS_TIP[row.state] or ""
  end
  local dim = row.state == "locked"
  if dim then
    r.name:SetTextColor(0.5, 0.5, 0.5)
  elseif row.state == "next" then
    r.name:SetTextColor(1, 0.82, 0)
  else
    r.name:SetTextColor(0.95, 0.95, 0.95)
  end
  r.icon:SetDesaturated(dim)
  r.icon:SetAlpha(dim and 0.6 or 1)
  if row.state == "next" then
    r.bg:SetColorTexture(1, 0.82, 0, 0.12)
    r.accent:Show()
  elseif i % 2 == 0 then
    r.bg:SetColorTexture(1, 1, 1, 0.035)
    r.accent:Hide()
  else
    r.bg:SetColorTexture(0, 0, 0, 0)
    r.accent:Hide()
  end
  r:Show()
end

BuildTalentsPage = function(page)
  page.footer = "Points are only spent when you click Learn."
  local icon = page:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT", 12, -10)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  page.icon = icon
  local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(title, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
  page.title = title
  local nextLine = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(nextLine, "GameFontHighlightSmall")
  nextLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  nextLine:SetPoint("RIGHT", page, "RIGHT", -236, 0)
  nextLine:SetJustifyH("LEFT")
  nextLine:SetWordWrap(false)
  page.nextLine = nextLine

  local bar = CreateFrame("StatusBar", nil, page, "BackdropTemplate")
  bar:SetSize(206, 16)
  bar:SetPoint("TOPRIGHT", -14, -12)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(HUNTER[1], HUNTER[2], HUNTER[3])
  bar:SetMinMaxValues(0, 51)
  Backdrop(bar, BADGE_BACKDROP, 0, 0, 0, 0.6, 0.6, 0.6, 0.6, 1)
  local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(barText, "GameFontHighlightSmall")
  barText:SetPoint("CENTER", 0, 0)
  page.bar, page.barText = bar, barText
  local unspent = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(unspent, "GameFontNormalSmall")
  unspent:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -6)
  page.unspent = unspent

  -- Column headings, like Blizzard's list headers.
  local cols = { { "Level", 30 }, { "Talent", 106 }, { "Points", 392, 70 }, { "Tree", 466, 40 } }
  for _, col in ipairs(cols) do
    local fs = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    EnsureFont(fs, "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 6 + col[2], -60)
    if col[3] then
      fs:SetWidth(col[3])
      fs:SetJustifyH("CENTER")
    end
    fs:SetText(col[1])
  end
  local statusHead = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(statusHead, "GameFontDisableSmall")
  statusHead:SetPoint("TOPRIGHT", -40, -60)
  statusHead:SetText("Status")
  local rule = page:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 8, -74)
  rule:SetPoint("TOPRIGHT", -8, -74)
  rule:SetHeight(1)
  rule:SetColorTexture(1, 0.82, 0, 0.25)

  local scroll, child = MakeScroll(page, -78, 6)
  page.scroll, page.child = scroll, child
  page.rows = {}

  local learnNext = BarButton(page, "Learn Next", 120, {
    lock = true,
    tip = "Spends one point on the next talent in this plan.",
    allowed = function()
      return page.canLearn, page.cantWhy
    end,
    onClick = function()
      Nock.LearnNextTalent(Selected())
      Sound("UI_CLASS_TALENT_LEARN_TALENT")
      if C_Timer then
        C_Timer.After(0.4, UI.Refresh)
      end
    end,
  })
  learnNext:SetPoint("BOTTOMRIGHT", -6, 4)
  local learnAll = BarButton(page, "Learn All", 110, {
    lock = true,
    tip = "Spends every unspent point you can, in plan order, and stops at the first talent the game won't take yet.",
    allowed = function()
      return page.canLearn, page.cantWhy
    end,
    onClick = function()
      local p = Selected()
      local n = page.unspentCount or 0
      Confirm("NOCK_LEARN_ALL", string.format("Learn up to %d talent point%s from %s now?", n, n == 1 and "" or "s", p.label), function()
        Nock.LearnAllTalents(p)
        Sound("UI_CLASS_TALENT_LEARN_TALENT")
        if C_Timer then
          C_Timer.After(0.4, UI.Refresh)
        end
      end)
    end,
  })
  learnAll:SetPoint("RIGHT", learnNext, "LEFT", -8, 0)
  local open = BarButton(page, "Open Talents", 120, {
    lock = true,
    tip = "Opens the Forever talent window (N).",
    onClick = function()
      if Nock.OpenTalentWindow then
        Nock.OpenTalentWindow()
      end
    end,
  })
  open:SetPoint("RIGHT", learnAll, "LEFT", -8, 0)
  return page
end

RefreshPage.talents = function(page, p)
  SetIcon(page.icon, PROFILE_ICONS[p.key])
  page.title:SetText(p.label .. "   " .. BuildString(p.build))
  local plan = Nock.PlanRows and Nock.PlanRows(p) or { rows = {}, done = 0, total = 51 }
  page.bar:SetMinMaxValues(0, plan.total)
  page.bar:SetValue(plan.done)
  page.barText:SetText(string.format("%d / %d points", plan.done, plan.total))
  page.unspentCount = plan.unspent
  if plan.hasTraits then
    page.unspent:SetText("Unspent points: |cffffffff" .. tostring(plan.unspent or "?") .. "|r")
  else
    page.unspent:SetText("|cff808080Talent progress unavailable|r")
  end
  if plan.nextStep then
    page.nextLine:SetText(string.format("Next: |cffffd100%s|r  ·  step %d, level %d", plan.nextStep.name, plan.nextIndex, plan.nextStep.level))
  elseif plan.hasTraits then
    page.nextLine:SetText("|cff20ff20This plan is complete.|r")
  else
    page.nextLine:SetText(plan.err or "Showing the full order.")
  end
  if not plan.canLearn then
    page.canLearn, page.cantWhy = false, plan.err or "This client doesn't let Nock learn talents. Use the talent window (N)."
  elseif not plan.nextStep then
    page.canLearn, page.cantWhy = false, "Nothing left to learn in this plan."
  elseif plan.unspent ~= nil and plan.unspent <= 0 then
    page.canLearn, page.cantWhy = false, "You have no unspent talent points."
  else
    page.canLearn, page.cantWhy = true, nil
  end
  for i, row in ipairs(plan.rows) do
    local r = page.rows[i]
    if not r then
      r = MakeTalentRow(page.child)
      r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
      page.rows[i] = r
    end
    PaintTalentRow(r, row, i, plan.level or 1)
  end
  for i = #plan.rows + 1, #page.rows do
    page.rows[i]:Hide()
  end
  page.child:SetHeight(math.max(20, #plan.rows * ROW_H + 6))
end

-- Rotation tab ---------------------------------------------------------------------

BuildRotationPage = function(page)
  page.footer = "Written priority only. Nock never watches the fight or picks your next shot."
  local _, child = MakeScroll(page, -6, 6)
  page.flow = NewFlow(child, CONTENT_W - 8)
  return page
end

RefreshPage.rotation = function(page, p)
  local flow = page.flow
  flow:Reset()
  local lines = {}
  for _, l in ipairs(p.rotation or {}) do
    lines[#lines + 1] = l
  end
  -- The first line is the page title; show it with the profile icon instead.
  local first = table.remove(lines, 1) or string.upper(p.label)
  flow:Header(TitleCase(first), BuildString(p.build) .. "  ·  " .. (SPEC_NAME[p.spec] or ""), PROFILE_ICONS[p.key])
  RenderGuide(flow, lines)
  flow:Space(6)
  RenderGuide(flow, Nock.AutoShotRules or {})
  flow:Space(8)
  flow:Para("Source: " .. (p.source or ""), "GameFontDisableSmall")
  if Nock.ManualNote then
    flow:Para(Nock.ManualNote, "GameFontDisableSmall")
  end
  flow:Finish()
end

-- Macros tab -------------------------------------------------------------------------

local function MakeMacroCard(parent)
  local c = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  c:SetWidth(CONTENT_W - 8)
  Backdrop(c, TOOLTIP_BACKDROP, 0.05, 0.05, 0.05, 0.85, 0.4, 0.4, 0.4, 1)
  local icon = c:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT", 12, -12)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.icon = icon
  local badge = MakeKeyBadge(c, "NumberFontNormal")
  badge:SetPoint("TOPLEFT", icon, "TOPLEFT", -6, 6)
  badge:SetFrameLevel((c:GetFrameLevel() or 1) + 3)
  c.badge = badge
  local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(title, "GameFontNormal")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
  c.title = title
  local sub = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(sub, "GameFontDisableSmall")
  sub:SetPoint("LEFT", title, "RIGHT", 8, 0)
  c.sub = sub
  local desc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(desc, "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  desc:SetPoint("RIGHT", c, "RIGHT", -96, 0)
  desc:SetJustifyH("LEFT")
  desc:SetJustifyV("TOP")
  desc:SetTextColor(0.85, 0.85, 0.85)
  c.desc = desc
  local box = CreateFrame("Frame", nil, c, "BackdropTemplate")
  Backdrop(box, BADGE_BACKDROP, 0, 0, 0, 0.55, 0.3, 0.3, 0.3, 1)
  c.box = box
  local body = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(body, "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", 8, -6)
  body:SetPoint("RIGHT", box, "RIGHT", -8, 0)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetSpacing(2)
  body:SetTextColor(0.62, 0.82, 1)
  c.body = body
  local copy = PanelButton(c, "Copy", 76, {
    tip = "Shows the macro text highlighted so you can copy it with Ctrl+C.",
    onClick = function()
      ShowCopy(c.copyTitle or "Macro", c.copyBody or "")
    end,
  })
  copy:SetPoint("TOPRIGHT", -10, -10)
  c.copy = copy
  return c
end

local function PaintMacroCard(c, key, title, macroName, desc, body, icon, known, extraTag)
  if key then
    c.badge:SetKey(key)
    c.badge:Show()
  else
    c.badge:Hide()
  end
  SetIcon(c.icon, icon)
  c.icon:SetDesaturated(not known)
  c.title:SetText(title)
  c.sub:SetText((macroName or "") .. (extraTag and ("  " .. extraTag) or ""))
  c.desc:SetText(desc or "")
  c.body:SetText(body or "")
  c.copyTitle, c.copyBody = macroName or title, body or ""
  local descH = (desc and desc ~= "") and (c.desc:GetStringHeight() or 12) or 0
  local bodyH = (c.body:GetStringHeight() or 12) + 12
  local top = math.max(56, 12 + 16 + descH + 8)
  c.box:ClearAllPoints()
  c.box:SetPoint("TOPLEFT", c, "TOPLEFT", 58, -top)
  c.box:SetPoint("RIGHT", c, "RIGHT", -10, 0)
  c.box:SetHeight(bodyH)
  c:SetHeight(top + bodyH + 10)
  c:Show()
  return top + bodyH + 10
end

local MACRO_KEY_ORDER = { "1", "2", "3", "4", "5", "6", "Q", "E", "R", "T", "SHIFT-T", "ALT-T", "CTRL-G", "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-G", "ALT-G" }

BuildMacrosPage = function(page)
  page.footer = "Character macros, 255 characters max. Each press casts at most one global-cooldown spell."
  local _, child = MakeScroll(page, -6, 6)
  page.child = child
  page.flow = NewFlow(child, CONTENT_W - 8)
  page.cards = {}
  return page
end

RefreshPage.macros = function(page, p)
  local flow = page.flow
  flow:Reset()
  local layout = LayoutForProfile(p)
  local keys, seen = {}, {}
  for _, k in ipairs(MACRO_KEY_ORDER) do
    if layout[k] and layout[k].kind == "macro" then
      keys[#keys + 1] = k
      seen[k] = true
    end
  end
  local rest = {}
  for k, e in pairs(layout) do
    if e.kind == "macro" and not seen[k] then
      rest[#rest + 1] = k
    end
  end
  table.sort(rest)
  for _, k in ipairs(rest) do
    keys[#keys + 1] = k
  end
  local used = 0
  local function Card()
    used = used + 1
    local c = page.cards[used]
    if not c then
      c = MakeMacroCard(page.child)
      page.cards[used] = c
    end
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 4, flow.y)
    return c
  end
  flow:Header("Macros Nock creates and binds", #keys .. " character macros for " .. p.label .. ". Apply Profile creates them and binds them to these keys.")
  for _, k in ipairs(keys) do
    local e = layout[k]
    local known = Nock.EntryKnown and Nock.EntryKnown(e)
    local tag = e.slot and ("|cff808080· bar slot " .. e.slot .. "|r") or nil
    local h = PaintMacroCard(Card(), k, Nock.EntryLabel(e), e.name, e.note, e.macro, Nock.IconFor(e), known, tag)
    flow.y = flow.y - h - 6
  end
  flow:Space(6)
  flow:Header("More macros to paste yourself", "Nock doesn't create these. Copy one into /macro if you want it.")
  for _, item in ipairs(Nock.MacroLibrary or {}) do
    local h = PaintMacroCard(Card(), nil, item[1], nil, nil, item[2], Nock.IconFor({ macro = item[2] }), true, "|cff808080Not created by Nock|r")
    flow.y = flow.y - h - 6
  end
  for i = used + 1, #page.cards do
    page.cards[i]:Hide()
  end
  flow:Space(4)
  flow:Para("About /castsequence: Forever uses the modern macro system, so /castsequence works. It moves to the next spell only when a cast succeeds, and one press still casts one spell. Nock leaves it out because a failed step stalls the whole sequence.", "GameFontDisableSmall")
  flow:Finish()
end

-- Field Manual tab ---------------------------------------------------------------

BuildManualPage = function(page)
  page.footer = "Static notes from Forever guides and patch notes. No live combat checks."
  local callout = CreateFrame("Frame", nil, page, "BackdropTemplate")
  callout:SetPoint("TOPLEFT", 8, -8)
  callout:SetPoint("TOPRIGHT", -8, -8)
  callout:SetHeight(52)
  Backdrop(callout, TOOLTIP_BACKDROP, 0.16, 0.12, 0.03, 0.9, 1, 0.82, 0, 1)
  local arrow = callout:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(20, 20)
  arrow:SetPoint("LEFT", 12, 0)
  SetAtlasOr(arrow, STATE_ART.next.atlas, STATE_ART.next.file)
  local ctitle = callout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(ctitle, "GameFontNormal")
  ctitle:SetPoint("TOPLEFT", 40, -9)
  ctitle:SetText("What do I take next?")
  local ctext = callout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(ctext, "GameFontHighlightSmall")
  ctext:SetPoint("TOPLEFT", ctitle, "BOTTOMLEFT", 0, -4)
  ctext:SetPoint("RIGHT", callout, "RIGHT", -12, 0)
  ctext:SetJustifyH("LEFT")
  ctext:SetWordWrap(false)
  page.ctext = ctext
  local _, child = MakeScroll(page, -66, 6)
  page.flow = NewFlow(child, CONTENT_W - 8)
  return page
end

RefreshPage.manual = function(page, p)
  local spec = p.spec == "bm" and "bm" or "marks"
  local level = Nock.PlayerLevel and Nock.PlayerLevel() or 1
  page.ctext:SetText(Nock.NextTalentLine and Nock.NextTalentLine(spec, level) or "")
  local flow = page.flow
  flow:Reset()
  flow:Header("Spell notes", (SPEC_NAME[spec] or "") .. " order. Grey spells are ones you haven't learned yet.")
  local notes = Nock.NOTES or {}
  local shown, list = {}, {}
  for _, name in ipairs((Nock.FieldOrder and Nock.FieldOrder[spec]) or {}) do
    if notes[name] and not shown[name] then
      list[#list + 1] = name
      shown[name] = true
    end
  end
  local rest = {}
  for name in pairs(notes) do
    if not shown[name] then
      rest[#rest + 1] = name
    end
  end
  table.sort(rest)
  for _, name in ipairs(rest) do
    list[#list + 1] = name
  end
  for _, name in ipairs(list) do
    local known = name == "Auto Shot" or (Nock.PlayerKnows and Nock.PlayerKnows(name)) or false
    flow:IconRow(Nock.IconFor and Nock.IconFor(name), name, notes[name], known, (not known) and "not learned yet" or nil)
  end
  flow:Space(6)
  RenderGuide(flow, Nock.AutoShotRules or {})
  flow:Finish()
end

-- Opening ----------------------------------------------------------------------------

function UI.Toggle()
  if frame and frame:IsShown() then
    frame:Hide()
  else
    Nock.ShowPanel((IsSimple() and "myrot") or UI.tab or NockCharDB.uiTab or "myrot")
  end
end

function Nock.ShowPanel(tab, spec)
  if not (Nock.IsHunter and Nock.IsHunter()) then
    Print("This is a hunter addon. Log in on a hunter to use it.")
    return
  end
  local f = CreateMain()
  if spec then
    local p = Profiles()[UI.sel]
    if not p or p.spec ~= spec then
      local d = Nock.DefaultProfileFor and Nock.DefaultProfileFor(spec)
      if d then
        UI.sel = d.key
      end
    end
  end
  Selected()
  tab = TAB_ALIAS[tab] or tab or UI.tab or NockCharDB.uiTab or "myrot"
  if not f:IsShown() then
    f:Show()
  end
  UI.SelectTab(tab)
end

function Nock:Open()
  Nock.ShowPanel((IsSimple() and "myrot") or UI.tab or NockCharDB.uiTab or "myrot")
end

function Nock.OpenProfiles(key)
  if key and Profiles()[key] then
    UI.sel = key
  end
  Nock.ShowPanel("profiles")
end

function Nock.OpenGuide(spec)
  Nock.ShowPanel("manual", spec)
end

-- Action-button key badges --------------------------------------------------------
-- A small keycap in the corner of each action button that holds a Nock spell
-- or macro. Built and updated only out of combat.

local BAR_PREFIXES = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
  "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local badges = {}
local badgesDirty = false

local function ButtonSlot(btn)
  local slot = rawget(btn, "action")
  if type(slot) ~= "number" and btn.GetAttribute then
    local ok, v = pcall(btn.GetAttribute, btn, "action")
    if ok then
      slot = v
    end
  end
  return tonumber(slot)
end

local function KeyMaps(layout)
  local spells, macros = {}, {}
  local rank = {}
  for i, k in ipairs(Nock.KeycapOrder or {}) do
    rank[k] = i
  end
  for key, e in pairs(layout) do
    local map = e.kind == "macro" and macros or spells
    local cur = map[e.name]
    if not cur or (rank[key] or 99) < (rank[cur] or 99) then
      map[e.name] = key
    end
  end
  return spells, macros
end

local function SlotKey(slot, spells, macros)
  if not (slot and GetActionInfo) then
    return nil
  end
  local ok, kind, id = pcall(GetActionInfo, slot)
  if not ok or not kind then
    return nil
  end
  if kind == "spell" and id then
    local name = Nock.SpellData and Nock.SpellData(id)
    return name and spells[name]
  elseif kind == "macro" and id and GetMacroInfo then
    local name = GetMacroInfo(id)
    return name and macros[name]
  end
  return nil
end

function UI.UpdateBadges()
  if InCombat() then
    badgesDirty = true
    return
  end
  badgesDirty = false
  -- Never parent frames onto Blizzard ActionButtons. That taints their
  -- OnEvent / cooldown updates on Forever (secret SetCooldown). Nock's
  -- own tiles already draw key labels; this path is retired.
  for _, b in pairs(badges) do
    if b.Hide then
      b:Hide()
    end
  end
end

function UI.BadgeCount()
  local n = 0
  for _, b in pairs(badges) do
    if b:IsShown() then
      n = n + 1
    end
  end
  return n
end

function Nock.RefreshUI()
  if UI.ApplyWindowSize then
    UI.ApplyWindowSize()
  end
  UI.Refresh()
  UI.UpdateBadges()
end

Nock.RefreshProfilesFrame = Nock.RefreshUI

-- Minimap button (only when the client has no addon compartment) ---------------

local function CreateMinimapButton()
  if UI.minimap or AddonCompartmentFrame or not Minimap or NockDB.hideMinimap then
    return
  end
  local b = CreateFrame("Button", "NockMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture(HUNTER_ICON)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  local function Place()
    local angle = math.rad(NockDB.minimapAngle or 200)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
  end
  Place()
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      if mx and cx and scale then
        NockDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        Place()
      end
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnClick", function(_, button)
    _G.Nock_OnAddonCompartmentClick("Nock", button)
  end)
  AttachTip(b, function()
    return "Nock", { "Left-click: open Nock", "Right-click: keyboard card on or off", { "Drag to move", 0.6, 0.6, 0.6 } }
  end)
  UI.minimap = b
end

-- Addon compartment (TOC: AddonCompartmentFunc) -----------------------------------

function _G.Nock_OnAddonCompartmentClick(addonName, buttonName)
  if buttonName == "RightButton" then
    Nock.SetOverlayShown(not Nock.IsOverlayShown())
  else
    UI.Toggle()
  end
end

function _G.Nock_OnAddonCompartmentEnter(addonName, menuButton)
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(menuButton or UIParent, "ANCHOR_LEFT")
  GameTooltip:SetText("Nock", 1, 0.82, 0)
  local active = Active()
  GameTooltip:AddLine(active and ("Profile: " .. active.label) or "No profile applied yet", 1, 1, 1)
  GameTooltip:AddLine("Left-click: open Nock", 0.8, 0.8, 0.8)
  GameTooltip:AddLine("Right-click: keyboard card on or off", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

function _G.Nock_OnAddonCompartmentLeave()
  HideTip()
end

-- Events -------------------------------------------------------------------------------

local ev = CreateFrame("Frame")
for _, e in ipairs({
  "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_BINDINGS", "UPDATE_MACROS",
}) do
  pcall(ev.RegisterEvent, ev, e)
end

local pending = false
local function QueueBadges()
  if pending then
    return
  end
  pending = true
  local function run()
    pending = false
    UI.UpdateBadges()
  end
  if C_Timer then
    C_Timer.After(0.2, run)
  else
    run()
  end
end

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "Nock" then
      NockDB = NockDB or {}
      NockCharDB = NockCharDB or {}
      if NockCharDB.badges == nil then
        NockCharDB.badges = true
      end
      UI.tab = NockCharDB.uiTab
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    UI.combat = (InCombatLockdown and InCombatLockdown()) and true or false
    CreateMinimapButton()
    QueueBadges()
  elseif event == "PLAYER_REGEN_DISABLED" then
    UI.combat = true
    UI.Refresh()
  elseif event == "PLAYER_REGEN_ENABLED" then
    UI.combat = false
    UI.Refresh()
    if badgesDirty then
      QueueBadges()
    end
  else
    QueueBadges()
  end
end)

-- Slash additions: /nock badges, /nock resetui
local baseSlash = SlashCmdList.NOCK
SlashCmdList.NOCK = function(msg)
  local m = string.lower(strtrim(msg or ""))
  if m == "badges" then
    NockCharDB.badges = NockCharDB.badges == false
    UI.UpdateBadges()
    UI.Refresh()
    return Print("Action button key badges " .. (NockCharDB.badges and "on." or "off."))
  elseif m == "resetui" then
    NockDB.uiPos = nil
    if frame then
      RestorePosition(frame)
    end
    return Print("Window moved back to the middle of the screen.")
  end
  return baseSlash(msg)
end

-- Shared with UI_MyRotation.lua -----------------------------------------------------

-- Segmented control: connected buttons with a clear selected state.
local function Segmented(parent, items, get, set, width, tip)
  local wrap = CreateFrame("Frame", nil, parent)
  local n = #items
  local h = 32
  width = width or (n * 100)
  wrap:SetSize(width, h)
  wrap.buttons = {}
  local function Paint()
    local cur = get and get()
    for _, b in ipairs(wrap.buttons) do
      local on = b.value == cur
      if b.bg then
        if on then
          b.bg:SetColorTexture(0.55, 0.40, 0.12, 0.95)
        else
          b.bg:SetColorTexture(0.10, 0.08, 0.05, 0.90)
        end
      end
      if b.border then
        if on then
          b.border:SetColorTexture(0.95, 0.82, 0.38, 1)
        else
          b.border:SetColorTexture(0.35, 0.30, 0.20, 0.9)
        end
      end
      if b.label then
        if on then
          b.label:SetTextColor(1, 0.96, 0.78)
        else
          b.label:SetTextColor(0.72, 0.74, 0.68)
        end
      end
    end
  end
  wrap.Sync = Paint
  local bw = math.floor(width / n)
  for i, item in ipairs(items) do
    local b = CreateFrame("Button", nil, wrap)
    b:SetSize(bw - 2, h)
    b:SetPoint("TOPLEFT", (i - 1) * bw, 0)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    b.border = border
    local bg = b:CreateTexture(nil, "ARTWORK")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b.bg = bg
    local fs = b:CreateFontString(nil, "OVERLAY")
    local body = 16
    if UI.WindowMetrics then
      body = UI.WindowMetrics().body or 16
    end
    EnsureFont(fs, body, "OUTLINE")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(item[1])
    b.label = fs
    b.value = item[2]
    b:SetScript("OnClick", function()
      Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
      if set then
        set(item[2], item[1])
      end
      Paint()
    end)
    if tip then
      b:SetScript("OnEnter", function(self)
        ShowTip(self, item[1], { tip })
      end)
      b:SetScript("OnLeave", HideTip)
    end
    wrap.buttons[#wrap.buttons + 1] = b
  end
  Paint()
  return wrap
end

UI.lib = {
  InCombat = InCombat, Active = Active, Selected = Selected, Profiles = Profiles,
  PanelButton = PanelButton, BarButton = BarButton, UpdateButtonStates = UpdateButtonStates,
  Confirm = Confirm, NewFlow = NewFlow, MakeKeyBadge = MakeKeyBadge, SetIcon = SetIcon,
  SetAtlasOr = SetAtlasOr, HasAtlas = HasAtlas, Sound = Sound, ShowTip = ShowTip, HideTip = HideTip,
  AttachTip = AttachTip, Field = Field, TryCreate = TryCreate, Backdrop = Backdrop,
  TOOLTIP_BACKDROP = TOOLTIP_BACKDROP, BADGE_BACKDROP = BADGE_BACKDROP, MakeScroll = MakeScroll,
  SectionLabel = SectionLabel, PROFILE_ICONS = PROFILE_ICONS, TREE = TREE, HUNTER_HEX = HUNTER_HEX,
  SPEC_NAME = SPEC_NAME, STATE_ART = STATE_ART, KeyLabel = KeyLabel, CONTENT_W = CONTENT_W,
  Segmented = Segmented, WindowMetrics = UI.WindowMetrics, ApplyWindowSize = UI.ApplyWindowSize, ShowTip = ShowTip, HideTip = HideTip,
  CheckBox = CheckBox, RefreshPage = RefreshPage, HUNTER_ICON = HUNTER_ICON, QUESTION = QUESTION, Print = Print,
}
