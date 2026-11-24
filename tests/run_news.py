#!/usr/bin/env python3
"""Nock 3.8.0: What's New window, its data, and the release notes (Lua 5.1 via lupa)."""
import re, sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parent.parent; ROOT = root / "Nock"; TESTS = root / "tests"
sys.path.insert(0, str(root / "tools"))
import release_notes
toc = (ROOT / "Nock_Forever.toc").read_text()
ver = re.search(r"## Version: (\S+)", toc).group(1)
files = [l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
fails = []
def check(ok, what):
    print(("ok  " if ok else "FAIL ") + what)
    if not ok:
        fails.append(what)

# Release notes / CHANGELOG in sync with Changelog.lua
text, top = release_notes.notes()
check(top == ver, "Changelog.lua top entry is the TOC version (%s)" % ver)
check((root / "RELEASE_NOTES.md").read_text() == text, "RELEASE_NOTES.md is up to date (python3 tools/release_notes.py)")
check("filename: RELEASE_NOTES.md" in (root / ".pkgmeta").read_text(), ".pkgmeta uses RELEASE_NOTES.md for GitHub and CurseForge")
cl = (root / "CHANGELOG.md").read_text()
sec = cl.split("## " + ver, 1)[1].split("\n## ", 1)[0] if ("## " + ver) in cl else ""
bullets = [l[2:] for l in text.splitlines() if l.startswith("- ")]
check(sec and all(b in sec for b in bullets), "CHANGELOG.md %s has every What's New bullet" % ver)

stubs = (TESTS / "stubs_threat.lua").read_text(); stubs = stubs[:stubs.find("NockCharDB = {}")]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(stubs); lua.execute((TESTS / "stubs_fresh.lua").read_text())
lua.execute(r'''
local CF = CreateFrame
local noop = function() end
local function fallback(f)
  local m = getmetatable(f)
  if m and type(m.__index) == "table" then
    local idx = m.__index
    m.__index = function(t, k) local v = idx[k]; if v ~= nil then return v end; if type(k)=="string" and k:match("^%u") then return noop end end
  end
  return f
end
function CreateFrame(...) return fallback(CF(...)) end
UISpecialFrames = {}
COMBAT = false
function InCombatLockdown() return COMBAT end
function GetMacroIndexByName() return 0 end
function GetCursorInfo() return nil end
''')
g = lua.globals()
for f in files:
    g._SRC = (ROOT / f).read_text(); g._N = f
    lua.execute('assert(loadstring(_SRC,_N))("Nock")')
nf = lua.execute(r'''
local fails = {}
local function check(ok, what) if not ok then fails[#fails + 1] = what end; print((ok and "ok  " or "FAIL ") .. what) end
local N = Nock.WhatsNew
check(N and Nock.Changelog and #Nock.Changelog >= 7, "changelog data loaded (3.6.0 .. 3.8.0)")
for _, v in ipairs({ "3.8.0", "3.7.1", "3.7.0", "3.6.3", "3.6.2", "3.6.1", "3.6.0" }) do
  local e = N.Entry(v)
  check(e and e.date and e.summary and (#e.new + #e.improved + #e.fixed) > 0, "entry " .. v)
end
check(Nock.Changelog[1].version == Nock.Version, "top entry is Nock.Version")
check(N.Decide(nil, "3.8.0", false, true) == "welcome", "fresh install: welcome")
check(N.Decide(nil, "3.8.0", false, false) == "news", "upgrade from before 3.8.0: what's new")
check(N.Decide("3.7.1", "3.8.0", false, false) == "news", "version changed: what's new")
check(N.Decide("3.8.0", "3.8.0", false, false) == nil, "same version: nothing")
check(N.Decide("3.7.1", "3.8.0", true, false) == nil, "don't show again respected")
check(N.NiceDate("2026-11-23") == "Nov 23, 2026", "date format")

NockDB = { news = {} }
Nock.freshInstall = false
COMBAT = true
check(N.Check() == "pending", "waits for combat to end")
COMBAT = false
check(N.Check() == "news", "opens once after the update")
check(NockDB.news.seen == Nock.Version, "last seen version stored")
check(N.frame and N.frame:IsShown(), "window shown")
local h1 = N.frame.contentH
check(type(h1) == "number" and h1 > 0, "content laid out (" .. tostring(h1) .. ")")
N.frame.open = { ["3.7.1"] = true }
N.Layout()
check(N.frame.contentH > h1, "earlier version expands below")
N.frame.open = {}
N.Layout()
check(N.frame.contentH == h1, "and collapses again")
local esc = false
for _, n in ipairs(UISpecialFrames) do if n == "NockWhatsNew" then esc = true end end
check(esc, "Esc closes it")
N.frame:Hide()
check(N.Check() == nil, "not again on the next login")
SlashCmdList.NOCK("new")
check(N.frame:IsShown(), "/nock new opens it")
SlashCmdList.NOCK("new")
check(not N.frame:IsShown(), "/nock new again closes it")
N.SetOff(true)
check(NockDB.news.off == true and N.Off(), "don't show again saved")
N.Show("welcome")
check(N.frame.mode == "welcome", "welcome view")
return #fails
''')
nf = (nf or 0) + len(fails)
print("NEWS_TEST_OK" if nf == 0 else "NEWS_FAIL %d" % nf)
sys.exit(1 if nf else 0)
