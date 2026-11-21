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
    { key = "glow", label = "Make the Wing Clip key glow on Nock's bar when it is wanted" },
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
  return Core.Flag(r)
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
    T.EnsureFont(fs, size, "THICKOUTLINE")
  else
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "THICKOUTLINE")
  end
end

local function Make()
  if frame then
    return frame
  end
  local f = CreateFrame("Frame", "NockRangeFrame", UIParent)
  f:SetSize(420, 64)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, -90)
  f:SetFrameStrata("MEDIUM")
  if f.EnableMouse then
    f:EnableMouse(false)
  end
  f.head = f:CreateFontString(nil, "OVERLAY")
  Font(f.head, 26)
  f.head:SetPoint("TOP", 0, 0)
  f.sub = f:CreateFontString(nil, "OVERLAY")
  Font(f.sub, 16)
  f.sub:SetPoint("TOP", f.head, "BOTTOM", 0, -4)
  -- Wing Clip timer bar.
  f.barBg = f:CreateTexture(nil, "BACKGROUND")
  f.barBg:SetSize(180, 8)
  f.barBg:SetPoint("TOP", f.sub, "BOTTOM", 0, -6)
  f.barBg:SetColorTexture(0, 0, 0, 0.6)
  f.bar = f:CreateTexture(nil, "ARTWORK")
  f.bar:SetPoint("LEFT", f.barBg, "LEFT", 0, 0)
  f.bar:SetSize(180, 8)
  f.bar:SetColorTexture(0.30, 1.00, 0.55, 0.9)
  f:Hide()
  frame = f
  M.frame = f
  if Core.MakeMovable then
    Core.MakeMovable(f, "range", "Dead zone / Wing Clip readout", { "CENTER", "CENTER", 0, -90 }, {
      preview = function(on)
        if on then
          f.head:SetText("WING CLIP, then step back")
          f.head:SetTextColor(1, 0.8, 0.2)
          f.sub:SetText("Sample: the melee / dead zone readout")
          f:Show()
        else
          f:Hide()
        end
      end,
    })
  end
  return f
end

local function Show(head, color, sub, clipLeft)
  local f = Make()
  local c = Core.COLORS[color] or Core.COLORS.warn
  f.head:SetText(head)
  f.head:SetTextColor(c[1], c[2], c[3])
  f.sub:SetText(sub or "")
  f.sub:SetTextColor(0.92, 0.97, 0.94)
  if clipLeft and clipLeft > 0 then
    f.bar:SetWidth(math.max(1, 180 * math.min(1, clipLeft / CLIP_DURATION)))
    f.bar:Show()
    f.barBg:Show()
  else
    f.bar:Hide()
    f.barBg:Hide()
  end
  f:Show()
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

local glowing = {}
local function ClipCaps()
  local out = {}
  local ov = Nock.Overlay and Nock.Overlay()
  if not ov then
    return out
  end
  for _, list in ipairs({ ov.caps or {}, ov.utilCaps or {} }) do
    for _, cap in pairs(list) do
      local e = type(cap) == "table" and cap.entry
      local name = (cap.spellName and cap.spellName ~= "" and cap.spellName) or (e and e.name)
      if type(name) == "string" and name:find(wingName, 1, true) then
        out[#out + 1] = cap
      end
    end
  end
  return out
end

local function SetGlow(on)
  if Core.Get("range", "glow") == false then
    on = false
  end
  if on then
    for _, cap in ipairs(ClipCaps()) do
      if not cap.nockClipGlow and cap.CreateTexture then
        local g = cap:CreateTexture(nil, "OVERLAY")
        g:SetPoint("TOPLEFT", -6, 6)
        g:SetPoint("BOTTOMRIGHT", 6, -6)
        g:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        if g.SetBlendMode then
          g:SetBlendMode("ADD")
        end
        g:SetVertexColor(1, 0.8, 0.2)
        cap.nockClipGlow = g
      end
      if cap.nockClipGlow then
        local a = 0.55 + 0.45 * math.sin(Core.Now() * 8)
        cap.nockClipGlow:SetAlpha(a)
        cap.nockClipGlow:Show()
        glowing[cap] = true
      end
    end
  else
    for cap in pairs(glowing) do
      if cap.nockClipGlow then
        cap.nockClipGlow:Hide()
      end
      glowing[cap] = nil
    end
  end
end

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
    Hide()
    SetGlow(false)
    lastZone = nil
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
    Core.Alert("Wing Clip fell off", { color = "warn", key = "wingclip",
      sub = "It is still in melee: Wing Clip again, then step back.", sound = Core.PvPMode() and true or ((not Quiet()) and "soft" or nil),
      priority = Core.PvPMode() and 3 or 2, duration = 2.5 })
  end
  M.wasClipped = clipped and zone ~= "ok"

  local showIt = Core.Get("range", "indicator") ~= false
  if zone == "melee" then
    if knowsClip and Core.Get("range", "wingclip") ~= false then
      if clipped then
        Show("STEP BACK", "good", string.format("Wing Clip %ds%s — get out to 8 yards and shoot", math.ceil(left), src == "cast" and "*" or ""), left)
      else
        wantClip = true
        local r = Core.Rank("Wing Clip")
        local note = Core.Leans("survival") and "  (Improved Wing Clip can root)" or ""
        Show("WING CLIP, then step back", "warn", (r > 1 and ("Rank " .. r) or "Not slowed") .. note)
      end
    elseif showIt then
      Show("MELEE", "warn", "Raptor Strike, then step back out to 8 yards")
    end
  elseif zone == "deadzone" and showIt then
    Show("DEAD ZONE", "bad", clipped and string.format("Step back — Wing Clip %ds", math.ceil(left)) or "Too close to shoot: step back", clipped and left or nil)
  elseif zone == "far" and showIt and combat and Core.Get("range", "far") ~= false then
    Show("TOO FAR", "info", "Move in to shoot")
  else
    Hide()
  end

  if zone == "deadzone" and Core.Get("range", "flash") ~= false and not Quiet() then
    local again = Core.PvPMode() and 2 or (Core.Leans("marks") and 3 or 999)
    if lastZone ~= "deadzone" or now - lastFlash > again then
      lastFlash = now
      Core.Flash(1, 0.45, 0.1, 0.7)
    end
  end
  SetGlow(wantClip)
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
  end
end

-- 10 checks a second only with a hostile target; otherwise the tick is a no-op.
Core.Every("range", 0.1, function()
  M.Update()
end)

function M:Slash(rest)
  if rest == "test" then
    Show("WING CLIP, then step back", "warn", "Test: this is where the readout sits")
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
