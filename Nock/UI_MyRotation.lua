--[[
  Nock 1.6.0 — My Rotation tab and the on-screen rotation card

  Both show the same guide, built by Nock.BuildMyRotation from your level,
  your spellbook and the keys you have bound right now. They are rebuilt
  only out of combat, after a level-up, a new spell, a key or bar change, a
  talent change or a profile change. Anything that happens during combat
  waits for PLAYER_REGEN_ENABLED. In combat the text just stays as it is.
]]

local Nock = _G.Nock
local UI = Nock and Nock.UI
if not (UI and UI.lib) then
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
local L = UI.lib

local MR = { cache = {}, pending = false, builds = 0 }
UI.MyRot = MR

local RED = "|cffff4040"
local GOLD = "|cffffd100"
local GREY = "|cff808080"

-- Building (out of combat only) --------------------------------------------------

local function CardProfile()
  local a = L.Active()
  if a then
    return a
  end
  local level = Nock.PlayerLevel and Nock.PlayerLevel() or 1
  if Nock.DefaultProfileFor then
    return Nock.DefaultProfileFor(NockCharDB.spec or (Nock.DetectSpec and Nock.DetectSpec()) or "bm", level)
  end
  return L.Profiles().bmlvl
end
MR.CardProfile = CardProfile

-- The cached guide for a profile. Returns nil in combat if it was never built.
function MR.Get(p)
  if not p then
    return nil
  end
  local level = Nock.PlayerLevel and Nock.PlayerLevel() or 1
  local c = MR.cache[p.key]
  if c and c.level == level then
    return c
  end
  if L.InCombat() then
    MR.pending = true
    return c
  end
  local ok, data = pcall(Nock.BuildMyRotation, p, level)
  if not ok then
    L.Print("My Rotation couldn't be built: " .. tostring(data))
    return c
  end
  MR.builds = MR.builds + 1
  data.builtAt = (date and date("%H:%M")) or ""
  MR.cache[p.key] = data
  return data
end

local Repaint

-- In combat the old guide stays up; the rebuild waits for PLAYER_REGEN_ENABLED.
function MR.Invalidate()
  if L.InCombat() then
    MR.pending = true
    return
  end
  MR.cache = {}
  MR.pending = false
  Repaint()
end

-- Opener tiles and list rows (pooled) -----------------------------------------------

local function BindTip(btn)
  local r = btn.r
  if not r then
    return nil
  end
  local lines = {}
  if r.layoutKey then
    lines[#lines + 1] = "Binds " .. r.label .. " to " .. GOLD .. L.KeyLabel(r.layoutKey) .. "|r, the key Nock planned for it."
    local old = GetBindingAction and GetBindingAction(r.layoutKey, true)
    if old and old ~= "" then
      lines[#lines + 1] = { "Replaces: " .. old, 1, 0.5, 0.25 }
    end
    lines[#lines + 1] = { "Restore Keys on the Profiles tab can undo it.", 0.6, 0.6, 0.6 }
  else
    lines[#lines + 1] = "Nock has no key planned for this. Put it on a bar or bind it in Key Bindings."
  end
  return "Bind it", lines
end

local function BindButton(parent)
  local b = L.PanelButton(parent, "Bind it", 64, {
    height = 18,
    lock = true,
    tipTitle = "Bind it",
    sound = "IG_MAINMENU_OPTION_CHECKBOX_ON",
    allowed = function()
      return true
    end,
    onClick = function(self)
      if self.r and Nock.BindAction(self.r) then
        MR.Invalidate()
        if UI.UpdateBadges then
          UI.UpdateBadges()
        end
      end
    end,
  })
  b:SetScript("OnEnter", function(self)
    local title, lines = BindTip(self)
    if self.reason then
      lines = lines or {}
      lines[#lines + 1] = { self.reason, 1, 0.25, 0.25 }
    end
    L.ShowTip(self, title or "Bind it", lines)
  end)
  local fs = L.Field(b, "Text")
  if fs and fs.SetFontObject then
    fs:SetFontObject("GameFontNormalSmall")
  end
  return b
end

local function ActionTip(owner, r)
  local lines = {}
  if r.key then
    local how = r.how == "bar" and "action bar key" or (r.how == "spell" and "your own key" or "Nock key")
    lines[#lines + 1] = { "Press " .. L.KeyLabel(r.key) .. "  (" .. how .. ")", 1, 0.82, 0 }
  else
    lines[#lines + 1] = { r.onBar and "On a bar, but that bar slot has no key." or "Not bound to any key and not on a bar.", 1, 0.25, 0.25 }
    if r.layoutKey then
      lines[#lines + 1] = { "Bind it puts it on " .. L.KeyLabel(r.layoutKey) .. ".", 0.6, 0.6, 0.6 }
    end
  end
  if r.rank then
    lines[#lines + 1] = { r.rank .. " (your highest; casting by name uses it)", 0.6, 0.8, 1 }
  end
  if r.why then
    lines[#lines + 1] = r.why
  end
  if r.entry and r.entry.kind == "macro" and r.entry.macro then
    lines[#lines + 1] = { r.entry.macro, 0.62, 0.82, 1 }
  end
  L.ShowTip(owner, r.label, lines)
end

local TILE_W, TILE_H = 100, 96

local function MakeTile(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(TILE_W, TILE_H)
  t:EnableMouse(true)
  local icon = t:CreateTexture(nil, "ARTWORK")
  icon:SetSize(38, 38)
  icon:SetPoint("TOP", 0, -8)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t.icon = icon
  local art = t:CreateTexture(nil, "OVERLAY")
  art:SetSize(44, 44)
  art:SetPoint("CENTER", icon, "CENTER")
  if not L.SetAtlasOr(art, "UI-HUD-ActionBar-IconFrame", nil) then
    art:Hide()
  end
  local num = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(num, "GameFontNormalSmall")
  num:SetPoint("TOPLEFT", 4, -4)
  t.num = num
  local badge = L.MakeKeyBadge(t, "NumberFontNormal")
  badge:SetPoint("TOP", icon, "BOTTOM", 0, 6)
  badge:SetFrameLevel((t:GetFrameLevel() or 1) + 3)
  t.badge = badge
  local missing = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(missing, "GameFontNormalSmall")
  missing:SetPoint("TOP", icon, "BOTTOM", 0, -2)
  missing:SetTextColor(1, 0.25, 0.25)
  missing:SetText("not bound")
  t.missing = missing
  local name = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(name, "GameFontHighlightSmall")
  name:SetPoint("TOP", icon, "BOTTOM", 0, -14)
  name:SetWidth(TILE_W - 4)
  name:SetJustifyH("CENTER")
  if name.SetMaxLines then
    name:SetMaxLines(2)
  end
  t.name = name
  local bind = BindButton(t)
  bind:SetPoint("BOTTOM", 0, 0)
  t.bind = bind
  local arrow = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(arrow, "GameFontNormalLarge")
  arrow:SetText(">")
  arrow:SetPoint("LEFT", t, "RIGHT", -2, 14)
  t.arrow = arrow
  t:SetScript("OnEnter", function(self)
    if self.r then
      ActionTip(self, self.r)
    end
  end)
  t:SetScript("OnLeave", L.HideTip)
  return t
end

local function PaintTile(t, r, i, last)
  t.r = r
  t.bind.r = r
  t.num:SetText(tostring(i))
  L.SetIcon(t.icon, r.icon)
  t.name:SetText(r.label)
  if r.key then
    t.badge:SetKey(r.key)
    t.badge:Show()
    t.missing:Hide()
    t.bind:Hide()
  else
    t.badge:Hide()
    t.missing:Show()
    t.bind:SetShown(r.layoutKey and true or false)
  end
  t.arrow:SetShown(not last)
  t:Show()
end

local function RowW()
  local U = Nock.UI
  return (U and U.metrics and U.metrics.content) or L.CONTENT_W
end

local function MakeRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(RowW(), 34)
  r:EnableMouse(true)
  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  r.bg = bg
  local num = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(num, "GameFontNormal")
  num:SetPoint("TOPLEFT", 6, -8)
  num:SetWidth(28)
  num:SetJustifyH("RIGHT")
  r.num = num
  local icon = r:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26)
  icon:SetPoint("TOPLEFT", 40, -4)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.icon = icon
  local badge = L.MakeKeyBadge(r)
  badge:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  r.badge = badge
  local name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(name, "GameFontNormal")
  name:SetPoint("TOPLEFT", 136, -4)
  name:SetJustifyH("LEFT")
  r.name = name
  local why = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(why, "GameFontHighlightSmall")
  why:SetPoint("TOPLEFT", 136, -19)
  why:SetWidth(RowW() - 216)
  why:SetJustifyH("LEFT")
  why:SetJustifyV("TOP")
  why:SetTextColor(0.86, 0.86, 0.86)
  r.why = why
  local missing = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(missing, "GameFontNormalSmall")
  missing:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  missing:SetTextColor(1, 0.25, 0.25)
  missing:SetText("not bound")
  r.missing = missing
  local bind = BindButton(r)
  bind:SetPoint("TOPRIGHT", -8, -6)
  r.bind = bind
  r:SetScript("OnEnter", function(self)
    if self.r and self.r.action then
      ActionTip(self, self.r)
    end
  end)
  r:SetScript("OnLeave", L.HideTip)
  return r
end

-- kind: "num" (numbered), "dot" (bullet), "soon" (level column)
local function PaintRow(row, r, idx, kind, stripe)
  row.r = r
  row.bind.r = r
  if kind == "num" then
    row.num:SetText(idx .. ".")
  elseif kind == "soon" then
    row.num:SetText(GREY .. "Lv|r " .. r.level)
  else
    row.num:SetText(GOLD .. "-|r")
  end
  row.bg:SetColorTexture(1, 1, 1, stripe and 0.035 or 0)
  if kind == "soon" then
    L.SetIcon(row.icon, r.icon)
    row.icon:Show()
    row.icon:SetDesaturated(true)
    row.icon:SetAlpha(0.75)
    row.badge:Hide()
    row.missing:Hide()
    row.bind:Hide()
    row.name:SetText(r.name .. "  " .. GREY .. (r.how == "talent" and "talent in your plan" or "trainer") .. "|r")
    row.why:SetText(r.change:sub(1, 1):upper() .. r.change:sub(2) .. "." .. (r.key and ("  Nock puts it on " .. GOLD .. L.KeyLabel(r.key) .. "|r.") or ""))
  elseif r.action then
    L.SetIcon(row.icon, r.icon)
    row.icon:Show()
    row.icon:SetDesaturated(false)
    row.icon:SetAlpha(1)
    row.name:SetText(r.label .. (r.rank and ("  " .. GREY .. r.rank .. "|r") or ""))
    row.why:SetText(r.why or "")
    if r.key then
      row.badge:SetKey(r.key)
      row.badge:Show()
      row.missing:Hide()
      row.bind:Hide()
    else
      row.badge:Hide()
      row.missing:Show()
      row.bind:SetShown(r.layoutKey and true or false)
    end
  else
    row.icon:Hide()
    row.badge:Hide()
    row.missing:Hide()
    row.bind:Hide()
    row.name:SetText("")
    row.why:SetText(r.text or "")
  end
  local h
  if r.action or kind == "soon" then
    h = math.max(34, 22 + (row.why:GetStringHeight() or 12))
  else
    row.why:ClearAllPoints()
    row.why:SetPoint("TOPLEFT", 40, -6)
    h = math.max(22, 10 + (row.why:GetStringHeight() or 12))
  end
  if r.action or kind == "soon" then
    row.why:ClearAllPoints()
    row.why:SetPoint("TOPLEFT", 136, -19)
  end
  row:SetHeight(h)
  row:Show()
  return h
end

-- Cheat sheet rows (1.9.0) ----------------------------------------------------------
-- One big plain-English line per row with the key(s) as large keycaps.

local function Font(fs, names)
  for _, n in ipairs(names) do
    if _G[n] then
      if fs.SetFontObject then
        pcall(fs.SetFontObject, fs, n)
      end
      EnsureFont(fs, n)
      return
    end
  end
  if fs.SetFontObject then
    pcall(fs.SetFontObject, fs, names[#names])
  end
  EnsureFont(fs, names[#names])
end

-- "SHIFT-Z" -> "Shift-Z": spelled out, so nobody has to guess what S- means.
local function CheatKeyLabel(key)
  if not key then
    return "?"
  end
  -- 2.1: mouse buttons as M4 / M5 / MMB (the key bar's badges).
  key = key:gsub("BUTTON3$", "MMB"):gsub("BUTTON(%d)$", "M%1")
  return (key:gsub("SHIFT%-", "Shift-"):gsub("ALT%-", "Alt-"):gsub("CTRL%-", "Ctrl-"))
end
MR.CheatKeyLabel = CheatKeyLabel

-- 3.0.9: hover-free one-glance key map (left-hand keys Nock assigned).
local function KeyMapText()
  -- Plain two-column dump for the small Hunting Notes card. Names are
  -- never truncated; each pair sits on its own line and wraps.
  local Book = Nock.Book
  if not (Book and Book.CheatMap) then
    return ""
  end
  local map = Book.CheatMap()
  if not map or #map == 0 then
    return ""
  end
  local lines = {}
  local i = 1
  while i <= #map do
    local function cell(rec)
      if not rec then
        return ""
      end
      return string.format("%s  %s", CheatKeyLabel(rec.key), rec.label or rec.id or "")
    end
    local a, b = cell(map[i]), cell(map[i + 1])
    if b ~= "" then
      lines[#lines + 1] = a .. "    " .. b
    else
      lines[#lines + 1] = a
    end
    i = i + 2
  end
  return table.concat(lines, "\n")
end

MR.KeyMapText = KeyMapText
local MOUSE_TEAL = "|cff73f2e6"

local function BigBadge(parent, big)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  if L.Backdrop and L.BADGE_BACKDROP then
    L.Backdrop(b, L.BADGE_BACKDROP, 0.03, 0.08, 0.06, 0.92, 0.62, 0.8, 0.7, 1)
  end
  local fs = b:CreateFontString(nil, "OVERLAY")
  EnsureFont(fs)
  Font(fs, big and { "GameFontNormalHuge", "GameFontNormalLarge" } or { "GameFontNormalLarge", "GameFontNormal" })
  fs:SetPoint("CENTER", 0, 0)
  fs:SetTextColor(0.79, 1, 0.88)
  b.text = fs
  b.h = big and 30 or 24
  b.SetKey = function(self, key, missing, alt)
    if missing then
      self.text:SetText(RED .. "?|r")
    else
      local t = CheatKeyLabel(key)
      if key and key:find("BUTTON", 1, true) then
        t = MOUSE_TEAL .. t .. "|r"
      end
      if alt then
        t = t .. " / " .. MOUSE_TEAL .. CheatKeyLabel(alt) .. "|r"
      end
      self.text:SetText(t)
    end
    local w = (self.text:GetStringWidth() or 10) + (big and 18 or 14)
    self:SetSize(math.max(self.h, w), self.h)
  end
  return b
end

local function MakeKeyCell(parent, width)
  local cell = CreateFrame("Frame", nil, parent)
  cell:SetSize(width, 32)
  local badge = BigBadge(cell, false)
  badge:SetPoint("TOPLEFT", 0, -2)
  cell.badge = badge
  local fs = cell:CreateFontString(nil, "OVERLAY")
  EnsureFont(fs, 16, "OUTLINE")
  fs:SetPoint("TOPLEFT", cell, "TOPLEFT", 64, -5)
  fs:SetPoint("RIGHT", cell, "RIGHT", -6, 0)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(true)
  fs:SetTextColor(0.92, 0.93, 0.86)
  cell.name = fs
  -- 3.5.0: labels start on one fixed column, whatever the badge width.
  cell.SetKeyColumn = function(self, x)
    self.name:ClearAllPoints()
    self.name:SetPoint("TOPLEFT", self, "TOPLEFT", x, -5)
    self.name:SetPoint("RIGHT", self, "RIGHT", -6, 0)
  end
  cell.Paint = function(self, rec)
    self.badge:SetKey(rec and rec.key, not (rec and rec.key), nil)
    self.name:SetText((rec and (rec.label or rec.id)) or "")
    local nh = (self.name.GetStringHeight and self.name:GetStringHeight()) or 16
    local bh = self.badge.h or 24
    local h = math.max(32, math.max(bh, nh) + 8)
    self:SetHeight(h)
    return h
  end
  return cell
end

-- Two-column key list in the My Rotation scroll: badge + full name, wrapped.
local function PaintKeyMap(page, width, y)
  page.keyCells = page.keyCells or {}
  for _, c in ipairs(page.keyCells) do
    c:Hide()
  end
  if page.keymapFS then
    page.keymapFS:Hide()
  end
  local Book = Nock.Book
  if not (Book and Book.CheatMap) then
    return 0
  end
  local map = Book.CheatMap()
  if not map or #map == 0 then
    return 0
  end
  local colW = math.floor((width - 24) / 2)
  -- Pass 1: badges, to find one key column for the whole list.
  local keyCol = 48
  for i, rec in ipairs(map) do
    local cell = page.keyCells[i]
    if not cell then
      cell = MakeKeyCell(page.child, colW)
      page.keyCells[i] = cell
    end
    cell:SetWidth(colW)
    cell.badge:SetKey(rec and rec.key, not (rec and rec.key), nil)
    keyCol = math.max(keyCol, (tonumber((cell.badge:GetWidth())) or 40) + 12)
  end
  keyCol = math.min(keyCol, math.floor(colW * 0.42))
  -- Pass 2: rows in pairs so the two columns line up.
  local total, idx = 0, 0
  local i = 1
  while i <= #map do
    local hRow = 0
    for col = 0, 1 do
      local rec = map[i + col]
      if rec then
        local cell = page.keyCells[i + col]
        cell:SetKeyColumn(keyCol)
        hRow = math.max(hRow, cell:Paint(rec))
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", page.child, "TOPLEFT", 8 + col * (colW + 8), y - total)
        cell:Show()
        idx = i + col
      end
    end
    total = total + hRow + 4
    i = i + 2
  end
  for j = idx + 1, #page.keyCells do
    page.keyCells[j]:Hide()
  end
  local leftH, rightH = total, total
  return math.max(leftH, rightH) + 8
end
local function MakeCheatRow(parent, width, big)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, big and 52 or 40)
  row:EnableMouse(true)
  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  row.bg = bg
  row.keyW = big and 150 or 92
  row.badges = { BigBadge(row, big), BigBadge(row, big) }
  local plus = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  EnsureFont(plus, "GameFontDisable")
  row.plus = plus
  local text = row:CreateFontString(nil, "OVERLAY")
  EnsureFont(text)
  Font(text, big and { "GameFontHighlightHuge", "GameFontHighlightLarge" } or { "GameFontHighlightLarge", "GameFontHighlight" })
  text:SetPoint("TOPLEFT", row.keyW, big and -6 or -4)
  text:SetWidth(width - row.keyW - 6)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  row.text = text
  local hint = row:CreateFontString(nil, "OVERLAY", big and "GameFontHighlightSmall" or "GameFontDisableSmall")
  EnsureFont(hint, big and "GameFontHighlightSmall" or "GameFontDisableSmall")
  hint:SetJustifyH("LEFT")
  hint:SetJustifyV("TOP")
  hint:SetWidth(width - row.keyW - 6)
  hint:SetTextColor(0.7, 0.7, 0.7)
  row.hint = hint
  row:SetScript("OnEnter", function(self)
    local c = self.c
    if not c then
      return
    end
    local lines = {}
    for _, r in ipairs(c.rs) do
      if r.key then
        lines[#lines + 1] = { CheatKeyLabel(r.key) .. " = " .. r.label, 1, 0.82, 0 }
      else
        lines[#lines + 1] = { r.label .. " has no key yet. Nock will put it on an empty key.", 1, 0.25, 0.25 }
      end
    end
    if c.hint then
      lines[#lines + 1] = c.hint
    end
    L.ShowTip(self, c.text, lines)
  end)
  row:SetScript("OnLeave", L.HideTip)
  -- Dragging a row drags whatever it sits on (the card).
  if row.RegisterForDrag then
    row:RegisterForDrag("LeftButton")
  end
  local function Forward(name)
    return function()
      local fn = parent.GetScript and parent:GetScript(name)
      if fn then
        fn(parent)
      end
    end
  end
  row:SetScript("OnDragStart", Forward("OnDragStart"))
  row:SetScript("OnDragStop", Forward("OnDragStop"))
  return row
end

-- Paints one cheat line. Returns the row height.
local function PaintCheatRow(row, c, stripe)
  row.c = c
  row.bg:SetColorTexture(0.6, 1, 0.8, stripe and 0.05 or 0.015)
  local x = 6
  local prev
  for i, b in ipairs(row.badges) do
    local r = c.rs[i]
    if r then
      b:SetKey(r.key, not r.key, r.alt)
      b:ClearAllPoints()
      if prev then
        row.plus:ClearAllPoints()
        row.plus:SetPoint("LEFT", prev, "RIGHT", 3, 0)
        row.plus:SetText("then")
        row.plus:Show()
        b:SetPoint("LEFT", row.plus, "RIGHT", 3, 0)
      else
        b:SetPoint("TOPLEFT", row, "TOPLEFT", x, -4)
        row.plus:Hide()
      end
      b:Show()
      prev = b
    else
      b:Hide()
    end
  end
  row.text:SetWidth(math.max(120, (tonumber((row:GetWidth())) or 400) - row.keyW - 6))
  row.text:SetText(c.text)
  local missing = false
  for _, r in ipairs(c.rs) do
    if not r.key then
      missing = true
    end
  end
  local hint = c.hint or ""
  if missing then
    hint = RED .. "No key yet: Nock will put it on an empty key.|r " .. hint
  end
  row.hint:SetText(hint)
  row.hint:ClearAllPoints()
  row.hint:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
  local th = row.text:GetStringHeight() or 16
  local hh = row.hint:GetStringHeight() or 10
  local h = math.max(row.badges[1].h + 8, th + hh + 12)
  row:SetHeight(h)
  row:Show()
  return h
end

-- The tab ------------------------------------------------------------------------

local function BuildPage(page)
  page.footer = "Built out of combat from your keys and spellbook. It doesn't change during a fight."
  -- Top strip (doesn't scroll): profile icon, title, built-at line, warning.
  local icon = page:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT", 12, -10)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  page.icon = icon
  local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(title, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
  page.title = title
  local built = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(built, 13, "")
  built:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  page.built = built
  local warn = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(warn, 14, "")
  warn:SetPoint("TOPRIGHT", -16, -14)
  warn:SetJustifyH("RIGHT")
  page.warn = warn
  local note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(note, 13, "")
  note:SetPoint("TOPRIGHT", warn, "BOTTOMRIGHT", 0, -5)
  note:SetJustifyH("RIGHT")
  note:SetTextColor(0.7, 0.7, 0.7)
  page.note = note
  local rule = page:CreateTexture(nil, "BORDER")
  rule:SetPoint("TOPLEFT", 8, -54)
  rule:SetPoint("TOPRIGHT", -8, -54)
  rule:SetHeight(1)
  rule:SetColorTexture(1, 0.82, 0, 0.25)

  local scroll, child = L.MakeScroll(page, -58, 6)
  page.scroll, page.child = scroll, child
  page.flow = L.NewFlow(child, L.CONTENT_W)
  page.tiles, page.rows = {}, {}

  local cardBtn = L.BarButton(page, "Show Notes", 110, {
    tip = "Hunting Notes: the five plain lines, pinned on screen until you close it. Hold Alt over the key bar to just peek. Same as /nock notes.",
    onClick = function()
      MR.SetCardShown(not MR.IsCardShown())
      UI.Refresh()
    end,
  })
  cardBtn:SetPoint("BOTTOMRIGHT", -6, 4)
  page.cardBtn = cardBtn

  local bindAll = L.BarButton(page, "Bind Missing", 120, {
    lock = true,
    tip = "Binds every spell on this page that has no key to the key Nock planned for it. Your old keys go into the Restore Keys snapshot first.",
    allowed = function()
      local d = page.data
      if not d then
        return false, "Nothing built yet."
      end
      if (d.unbound or 0) == 0 then
        return false, "Everything on this page already has a key."
      end
      return true
    end,
    onClick = function()
      local d = page.data
      if not d then
        return
      end
      L.Confirm("NOCK_BIND_MISSING", string.format("Bind %d spell%s that have no key yet?", d.unbound, d.unbound == 1 and "" or "s"), function()
        MR.BindMissing(d)
      end)
    end,
  })
  bindAll:SetPoint("RIGHT", cardBtn, "LEFT", -8, 0)

  local rebuild = L.BarButton(page, "Rebuild", 80, {
    lock = true,
    tip = "Reads your spellbook, level, keys and bars again, puts any newly trained spell on its planned empty key, and tells you in chat what is on a tile, on a key only, or still waiting at the trainer. Never replaces a key you set yourself. Same as /nock check. Nock also does this by itself after level-ups, new spells and key changes.",
    onClick = function()
      MR.Rebuild()
    end,
  })
  rebuild:SetPoint("RIGHT", bindAll, "LEFT", -8, 0)
  return page
end

-- 3.10.1: Rebuild really rebuilds. Rescan the spellbook, let keep-up bind and
-- place anything newly trained on its planned EMPTY key (keys you set stay
-- yours), repaint the bar and this page, then say what happened in chat.
function MR.Rebuild(quiet)
  if L.InCombat() then
    MR.pending = true
    L.Print("In combat. Nock rebuilds the moment the fight ends.")
    return
  end
  if Nock.SpellbookIndex then
    pcall(Nock.SpellbookIndex, true)
  end
  if Nock.Core and Nock.Core.ScanSpells then
    pcall(Nock.Core.ScanSpells)
  end
  local S = Nock.Setup
  local filled = 0
  local active = true
  if S and S.KeepUp then
    active = not S.KeepUpActive or S.KeepUpActive()
    local ok, n = pcall(S.KeepUp)
    filled = ok and tonumber(n) or 0
  end
  MR.Invalidate()
  if Nock.UpdateOverlay then
    pcall(Nock.UpdateOverlay)
  end
  if quiet then
    return
  end
  if not active then
    L.Print("Nock is not filling keys right now (Use my own keybinds, or auto keep-up is off). The report below only reads.")
  end
  if Nock.PrintCheck then
    local ok, err = pcall(Nock.PrintCheck, nil, filled > 0 and ("Rebuilt, " .. filled .. " key" .. (filled == 1 and "" or "s") .. " filled.") or "Rebuilt.")
    if not ok then
      L.Print("Check failed: " .. tostring(err))
    end
  end
end

function MR.BindMissing(d)
  local done = {}
  local n = 0
  local function walk(list)
    for _, r in ipairs(list or {}) do
      if r.action and r.unbound and r.layoutKey and not done[r.action] then
        done[r.action] = true
        local ok = Nock.BindEntry(r.layoutKey, r.entry)
        if ok then
          n = n + 1
        end
      end
    end
  end
  walk(d.opener)
  for _, s in ipairs(d.sections) do
    walk(s.items)
  end
  L.Print(string.format("Bound %d spell%s. Restore Keys can undo it.", n, n == 1 and "" or "s"))
  MR.Invalidate()
  if UI.UpdateBadges then
    UI.UpdateBadges()
  end
end

local SECTION_ICON = {
  single = "Interface\\Icons\\Ability_Hunter_AimedShot",
  aoe2 = "Interface\\Icons\\Ability_UpgradeMoonGlaive",
  aoe4 = "Interface\\Icons\\Ability_Marksmanship",
  move = "Interface\\Icons\\Ability_Rogue_Sprint",
  ohno = "Interface\\Icons\\Ability_Rogue_FeignDeath",
  pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
}

local function PaintPage(page, p, d)
  page.data = d
  local f = page.flow
  f:Reset()
  for _, t in ipairs(page.tiles) do
    t:Hide()
    t.arrow:Hide()
  end
  for _, r in ipairs(page.rows) do
    r:Hide()
  end
  L.SetIcon(page.icon, L.PROFILE_ICONS[p.key])
  page.title:SetText(p.label .. "  " .. GREY .. "level " .. (d and d.level or "?") .. "|r")
  local active = L.Active()
  if not d then
    page.built:SetText("")
    page.warn:SetText("")
    page.note:SetText("")
    for _, cr in ipairs(page.cheatRows or {}) do
      cr:Hide()
    end
    if page.moreBtn then
      page.moreBtn:Hide()
    end
    f:Para(RED .. "You're in combat.|r My Rotation is built out of combat only. It will appear when the fight ends.")
    f:Finish()
    return
  end
  page.built:SetText("Built at " .. (d.builtAt or "") .. " out of combat  ·  updates after level-ups, new spells and key changes")
  if d.unbound > 0 then
    page.warn:SetText(RED .. d.unbound .. " spell" .. (d.unbound == 1 and "" or "s") .. " you should use ha" .. (d.unbound == 1 and "s" or "ve") .. " no key|r")
  else
    page.warn:SetText("|cff20ff20Every spell here has a key|r")
  end
  if active and active.key == p.key then
    page.note:SetText("Active profile")
  else
    page.note:SetText("Not applied: keys shown are the ones you have now")
  end

  local rowN = 0
  local function Row()
    rowN = rowN + 1
    local row = page.rows[rowN]
    if not row then
      row = MakeRow(page.child)
      page.rows[rowN] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, f.y)
    return row
  end
  local function List(items, kind)
    for i, r in ipairs(items) do
      local h = PaintRow(Row(), r, i, kind, i % 2 == 0)
      f.y = f.y - h - 2
    end
  end

  -- Cheat sheet (1.9.0): the whole rotation in a few big lines.
  page.cheatRows = page.cheatRows or {}
  for _, cr in ipairs(page.cheatRows) do
    cr:Hide()
  end
  f:Header("Cheat Sheet", "That's it. These keys are all you need.", "Interface\\Icons\\INV_Misc_Note_06")
  do
    local h = PaintKeyMap(page, RowW(), f.y)
    f.y = f.y - h - 8
  end
  for i, c in ipairs(d.cheat or {}) do
    local cr = page.cheatRows[i]
    if not cr then
      cr = MakeCheatRow(page.child, RowW(), true)
      page.cheatRows[i] = cr
    end
    cr:SetWidth(RowW())
    cr:ClearAllPoints()
    cr:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, f.y)
    local h = PaintCheatRow(cr, c, i % 2 == 0)
    f.y = f.y - h - 8
  end
  f:Space(8)
  if not page.moreBtn then
    page.moreBtn = L.PanelButton(page.child, "More detail", 160, {
      tip = "Shows or hides the full lists: opener, single target, packs, kiting, oh no, pet, coming soon and tips.",
      onClick = function()
        NockCharDB.mrDetail = not NockCharDB.mrDetail
        page.painted = nil
        PaintPage(page, p, page.data)
        page.painted = p.key
      end,
    })
  end
  page.moreBtn:ClearAllPoints()
  page.moreBtn:SetPoint("TOPLEFT", page.child, "TOPLEFT", 4, f.y)
  page.moreBtn:SetText(NockCharDB.mrDetail and "Less detail" or "More detail")
  page.moreBtn:Show()
  f.y = f.y - 30
  if not NockCharDB.mrDetail then
    f:Finish()
    return
  end

  -- Opener
  f:Header("Opener", "Press these in order to start a fight.", "Interface\\Icons\\Ability_Hunter_SniperShot")
  for i, r in ipairs(d.opener) do
    local t = page.tiles[i]
    if not t then
      t = MakeTile(page.child)
      page.tiles[i] = t
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", page.child, "TOPLEFT", 8 + (i - 1) * (TILE_W + 10), f.y)
    PaintTile(t, r, i, i == #d.opener)
  end
  f.y = f.y - TILE_H - 8

  for _, s in ipairs(d.sections) do
    f:Header(s.title, s.sub, SECTION_ICON[s.key])
    List(s.items, s.numbered and "num" or "dot")
    f:Space(4)
  end

  f:Header("Coming soon", "What you get next and how it changes the rotation.", "Interface\\Icons\\INV_Misc_Book_09")
  if #d.soon == 0 then
    f:Para("Nothing new for your rotation: you have every damage spell for this profile.")
  else
    List(d.soon, "soon")
  end
  f:Space(4)
  f:Header("Most damage tips", nil, "Interface\\Icons\\INV_Misc_Note_01")
  for _, tip in ipairs(d.tips) do
    f:Bullet(tip)
  end
  f:Finish()
end

L.RefreshPage.myrot = function(page, p)
  local d = MR.Get(p)
  if page.data ~= d or page.painted ~= p.key or not d then
    PaintPage(page, p, d)
    page.painted = p.key
  end
  page.cardBtn:SetText(MR.IsCardShown() and "Hide Notes" or "Show Notes")
end

UI.extraPages = UI.extraPages or {}
UI.extraPages.myrot = BuildPage

-- The card: Hunting Notes (2.0) --------------------------------------------------
-- Hidden by default. Hold Alt over the key bar to peek at it, or pin it with
-- its key binding, the minimap right-click or /nock notes. A plain frame (not
-- secure), so it can show in combat; its lines are only rebuilt out of combat.

local card
local CARD_W = 340

local function SaveCardPos(f)
  local point, _, relPoint, x, y = f:GetPoint(1)
  if point then
    NockCharDB.cardPos = { point, relPoint, x, y }
    NockCharDB.cardFree = true
  end
end

local function KeyText(r)
  if r.key then
    return GOLD .. "[" .. L.KeyLabel(r.key) .. "]|r"
  end
  return RED .. "[not bound]|r"
end

local function AnchorCard(f)
  f = f or card
  if not f then
    return
  end
  f:ClearAllPoints()
  local bar = Nock.Overlay and Nock.Overlay()
  local pos = NockCharDB.cardPos
  if bar and bar:IsShown() and not NockCharDB.cardFree then
    f:SetPoint("BOTTOM", bar, "TOP", 0, 44)
  elseif type(pos) == "table" and pos[1] then
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
  end
end
MR.AnchorCard = AnchorCard

local function CreateCard()
  if card then
    return card
  end
  local f = CreateFrame("Frame", "NockRotationCard", UIParent)
  f:SetSize(CARD_W, 200)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if not self.peek then
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveCardPos(self)
  end)
  local T = _G.NockTheme
  if T then
    T.MistPanel(f, { cornerSize = 32, edge = 18, cornerOffset = -2, ornament = false, mapAlpha = 0.08 })
  else
    L.Backdrop(f, L.TOOLTIP_BACKDROP, 0.03, 0.08, 0.06, 0.92, 0.6, 0.8, 0.7, 1)
  end
  local head = f:CreateTexture(nil, "ARTWORK", nil, 2)
  head:SetPoint("TOPLEFT", 36, -2)
  head:SetPoint("TOPRIGHT", -36, -2)
  head:SetHeight(32)
  if not (T and T.SetTex(head, "title")) then
    if not (T and T.SetTex(head, "header")) then
      head:SetColorTexture(0.06, 0.12, 0.1, 0.9)
    end
  end
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(16, 16)
  icon:SetPoint("TOPLEFT", 48, -10)
  if not (T and T.SetTex(icon, "moon")) then
    L.SetIcon(icon, L.HUNTER_ICON)
  end
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(title, "GameFontNormal")
  title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  title:SetText("Hunting Notes")
  title:SetTextColor(0.84, 1, 0.91)
  f.title = title
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(sub, "GameFontDisableSmall")
  sub:SetPoint("RIGHT", f, "TOPRIGHT", -36, -18)
  sub:SetTextColor(0.61, 0.77, 0.69)
  f.sub = sub
  -- A thin vine under the header.
  local rule = f:CreateTexture(nil, "ARTWORK", nil, 3)
  rule:SetPoint("TOPLEFT", 40, -34)
  rule:SetPoint("TOPRIGHT", -40, -34)
  rule:SetHeight(12)
  if not (T and T.SetTex(rule, "divider")) then
    rule:SetColorTexture(0.45, 0.62, 0.48, 0.5)
    rule:SetHeight(1)
  end
  f.rule = rule
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -8, -8)
  if T and T.SkinClose then
    T.SkinClose(close, 22)
  end
  close:SetScript("OnClick", function()
    MR.SetCardShown(false)
    UI.Refresh()
  end)
  f.close = close
  f.lock = { tex = { SetDesaturated = function() end, SetAlpha = function() end } } -- 1.x field
  f.icons = {}
  f.cheat = {}
  for i = 1, 6 do
    f.cheat[i] = MakeCheatRow(f, CARD_W - 16, false)
    f.cheat[i]:Hide()
  end
  local foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(foot, "GameFontDisableSmall")
  foot:SetPoint("BOTTOMLEFT", 14, 10)
  foot:SetPoint("BOTTOMRIGHT", -14, 10)
  foot:SetJustifyH("LEFT")
  foot:SetTextColor(0.61, 0.77, 0.69)
  foot:SetText("Hold Alt over the key bar to peek  ·  /nock for more")
  f.foot = foot
  -- Kept for 1.x callers; 2.0 has no detail block or Open button on the card.
  f.more = { Hide = function() end, Show = function() end, ClearAllPoints = function() end, SetPoint = function() end, fs = { SetText = function() end, SetTextColor = function() end } }
  f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(f.body, "GameFontHighlightSmall")
  f.body:SetPoint("TOPLEFT", 16, -48)
  f.body:SetWidth(CARD_W - 24)
  f.body:SetJustifyH("LEFT")
  f.body:Hide()
  local kmfs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(kmfs, 11, "OUTLINE")
  kmfs:SetJustifyH("LEFT")
  kmfs:SetJustifyV("TOP")
  kmfs:SetWidth(CARD_W - 24)
  kmfs:SetTextColor(0.90, 0.95, 0.88)
  kmfs:SetText("")
  f.keymap = kmfs
  f:Hide()
  card = f
  MR.card = f
  AnchorCard(f)
  return f
end

local function PaintCard()
  if not (card and card:IsShown()) then
    return
  end
  if card.peek then card.close:Hide() else card.close:Show() end
  local p = CardProfile()
  local d = MR.Get(p)
  if not d then
    card.sub:SetText(p.label)
    card.body:SetText(RED .. "Builds when combat ends.|r")
    card.body:Show()
    for _, cr in ipairs(card.cheat) do
      cr:Hide()
    end
    card:SetHeight(96)
    return
  end
  card.body:Hide()
  card.sub:SetText(p.label .. "  ·  level " .. d.level)
  local y = -38
  local km = KeyMapText()
  if card.keymap then
    if km ~= "" then
      card.keymap:ClearAllPoints()
      card.keymap:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
      card.keymap:SetWidth(CARD_W - 24)
      card.keymap:SetText(km)
      card.keymap:Show()
      local h = card.keymap.GetStringHeight and card.keymap:GetStringHeight() or 80
      if type(h) ~= "number" or h < 12 then
        local nln = 1
        for _ in km:gmatch("\n") do
          nln = nln + 1
        end
        h = 14 * nln
      end
      y = y - h - 8
    else
      card.keymap:Hide()
    end
  end
  local n = 0
  for i, cr in ipairs(card.cheat) do
    local c = d.cheat and d.cheat[i]
    if c and n < 6 then
      n = n + 1
      cr:ClearAllPoints()
      cr:SetPoint("TOPLEFT", card, "TOPLEFT", 8, y)
      y = y - PaintCheatRow(cr, c, i % 2 == 0) - 2
    else
      cr:Hide()
    end
  end
  card:SetHeight(-y + 30)
end

function MR.SyncCardButton()
end
MR.PaintCard = PaintCard
MR.FirstWithAction = function(items, n)
  local out = {}
  for _, r in ipairs(items or {}) do
    if r.action and #out < n then
      out[#out + 1] = r
    end
  end
  return out
end
MR.KeyText = KeyText

-- Pinned (shown until closed).
function MR.IsCardShown()
  return card and card:IsShown() and not card.peek or false
end

function MR.SetCardShown(on)
  NockCharDB.card = on and true or false
  if on then
    local f = CreateCard()
    f.peek = nil
    AnchorCard(f)
    f:Show()
    PaintCard()
  elseif card then
    card.peek = nil
    card:Hide()
  end
end

-- Peek: shown while Alt is held over the key bar; never changes the pinned state.
function MR.PeekCard(on)
  if on then
    if MR.IsCardShown() then
      return
    end
    local f = CreateCard()
    f.peek = true
    AnchorCard(f)
    f:Show()
    PaintCard()
  elseif card and card.peek then
    card.peek = nil
    card:Hide()
  end
end

Repaint = function()
  UI.Refresh()
  PaintCard()
end

-- Profile, key and talent changes made through Nock rebuild it too.
for _, fname in ipairs({ "ApplyProfile", "RestoreKeys", "LearnNextTalent", "LearnAllTalents" }) do
  local base = Nock[fname]
  if base then
    Nock[fname] = function(...)
      local a, b, c = base(...)
      MR.Invalidate()
      return a, b, c
    end
  end
end

-- Events -------------------------------------------------------------------------------

local ev = CreateFrame("Frame")
for _, e in ipairs({
  "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB",
  "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE",
  "PLAYER_REGEN_ENABLED",
}) do
  pcall(ev.RegisterEvent, ev, e)
end

local queued = false
local function Queue()
  if L.InCombat() then
    MR.pending = true
    return
  end
  if queued then
    return
  end
  queued = true
  local function run()
    queued = false
    MR.Invalidate()
  end
  if C_Timer then
    C_Timer.After(0.3, run)
  else
    run()
  end
end

ev:SetScript("OnEvent", function(_, event)
  if not (Nock.IsHunter and Nock.IsHunter()) then
    return
  end
  if event == "PLAYER_LOGIN" then
    if NockCharDB.card then
      MR.SetCardShown(true)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if MR.pending then
      -- UI.lua clears UI.combat on this same event; run after it.
      if C_Timer then
        C_Timer.After(0.1, MR.Invalidate)
      else
        MR.Invalidate()
      end
    end
  else
    Queue()
  end
end)

-- Slash: /nock myrotation, /nock card, /nock card lock ---------------------------

local baseSlash = SlashCmdList.NOCK
SlashCmdList.NOCK = function(msg)
  local m = string.lower(strtrim(msg or ""))
  if m == "myrotation" or m == "myrot" or m == "mine" or m == "my" then
    return Nock.ShowPanel("myrot")
  elseif m == "check" or m == "rebuild" then
    return MR.Rebuild()
  elseif m:sub(1, 6) == "check " then
    local name = strtrim(strtrim(msg or ""):sub(7))
    local want = name:lower()
    -- Accept any capitalisation: match against the trainer list and the spellbook.
    local found
    for _, row in ipairs((Nock.Data and Nock.Data.TrainerSpells) or {}) do
      if row[2]:lower() == want then
        found = row[2]
        break
      end
    end
    if not found and Nock.SpellbookIndex then
      for n in pairs(Nock.SpellbookIndex(true)) do
        if n:lower() == want then
          found = n
          break
        end
      end
    end
    return Nock.CheckSpell(found or name)
  elseif m == "card" then
    MR.SetCardShown(not MR.IsCardShown())
    UI.Refresh()
    return L.Print("Hunting Notes " .. (MR.IsCardShown() and "pinned. Close it with the X, or hold Alt over the key bar to peek." or "hidden. Hold Alt over the key bar to peek."))
  end
  return baseSlash(msg)
end
