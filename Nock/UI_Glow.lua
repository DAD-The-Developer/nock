
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
--[[
  Nock 1.7.0 (2.0 look) — priority glow, crosshair and opener tokens

  Two STATIC marks on your action buttons, taken from My Rotation:
    - Priority glow: a soft emerald glow on the buttons that hold your top 3
      single-target spells, brightest for #1 and dimmer down the list.
    - Opener numbers: a small 1, 2, 3... tag on the buttons for your opener.

  They are rebuilt only out of combat (after key, bar, spell, level, talent or
  profile changes) and stay exactly as they are during a fight. Nothing here
  reads cooldowns, procs, target, health, auras, mana, range or the combat
  log. The glow is Nock's own texture on top of the button; it does not use
  Blizzard's proc glow (ActionButton_ShowOverlayGlow / SpellActivationOverlay).
  The optional pulse is a slow clock-driven fade, the same for every button.
]]

local Nock = _G.Nock
local UI = Nock and Nock.UI
local MR = UI and UI.MyRot
if not (MR and UI.lib) then
  return
end
local L = UI.lib

local G = { state = {}, overlays = {}, tags = {}, pending = false, updates = 0 }
UI.Glow = G

-- 2.0: top 3 only, in Emerald Dream green. Brightest (plus the crosshair) on #1.
local TOP = 3
local TIER_ALPHA = { 1.0, 0.62, 0.38 }
local TIER_COLOR = {
  { 0.30, 1.00, 0.62 }, { 0.34, 0.92, 0.62 }, { 0.40, 0.82, 0.62 },
}
local function Theme()
  return _G.NockTheme
end
local INTENSITY = { low = 0.55, medium = 0.8, high = 1.0 }
local INTENSITY_ORDER = { "low", "medium", "high" }
local STYLE_ORDER = { "steady", "pulse" }

local function Opt()
  NockCharDB = NockCharDB or {}
  if NockCharDB.glow == nil then
    NockCharDB.glow = true
  end
  if NockCharDB.numbers == nil then
    NockCharDB.numbers = true
  end
  if NockCharDB.crosshair == nil then
    NockCharDB.crosshair = true
  end
  if NockCharDB.glowStyle ~= "pulse" and NockCharDB.glowStyle ~= "steady" then
    NockCharDB.glowStyle = "steady"
  end
  if not INTENSITY[NockCharDB.glowIntensity or ""] then
    NockCharDB.glowIntensity = "medium"
  end
  return NockCharDB
end
G.Opt = Opt

-- Buttons ----------------------------------------------------------------------------
-- Blizzard bars first, then Bartender4, Dominos and ElvUI by frame name, then any
-- LibActionButton registry. Missing ones are simply skipped.

local function Buttons()
  local list, seen = {}, {}
  local function add(b)
    if type(b) == "table" and not seen[b] and b.CreateTexture then
      seen[b] = true
      list[#list + 1] = b
    end
  end
  -- Only Nock's own tiles. Never create textures or write state on Blizzard
  -- ActionButtons (or other addons' action buttons): that taints cooldown
  -- updates on Forever.
  if Nock.Overlay then
    local ov = Nock.Overlay()
    if ov and ov.caps then
      for _, cap in pairs(ov.caps) do
        add(cap)
      end
    end
    if ov and ov.utilCaps then
      for _, cap in pairs(ov.utilCaps) do
        add(cap)
      end
    end
  end
  return list
end
G.Buttons = Buttons

-- What a button holds: "spell"/"macro" and an id, from its action slot or (for
-- LibActionButton spell/macro buttons) its own state.
local function ButtonContent(btn)
  -- Nock secure tiles (and any other type=spell/macro/item button).
  if btn.GetAttribute then
    local ok, typ = pcall(btn.GetAttribute, btn, "type")
    if ok and typ == "spell" then
      local ok2, spell = pcall(btn.GetAttribute, btn, "spell")
      if ok2 and spell then
        return "spell", spell
      end
    elseif ok and typ == "macro" then
      local ok2, macro = pcall(btn.GetAttribute, btn, "macro")
      if ok2 and macro then
        return "macro", macro
      end
    elseif ok and typ == "item" then
      local ok2, item = pcall(btn.GetAttribute, btn, "item")
      if ok2 and item then
        return "item", item
      end
    end
  end
  local stype, saction = rawget(btn, "_state_type"), rawget(btn, "_state_action")
  if stype == "spell" or stype == "macro" then
    return stype, saction
  end
  local slot
  if stype == "action" then
    slot = saction
  end
  slot = slot or rawget(btn, "action")
  if type(slot) ~= "number" and btn.GetAttribute then
    local ok, v = pcall(btn.GetAttribute, btn, "action")
    if ok then
      slot = v
    end
  end
  slot = tonumber(slot)
  if not (slot and GetActionInfo) then
    return nil
  end
  local ok, kind, id = pcall(GetActionInfo, slot)
  if ok and kind and id then
    return kind, id, slot
  end
  return nil
end

-- Names a button answers to: the spell, or the macro's name plus the spell the
-- macro casts (GetMacroSpell, then its #showtooltip / /cast line).
local function ButtonNames(btn)
  local kind, id = ButtonContent(btn)
  local names = {}
  if kind == "spell" then
    local name = Nock.SpellData and Nock.SpellData(id)
    if name then
      names[name] = true
    end
  elseif kind == "macro" then
    local mname, _, body
    if type(id) == "string" then
      mname = id
      if GetMacroIndexByName and GetMacroInfo then
        local idx = GetMacroIndexByName(id)
        if idx and idx > 0 then
          mname, _, body = GetMacroInfo(idx)
          mname = mname or id
        end
      end
    elseif GetMacroInfo then
      mname, _, body = GetMacroInfo(id)
    end
    if mname then
      names[mname] = true
    end
    if GetMacroSpell then
      local ok, spellID = pcall(GetMacroSpell, id)
      if ok and spellID then
        local sname = Nock.SpellData and Nock.SpellData(spellID)
        if sname then
          names[sname] = true
        end
      end
    end
    if type(body) == "string" and Nock.MacroSpell then
      local sname = Nock.MacroSpell({ kind = "macro", macro = body })
      if sname then
        names[sname] = true
      end
    end
  end
  return names
end
G.ButtonNames = ButtonNames

local function Matches(names, r)
  if not r.action then
    return false
  end
  if names[r.action] then
    return true
  end
  return r.entry and r.entry.kind == "macro" and names[r.entry.name] and true or false
end

-- Overlays -------------------------------------------------------------------------

local function MakeOverlay(btn)
  local o = CreateFrame("Frame", nil, btn)
  o:SetAllPoints(btn)
  o:SetFrameLevel((btn:GetFrameLevel() or 1) + 4)
  local w = btn.GetWidth and btn:GetWidth() or 45
  if type(w) ~= "number" or w <= 0 then
    w = 45
  end
  -- The halo sits on a child frame one level BELOW the button, so it only
  -- shows around the edges and never washes out the spell icon.
  local back = CreateFrame("Frame", nil, o)
  back:SetAllPoints(btn)
  back:SetFrameLevel(math.max(0, (btn:GetFrameLevel() or 1) - 1))
  o.back = back
  local outer = back:CreateTexture(nil, "BACKGROUND")
  outer:SetPoint("CENTER", btn, "CENTER", 0, 0)
  outer:SetSize(w * 1.55, w * 1.55)
  -- Soft halo: Nock's glow ring (falls back to Blizzard's square highlight).
  local T = Theme()
  local okTex = T and T.SetTex(outer, "glow")
  if not okTex and outer:SetTexture("Interface\\Buttons\\ButtonHilight-Square") == false then
    outer:Hide()
    o.noOuter = true
  end
  outer:SetBlendMode("ADD")
  o.outer = outer
  local inner = o:CreateTexture(nil, "OVERLAY")
  inner:SetAllPoints(btn)
  -- Crisp ring: the action bar's own mouseover frame, tinted gold.
  if not L.SetAtlasOr(inner, "UI-HUD-ActionBar-IconFrame-Mouseover", nil) then
    L.SetAtlasOr(inner, "UI-HUD-ActionBar-IconFrame-Border", "Interface\\Buttons\\ButtonHilight-Square")
  end
  inner:SetBlendMode("ADD")
  o.inner = inner
  -- Crosshair on the top shot (rank 1 only, can be turned off).
  local ret = o:CreateTexture(nil, "OVERLAY", nil, 2)
  ret:SetPoint("CENTER", btn, "CENTER", 0, 0)
  ret:SetSize(w * 1.5, w * 1.5)
  if T and T.SetTex(ret, "reticle") then
    ret:SetBlendMode("ADD")
  else
    ret:SetTexture(nil)
  end
  ret:Hide()
  o.reticle = ret
  o:Hide()
  return o
end

local function MakeTag(btn)
  local t = CreateFrame("Frame", nil, btn, "BackdropTemplate")
  t:SetSize(15, 15)
  -- Left edge, middle: clear of the key badge (top left), hotkey (top
  -- right), count/charges (bottom right) and macro name (bottom).
  t:SetPoint("LEFT", btn, "LEFT", -4, 0)
  t:SetFrameLevel((btn:GetFrameLevel() or 1) + 7)
  -- Moon-silver token with dark ink (falls back to a small dark badge).
  local T = Theme()
  local bg = t:CreateTexture(nil, "ARTWORK")
  bg:SetAllPoints()
  local dark = false
  if not (T and T.SetTex(bg, "token")) then
    bg:SetTexture(nil)
    L.Backdrop(t, L.BADGE_BACKDROP, 0.02, 0.08, 0.06, 0.92, 0.42, 1, 0.7, 1)
    dark = true
  end
  t.bg = bg
  local fs = t:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  EnsureFont(fs, "NumberFontNormalSmall")
  fs:SetPoint("CENTER", 0, 0)
  -- 2.2 badge is dark carved wood, so the number stays light either way.
  fs:SetTextColor(0.93, 0.97, 0.88)
  if not dark then
    fs:SetShadowOffset(0, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
  end
  t.text = fs
  t:Hide()
  return t
end

local pulse = CreateFrame("Frame")
pulse.t = 0
local function PulseAlpha()
  -- Purely time-based: 0.55 .. 1.0 over 3 seconds, identical for every glow.
  local now = (GetTime and GetTime()) or pulse.t
  return 0.775 + 0.225 * math.sin(now * 2 * math.pi / 3)
end
G.PulseAlpha = PulseAlpha

local function ApplyStyle()
  local o = Opt()
  local animate = o.glow and o.glowStyle == "pulse"
  if animate then
    pulse:SetScript("OnUpdate", function(self, elapsed)
      self.t = (self.t or 0) + (elapsed or 0)
      local a = PulseAlpha()
      for _, ov in pairs(G.overlays) do
        ov:SetAlpha(a)
      end
    end)
  else
    pulse:SetScript("OnUpdate", nil)
    for _, ov in pairs(G.overlays) do
      ov:SetAlpha(1)
    end
  end
end
G.ApplyStyle = ApplyStyle

local function PaintGlow(btn, rank)
  local ov = G.overlays[btn]
  if not rank then
    if ov then
      ov:Hide()
    end
    return
  end
  if not ov then
    ov = MakeOverlay(btn)
    G.overlays[btn] = ov
  end
  local k = INTENSITY[Opt().glowIntensity] or 0.8
  local c = TIER_COLOR[rank]
  local a = TIER_ALPHA[rank] * k
  ov.outer:SetVertexColor(c[1], c[2], c[3], a * 0.7)
  ov.inner:SetVertexColor(c[1], c[2], c[3], a)
  if ov.reticle then
    if rank == 1 and Opt().crosshair then
      ov.reticle:SetVertexColor(0.75, 1, 0.85, 0.95)
      ov.reticle:Show()
    else
      ov.reticle:Hide()
    end
  end
  ov.rank, ov.tierAlpha = rank, a
  ov:Show()
end

local function PaintTag(btn, nums)
  local t = G.tags[btn]
  if not nums then
    if t then
      t:Hide()
    end
    return
  end
  if not t then
    t = MakeTag(btn)
    G.tags[btn] = t
  end
  t.text:SetText(table.concat(nums, ","))
  t:SetWidth(#nums > 1 and (8 + 7 * #nums) or 15)
  t:Show()
end

-- Rebuild (out of combat only) ---------------------------------------------------------

local function HideAll()
  for _, ov in pairs(G.overlays) do
    ov:Hide()
  end
  for _, t in pairs(G.tags) do
    t:Hide()
  end
end

function G.Update()
  if L.InCombat() then
    G.pending = true
    return false
  end
  G.pending = false
  G.updates = G.updates + 1
  local o = Opt()
  local wantGlow, wantNums = o.glow, o.numbers
  local d
  if (wantGlow or wantNums) and Nock.IsHunter and Nock.IsHunter() then
    d = MR.Get(MR.CardProfile())
  end
  local prio, opener = {}, {}
  if d then
    local single
    for _, s in ipairs(d.sections or {}) do
      if s.key == "single" then
        single = s
      end
    end
    local seen = {}
    for _, r in ipairs(single and single.items or {}) do
      if r.action and not seen[r.action] and #prio < TOP then
        seen[r.action] = true
        prio[#prio + 1] = r
      end
    end
    opener = d.opener or {}
  end
  -- Start clean, so a button that left a bar (or a bar addon) loses its marks.
  HideAll()
  local state = {}
  for _, btn in ipairs(Buttons()) do
    local names = ButtonNames(btn)
    local rank, nums
    if wantGlow then
      for i, r in ipairs(prio) do
        if Matches(names, r) then
          rank = i
          break
        end
      end
    end
    if wantNums then
      for i, r in ipairs(opener) do
        if Matches(names, r) then
          nums = nums or {}
          nums[#nums + 1] = tostring(i)
        end
      end
    end
    PaintGlow(btn, rank)
    PaintTag(btn, nums)
    if rank or nums then
      state[btn] = { rank = rank, nums = nums and table.concat(nums, ",") or nil }
    end
  end
  G.state = state
  ApplyStyle()
  return true
end

local queued = false
local function Queue()
  if L.InCombat() then
    G.pending = true
    return
  end
  if queued then
    return
  end
  queued = true
  local function run()
    queued = false
    G.Update()
  end
  if C_Timer then
    C_Timer.After(0.3, run)
  else
    run()
  end
end
G.Queue = Queue

-- Every My Rotation rebuild (keys, bars, spells, level, talents, profile) redoes the glow.
local baseInvalidate = MR.Invalidate
function MR.Invalidate(...)
  baseInvalidate(...)
  if L.InCombat() then
    G.pending = true
  else
    G.Update()
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({
  "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_MACROS", "PLAYER_REGEN_ENABLED",
}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if G.pending then
      if C_Timer then
        C_Timer.After(0.2, G.Update)
      else
        G.Update()
      end
    end
  else
    Queue()
  end
end)

-- Options ------------------------------------------------------------------------------

local STYLE_LABEL = { steady = "Steady", pulse = "Pulse" }
local INT_LABEL = { low = "Low", medium = "Medium", high = "High" }

function G.SetGlow(on)
  Opt().glow = on and true or false
  if not on then
    for _, ov in pairs(G.overlays) do
      ov:Hide()
    end
    ApplyStyle()
  end
  Queue()
  UI.Refresh()
end

function G.SetNumbers(on)
  Opt().numbers = on and true or false
  if not on then
    for _, t in pairs(G.tags) do
      t:Hide()
    end
  end
  Queue()
  UI.Refresh()
end

function G.SetCrosshair(on)
  Opt().crosshair = on and true or false
  for btn, ov in pairs(G.overlays) do
    if ov:IsShown() and ov.rank then
      PaintGlow(btn, ov.rank)
    end
  end
  UI.Refresh()
end

function G.SetStyle(style)
  Opt().glowStyle = style
  ApplyStyle()
  UI.Refresh()
end

function G.SetIntensity(level)
  Opt().glowIntensity = level
  -- Re-tint what is already shown; safe in combat (Nock's own textures only).
  for btn, ov in pairs(G.overlays) do
    if ov:IsShown() and ov.rank then
      PaintGlow(btn, ov.rank)
    end
  end
  UI.Refresh()
end

local function NextOf(list, cur)
  for i, v in ipairs(list) do
    if v == cur then
      return list[i % #list + 1]
    end
  end
  return list[1]
end

UI.profileOptionHooks = UI.profileOptionHooks or {}
table.insert(UI.profileOptionHooks, function(page, CheckBox)
  local glow = CheckBox(page, "Priority glow",
    "A soft emerald glow on the buttons for your top 3 single-target spells from your written plan: brightest (with a crosshair) on #1. It is set out of combat and never changes during a fight.",
    function() return Opt().glow end, G.SetGlow)
  glow:SetPoint("TOPLEFT", 12, -460)
  page.checks[#page.checks + 1] = glow
  local nums = CheckBox(page, "Opener numbers",
    "Small 1, 2, 3 tags on the buttons for your opener from My Rotation, on the left edge so they don't cover the key or charges.",
    function() return Opt().numbers end, G.SetNumbers)
  nums:SetPoint("TOPLEFT", 352, -460)
  page.checks[#page.checks + 1] = nums
  local style = L.PanelButton(page, "Steady", 74, {
    height = 20,
    tipTitle = "Glow style",
    tip = "Steady: always the same. Pulse: a slow fade on a clock, the same on every button. It never reacts to the fight.",
    onClick = function()
      G.SetStyle(NextOf(STYLE_ORDER, Opt().glowStyle))
    end,
  })
  style:SetPoint("TOPLEFT", 150, -463)
  local intensity = L.PanelButton(page, "Medium", 84, {
    height = 20,
    tipTitle = "Glow intensity",
    tip = "How bright the glow is: Low, Medium or High.",
    onClick = function()
      G.SetIntensity(NextOf(INTENSITY_ORDER, Opt().glowIntensity))
    end,
  })
  intensity:SetPoint("LEFT", style, "RIGHT", 4, 0)
  page.glowStyle, page.glowIntensity = style, intensity
end)

local baseProfilesRefresh = L.RefreshPage.profiles
L.RefreshPage.profiles = function(page, p)
  baseProfilesRefresh(page, p)
  if page.glowStyle then
    local o = Opt()
    page.glowStyle:SetText("Glow: " .. STYLE_LABEL[o.glowStyle])
    page.glowIntensity:SetText(INT_LABEL[o.glowIntensity])
    page.glowStyle:SetEnabled(o.glow and true or false)
    page.glowIntensity:SetEnabled(o.glow and true or false)
  end
end

-- Slash: /nock glow [steady|pulse|off|on|low|medium|high], /nock numbers ----------------

local baseSlash = SlashCmdList.NOCK
SlashCmdList.NOCK = function(msg)
  local m = string.lower(strtrim(msg or ""))
  local cmd, arg = m:match("^(%S+)%s*(.*)$")
  if cmd == "glow" then
    if arg == "" then
      G.SetGlow(not Opt().glow)
    elseif arg == "off" then
      G.SetGlow(false)
    elseif arg == "on" then
      G.SetGlow(true)
    elseif STYLE_LABEL[arg] then
      Opt().glow = true
      G.SetStyle(arg)
      G.SetGlow(true)
    elseif INT_LABEL[arg] then
      G.SetIntensity(arg)
    else
      return L.Print("/nock glow [on|off|steady|pulse|low|medium|high]")
    end
    local o = Opt()
    return L.Print("Priority glow " .. (o.glow and ("on (" .. o.glowStyle .. ", " .. o.glowIntensity .. ")") or "off") ..
      (L.InCombat() and ". It updates when combat ends." or "."))
  elseif cmd == "crosshair" then
    G.SetCrosshair(not Opt().crosshair)
    return L.Print("Crosshair on the top shot " .. (Opt().crosshair and "on." or "off."))
  elseif cmd == "numbers" then
    G.SetNumbers(not Opt().numbers)
    return L.Print("Opener numbers " .. (Opt().numbers and "on." or "off.") .. (L.InCombat() and " They update when combat ends." or ""))
  end
  return baseSlash(msg)
end
