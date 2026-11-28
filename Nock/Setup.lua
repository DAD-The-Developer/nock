-- Nock 1.8.0 (1.9.0): "stupid simple" setup.
--  * One popup when this character isn't set up (or the setup is stale).
--  * Auto keep-up: newly available spells and macros go on their keys/bars.
--  * A gold "Spend talent point" button while you have points.
--  * The More tab, the simple/advanced view and the minimap click.
-- Everything here only writes bindings, action slots and macros, and only out
-- of combat. Nothing reads fight state (target, health, cooldowns, auras).

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
local MR = UI.MyRot

local S = {}
Nock.Setup = S
UI.Setup = S

local function Print(msg)
  if Nock.Print then
    Nock.Print(msg)
  end
end

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function InCombat()
  return (InCombatLockdown and InCombatLockdown()) or false
end

local function IsHunter()
  return Nock.IsHunter and Nock.IsHunter()
end

local function Level()
  return (Nock.PlayerLevel and Nock.PlayerLevel()) or (UnitLevel and UnitLevel("player")) or 1
end

function S.CharName()
  local name, realm = UnitName("player")
  if not realm or realm == "" then
    realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
  end
  return (name or "?") .. "-" .. realm
end

-- "1.7.0" < "1.8.0"
function S.VersionLess(a, b)
  local function parts(v)
    local t = {}
    for n in tostring(v or "0"):gmatch("%d+") do
      t[#t + 1] = tonumber(n)
    end
    return t
  end
  local x, y = parts(a), parts(b)
  for i = 1, math.max(#x, #y) do
    local p, q = x[i] or 0, y[i] or 0
    if p ~= q then
      return p < q
    end
  end
  return false
end

local function Profiles()
  return Nock.Profiles or {}
end

-- Layout for a profile (the profile decides overrides, so swap it in briefly).
local function LayoutForProfile(p)
  local db = DB()
  local prev = db.profile
  db.profile = p.key
  local ok, layout = pcall(Nock.LayoutFor, p.spec)
  db.profile = prev
  return ok and layout or {}
end

local function Available(entry)
  if Nock.EntryKnown then
    return Nock.EntryKnown(entry) and true or false
  end
  if entry.kind == "macro" then
    return (not entry.requires) or Nock.PlayerKnows(entry.requires)
  end
  return Nock.PlayerKnows(entry.name) and true or false
end

local function SortedKeys(layout)
  local order, seen = {}, {}
  for _, k in ipairs(Nock.KeycapOrder or {}) do
    if layout[k] and not seen[k] then
      order[#order + 1] = k
      seen[k] = true
    end
  end
  local rest = {}
  for k in pairs(layout) do
    if not seen[k] then
      rest[#rest + 1] = k
    end
  end
  table.sort(rest)
  for _, k in ipairs(rest) do
    order[#order + 1] = k
  end
  return order
end

local function KeyLabel(key)
  return (Nock.KeyLabel and Nock.KeyLabel(key)) or key
end

local function Label(entry)
  return entry.requires or (Nock.EntryLabel and Nock.EntryLabel(entry)) or entry.name
end

-- Auto-pick -----------------------------------------------------------------------

function S.AutoPick()
  local P = Profiles()
  local level = Level()
  if level >= 60 then
    local spec = Nock.DetectSpec and Nock.DetectSpec() or "bm"
    return spec == "bm" and P.bm60 or P.mm60
  end
  local bm, mm = 0, 0
  if Nock.TraitPointsByTab then
    local ok, a, b = pcall(Nock.TraitPointsByTab)
    if ok then
      bm, mm = tonumber(a) or 0, tonumber(b) or 0
    end
  end
  if mm > bm and mm >= 5 then
    return P.mmlvl
  end
  return P.bmlvl
end

-- The profile the popup offers: your pick ("change"), else your current
-- profile, else the auto-pick.
function S.Pick()
  local P = Profiles()
  if S.choice and P[S.choice] then
    return P[S.choice]
  end
  local db = DB()
  local cur = db.profile and P[db.profile]
  if cur then
    -- Hitting 60 moves a leveling profile to its 60 version.
    if Level() >= 60 and (cur.key == "bmlvl" or cur.key == "mmlvl") then
      return cur.spec == "bm" and P.bm60 or P.mm60
    end
    return cur
  end
  return S.AutoPick()
end

-- Key tracking --------------------------------------------------------------------
-- nockKeys[key] = the command Nock put there. If the key later holds something
-- else, you rebound it: it goes in userKeys and Nock never touches it again
-- (until you click Set me up). readyKeys[key] = what Nock last announced there.

local function Tables()
  local db = DB()
  db.nockKeys = db.nockKeys or {}
  db.userKeys = db.userKeys or {}
  db.readyKeys = db.readyKeys or {}
  db.userTold = db.userTold or {}
  return db
end

function S.Scan(p)
  local db = Tables()
  local layout = LayoutForProfile(p)
  local current = db.appliedInfo and db.appliedInfo.version == Nock.Version and db.appliedInfo.char == S.CharName()
  local missing, newUser, cleared = {}, {}, {}
  local total = 0
  for _, key in ipairs(SortedKeys(layout)) do
    if Nock.Book and Nock.Book.OwnsKey and Nock.Book.OwnsKey(key) then
      -- Override-only: never "missing", but remember if the key is already yours.
      -- Leave retired leftover binds (Shift-6 Wing Clip, etc.) for RetireOldKeys.
      local e = layout[key]
      local cur = GetBindingAction(key, true) or ""
      local retired = Nock.RetiredKeys and Nock.RetiredKeys[key] == cur
      if (not retired) and cur ~= "" and db.userKeys[key] == nil then
        local want = e and Nock.BindingCommand(e)
        if cur ~= want then
          db.userKeys[key] = cur
        end
      end
    else
    local e = layout[key]
    if Available(e) then
      total = total + 1
      local want = Nock.BindingCommand(e)
      local cur = GetBindingAction(key, true) or ""
      local mine = db.nockKeys[key]
      if e.ifFree and db.userKeys[key] == nil and cur ~= want and not (mine and cur ~= "" and cur ~= mine) then
        -- 2.0.1 racial keys: bound by keep-up only while free. A key that
        -- already does something of yours is quietly yours; never "missing".
        if (cur ~= "" and not mine) or (cur == "" and mine) then
          db.userKeys[key] = cur
          db.userTold[key] = true
        end
      elseif db.userKeys[key] ~= nil then
        if cur == want then
          db.userKeys[key] = nil -- you put Nock's spell back yourself
          db.nockKeys[key] = want
        end
      elseif cur == want then
        db.nockKeys[key] = want
        if e.kind == "macro" and GetMacroIndexByName(e.name) == 0 then
          missing[#missing + 1] = key
        end
      elseif cur == "" then
        if mine then
          cleared[#cleared + 1] = key
        else
          missing[#missing + 1] = key
        end
      elseif mine and cur ~= mine then
        db.userKeys[key] = cur
        newUser[#newUser + 1] = key
      elseif not mine and current then
        -- Bound to something else before Nock had a spell for it: yours.
        db.userKeys[key] = cur
        newUser[#newUser + 1] = key
      else
        missing[#missing + 1] = key
      end
    end
    end
  end
  -- A few cleared keys = you unbound them. Most of them = bindings were lost.
  if #cleared >= 3 and #cleared * 2 >= total then
    for _, k in ipairs(cleared) do
      missing[#missing + 1] = k
    end
  else
    for _, k in ipairs(cleared) do
      db.userKeys[k] = ""
      newUser[#newUser + 1] = k
    end
  end
  return missing, newUser, layout
end

function S.TellUser(keys, layout)
  local db = Tables()
  for _, key in ipairs(keys or {}) do
    if not db.userTold[key] then
      db.userTold[key] = true
      local e = layout and layout[key]
      Print(string.format("You changed %s yourself, so Nock will leave it alone%s. /nock setup gives it back to Nock.",
        KeyLabel(key), e and (" (Nock had " .. Label(e) .. " there)") or ""))
    end
  end
end

-- Record what a successful apply bound, for this character and version.
local function RecordApply(p)
  local db = Tables()
  local layout = LayoutForProfile(p)
  db.nockKeys, db.userKeys, db.readyKeys, db.userTold = {}, {}, {}, {}
  for key, e in pairs(layout) do
    local want = Nock.BindingCommand(e)
    if (GetBindingAction(key, true) or "") == want then
      db.nockKeys[key] = want
      if Available(e) then
        db.readyKeys[key] = want
      end
    end
  end
  db.appliedInfo = { profile = p.key, version = Nock.Version, char = S.CharName(), time = time and time() or 0 }
  db.setupYes = true
  db.setupDeclined = nil
end

local baseApply = Nock.ApplyProfile
function Nock.ApplyProfile(key, ...)
  local db = DB()
  local r = baseApply(key, ...)
  local p = Profiles()[key]
  if p and db.applied and db.profile == key and db.version == Nock.Version and not InCombat() then
    RecordApply(p)
  end
  if MR and MR.SyncCardButton then
    MR.SyncCardButton()
  end
  return r
end

local baseRestore = Nock.RestoreKeys
if baseRestore then
  function Nock.RestoreKeys(...)
    local r = baseRestore(...)
    local db = DB()
    if not db.applied then
      db.nockKeys, db.userKeys, db.readyKeys, db.userTold = {}, {}, {}, {}
      db.appliedInfo = nil
      db.setupYes = nil
      db.setupDeclined = true -- you undid it: no more automatic popups
    end
    if MR and MR.SyncCardButton then
      MR.SyncCardButton()
    end
    return r
  end
end

-- Status ---------------------------------------------------------------------------

function S.Status()
  if not IsHunter() then
    return { needs = false }
  end
  local db = DB()
  local info = db.appliedInfo
  local P = Profiles()
  if not db.applied or not db.profile or not P[db.profile] then
    return { needs = true, reason = "first", text = "Nock isn't set up on this character yet." }
  end
  if not info then
    return { needs = true, reason = "version",
      text = "Nock was updated to " .. Nock.Version .. ". One click checks and refreshes your keys, bars and macros." }
  end
  if info.char ~= S.CharName() then
    return { needs = true, reason = "char", text = "Nock was set up for " .. tostring(info.char) .. ", not this character." }
  end
  -- 2.0: only a change to keys, bars or macros (Nock.LayoutVersion) asks again.
  local need = Nock.LayoutVersion or Nock.Version
  if S.VersionLess(info.version, need) or S.VersionLess(db.version, need) then
    return { needs = true, reason = "version",
      text = "Nock was updated to " .. Nock.Version .. ". One click refreshes your keys, bars and macros." }
  end
  local missing, newUser, layout = S.Scan(P[db.profile])
  S.TellUser(newUser, layout)
  if #missing > 0 then
    local names = {}
    for i = 1, math.min(3, #missing) do
      local e = layout[missing[i]]
      names[#names + 1] = KeyLabel(missing[i]) .. " (" .. Label(e) .. ")"
    end
    return { needs = true, reason = "keys", missing = missing,
      text = string.format("%d Nock key%s not set: %s%s.", #missing, #missing == 1 and " is" or "s are",
        table.concat(names, ", "), #missing > 3 and (" and " .. (#missing - 3) .. " more") or "") }
  end
  return { needs = false }
end

function S.Needs()
  local ok, st = pcall(S.Status)
  return ok and st and st.needs or false
end

-- Apply (the big button) ---------------------------------------------------------------

function S.Apply(key)
  key = key or S.Pick().key
  local p = Profiles()[key]
  if not p then
    return false
  end
  if InCombat() then
    Print("Leave combat first. Nock sets up your keys as soon as you can.")
    S.applyQueued = key
    return false
  end
  Nock.capture = {}
  local ok, err = pcall(Nock.ApplyProfile, key)
  local lines = Nock.capture
  Nock.capture = nil
  local db = DB()
  if ok and db.applied and db.profile == key and db.appliedInfo and db.appliedInfo.version == Nock.Version then
    S.choice = nil
    S.snoozed = nil
    if S.frame then
      S.frame:Hide()
    end
    if Nock.SetOverlayShown and DB().overlay ~= false then
      Nock.SetOverlayShown(true)
    end
    local pts = Nock.UnspentTalentPoints and Nock.UnspentTalentPoints() or 0
    Print(string.format("Done! %s is set up: keys, bars and macros. Your keys are on the key bar; hold Alt over it for Hunting Notes.%s /nock restore undoes it.",
      p.label, (pts or 0) > 0 and " Click the gold button to spend your talent point." or ""))
    if MR and MR.Invalidate then
      MR.Invalidate()
    end
    S.UpdateTalentButton()
    if UI.Refresh then
      UI.Refresh()
    end
    return true
  end
  for _, l in ipairs(lines or {}) do
    Print(l)
  end
  if not ok then
    Print("Setup failed: " .. tostring(err))
  end
  return false
end

-- Popup ------------------------------------------------------------------------------

local W, H = 400, 290

local function BuildPopup()
  if S.frame then
    return S.frame
  end
  local f = L.TryCreate("Frame", "NockSetupFrame", UIParent, "DefaultPanelTemplate", "BackdropTemplate")
  f:SetSize(W, H)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if not L.Field(f, "TitleContainer") and not L.Field(f, "NineSlice") and f.SetBackdrop then
    f:SetBackdrop(L.TOOLTIP_BACKDROP)
  end
  if UISpecialFrames then
    table.insert(UISpecialFrames, "NockSetupFrame")
  end
  local tc = L.Field(f, "TitleContainer")
  local tt = tc and L.Field(tc, "TitleText") or L.Field(f, "TitleText")
  if not tt then
    tt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    EnsureFont(tt, "GameFontNormal")
    tt:SetPoint("TOP", 0, -6)
  end
  tt:SetText("Nock")
  local close = L.TryCreate("Button", nil, f, "UIPanelCloseButtonDefaultAnchors", "UIPanelCloseButton")
  close:ClearAllPoints()
  close:SetPoint("TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() S.NotNow() end)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(48, 48)
  icon:SetPoint("TOPLEFT", 18, -34)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  L.SetIcon(icon, L.HUNTER_ICON)
  f.icon = icon

  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(head, "GameFontNormalLarge")
  head:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
  head:SetText("Let's set up your keys")
  f.head = head
  local reason = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(reason, "GameFontHighlightSmall")
  reason:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
  reason:SetWidth(W - 100)
  reason:SetJustifyH("LEFT")
  reason:SetTextColor(0.8, 0.8, 0.8)
  f.reason = reason

  -- Picked profile, one line, with a small "change" link.
  local picon = f:CreateTexture(nil, "ARTWORK")
  picon:SetSize(20, 20)
  picon:SetPoint("TOPLEFT", 22, -100)
  picon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.picon = picon
  local pline = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  EnsureFont(pline, "GameFontHighlight")
  pline:SetPoint("LEFT", picon, "RIGHT", 8, 0)
  pline:SetJustifyH("LEFT")
  f.pline = pline
  local change = CreateFrame("Button", nil, f)
  change:SetSize(50, 18)
  change:SetPoint("LEFT", pline, "RIGHT", 6, 0)
  local cfs = change:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(cfs, "GameFontNormalSmall")
  cfs:SetPoint("LEFT")
  cfs:SetText("change")
  change.fs = cfs
  change:SetScript("OnEnter", function(self)
    self.fs:SetTextColor(1, 1, 1)
    L.ShowTip(self, "Change profile", { "Cycles Beast Mastery and Marksmanship, leveling and level 60." })
  end)
  change:SetScript("OnLeave", function(self)
    self.fs:SetTextColor(1, 0.82, 0)
    L.HideTip()
  end)
  change:SetScript("OnClick", function()
    L.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    S.CycleChoice()
  end)
  f.change = change

  local what = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(what, "GameFontDisableSmall")
  what:SetPoint("TOPLEFT", 22, -128)
  what:SetWidth(W - 44)
  what:SetJustifyH("LEFT")
  what:SetText("Binds your keys, fills your action bar and makes Nock's macros. Your old keys are saved: /nock restore undoes it.")
  f.what = what

  -- 3.8.0: the one key question. Nock's layout (its left-hand keys take priority while on), or your
  -- own keybinds (Nock sets no keys; buttons show the keys you use).
  local klabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(klabel, "GameFontNormal")
  klabel:SetPoint("TOPLEFT", 22, -172)
  klabel:SetText("Keys")
  local function KeyChoice(text, own, tip)
    local b = L.PanelButton(f, text, 150, {
      lock = true,
      tip = tip,
      onClick = function()
        if Nock.Binds then
          Nock.Binds.SetOwn(own)
        end
        S.Paint()
      end,
    })
    b:SetHeight(26)
    return b
  end
  f.keyNock = KeyChoice("Nock layout", false, Nock.Binds and Nock.Binds.LAYOUT_TEXT or "Nock's left-hand keys take priority while it's on.")
  f.keyOwn = KeyChoice("My own keybinds", true, "Nock sets no keys at all. Every Nock button shows the key you already use for that spell. Your keybinds are backed up either way: /nock binds.")
  f.keyNock:SetPoint("LEFT", klabel, "RIGHT", 16, 0)
  f.keyOwn:SetPoint("LEFT", f.keyNock, "RIGHT", 8, 0)

  local go = L.PanelButton(f, "Nock: Set me up", 240, {
    height = 36, lock = true,
    tipTitle = "Nock: Set me up",
    tip = "One click: keys, bars and macros for the profile above. Out of combat only.",
    onClick = function()
      if Nock.OwnBinds and Nock.OwnBinds() then
        f:Hide()
        Print("Using your own keybinds. Nock's buttons show your keys; it sets none. Change it any time in Options > Keybind backup.")
        return
      end
      S.Apply(S.Pick().key)
    end,
  })
  go:SetPoint("BOTTOM", 0, 44)
  local gfs = go.GetFontString and go:GetFontString()
  if gfs then
    gfs:SetFontObject("GameFontNormalLarge")
  end
  f.go = go
  local no = L.PanelButton(f, "Not now", 100, {
    tip = "Hides this until next login. /nock setup brings it back.",
    onClick = function()
      S.NotNow()
    end,
  })
  no:SetPoint("BOTTOM", 0, 14)
  f.no = no

  f:SetScript("OnShow", function()
    S.Paint()
  end)
  f:Hide()
  S.frame = f
  return f
end

function S.CycleChoice()
  local order = Nock.ProfileOrder or { "bmlvl", "bm60", "mmlvl", "mm60" }
  local cur = S.Pick().key
  local nextKey = order[1]
  for i, k in ipairs(order) do
    if k == cur then
      nextKey = order[i % #order + 1]
    end
  end
  S.choice = nextKey
  S.Paint()
end

function S.Paint()
  local f = S.frame
  if not f then
    return
  end
  local p = S.Pick()
  local st = S.status or S.Status()
  L.SetIcon(f.picon, L.PROFILE_ICONS[p.key])
  local why = S.choice and "your pick" or ("picked for level " .. Level())
  f.pline:SetText(p.label .. "  |cff999999(" .. why .. ")|r")
  f.reason:SetText(st.text or ("Everything is already set up. Clicking again re-applies " .. p.label .. "."))
  local own = Nock.OwnBinds and Nock.OwnBinds() or false
  if f.keyNock and f.keyOwn then
    local on, off = own and f.keyOwn or f.keyNock, own and f.keyNock or f.keyOwn
    if on.LockHighlight then on:LockHighlight() end
    if off.UnlockHighlight then off:UnlockHighlight() end
    local fon, foff = on.GetFontString and on:GetFontString(), off.GetFontString and off:GetFontString()
    if fon and fon.SetTextColor then fon:SetTextColor(1, 0.82, 0) end
    if foff and foff.SetTextColor then foff:SetTextColor(0.6, 0.6, 0.6) end
  end
  if f.go then
    f.go:SetText(own and "Done: use my own keybinds" or "Nock: Set me up")
  end
  if f.what then
    f.what:SetText(own and "Nock sets no keys. Its buttons show the keys you already use. Your keybinds are backed up: /nock binds."
      or "Nock's left-hand keys take priority while on. Set me up also saves Nock's keys and bars into your keybinds; undo with /nock binds restore.")
  end
  L.UpdateButtonStates()
end

function S.Show(force)
  if not IsHunter() then
    return Print("This is a hunter addon.")
  end
  if force then
    S.snoozed = nil
  end
  local f = BuildPopup()
  S.status = S.Status()
  f:Show()
  S.Paint()
  L.Sound("IG_MAINMENU_OPEN")
  return f
end

function S.NotNow()
  S.snoozed = true
  if S.frame then
    S.frame:Hide()
  end
  L.Sound("IG_MAINMENU_CLOSE")
  Print("OK. Type /nock setup when you want it.")
end

local TipLines
local function HookMinimap()
  if UI.minimap and not S.minimapHooked then
    S.minimapHooked = true
    L.AttachTip(UI.minimap, function()
      return TipLines()
    end)
  end
end

-- Login check. Out of combat only; in combat it waits for combat to end.
function S.Check()
  if not IsHunter() then
    return
  end
  if InCombat() then
    S.checkPending = true
    return
  end
  S.checkPending = nil
  HookMinimap()
  local db = DB()
  if db.appliedInfo and db.appliedInfo.char ~= S.CharName() then
    db.applied = false
  end
  local st = S.Status()
  S.status = st
  -- 3.0: no setup popup on login. The bar appears and empty keys are filled.
  -- /nock setup still opens the window if someone wants a full apply.
  if not db.setupDeclined and Nock.BootQuiet then
    Nock.BootQuiet()
  end
  if MR and MR.SyncCardButton then
    MR.SyncCardButton()
  end
end

-- Auto keep-up --------------------------------------------------------------------------

function S.KeepUpActive()
  local db = DB()
  -- 3.0: fill empty keys by themselves, even if the player never clicked
  -- setup. Restore-my-old-keys (setupDeclined) turns this off.
  if Nock.OwnBinds and Nock.OwnBinds() then
    return false -- 3.8.0: "Use my own keybinds": Nock fills no keys
  end
  return db.autofill ~= false and not db.setupDeclined and IsHunter() and true or false
end

function Nock.KeepUpHandles()
  return S.KeepUpActive()
end

local function PlaceOnSlot(entry)
  if not entry.slot or HasAction(entry.slot) or GetCursorInfo() then
    return
  end
  if Nock.PickupEntry(entry) then
    PlaceAction(entry.slot)
  end
  if Nock.ClearCursorSafe then
    Nock.ClearCursorSafe()
  end
end

function S.KeepUp()
  S.keepQueued = nil
  if not S.KeepUpActive() then
    return 0
  end
  if InCombat() then
    S.keepPending = true
    return 0
  end
  S.keepPending = nil
  local db = Tables()
  local p = db.profile and Profiles()[db.profile]
  if not p then
    p = S.Pick and S.Pick() or nil
    if p then
      db.profile = p.key
      if p.spec then
        db.spec = p.spec
      end
    end
  end
  if not p then
    return 0
  end
  local _, newUser, layout = S.Scan(p)
  S.TellUser(newUser, layout)
  local changes, bound, added = {}, false, {}
  S.lastAdded = added
  -- 1.9: clear keys Nock no longer uses (Shift-6) if they still hold Nock's spell.
  if Nock.RetireOldKeys and Nock.RetireOldKeys() > 0 then
    bound = true
  end
  for _, key in ipairs(SortedKeys(layout)) do
    if Nock.Book and Nock.Book.OwnsKey and Nock.Book.OwnsKey(key) then
      -- 3.0.9 override binds; do not SaveBindings these keys.
    else
    local e = layout[key]
    if db.userKeys[key] == nil and Available(e) then
      local want = Nock.BindingCommand(e)
      local cur = GetBindingAction(key, true) or ""
      local okMacro = Nock.EnsureMacro(e)
      if okMacro and cur ~= want and (cur == "" or cur == db.nockKeys[key]) then
        SetBinding(key)
        if e.kind == "macro" then
          SetBindingMacro(key, e.name)
        else
          SetBindingSpell(key, e.name)
        end
        db.nockKeys[key] = want
        cur = want
        bound = true
        PlaceOnSlot(e)
      end
      if cur == want and db.readyKeys[key] ~= want then
        db.readyKeys[key] = want
        changes[#changes + 1] = Label(e) .. " is now on " .. KeyLabel(key) .. "."
        added[#added + 1] = Label(e) .. " (" .. KeyLabel(key) .. ")"
      end
    end
    end
  end
  if bound then
    SaveBindings(GetCurrentBindingSet())
  end
  -- 2.0: one line in chat for everything that was added.
  -- 3.10.2: Nock.Auto says these together with new spells, ranks and pet skills.
  if #changes > 0 and Nock.Auto and Nock.Auto.Placed and Nock.Auto.Placed(changes) then
    -- taken
  elseif #changes == 1 then
    Print(changes[1])
  elseif #changes > 1 then
    Print("New on your keys: " .. table.concat(S.lastAdded or {}, ", ") .. ".")
  end
  if #changes > 0 then
    if MR and MR.Invalidate then
      MR.Invalidate()
    end
    if Nock.UpdateOverlay then
      Nock.UpdateOverlay()
    end
  end
  return #changes
end

function S.QueueKeepUp()
  if S.keepQueued then
    return
  end
  S.keepQueued = true
  if C_Timer and C_Timer.After then
    C_Timer.After(1, S.KeepUp)
  else
    S.KeepUp()
  end
end

-- Talent point reminder -------------------------------------------------------------------

local tbtn

local function BuildTalentButton()
  if tbtn then
    return tbtn
  end
  tbtn = L.TryCreate("Button", "NockTalentButton", UIParent, "UIPanelButtonTemplate")
  tbtn:SetSize(150, 24)
  tbtn:SetFrameStrata("MEDIUM")
  tbtn:SetText("Spend talent point")
  local fs = tbtn.GetFontString and tbtn:GetFontString()
  if fs then
    fs:SetTextColor(1, 0.82, 0)
  end
  local glow = tbtn:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", -6, 6)
  glow:SetPoint("BOTTOMRIGHT", 6, -6)
  glow:SetColorTexture(1, 0.82, 0, 0.18)
  tbtn.glow = glow
  tbtn:SetScript("OnClick", function()
    if InCombat() then
      return
    end
    L.Sound("IG_MAINMENU_OPTION")
    local p = Nock.ActiveProfile and Nock.ActiveProfile() or S.Pick()
    Nock.LearnNextTalent(p)
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, S.UpdateTalentButton)
    end
    S.UpdateTalentButton()
  end)
  L.AttachTip(tbtn, function()
    local p = Nock.ActiveProfile and Nock.ActiveProfile() or S.Pick()
    local line = Nock.NextTalentLine and Nock.NextTalentLine(p.spec, Level()) or ""
    return "Spend talent point", { "Learns the next talent in " .. p.label .. ".", line,
      { "Turn off on the Options tab, or /nock remind.", 0.6, 0.6, 0.6 } }
  end)
  tbtn:Hide()
  return tbtn
end

function S.UpdateTalentButton()
  local db = DB()
  local pts = Nock.UnspentTalentPoints and Nock.UnspentTalentPoints() or 0
  local want = IsHunter() and db.talentReminder ~= false and (pts or 0) > 0 and Level() >= 10
  if not want then
    if tbtn then
      tbtn:Hide()
    end
    return false
  end
  -- A secure-free plain button: still, keep changes out of combat.
  if InCombat() then
    if tbtn then
      tbtn:Hide()
    end
    return false
  end
  local b = BuildTalentButton()
  b:SetText(pts > 1 and ("Spend " .. pts .. " talent points") or "Spend talent point")
  b:ClearAllPoints()
  local card = _G.NockRotationCard
  if card and card:IsShown() then
    b:SetPoint("TOP", card, "BOTTOM", 0, -6)
  elseif Minimap then
    b:SetPoint("TOP", Minimap, "BOTTOM", 0, -24)
  else
    b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -220)
  end
  b:Show()
  return true
end

if MR and MR.SetCardShown then
  local baseCard = MR.SetCardShown
  function MR.SetCardShown(...)
    local r = baseCard(...)
    S.UpdateTalentButton()
    return r
  end
end

-- The More tab ------------------------------------------------------------------------------

local ENTRIES = {
  { "Profiles and options", "Pick BM or MM, apply, restore your old keys, and every option.",
    "Interface\\Icons\\INV_Misc_Gear_01", function() UI.SelectTab("profiles") end },
  { "Written rotation", "The full rotation for your profile, in words.",
    "Interface\\Icons\\INV_Misc_Book_09", function() UI.SelectTab("rotation") end },
  { "Macros", "Every Nock macro and what it does.",
    "Interface\\Icons\\INV_Misc_Note_01", function() UI.SelectTab("macros") end },
  { "Field Manual", "Pet care, Auto Shot rules, and what to do next.",
    "Interface\\Icons\\INV_Misc_Book_11", function() UI.SelectTab("manual") end },
}

local function BuildMore(page)
  page.footer = "Written guides. Read them before the fight; Nock never watches it."
  local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(title, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("Guide")
  title:SetTextColor(0.84, 1, 0.91)
  local sub = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(sub, "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  sub:SetTextColor(0.75, 0.75, 0.75)
  sub:SetText("Profiles, the written rotation, macros and the Field Manual.")
  page.rows = {}
  local colW = math.floor(((L.CONTENT_W or 640) - 40) / 2)
  for i, e in ipairs(ENTRIES) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local b = CreateFrame("Button", nil, page, "BackdropTemplate")
    b:SetSize(colW, 58)
    b:SetPoint("TOPLEFT", 14 + col * (colW + 12), -58 - row * 66)
    if b.SetBackdrop then
      b:SetBackdrop(L.TOOLTIP_BACKDROP)
      b:SetBackdropColor(0.03, 0.09, 0.07, 0.85)
      b:SetBackdropBorderColor(0.5, 0.66, 0.6, 0.9)
    end
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetSize(36, 36)
    ic:SetPoint("LEFT", 10, 0)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    L.SetIcon(ic, e[3])
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    EnsureFont(t, "GameFontNormal")
    t:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, -1)
    t:SetText(e[1])
    local d = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    EnsureFont(d, "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    d:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    d:SetJustifyH("LEFT")
    d:SetTextColor(0.75, 0.75, 0.75)
    d:SetText(e[2])
    b:SetScript("OnEnter", function(self)
      if self.SetBackdropBorderColor then
        self:SetBackdropBorderColor(0.3, 1, 0.62, 1)
      end
    end)
    b:SetScript("OnLeave", function(self)
      if self.SetBackdropBorderColor then
        self:SetBackdropBorderColor(0.5, 0.66, 0.6, 0.9)
      end
    end)
    b:SetScript("OnClick", function()
      L.Sound("IG_MAINMENU_OPTION")
      e[4]()
    end)
    b.title = e[1]
    page.rows[i] = b
  end
  page.checks = {}
  return page
end

UI.extraPages = UI.extraPages or {}
UI.extraPages.advanced = BuildMore
L.RefreshPage.advanced = function(page)
  for _, cb in ipairs(page.checks or {}) do
    cb:Sync()
  end
end

-- Minimap / compartment click ------------------------------------------------------------------
-- Simple view: left = the My Rotation card (or setup), right = the Nock window.
-- Advanced view: what 1.7 did (left = window, right = keyboard card).

local baseClick = _G.Nock_OnAddonCompartmentClick
function _G.Nock_OnAddonCompartmentClick(name, button, ...)
  if not (UI.IsSimple and UI.IsSimple()) then
    if baseClick then
      return baseClick(name, button, ...)
    end
    return
  end
  -- 2.0: left = the Nock window (or setup), right = Hunting Notes.
  if button == "RightButton" then
    if MR and MR.SetCardShown then
      MR.SetCardShown(not MR.IsCardShown())
    end
    return
  end
  return UI.Toggle()
end

function TipLines()
  if UI.IsSimple and UI.IsSimple() then
    return "Nock", {
      "Left-click: open Nock",
      "Right-click: Hunting Notes (what to press)",
    }
  end
  return "Nock", { "Left-click: open Nock", "Right-click: keyboard card" }
end

local baseEnter = _G.Nock_OnAddonCompartmentEnter
function _G.Nock_OnAddonCompartmentEnter(name, owner, ...)
  if owner and GameTooltip then
    local t, lines = TipLines()
    L.ShowTip(owner, t, lines)
    return
  end
  if baseEnter then
    return baseEnter(name, owner, ...)
  end
end

-- Slash ---------------------------------------------------------------------------------------

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg, ...)
    local cmd, rest = tostring(msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "setup" then
      return S.Show(true)
    elseif cmd == "simple" then
      UI.SetView("simple")
      Nock.ShowPanel("myrot")
      return Print("Simple view: My Rotation, Talents, Guide and Options.")
    elseif cmd == "advanced" then
      UI.SetView("advanced")
      Nock.ShowPanel("profiles")
      return Print("Advanced view: all tabs. /nock simple goes back.")
    elseif cmd == "keepup" then
      local db = DB()
      if rest == "on" then
        db.autofill = true
      elseif rest == "off" then
        db.autofill = false
      else
        db.autofill = db.autofill == false
      end
      if db.autofill ~= false then
        S.QueueKeepUp()
      end
      return Print("Auto keep-up is " .. (db.autofill ~= false and "on." or "off."))
    elseif cmd == "remind" then
      local db = DB()
      db.talentReminder = db.talentReminder == false
      S.UpdateTalentButton()
      return Print("Talent point reminder is " .. (db.talentReminder ~= false and "on." or "off."))
    end
    return baseSlash(msg, ...)
  end
end

-- Events ----------------------------------------------------------------------------------------

local ev = CreateFrame("Frame")
for _, e in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
  "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED",
  "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
}) do
  pcall(ev.RegisterEvent, ev, e)
end

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    HookMinimap()
    if not S.loginChecked then
      S.loginChecked = true
      if C_Timer and C_Timer.After then
        C_Timer.After(3, S.Check)
      else
        S.Check()
      end
    end
    S.UpdateTalentButton()
  elseif event == "PLAYER_REGEN_DISABLED" then
    if tbtn then
      tbtn:Hide()
    end
    L.UpdateButtonStates()
  elseif event == "PLAYER_REGEN_ENABLED" then
    L.UpdateButtonStates()
    if S.checkPending then
      S.Check()
    end
    if S.applyQueued then
      local k = S.applyQueued
      S.applyQueued = nil
      S.Apply(k)
    end
    if S.keepPending then
      S.KeepUp()
    end
    S.UpdateTalentButton()
  elseif event == "SPELLS_CHANGED" then
    -- Only matters if a learn event was missed; cheap because KeepUp is debounced.
    if S.KeepUpActive() and S.loginChecked then
      S.QueueKeepUp()
    end
  else
    -- Level-up, new spell, talent change.
    S.QueueKeepUp()
    S.UpdateTalentButton()
  end
end)

-- 2.1.0 keymap move + mouse buttons ----------------------------------------------------
-- Lives in Setup.lua (not a new file) so a plain /reload picks it up: WoW only
-- reads new files listed in a .toc after a full restart.
--[[ Keymap21
  Nock 2.1.0: the 2.1 keymap move (KEYMAP-2.1.md) and the mouse buttons.
  * A character set up on an older Nock gets ONE popup: Move my keys / Not now
    / Keep mouse off. Nothing moves until you click.
  * A key moves only if it still holds exactly what Nock put there. Anything
    you bound yourself stays yours. Mouse buttons are used only while empty.
  * Every key 2.1 touches joins the Restore Keys snapshot first, so "Restore
    my old keys" puts back what you had before Nock, mouse included.
  * Writes bindings only, and only out of combat. Nothing reads the fight.
]]

do
local L = UI.lib
local S = Nock.Setup
local MR = UI.MyRot

local K = {}
Nock.Keymap21 = K
local KM = Nock.KeymapVersion or "2.1"

local function Print(msg)
  if Nock.Print then
    Nock.Print(msg)
  end
end

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function InCombat()
  return (InCombatLockdown and InCombatLockdown()) or false
end

local function KeyLabel(key)
  return (Nock.KeyLabel and Nock.KeyLabel(key)) or key
end

-- Keys Nock 2.0.1 used that mean something else in 2.1, with what 2.0.1 put
-- there. (Keys 2.1 hands back entirely, like V, C and Shift-Z, are in
-- Nock.RetiredKeys and cleared by Nock.RetireOldKeys.)
local MOVED = {
  ["T"] = { "MACRO Nock:Pet", "MACRO Nock:PetGo" },
  ["SHIFT-Q"] = { "MACRO Nock:PetGo" },
  ["ALT-Q"] = { "MACRO Nock:PetBack" },
  ["SHIFT-T"] = { "SPELL Flare" },
  ["SHIFT-X"] = { "SPELL Explosive Trap" },
  ["SHIFT-F"] = { "SPELL Immolation Trap" },
  ["ALT-F"] = { "SPELL Frost Trap" },
  ["Z"] = { "SPELL Aspect of the Monkey", "SPELL Aspect of the Viper" },
  ["SHIFT-C"] = { "SPELL Aspect of the Pack" },
  ["SHIFT-E"] = { "MACRO Nock:Intim", "SPELL Intimidation" },
  ["SHIFT-3"] = { "MACRO Nock:Wrath", "SPELL Bestial Wrath" },
  ["SHIFT-G"] = { "SPELL Tranquilizing Shot" },
  ["SHIFT-R"] = { "SPELL Viper Sting" },
}
K.Moved = MOVED

-- What the popup and /nock keys list (KEYMAP-2.1.md "What changes").
local CHANGES = {
  { "Mouse 4", "Wing Clip (was Shift-Z, which is now empty)", mouse = true },
  { "Mouse 5", "Concussive Shot (Q still works)", mouse = true },
  { "Wheel click", "Feign Death (E still works)", mouse = true },
  { "Shift + Mouse 4 / 5", "Strider Kick / Scatter Shot, once you have them", mouse = true },
  { "T", "Pet attack (was Call / Revive)" },
  { "Shift-T / Alt-T", "Pet follow / Pet stay" },
  { "Ctrl-G", "Call / Revive Pet" },
  { "Ctrl-T", "Feed Pet (was V)" },
  { "F / Shift-F / Alt-F / Ctrl-F", "Freezing / Frost / Immolation / Explosive trap" },
  { "X / Shift-X / Alt-X / Ctrl-X", "Hawk / Cheetah (was C) / Monkey / Pack" },
  { "Z / Ctrl-Z", "Aspect of the Wild / Aspect of the Beast" },
  { "Shift-Q / Alt-Q / Ctrl-Q", "Scatter Shot / Strider Kick / Scare Beast" },
  { "Shift-E / Ctrl-E", "Deterrence / Disengage (was `)" },
  { "Shift-G / Alt-G", "Bestial Wrath / Intimidation (BM, were Shift-3 / Shift-E)" },
  { "Alt-2 / Alt-3 / Alt-4", "Distracting / Tranquilizing / Flare" },
  { "Shift-5 / Alt-5", "Scorpid Sting / Viper Sting" },
  { "Shift-6", "Lacerate" },
  { "Shift-R / Alt-R", "Beast Lore / Eagle Eye" },
  { "H / Shift-H", "Eyes of the Beast / Tame Beast" },
  { "Shift / Alt / Ctrl-C", "Track Beasts / Humanoids / Hidden" },
  { "C and V", "back to Blizzard (character pane, nameplates)" },
}
K.Changes = CHANGES

local function Profile()
  local P = Nock.Profiles or {}
  return P[DB().profile]
end

local function LayoutNow()
  local p = Profile()
  if not (p and Nock.LayoutFor) then
    return {}
  end
  local ok, layout = pcall(Nock.LayoutFor, p.spec)
  return ok and layout or {}
end

function K.Pending()
  local db = DB()
  if not (Nock.IsHunter and Nock.IsHunter()) then
    return false
  end
  if Nock.OwnBinds and Nock.OwnBinds() then
    return false -- 3.8.0: own keybinds: nothing to migrate
  end
  return (db.applied and db.appliedInfo and Profile() and db.km ~= KM) and true or false
end

-- Every key 2.1 may write joins the Restore Keys snapshot before it changes.
function K.ExtendSnapshot(layout)
  local db = DB()
  local snap = db.snapshot
  if not (snap and snap.keys) then
    return
  end
  local function add(key)
    if snap.keys[key] == nil then
      snap.keys[key] = GetBindingAction(key, true) or ""
    end
  end
  for key in pairs(layout or {}) do
    add(key)
  end
  for key in pairs(MOVED) do
    add(key)
  end
  for key in pairs(Nock.RetiredKeys or {}) do
    add(key)
  end
  for _, m in ipairs(Nock.MouseKeys or {}) do
    add(m.key)
  end
  add("SHIFT-Z")
end

-- Mouse buttons that already do something that isn't Nock's.
function K.TakenMouse()
  local out = {}
  local track = DB().nockKeys or {}
  for _, m in ipairs(Nock.MouseKeys or {}) do
    local cur = GetBindingAction(m.key, true) or ""
    if cur ~= "" and cur ~= track[m.key] and not (m.key == "BUTTON4" and cur == "SPELL Wing Clip") then
      out[#out + 1] = m.key
    end
  end
  return out
end

-- Binds every layout key that is free or still Nock's to its 2.1 spell.
-- Keys you own (userKeys) are never touched.
function K.BindFree(p)
  local db = DB()
  p = p or Profile()
  if not p or InCombat() or (Nock.OwnBinds and Nock.OwnBinds()) then
    return 0, {}
  end
  if Nock.Binds then Nock.Binds.EnsureFirst() end
  local _, newUser, layout = S.Scan(p)
  S.TellUser(newUser, layout)
  local n, added = 0, {}
  for key, e in pairs(layout) do
    if Nock.Book and Nock.Book.OwnsKey and Nock.Book.OwnsKey(key) then
      -- 3.0.9 override binds; do not SaveBindings these keys.
    else
    local avail = Nock.EntryKnown and Nock.EntryKnown(e)
    if db.userKeys[key] == nil and avail then
      local want = Nock.BindingCommand(e)
      local cur = GetBindingAction(key, true) or ""
      if cur ~= want and (cur == "" or cur == db.nockKeys[key]) and Nock.EnsureMacro(e) then
        SetBinding(key)
        if e.kind == "macro" then
          SetBindingMacro(key, e.name)
        else
          SetBindingSpell(key, e.name)
        end
        db.nockKeys[key] = want
        n = n + 1
      end
      if (GetBindingAction(key, true) or "") == want then
        db.nockKeys[key] = want
        if db.readyKeys[key] ~= want then
          db.readyKeys[key] = want
          added[#added + 1] = key
        end
      end
    end
    end
  end
  return n, added
end

local function Refresh()
  if MR and MR.Invalidate then
    MR.Invalidate()
  end
  if Nock.UpdateOverlay then
    Nock.UpdateOverlay()
  end
  if UI.Refresh then
    pcall(UI.Refresh)
  end
end

-- The move. mouseOn = false is "Keep mouse off".
function K.Migrate(mouseOn)
  local db = DB()
  if not K.Pending() then
    return false
  end
  if InCombat() then
    K.queued = { mouse = mouseOn ~= false }
    Print("Leave combat first. Nock moves your keys as soon as the fight ends.")
    return false
  end
  K.queued = nil
  db.mouse = mouseOn ~= false
  local p = Profile()
  local taken = db.mouse and K.TakenMouse() or {}
  K.ExtendSnapshot(LayoutNow())
  db.nockKeys = db.nockKeys or {}
  db.userKeys = db.userKeys or {}
  db.readyKeys = db.readyKeys or {}
  db.userTold = db.userTold or {}
  -- 1. Clear keys that still hold what 2.0.1 put there.
  local layout = LayoutNow()
  local cleared = 0
  for key, olds in pairs(MOVED) do
    local cur = GetBindingAction(key, true) or ""
    local want = layout[key] and Nock.BindingCommand(layout[key])
    if db.userKeys[key] == nil and cur ~= "" and cur ~= want then
      for _, old in ipairs(olds) do
        if cur == old then
          SetBinding(key)
          db.nockKeys[key], db.readyKeys[key] = nil, nil
          cleared = cleared + 1
          break
        end
      end
    end
  end
  cleared = cleared + ((Nock.RetireOldKeys and Nock.RetireOldKeys()) or 0)
  -- 2. The 2.1 keymap is now current: a new key that already holds something
  --    of yours is yours (Setup's Scan treats it so for this version).
  db.km = KM
  db.version = Nock.Version
  if db.appliedInfo then
    db.appliedInfo.version = Nock.Version
  end
  -- 3. Bind what is free.
  local bound = K.BindFree(p)
  if SaveBindings and GetCurrentBindingSet then
    SaveBindings(GetCurrentBindingSet())
  end
  K.lastResult = { cleared = cleared, bound = bound, taken = taken, mouse = db.mouse }
  local msg = string.format("Nock 2.1 keys are in: %d moved, %d new.", cleared, bound)
  if db.mouse then
    msg = msg .. " Mouse 4 Wing Clip, Mouse 5 Concussive, wheel click Feign Death (once learned)."
  else
    msg = msg .. " Mouse buttons left off; Wing Clip stays on Shift-Z."
  end
  Print(msg .. " /nock keys lists them; Restore my old keys in Options undoes it.")
  for _, key in ipairs(taken) do
    Print((Nock.MouseName and Nock.MouseName[key] or KeyLabel(key)):gsub("^%l", string.upper)
      .. " already does something of yours, so Nock left it alone.")
  end
  if K.frame then
    K.frame:Hide()
  end
  Refresh()
  return true
end

function K.NotNow()
  K.snoozed = true
  if K.frame then
    K.frame:Hide()
  end
  Print("OK, your keys stay as they are. The red ! on the key bar or /nock migrate brings this back.")
end

-- Options checkbox and /nock mouse.
function K.SetMouse(on)
  local db = DB()
  if InCombat() then
    Print("Leave combat first.")
    return false
  end
  on = on and true or false
  if Nock.OwnBinds and Nock.OwnBinds() then
    db.mouse = on -- 3.8.0: own keybinds: remember the choice, change no keys
    Print("You use your own keybinds, so Nock changed no keys.")
    return true
  end
  if Nock.Binds then Nock.Binds.EnsureFirst() end
  if K.Pending() then
    db.mouse = on
    return true
  end
  K.ExtendSnapshot(LayoutNow())
  db.mouse = on
  local track = db.nockKeys or {}
  local cleared = 0
  if not on then
    for _, m in ipairs(Nock.MouseKeys or {}) do
      local cur = GetBindingAction(m.key, true) or ""
      if cur ~= "" and track[m.key] == cur then
        SetBinding(m.key)
        cleared = cleared + 1
      end
      track[m.key] = nil
      if db.readyKeys then db.readyKeys[m.key] = nil end
      if db.userKeys then db.userKeys[m.key] = nil end
    end
  end
  if on and db.userKeys then
    -- Turning it on again: empty buttons are fair game once more.
    for _, m in ipairs(Nock.MouseKeys or {}) do
      if (GetBindingAction(m.key, true) or "") == "" then
        db.userKeys[m.key] = nil
        if db.userTold then db.userTold[m.key] = nil end
        if db.nockKeys then db.nockKeys[m.key] = nil end
        if db.readyKeys then db.readyKeys[m.key] = nil end
      end
    end
  end
  if Nock.RetireOldKeys then
    Nock.RetireOldKeys() -- Shift-Z's Wing Clip goes when Mouse 4 takes it
  end
  local bound = 0
  if db.applied and Profile() then
    bound = K.BindFree(Profile())
  end
  if SaveBindings and GetCurrentBindingSet then
    SaveBindings(GetCurrentBindingSet())
  end
  if on then
    Print("Mouse buttons on: Mouse 4 Wing Clip, Mouse 5 Concussive, wheel click Feign Death. Only empty buttons are used.")
  else
    Print("Mouse buttons off. Nock cleared " .. cleared .. " of its mouse binds; Wing Clip is back on Shift-Z.")
  end
  Refresh()
  return true
end

-- Popup ----------------------------------------------------------------------------

local W = 470

local function Row(f, y, left, right)
  local a = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  EnsureFont(a, "GameFontNormalSmall")
  a:SetPoint("TOPLEFT", 22, y)
  a:SetWidth(130)
  a:SetJustifyH("LEFT")
  a:SetText(left)
  local b = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(b, "GameFontHighlightSmall")
  b:SetPoint("TOPLEFT", 158, y)
  b:SetWidth(W - 180)
  b:SetJustifyH("LEFT")
  b:SetText(right)
  return a, b
end

local function Build()
  if K.frame then
    return K.frame
  end
  local f = L.TryCreate("Frame", "NockKeymap21Frame", UIParent, "BackdropTemplate")
  f:SetSize(W, 330)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if L.Backdrop and L.TOOLTIP_BACKDROP then
    L.Backdrop(f, L.TOOLTIP_BACKDROP, 0.03, 0.07, 0.05, 0.96, 0.85, 0.66, 0.2, 1)
  elseif f.SetBackdrop then
    f:SetBackdrop(L.TOOLTIP_BACKDROP)
  end
  if UISpecialFrames then
    table.insert(UISpecialFrames, "NockKeymap21Frame")
  end
  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  EnsureFont(head, "GameFontNormalLarge")
  head:SetPoint("TOPLEFT", 20, -16)
  head:SetText("Nock 2.1: new keys")
  head:SetTextColor(1, 0.82, 0.3)
  local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(body, "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", 20, -42)
  body:SetWidth(W - 40)
  body:SetJustifyH("LEFT")
  body:SetText("Nock moves a few keys to make kiting easier and puts three spells on your mouse. Only keys that still hold Nock's own spell move. Keys you set yourself stay yours.")
  local y = -84
  f.rows = {}
  local rows = {
    { "Mouse button 4", "Wing Clip (was Shift-Z, which is now empty)" },
    { "Mouse button 5", "Concussive Shot (Q still works)" },
    { "Wheel click", "Feign Death (E still works)" },
    { "Shift + mouse 4 / 5", "Strider Kick / Scatter Shot, once you have them" },
    { "If one is taken", "" },
    { "Also moving", "T Pet attack, Ctrl-G Call/Revive, Shift-X Cheetah, C and V back to Blizzard, traps on F, Shift-5 / Shift-6 used (full list: /nock keys)" },
  }
  for i, r in ipairs(rows) do
    local a, b = Row(f, y, r[1], r[2])
    f.rows[i] = { a, b }
    y = y - (i == #rows and 30 or 18)
  end
  f.takenRow = f.rows[5]
  local foot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  EnsureFont(foot, "GameFontHighlightSmall")
  foot:SetPoint("TOPLEFT", 20, y - 6)
  foot:SetWidth(W - 40)
  foot:SetJustifyH("LEFT")
  foot:SetText("Mouse scrolling stays camera zoom. Turn the mouse keys off any time in Options.")
  local move = L.PanelButton(f, "Move my keys", 130, {
    lock = true,
    tip = "Moves Nock's keys to the 2.1 layout and puts Wing Clip, Concussive and Feign Death on your mouse. Out of combat only.",
    onClick = function() K.Migrate(true) end,
  })
  move:SetPoint("BOTTOMLEFT", 20, 34)
  f.move = move
  local no = L.PanelButton(f, "Not now", 100, {
    tip = "Changes nothing. The red ! on the key bar stays until you choose.",
    onClick = function() K.NotNow() end,
  })
  no:SetPoint("LEFT", move, "RIGHT", 8, 0)
  f.no = no
  local off = L.PanelButton(f, "Keep mouse off", 130, {
    lock = true,
    tip = "Moves the keyboard keys only. Your mouse buttons stay as they are and Wing Clip stays on Shift-Z.",
    onClick = function() K.Migrate(false) end,
  })
  off:SetPoint("LEFT", no, "RIGHT", 8, 0)
  f.off = off
  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  EnsureFont(hint, "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 22, 14)
  hint:SetText("\"Restore my old keys\" in Options undoes all of it.")
  f:Hide()
  K.frame = f
  return f
end

function K.Paint()
  local f = K.frame
  if not f then
    return
  end
  local taken = K.TakenMouse()
  local a, b = f.takenRow[1], f.takenRow[2]
  if #taken > 0 then
    local names = {}
    for _, key in ipairs(taken) do
      names[#names + 1] = (Nock.MouseName and Nock.MouseName[key]) or KeyLabel(key)
    end
    local t = table.concat(names, ", ")
    b:SetText(t:gsub("^%l", string.upper) .. (#taken == 1 and " already does" or " already do")
      .. " something of yours, so Nock leaves " .. (#taken == 1 and "it" or "them") .. " alone.")
    a:Show()
    b:Show()
  else
    a:Hide()
    b:Hide()
  end
  if L.UpdateButtonStates then
    L.UpdateButtonStates()
  end
end

function K.ShowPopup(force)
  if not K.Pending() then
    return nil
  end
  if force then
    K.snoozed = nil
  end
  local f = Build()
  f:Show()
  K.Paint()
  if L.Sound then
    L.Sound("IG_MAINMENU_OPEN")
  end
  return f
end

function K.PrintKeys()
  Print("Nock 2.1 keys" .. (K.Pending() and " (not moved yet: /nock migrate)" or "") .. ":")
  local mouse = DB().mouse ~= false
  for _, c in ipairs(CHANGES) do
    if not c.mouse or mouse then
      Print("  " .. c[1] .. ": " .. c[2])
    end
  end
  if not mouse then
    Print("  Mouse buttons: off (Options). Wing Clip is on Shift-Z.")
  end
end

-- Hooks into Setup ---------------------------------------------------------------------

local baseStatus = S.Status
function S.Status(...)
  if K.Pending() then
    return { needs = true, reason = "keys21",
      text = "Nock 2.1 moves a few keys and puts three spells on your mouse. Nothing moves until you say so." }
  end
  return baseStatus(...)
end

local baseShow = S.Show
function S.Show(force, ...)
  if K.Pending() then
    if K.snoozed and not force then
      return nil
    end
    return K.ShowPopup(force)
  end
  return baseShow(force, ...)
end

-- No quiet moves while the popup's question is open; after it, every key that
-- keep-up adds joins the Restore Keys snapshot first.
local baseKeepUp = S.KeepUp
function S.KeepUp(...)
  if K.Pending() then
    S.keepQueued = nil
    return 0
  end
  if not InCombat() and DB().applied then
    K.ExtendSnapshot(LayoutNow())
  end
  return baseKeepUp(...)
end

local baseRestore = Nock.RestoreKeys
if baseRestore then
  function Nock.RestoreKeys(...)
    local r = baseRestore(...)
    if r and not DB().applied then
      DB().km = nil
      if K.frame then
        K.frame:Hide()
      end
    end
    return r
  end
end

-- Slash -----------------------------------------------------------------------------------

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg, ...)
    local cmd, rest = tostring(msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "keys" then
      return K.PrintKeys()
    elseif cmd == "migrate" then
      if not K.Pending() then
        return Print("Your keys are already on the 2.1 layout.")
      end
      if rest == "nomouse" then
        return K.Migrate(false)
      elseif rest == "now" then
        return K.Migrate(true)
      end
      return K.ShowPopup(true)
    elseif cmd == "mouse" then
      local on
      if rest == "on" then
        on = true
      elseif rest == "off" then
        on = false
      else
        on = DB().mouse == false
      end
      return K.SetMouse(on)
    end
    return baseSlash(msg, ...)
  end
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
  if K.queued then
    local q = K.queued
    K.queued = nil
    K.Migrate(q.mouse)
  end
end)
end
