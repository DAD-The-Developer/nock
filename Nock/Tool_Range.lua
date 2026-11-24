--[[
  Nock 3.4.0 hunter tool: dead zone, range and Wing Clip.

  A big readout under your character while you fight:
    MELEE      "WING CLIP, then step back"  (when the target is not slowed)
    MELEE      "STEP BACK  Wing Clip 7s"    (already clipped: get out to 8 yd)
    DEAD ZONE  too close for Auto Shot, not in melee: step back
    TOO FAR    beyond your shot range
  The screen edge flashes when you drift into the dead zone, the Wing Clip
  key on Nock's bar glows while Nock wants a clip, and you get an alert when
  Wing Clip falls off something still in your face.

  How it reads range: IsSpellInRange on Raptor Strike / Wing Clip (melee)
  and Auto Shot (ranged), which Forever keeps readable in combat. Wing Clip
  time comes from the target's debuff when the client lets addons read it,
  otherwise from your own Wing Clip cast (10 s; a dodged clip still counts,
  so treat it as a guide).

  Profile aware: only prompts Wing Clip once you know it (rank shown);
  Survival builds get the Improved Wing Clip root note; Marksmanship builds
  get repeated dead-zone flashes; in dungeons and raids the readout stays but
  flashes and sounds go quiet (switchable).
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "range",
  name = "Dead zone, range and Wing Clip",
  desc = "Readout for melee / dead zone / too far, Wing Clip prompt and timer, edge flash.",
  cmd = { "range", "deadzone", "wingclip", "clip" },
  defaults = { on = true, indicator = true, flash = true, far = true, wingclip = true, falloff = true, glow = true, quietGroup = true },
  options = {
    { key = "indicator", label = "Show the melee / dead zone / too far readout" },
    { key = "wingclip", label = "Prompt Wing Clip, then step back, in melee" },
    { key = "falloff", label = "Alert when Wing Clip falls off a target still in melee" },
    { key = "glow", label = "Soft pulse on the Wing Clip button in melee or the dead zone (until the target is slowed)" },
    { key = "flash", label = "Flash the screen edge in the dead zone" },
    { key = "far", label = "Show TOO FAR in combat" },
    { key = "quietGroup", label = "In dungeons and raids: readout only, no flashes" },
  },
  help = { "/nock range — dead zone / melee readout and Wing Clip helper on or off   /nock range test" },
})

local CLIP_DURATION = 10
local MELEE_SPELLS = { "Raptor Strike", "Wing Clip", "Mongoose Bite", "Counterattack", "Lacerate" }
local RANGED_SPELLS = { "Auto Shot", "Arcane Shot", "Serpent Sting", "Concussive Shot" }

-- Range reading ------------------------------------------------------------------

local function InRange(name)
  local r
  if C_Spell and C_Spell.IsSpellInRange then
    local ok, v = pcall(C_Spell.IsSpellInRange, name, "target")
    if ok then
      r = v
    end
  elseif IsSpellInRange then
    local ok, v = pcall(IsSpellInRange, name, "target")
    if ok then
      r = v
    end
  end
  r = Core.Flag(r)
  if r == nil and Nock.SpellRange then
    r = Nock.SpellRange(name) -- 3.8.0: falls back to the action bar slot (IsActionInRange)
  end
  return r
end

local function FirstReading(list)
  for _, name in ipairs(list) do
    if Core.Knows(name) then
      local v = InRange(name)
      if v ~= nil then
        return v
      end
    end
  end
  return nil
end

local function Close()
  if not CheckInteractDistance then
    return nil
  end
  local ok, v = pcall(CheckInteractDistance, "target", 3)
  if ok then
    return Core.Flag(v)
  end
  return nil
end

--[[ Decide the zone from readings (pure, tested).
  melee/ranged/close: true, false or nil. recentMelee: seconds since the last
  melee reading (nil = never). Returns "melee", "deadzone", "far", "ok" or nil. ]]
function M.Classify(melee, ranged, close, recentMelee)
  if melee == true then
    return "melee"
  end
  if ranged == true then
    return "ok"
  end
  if ranged == false then
    if close == true or (recentMelee and recentMelee < 2) then
      return "deadzone"
    end
    return "far"
  end
  if close == true then
    return "deadzone"
  end
  return nil
end

-- Wing Clip on the target -------------------------------------------------------

local clip = { t = nil, guid = nil, rank = 0 }
local wingName = "Wing Clip"

local function AurasSecret()
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
    if ok and Core.Flag(v) ~= false then
      return true
    end
  end
  return false
end

-- 3.8.0: seconds left on a debuff on the target, 0 when it is not there,
-- nil when the client won't say. C_UnitAuras first, then classic UnitDebuff.
function M.AuraLeft(name, now)
  now = now or Core.Now()
  if AurasSecret() then
    return nil
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", name, "HARMFUL")
    if ok then
      if type(data) == "table" then
        local exp = Core.Number(data.expirationTime)
        if exp and exp > 0 then
          return math.max(0, exp - now)
        end
        return CLIP_DURATION
      end
      return 0
    end
  end
  if UnitDebuff then
    for i = 1, 40 do
      local ok, n, _, _, _, _, exp = pcall(UnitDebuff, "target", i)
      if not ok or not n then
        break
      end
      if n == name then
        exp = Core.Number(exp)
        if exp and exp > 0 then
          return math.max(0, exp - now)
        end
        return CLIP_DURATION
      end
    end
    return 0
  end
  return nil
end

-- Slows that make a Wing Clip pointless right now (besides Wing Clip itself).
M.SLOWS = { "Concussive Shot", "Frost Trap Aura", "Improved Wing Clip" }

-- Is the target already slowed? Returns seconds left and the slow's name.
function M.SlowRemaining(now)
  local left, src = M.ClipRemaining(now)
  if left and left > 0 then
    return left, wingName, src
  end
  if src ~= "aura" then
    local l = M.AuraLeft(wingName, now) -- classic UnitDebuff when C_UnitAuras is missing
    if l and l > 0 then
      return l, wingName, "aura"
    end
  end
  for _, n in ipairs(M.SLOWS) do
    local l = M.AuraLeft(n, now)
    if l and l > 0 then
      return l, n, "aura"
    end
  end
  return 0, nil
end

-- Pure: Wing Clip button state from the zone and the target's slow.
-- lit: in melee. pulse: wanted (melee or dead zone, not slowed). timer: slow left.
function M.ClipButtonState(hostile, zone, slowLeft, knows, pulseOn)
  if not hostile then
    return { lit = false, pulse = false }
  end
  local slowed = slowLeft and slowLeft > 0
  local st = { lit = zone == "melee", pulse = false }
  if knows and pulseOn ~= false and not slowed and (zone == "melee" or zone == "deadzone") then
    st.pulse = true
  end
  if slowed then
    st.timer = slowLeft
  end
  return st
end

-- Returns remaining seconds (0 = not clipped) and the source ("aura" / "cast"),
-- or nil when unknown.
function M.ClipRemaining(now)
  now = now or Core.Now()
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName and not AurasSecret() then
    local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", wingName, "HARMFUL")
    if ok then
      if type(data) == "table" then
        local exp = Core.Number(data.expirationTime)
        if exp and exp > 0 then
          return math.max(0, exp - now), "aura"
        end
        return CLIP_DURATION, "aura"
      elseif data == nil then
        return 0, "aura"
      end
    end
  end
  if clip.t then
    local left = CLIP_DURATION - (now - clip.t)
    if left > 0 then
      return left, "cast"
    end
  end
  return 0, "cast"
end

local function TargetGUID()
  local g = Core.Call(UnitGUID, "target")
  if g and not Core.IsSecret(g) then
    return g
  end
  return nil
end

Core.On("UNIT_SPELLCAST_SUCCEEDED", "range", function(_, unit, _, spellID)
  if unit ~= "player" or not spellID or Core.IsSecret(spellID) then
    return
  end
  local name = C_Spell and C_Spell.GetSpellName and Core.Call(C_Spell.GetSpellName, spellID)
  if not name and GetSpellInfo then
    name = Core.Call(GetSpellInfo, spellID)
  end
  if name == wingName then
    clip.t = Core.Now()
    clip.guid = TargetGUID()
  end
end)

Core.On("PLAYER_TARGET_CHANGED", "range", function()
  local g = TargetGUID()
  if not (g and clip.guid and g == clip.guid) then
    clip.t = nil
  end
  M.wasClipped = false
end)

-- Readout frame -------------------------------------------------------------------

local frame
local function Font(fs, size)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    T.EnsureFont(fs, size, "")
  else
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "")
  end
  if fs.SetShadowOffset then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.95)
  end
end

local function Theme()
  local A = Nock.Alerts
  return A and A:Theme() or nil
end

local CUE_H, CUE_ICON = 32, 22

-- 3.5.0: one slim plate under your character — icon, a few words, and a
-- 2 px Wing Clip timer along the bottom edge.
local function Make()
  if frame then
    return frame
  end
  local f = CreateFrame("Frame", "NockRangeFrame", UIParent)
  f:SetSize(260, CUE_H)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, -90)
  f:SetFrameStrata("MEDIUM")
  if f.EnableMouse then
    f:EnableMouse(false)
  end
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetPoint("TOPLEFT", 1, -1)
  f.bg:SetPoint("BOTTOMRIGHT", -1, 1)
  f.edges = {}
  for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local e = f:CreateTexture(nil, "BORDER")
    e:SetPoint(spec[1])
    e:SetPoint(spec[2])
    if spec[3] then e:SetHeight(1) else e:SetWidth(1) end
    f.edges[i] = e
  end
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(CUE_ICON, CUE_ICON)
  f.icon:SetPoint("LEFT", 6, 0)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.head = f:CreateFontString(nil, "OVERLAY")
  Font(f.head, 16)
  f.head:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
  f.head:SetJustifyH("LEFT")
  f.sub = f:CreateFontString(nil, "OVERLAY")
  Font(f.sub, 13)
  f.sub:SetPoint("LEFT", f.head, "RIGHT", 8, 0)
  f.sub:SetJustifyH("LEFT")
  f.bar = f:CreateTexture(nil, "OVERLAY")
  f.bar:SetPoint("BOTTOMLEFT", 1, 1)
  f.bar:SetHeight(2)
  f.barBg = f.bar -- 3.4 name kept for older code paths
  f:Hide()
  frame = f
  M.frame = f
  if Core.MakeMovable then
    Core.MakeMovable(f, "range", "Range / Wing Clip cue", { "CENTER", "CENTER", 0, -90 }, {
      preview = function(on)
        if on then
          M.Paint("Wing Clip, then step back", "warn", "rank 2", 6, "spell:Wing Clip")
        else
          f:Hide()
        end
      end,
    })
  end
  return f
end

local ICONS = { melee = "spell:Wing Clip", clip = "spell:Wing Clip", dead = "spell:Auto Shot", far = "spell:Auto Shot" }

function M.Paint(head, color, sub, clipLeft, icon)
  local f = Make()
  local th = Theme()
  local cue = th and th.cue or Core.COLORS
  local c = cue[color] or cue.warn
  local bgc = th and th.bgTop or { 0.06, 0.07, 0.06, 0.9 }
  local trim = th and th.trim or { 0.7, 0.65, 0.5, 0.8 }
  f.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], 0.78)
  for _, e in ipairs(f.edges) do
    e:SetColorTexture(trim[1], trim[2], trim[3], 0.55)
  end
  local tex = Nock.Alerts and Nock.Alerts.ResolveIcon(icon or "spell:Wing Clip") or nil
  f.icon:SetTexture(tex)
  f.head:SetText(head)
  f.head:SetTextColor(c[1], c[2], c[3])
  f.sub:SetText(sub or "")
  local sc = th and th.sub or { 0.7, 0.76, 0.72 }
  f.sub:SetTextColor(sc[1], sc[2], sc[3])
  local w = 6 + CUE_ICON + 8 + (tonumber((f.head:GetStringWidth())) or 160)
  if sub and sub ~= "" then
    w = w + 8 + (tonumber((f.sub:GetStringWidth())) or 60)
  end
  w = math.floor(math.max(160, w + 14) + 0.5)
  f:SetWidth(w)
  if clipLeft and clipLeft > 0 then
    local g = cue.good or c
    f.bar:SetColorTexture(g[1], g[2], g[3], 0.95)
    f.bar:SetWidth(math.max(1, (w - 2) * math.min(1, clipLeft / CLIP_DURATION)))
    f.bar:Show()
  else
    f.bar:Hide()
  end
  f:Show()
end

local function Show(head, color, sub, clipLeft, icon)
  M.Paint(head, color, sub, clipLeft, icon)
end

local function Hide()
  if Core.Unlocked and Core.Unlocked() then
    return
  end
  if frame then
    frame:Hide()
  end
end

-- Key bar glow --------------------------------------------------------------------

local glowing, timed = {}, {}
local function ClipCaps()
  local out = {}
  local ov = Nock.Overlay and Nock.Overlay()
  if not ov then
    return out
  end
  local lists = { ov.caps or {}, ov.utilCaps or {} }
  if ov.extra and ov.extra.caps then
    lists[#lists + 1] = ov.extra.caps
  end
  for _, list in ipairs(lists) do
    for _, cap in pairs(list) do
      local e = type(cap) == "table" and cap.entry
      local name = (cap.spellName and cap.spellName ~= "" and cap.spellName) or (e and e.name)
      if type(name) == "string" and name:find(wingName, 1, true) and (not cap.IsShown or cap:IsShown()) then
        out[#out + 1] = cap
      end
    end
  end
  return out
end
M.ClipCaps = ClipCaps

-- 3.8.0: a calm pulse, run by the game's animation system (no Lua per frame):
-- a soft warm ring breathing between 15% and 55% over 0.9 s.
local function MakePulse(cap)
  if cap.nockClipGlow or not cap.CreateTexture then
    return cap.nockClipGlow
  end
  local g = cap:CreateTexture(nil, "OVERLAY")
  g:SetPoint("TOPLEFT", -6, 6)
  g:SetPoint("BOTTOMRIGHT", 6, -6)
  g:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  if g.SetBlendMode then
    g:SetBlendMode("ADD")
  end
  g:SetVertexColor(1, 0.82, 0.45)
  g:SetAlpha(0.15)
  g:Hide()
  if g.CreateAnimationGroup then
    local ag = g:CreateAnimationGroup()
    if ag.SetLooping then
      ag:SetLooping("BOUNCE")
    end
    local a = ag.CreateAnimation and ag:CreateAnimation("Alpha")
    if a then
      if a.SetFromAlpha then a:SetFromAlpha(0.15) end
      if a.SetToAlpha then a:SetToAlpha(0.55) end
      if a.SetDuration then a:SetDuration(0.9) end
      if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
    end
    g.anim = ag
  end
  cap.nockClipGlow = g
  return g
end

local function MakeTimer(cap)
  if cap.nockClipTime or not cap.CreateFontString then
    return cap.nockClipTime
  end
  local fs = cap:CreateFontString(nil, "OVERLAY")
  Font(fs, 11)
  if fs.SetDrawLayer then
    fs:SetDrawLayer("OVERLAY", 7)
  end
  fs:SetPoint("BOTTOMLEFT", cap.icon or cap, "BOTTOMLEFT", 3, 2)
  fs:SetTextColor(0.62, 0.86, 0.66)
  fs:Hide()
  cap.nockClipTime = fs
  return fs
end

local function SetGlow(on)
  if Core.Get("range", "glow") == false then
    on = false
  end
  if on then
    for _, cap in ipairs(ClipCaps()) do
      local g = MakePulse(cap)
      if g and not glowing[cap] then
        g:Show()
        if g.anim then
          g.anim:Play()
        else
          g:SetAlpha(0.4)
        end
        glowing[cap] = true
      end
    end
  else
    for cap in pairs(glowing) do
      local g = cap.nockClipGlow
      if g then
        if g.anim then
          g.anim:Stop()
        end
        g:Hide()
      end
      glowing[cap] = nil
    end
  end
end
M.SetGlow = SetGlow

-- The slow's seconds left, small and muted in the button's corner.
local function SetTimer(left)
  if left and left > 0 then
    for _, cap in ipairs(ClipCaps()) do
      local fs = MakeTimer(cap)
      if fs then
        fs:SetText(string.format("%d", math.ceil(left)))
        fs:Show()
        timed[cap] = true
      end
    end
  else
    for cap in pairs(timed) do
      if cap.nockClipTime then
        cap.nockClipTime:Hide()
      end
      timed[cap] = nil
    end
  end
end
M.SetTimer = SetTimer

-- Main tick -----------------------------------------------------------------------

local lastZone, lastMeleeT, lastFlash = nil, nil, 0

local function Quiet()
  if Core.PvPMode() then
    return false
  end
  local ctx = Core.P.context
  return Core.Get("range", "quietGroup") ~= false and (ctx == "dungeon" or ctx == "raidinstance")
end

function M.Update()
  if not Core.HasHostileTarget() then
    if lastZone ~= "none" then
      Hide()
      SetGlow(false)
      SetTimer(nil)
      lastZone = "none"
    end
    return
  end
  local now = Core.Now()
  local melee = FirstReading(MELEE_SPELLS)
  local ranged = FirstReading(RANGED_SPELLS)
  local close = (melee == nil) and Close() or nil
  if melee == true then
    lastMeleeT = now
  end
  local zone = M.Classify(melee, ranged, close, lastMeleeT and (now - lastMeleeT) or nil)
  local combat = Core.InCombat()
  local left, src = M.ClipRemaining(now)
  local clipped = left and left > 0
  local knowsClip = Core.Knows("Wing Clip")
  local wantClip = false

  -- Wing Clip fell off while still in melee.
  if M.wasClipped and not clipped and zone == "melee" and Core.Get("range", "falloff") ~= false and Core.Throttle("range:falloff", 4) then
    Nock.Alerts:Fire("range.clipoff")
  end
  M.wasClipped = clipped and zone ~= "ok"

  local showIt = Core.Get("range", "indicator") ~= false
  if zone == "melee" then
    if knowsClip and Core.Get("range", "wingclip") ~= false then
      if clipped then
        Show("Step back", "good", string.format("Wing Clip %ds%s", math.ceil(left), src == "cast" and "*" or ""), left, ICONS.clip)
      else
        wantClip = true
        local r = Core.Rank("Wing Clip")
        local note = Core.Leans("survival") and "may root" or nil
        Show("Wing Clip, then step back", "warn", note or (r > 1 and ("rank " .. r) or nil), nil, ICONS.melee)
      end
    elseif showIt then
      Show("Melee range", "warn", "Raptor Strike, then step back", nil, "spell:Raptor Strike")
    end
  elseif zone == "deadzone" and showIt then
    Show("Dead zone", "bad", clipped and string.format("step back · Wing Clip %ds", math.ceil(left)) or "step back", clipped and left or nil, ICONS.dead)
  elseif zone == "far" and showIt and combat and Core.Get("range", "far") ~= false then
    Show("Out of range", "info", nil, nil, ICONS.far)
  else
    Hide()
  end

  if zone == "deadzone" and lastZone ~= "deadzone" and Core.PvPMode() then
    Nock.Alerts:Fire("range.deadzone")
  end
  if zone == "deadzone" and Core.Get("range", "flash") ~= false and not Quiet() then
    local again = Core.PvPMode() and 3 or (Core.Leans("marks") and 4 or 999)
    if lastZone ~= "deadzone" or now - lastFlash > again then
      lastFlash = now
      Core.Flash(0.95, 0.45, 0.15, 0.6)
    end
  end
  -- 3.8.0: the Wing Clip button pulses softly while a clip is wanted (melee
  -- or the dead zone, target not slowed); once slowed it shows the time left.
  local slowLeft = M.SlowRemaining(now)
  local st = M.ClipButtonState(true, zone, slowLeft, knowsClip, Core.Get("range", "glow"))
  M.lastState = st
  SetGlow(st.pulse)
  SetTimer(st.timer)
  lastZone = zone
end

function M:Init()
  Make()
  local _, _, name = Core.Call(Nock.PlayerKnows, "Wing Clip")
  if type(name) == "string" and name ~= "" then
    wingName = name
  end
end

function M:Refresh()
  if not Core.Enabled("range") then
    Hide()
    SetGlow(false)
    SetTimer(nil)
  end
end

-- 10 checks a second only with a hostile target; otherwise the tick is a no-op.
Core.Every("range", 0.1, function()
  M.Update()
end)

function M:Slash(rest)
  if rest == "test" then
    Show("Wing Clip, then step back", "warn", "test", 6, ICONS.melee)
    if C_Timer and C_Timer.After then
      C_Timer.After(3, Hide)
    end
    return
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local r = Core.Rank("Wing Clip")
  local out = {}
  out[#out + 1] = r > 0 and string.format("Wing Clip rank %d known. In melee: Wing Clip, then step back out to 8 yards.", r)
    or "Wing Clip comes at level 12. Until then: Raptor Strike and step back."
  if Core.Leans("survival") then
    out[#out + 1] = "Survival: Improved Wing Clip gives Wing Clip a chance to root — clip first, then walk out."
  end
  out[#out + 1] = "Readout: MELEE / DEAD ZONE (inside 8 yd) / TOO FAR. A * after the Wing Clip timer means it is estimated from your cast."
  return out
end
