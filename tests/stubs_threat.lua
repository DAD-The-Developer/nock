-- Minimal WoW stubs for the Nock threat meter tests (Lua 5.1).

local function obj(kind, name)
  local self = { _kind = kind or "Frame", _name = name, _shown = false, _points = {},
                 _w = 0, _h = 0, _texts = {}, _scripts = {}, _alpha = 1, _level = 1 }
  local textures, fonts = {}, {}
  local function tex()
    local t = {
      _w = 0, _h = 0, _shown = true, _points = {}, _color = {0,0,0,1}, _v = {1,1,1,1},
    }
    function t:SetAllPoints() end
    function t:SetPoint(point, a, b, c, d)
      self._points = self._points -- keep parent
      t._points[#t._points + 1] = { point, a, b, c, d }
    end
    function t:ClearAllPoints() t._points = {} end
    function t:SetSize(w, h) t._w, t._h = w, h end
    function t:SetWidth(w) t._w = w end
    function t:SetHeight(h) t._h = h end
    function t:GetWidth() return t._w end
    function t:GetHeight() return t._h end
    function t:SetTexture(path) t._path = path; return true end
    function t:SetColorTexture(r,g,b,a) t._color = {r,g,b,a} end
    function t:SetVertexColor(r,g,b,a) t._v = {r,g,b,a or 1} end
    function t:SetTexCoord() end
    function t:SetDrawLayer() end
    function t:Show() t._shown = true end
    function t:Hide() t._shown = false end
    function t:GetParent() return self end
    textures[#textures + 1] = t
    return t
  end
  local function fs()
    local f = { _text = "", _font = true, _w = 0 }
    function f:SetFont(path, size, flags) f._font, f._size, f._flags = path, size, flags; return true end
    function f:SetText(v) f._text = v or "" end
    function f:GetText() return f._text end
    function f:Show() f._shown = true end
    function f:Hide() f._shown = false end
    function f:SetTextColor(r,g,b,a) f._color = {r,g,b,a} end
    function f:SetPoint(point, a, b, c, d) f._points = f._points or {}; f._points[#f._points+1] = {point,a,b,c,d} end
    function f:ClearAllPoints() f._points = {} end
    function f:SetWidth(w) f._w = w end
    function f:SetJustifyH(h) f._justify = h end
  function f:SetJustifyV(v) f._justifyV = v end
  function f:SetHeight(h) f._h = h end
  function f:GetJustifyH() return f._justify end
    function f:SetDrawLayer() end
    fonts[#fonts + 1] = f
    return f
  end
  local mt = {}
  function mt:SetSize(w,h) self._w, self._h = w, h end
  function mt:SetWidth(w) self._w = w end
  function mt:SetHeight(h) self._h = h end
  function mt:GetWidth() return self._w end
  function mt:GetHeight() return self._h end
  function mt:SetPoint(point, a, b, c, d)
    self._points[#self._points + 1] = { point, a, b, c, d }
    if point == "CENTER" and type(a) == "table" and a.GetCenter then
      local rx, ry = a:GetCenter()
      local ox, oy
      if type(b) == "string" then
        ox, oy = c or 0, d or 0
      else
        ox, oy = b or 0, c or 0
      end
      if rx then
        self._cx, self._cy = rx + ox, ry + oy
      end
    end
  end
  function mt:GetPoint(i)
    local p = self._points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
  end
  function mt:ClearAllPoints() self._points = {} end
  function mt:SetParent(p) self._parent = p end
  function mt:GetParent() return self._parent or self end
  function mt:Show() self._shown = true end
  function mt:Hide() self._shown = false end
  function mt:IsShown() return self._shown and true or false end
  function mt:SetFrameStrata() end
  function mt:SetFrameLevel(n) self._level = n end
  function mt:GetFrameLevel() return self._level or 1 end
  function mt:EnableMouse(v) self._mouse = v and true or false end
  function mt:SetMovable(v) self._movable = v and true or false end
  function mt:RegisterForDrag() self._drag = true end
  function mt:StartMoving() self._moving = true end
  function mt:StopMovingOrSizing() self._moving = false end
  function mt:GetEffectiveScale() return self._scale or 1 end
  function mt:SetAllPoints() end
  function mt:GetCenter()
    if self._cx then return self._cx, self._cy end
    return nil
  end
  function mt:SetClampedToScreen() end
  function mt:RegisterEvent(e)
    _G.REGISTERED = _G.REGISTERED or {}
    _G.REGISTERED[e] = true
  end
  function mt:RegisterUnitEvent(e, unit)
    _G.REGISTERED_UNITS = _G.REGISTERED_UNITS or {}
    _G.REGISTERED_UNITS[e] = _G.REGISTERED_UNITS[e] or {}
    _G.REGISTERED_UNITS[e][unit] = true
  end
  function mt:SetScript(name, fn) self._scripts[name] = fn end
  function mt:GetScript(name) return self._scripts[name] end
  function mt:CreateTexture() return tex() end
  function mt:CreateFontString() return fs() end
  function mt:GetName() return self._name end
  setmetatable(self, { __index = mt })
  return self
end

FRAMES = {}
REGISTERED = {}
function CreateFrame(kind, name, parent)
  local f = obj(kind, name)
  if name then _G[name] = f end
  FRAMES[#FRAMES + 1] = f
  return f
end

UIParent = obj("Frame", "UIParent")
UIParent._cx, UIParent._cy = 960, 540
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

INCOMBAT = false
function InCombatLockdown() return INCOMBAT end

UNIT_EXISTS = { player = true }
UNIT_NAMES = { player = "TestHunter" }
UNIT_GUIDS = { player = "Player-1-0001", target = "Creature-1-0002", pet = "Pet-1-0003", pettarget = "Creature-1-0002" }
UNIT_CAN_ATTACK = {}
THREAT = {} -- [unit][mob] = { isTanking, status, scaled, raw, value }
THREAT_SECRET = {}
issecretvalue = function(v)
  return type(v) == "table" and v.__secret == true
end

C_Secrets = {
  ShouldUnitThreatValuesBeSecret = function(unit, mob)
    return THREAT_SECRET[unit] and true or false
  end,
  ShouldUnitThreatStateBeSecret = function() return false end,
}

function UnitExists(u) return UNIT_EXISTS[u] and true or false end
function UnitName(u) return UNIT_NAMES[u] end
function UnitGUID(u) return UNIT_GUIDS[u] end
function UnitCanAttack(a, b) return UNIT_CAN_ATTACK[b] and true or false end

function UnitDetailedThreatSituation(unit, mob)
  local recs = THREAT[unit]
  if not recs then return nil end
  -- accept unit token or guid
  local rec = recs[mob]
  if not rec then
    for k, v in pairs(recs) do
      if UNIT_GUIDS[k] == mob or k == mob then rec = v break end
    end
  end
  if not rec then return nil end
  return rec[1], rec[2], rec[3], rec[4], rec[5]
end

SITUATION = SITUATION or {}  -- [unit][mob] = status
LEAD_PCT = LEAD_PCT or {}    -- [unit][mob] = percent

function UnitThreatSituation(unit, mob)
  local recs = SITUATION[unit]
  if not recs then return nil end
  return recs[mob]
end

function UnitThreatPercentageOfLead(unit, mob)
  local recs = LEAD_PCT[unit]
  if not recs then return nil end
  return recs[mob]
end

CHAT_LOG = {}
DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, msg)
    CHAT_LOG[#CHAT_LOG + 1] = msg
  end,
}

NockCharDB = {}
NockDB = {}
Nock = {
  BarSize = function() return "large" end,
  Overlay = function()
    if not _G._overlay then
      local bow = obj("Texture", "bow")
      function bow:GetParent() return _G._overlay end
      local body = obj("Frame", "body")
      body:SetWidth(505)
      body:SetHeight(84)
      body._cx, body._cy = 960, 400
      bow:SetHeight(104)
      _G._overlay = { bow = bow, body = body }
    end
    return _G._overlay
  end,
  inCombatFlag = false,
  Print = function(msg) CHAT_LOG[#CHAT_LOG + 1] = msg end,
}
_G.Nock = Nock

NockTheme = {
  EnsureFont = function(fs, size, flags)
    if fs and fs.SetFont then fs:SetFont("Fonts\\FRIZQT__.TTF", type(size)=="number" and size or 16, flags or "THICKOUTLINE") end
    return true
  end,
  SetTex = function(tex, key, r, g, b, a)
    if tex and tex.SetTexture then tex:SetTexture("Interface\\AddOns\\Nock\\Media\\Textures\\"..tostring(key)..".tga") end
    if tex and tex.SetVertexColor and r then tex:SetVertexColor(r,g,b,a or 1) end
    return true
  end,
}
