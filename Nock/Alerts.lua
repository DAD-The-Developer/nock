--[[
  Nock 3.5.0: the alert framework.

  Every Nock reminder is a registered alert. Modules never draw their own
  banners; they call

      Nock.Alerts:Fire("feign.resisted")
      Nock.Alerts:Fire("supplies.leave", { list = "ammo 120/600" })
      Nock.Alerts:Clear("aspect.daze")

  and the manager decides whether, where and how it shows:
    * one tidy stack (movable with /nock unlock), at most 1-2 toasts at once
    * priority queue: critical > warning > info; a critical replaces the
      lowest toast when the stack is full
    * de-duplication (the same alert refreshes instead of stacking) and a
      cooldown per alert so nothing spams
    * per-priority show time, smooth fade and slide
    * category and per-alert switches, quiet mode (critical only, silent),
      sounds only for critical, size scale
    * contexts (solo / party / raid / dungeon / raidinstance / pvp), level
      range, spec and a condition function, all checked before showing

  Defining an alert (Data_Alerts.lua, or any module):

      Nock.Alerts:Register({
        id = "pet.unhappy", category = "pet", priority = "warning",
        icon = "spell:Feed Pet", title = "{pet} is unhappy",
        sub = "Feed it (Feed pet key)", cooldown = 45,
        contexts = { pvp = false }, minLevel = 10, spec = nil,
        label = "Pet is unhappy",       -- shown in Options
      })

  Themes: Nock.Alerts:RegisterTheme(id, table). Missing keys fall back to
  the base theme, so a new HUD style looks right with no extra work.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local A = { defs = {}, order = {}, categories = {}, catOrder = {}, themes = {} }
Nock.Alerts = A

local RANK = { info = 1, warning = 2, critical = 3 }
A.RANK = RANK
local DURATION = { info = 6, warning = 5, critical = 4 }
local COOLDOWN = { info = 60, warning = 20, critical = 3 }
local FADE_IN, FADE_OUT, SLIDE = 0.18, 0.35, 8
local QUEUE_MAX, QUEUE_STALE = 6, 12
local SOUND_CRIT = 37666 -- SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING: short and clean
local SOUND_FALLBACK = 8959

A.CATEGORY_LABELS = {
  pet = "Pet", supplies = "Supplies", aspects = "Aspects", feign = "Feign Death", range = "Range and Wing Clip",
  train = "Trainer", tame = "Taming", pvp = "PvP", vendor = "Vendor", gold = "Gold", route = "Route", tracker = "Tracker", general = "General",
}

-- Settings ---------------------------------------------------------------------

local function S()
  _G.NockCharDB = _G.NockCharDB or {}
  local db = _G.NockCharDB
  if type(db.alerts) ~= "table" then
    db.alerts = {}
  end
  local s = db.alerts
  if type(s.off) ~= "table" then
    s.off = {}
  end
  if type(s.cats) ~= "table" then
    s.cats = {}
  end
  return s
end
A.Settings = S

function A:IsQuiet() return S().quiet == true end
function A:SoundOn() return S().sound ~= false and (_G.NockCharDB.toolsSound ~= false) end
function A:Scale() return tonumber(S().scale) or 1 end
function A:MaxVisible() return (tonumber(S().max) == 1) and 1 or 2 end
function A:CategoryOn(cat) return S().cats[cat] ~= false end
function A:AlertOn(id) return not S().off[id] end

function A:SetQuiet(on) S().quiet = on and true or nil end
function A:SetSound(on) S().sound = on and true or false end
function A:SetScale(v) S().scale = tonumber(v) or 1; A:Layout() end
function A:SetMax(n) S().max = (tonumber(n) == 1) and 1 or 2; A:Layout() end
function A:SetCategory(cat, on)
  if on then
    S().cats[cat] = nil
  else
    S().cats[cat] = false
  end
end
function A:SetAlert(id, on) S().off[id] = (not on) or nil end

-- Registry ---------------------------------------------------------------------

function A:Register(def)
  if type(def) ~= "table" or not def.id then
    return nil
  end
  def.category = def.category or "general"
  def.priority = RANK[def.priority] and def.priority or "info"
  if not self.defs[def.id] then
    self.order[#self.order + 1] = def.id
  end
  self.defs[def.id] = def
  if not self.categories[def.category] then
    self.categories[def.category] = {}
    self.catOrder[#self.catOrder + 1] = def.category
  end
  local list = self.categories[def.category]
  local found = false
  for _, id in ipairs(list) do
    if id == def.id then
      found = true
    end
  end
  if not found then
    list[#list + 1] = def.id
  end
  return def
end

function A:Get(id)
  return self.defs[id]
end

-- "{name}" -> vars.name. Unknown names become "".
function A.Format(template, vars)
  if type(template) == "function" then
    local ok, out = pcall(template, vars or {})
    return ok and out or nil
  end
  if type(template) ~= "string" then
    return nil
  end
  return (template:gsub("{(%w+)}", function(k)
    local v = vars and vars[k]
    return v ~= nil and tostring(v) or ""
  end))
end

function A.ResolveIcon(icon, vars)
  if type(icon) == "function" then
    local ok, v = pcall(icon, vars or {})
    icon = ok and v or nil
  end
  if type(icon) ~= "string" then
    return nil
  end
  local kind, rest = icon:match("^(%a+):(.+)$")
  if kind == "spell" then
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
      tex = Core.Call(C_Spell.GetSpellTexture, rest)
    end
    if not tex and Nock.PlayerKnows then
      tex = select(4, Core.Call(Nock.PlayerKnows, rest))
    end
    if tex and not Core.IsSecret(tex) then
      return tex
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
  elseif kind == "item" then
    local id = tonumber(rest)
    local tex = id and C_Item and C_Item.GetItemIconByID and Core.Call(C_Item.GetItemIconByID, id)
    return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  return icon
end

-- Is this alert allowed right now? (pure apart from settings / profile; tested)
function A:Allowed(def, vars)
  if Core.Muted and Core.Muted() then
    return false, "muted"
  end
  if not self:CategoryOn(def.category) then
    return false, "category"
  end
  if not self:AlertOn(def.id) then
    return false, "off"
  end
  if self:IsQuiet() and def.priority ~= "critical" then
    return false, "quiet"
  end
  local P = Core.P
  if type(def.contexts) == "table" then
    local v = def.contexts[P.context]
    if v == false then
      return false, "context"
    end
    if def.contexts.only and not v then
      return false, "context"
    end
  end
  if def.minLevel and P.level < def.minLevel then
    return false, "level"
  end
  if def.maxLevel and P.level > def.maxLevel then
    return false, "level"
  end
  if type(def.spec) == "table" and not def.spec[P.spec] then
    return false, "spec"
  end
  if def.condition then
    local ok, v = pcall(def.condition, vars or {})
    if not ok or not v then
      return false, "condition"
    end
  end
  return true
end

-- Themes -----------------------------------------------------------------------
-- Colours are r, g, b, a. A theme only lists what differs from base.

A.themes.base = {
  bgTop = { 0.075, 0.085, 0.075, 0.94 },
  bgBottom = { 0.035, 0.042, 0.038, 0.94 },
  trim = { 0.74, 0.68, 0.50, 0.85 }, -- thin silver-gold edge
  inner = { 0, 0, 0, 0.65 }, -- 1 px dark line inside the trim
  glow = { 0.25, 0.89, 0.60, 0.10 }, -- soft accent wash from the left
  title = { 0.96, 0.95, 0.90 },
  sub = { 0.70, 0.76, 0.72 },
  iconTrim = { 0.74, 0.68, 0.50, 0.9 },
  accent = {
    critical = { 0.90, 0.28, 0.24 },
    warning = { 0.95, 0.70, 0.24 },
    info = { 0.30, 0.85, 0.58 },
  },
  cue = { good = { 0.40, 0.92, 0.62 }, warn = { 1.00, 0.78, 0.30 }, bad = { 1.00, 0.42, 0.36 }, info = { 0.62, 0.78, 0.92 } },
  font = nil, -- nil = the style's default font
}

-- Emerald Dream: dark carved wood / leather, silver-gold trim, emerald accent.
A.themes.emerald = {
  bgTop = { 0.085, 0.100, 0.080, 0.94 },
  bgBottom = { 0.040, 0.050, 0.040, 0.94 },
  trim = { 0.76, 0.72, 0.56, 0.85 },
  glow = { 0.25, 0.89, 0.60, 0.12 },
}

-- Gunsmith: gunmetal plate, brass trim, warm accent.
A.themes.gunsmith = {
  bgTop = { 0.115, 0.120, 0.128, 0.95 },
  bgBottom = { 0.055, 0.058, 0.064, 0.95 },
  trim = { 0.82, 0.63, 0.32, 0.90 },
  iconTrim = { 0.82, 0.63, 0.32, 0.95 },
  glow = { 0.95, 0.62, 0.25, 0.10 },
  sub = { 0.74, 0.72, 0.68 },
  accent = { info = { 0.85, 0.66, 0.32 } },
}

local function Inherit(t, base)
  for k, v in pairs(base) do
    if t[k] == nil then
      t[k] = v
    elseif type(v) == "table" and type(t[k]) == "table" and k ~= "font" then
      Inherit(t[k], v)
    end
  end
  return t
end

function A:RegisterTheme(id, t)
  self.themes[id] = Inherit(t or {}, self.themes.base)
  return self.themes[id]
end
for id, t in pairs(A.themes) do
  if id ~= "base" then
    Inherit(t, A.themes.base)
  end
end

function A:Theme()
  local id = Nock.StyleId and Core.Call(Nock.StyleId) or "emerald"
  return self.themes[id] or self.themes.emerald
end

-- Toast frames -----------------------------------------------------------------

local stack, pool, visible, queue = nil, {}, {}, {}
local lastShown = {}
A.visible, A.queue = visible, queue

local W, H, H1, ICON, PAD, GAP = 340, 50, 40, 32, 9, 6

local function Font(fs, size, flags)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(fs, size, flags)
  elseif fs.SetFont then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags)
  end
  if fs.SetShadowOffset then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
  end
end

local function Solid(parent, layer, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub or 0)
  if t.SetSnapToPixelGrid then
    t:SetSnapToPixelGrid(true)
    t:SetTexelSnappingBias(0)
  end
  return t
end

local function SizeFactor()
  local s = Nock.BarSize and Core.Call(Nock.BarSize) or "large"
  local f = (s == "small" and 0.88) or (s == "normal" and 0.95) or 1.04
  return f * A:Scale()
end

local function MakeStack()
  if stack then
    return stack
  end
  local f = CreateFrame("Frame", "NockAlertStack", UIParent)
  f:SetSize(W, H * 2 + GAP)
  f:SetFrameStrata("HIGH")
  f:SetFrameLevel(30)
  if Core.MakeMovable then
    Core.MakeMovable(f, "alert", "Nock alerts", { "TOP", "TOP", 0, -150 }, {
      preview = function(on)
        if on then
          A:Test(true)
        else
          A:Clear()
        end
      end,
    })
  end
  if f.EnableMouse and not (Core.Unlocked and Core.Unlocked()) then
    f:EnableMouse(false)
  end
  stack = f
  A.stack = f
  return f
end
A.EnsureStack = MakeStack

local function NewToast()
  local parent = MakeStack()
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(W, H)
  if t.EnableMouse then
    t:EnableMouse(false)
  end
  t.bg = Solid(t, "BACKGROUND")
  t.bg:SetPoint("TOPLEFT", 1, -1)
  t.bg:SetPoint("BOTTOMRIGHT", -1, 1)
  t.glow = Solid(t, "BACKGROUND", 1)
  t.glow:SetPoint("TOPLEFT", 1, -1)
  t.glow:SetPoint("BOTTOMLEFT", 1, 1)
  t.glow:SetWidth(120)
  t.edges = {}
  for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local e = Solid(t, "BORDER")
    e:SetPoint(spec[1])
    e:SetPoint(spec[2])
    if spec[3] then e:SetHeight(1) else e:SetWidth(1) end
    t.edges[i] = e
  end
  t.innerTop = Solid(t, "BORDER", 1)
  t.innerTop:SetPoint("TOPLEFT", 1, -1)
  t.innerTop:SetPoint("TOPRIGHT", -1, -1)
  t.innerTop:SetHeight(1)
  t.accent = Solid(t, "ARTWORK")
  t.accent:SetPoint("TOPLEFT", 1, -1)
  t.accent:SetPoint("BOTTOMLEFT", 1, 1)
  t.accent:SetWidth(3)
  t.iconTrim = Solid(t, "ARTWORK", 1)
  t.iconTrim:SetSize(ICON + 2, ICON + 2)
  t.iconTrim:SetPoint("LEFT", PAD + 2, 0)
  t.icon = t:CreateTexture(nil, "ARTWORK", nil, 2)
  t.icon:SetSize(ICON, ICON)
  t.icon:SetPoint("CENTER", t.iconTrim, "CENTER")
  t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t.title = t:CreateFontString(nil, "OVERLAY")
  Font(t.title, 15, "")
  t.title:SetJustifyH("LEFT")
  if t.title.SetWordWrap then t.title:SetWordWrap(false) end
  t.sub = t:CreateFontString(nil, "OVERLAY")
  Font(t.sub, 12, "")
  t.sub:SetJustifyH("LEFT")
  if t.sub.SetWordWrap then t.sub:SetWordWrap(false) end
  t:Hide()
  return t
end

local function Paint(t, item)
  local th = A:Theme()
  local function c(tex, col)
    tex:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
  end
  if t.bg.SetGradient and CreateColor then
    t.bg:SetColorTexture(1, 1, 1, 1)
    local ok = pcall(t.bg.SetGradient, t.bg, "VERTICAL",
      CreateColor(th.bgBottom[1], th.bgBottom[2], th.bgBottom[3], th.bgBottom[4]),
      CreateColor(th.bgTop[1], th.bgTop[2], th.bgTop[3], th.bgTop[4]))
    if not ok then
      c(t.bg, th.bgTop)
    end
  else
    c(t.bg, th.bgTop)
  end
  local acc = th.accent[item.def.priority] or th.accent.info
  if t.glow.SetGradient and CreateColor then
    t.glow:SetColorTexture(1, 1, 1, 1)
    pcall(t.glow.SetGradient, t.glow, "HORIZONTAL", CreateColor(acc[1], acc[2], acc[3], th.glow[4] or 0.1), CreateColor(acc[1], acc[2], acc[3], 0))
  else
    t.glow:SetColorTexture(acc[1], acc[2], acc[3], (th.glow[4] or 0.1) * 0.5)
  end
  for _, e in ipairs(t.edges) do
    c(e, th.trim)
  end
  c(t.innerTop, th.inner)
  c(t.accent, { acc[1], acc[2], acc[3], 1 })
  c(t.iconTrim, th.iconTrim)
  t.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  t.title:SetText(item.title or "")
  t.title:SetTextColor(th.title[1], th.title[2], th.title[3])
  t.sub:SetText(item.sub or "")
  t.sub:SetTextColor(th.sub[1], th.sub[2], th.sub[3])
  local hasSub = item.sub and item.sub ~= ""
  local x = PAD + 2 + ICON + 2 + 10
  t.title:ClearAllPoints()
  t.sub:ClearAllPoints()
  t.title:SetWidth(W - x - PAD - 4)
  t.sub:SetWidth(W - x - PAD - 4)
  if hasSub then
    t.title:SetPoint("TOPLEFT", x, -9)
    t.sub:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -3)
    t.sub:Show()
  else
    t.title:SetPoint("LEFT", x, 0)
    t.sub:Hide()
  end
  t:SetHeight(hasSub and H or H1)
end

-- Layout and animation --------------------------------------------------------------

function A:Layout()
  local f = MakeStack()
  f:SetScale(SizeFactor())
  local y = 0
  for _, t in ipairs(visible) do
    t:ClearAllPoints()
    t.baseY = -y
    t:SetPoint("TOP", f, "TOP", 0, t.baseY + (t.slide or 0))
    y = y + (t:GetHeight() or H) + GAP
  end
end

local driver = CreateFrame("Frame")
local function Release(t)
  t:Hide()
  t.item = nil
  pool[#pool + 1] = t
end

local function Pump()
  local now = Core.Now()
  -- drop stale low-priority queue entries
  for i = #queue, 1, -1 do
    if now - queue[i].at > QUEUE_STALE and queue[i].rank < RANK.critical then
      table.remove(queue, i)
    end
  end
  while #visible < A:MaxVisible() and #queue > 0 do
    table.sort(queue, function(a, b)
      if a.rank ~= b.rank then return a.rank > b.rank end
      return a.at < b.at
    end)
    A:_Show(table.remove(queue, 1))
  end
end

local function OnUpdate()
  local now = Core.Now()
  local changed = false
  for i = #visible, 1, -1 do
    local t = visible[i]
    local age = now - t.start
    local left = t.untilT - now
    if left <= 0 then
      table.remove(visible, i)
      Release(t)
      changed = true
    else
      local a = 1
      if age < FADE_IN then
        a = age / FADE_IN
        t.slide = SLIDE * (1 - a)
      else
        t.slide = 0
      end
      if left < FADE_OUT then
        a = math.min(a, left / FADE_OUT)
      end
      t:SetAlpha(a)
      t:SetPoint("TOP", stack, "TOP", 0, (t.baseY or 0) + (t.slide or 0))
    end
  end
  if changed then
    Pump()
    A:Layout()
  end
  if #visible == 0 and #queue == 0 then
    driver:SetScript("OnUpdate", nil) -- idle: no per-frame work at all
  end
end
A._OnUpdate = OnUpdate

local function Wake()
  driver:SetScript("OnUpdate", OnUpdate)
end

function A:_Show(item)
  local t = table.remove(pool) or NewToast()
  t.item = item
  Paint(t, item)
  t.start = Core.Now()
  t.untilT = t.start + item.duration
  t.slide = SLIDE
  t:SetAlpha(0)
  t:Show()
  -- Highest priority on top.
  local pos = #visible + 1
  for i, v in ipairs(visible) do
    if item.rank > v.item.rank then
      pos = i
      break
    end
  end
  table.insert(visible, pos, t)
  self:Layout()
  Wake()
  Core.lastAlert = item.title
  Core.lastAlertSub = item.sub
  Core.lastAlertId = item.def.id
  if item.def.priority == "critical" and item.sound ~= false and self:SoundOn() and not self:IsQuiet() and PlaySound then
    local ok = pcall(PlaySound, SOUND_CRIT, "Master")
    if not ok then
      pcall(PlaySound, SOUND_FALLBACK, "Master")
    end
  end
end

-- Public API ---------------------------------------------------------------------

--[[ Fire(id, vars, opts)  vars fill {templates}; opts: key (dedupe key, e.g.
  per target), force (ignore cooldown), duration, title/sub/icon overrides.
  Returns true when shown, refreshed or queued. ]]
function A:Fire(id, vars, opts)
  local def = self.defs[id]
  if not def then
    return false
  end
  opts = opts or {}
  vars = vars or {}
  local ok = self:Allowed(def, vars)
  if not ok and not opts.test then
    return false
  end
  local key = opts.key or id
  local item = {
    def = def, key = key, rank = RANK[def.priority], at = Core.Now(),
    title = opts.title or A.Format(def.title, vars) or id,
    sub = opts.sub or A.Format(def.sub, vars),
    icon = A.ResolveIcon(opts.icon or def.icon, vars),
    duration = opts.duration or def.duration or DURATION[def.priority],
    sound = def.sound,
  }
  -- Already on screen: refresh text and timer, no new toast.
  for _, t in ipairs(visible) do
    if t.item and t.item.key == key then
      t.item = item
      Paint(t, item)
      t.untilT = Core.Now() + item.duration
      self:Layout()
      Core.lastAlert = item.title
      Core.lastAlertSub = item.sub
      return true
    end
  end
  local cd = def.cooldown or COOLDOWN[def.priority]
  if not opts.force and lastShown[key] and Core.Now() - lastShown[key] < cd then
    return false
  end
  lastShown[key] = Core.Now()
  Core.lastFired = item.title .. ((item.sub and item.sub ~= "") and (" | " .. item.sub) or "")
  for i, q in ipairs(queue) do
    if q.key == key then
      queue[i] = item
      return true
    end
  end
  if #visible < self:MaxVisible() then
    self:_Show(item)
    return true
  end
  -- Full: a higher priority bumps the lowest visible toast.
  local low, lowI
  for i, t in ipairs(visible) do
    if not low or t.item.rank < low.item.rank then
      low, lowI = t, i
    end
  end
  if low and item.rank > low.item.rank then
    table.remove(visible, lowI)
    Release(low)
    self:_Show(item)
    return true
  end
  if #queue < QUEUE_MAX then
    queue[#queue + 1] = item
    Wake()
    return true
  end
  return false
end

-- Clear(idOrKey): remove matching toasts and queued items; nil clears all.
function A:Clear(id)
  for i = #visible, 1, -1 do
    local t = visible[i]
    if not id or (t.item and (t.item.key == id or t.item.def.id == id)) then
      table.remove(visible, i)
      Release(t)
    end
  end
  for i = #queue, 1, -1 do
    if not id or queue[i].key == id or queue[i].def.id == id then
      table.remove(queue, i)
    end
  end
  if stack then
    self:Layout()
  end
end

function A:ResetCooldowns()
  for k in pairs(lastShown) do
    lastShown[k] = nil
  end
end

-- Old-style Core.Alert(text, opts) calls: an ad-hoc alert in "general".
local LEGACY_PRIO = { [3] = "critical", [2] = "warning", [1] = "info" }
local COLOR_PRIO = { bad = "critical", warn = "warning", good = "info", info = "info" }
function A:FireAdhoc(text, opts)
  local prio = LEGACY_PRIO[opts.priority] or COLOR_PRIO[opts.color] or "warning"
  local id = "adhoc." .. tostring(opts.key or text)
  if not self.defs[id] then
    self.defs[id] = { id = id, category = opts.category or "general", priority = prio, cooldown = 0, hidden = true }
  end
  self.defs[id].priority = prio
  return self:Fire(id, nil, { title = text, sub = opts.sub, icon = opts.icon, duration = opts.duration, force = true })
end

-- Preview: one of each priority.
function A:Test(keep)
  self:Clear()
  self:ResetCooldowns()
  local dur = keep and 1e9 or nil
  self:Fire("feign.resisted", nil, { test = true, force = true, duration = dur })
  self:Fire("supplies.leave", { list = "ammo 120 / 600" }, { test = true, force = true, duration = dur })
  self:Fire("train.levelup", { list = "Serpent Sting 4, Aspect of the Hawk 3" }, { test = true, force = true, duration = dur and dur or 9 })
end

function _G.Nock_TestAlerts()
  A:Test()
end

-- /nock alerts ---------------------------------------------------------------------

local function Say(msg)
  Core.Say(msg)
end

function A:Slash(rest)
  rest = rest or ""
  local word, more = rest:match("^(%S*)%s*(.*)$")
  if word == "test" then
    return self:Test()
  elseif word == "quiet" then
    self:SetQuiet(not self:IsQuiet())
    return Say("Alerts: " .. (self:IsQuiet() and "quiet (critical only, no sound)" or "normal"))
  elseif word == "sound" then
    self:SetSound(not self:SoundOn())
    return Say("Alert sound (critical only): " .. (self:SoundOn() and "on" or "off"))
  elseif word == "size" or word == "scale" then
    local v = tonumber(more)
    if v and v >= 0.6 and v <= 1.6 then
      self:SetScale(v)
      self:Test()
    end
    return Say(string.format("Alert size: %.2f  (/nock alerts size 0.8 – 1.4)", self:Scale()))
  elseif word == "max" then
    self:SetMax(tonumber(more) or 2)
    return Say("Alerts on screen at once: " .. self:MaxVisible())
  elseif word == "list" then
    for _, cat in ipairs(self.catOrder) do
      local names = {}
      for _, id in ipairs(self.categories[cat]) do
        local d = self.defs[id]
        if not d.hidden then
          names[#names + 1] = id .. (self:AlertOn(id) and "" or " (off)")
        end
      end
      if #names > 0 then
        Say((self.CATEGORY_LABELS[cat] or cat) .. (self:CategoryOn(cat) and "" or " (off)") .. ": " .. table.concat(names, ", "))
      end
    end
    return
  elseif self.categories[word] and (more == "on" or more == "off") then
    self:SetCategory(word, more == "on")
    return Say((self.CATEGORY_LABELS[word] or word) .. " alerts " .. more)
  elseif self.defs[word] and (more == "on" or more == "off") then
    self:SetAlert(word, more == "on")
    return Say(word .. " " .. more)
  end
  Say("/nock alerts test | quiet | sound | size <0.8-1.4> | max 1|2 | list | <category> on|off | <alert id> on|off")
end

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg)
    local m = string.lower(strtrim and strtrim(msg or "") or (msg or ""))
    local cmd, rest = m:match("^(%S+)%s*(.*)$")
    if cmd == "alerts" or cmd == "alert" then
      return A:Slash(rest)
    end
    baseSlash(msg)
    if m == "help" then
      Say("/nock alerts — test | quiet | sound | size | list | <category> on|off")
    end
  end
end

Core.On("PLAYER_LOGIN", "core", function()
  pcall(MakeStack)
end)
