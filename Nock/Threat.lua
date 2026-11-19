--[[
  Nock threat meter — you and your pet vs the current target.

  Display only. Forever 1.60.1 (Interface 16001) ships the native APIs
  UnitDetailedThreatSituation, UnitThreatSituation, UNIT_THREAT_LIST_UPDATE
  and UNIT_THREAT_SITUATION_UPDATE, so Nock does not bundle a threat library.

  The second argument in Forever's usage string is named mobGUID; we try the
  unit token first (standard WoW) and fall back to UnitGUID(mob). Threat
  values can be secret (C_Secrets.ShouldUnitThreatValuesBeSecret); we never
  format a secret number.

  Hidden out of combat. Default on; one /nock toggle. No setup, no extra keys.

  3.0.13: carved-wood frame with silver-gold trim and corner filigree. A
  consistent padding grid; names left, percent and status right, all
  vertically centered; equal-height bars; width matches the bow plaque.
  3.0.14: the meter is built even after a /reload in combat (it is not a
  secure frame), polls every 0.2s while in a fight, shows "—" for nil or
  secret values instead of a blank bar, and /nock threat debug prints the
  raw Forever API returns.
  3.0.15: ApplyRowGrid no longer clears the row anchors, so the You / Pet
  bars actually appear inside the plaque. Fonts are set without depending
  on GameFontHighlight. Errors are saved to NockCharDB.errors and printed
  once in chat. Debug labels the five API returns.
  3.1.0: the plaque follows the active HUD style (Emerald or Gunsmith).
  It can be unlocked and dragged (/nock threat unlock|lock|reset, plus a
  keybindable toggle). While unlocked it shows a highlighted outline and
  a "Drag to move" label; the whole plaque is the handle. It snaps to the
  HUD center line, saves its position per character, stays locked by
  default, and will not move in combat (unlock is queued until the fight
  ends). Hidden out of combat unless unlocked so you can place it.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local Threat = {}
Nock.Threat = Threat

local wrap
local rows = {}
local created
local tickerAt = 0

local EMERALD = { 0.22, 0.85, 0.50 }
local AMBER = { 0.95, 0.68, 0.16 }
local RED = { 0.92, 0.22, 0.18 }
local CREAM = { 1.00, 0.98, 0.82 }
local GOLD = { 0.78, 0.70, 0.38 }

local function Colors()
  local T = _G.NockTheme
  if T and T.ThreatColors then
    local c = T.ThreatColors()
    if type(c) == "table" and c.safe then
      return c
    end
  end
  return { safe = EMERALD, amber = AMBER, red = RED, cream = CREAM, gold = GOLD }
end

local function SafeColor()
  return Colors().safe or EMERALD
end

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function Enabled()
  return DB().nockThreat ~= false
end

-- Persist a threat error in NockCharDB.errors and print it once in chat.
local threatWarned
local function ReportError(where, err)
  local msg = tostring(where) .. ": " .. tostring(err)
  Threat._lastError = msg
  local db = DB()
  db.errors = db.errors or {}
  local when = (date and date("%Y-%m-%d %H:%M:%S")) or "?"
  table.insert(db.errors, 1, when .. " " .. msg)
  while #db.errors > 20 do
    table.remove(db.errors)
  end
  if Nock.NoteError then
    -- NoteError also appends; skip it to avoid a duplicate line.
  end
  if not threatWarned then
    threatWarned = true
    local text = "|cfff0e2b6Nock:|r Threat meter error: " .. tostring(err)
    local frame = _G.DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
      pcall(frame.AddMessage, frame, text)
    end
    if print then
      pcall(print, text)
    end
  end
end

local function InCombat()
  if Nock.inCombatFlag then
    return true
  end
  if InCombatLockdown then
    return InCombatLockdown() and true or false
  end
  return false
end

local function EnsureFont(fs, size, flags)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    return T.EnsureFont(fs, size, flags or "THICKOUTLINE")
  end
  if not fs or not fs.SetFont then
    return false
  end
  local path = (type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
  pcall(fs.SetFont, fs, path, type(size) == "number" and size or 16, flags or "THICKOUTLINE")
  return true
end

local function SetTex(tex, key, r, g, b, a)
  local T = _G.NockTheme
  if T and T.SetTex then
    return T.SetTex(tex, key, r, g, b, a)
  end
  if tex and tex.SetColorTexture then
    tex:SetColorTexture(r or 0.07, g or 0.12, b or 0.10, a or 0.94)
  end
  return false
end

local function ReadableNumber(v)
  if v == nil then
    return nil
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then
      return nil
    end
  end
  local ok, n = pcall(tonumber, v)
  if ok and type(n) == "number" then
    return n
  end
  return nil
end

local function ReadableFlag(v)
  if v == nil then
    return nil
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then
      return nil
    end
  end
  if v == true or v == 1 then
    return true
  end
  if v == false or v == 0 then
    return false
  end
  return nil
end

local function ReadableString(v)
  if type(v) ~= "string" then
    return nil
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then
      return nil
    end
  end
  return v
end

function Threat.HasNativeAPI()
  return type(_G.UnitDetailedThreatSituation) == "function"
      or type(_G.UnitThreatSituation) == "function"
      or type(_G.UnitThreatPercentageOfLead) == "function"
end

local function UnitOk(unit)
  if not unit or not UnitExists then
    return false
  end
  local ok, exists = pcall(UnitExists, unit)
  if not ok then
    return false
  end
  local flag = ReadableFlag(exists)
  return flag == true
end

local function UnitLabel(unit, fallback)
  if UnitName and UnitOk(unit) then
    local ok, name = pcall(UnitName, unit)
    if ok then
      local s = ReadableString(name)
      if s and s ~= "" then
        return s
      end
    end
  end
  return fallback
end

local function IsHostile(unit)
  if not UnitOk(unit) then
    return false
  end
  if UnitCanAttack then
    local ok, can = pcall(UnitCanAttack, "player", unit)
    if ok then
      local flag = ReadableFlag(can)
      if flag ~= nil then
        return flag
      end
    end
  end
  -- In a fight, the current target is good enough if we can't read hostility.
  return InCombat()
end

-- Current target, or the pet's target if you have none.
function Threat.MobUnit()
  if UnitOk("target") and IsHostile("target") then
    return "target"
  end
  if UnitOk("pettarget") and IsHostile("pettarget") then
    return "pettarget"
  end
  return nil
end

local function ValuesSecret(unit, mob)
  local S = _G.C_Secrets
  if S and S.ShouldUnitThreatValuesBeSecret then
    local ok, secret = pcall(S.ShouldUnitThreatValuesBeSecret, unit, mob)
    if ok and ReadableFlag(secret) == true then
      return true
    end
  end
  return false
end

local function UnpackThreat(isTanking, status, scaled, raw, value)
  return {
    tanking = ReadableFlag(isTanking),
    status = ReadableNumber(status),
    scaled = ReadableNumber(scaled),
    raw = ReadableNumber(raw),
    value = ReadableNumber(value),
  }
end

-- Query one unit vs a mob. Tries the unit token, then the mob's GUID,
-- matching Forever's usage string `UnitDetailedThreatSituation(unit, mobGUID)`.
-- Return order (standard WoW, and what the 3.0.14 in-game dump matches):
--   isTanking, status, scaledPercent, rawPercent, threatValue
-- status: 0 below tank, 1 higher than tank, 2 insecurely tanking, 3 tanking.
function Threat.Query(unit, mob)
  if not Threat.HasNativeAPI() or not unit or not mob then
    return nil
  end
  if ValuesSecret(unit, mob) then
    return { secret = true }
  end
  local fn = _G.UnitDetailedThreatSituation
  local ok, a, b, c, d, e = pcall(fn, unit, mob)
  if (not ok or (a == nil and b == nil and c == nil)) and UnitGUID then
    local gok, guid = pcall(UnitGUID, mob)
    if gok then
      guid = ReadableString(guid)
      if guid then
        ok, a, b, c, d, e = pcall(fn, unit, guid)
      end
    end
  end
  if not ok then
    a, b, c, d, e = nil, nil, nil, nil, nil
  end
  local unpacked
  if not (a == nil and b == nil and c == nil) then
    unpacked = UnpackThreat(a, b, c, d, e)
    -- Forever may return secret userdata: not nil, but unreadable.
    if unpacked.tanking == nil and unpacked.status == nil
        and unpacked.scaled == nil and unpacked.raw == nil and unpacked.value == nil then
      return { secret = true }
    end
    return unpacked
  end
  -- Detailed call was empty. Try the simpler APIs before giving up.
  local sit, pctLead
  local sitFn = _G.UnitThreatSituation
  if type(sitFn) == "function" then
    local sok, sv = pcall(sitFn, unit, mob)
    if sok then
      sit = ReadableNumber(sv)
    end
    if sit == nil and UnitGUID then
      local gok, guid = pcall(UnitGUID, mob)
      if gok then
        guid = ReadableString(guid)
        if guid then
          sok, sv = pcall(sitFn, unit, guid)
          if sok then
            sit = ReadableNumber(sv)
          end
        end
      end
    end
  end
  local leadFn = _G.UnitThreatPercentageOfLead
  if type(leadFn) == "function" then
    local pok, pv = pcall(leadFn, unit, mob)
    if pok then
      pctLead = ReadableNumber(pv)
    end
  end
  if sit == nil and pctLead == nil then
    return { off = true }
  end
  return {
    tanking = (sit == 2 or sit == 3) or nil,
    status = sit,
    scaled = pctLead,
  }
end

local function IsTanking(info)
  if not info or info.off or info.secret then
    return false
  end
  if info.tanking == true then
    return true
  end
  local s = info.status
  return s == 2 or s == 3
end

-- Color and caption for one bar. Pet holding aggro is the safe (emerald) state.
-- The player going over the tank, or pulling, is amber then red.
function Threat.Style(who, info)
  local c = Colors()
  local safe, amber, red = c.safe, c.amber, c.red
  if not info or info.off then
    return safe, nil, ""
  end
  if info.secret then
    return safe, nil, ""
  end
  local pct = info.scaled
  if not pct then
    pct = 0
  end
  local tanking = IsTanking(info)
  if who == "player" then
    if tanking then
      return red, pct, "You pulled"
    end
    -- status 1 = higher threat than the tank, not yet pulled.
    if info.status == 1 or pct >= 100 then
      if pct >= 110 then
        return red, pct, "About to pull"
      end
      return amber, pct, "About to pull"
    end
    if pct >= 80 then
      return amber, pct, ""
    end
    return safe, pct, ""
  end
  -- Pet: aggro is what we want.
  if tanking then
    return safe, pct, "Aggro"
  end
  if info.status == 1 or pct >= 100 then
    return amber, pct, ""
  end
  return safe, pct, ""
end

function Threat.FormatPct(pct)
  local n = ReadableNumber(pct)
  if n == nil then
    return "—"
  end
  if n < 0 then
    n = 0
  end
  return string.format("%d%%", math.floor(n + 0.5))
end

local function SizeKey()
  if Nock.BarSize then
    return Nock.BarSize() or "large"
  end
  return (DB().barSize) or "large"
end

-- One grid for every size. Width follows the bow plaque (overlay.body)
-- so the meter lines up with the HUD; height is pad + two equal rows.
local function Metrics()
  local k = SizeKey()
  local m
  if k == "small" then
    m = { pad = 10, rowH = 20, gap = 6, font = 13, labelW = 64, nameGap = 8,
          trackH = 14, pctW = 42, tagW = 96, colGap = 8, corner = 22, edge = 10,
          capOverlap = 8, stringOffset = 6, fallbackW = 280 }
  elseif k == "normal" then
    m = { pad = 12, rowH = 24, gap = 8, font = 15, labelW = 76, nameGap = 10,
          trackH = 18, pctW = 50, tagW = 114, colGap = 10, corner = 26, edge = 12,
          capOverlap = 10, stringOffset = 7, fallbackW = 360 }
  else
    m = { pad = 14, rowH = 28, gap = 10, font = 18, labelW = 88, nameGap = 10,
          trackH = 22, pctW = 56, tagW = 132, colGap = 10, corner = 32, edge = 12,
          capOverlap = 12, stringOffset = 9, fallbackW = 505 }
  end
  m.h = m.pad + m.rowH + m.gap + m.rowH + m.pad
  -- track sits between the name column and the right text columns.
  m.rightW = m.pctW + m.colGap + m.tagW
  return m
end

-- Content UVs for the XP fill / track art (the files have empty padding).
local FILL_U, FILL_V = 0.901367, 0.562500

local function FillUV()
  local T = _G.NockTheme
  local uv = T and T.XP and T.XP()
  if type(uv) == "table" and uv.fillU then
    return uv.fillU, uv.fillV
  end
  return FILL_U, FILL_V
end

local BG_U0, BG_V0, BG_U1, BG_V1 = 24 / 2048, 5 / 256, 2019 / 2048, 250 / 256

local function BodyWidth()
  local ov = Nock.Overlay and Nock.Overlay()
  if ov and ov.body and ov.body.GetWidth then
    local w = ov.body:GetWidth()
    if type(w) == "number" and w >= 200 then
      return w
    end
  end
  return Metrics().fallbackW
end

local function BowClearance()
  -- Sit a tight gap above the bow's carved tip. The bow texture is
  -- 2048x512 with the ornament starting at row 118, and the frame is
  -- anchored so the string hovers just above the tiles (Nock.lua).
  local ov = Nock.Overlay and Nock.Overlay()
  if not (ov and ov.bow and ov.body) then
    return nil
  end
  local bowH = (ov.bow.GetHeight and ov.bow:GetHeight()) or 0
  if type(bowH) ~= "number" or bowH < 20 then
    return nil
  end
  local m = Metrics()
  local contentTop = 118 / 512
  local stringFromBottom = 34 / 384
  local bowBottomOff = -(m.stringOffset or 9) - bowH * stringFromBottom
  local visTip = bowBottomOff + bowH * (1 - contentTop)
  return math.floor(visTip + 16 + 0.5)
end

local function SetEdgeTex(tex, which)
  -- which: "h" (top/bottom) or "v" (left/right).
  if SetTex(tex, "edge", 0.75, 0.68, 0.38, 1) or SetTex(tex, "ornament", 0.75, 0.68, 0.38, 1) then
    if which == "v" and tex.SetTexCoord then
      -- Rotate the horizontal rail 90 degrees clockwise.
      pcall(tex.SetTexCoord, tex, 0, 1, 1, 1, 0, 0, 1, 0)
    end
    return true
  end
  tex:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
  return false
end

local function BuildFrame(parent)
  local m = Metrics()
  local wood = parent:CreateTexture(nil, "BACKGROUND")
  -- Inset the wood so the carved edge and corners sit on the rim, snugly.
  local inset = 3
  wood:SetPoint("TOPLEFT", inset, -inset)
  wood:SetPoint("BOTTOMRIGHT", -inset, inset)
  if not SetTex(wood, "barwood", 0.16, 0.10, 0.05, 0.96) then
    wood:SetColorTexture(0.07, 0.12, 0.10, 0.94)
  end
  parent.wood = wood

  -- Silver-gold outer line and a tight emerald inner line.
  local function rim(layer, r, g, b, a, d, thick)
    local top = parent:CreateTexture(nil, layer)
    top:SetColorTexture(r, g, b, a)
    top:SetPoint("TOPLEFT", d, -d)
    top:SetPoint("TOPRIGHT", -d, -d)
    top:SetHeight(thick)
    local bot = parent:CreateTexture(nil, layer)
    bot:SetColorTexture(r, g, b, a)
    bot:SetPoint("BOTTOMLEFT", d, d)
    bot:SetPoint("BOTTOMRIGHT", -d, d)
    bot:SetHeight(thick)
    local left = parent:CreateTexture(nil, layer)
    left:SetColorTexture(r, g, b, a)
    left:SetPoint("TOPLEFT", d, -d)
    left:SetPoint("BOTTOMLEFT", d, d)
    left:SetWidth(thick)
    local right = parent:CreateTexture(nil, layer)
    right:SetColorTexture(r, g, b, a)
    right:SetPoint("TOPRIGHT", -d, -d)
    right:SetPoint("BOTTOMRIGHT", -d, d)
    right:SetWidth(thick)
    return { top, bot, left, right }
  end
  parent.rimDark = rim("BORDER", 0.05, 0.08, 0.05, 1, 0, 1)
  parent.rimGold = rim("BORDER", 0.78, 0.70, 0.38, 1, 1, 1)
  parent.rimEmerald = rim("ARTWORK", 0.31, 0.78, 0.51, 0.85, 2, 1)

  -- Carved rails between the corners.
  local function rail(pointA, a1, a2, pointB, b1, b2, sizeKey, orient)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint(pointA, parent, pointA, a1, a2)
    t:SetPoint(pointB, parent, pointB, b1, b2)
    if sizeKey == "h" then
      t:SetHeight(m.edge)
    else
      t:SetWidth(m.edge)
    end
    SetEdgeTex(t, orient)
    return t
  end
  local c = m.corner
  parent.railTop = rail("TOPLEFT", c, 0, "TOPRIGHT", -c, 0, "h", "h")
  parent.railBot = rail("BOTTOMLEFT", c, 0, "BOTTOMRIGHT", -c, 0, "h", "h")
  parent.railLeft = rail("TOPLEFT", 0, -c, "BOTTOMLEFT", 0, c, "v", "v")
  parent.railRight = rail("TOPRIGHT", 0, -c, "BOTTOMRIGHT", 0, c, "v", "v")

  -- Leaf-and-gold corners, mirrored.
  local corners = {
    { "TOPLEFT", 0, 0, 0, 1, 0, 1 },
    { "TOPRIGHT", 0, 0, 1, 0, 0, 1 },
    { "BOTTOMLEFT", 0, 0, 0, 1, 1, 0 },
    { "BOTTOMRIGHT", 0, 0, 1, 0, 1, 0 },
  }
  parent.corners = {}
  for i, spec in ipairs(corners) do
    local t = parent:CreateTexture(nil, "OVERLAY")
    if t.SetDrawLayer then
      pcall(t.SetDrawLayer, t, "OVERLAY", 6)
    end
    t:SetSize(c, c)
    t:SetPoint(spec[1], parent, spec[1], spec[2], spec[3])
    if SetTex(t, "corner") then
      if t.SetTexCoord then
        pcall(t.SetTexCoord, t, spec[4], spec[5], spec[6], spec[7])
      end
    else
      t:Hide()
    end
    parent.corners[i] = t
  end
end

local function ApplyRowGrid(row)
  local m = Metrics()
  -- Do not ClearAllPoints on the row itself: PlaceRows owns those anchors.
  -- 3.0.13-3.0.14 cleared them here, so the plaque showed and the rows
  -- had no position — an empty wood frame with no names or bars.
  row:SetHeight(m.rowH)
  if row.label then
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetWidth(m.labelW)
    row.label:SetHeight(m.rowH)
    if row.label.SetJustifyV then
      row.label:SetJustifyV("MIDDLE")
    end
    row.label:SetJustifyH("LEFT")
  end
  -- Right column: percent right-aligned, then a fixed tag column.
  if row.tag then
    row.tag:ClearAllPoints()
    row.tag:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.tag:SetWidth(m.tagW)
    row.tag:SetHeight(m.rowH)
    if row.tag.SetJustifyV then
      row.tag:SetJustifyV("MIDDLE")
    end
    row.tag:SetJustifyH("LEFT")
  end
  if row.pct then
    row.pct:ClearAllPoints()
    row.pct:SetPoint("RIGHT", row.tag or row, row.tag and "LEFT" or "RIGHT", row.tag and -m.colGap or 0, 0)
    row.pct:SetWidth(m.pctW)
    row.pct:SetHeight(m.rowH)
    if row.pct.SetJustifyV then
      row.pct:SetJustifyV("MIDDLE")
    end
    row.pct:SetJustifyH("RIGHT")
  end
  -- The bar fills the space between the name and the percent column.
  if row.track then
    row.track:ClearAllPoints()
    row.track:SetPoint("LEFT", row.label, "RIGHT", m.nameGap, 0)
    row.track:SetPoint("RIGHT", row.pct, "LEFT", -m.colGap, 0)
    row.track:SetHeight(m.trackH)
  end
  if row.trackEdge then
    row.trackEdge:ClearAllPoints()
    row.trackEdge:SetPoint("TOPLEFT", row.track, "TOPLEFT", -1, 1)
    row.trackEdge:SetPoint("BOTTOMRIGHT", row.track, "BOTTOMRIGHT", 1, -1)
  end
  if row.fill then
    row.fill:ClearAllPoints()
    row.fill:SetPoint("LEFT", row.track, "LEFT", 1, 0)
    row.fill:SetHeight(m.trackH - 2)
  end
  if row.gloss then
    row.gloss:ClearAllPoints()
    row.gloss:SetPoint("TOPLEFT", row.fill, "TOPLEFT", 0, 0)
    row.gloss:SetPoint("TOPRIGHT", row.fill, "TOPRIGHT", 0, 0)
    row.gloss:SetHeight(math.max(2, math.floor((m.trackH - 2) * 0.4 + 0.5)))
  end
  -- Computed track width: never rely on GetWidth being laid out yet.
  local w = (wrap and wrap.GetWidth and wrap:GetWidth()) or BodyWidth()
  row.trackW = math.max(8, w - 2 * m.pad - m.labelW - m.nameGap - m.colGap - m.rightW)
end

local function MakeRow(parent, which)
  local m = Metrics()
  local row = CreateFrame("Frame", nil, parent)
  row.which = which
  row:SetHeight(m.rowH)
  if row.EnableMouse then
    row:EnableMouse(false)
  end
  if parent.GetFrameLevel and row.SetFrameLevel then
    pcall(row.SetFrameLevel, row, (parent:GetFrameLevel() or 20) + 5)
  end
  row:Show()

  local function makeFS()
    -- Do not inherit GameFontHighlight: if that object has no font yet,
    -- SetText throws "Font not set". Always set a font ourselves.
    local fs = row:CreateFontString(nil, "OVERLAY")
    EnsureFont(fs, m.font, "THICKOUTLINE")
    local cream = Colors().cream or CREAM
    fs:SetTextColor(cream[1], cream[2], cream[3])
    pcall(fs.SetText, fs, "")
    return fs
  end
  row.label = makeFS()
  row.tag = makeFS()
  row.pct = makeFS()

  local trackEdge = row:CreateTexture(nil, "ARTWORK")
  trackEdge:SetColorTexture(0.12, 0.10, 0.06, 0.95)
  row.trackEdge = trackEdge

  local track = row:CreateTexture(nil, "ARTWORK")
  if not SetTex(track, "xp_bg", 0.05, 0.08, 0.06, 0.95) then
    track:SetColorTexture(0.05, 0.08, 0.06, 0.95)
  end
  if track.SetTexCoord then
    pcall(track.SetTexCoord, track, BG_U0, BG_U1, BG_V0, BG_V1)
  end
  row.track = track

  local fill = row:CreateTexture(nil, "OVERLAY")
  local safe = SafeColor()
  if not SetTex(fill, "xp_fill", safe[1], safe[2], safe[3], 1) then
    fill:SetColorTexture(safe[1], safe[2], safe[3], 1)
  end
  if fill.SetTexCoord then
    local fu, fv = FillUV()
    pcall(fill.SetTexCoord, fill, 0, fu, 0, fv)
  end
  if fill.SetVertexColor then
    fill:SetVertexColor(safe[1], safe[2], safe[3], 1)
  end
  row.fill = fill

  -- Subtle gloss along the top of the fill, like a polished bar.
  local gloss = row:CreateTexture(nil, "OVERLAY")
  gloss:SetColorTexture(1, 1, 1, 0.22)
  row.gloss = gloss

  return row
end

local function PlaceRows()
  local m = Metrics()
  if rows.player then
    rows.player:ClearAllPoints()
    rows.player:SetPoint("TOPLEFT", wrap, "TOPLEFT", m.pad, -m.pad)
    rows.player:SetPoint("TOPRIGHT", wrap, "TOPRIGHT", -m.pad, -m.pad)
    rows.player:Show()
    ApplyRowGrid(rows.player)
  end
  if rows.pet then
    rows.pet:ClearAllPoints()
    local y = -(m.pad + m.rowH + m.gap)
    rows.pet:SetPoint("TOPLEFT", wrap, "TOPLEFT", m.pad, y)
    rows.pet:SetPoint("TOPRIGHT", wrap, "TOPRIGHT", -m.pad, y)
    rows.pet:Show()
    ApplyRowGrid(rows.pet)
  end
end


-- Movement. Locked by default. Position is saved per character.
-- The whole plaque is the drag handle — no fiddly click targets.
local SNAP_PX = 20
local pendingUnlock

function Threat.IsLocked()
  return DB().threatLocked ~= false
end

local function ParentScale(f)
  if f and f.GetEffectiveScale then
    local s = f:GetEffectiveScale()
    if type(s) == "number" and s > 0 then
      return s
    end
  end
  return 1
end

local function CenterOnParent(f)
  if not (f and f.GetCenter and UIParent and UIParent.GetCenter) then
    return nil
  end
  local fx, fy = f:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not fx or not ux then
    return nil
  end
  local fs, ps = ParentScale(f), ParentScale(UIParent)
  return (fx * fs / ps) - ux, (fy * fs / ps) - uy, fy * fs / ps, ux, uy
end

local function BodyCenterX()
  local ov = Nock.Overlay and Nock.Overlay()
  local body = ov and ov.body
  if not (body and body.GetCenter and UIParent and UIParent.GetCenter) then
    return nil
  end
  local bx = body:GetCenter()
  local ux = UIParent:GetCenter()
  if not bx or not ux then
    return nil
  end
  local bs, ps = ParentScale(body), ParentScale(UIParent)
  return (bx * bs / ps)
end

function Threat.SnapIfClose()
  if not wrap then
    return false
  end
  local fxOff, fyOff, _, ux, uy = CenterOnParent(wrap)
  local bodyX = BodyCenterX()
  if not fxOff or not bodyX or not ux then
    return false
  end
  local wrapX = ux + fxOff
  if math.abs(wrapX - bodyX) <= SNAP_PX then
    wrap:ClearAllPoints()
    wrap:SetPoint("CENTER", UIParent, "CENTER", bodyX - ux, fyOff)
    return true
  end
  return false
end

local function SavePos()
  if not wrap then
    return
  end
  Threat.SnapIfClose()
  local fxOff, fyOff = CenterOnParent(wrap)
  if fxOff then
    DB().threatPos = { x = fxOff, y = fyOff }
    return
  end
  local point, _, relPoint, x, y = wrap:GetPoint(1)
  if point then
    DB().threatPos = { point = point, relPoint = relPoint, x = x, y = y }
  end
end

local function PlaceDefault()
  local ov = Nock.Overlay and Nock.Overlay()
  local rise = BowClearance()
  if ov and ov.body and rise then
    wrap:SetPoint("BOTTOM", ov.body, "TOP", 0, rise)
  elseif ov and ov.bow and ov.bow.GetParent then
    wrap:SetPoint("BOTTOM", ov.bow, "TOP", 0, 8)
  elseif ov and ov.body then
    wrap:SetPoint("BOTTOM", ov.body, "TOP", 0, 96)
  else
    wrap:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 520)
  end
end

local function PlaceSaved()
  local pos = DB().threatPos
  if not pos then
    return false
  end
  if pos.x ~= nil and pos.y ~= nil then
    wrap:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
    return true
  end
  if pos.point then
    wrap:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    return true
  end
  return false
end

local function AccentRGB()
  local c = Colors()
  local a = c.gold or c.safe or GOLD
  return a[1], a[2], a[3]
end

local function EnsureMoveChrome()
  if not wrap or wrap.moveChrome then
    return
  end
  local chrome = CreateFrame("Frame", nil, wrap)
  chrome:SetAllPoints(wrap)
  if chrome.EnableMouse then
    chrome:EnableMouse(false)
  end
  if wrap.GetFrameLevel and chrome.SetFrameLevel then
    pcall(chrome.SetFrameLevel, chrome, (wrap:GetFrameLevel() or 20) + 20)
  end
  local function edge()
    local t = chrome:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 1, 1, 1)
    return t
  end
  local top, bot, left, right = edge(), edge(), edge(), edge()
  top:SetPoint("TOPLEFT", chrome, "TOPLEFT", -2, 2)
  top:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", 2, 2)
  top:SetHeight(3)
  bot:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", -2, -2)
  bot:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", 2, -2)
  bot:SetHeight(3)
  left:SetPoint("TOPLEFT", chrome, "TOPLEFT", -2, 2)
  left:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", -2, -2)
  left:SetWidth(3)
  right:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", 2, 2)
  right:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", 2, -2)
  right:SetWidth(3)
  chrome.edges = { top, bot, left, right }
  local label = chrome:CreateFontString(nil, "OVERLAY")
  EnsureFont(label, 16, "THICKOUTLINE")
  label:SetPoint("CENTER", chrome, "CENTER", 0, 0)
  label:SetText("Drag to move")
  local r, g, b = AccentRGB()
  if label.SetTextColor then
    label:SetTextColor(r, g, b, 1)
  end
  chrome.label = label
  wrap.moveChrome = chrome
  wrap.moveLabel = label
  chrome:Hide()
end

local function PaintMoveChrome()
  if not wrap or not wrap.moveChrome then
    return
  end
  local r, g, b = AccentRGB()
  for _, t in ipairs(wrap.moveChrome.edges or {}) do
    if t.SetColorTexture then
      t:SetColorTexture(r, g, b, 1)
    elseif t.SetVertexColor then
      t:SetVertexColor(r, g, b, 1)
    end
  end
  if wrap.moveLabel and wrap.moveLabel.SetTextColor then
    wrap.moveLabel:SetTextColor(r, g, b, 1)
  end
end

local function ShowMoveChrome(on)
  EnsureMoveChrome()
  if not wrap or not wrap.moveChrome then
    return
  end
  if on then
    PaintMoveChrome()
    wrap.moveChrome:Show()
    if wrap.moveLabel then
      wrap.moveLabel:SetText("Drag to move")
      wrap.moveLabel:Show()
    end
  else
    wrap.moveChrome:Hide()
  end
end

local function ApplyLockState()
  if not wrap then
    return
  end
  EnsureMoveChrome()
  local unlocked = not Threat.IsLocked()
  local fighting = InCombat()
  -- The whole plaque is the handle, but never start a move in a fight.
  if wrap.SetMovable then
    wrap:SetMovable(unlocked and not fighting)
  end
  if wrap.EnableMouse then
    wrap:EnableMouse(unlocked and not fighting)
  end
  if unlocked and wrap.RegisterForDrag then
    wrap:RegisterForDrag("LeftButton")
  end
  ShowMoveChrome(unlocked)
  if unlocked and not fighting then
    wrap:Show()
  end
end

local function WireDrag()
  if not wrap or wrap._nockDragWired then
    return
  end
  wrap._nockDragWired = true
  if wrap.RegisterForDrag then
    wrap:RegisterForDrag("LeftButton")
  end
  wrap:SetScript("OnDragStart", function(self)
    if Threat.IsLocked() then
      return
    end
    if InCombat() then
      local Nock = _G.Nock
      if Nock and Nock.Print then
        Nock.Print("Leave combat first.")
      end
      return
    end
    if self.StartMoving then
      self:StartMoving()
    end
  end)
  wrap:SetScript("OnDragStop", function(self)
    if self.StopMovingOrSizing then
      self:StopMovingOrSizing()
    end
    if Threat.IsLocked() or InCombat() then
      return
    end
    SavePos()
  end)
end

function Threat.SetLocked(on)
  on = on and true or false
  if not on and InCombat() then
    pendingUnlock = true
    return false, "combat"
  end
  pendingUnlock = nil
  DB().threatLocked = on
  if not on or wrap then
    Threat.Ensure()
  end
  ApplyLockState()
  if on and not InCombat() and wrap then
    -- Locking out of combat hides the plaque again, same as usual.
    wrap:Hide()
  end
  return true
end

function Threat.ToggleLocked()
  return Threat.SetLocked(not Threat.IsLocked())
end

function Threat.ResetPos()
  if InCombat() then
    return false, "combat"
  end
  DB().threatPos = nil
  if wrap then
    Threat.Layout()
  end
  return true
end

function Threat.ApplyPendingUnlock()
  if pendingUnlock and not InCombat() then
    pendingUnlock = nil
    Threat.SetLocked(false)
  else
    ApplyLockState()
  end
end

function Threat.Restyle()
  if not wrap then
    return
  end
  -- Re-apply style textures and UVs, then re-layout / repaint.
  if wrap.wood and SetTex then
    SetTex(wrap.wood, "barwood", 0.16, 0.10, 0.05, 0.96)
  end
  local fu, fv = FillUV()
  for _, row in pairs(rows) do
    if row.track and row.track.SetTexCoord then
      pcall(row.track.SetTexCoord, row.track, BG_U0, BG_U1, BG_V0, BG_V1)
    end
    if row.fill and row.fill.SetTexCoord then
      pcall(row.fill.SetTexCoord, row.fill, 0, fu, 0, fv)
    end
    if row.track then
      SetTex(row.track, "xp_bg", 0.05, 0.08, 0.06, 0.95)
    end
    if row.fill then
      local safe = SafeColor()
      SetTex(row.fill, "xp_fill", safe[1], safe[2], safe[3], 1)
    end
  end
  -- Corners / rails
  if wrap.corners then
    for _, t in ipairs(wrap.corners) do
      SetTex(t, "corner")
    end
  end
  PaintMoveChrome()
  Threat.Layout()
end

function _G.Nock_ToggleThreatUnlock()
  local ok, why = Threat.ToggleLocked()
  local msg
  if why == "combat" then
    msg = "Leave combat first — the threat meter will unlock when the fight ends."
  elseif Threat.IsLocked() then
    msg = "Threat meter locked."
  else
    msg = "Threat meter unlocked: drag it anywhere. It snaps to the middle of the bar. /nock threat lock when you're done, or /nock threat reset to put it back above the bow."
  end
  if Nock.Print then
    Nock.Print(msg)
  else
    local frame = _G.DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
      pcall(frame.AddMessage, frame, "|cfff0e2b6Nock:|r " .. msg)
    end
  end
end

function Threat.Ensure()
  if wrap then
    return wrap
  end
  -- This is a display-only, insecure frame. Creating and anchoring it
  -- in combat is allowed, and is what makes a mid-fight /reload work.
  local m = Metrics()
  wrap = CreateFrame("Frame", "NockThreatMeter", UIParent)
  wrap:SetSize(BodyWidth(), m.h)
  wrap:SetFrameStrata("MEDIUM")
  wrap:SetFrameLevel(20)
  wrap:Hide()
  wrap:EnableMouse(false)
  wrap:SetClampedToScreen(true)

  BuildFrame(wrap)
  rows.player = MakeRow(wrap, "player")
  rows.pet = MakeRow(wrap, "pet")
  PlaceRows()
  WireDrag()
  EnsureMoveChrome()
  ApplyLockState()

  wrap:SetScript("OnSizeChanged", function()
    PlaceRows()
  end)

  created = true
  return wrap
end

function Threat.MeasureTracks()
  PlaceRows()
end

function Threat.Layout()
  if not Enabled() then
    if wrap then
      wrap:Hide()
    end
    return 0
  end
  if not Threat.Ensure() then
    return 0
  end
  local m = Metrics()
  wrap:SetSize(BodyWidth(), m.h)
  wrap:ClearAllPoints()
  -- Sit just above the bow unless this character has dragged it elsewhere.
  if not PlaceSaved() then
    PlaceDefault()
  end
  ApplyLockState()
  -- Resize corners and rails if the bar size changed.
  if wrap.corners then
    for _, t in ipairs(wrap.corners) do
      t:SetSize(m.corner, m.corner)
    end
  end
  if wrap.railTop then wrap.railTop:SetHeight(m.edge) end
  if wrap.railBot then wrap.railBot:SetHeight(m.edge) end
  if wrap.railLeft then wrap.railLeft:SetWidth(m.edge) end
  if wrap.railRight then wrap.railRight:SetWidth(m.edge) end
  for _, row in pairs(rows) do
    EnsureFont(row.label, m.font, "THICKOUTLINE")
    EnsureFont(row.pct, m.font, "THICKOUTLINE")
    EnsureFont(row.tag, m.font, "THICKOUTLINE")
  end
  PlaceRows()
  Threat.Update()
  return m.h
end

local function PaintRow(row, name, color, pct, tag)
  if not row then
    return
  end
  row:Show()
  local m = Metrics()
  local function write(fs, text, cr, cg, cb)
    if not fs then
      return
    end
    EnsureFont(fs, m.font, "THICKOUTLINE")
    local ok, err = pcall(fs.SetText, fs, text or "")
    if not ok then
      ReportError("Threat.SetText", err)
      EnsureFont(fs, m.font, "THICKOUTLINE")
      ok, err = pcall(fs.SetText, fs, text or "")
      if not ok then
        ReportError("Threat.SetText retry", err)
      end
    end
    if cr and fs.SetTextColor then
      pcall(fs.SetTextColor, fs, cr, cg, cb)
    end
  end
  local cream = Colors().cream or CREAM
  write(row.label, name or "", cream[1], cream[2], cream[3])
  local r, g, b = color[1], color[2], color[3]
  if row.fill then
    if row.fill.SetVertexColor then
      row.fill:SetVertexColor(r, g, b, 1)
    else
      row.fill:SetColorTexture(r, g, b, 1)
    end
    -- Recompute from the grid so a 100% fill reaches the end of the track.
    local tw = row.trackW or 200
    if wrap and wrap.GetWidth then
      local ww = wrap:GetWidth()
      if type(ww) == "number" and ww > 1 then
        tw = math.max(8, ww - 2 * m.pad - m.labelW - m.nameGap - m.colGap - m.rightW)
        row.trackW = tw
      end
    end
    local inner = math.max(1, tw - 2)
    local width = 1
    if type(pct) == "number" then
      local frac = pct / 100
      if frac < 0 then frac = 0 end
      if frac > 1 then frac = 1 end
      width = math.max(1, inner * frac)
    end
    row.fill:SetWidth(width)
  end
  if row.gloss then
    if type(pct) == "number" and pct > 0 then
      row.gloss:Show()
      row.gloss:SetColorTexture(1, 1, 1, 0.22)
    else
      row.gloss:Hide()
    end
  end
  write(row.pct, Threat.FormatPct(pct), r, g, b)
  write(row.tag, tag or "", r, g, b)
end


function Threat.Update()
  local ok, err = pcall(Threat._UpdateInner)
  if not ok then
    ReportError("Threat.Update", err)
  end
end

function Threat._UpdateInner()
  if not Enabled() then
    if wrap then
      wrap:Hide()
    end
    return
  end
  if not InCombat() then
    if wrap then
      if Threat.IsLocked() then
        wrap:Hide()
      else
        -- Unlocked: keep the plaque up so it can be dragged with no fiddly click.
        local pColor, pPct, pTag = Threat.Style("player", { off = true })
        local petColor, petPct, petTag = Threat.Style("pet", { off = true })
        PaintRow(rows.player, "You", pColor, pPct, pTag)
        if UnitOk("pet") then
          PaintRow(rows.pet, UnitLabel("pet", "Pet"), petColor, petPct, petTag)
          rows.pet:Show()
        elseif rows.pet then
          rows.pet:Hide()
        end
        wrap:Show()
        ApplyLockState()
      end
    end
    return
  end
  if not wrap then
    Threat.Ensure()
  end
  if not wrap then
    return
  end

  local mob = Threat.MobUnit()
  local playerInfo = mob and Threat.Query("player", mob) or nil
  local petInfo = (mob and UnitOk("pet")) and Threat.Query("pet", mob) or nil

  local pColor, pPct, pTag = Threat.Style("player", playerInfo or { off = true })
  local petColor, petPct, petTag = Threat.Style("pet", petInfo or { off = true })

  PaintRow(rows.player, "You", pColor, pPct, pTag)
  if UnitOk("pet") then
    local petName = UnitLabel("pet", "Pet")
    if #petName > 12 then
      petName = string.sub(petName, 1, 11) .. "."
    end
    PaintRow(rows.pet, petName, petColor, petPct, petTag)
    rows.pet:Show()
  else
    if rows.pet then
      rows.pet:Hide()
    end
  end

  -- Stay visible for the whole fight so a missed event or a nil query
  -- cannot flicker the plaque off.
  wrap:Show()
end

function Threat.SetEnabled(on)
  DB().nockThreat = on and true or false
  if not on then
    if wrap then
      wrap:Hide()
    end
    return
  end
  Threat.Layout()
end

Nock.SetNockThreat = Threat.SetEnabled

local function Chat(msg)
  msg = "|cfff0e2b6Nock:|r " .. tostring(msg)
  local frame = _G.DEFAULT_CHAT_FRAME
  if frame and frame.AddMessage then
    pcall(frame.AddMessage, frame, msg)
  end
  if print then
    pcall(print, msg)
  end
end

local function Describe(v)
  if v == nil then
    return "nil"
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then
      return "[secret]"
    end
  end
  local t = type(v)
  if t == "boolean" or t == "number" then
    return tostring(v)
  end
  if t == "string" then
    if #v > 48 then
      v = string.sub(v, 1, 45) .. "..."
    end
    return string.format("%q", v)
  end
  return "<" .. t .. ">"
end

local function CallDump(label, fn, ...)
  if type(fn) ~= "function" then
    Chat("  " .. label .. " is not a function")
    return
  end
  local pack = { pcall(fn, ...) }
  local ok = pack[1]
  if not ok then
    Chat("  " .. label .. " error: " .. Describe(pack[2]))
    return
  end
  local bits = {}
  -- Show at least the five returns UnitDetailedThreatSituation uses.
  local n = math.max(5, #pack - 1)
  for i = 1, n do
    bits[#bits + 1] = Describe(pack[i + 1])
  end
  Chat("  " .. label .. " -> " .. table.concat(bits, ", "))
end

local function CallDumpDetailed(label, fn, ...)
  if type(fn) ~= "function" then
    Chat("  " .. label .. " is not a function")
    return
  end
  local pack = { pcall(fn, ...) }
  if not pack[1] then
    Chat("  " .. label .. " error: " .. Describe(pack[2]))
    return
  end
  Chat("  " .. label
    .. " -> isTanking=" .. Describe(pack[2])
    .. "  status=" .. Describe(pack[3])
    .. "  scaled=" .. Describe(pack[4])
    .. "  raw=" .. Describe(pack[5])
    .. "  value=" .. Describe(pack[6]))
end

-- Print raw Forever threat API returns so we can see what the live
-- client is actually handing the meter. Safe with secret values.
function Threat.Debug()
  Chat("threat debug  (Nock 3.1.1)")
  Chat("  enabled=" .. tostring(Enabled())
    .. "  inCombat=" .. tostring(InCombat())
    .. "  hasAPI=" .. tostring(Threat.HasNativeAPI()))
  Chat("  UnitDetailedThreatSituation=" .. type(_G.UnitDetailedThreatSituation)
    .. "  UnitThreatSituation=" .. type(_G.UnitThreatSituation)
    .. "  UnitThreatPercentageOfLead=" .. type(_G.UnitThreatPercentageOfLead))
  if Threat._lastError then
    Chat("  last error: " .. Threat._lastError)
  end
  Chat("  exists: target=" .. tostring(UnitOk("target"))
    .. "  pet=" .. tostring(UnitOk("pet"))
    .. "  pettarget=" .. tostring(UnitOk("pettarget")))
  local mob = Threat.MobUnit()
  Chat("  mob unit=" .. tostring(mob or "nil"))
  if mob and UnitGUID then
    local ok, guid = pcall(UnitGUID, mob)
    Chat("  mob GUID=" .. (ok and Describe(guid) or ("error " .. Describe(guid))))
  end
  if wrap then
    Chat("  frame exists shown=" .. tostring(wrap:IsShown())
      .. "  size=" .. tostring(wrap:GetWidth()) .. "x" .. tostring(wrap:GetHeight()))
  else
    Chat("  frame does not exist yet")
  end
  local function dumpUnit(unit)
    if not mob then
      Chat("  " .. unit .. ": no mob")
      return
    end
    Chat("  -- " .. unit .. " vs " .. tostring(mob) .. " --")
    if ValuesSecret(unit, mob) then
      Chat("  C_Secrets.ShouldUnitThreatValuesBeSecret = true")
    end
    CallDumpDetailed("UnitDetailedThreatSituation(" .. unit .. ", " .. tostring(mob) .. ")", _G.UnitDetailedThreatSituation, unit, mob)
    if UnitGUID then
      local ok, guid = pcall(UnitGUID, mob)
      if ok then
        guid = ReadableString(guid)
        if guid then
          CallDumpDetailed("UnitDetailedThreatSituation(" .. unit .. ", GUID)", _G.UnitDetailedThreatSituation, unit, guid)
        end
      end
    end
    CallDump("UnitThreatSituation(" .. unit .. ", " .. tostring(mob) .. ")", _G.UnitThreatSituation, unit, mob)
    CallDump("UnitThreatPercentageOfLead(" .. unit .. ", " .. tostring(mob) .. ")", _G.UnitThreatPercentageOfLead, unit, mob)
    local info = Threat.Query(unit, mob)
    if not info then
      Chat("  " .. unit .. " Query=nil")
    elseif info.secret then
      Chat("  " .. unit .. " Query={secret}")
    elseif info.off then
      Chat("  " .. unit .. " Query={off}")
    else
      Chat("  " .. unit .. " Query: isTanking=" .. Describe(info.tanking)
        .. "  status=" .. Describe(info.status)
        .. "  scaled=" .. Describe(info.scaled)
        .. "  raw=" .. Describe(info.raw)
        .. "  value=" .. Describe(info.value))
    end
  end
  dumpUnit("player")
  if UnitOk("pet") then
    dumpUnit("pet")
  else
    Chat("  pet: not out")
  end
end

-- Events live on their own insecure frame so the meter can refresh in combat.
local ev = CreateFrame("Frame")
local function SafeRegister(name)
  pcall(ev.RegisterEvent, ev, name)
end
local function SafeRegisterUnit(event, unit)
  if ev.RegisterUnitEvent then
    local ok = pcall(ev.RegisterUnitEvent, ev, event, unit)
    if ok then
      return
    end
  end
  pcall(ev.RegisterEvent, ev, event)
end
SafeRegister("PLAYER_LOGIN")
SafeRegister("PLAYER_ENTERING_WORLD")
SafeRegister("PLAYER_REGEN_DISABLED")
SafeRegister("PLAYER_REGEN_ENABLED")
SafeRegister("PLAYER_TARGET_CHANGED")
SafeRegister("UNIT_PET")
-- UNIT_THREAT_* may require a unit filter on Forever; register both ways.
for _, evName in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
  SafeRegister(evName)
  for _, unit in ipairs({ "player", "pet", "target", "pettarget" }) do
    SafeRegisterUnit(evName, unit)
  end
end

ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if InCombat() then
      Threat.Ensure()
      Threat.Update()
    else
      Threat.Layout()
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    -- Leaving combat hides the plaque only when it is locked. While
    -- unlocked it must stay up (with placeholder rows) so it can be dragged.
    Threat.Update()
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    Threat.Ensure()
  end
  Threat.Update()
end)

-- Poll every 0.2s while in combat, even if the frame is not yet shown.
-- That covers missed events and a /reload mid-fight.
ev:SetScript("OnUpdate", function(_, elapsed)
  tickerAt = tickerAt + (elapsed or 0)
  if tickerAt < 0.2 then
    return
  end
  tickerAt = 0
  if not Enabled() then
    return
  end
  if InCombat() then
    if not wrap then
      Threat.Ensure()
    end
    Threat.Update()
  elseif wrap and wrap:IsShown() then
    -- Do not yank the plaque away if the player just unlocked it to move it.
    if Threat.IsLocked() then
      wrap:Hide()
    else
      Threat.Update()
    end
  end
end)

-- Used by tests.
Threat._rows = rows
Threat._metrics = Metrics
Threat.IsTanking = IsTanking
Threat._ev = ev
Threat._pendingUnlock = function() return pendingUnlock end
function Threat._wipeForTest()
  if wrap then
    wrap:Hide()
  end
  wrap = nil
  rows.player = nil
  rows.pet = nil
  created = false
  tickerAt = 0
  pendingUnlock = nil
end
