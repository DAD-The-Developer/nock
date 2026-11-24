#!/usr/bin/env python3
"""Load every file in Nock.toc with empty NockDB / NockCharDB (Lua 5.1)."""
import sys
from pathlib import Path

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

ROOT = Path("/workspace/nock/Nock")
TESTS = Path("/workspace/nock/tests")

toc = (ROOT / "Nock.toc").read_text()
if "## Interface: 16001" not in toc:
    sys.exit("TOC Interface is not 16001")
if "## Version: 3.8.1" not in toc:
    sys.exit("TOC Version is not 3.8.1")

lua_files = [
    line.strip()
    for line in toc.splitlines()
    if line.strip() and not line.strip().startswith("#") and line.strip().endswith(".lua")
]
if lua_files[0] != "Theme.lua" or lua_files[-1] != "UI_Launcher.lua":
    sys.exit("unexpected TOC file list: " + ",".join(lua_files))

stubs = (TESTS / "stubs_threat.lua").read_text()
cut = stubs.find("NockCharDB = {}")
if cut < 0:
    sys.exit("could not trim stub Nock tables")
stubs = stubs[:cut]
extra = (TESTS / "stubs_fresh.lua").read_text()

lua = LuaRuntime(unpack_returned_tuples=True)

def run(src, name, addon_name=None):
    try:
        if addon_name:
            g = lua.globals()
            g._SRC = src
            g._NAME = name
            g._ADDON = addon_name
            lua.execute('assert(loadstring(_SRC, _NAME))(_ADDON)')
        else:
            lua.execute(src)
    except Exception as e:
        print("LUA ERROR in", name, ":", e)
        sys.exit(1)

run(stubs, "stubs_threat.lua (trimmed)")
run(extra, "stubs_fresh.lua")

for name in lua_files:
    path = ROOT / name
    if not path.exists():
        sys.exit("missing toc file: " + name)
    # WoW passes the addon name as the file's vararg (...).
    run(path.read_text(), name, addon_name="Nock")
    print("loaded", name)

# Drive ADDON_LOADED and PLAYER_LOGIN like a first login on a hunter.
run(r'''
  for _, f in ipairs(FRAMES or {}) do
    local fn = f.GetScript and f:GetScript("OnEvent")
    if fn then
      pcall(fn, f, "ADDON_LOADED", "Nock")
    end
  end
  for _, f in ipairs(FRAMES or {}) do
    local fn = f.GetScript and f:GetScript("OnEvent")
    if fn then
      pcall(fn, f, "PLAYER_LOGIN")
    end
  end
''', "events")

g = lua.globals()

def fail(msg):
    print("FRESH_LOAD_FAIL:", msg)
    sys.exit(1)

nock = g.Nock
if not nock:
    fail("Nock global missing after load")
if nock.Version != "3.8.1":
    fail("Nock.Version is %r, expected 3.8.1" % (nock.Version,))

theme = g.NockTheme
if not theme:
    fail("NockTheme missing")
style = theme.StyleId() if theme.StyleId else None
if style != "emerald":
    fail("default style is %r, expected emerald" % (style,))

if nock.BarSize and nock.BarSize() != "large":
    fail("BarSize default is %r, expected large" % (nock.BarSize(),))

if not nock.IsHunter or not nock.IsHunter():
    fail("fresh hunter should be recognized")

db = g.NockCharDB
acct = g.NockDB
if db is None or acct is None:
    fail("DB tables missing")
if db.autofill is not True:
    fail("autofill default should be true, got %r" % (db.autofill,))
if db.overlay is not True:
    fail("overlay default should be true, got %r" % (db.overlay,))
if db.hudStyle not in (None, "emerald"):
    fail("empty DB should not force a non-default style, got %r" % (db.hudStyle,))
if nock.Launcher is None:
    fail("Nock.Launcher missing")
core = nock.Core
if core is None:
    fail("Nock.Core (3.4 hunter tools) missing")
nmods = lua.eval("#Nock.Core.order")
if nmods != 11:
    fail("expected 11 hunter tools, got %r" % (nmods,))
errs = lua.eval("(function() local n = 0; for k, v in pairs(Nock.Core.errors or {}) do print('tool error', k, v); n = n + 1 end; return n end)()")
if errs:
    fail("hunter tool errors on first login")
if not g.NockFeedButton:
    fail("NockFeedButton (feed pet keybind) missing")
# 3.6.3 dedicated Wing Clip / Hunter's Mark keys
if not g.NockWingClipButton or not g.NockMarkButton:
    fail("dedicated Wing Clip / Hunter's Mark buttons missing")
if g.NockWingClipButton.GetAttribute(g.NockWingClipButton, "macrotext") != "/cast Wing Clip":
    fail("Wing Clip button must cast by name (highest rank)")
if g.NockMarkButton.GetAttribute(g.NockMarkButton, "macrotext") != "/cast Hunter's Mark":
    fail("Hunter's Mark button must cast by name (highest rank)")
res = lua.execute(r'''
  local D = Nock.Dedicated
  local set = {}
  SetOverrideBindingClick = function(owner, prio, key, btn) set[key] = btn end
  ClearOverrideBindings = function() set = {} end
  -- free keys: both suggested
  GetBindingAction = function() return "" end
  GetBindingKey = function() return nil end
  D.SetEnabled(false); D.SetEnabled(true)
  assert(set["CAPSLOCK"] == "NockWingClipButton", "CAPSLOCK not suggested")
  -- 3.6.3: no change means no Clear/Set (UPDATE_BINDINGS loop)
  local clears = 0
  local realClear = ClearOverrideBindings
  ClearOverrideBindings = function(...) clears = clears + 1; return realClear(...) end
  D.Apply(); D.Apply()
  assert(clears == 0, "Apply re-set unchanged overrides (binding loop)")
  ClearOverrideBindings = realClear
  assert(set["`"] == "NockMarkButton", "` not suggested")
  -- his own key on ` : Nock must not use it
  GetBindingAction = function(k) if k == "`" then return "TOGGLEAUTORUN" end return "" end
  D.Apply()
  assert(set["`"] == nil, "took a key he owns")
  assert(set["CAPSLOCK"] == "NockWingClipButton")
  -- he bound Wing Clip himself: no suggestion for it
  GetBindingKey = function(c) if c == "CLICK NockWingClipButton:LeftButton" then return "SHIFT-W" end end
  D.Apply()
  assert(set["CAPSLOCK"] == nil, "suggested over his own Wing Clip key")
  local k, how = D.KeyFor(D.LIST[1])
  assert(k == "SHIFT-W" and how == "yours")
  -- in combat: nothing changes
  local prev = InCombatLockdown
  InCombatLockdown = function() return true end
  set = { sentinel = true }
  D.Apply()
  assert(set.sentinel, "changed binds in combat")
  InCombatLockdown = prev
  -- switch off
  GetBindingKey = function() return nil end
  GetBindingAction = function() return "" end
  set = {}
  D.Apply()
  assert(set["CAPSLOCK"] and set["`"], "suggestions not restored once keys are free")
  D.SetEnabled(false)
  assert(next(set) == nil, "suggestions stayed on when switched off")
  D.SetEnabled(true)
  assert(set["CAPSLOCK"] and set["`"])
  NockCharDB.dedicatedKeys = nil
''')
print("dedicated keys OK:", g.Nock.Dedicated.Summary())
if not g.NockPetRevive or not g.NockPetMend:
    fail("pet bar Call / Revive and Mend tiles missing (3.6.3)")
if "[@pet,dead][nopet] Revive Pet" not in str(lua.eval("Nock.PetReviveMacro")):
    fail("revive macro must revive a dead pet that is not in the world")

# 3.5.0 alert manager
alerts = nock.Alerts
if not alerts:
    fail("Nock.Alerts (3.5.0 alert manager) missing")
ndefs = lua.eval("(function() local n = 0 for _ in pairs(Nock.Alerts.defs) do n = n + 1 end return n end)()")
if ndefs < 20:
    fail("expected 20+ registered alerts, got %r" % (ndefs,))
if not g.NockAlertStack:
    fail("alert stack frame not created on login")

# Account and character tables must not contain a pre-baked profile or position
# from someone else's character.
# lupa tables: iterate via lua
lua.execute(r'''
  FRESH_KEYS = {}
  for k, v in pairs(NockCharDB or {}) do
    FRESH_KEYS[#FRESH_KEYS + 1] = tostring(k) .. "=" .. type(v)
  end
  FRESH_ACCT = {}
  for k, v in pairs(NockDB or {}) do
    FRESH_ACCT[#FRESH_ACCT + 1] = tostring(k) .. "=" .. type(v)
  end
''')
keys = list(g.FRESH_KEYS.values()) if g.FRESH_KEYS else []
acct_keys = list(g.FRESH_ACCT.values()) if g.FRESH_ACCT else []
# lupa lua tables may be 1-indexed dict-like
print("NockCharDB after ADDON_LOADED:", keys)
print("NockDB after ADDON_LOADED:", acct_keys)

blob = " ".join(str(x) for x in keys + acct_keys)
# Fresh DBs should only hold default option keys, never a character or account name.
for item in keys + acct_keys:
    if "=" not in str(item):
        continue
    k = str(item).split("=", 1)[0].lower()
    if "name" in k or "realm" in k or "character" in k or "account" in k:
        fail("empty DB should not store a name field: " + str(item))

print("FRESH_LOAD_OK version=%s style=%s bar=%s files=%d" % (
    nock.Version, style, nock.BarSize() if nock.BarSize else "?", len(lua_files)))
print("Interface 16001, empty NockDB/NockCharDB, defaults only")
sys.exit(0)
