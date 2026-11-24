#!/usr/bin/env python3
"""3.6.2: pet bar with a live / dead pet, and the Wing Clip tile. Usage: run_petbar.py [alive|corpse|dead]"""
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parent.parent; ROOT=root/"Nock"; TESTS=Path("/workspace/nock/tests")
toc=(ROOT/"Nock.toc").read_text()
files=[l.strip() for l in toc.splitlines() if l.strip().endswith(".lua") and not l.startswith("#")]
stubs=(TESTS/"stubs_threat.lua").read_text(); stubs=stubs[:stubs.find("NockCharDB = {}")]
lua=LuaRuntime(unpack_returned_tuples=True)
mode=sys.argv[1] if len(sys.argv)>1 else 'alive'
m4mine = 'm4mine' in sys.argv
lua.execute('M4MINE = %s' % ('true' if m4mine else 'false'))
lua.execute('DEAD = %s; CORPSE = %s' % ('true' if mode!='alive' else 'false', 'true' if mode=='corpse' else 'false'))
lua.execute(stubs); lua.execute((TESTS/"stubs_fresh.lua").read_text())
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
''')
lua.execute(r'''
UNIT_EXISTS = UNIT_EXISTS or {}; UNIT_EXISTS.pet = (DEAD ~= true) or CORPSE
function GetBindingAction(k) if M4MINE and k == 'BUTTON4' then return 'TOGGLEAUTORUN' end if M4MINE and k == 'SHIFT-Z' then return 'SPELL Wing Clip' end return '' end
function GetBindingKey(c) if M4MINE and c == 'SPELL Wing Clip' then return 'SHIFT-Z' end end
local ids = {['Revive Pet']=982, ['Call Pet']=883, ['Mend Pet']=136, ['Feed Pet']=6991, ['Beast Training']=5149, ['Wing Clip']=2974, ['Hunter\'s Mark']=1130, ['Tame Beast']=1515}
function GetSpellInfo(n) local id = ids[n] or (type(n)=='number' and n) ; if id then return (type(n)=='string' and n or 'X'), nil, 132161, 0,0,0, id end end
C_Spell = nil
local slots = { {"PET_ACTION_ATTACK","PET_ATTACK_TEXTURE",true}, {"PET_ACTION_FOLLOW","PET_FOLLOW_TEXTURE",true}, {"PET_ACTION_WAIT","PET_WAIT_TEXTURE",true},
 {"Bite","Interface\\Icons\\Ability_Racial_Cannibalize",false}, {"Growl","Interface\\Icons\\Ability_Physical_Taunt",false} }
function GetPetActionInfo(i) if DEAD then return nil end local s = slots[i]; if s then return s[1], s[2], s[3], false, true, true, 17253 end end
function GetMacroIndexByName() return 0 end
function SetBindingMacro() return true end
function SetBindingSpell() return true end
function CreateMacro() return 1 end
function EditMacro() return 1 end
function GetMacroInfo() return nil end
function PetHasActionBar() return true end
function HasPetUI() return true, true end
function IsPlayerSpell() return true end
function IsSpellKnown() return true end
''')
g=lua.globals()
for f in files:
    g._SRC=(ROOT/f).read_text(); g._N=f
    lua.execute('assert(loadstring(_SRC,_N))("Nock")')
lua.execute(r'''
for _, ev in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","UPDATE_BINDINGS","PET_BAR_UPDATE","UNIT_PET"}) do
  for _, f in ipairs(FRAMES or {}) do local fn = f.GetScript and f:GetScript("OnEvent"); if fn then pcall(fn, f, ev, ev=="ADDON_LOADED" and "Nock" or "player") end end
end
if C_Timer and C_Timer._run then C_Timer._run() end
''')
lua.execute(r'''
pcall(Nock.SetOverlayShown, true); print('upd', pcall(Nock.UpdatePetBar))
local n, names = 0, {}
print('tame', NockPetTame and NockPetTame:IsShown(), NockPetTame and NockPetTame.tag:GetText(), NockPetTame and NockPetTame:GetAttribute('spell'))
print('revive', NockPetRevive and NockPetRevive:IsShown(), NockPetRevive and NockPetRevive.tag:GetText(), NockPetRevive and NockPetRevive:GetAttribute('macrotext'), 'mend', NockPetMend and NockPetMend:IsShown(), NockPetMend and NockPetMend.tag and NockPetMend.tag:GetText())
local ex = Nock and overlay
for _, f in ipairs(FRAMES) do if f.rec and f.rec.id == 'Wing Clip' then print('wingclip tile', f:IsShown(), f.key, f.label and f.label:GetText(), f:GetAttribute('spell'), 'noBind', f.rec.noBind) end end
for i=1,5 do local b=_G['NockPetBtn'..i]; if b then print('pet', i, b:IsShown(), b.tag and b.tag:GetText(), b.tag and b.tag._shown) end end
for i=1,10 do local b=_G["NockPetBtn"..i]; if b and b:IsShown() then n=n+1; names[#names+1]=i end end
print("shown pet caps", n, table.concat(names,","), "wrap", NockPetBar and NockPetBar:IsShown(), "feed", NockPetFeed and NockPetFeed:IsShown(), "train", NockPetTrain and NockPetTrain:IsShown())
for k,v in pairs(Nock.Core and Nock.Core.errors or {}) do print("err",k,v) end
for k,v in pairs(NockCharDB.errors or {}) do print("dberr",k,v) end
''')

r = lua.eval("""(function()
  local wc, wkey
  for i = 1, 200 do
    local f = _G['NockOverlayKey'..i]
    if f and f:IsShown() and f.entry and f.entry.name == 'Wing Clip' and f.isMain then wc = f; wkey = f.key end
  end
  local n = 0
  for i = 1, 10 do local b = _G['NockPetBtn'..i]; if b and b:IsShown() then n = n + 1 end end
  return wc and 1 or 0, n, (NockPetRevive:IsShown() and NockPetTame and NockPetTame:IsShown()) and 1 or 0, NockPetBtn1.tag:GetText() or '', tostring(wkey), wc and wc.label:GetText() or ''
end)()""")
wc, n, rev, tag, wkey, wlabel = r
want = 5 if mode == "alive" else 0
if wc != 1: sys.exit("PETBAR_FAIL: no full-size Wing Clip tile on the bow bar")
if wkey != ("SHIFT-Z" if m4mine else "BUTTON4"): sys.exit("PETBAR_FAIL: Wing Clip tile on %s" % wkey)
if n != want: sys.exit("PETBAR_FAIL: %d pet command tiles, expected %d" % (n, want))
if rev != 1: sys.exit("PETBAR_FAIL: Call / Revive or Tame Beast tile missing")
if mode == "alive" and not tag: sys.exit("PETBAR_FAIL: Attack tile has no key label")
print("PETBAR_OK", mode, "m4mine" if m4mine else "", "wing clip on", wkey, wlabel)
