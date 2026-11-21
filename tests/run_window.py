#!/usr/bin/env python3
"""3.5.0: build the main window on a fresh install and open every tab at
every bar size. Checks the layout grid: tabs fit inside the frame, page
buttons live in the action bar row, header/content/action/tab regions do
not overlap. Frames get a lenient fallback for widget methods the stubs
do not model."""
import sys
from pathlib import Path
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

ROOT = Path("/workspace/nock/Nock")
TESTS = Path("/workspace/nock/tests")
toc = (ROOT / "Nock.toc").read_text()
files = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
stubs = (TESTS / "stubs_threat.lua").read_text()
stubs = stubs[:stubs.find("NockCharDB = {}")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(stubs)
lua.execute((TESTS / "stubs_fresh.lua").read_text())
lua.execute(r'''
local function lenient(o)
  if type(o) ~= "table" then return o end
  local m = getmetatable(o)
  if not m then m = {}; setmetatable(o, m) end
  if m.__nockLenient then return o end
  local old = m.__index
  m.__index = function(t, k)
    local v
    if type(old) == "table" then v = old[k] elseif type(old) == "function" then v = old(t, k) end
    if v ~= nil then return v end
    local verb = false
    if type(k) == "string" then
      for _, pre in ipairs({ "Set", "Get", "Is", "Enable", "Disable", "Register", "Unregister", "Hook", "Clear", "Show", "Hide", "Raise", "Lower", "Start", "Stop", "Add", "Play", "Create", "Can", "Has", "Lock", "Unlock", "Update", "Scroll", "Click", "Adjust" }) do
        if k:sub(1, #pre) == pre then verb = true break end
      end
    end
    if verb then
      if k:match("^Create") then return function() return lenient({}) end end
      if k == "GetStringWidth" then return function(self) return #(tostring(self._text or "")) * 8 end end
      if k == "GetStringHeight" then return function() return 16 end end
      if k == "GetWidth" then return function(self) return self._w or 100 end end
      if k == "GetHeight" then return function(self) return self._h or 20 end end
      if k == "SetWidth" then return function(self, w) self._w = w end end
      if k == "SetHeight" then return function(self, h) self._h = h end end
      if k == "SetSize" then return function(self, w, h) self._w, self._h = w, h end end
      if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
      if k == "SetText" then return function(self, s) self._text = s end end
      if k == "GetText" then return function(self) return self._text end end
      if k == "IsShown" then return function(self) return self._shown ~= false end end
      if k == "GetParent" then return function(self) return self._parent end end
      return function() end
    end
  end
  m.__nockLenient = true
  return o
end
LENIENT = lenient
local orig = CreateFrame
function CreateFrame(kind, name, parent, ...)
  local f = orig(kind, name, parent, ...)
  lenient(f)
  rawset(f, "_parent", parent)
  local ct, cf = f.CreateTexture, f.CreateFontString
  rawset(f, "CreateTexture", function(self, ...) return lenient(ct(self, ...) or {}) end)
  rawset(f, "CreateFontString", function(self, ...) return lenient(cf(self, ...) or {}) end)
  return f
end
lenient(UIParent)
UIParent.GetWidth = function() return 1920 end
UIParent.GetHeight = function() return 1080 end
UISpecialFrames = UISpecialFrames or {}
tinsert = tinsert or table.insert
''')
for name in files:
    try:
        lua.globals()._SRC = (ROOT / name).read_text()
        lua.execute('assert(loadstring(_SRC, "' + name + '"))("Nock")')
    except Exception as e:
        sys.exit("LOAD ERROR " + name + ": " + str(e))
res = lua.execute(r'''
for _, f in ipairs(FRAMES or {}) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "ADDON_LOADED", "Nock") end end
for _, f in ipairs(FRAMES or {}) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, "PLAYER_LOGIN") end end
local UI = Nock.UI
local out, fails = {}, 0
local function check(c, msg) if not c then fails = fails + 1; out[#out + 1] = "FAIL " .. msg else out[#out + 1] = "ok   " .. msg end end
local tabs = { "myrot", "talents", "profiles", "rotation", "macros", "manual", "kit", "options" }
for _, size in ipairs({ "small", "normal", "large" }) do
  NockCharDB.barSize = size
  if Nock.BarSize then local old = Nock.BarSize; Nock.BarSize = function() return size end end
  for _, view in ipairs({ "simple", "advanced" }) do
    NockCharDB.view = view
    for _, key in ipairs(tabs) do
      local ok, err = pcall(Nock.ShowPanel, key)
      if not ok then check(false, size .. "/" .. view .. "/" .. key .. ": " .. tostring(err)) end
      local okR, errR = pcall(UI.ApplyWindowSize)
      if not okR then check(false, "ApplyWindowSize " .. size .. ": " .. tostring(errR)) end
    end
    local m = UI.metrics
    local sum, n = 0, 0
    for _, t in ipairs(UI.tabs) do
      if t:IsShown() then sum = sum + (t._w or 0) + 4; n = n + 1 end
    end
    check(sum - 4 <= m.w - 2 * UI.GRID.gutter, string.format("%s/%s: %d tabs fit (%d of %d px)", size, view, n, sum - 4, m.w - 2 * UI.GRID.gutter))
    check(m.attic + 200 < m.h - m.bottom, size .. ": content area keeps real height")
    check(m.barY >= m.tabY + m.tabH and m.bottom >= m.barY + m.barH, size .. ": action bar sits between tabs and content")
  end
end
local frame = UI.frame
check(frame and frame.actionBar, "action bar region exists")
local okParent, nb = true, 0
for key, page in pairs(UI.pages) do
  for _, b in ipairs(page.buttons or {}) do
    nb = nb + 1
    if rawget(b, "_parent") ~= frame.actionBar then okParent = false end
  end
end
check(okParent and nb >= 9, "every page button is in the action bar (" .. nb .. ")")
for id, e in pairs((Nock.Core and Nock.Core.errors) or {}) do check(false, "module error " .. id .. ": " .. e) end
print(table.concat(out, "\n"))
return fails
''')
if res:
    sys.exit(str(res) + " window checks failed")
print("WINDOW_TEST_OK")
