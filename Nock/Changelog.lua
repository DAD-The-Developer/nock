--[[
  Nock 3.8.0: What's New.

  Nock.Changelog is the release notes as data, newest first. CHANGELOG.md
  carries the same notes (tests/run_news.py checks they match), and
  tools/release_notes.py writes RELEASE_NOTES.md from this table for the
  GitHub release and the CurseForge changelog.

  The window opens by itself once, on the first login after Nock's version
  changes (NockDB.news.seen, account wide). A brand-new install gets a short
  welcome instead. /nock new and Options > "What's new" open it any time.
  "Don't show this after updates" stops the automatic popup (NockDB.news.off).
]]

local Nock = _G.Nock
if not Nock then
  return
end

local IC = "Interface\\Icons\\"

-- { version, date (YYYY-MM-DD), summary, new = {}, improved = {}, fixed = {} }
-- Each bullet is { text, icon } (icon optional).
Nock.Changelog = {
  {
    version = "3.8.1", date = "2026-11-23",
    summary = "Clearer words for the two key choices.",
    new = {},
    improved = {},
    fixed = {
      { "Clearer keybind layout description: Nock's left-hand keys (e.g. Ctrl-G, Ctrl-Z, C, Z, X, V) take priority while Nock layout is on; your saved keybinds are never overwritten and come back when you switch to My own keybinds. 3.8.0 wrongly said \"free keys only\". How keys work did not change.", IC .. "INV_Misc_Key_03" },
    },
  },
  {
    version = "3.8.0", date = "2026-11-23",
    summary = "Your keybinds are backed up, your own keys are a first-class choice, and every button reads range and cooldowns.",
    new = {
      { "Keybind backup. The first time 3.8.0 loads, Nock saves a copy of every keybind you have (both keys of each action, and whether you use account or character keybinds). That first copy is kept for good. /nock binds restore or Options > Keybind backup puts them back, after you confirm.", IC .. "INV_Misc_Key_03" },
      { "Use my own keybinds. Nock sets no keys at all, and every Nock button shows the key you already use for that spell. Pick it in Setup (Keys: Nock layout or My own keybinds), in Options, or with /nock binds own on.", IC .. "INV_Misc_Key_04" },
      { "A What's New window that opens once after an update (a short welcome on a new install). /nock new or Options > What's new opens it again.", IC .. "INV_Misc_Book_09" },
    },
    improved = {
      { "Range on every button. Shots turn a calm red when the target is out of range or inside the dead zone; melee skills light up only in melee range; Mend Pet and Intimidation dim when your pet can't use them. Aspects, traps and Feign Death are never shaded.", IC .. "Ability_Marksmanship" },
      { "Wing Clip button: lit in melee, a slow soft pulse in melee or the dead zone until the target is slowed, then the seconds left in the corner. Concussive Shot and Frost Trap count as slowed. Options can turn the pulse off.", IC .. "Ability_Rogue_Trip" },
      { "Cooldowns: clean sweep with whole-second numbers, a faint sweep for the global cooldown, and one brief soft highlight when a long cooldown is ready and you can use it. Numbers and the highlight each have a switch in Options.", IC .. "Spell_Nature_TimeStop" },
      { "Range reads run on one shared timer and only while you have a target." },
    },
    fixed = {},
  },
  {
    version = "3.7.1", date = "2026-11-23",
    summary = "Rare tameable beasts on the map, and Tame Beast on the pet bar.",
    new = {
      { "Rare beast pins say Rare spawn or Rare elite spawn, the respawn time after it dies and how many spawn spots it has, with the share per spot where the data gives one.", IC .. "Ability_Hunter_BeastTaming" },
      { "Hover a rare's pin on the world map to see every spawn spot and its patrol path. Click to keep them shown.", IC .. "INV_Misc_Map_01" },
      { "Tame Beast tile on the pet bar, next to Call / Revive.", IC .. "Ability_Hunter_BeastCall" },
    },
    improved = {
      { "The Field Kit rare list shows the respawn time." },
    },
    fixed = {},
  },
  {
    version = "3.7.0", date = "2026-11-23",
    summary = "The Dashboard.",
    new = {
      { "Dashboard: free bag slots, ammo left with minutes of Auto Shot, and your tracked quests with progress. For a screen corner or a second monitor. /nock dash.", IC .. "INV_Misc_Bag_08" },
    },
    improved = {},
    fixed = {},
  },
  {
    version = "3.6.3", date = "2026-11-21",
    summary = "Wing Clip always has a full-size tile.",
    new = {},
    improved = {
      { "Main bar tiles show the dedicated key as a second badge (Caps on Wing Clip, ` on Hunter's Mark)." },
    },
    fixed = {
      { "Wing Clip had no bow tile when Mouse 4 held your own bind. It now sits right after Q.", IC .. "Ability_Rogue_Trip" },
    },
  },
  {
    version = "3.6.2", date = "2026-11-21",
    summary = "Pet bar readability.",
    new = {},
    improved = {
      { "Attack, Follow and Stay show the key that does the same thing." },
    },
    fixed = {
      { "Pet commands and stances were drawn too dark and looked missing. They are full colour now.", IC .. "Ability_Hunter_BeastCall" },
    },
  },
  {
    version = "3.6.1", date = "2026-11-21",
    summary = "Pet bar fixes.",
    new = {
      { "Call / Revive and Mend Pet tiles on the pet bar.", IC .. "Ability_Hunter_MendPet" },
    },
    improved = {},
    fixed = {
      { "With a dead or missing pet the pet bar stays up with Call / Revive." },
      { "Call / Revive also revives a dead pet that is no longer in the world." },
      { "Dedicated keys no longer re-set themselves in a loop when keybinds update." },
    },
  },
  {
    version = "3.6.0", date = "2026-11-21",
    summary = "Dedicated Wing Clip and Hunter's Mark keys.",
    new = {
      { "Key Bindings entries that always cast your highest Wing Clip and Hunter's Mark, with left-hand suggestions (Caps Lock and `) used only when those keys are empty.", IC .. "INV_Misc_Key_03" },
    },
    improved = {},
    fixed = {},
  },
}

local N = {}
Nock.WhatsNew = N

N.WELCOME = {
  version = nil, date = nil,
  summary = "A keyboard-first hunter HUD for WoW Forever.",
  new = {
    { "Your shots, pet and tools on one bar near WASD. Hover any button for what it does.", IC .. "Ability_Hunter_BeastTaming" },
    { "Keys: Nock layout (Nock's left-hand keys take priority while it's on; your saved keybinds are never overwritten) or My own keybinds. Your keybinds are backed up either way (/nock binds).", IC .. "INV_Misc_Key_03" },
    { "Options are in the Nock window (/nock). /nock new shows what changed in each update.", IC .. "INV_Misc_Book_09" },
  },
  improved = {}, fixed = {},
}

local function DB()
  NockDB = NockDB or {}
  NockDB.news = NockDB.news or {}
  return NockDB.news
end

function N.Entry(version)
  for _, e in ipairs(Nock.Changelog) do
    if e.version == version then
      return e
    end
  end
  return nil
end

function N.Off()
  return DB().off == true
end

function N.SetOff(on)
  DB().off = on and true or false
end

-- Pure: what to show at login. Returns "welcome", "news" or nil.
function N.Decide(seen, current, off, fresh)
  if seen == current then
    return nil
  end
  if seen == nil and fresh then
    return "welcome"
  end
  if off then
    return nil
  end
  return "news"
end

-- Plain-text notes for one version (GitHub release / CurseForge changelog).
function N.Markdown(e)
  e = e or Nock.Changelog[1]
  local out = { "## Nock " .. e.version .. " (" .. e.date .. ")", "", e.summary, "" }
  for _, sec in ipairs({ { "new", "New" }, { "improved", "Improved" }, { "fixed", "Fixed" } }) do
    local list = e[sec[1]] or {}
    if #list > 0 then
      out[#out + 1] = "### " .. sec[2]
      out[#out + 1] = ""
      for _, b in ipairs(list) do
        out[#out + 1] = "- " .. b[1]
      end
      out[#out + 1] = ""
    end
  end
  return table.concat(out, "\n")
end

-- Window -----------------------------------------------------------------------------

local SECTION = {
  { key = "new", title = "New", color = { 0.25, 0.89, 0.60 } },
  { key = "improved", title = "Improved", color = { 0.50, 0.75, 1.00 } },
  { key = "fixed", title = "Fixed", color = { 0.95, 0.75, 0.35 } },
}

local function M()
  local UI = Nock.UI
  local m = UI and UI.WindowMetrics and UI.WindowMetrics() or { body = 18, header = 22, title = 22, small = 14, size = "large" }
  return m
end

local function Font(fs, size, flags)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(fs, size, flags or "")
  elseif fs.SetFont then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags or "")
  end
  if fs.SetShadowOffset then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
  end
end

local function NiceDate(d)
  local y, mo, da = tostring(d or ""):match("^(%d+)-(%d+)-(%d+)$")
  local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
  if not y then
    return d or ""
  end
  return string.format("%s %d, %s", months[tonumber(mo)] or mo, tonumber(da), y)
end
N.NiceDate = NiceDate

local frame
local PAD, GAP, SECT_GAP, ICON = 20, 8, 16, 20

-- Pool of rows in the scroll child, reused on every layout.
local function Pool(f)
  f.pool = f.pool or { fs = {}, tex = {}, btn = {} }
  f.used = { fs = 0, tex = 0, btn = 0 }
end

local function TakeFS(f)
  local u = f.used.fs + 1
  f.used.fs = u
  local fs = f.pool.fs[u]
  if not fs then
    fs = f.child:CreateFontString(nil, "OVERLAY")
    Font(fs, 14)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    f.pool.fs[u] = fs
  end
  fs:ClearAllPoints()
  fs:Show()
  return fs
end

local function TakeTex(f)
  local u = f.used.tex + 1
  f.used.tex = u
  local t = f.pool.tex[u]
  if not t then
    t = f.child:CreateTexture(nil, "ARTWORK")
    f.pool.tex[u] = t
  end
  t:ClearAllPoints()
  t:SetVertexColor(1, 1, 1)
  t:SetTexCoord(0, 1, 0, 1)
  t:Show()
  return t
end

local function TakeBtn(f)
  local u = f.used.btn + 1
  f.used.btn = u
  local b = f.pool.btn[u]
  if not b then
    b = CreateFrame("Button", nil, f.child)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(1, 1, 1, 0.05)
    b.edge = b:CreateTexture(nil, "BORDER")
    b.edge:SetPoint("BOTTOMLEFT")
    b.edge:SetPoint("BOTTOMRIGHT")
    b.edge:SetHeight(1)
    b.edge:SetColorTexture(0.5, 0.66, 0.6, 0.35)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(0.3, 1, 0.62, 0.08)
    b.sign = b:CreateFontString(nil, "OVERLAY")
    Font(b.sign, 14)
    b.sign:SetPoint("LEFT", 10, 0)
    b.text = b:CreateFontString(nil, "OVERLAY")
    Font(b.text, 14)
    b.text:SetPoint("LEFT", 34, 0)
    b.date = b:CreateFontString(nil, "OVERLAY")
    Font(b.date, 12)
    b.date:SetPoint("RIGHT", -10, 0)
    f.pool.btn[u] = b
  end
  b:ClearAllPoints()
  b:Show()
  return b
end

local function HideUnused(f)
  for i = f.used.fs + 1, #f.pool.fs do f.pool.fs[i]:Hide() end
  for i = f.used.tex + 1, #f.pool.tex do f.pool.tex[i]:Hide() end
  for i = f.used.btn + 1, #f.pool.btn do f.pool.btn[i]:Hide() end
end

-- Lays out one version's sections at y; returns the new y.
local function LayoutEntry(f, e, y, w, m)
  local body = m.body or 18
  if e.summary and e.summary ~= "" then
    local s = TakeFS(f)
    Font(s, body)
    s:SetTextColor(0.92, 0.97, 0.94)
    s:SetWidth(w)
    s:SetPoint("TOPLEFT", f.child, "TOPLEFT", PAD, y)
    s:SetText(e.summary)
    y = y - (tonumber((s:GetStringHeight())) or body) - SECT_GAP
  end
  for _, sec in ipairs(SECTION) do
    local list = e[sec.key] or {}
    if #list > 0 then
      local bar = TakeTex(f)
      bar:SetColorTexture(sec.color[1], sec.color[2], sec.color[3], 0.9)
      bar:SetSize(3, (m.small or 14) + 2)
      bar:SetPoint("TOPLEFT", f.child, "TOPLEFT", PAD, y)
      local h = TakeFS(f)
      Font(h, m.small or 14, "")
      h:SetTextColor(sec.color[1], sec.color[2], sec.color[3])
      h:SetWidth(w - 12)
      h:SetPoint("TOPLEFT", f.child, "TOPLEFT", PAD + 10, y)
      h:SetText(string.upper(sec.title))
      y = y - (m.small or 14) - 2 - GAP
      for _, b in ipairs(list) do
        local x = PAD
        local iconTex = b[2]
        local t = TakeTex(f)
        if iconTex then
          t:SetTexture(iconTex)
          t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
          t:SetSize(ICON, ICON)
          t:SetPoint("TOPLEFT", f.child, "TOPLEFT", x, y)
        else
          -- Small square marker, centered on the first line.
          t:SetColorTexture(0.61, 0.77, 0.69, 0.9)
          t:SetSize(5, 5)
          t:SetPoint("TOPLEFT", f.child, "TOPLEFT", x + (ICON - 5) / 2, y - (body - 5) / 2 - 1)
        end
        local fs = TakeFS(f)
        Font(fs, body)
        fs:SetTextColor(0.86, 0.92, 0.89)
        fs:SetWidth(w - ICON - 10)
        fs:SetPoint("TOPLEFT", f.child, "TOPLEFT", x + ICON + 10, y)
        fs:SetText(b[1])
        local th = tonumber((fs:GetStringHeight())) or body
        y = y - math.max(ICON, th) - GAP
      end
      y = y - (SECT_GAP - GAP)
    end
  end
  return y
end

function N.Layout()
  local f = frame
  if not f then
    return
  end
  local m = M()
  Pool(f)
  local w = f.innerW or 480 -- fixed from the window width, so wrapping never depends on layout timing
  f.child:SetWidth(w + 2 * PAD)
  local y = -PAD
  local cur = f.mode == "welcome" and N.WELCOME or Nock.Changelog[1]
  y = LayoutEntry(f, cur, y, w, m)
  if f.mode ~= "welcome" and #Nock.Changelog > 1 then
    y = y - GAP
    local h = TakeFS(f)
    Font(h, m.small or 14)
    h:SetTextColor(0.61, 0.77, 0.69)
    h:SetWidth(w)
    h:SetPoint("TOPLEFT", f.child, "TOPLEFT", PAD, y)
    h:SetText("EARLIER VERSIONS")
    y = y - (m.small or 14) - GAP
    f.open = f.open or {}
    for i = 2, #Nock.Changelog do
      local e = Nock.Changelog[i]
      local b = TakeBtn(f)
      local rowH = (m.body or 18) + 14
      b:SetSize(w, rowH)
      b:SetPoint("TOPLEFT", f.child, "TOPLEFT", PAD, y)
      Font(b.text, m.body or 18)
      Font(b.sign, m.body or 18)
      Font(b.date, m.small or 14)
      b.sign:SetText(f.open[e.version] and "-" or "+")
      b.sign:SetTextColor(0.25, 0.89, 0.60)
      b.text:SetText("Nock " .. e.version)
      b.text:SetTextColor(0.92, 0.97, 0.94)
      b.date:SetText(NiceDate(e.date))
      b.date:SetTextColor(0.61, 0.77, 0.69)
      b:SetScript("OnClick", function()
        f.open[e.version] = not f.open[e.version]
        N.Layout()
      end)
      y = y - rowH - GAP
      if f.open[e.version] then
        y = LayoutEntry(f, e, y - 4, w, m) - GAP
      end
    end
  end
  HideUnused(f)
  f.child:SetHeight(math.max(20, -y + PAD))
  f.contentH = -y
end

local function Build()
  if frame then
    return frame
  end
  local L = Nock.UI and Nock.UI.lib
  local Try = L and L.TryCreate or function(kind, name, parent) return CreateFrame(kind, name, parent) end
  local m = M()
  local W = m.size == "small" and 560 or (m.size == "normal" and 600 or 640)
  local H = m.size == "small" and 560 or (m.size == "normal" and 600 or 660)
  local f = Try("Frame", "NockWhatsNew", UIParent, "DefaultPanelTemplate", "BackdropTemplate")
  f:SetSize(W, H)
  f:SetPoint("CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  if f.SetToplevel then f:SetToplevel(true) end
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if L and not L.Field(f, "TitleContainer") and not L.Field(f, "NineSlice") and f.SetBackdrop then
    f:SetBackdrop(L.TOOLTIP_BACKDROP)
  end
  if UISpecialFrames then
    table.insert(UISpecialFrames, "NockWhatsNew") -- Esc closes
  end
  local tc = L and L.Field(f, "TitleContainer")
  local tt = tc and L.Field(tc, "TitleText") or (L and L.Field(f, "TitleText"))
  if tt and tt.SetText then
    tt:SetText("Nock")
  end
  local close = Try("Button", nil, f, "UIPanelCloseButtonDefaultAnchors", "UIPanelCloseButton")
  close:ClearAllPoints()
  close:SetPoint("TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() f:Hide() end)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(44, 44)
  icon:SetPoint("TOPLEFT", PAD, -34)
  icon:SetTexture("Interface\\Icons\\ClassIcon_Hunter")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.icon = icon
  local head = f:CreateFontString(nil, "OVERLAY")
  Font(head, m.title or 22)
  head:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  head:SetJustifyH("LEFT")
  head:SetTextColor(0.92, 0.97, 0.94)
  f.head = head
  local sub = f:CreateFontString(nil, "OVERLAY")
  Font(sub, m.small or 14)
  sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
  sub:SetJustifyH("LEFT")
  sub:SetTextColor(0.61, 0.77, 0.69)
  f.sub = sub
  local rule = f:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", PAD, -34 - 44 - 12)
  rule:SetPoint("TOPRIGHT", -PAD, -34 - 44 - 12)
  rule:SetHeight(1)
  rule:SetColorTexture(0.5, 0.66, 0.6, 0.45)

  local top = -34 - 44 - 12 - 8
  local bottomH = 56
  local scroll
  if L and L.MakeScroll then
    scroll = L.MakeScroll(f, top, bottomH)
  else
    scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, top)
    scroll:SetPoint("BOTTOMRIGHT", -30, bottomH)
    scroll.child = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(scroll.child)
  end
  f.scroll = scroll
  f.innerW = W - 8 - 30 - 2 * PAD
  f.child = scroll.child or (scroll.GetScrollChild and scroll:GetScrollChild())

  local rule2 = f:CreateTexture(nil, "ARTWORK")
  rule2:SetPoint("BOTTOMLEFT", PAD, bottomH - 4)
  rule2:SetPoint("BOTTOMRIGHT", -PAD, bottomH - 4)
  rule2:SetHeight(1)
  rule2:SetColorTexture(0.5, 0.66, 0.6, 0.45)

  if L and L.CheckBox then
    local cb = L.CheckBox(f, "Don't show this after updates",
      "Nock won't open this window by itself after an update. /nock new or Options > What's new still open it.",
      function() return N.Off() end, function(on) N.SetOff(on) end)
    cb:SetPoint("BOTTOMLEFT", PAD - 4, 14)
    if cb.label then
      Font(cb.label, m.small or 14)
      cb.label:ClearAllPoints()
      cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    end
    f.offBox = cb
  end
  local ok
  if L and L.PanelButton then
    ok = L.PanelButton(f, "Close", 120, { onClick = function() f:Hide() end })
  else
    ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(120, 28)
    ok:SetText("Close")
    ok:SetScript("OnClick", function() f:Hide() end)
  end
  ok:SetHeight(28)
  ok:SetPoint("BOTTOMRIGHT", -PAD, 14)
  f.closeBtn = ok
  f:Hide()
  frame = f
  N.frame = f
  return f
end

function N.Show(mode)
  local f = Build()
  f.mode = mode or "news"
  if f.mode == "welcome" then
    f.head:SetText("Welcome to Nock")
    f.sub:SetText("Version " .. tostring(Nock.Version or ""))
  else
    local e = Nock.Changelog[1]
    f.head:SetText("What's new in Nock " .. e.version)
    f.sub:SetText(NiceDate(e.date))
  end
  if f.offBox and f.offBox.SetChecked then
    f.offBox:SetChecked(N.Off())
  end
  f:Show()
  N.Layout()
  if f.scroll and f.scroll.SetVerticalScroll then
    f.scroll:SetVerticalScroll(0)
  end
  DB().seen = Nock.Version
  return f
end

function N.Toggle()
  if frame and frame:IsShown() then
    frame:Hide()
  else
    N.Show("news")
  end
end

-- Once per version at login, out of combat, after the UI settles.
function N.Check()
  local d = DB()
  local what = N.Decide(d.seen, Nock.Version, d.off, Nock.freshInstall)
  if not what then
    d.seen = Nock.Version
    return nil
  end
  if InCombatLockdown and InCombatLockdown() then
    N.pending = true
    return "pending"
  end
  N.pending = nil
  N.Show(what)
  return what
end

if CreateFrame then
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if N.pending then
        N.Check()
      end
      return
    end
    if N.checked then
      return
    end
    N.checked = true
    if C_Timer and C_Timer.After then
      C_Timer.After(4, N.Check)
    else
      N.Check()
    end
  end)
end

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg, ...)
    local m = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if m == "new" or m == "news" or m == "whatsnew" or m == "changelog" then
      return N.Toggle()
    end
    baseSlash(msg, ...)
    if m == "help" and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff8fd18fNock|r /nock new — what's new in this version")
    end
  end
end
