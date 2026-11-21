--[[
  Nock 3.4.0 hunter tool: PvP (battlegrounds and arenas).

  In a battleground (or an arena, if the Forever client has them) Nock
  switches to PvP mode:
    * PvE nags step aside: pet feeding, the leveling route, the trainer
      reminder and the kill / XP tracker (each can be kept on).
    * Dead zone and Wing Clip cues get louder (repeat flashes, sounds).
    * A PvP readout over your character for an enemy player target:
        ENEMY MAGE  caster          Viper Sting
        Not slowed: Concussive / Wing Clip      (or "Slowed: Wing Clip 6s")
        Ice Block: immune — set a trap and wait
        Conc  Scatter 12s  Freeze  Frost  Clip  Feign 25s
    * Alerts when the target uses a PvP trinket or escape.
    * Low ammo warning when the queue pops (Supply warnings).
  Buffs and slows are read only when the client lets addons see auras;
  otherwise those lines stay empty rather than guess. Cooldowns use the
  spell cooldown API and hide when it is not readable.

  Scales by data: classes, matchup notes, buffs, slows, trinkets and your
  PvP tools are rows in Data_PvP.lua. Stings are only suggested once known.
]]

local Nock = _G.Nock
local Core = Nock and Nock.Core
if not Core then
  return
end

local M = Core.Register({
  id = "pvp",
  name = "PvP: target cues and readiness",
  desc = "In battlegrounds and arenas: enemy class and sting, slows, big enemy buffs, trinkets, your CC cooldowns.",
  cmd = { "pvp" },
  defaults = { on = true, readout = true, trinket = true, buffs = true, world = false },
  options = {
    { key = "readout", label = "Show the PvP readout for enemy player targets" },
    { key = "buffs", label = "Call out big enemy buffs (Ice Block, Divine Shield, Freedom ...)" },
    { key = "trinket", label = "Alert when the target uses a PvP trinket or escape" },
    { key = "world", label = "Also show the readout for enemy players outside battlegrounds" },
  },
  help = { "/nock pvp — PvP readout on or off   /nock pvp guide — PvP field notes   /nock tools pvp off — no PvP mode" },
})

local function D()
  return Nock.Data or {}
end

local function AurasSecret()
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
    if ok and Core.Flag(v) ~= false then
      return true
    end
  end
  return not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName)
end

-- Returns remaining seconds of an aura on the target (0 = none) or nil if unreadable.
local function AuraLeft(name, filter)
  local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", name, filter)
  if not ok then
    return nil
  end
  if type(data) ~= "table" then
    return 0
  end
  local exp = Core.Number(data.expirationTime)
  if exp and exp > 0 then
    return math.max(0.1, exp - Core.Now())
  end
  return 99
end

function M.EnemyPlayer()
  if not Core.HasHostileTarget() then
    return false
  end
  return Core.UnitFlag(UnitIsPlayer, "target") == true
end

-- What to show for a class (pure, tested): role, sting (if known), note.
function M.Advice(classFile, knows)
  local c = D().PvPClasses and D().PvPClasses[classFile]
  if not c then
    return nil
  end
  local sting = c.sting
  if sting and not knows(sting) then
    sting = knows("Serpent Sting") and "Serpent Sting" or nil
  end
  return c.role, sting, c.note
end

-- First slow on the target from a reader (pure, tested). reader(name) -> seconds or nil.
function M.FirstSlow(reader)
  local unknown = false
  for _, name in ipairs(D().PvPSlows or {}) do
    local left = reader(name)
    if left == nil then
      unknown = true
    elseif left > 0 then
      return name, left
    end
  end
  if unknown then
    return nil, nil
  end
  return false, 0
end

local function Cooldown(name)
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, name)
    if ok and type(info) == "table" then
      local s, d = Core.Number(info.startTime), Core.Number(info.duration)
      if s and d then
        if d <= 1.6 then
          return 0
        end
        return math.max(0, s + d - Core.Now())
      end
    end
    return nil
  end
  if GetSpellCooldown then
    local ok, s, d = pcall(GetSpellCooldown, name)
    s, d = ok and Core.Number(s), ok and Core.Number(d)
    if s and d then
      return d <= 1.6 and 0 or math.max(0, s + d - Core.Now())
    end
  end
  return nil
end

function M.ReadyLine()
  local parts = {}
  for _, row in ipairs(D().PvPTools or {}) do
    if Core.Knows(row[1]) then
      local cd = Cooldown(row[1])
      if cd == nil then
        parts[#parts + 1] = row[2]
      elseif cd <= 0 then
        parts[#parts + 1] = "|cff40e39a" .. row[2] .. "|r"
      else
        parts[#parts + 1] = string.format("|cff9a9a9a%s %ds|r", row[2], math.ceil(cd))
      end
    end
  end
  return table.concat(parts, "   ")
end

-- Readout ----------------------------------------------------------------------------

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
  local f = CreateFrame("Frame", "NockPvPFrame", UIParent)
  f:SetSize(520, 110)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 210)
  if f.EnableMouse then
    f:EnableMouse(false)
  end
  f.lines = {}
  local sizes = { 22, 16, 16, 15 }
  local prev
  for i = 1, 4 do
    local fs = f:CreateFontString(nil, "OVERLAY")
    Font(fs, sizes[i])
    if prev then
      fs:SetPoint("TOP", prev, "BOTTOM", 0, -4)
    else
      fs:SetPoint("TOP", 0, 0)
    end
    f.lines[i] = fs
    prev = fs
  end
  f:Hide()
  frame = f
  M.frame = f
  return f
end

local function WantReadout()
  if Core.Get("pvp", "readout") == false then
    return false
  end
  return Core.PvPMode() or Core.Get("pvp", "world") == true
end

function M.Update()
  if not (WantReadout() and M.EnemyPlayer()) then
    if frame then
      frame:Hide()
    end
    return
  end
  local f = Make()
  local name, classFile = Core.Call(UnitClass, "target")
  if Core.IsSecret(classFile) then
    classFile = nil
  end
  local role, sting = M.Advice(classFile, function(n) return Core.Knows(n) end)
  local cc = classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]
  f.lines[1]:SetText(string.format("ENEMY %s%s%s", type(name) == "string" and not Core.IsSecret(name) and name:upper() or "PLAYER",
    role and ("  ·  " .. role) or "", sting and ("  ·  " .. sting) or ""))
  if cc then
    f.lines[1]:SetTextColor(cc.r or 1, cc.g or 1, cc.b or 1)
  else
    f.lines[1]:SetTextColor(1, 0.35, 0.3)
  end
  -- Slows: Nock's own Wing Clip timer first (works when auras are hidden).
  local slowText
  local range = Core.Module("range")
  local clipLeft, src = 0, nil
  if range and range.ClipRemaining then
    clipLeft, src = range.ClipRemaining()
  end
  if clipLeft and clipLeft > 0 then
    slowText = string.format("|cff40e39aSlowed: Wing Clip %ds%s|r", math.ceil(clipLeft), src == "cast" and "*" or "")
  elseif not AurasSecret() then
    local slow, left = M.FirstSlow(function(n) return AuraLeft(n, "HARMFUL") end)
    if slow then
      slowText = string.format("|cff40e39aSlowed: %s%s|r", slow, left < 90 and string.format(" %ds", math.ceil(left)) or "")
    elseif slow == false then
      slowText = "|cffffcc33Not slowed: Concussive Shot / Wing Clip, step back|r"
    end
  end
  f.lines[2]:SetText(slowText or "")
  f.lines[2]:SetTextColor(0.92, 0.97, 0.94)
  local buffText = ""
  if Core.Get("pvp", "buffs") ~= false and not AurasSecret() then
    for buff, advice in pairs(D().PvPBuffs or {}) do
      local left = AuraLeft(buff, "HELPFUL")
      if left and left > 0 then
        buffText = string.format("|cffff7755%s|r: %s", buff, advice)
        break
      end
    end
  end
  f.lines[3]:SetText(buffText)
  f.lines[3]:SetTextColor(0.95, 0.9, 0.8)
  f.lines[4]:SetText(M.ReadyLine())
  f.lines[4]:SetTextColor(0.8, 0.85, 0.8)
  f:Show()
end

Core.Every("pvp", 0.25, function()
  M.Update()
end)

Core.On("UNIT_SPELLCAST_SUCCEEDED", "pvp", function(_, unit, _, spellID)
  if unit ~= "target" or Core.Get("pvp", "trinket") == false or not (Core.PvPMode() or Core.Get("pvp", "world") == true) then
    return
  end
  if not spellID or Core.IsSecret(spellID) or not M.EnemyPlayer() then
    return
  end
  local n = C_Spell and C_Spell.GetSpellName and Core.Call(C_Spell.GetSpellName, spellID)
  if type(n) == "string" and (D().PvPTrinkets or {})[n] then
    Core.Alert("Trinket: " .. n, { color = "warn", key = "pvptrinket", priority = 2,
      sub = "They broke free. Re-apply: Concussive, Scatter, trap.", sound = "soft", duration = 3 })
  end
end)

function M:Refresh()
  if frame and not Core.Enabled("pvp") then
    frame:Hide()
  end
end

function M:OnProfile(what)
  if what == "context" and Core.PvPMode() and Core.Throttle("pvp:enter", 30) then
    Core.Say(string.format("PvP mode%s: PvE nags off, dead zone and Wing Clip cues up. /nock pvp guide", Core.P.arena and " (arena)" or ""))
  end
end

function M.GuideLines()
  local out = {}
  for _, sec in ipairs(D().PvPGuide or {}) do
    out[#out + 1] = sec[1] .. ":"
    for _, line in ipairs(sec[2]) do
      out[#out + 1] = "  " .. line
    end
  end
  out[#out + 1] = "Class matchups:"
  local keys = {}
  for k in pairs(D().PvPClasses or {}) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local c = D().PvPClasses[k]
    out[#out + 1] = string.format("  %s (%s): %s", k:sub(1, 1) .. k:sub(2):lower(), c.role, c.note)
  end
  return out
end

function M:Slash(rest)
  if rest == "guide" or rest == "notes" then
    for _, line in ipairs(M.GuideLines()) do
      Core.Say(line)
    end
    return
  elseif rest == "readout" or rest == "world" or rest == "buffs" or rest == "trinket" then
    Core.Set("pvp", rest, not (Core.Get("pvp", rest) ~= false and Core.Get("pvp", rest) ~= nil))
    return Core.Say("PvP " .. rest .. ": " .. ((Core.Get("pvp", rest) and "on") or "off"))
  end
  for _, line in ipairs(M:Report()) do
    Core.Say(line)
  end
end

function M:Report()
  local out = {}
  out[#out + 1] = string.format("PvP mode: %s. Now: %s%s. Queue: %s.", Core.PvPSetting() and "automatic in battlegrounds and arenas" or "off",
    Core.PvPMode() and "PvP" or "not in PvP", Core.P.arena and " (arena)" or "", Core.P.queue or "none")
  local ready = M.ReadyLine()
  if ready ~= "" then
    out[#out + 1] = "Your tools: " .. ready:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  end
  if M.EnemyPlayer() then
    local _, classFile = Core.Call(UnitClass, "target")
    local role, sting, note = M.Advice(classFile, function(n) return Core.Knows(n) end)
    if note then
      out[#out + 1] = string.format("Target (%s): %s%s", role, sting and (sting .. ". ") or "", note)
    end
  end
  for _, line in ipairs(M.GuideLines()) do
    out[#out + 1] = line
  end
  return out
end
