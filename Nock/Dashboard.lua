--[[
  Nock 3.7.0: Dashboard.

  One compact panel with what you glance at between pulls:
    Bags     free general bag slots / total (quiver and ammo pouch not counted)
    Ammo     arrows or bullets left, and about how many minutes of Auto Shot
             that is at your current ranged speed
    Quests   your tracked quests with objective progress (the top of your
             quest log when nothing is tracked)

  Built to sit in a corner of the screen and be mirrored to a second
  monitor (OBS "Windowed Projector"), so it has an optional solid
  background and stays the same size and shape while it updates.

  /nock dash                 show or hide
  /nock dash unlock | lock   drag it (also /nock unlock moves every frame)
  /nock dash reset           back to the default spot
  /nock dash small | normal | large   size (Large is the default)
  /nock dash solid           solid or see-through background
  Options > On screen has the same switches. Settings live in
  NockCharDB.dash; the position in NockCharDB.positions.dash.

  WoW Forever API only (1.60.1, interface 16001): C_Container,
  C_QuestLog (GetNumQuestWatches, GetQuestIDForQuestWatchIndex,
  GetQuestObjectives, GetInfo), UnitRangedDamage. GetQuestLogTitle and
  friends do not exist on Forever.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local D = {}
Nock.Dash = D

-- Layout (Large = scale 1). One type system: 11 caps labels, 17 values,
-- 13 quest titles, 12 objectives. Every row has a fixed height so the panel
-- never shifts or overlaps when text changes.
local W = 300
local PAD = 12
local HEAD_H = 28
local STAT_H = 44
local GAP = 8
local QHEAD_H = 22
local QTITLE_H = 18
local QOBJ_H = 16
local QGAP = 6
local BAR_H = 4
local INNER_W = W - PAD * 2 - 4
local VALUE_W = 120
local MAX_QUESTS = 5
local MAX_OBJ = 4
local MAX_LINES = 16
local LOW_BAGS = 4
local LOW_AMMO_MIN = 5 -- minutes of Auto Shot
local SCALES = { small = 0.8, normal = 0.9, large = 1.0 }
local DEFAULT = { "TOPRIGHT", "TOPRIGHT", -24, -250 }

local GOOD = { 0.40, 0.92, 0.62 }
local WARN = { 1.00, 0.78, 0.30 }
local BAD = { 1.00, 0.42, 0.36 }

local frame
local dirty = true
local pending = false
local inCombat = false

-- Settings -------------------------------------------------------------------

local function DB()
  _G.NockCharDB = _G.NockCharDB or {}
  local db = _G.NockCharDB
  if type(db.dash) ~= "table" then
    db.dash = {}
  end
  return db.dash
end

function D.IsShown()
  return DB().show == true
end

function D.Size()
  local s = DB().size
  return SCALES[s] and s or "large"
end

function D.IsSolid()
  return DB().solid == true
end

function D.IsUnlocked()
  return DB().unlocked == true
end

local function Say(msg)
  if Core.Say then
    Core.Say(msg)
  end
end

-- Theme: the same palette as the 3.5 alert cards, so the panel matches the
-- reminders and the options window in both styles.
local function Theme()
  local A = Nock.Alerts
  local th = A and A.Theme and Core.Call(A.Theme, A)
  if type(th) == "table" then
    return th
  end
  return {
    bgTop = { 0.075, 0.085, 0.075, 0.94 },
    bgBottom = { 0.035, 0.042, 0.038, 0.94 },
    trim = { 0.74, 0.68, 0.50, 0.85 },
    inner = { 0, 0, 0, 0.65 },
    title = { 0.96, 0.95, 0.90 },
    sub = { 0.70, 0.76, 0.72 },
    accent = { info = { 0.30, 0.85, 0.58 } },
  }
end

-- Readers (pure-ish, tested) ---------------------------------------------------

local QUIVER, POUCH = 1, 2

local function IsAmmoBag(family)
  family = tonumber(family) or 0
  if bit and bit.band then
    return bit.band(family, QUIVER + POUCH) ~= 0
  end
  return family == QUIVER or family == POUCH or family == 3
end
D.IsAmmoBag = IsAmmoBag

-- free, total over the backpack and bags 1-4, skipping quivers and pouches.
function D.ReadBags()
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerNumFreeSlots) then
    return nil
  end
  local free, total = 0, 0
  local bags = _G.NUM_BAG_SLOTS or 4
  for bag = 0, bags do
    local slots = Core.Number(Core.Call(C.GetContainerNumSlots, bag)) or 0
    if slots > 0 then
      local nFree, family = Core.Call(C.GetContainerNumFreeSlots, bag)
      if not IsAmmoBag(Core.Number(family)) then
        total = total + slots
        free = free + (Core.Number(nFree) or 0)
      end
    end
  end
  return free, total
end

-- Seconds between Auto Shots, or nil.
function D.RangedSpeed()
  if not UnitRangedDamage then
    return nil
  end
  local speed = Core.Number(Core.Call(UnitRangedDamage, "player"))
  if speed and speed > 0.1 then
    return speed
  end
  return nil
end

-- Whole minutes of Auto Shot left (pure).
function D.MinutesLeft(count, speed)
  count, speed = tonumber(count) or 0, tonumber(speed)
  if not speed or speed <= 0 or count <= 0 then
    return count <= 0 and 0 or nil
  end
  return math.floor(count * speed / 60)
end

function D.ReadAmmo()
  local Q = Nock.Quiver
  local st = Q and Q.State and Core.Call(Q.State)
  local count, id, name = 0, nil, nil
  if type(st) == "table" then
    count, id, name = tonumber(st.count) or 0, st.id, st.name
  end
  local kind = "Ammo"
  if id and Core.ItemInfo then
    local _, _, _, _, _, subType = Core.ItemInfo(id)
    if subType == "Arrow" then
      kind = "Arrows"
    elseif subType == "Bullet" then
      kind = "Bullets"
    end
  end
  if kind == "Ammo" and type(name) == "string" then
    if name:find("Arrow", 1, true) then
      kind = "Arrows"
    elseif name:find("Shot", 1, true) or name:find("Bullet", 1, true) or name:find("Slug", 1, true) then
      kind = "Bullets"
    end
  end
  local speed = D.RangedSpeed()
  return { count = id and count or 0, id = id, name = name, kind = kind, speed = speed,
    minutes = id and D.MinutesLeft(count, speed) or 0 }
end

local function Str(v)
  if type(v) ~= "string" or Core.IsSecret(v) then
    return nil
  end
  return v
end

-- Objective line: "Kobold Candle 4/8". Uses the game's text, tidied.
function D.ObjectiveText(o)
  local text = Str(o.text) or ""
  local have, need = Core.Number(o.numFulfilled), Core.Number(o.numRequired)
  -- "Kobold Candle: 4/8" or "4/8 Kobold Candle" -> "Kobold Candle 4/8".
  local name, a, b = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
  if not name then
    a, b, name = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.+)$")
  end
  if name and a then
    return string.format("%s %s/%s", name, a, b)
  end
  if text ~= "" then
    return text
  end
  if have and need and need > 0 then
    return string.format("%d/%d", have, need)
  end
  return "Objective"
end

local function QuestEntry(questID)
  local QL = C_QuestLog
  local title = Str(QL.GetTitleForQuestID and Core.Call(QL.GetTitleForQuestID, questID))
  if not title and QL.GetLogIndexForQuestID and QL.GetInfo then
    local idx = Core.Call(QL.GetLogIndexForQuestID, questID)
    local info = idx and Core.Call(QL.GetInfo, idx)
    title = type(info) == "table" and Str(info.title) or nil
  end
  local objectives = {}
  local list = QL.GetQuestObjectives and Core.Call(QL.GetQuestObjectives, questID)
  if type(list) == "table" then
    for _, o in ipairs(list) do
      if type(o) == "table" then
        objectives[#objectives + 1] = { text = D.ObjectiveText(o), done = Core.Flag(o.finished) == true }
      end
    end
  end
  local complete = (QL.IsComplete and Core.Flag(Core.Call(QL.IsComplete, questID)) == true)
    or (QL.ReadyForTurnIn and Core.Flag(Core.Call(QL.ReadyForTurnIn, questID)) == true)
  local failed = QL.IsFailed and Core.Flag(Core.Call(QL.IsFailed, questID)) == true
  if not complete and #objectives > 0 then
    complete = true
    for _, o in ipairs(objectives) do
      if not o.done then
        complete = false
        break
      end
    end
  end
  return { id = questID, title = title or ("Quest " .. tostring(questID)), objectives = objectives,
    complete = complete and true or false, failed = failed and true or false }
end

-- { quests = { ... }, source = "tracked" | "log", more = n }
function D.ReadQuests()
  local QL = C_QuestLog
  local out = { quests = {}, source = "tracked", more = 0 }
  if not QL then
    return out
  end
  local ids, seen = {}, {}
  local nWatch = QL.GetNumQuestWatches and Core.Number(Core.Call(QL.GetNumQuestWatches)) or 0
  for w = 1, nWatch do
    local id = Core.Number(QL.GetQuestIDForQuestWatchIndex and Core.Call(QL.GetQuestIDForQuestWatchIndex, w))
    if id and id > 0 and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  if #ids == 0 then
    out.source = "log"
    local n = QL.GetNumQuestLogEntries and Core.Number(Core.Call(QL.GetNumQuestLogEntries)) or 0
    for i = 1, n do
      local info = QL.GetInfo and Core.Call(QL.GetInfo, i)
      if type(info) == "table" and not Core.Flag(info.isHeader) and not Core.Flag(info.isHidden) then
        local id = Core.Number(info.questID)
        if id and id > 0 and not seen[id] then
          seen[id] = true
          ids[#ids + 1] = id
        end
      end
    end
  end
  for i, id in ipairs(ids) do
    if i > MAX_QUESTS then
      out.more = #ids - MAX_QUESTS
      break
    end
    out.quests[#out.quests + 1] = QuestEntry(id)
  end
  return out
end

-- Fit quests into the line budget (pure, tested). Returns rows:
-- { kind = "title" | "obj" | "more", text, done, failed }.
function D.QuestRows(q, maxLines)
  maxLines = maxLines or MAX_LINES
  local rows = {}
  local hidden = q.more or 0
  for qi, quest in ipairs(q.quests or {}) do
    -- A quest needs its title plus at least one line (objective or "Done").
    local objs = quest.objectives or {}
    local want = 1 + ((quest.complete or #objs == 0) and 0 or math.min(#objs, MAX_OBJ))
    if #rows + want > maxLines then
      hidden = hidden + (#q.quests - qi + 1)
      break
    end
    rows[#rows + 1] = { kind = "title", text = quest.title, done = quest.complete, failed = quest.failed, first = qi == 1 }
    if not quest.complete then
      for oi, o in ipairs(objs) do
        if oi > MAX_OBJ then
          break
        end
        rows[#rows + 1] = { kind = "obj", text = o.text, done = o.done }
      end
    end
  end
  if hidden > 0 then
    rows[#rows + 1] = { kind = "more", text = string.format("+%d more in your quest log", hidden) }
  end
  return rows
end

-- Frame --------------------------------------------------------------------------

local function Font(fs, size)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(fs, size, "")
  elseif fs.SetFont then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "")
  end
  if fs.SetShadowOffset then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
  end
  if fs.SetWordWrap then
    fs:SetWordWrap(false)
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

local function Text(parent, size, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  Font(fs, size)
  fs:SetJustifyH(justify or "LEFT")
  if fs.SetJustifyV then
    fs:SetJustifyV("MIDDLE")
  end
  return fs
end

-- A stat block: caps label over a big value, a right-aligned note and a thin
-- square-ended meter underneath.
local function Stat(f, y, label)
  local s = {}
  s.label = Text(f, 11)
  s.label:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
  s.label:SetText(label)
  s.value = Text(f, 17)
  s.value:SetPoint("TOPLEFT", s.label, "BOTTOMLEFT", 0, -4)
  s.value:SetWidth(VALUE_W)
  -- The note shares the value's baseline, right-aligned; the two columns
  -- never meet (VALUE_W + 8 + note width = inner width).
  s.note = Text(f, 12, "RIGHT")
  s.note:SetPoint("BOTTOMRIGHT", s.value, "BOTTOMLEFT", INNER_W, 1)
  s.note:SetWidth(INNER_W - VALUE_W - 8)
  s.track = Solid(f, "ARTWORK")
  s.track:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y - STAT_H + BAR_H + 2)
  s.track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y - STAT_H + BAR_H + 2)
  s.track:SetHeight(BAR_H)
  s.fill = Solid(f, "ARTWORK", 1)
  s.fill:SetPoint("TOPLEFT", s.track, "TOPLEFT")
  s.fill:SetHeight(BAR_H)
  s.fill:SetWidth(1)
  return s
end

local function Divider(f)
  local t = Solid(f, "ARTWORK")
  t:SetHeight(1)
  return t
end

local function Create()
  if frame then
    return frame
  end
  local f = CreateFrame("Frame", "NockDashFrame", UIParent)
  f:SetSize(W, 200)
  if f.SetClampedToScreen then
    f:SetClampedToScreen(true)
  end
  f.bg = Solid(f, "BACKGROUND")
  f.bg:SetPoint("TOPLEFT", 1, -1)
  f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
  f.edges = {}
  for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local e = Solid(f, "BORDER")
    e:SetPoint(spec[1])
    e:SetPoint(spec[2])
    if spec[3] then e:SetHeight(1) else e:SetWidth(1) end
    f.edges[i] = e
  end
  f.inner = Solid(f, "BORDER", 1)
  f.inner:SetPoint("TOPLEFT", 1, -1)
  f.inner:SetPoint("TOPRIGHT", -1, -1)
  f.inner:SetHeight(1)
  f.accent = Solid(f, "ARTWORK")
  f.accent:SetPoint("TOPLEFT", 1, -1)
  f.accent:SetPoint("BOTTOMLEFT", 1, 1)
  f.accent:SetWidth(3)

  -- Header
  f.title = Text(f, 13)
  f.title:SetPoint("LEFT", f, "TOPLEFT", PAD + 4, -HEAD_H / 2)
  f.title:SetText("NOCK DASHBOARD")
  f.headLine = Divider(f)
  f.headLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -HEAD_H)
  f.headLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -HEAD_H)

  local y = -HEAD_H - GAP
  f.bags = Stat(f, y, "BAGS")
  y = y - STAT_H - GAP
  f.ammo = Stat(f, y, "AMMO")
  y = y - STAT_H - GAP
  f.qLine = Divider(f)
  f.qLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
  f.qLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
  y = y - GAP
  f.qLabel = Text(f, 11)
  f.qLabel:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, y)
  f.qLabel:SetText("QUESTS")
  f.qNote = Text(f, 11, "RIGHT")
  f.qNote:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
  f.qNote:SetWidth(W / 2)
  f.questTop = y - QHEAD_H + 4
  f.rows = {}

  if Core.MakeMovable then
    Core.MakeMovable(f, "dash", "Nock dashboard", DEFAULT, {
      strata = "MEDIUM", level = 20,
      free = function() return D.IsUnlocked() end,
      preview = function() D.ApplyMouse() end,
    })
  else
    f:SetPoint(DEFAULT[1], UIParent, DEFAULT[2], DEFAULT[3], DEFAULT[4])
  end
  frame = f
  D.frame = f
  D.ApplyMouse()
  return f
end

local function Row(i)
  local r = frame.rows[i]
  if r then
    return r
  end
  r = Text(frame, 13)
  r:SetWidth(W - PAD * 2 - 4)
  frame.rows[i] = r
  return r
end

-- Locked: clicks go through to the world. Unlocked: it can be dragged.
function D.ApplyMouse()
  if not frame or not frame.EnableMouse then
    return
  end
  local on = D.IsUnlocked() or (Core.Unlocked and Core.Unlocked())
  frame:EnableMouse(on and true or false)
  if Core.ShowMoverOutline then
    Core.ShowMoverOutline("dash", on)
  end
end

local function Color(fs, c, a)
  fs:SetTextColor(c[1], c[2], c[3], a or 1)
end

local function Meter(s, pct, c)
  pct = math.max(0, math.min(1, pct or 0))
  local w = (W - PAD * 2 - 4) * pct
  if w < 1 then
    s.fill:Hide()
  else
    s.fill:SetWidth(w)
    s.fill:SetColorTexture(c[1], c[2], c[3], 0.95)
    s.fill:Show()
  end
end

local function PaintFrame(th)
  local a = D.IsSolid() and 1 or nil
  local top, bot = th.bgTop, th.bgBottom
  if frame.bg.SetGradient and CreateColor then
    frame.bg:SetColorTexture(1, 1, 1, 1)
    local ok = pcall(frame.bg.SetGradient, frame.bg, "VERTICAL",
      CreateColor(bot[1], bot[2], bot[3], a or bot[4] or 0.94),
      CreateColor(top[1], top[2], top[3], a or top[4] or 0.94))
    if not ok then
      frame.bg:SetColorTexture(top[1], top[2], top[3], a or top[4] or 0.94)
    end
  else
    frame.bg:SetColorTexture(top[1], top[2], top[3], a or top[4] or 0.94)
  end
  for _, e in ipairs(frame.edges) do
    e:SetColorTexture(th.trim[1], th.trim[2], th.trim[3], th.trim[4] or 1)
  end
  local inner = th.inner or { 0, 0, 0, 0.65 }
  frame.inner:SetColorTexture(inner[1], inner[2], inner[3], inner[4] or 1)
  local acc = (th.accent and th.accent.info) or GOOD
  frame.accent:SetColorTexture(acc[1], acc[2], acc[3], 1)
  local line = { th.trim[1], th.trim[2], th.trim[3], 0.35 }
  frame.headLine:SetColorTexture(line[1], line[2], line[3], line[4])
  frame.qLine:SetColorTexture(line[1], line[2], line[3], line[4])
  for _, s in ipairs({ frame.bags, frame.ammo }) do
    s.track:SetColorTexture(0, 0, 0, 0.55)
    Color(s.label, th.sub)
    Color(s.note, th.sub)
  end
  Color(frame.title, th.trim)
  Color(frame.qLabel, th.sub)
  Color(frame.qNote, th.sub)
end

local function Paint()
  local th = Theme()
  PaintFrame(th)
  local title = th.title or { 0.96, 0.95, 0.90 }

  -- Bags
  local free, total = D.ReadBags()
  local b = frame.bags
  if free and total and total > 0 then
    local c = free <= 0 and BAD or (free <= LOW_BAGS and WARN or title)
    b.value:SetText(string.format("%d free", free))
    Color(b.value, c)
    b.note:SetText(string.format("%d / %d used", total - free, total))
    Meter(b, (total - free) / total, free <= LOW_BAGS and c or (th.accent and th.accent.info or GOOD))
  else
    b.value:SetText("--")
    Color(b.value, title)
    b.note:SetText("")
    Meter(b, 0, GOOD)
  end

  -- Ammo
  local am = D.ReadAmmo()
  local s = frame.ammo
  s.label:SetText(string.upper(am.kind or "Ammo"))
  if am.id then
    local low
    if am.minutes then
      low = am.minutes < LOW_AMMO_MIN
    else
      low = am.count < 200
    end
    local empty = am.count <= 0
    local c = empty and BAD or (low and WARN or title)
    s.value:SetText(Core.Short and am.count >= 10000 and Core.Short(am.count) or tostring(am.count))
    Color(s.value, c)
    if am.minutes then
      s.note:SetText(am.minutes >= 1 and string.format("about %d min", am.minutes) or "under 1 min")
    else
      s.note:SetText("")
    end
    local Q = Nock.Quiver
    local st = Q and Q.State and Core.Call(Q.State)
    local full = type(st) == "table" and tonumber(st.full) or 1000
    Meter(s, am.count / math.max(1, full), (empty or low) and c or (th.accent and th.accent.info or GOOD))
  else
    s.value:SetText("None loaded")
    Color(s.value, BAD)
    s.note:SetText("load ammo")
    Meter(s, 0, BAD)
  end

  -- Quests
  local q = D.ReadQuests()
  local rows = D.QuestRows(q, MAX_LINES)
  frame.qNote:SetText(q.source == "tracked" and (#q.quests > 0 and "tracked" or "") or (#q.quests > 0 and "from quest log" or ""))
  local y = frame.questTop
  local n = 0
  if #rows == 0 then
    n = 1
    local r = Row(1)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, y - 2)
    Font(r, 12)
    r:SetText("No quests in your log")
    Color(r, th.sub)
    r:Show()
    y = y - QOBJ_H - 2
  end
  for i, row in ipairs(rows) do
    n = i
    local r = Row(i)
    r:ClearAllPoints()
    if row.kind == "title" then
      if not row.first then
        y = y - QGAP
      end
      Font(r, 13)
      r:SetWidth(W - PAD * 2 - 4)
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, y)
      if row.failed then
        r:SetText(row.text .. "  |cffff6b5c(failed)|r")
        Color(r, title)
      elseif row.done then
        r:SetText(row.text .. "  (done)")
        Color(r, GOOD)
      else
        r:SetText(row.text)
        Color(r, title)
      end
      y = y - QTITLE_H
    elseif row.kind == "obj" then
      Font(r, 12)
      r:SetWidth(W - PAD * 2 - 16)
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 16, y)
      r:SetText(row.text)
      if row.done then
        Color(r, GOOD, 0.85)
      else
        Color(r, th.sub)
      end
      y = y - QOBJ_H
    else
      y = y - 2
      Font(r, 12)
      r:SetWidth(W - PAD * 2 - 4)
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, y)
      r:SetText(row.text)
      Color(r, th.sub, 0.8)
      y = y - QOBJ_H
    end
    r:Show()
  end
  for i = n + 1, #frame.rows do
    frame.rows[i]:Hide()
  end
  frame:SetHeight(math.floor(-y + PAD))
end

function D.Update()
  local hunter = (not Nock.IsHunter) or Nock.IsHunter()
  if not (D.IsShown() and hunter) then
    if frame then
      frame:Hide()
    end
    return
  end
  Create()
  frame:SetScale(SCALES[D.Size()] or 1)
  local ok, err = pcall(Paint)
  if not ok then
    Core.errors = Core.errors or {}
    Core.errors.dash = tostring(err)
  end
  dirty = false
  frame:Show()
end

-- Throttled: many events in a burst paint once, at most every 0.25 s.
local function Soon()
  dirty = true
  if pending then
    return
  end
  pending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0.25, function()
      pending = false
      D.Update()
    end)
  else
    pending = false
    D.Update()
  end
end
D.Soon = Soon

-- Settings API (Options window and slash) ------------------------------------------

local function RefreshUI()
  if Nock.UI and Nock.UI.Refresh then
    pcall(Nock.UI.Refresh)
  end
end

function D.SetShown(on)
  DB().show = on and true or false
  D.Update()
  RefreshUI()
end

function D.SetSize(size)
  if SCALES[size] then
    DB().size = size
    D.Update()
    RefreshUI()
  end
end

function D.SetSolid(on)
  DB().solid = on and true or false
  D.Update()
  RefreshUI()
end

function D.SetUnlocked(on)
  if on and InCombatLockdown and InCombatLockdown() then
    Say("Leave combat first.")
    return
  end
  DB().unlocked = on and true or false
  if on and not D.IsShown() then
    DB().show = true
  end
  D.Update()
  D.ApplyMouse()
  RefreshUI()
end

function D.Reset()
  _G.NockCharDB = _G.NockCharDB or {}
  if type(_G.NockCharDB.positions) == "table" then
    _G.NockCharDB.positions.dash = nil
  end
  if Core.PlaceMover then
    Core.PlaceMover("dash")
  end
  Say("Dashboard moved back to the top right, under the minimap.")
end

function D.Toggle()
  D.SetShown(not D.IsShown())
  Say("Dashboard " .. (D.IsShown() and "shown. /nock dash unlock to move it." or "hidden."))
end
_G.Nock_ToggleDash = D.Toggle

function D.Slash(rest)
  rest = rest or ""
  if rest == "" then
    return D.Toggle()
  elseif rest == "on" or rest == "show" then
    D.SetShown(true)
    return Say("Dashboard shown.")
  elseif rest == "off" or rest == "hide" then
    D.SetShown(false)
    return Say("Dashboard hidden.")
  elseif rest == "unlock" or rest == "move" then
    D.SetUnlocked(true)
    return Say("Dashboard unlocked: drag it anywhere, then /nock dash lock.")
  elseif rest == "lock" then
    D.SetUnlocked(false)
    return Say("Dashboard locked. Clicks pass through it.")
  elseif rest == "reset" then
    return D.Reset()
  elseif SCALES[rest] then
    D.SetSize(rest)
    return Say("Dashboard size: " .. rest .. ".")
  elseif rest == "solid" then
    D.SetSolid(not D.IsSolid())
    return Say("Dashboard background: " .. (D.IsSolid() and "solid." or "see-through."))
  end
  Say("/nock dash — show or hide   /nock dash unlock | lock | reset   /nock dash small | normal | large   /nock dash solid")
end

-- Events ---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
for _, e in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "BAG_UPDATE_DELAYED",
  "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_RANGEDDAMAGE",
  "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED",
  "UNIT_QUEST_LOG_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
  "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, arg1)
  if (event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_RANGEDDAMAGE" or event == "UNIT_QUEST_LOG_CHANGED")
    and arg1 ~= "player" then
    return
  end
  if event == "PLAYER_LOGIN" and D.IsUnlocked() then
    DB().unlocked = false -- locked again on every login, like /nock unlock
  end
  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    if D.IsUnlocked() then
      DB().unlocked = false
      D.ApplyMouse()
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
  end
  if not D.IsShown() and frame == nil then
    return
  end
  Soon()
end)

-- In combat ammo ticks down shot by shot; repaint once a second.
local acc = 0
ev:SetScript("OnUpdate", function(_, elapsed)
  if not inCombat or not D.IsShown() then
    return
  end
  acc = acc + (elapsed or 0)
  if acc >= 1 then
    acc = 0
    D.Update()
  end
end)

-- Restyle with the HUD style switch.
if hooksecurefunc and Nock.SetStyle then
  pcall(hooksecurefunc, Nock, "SetStyle", function()
    Soon()
  end)
end

-- /nock dash rides on the main /nock command.
local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg)
    local m = string.lower(strtrim and strtrim(msg or "") or (msg or ""))
    local cmd, rest = m:match("^(%S+)%s*(.*)$")
    if cmd == "dash" or cmd == "dashboard" then
      return D.Slash(rest)
    end
    baseSlash(msg)
    if m == "help" then
      Say("/nock dash — the dashboard (bags, ammo, tracked quests) on or off   /nock dash unlock | lock | reset | small | normal | large | solid")
    end
  end
end
