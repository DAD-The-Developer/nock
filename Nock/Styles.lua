--[[
  Nock 3.1.0: HUD style (Emerald or Gunsmith).

  Art and accent colors only. Layout, spacing and behavior stay the same.
  The chosen style is saved per character and can be changed live
  (/nock style, the Style picker, or a keybind) without a /reload.
  New .tga files still need a full client restart the first time they are
  installed.
]]

local T = _G.NockTheme
if not T then
  return
end

local MEDIA = T.MEDIA or "Interface\\AddOns\\Nock\\Media\\"
local TEX = T.TEX or (MEDIA .. "Textures\\")
local GUN = TEX .. "gun\\"

-- Snapshot of the shipped Emerald paths, taken once at load.
local EMERALD_TEX = {}
for k, v in pairs(T.tex or {}) do
  EMERALD_TEX[k] = v
end

local EMERALD_COLOR = {
  silver = { 0.75, 0.89, 0.81 },
  trim = { 0.50, 0.66, 0.60 },
  emerald = { 0.25, 0.89, 0.60 },
  glow = { 0.30, 1.00, 0.62 },
  key = { 0.79, 1.00, 0.88 },
  text = { 0.92, 0.97, 0.94 },
  sub = { 0.61, 0.77, 0.69 },
  wood = { 0.07, 0.12, 0.10 },
  mist = { 0.06, 0.16, 0.13 },
  bad = { 1.00, 0.30, 0.25 },
  brass = { 0.78, 0.70, 0.38 },
}
local EMERALD_HEX = {
  key = "|cffc9ffe1",
  emerald = "|cff40e39a",
  sub = "|cff9cc4b1",
  silver = "|cffbfe3cf",
}

-- Gunsmith fire / brass palette. Gameplay red stays red so pull warnings
-- are still obvious.
local GUN_COLOR = {
  silver = { 0.90, 0.74, 0.42 },
  trim = { 0.62, 0.45, 0.22 },
  emerald = { 0.95, 0.48, 0.10 }, -- fire-orange in the "accent" slot
  glow = { 1.00, 0.58, 0.14 },
  key = { 1.00, 0.92, 0.75 },
  text = { 0.98, 0.94, 0.86 },
  sub = { 0.78, 0.66, 0.48 },
  wood = { 0.10, 0.07, 0.04 },
  mist = { 0.10, 0.07, 0.04 },
  bad = { 1.00, 0.30, 0.25 },
  brass = { 0.90, 0.72, 0.32 },
}
local GUN_HEX = {
  key = "|cffffeac0",
  emerald = "|cfff27a1a",
  sub = "|cffc7a87a",
  silver = "|cffe6bc6b",
}

-- Default XP / cap UVs (Emerald 3.0.5 packing).
local EMERALD_XP = {
  winL = 0.071495, winR = 0.928505,
  winT = 0.431788, winB = 0.636059,
  fillT = 0.398361, fillB = 0.665771,
  fillU = 0.901367, fillV = 0.562500,
  restU = 0.901367, restV = 0.578125,
}
local EMERALD_CAP = {
  fletch = { 2 / 1024, 1019 / 1024, 5 / 512, 505 / 512 },
  head = { 4 / 1024, 851 / 1024, 3 / 512, 509 / 512 },
}

-- Measured from the packed Gunsmith TGAs (art/png-gun/uv.json).
local GUN_XP = {
  winL = 0.21728515625, winR = 0.78271484375,
  winT = 0.16796875, winB = 0.65234375,
  fillT = 0.14453125, fillB = 0.67578125,
  fillU = 1.0, fillV = 0.546875,
  restU = 1.0, restV = 0.546875,
}
local GUN_CAP = {
  fletch = { 0.509765625, 0.99609375, 0.01171875, 0.98828125 },
  head = { 0.00390625, 0.4921875, 0.01171875, 0.98828125 },
}

-- Tint applied when SetTex is used on these keys (XP fill etc.).
local EMERALD_TINT = {
  xp_fill = { 0.20, 0.72, 0.45, 1 },
  xp_rested = { 0.45, 0.95, 0.70, 1 },
  xp_frame = { 0.18, 0.11, 0.06, 1 },
  xp_badge = { 0.18, 0.11, 0.06, 1 },
  xp_spark = { 0.6, 1, 0.5, 1 },
  barwood = { 0.16, 0.10, 0.05, 0.96 },
}
local GUN_TINT = {
  -- Let the fire and silver art show through; only a light warm multiply.
  xp_fill = { 1.00, 0.92, 0.80, 1 },
  xp_rested = { 0.85, 0.92, 1.00, 1 },
  xp_frame = { 1, 1, 1, 1 },
  xp_badge = { 1, 1, 1, 1 },
  xp_spark = { 1, 1, 1, 1 },
  barwood = { 0.22, 0.14, 0.08, 0.96 },
}

local EMERALD_THREAT = {
  safe = { 0.22, 0.85, 0.50 },
  amber = { 0.95, 0.68, 0.16 },
  red = { 0.92, 0.22, 0.18 },
  cream = { 1.00, 0.98, 0.82 },
  gold = { 0.78, 0.70, 0.38 },
}
local GUN_THREAT = {
  safe = { 0.90, 0.68, 0.22 }, -- brass / ember: pet has aggro
  amber = { 1.00, 0.50, 0.10 },
  red = { 0.92, 0.22, 0.18 },
  cream = { 1.00, 0.95, 0.82 },
  gold = { 0.90, 0.72, 0.32 },
}

-- Filenames in Media/Textures/gun/ for every themed key.
local GUN_FILE = {
  bow = "bow.tga",
  fletch = "cap_fletch.tga",
  head = "cap_head.tga",
  bar = "bar.tga",
  keybadge = "keybadge.tga",
  paw = "paw.tga",
  reticle = "reticle.tga",
  map = "map.tga",
  mist = "mist.tga",
  vine = "vine.tga",
  crest = "crest.tga",
  moon = "moon.tga",
  header = "header.tga",
  divider_v = "divider_v.tga",
  tile = "tile.tga",
  glow = "glow.tga",
  token = "token.tga",
  badge = "badge.tga",
  divider = "divider.tga",
  corner = "corner.tga",
  edge = "edge.tga",
  edge_v = "edge_v.tga",
  ornament = "edge_ornament.tga",
  ornamentWide = "edge_ornament512.tga",
  bg = "bg.tga",
  title = "title.tga",
  close = "close.tga",
  closeHover = "close_hover.tga",
  barwood = "barwood.tga",
  xp_frame = "xp_frame.tga",
  xp_bg = "xp_bg.tga",
  xp_fill = "xp_fill.tga",
  xp_rested = "xp_rested.tga",
  xp_ticks = "xp_ticks.tga",
  xp_spark = "xp_spark.tga",
  xp_badge = "xp_badge.tga",
}

local STYLES = {
  emerald = {
    id = "emerald",
    name = "Emerald",
    color = EMERALD_COLOR,
    hex = EMERALD_HEX,
    xp = EMERALD_XP,
    cap = EMERALD_CAP,
    tint = EMERALD_TINT,
    threat = EMERALD_THREAT,
  },
  gunsmith = {
    id = "gunsmith",
    name = "Gunsmith",
    color = GUN_COLOR,
    hex = GUN_HEX,
    xp = GUN_XP,
    cap = GUN_CAP,
    tint = GUN_TINT,
    threat = GUN_THREAT,
  },
}

local ALIAS = {
  emerald = "emerald", dream = "emerald", bow = "emerald", rhok = "emerald",
  gunsmith = "gunsmith", gun = "gunsmith", rifle = "gunsmith", guns = "gunsmith",
  dwarven = "gunsmith",
}

local applied = {}
local currentId = "emerald"
local pendingStyle

local function DB()
  _G.NockCharDB = _G.NockCharDB or {}
  return _G.NockCharDB
end

local function InCombat()
  local Nock = _G.Nock
  if Nock and Nock.inCombatFlag then
    return true
  end
  if InCombatLockdown then
    return InCombatLockdown() and true or false
  end
  return false
end

function T.NormalizeStyle(id)
  if type(id) ~= "string" then
    return "emerald"
  end
  id = string.lower(id)
  return ALIAS[id] or (STYLES[id] and id) or "emerald"
end

function T.StyleId()
  return currentId
end

function T.Style()
  return STYLES[currentId] or STYLES.emerald
end

function T.StyleName()
  return T.Style().name
end

function T.XP()
  return T.Style().xp or EMERALD_XP
end

function T.CapUV(which)
  local cap = T.Style().cap or EMERALD_CAP
  return cap[which]
end

function T.FillTint(key)
  local t = T.Style().tint
  return t and t[key] or nil
end

function T.ThreatColors()
  return T.Style().threat or EMERALD_THREAT
end

-- Theme.SetTex is wrapped below so we can re-apply paths after a swap.
local origSetTex = T.SetTex
function T.SetTex(tex, key, r, g, b, a)
  if tex then
    tex._nockTexKey = key
    tex._nockTexColor = { r, g, b, a }
    if not tex._nockTexReg then
      tex._nockTexReg = true
      applied[#applied + 1] = tex
    end
    local tint = T.FillTint(key)
    if tint and (r == nil) then
      r, g, b, a = tint[1], tint[2], tint[3], tint[4]
    end
  end
  return origSetTex(tex, key, r, g, b, a)
end

local function CopyColors(dst, src)
  for k, v in pairs(src) do
    dst[k] = v
  end
end

local function ApplyPaths(id)
  -- Always restore Emerald, then overlay Gunsmith so a missing gun
  -- file would still have a path (the gun files all ship together).
  for k, v in pairs(EMERALD_TEX) do
    T.tex[k] = v
  end
  if id == "gunsmith" then
    for k, file in pairs(GUN_FILE) do
      T.tex[k] = GUN .. file
    end
  end
end

local function RefreshTextures()
  for _, tex in ipairs(applied) do
    if tex and tex._nockTexKey then
      local c = tex._nockTexColor or {}
      origSetTex(tex, tex._nockTexKey, c[1], c[2], c[3], c[4])
      local tint = T.FillTint(tex._nockTexKey)
      if tint and tex.SetVertexColor then
        pcall(tex.SetVertexColor, tex, tint[1], tint[2], tint[3], tint[4] or 1)
      end
    end
  end
end

local function RefreshHUD()
  RefreshTextures()
  local Nock = _G.Nock
  if Nock and Nock.UpdateOverlay then
    pcall(Nock.UpdateOverlay)
  end
  if Nock and Nock.Threat and Nock.Threat.Restyle then
    pcall(Nock.Threat.Restyle)
  elseif Nock and Nock.Threat and Nock.Threat.Layout then
    pcall(Nock.Threat.Layout)
  end
  if Nock and Nock.ApplyStyleCrops then
    pcall(Nock.ApplyStyleCrops)
  end
  if Nock and Nock.RefreshUI then
    pcall(Nock.RefreshUI)
  end
  if Nock and Nock.UI and Nock.UI.RestyleChrome then
    pcall(Nock.UI.RestyleChrome)
  end
  if Nock and Nock.Launcher and Nock.Launcher.Restyle then
    pcall(Nock.Launcher.Restyle)
  end
  if Nock and Nock.Quiver and Nock.Quiver.Restyle then
    pcall(Nock.Quiver.Restyle)
  end
end

-- skipRefresh: used at file load, before the HUD exists.
function T.ApplyStyle(id, skipRefresh)
  id = T.NormalizeStyle(id)
  currentId = id
  local style = STYLES[id]
  ApplyPaths(id)
  if T.color then
    CopyColors(T.color, style.color)
  end
  if T.hex then
    CopyColors(T.hex, style.hex)
  end
  if not skipRefresh then
    RefreshHUD()
  end
  return id
end

function T.SetStyle(id)
  id = T.NormalizeStyle(id)
  if InCombat() then
    pendingStyle = id
    return id, "combat"
  end
  pendingStyle = nil
  DB().hudStyle = id
  T.ApplyStyle(id, false)
  return id, "ok"
end

function T.ToggleStyle()
  local nextId = (currentId == "gunsmith") and "emerald" or "gunsmith"
  return T.SetStyle(nextId)
end

function T.ApplyPendingStyle()
  if pendingStyle then
    local id = pendingStyle
    pendingStyle = nil
    return T.SetStyle(id)
  end
end

-- WoW loads this file BEFORE SavedVariablesPerCharacter. Applying a saved
-- style here would always see an empty table and fall back to Emerald, then
-- never re-read NockCharDB.hudStyle after ADDON_LOADED. Default to Emerald
-- art only; Nock.lua calls T.LoadSavedStyle() once the saved table is in.
T.ApplyStyle("emerald", true)

function T.LoadSavedStyle()
  local saved = _G.NockCharDB and _G.NockCharDB.hudStyle
  local id = T.NormalizeStyle(saved or "emerald")
  T.ApplyStyle(id, true)
  return id
end

function _G.Nock_ToggleStyle()
  local id, why = T.ToggleStyle()
  local Nock = _G.Nock
  local name = (STYLES[id] and STYLES[id].name) or id
  local msg
  if why == "combat" then
    msg = "Style will switch to " .. name .. " when the fight ends."
  else
    msg = "Style: " .. name .. "."
  end
  if Nock and Nock.Print then
    Nock.Print(msg)
  else
    local f = _G.DEFAULT_CHAT_FRAME
    if f and f.AddMessage then
      f:AddMessage("|cfff0e2b6Nock:|r " .. msg)
    end
  end
end

T.STYLES = STYLES
