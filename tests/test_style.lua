-- Nock 3.1.0 style-system tests (Lua 5.1).

local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert") .. ": got " .. tostring(a) .. " expected " .. tostring(b), 2)
  end
end
local function assert_true(v, msg)
  if not v then error(msg or "assert_true failed", 2) end
end

local T = _G.NockTheme
assert_true(T, "NockTheme exists")
assert_true(T.NormalizeStyle, "NormalizeStyle exists")
assert_eq(T.NormalizeStyle("gun"), "gunsmith", "gun alias")
assert_eq(T.NormalizeStyle("rifle"), "gunsmith", "rifle alias")
assert_eq(T.NormalizeStyle("emerald"), "emerald", "emerald")
assert_eq(T.NormalizeStyle("dream"), "emerald", "dream alias")
assert_eq(T.NormalizeStyle("bow"), "emerald", "bow alias")
assert_eq(T.NormalizeStyle("nope"), "emerald", "unknown falls back to emerald")
assert_eq(T.StyleId(), "emerald", "default style is Emerald")
assert_eq(T.StyleName(), "Emerald", "default name")

local bow0 = T.tex.bow
assert_true(bow0 and not tostring(bow0):find("\\gun\\", 1, true), "default bow is not a gun path: " .. tostring(bow0))
assert_true(T.tex.xp_frame and not tostring(T.tex.xp_frame):find("\\gun\\", 1, true), "default xp_frame is emerald")

-- Apply gunsmith
local id = T.ApplyStyle("gunsmith", true)
assert_eq(id, "gunsmith")
assert_eq(T.StyleId(), "gunsmith")
assert_eq(T.StyleName(), "Gunsmith")
assert_true(tostring(T.tex.bow):find("\\gun\\bow.tga", 1, true), "gun bow path, got " .. tostring(T.tex.bow))
assert_true(tostring(T.tex.xp_frame):find("\\gun\\xp_frame.tga", 1, true), "gun xp_frame")
assert_true(tostring(T.tex.xp_fill):find("\\gun\\xp_fill.tga", 1, true), "gun xp_fill")
assert_true(tostring(T.tex.corner):find("\\gun\\corner.tga", 1, true), "gun corner (derived)")
assert_true(tostring(T.tex.paw):find("\\gun\\paw.tga", 1, true), "gun paw")
local uv = T.XP()
assert_true(math.abs(uv.winL - 0.21728515625) < 1e-9, "gun XP window left UV")
assert_true(math.abs(uv.winR - 0.78271484375) < 1e-9, "gun XP window right UV")
local cap = T.CapUV("fletch")
assert_true(cap[1] > 0.5, "gun fletch crop is right-aligned")
local head = T.CapUV("head")
assert_true(head[2] < 0.5, "gun head crop is left-aligned")
local safe = T.ThreatColors().safe
assert_true(safe[1] > 0.7 and safe[2] < 0.75, "gunsmith safe threat is brass, not emerald")
local fill = T.FillTint("xp_fill")
assert_true(fill and fill[1] > 0.9, "gun XP fill tint lets the fire art show")
print("gunsmith apply ok")

-- Back to emerald
T.ApplyStyle("emerald", true)
assert_eq(T.StyleId(), "emerald")
assert_eq(T.tex.bow, bow0, "emerald bow path restored")
assert_true(not tostring(T.tex.xp_fill):find("\\gun\\", 1, true), "emerald xp_fill restored")
local euv = T.XP()
assert_true(math.abs(euv.winL - 0.071495) < 1e-6, "emerald XP window UV restored")
local ecap = T.CapUV("fletch")
assert_true(ecap[1] < 0.01, "emerald fletch crop starts at the left")
local esafe = T.ThreatColors().safe
assert_true(esafe[2] > 0.7, "emerald safe threat is green again")
print("emerald restore ok")

-- SetStyle persists and queues in combat
NockCharDB.hudStyle = nil
INCOMBAT = false
Nock.inCombatFlag = false
local sid, why = T.SetStyle("gun")
assert_eq(sid, "gunsmith")
assert_eq(why, "ok")
assert_eq(NockCharDB.hudStyle, "gunsmith", "saved per character")
assert_eq(T.StyleId(), "gunsmith")

INCOMBAT = true
Nock.inCombatFlag = true
sid, why = T.SetStyle("emerald")
assert_eq(why, "combat", "style change is queued in combat")
assert_eq(T.StyleId(), "gunsmith", "still gunsmith during the fight")
assert_eq(NockCharDB.hudStyle, "gunsmith", "saved style is not overwritten mid-fight")
INCOMBAT = false
Nock.inCombatFlag = false
T.ApplyPendingStyle()
assert_eq(T.StyleId(), "emerald", "queued style applies after combat")
assert_eq(NockCharDB.hudStyle, "emerald")
print("persist / combat queue ok")

-- Toggle
T.SetStyle("emerald")
sid = T.ToggleStyle()
assert_eq(sid, "gunsmith", "toggle from emerald goes to gunsmith")
sid = T.ToggleStyle()
assert_eq(sid, "emerald", "toggle from gunsmith goes to emerald")
print("toggle ok")

-- SetTex registers and restyles
local tex = { _path = "" }
function tex:SetTexture(path) self._path = path; return true end
function tex:SetVertexColor(r,g,b,a) self._v = {r,g,b,a} end
T.ApplyStyle("emerald", true)
T.SetTex(tex, "bow")
assert_true(tex._nockTexKey == "bow", "SetTex tags the key")
assert_true(not tostring(tex._path):find("\\gun\\", 1, true), "emerald path applied")
T.ApplyStyle("gunsmith", false) -- refresh registered textures
assert_true(tostring(tex._path):find("\\gun\\bow.tga", 1, true), "restyle updates registered textures, got " .. tostring(tex._path))
print("restyle registry ok")

-- TOC and bindings
local function read(path)
  local f = io.open(path, "r")
  local d = f:read("*a")
  f:close()
  return d
end
local toc = read("/workspace/nock/Nock/Nock.toc")
assert_true(toc:find("Styles.lua", 1, true), "TOC loads Styles.lua")
assert_true(toc:find("Version: 3.5.1", 1, true), "TOC is 3.5.1")
local bind = read("/workspace/nock/Nock/Bindings.xml")
assert_true(bind:find("NOCK_STYLE", 1, true), "style toggle is in Bindings")
assert_true(bind:find("NOCK_THREAT_UNLOCK", 1, true), "threat unlock is in Bindings")
assert_true(bind:find("Nock_ToggleStyle()", 1, true), "style binding calls Nock_ToggleStyle")
assert_true(bind:find("Nock_ToggleThreatUnlock()", 1, true), "threat binding calls Nock_ToggleThreatUnlock")
local nock = read("/workspace/nock/Nock/Nock.lua")
assert_true(nock:find('msg:match("^style")', 1, true) or nock:find('msg:match("^style")', 1, true) or nock:find("threat unlock", 1, true), "slash has style / threat move")
assert_true(nock:find("threat unlock", 1, true), "slash has threat unlock")
assert_true(nock:find("threat lock", 1, true), "slash has threat lock")
assert_true(nock:find("threat reset", 1, true), "slash has threat reset")
assert_true(nock:find('msg == "save"', 1, true), "slash has /nock save")
assert_true(nock:find("profile save", 1, true), "slash has profile save")
assert_true(nock:find("profile load", 1, true), "slash has profile load")
assert_true(nock:find("LoadSavedStyle", 1, true), "Nock.lua applies LoadSavedStyle on ADDON_LOADED")
assert_true(nock:find('msg:match("^button")', 1, true), "slash has /nock button")
assert_true(nock:find("button reset", 1, true), "slash has /nock button reset")
assert_true(toc:find("UI_Launcher.lua", 1, true), "TOC loads UI_Launcher.lua")
local theme = read("/workspace/nock/Nock/Theme.lua")
assert_true(theme:find('BINDING_NAME_NOCK_WINDOW = "Open Nock"', 1, true), "keybind is named Open Nock")
assert_true(theme:find("function T.SolidFill", 1, true), "Theme has SolidFill underlay")
assert_true(theme:find("SetBackdrop", 1, true), "HideDefaultChrome drops Backdrop")
local ui = read("/workspace/nock/Nock/UI.lua")
assert_true(ui:find("function UI.WindowMetrics", 1, true), "window scales with bar size")
assert_true(ui:find("function UI.ApplyWindowSize", 1, true), "ApplyWindowSize exists")
assert_true(ui:find("SetClampedToScreen", 1, true), "tooltips clamp to the screen")
assert_true(ui:find('"BOTTOMLEFT", frame, "BOTTOMLEFT", GRID.gutter, m.tabY', 1, true), "tabs sit inside the frame")
assert_true(ui:find("function UI.LayoutActionBar", 1, true), "page buttons have their own action bar row")
assert_true(ui:find("FitToScreen(frame, m)", 1, true), "window is scaled to fit the screen")
assert_true(not ui:find('TOPLEFT", f, "BOTTOMLEFT", 12, 2', 1, true), "tabs no longer hang off the bottom")
local opt = read("/workspace/nock/Nock/UI_Options.lua")
assert_true(opt:find("Show Nock button", 1, true), "Options has Show Nock button toggle")
assert_true(opt:find("Segmented", 1, true), "Options uses segmented size/style buttons")
local rot = read("/workspace/nock/Nock/UI_MyRotation.lua")
assert_true(rot:find("function PaintKeyMap", 1, true), "cheat sheet is a two-column key list")
assert_true(not rot:find('lab:sub(1, 13)', 1, true), "cheat sheet no longer truncates names")
local launch = read("/workspace/nock/Nock/UI_Launcher.lua")
assert_true(launch:find("GameMenuButtonNock", 1, true), "Game Menu button is created")
assert_true(launch:find("HookScript", 1, true), "Game Menu uses HookScript OnShow")
assert_true(not launch:find("hooksecurefunc(", 1, true), "Game Menu does not hooksecurefunc protected APIs")
assert_true(not launch:find("HideUIPanel(", 1, true), "Game Menu click does not call HideUIPanel")
assert_true(launch:find("NockLauncherButton", 1, true), "movable launcher button exists")
assert_true(launch:find("IsShiftKeyDown", 1, true), "launcher moves with Shift-drag")
assert_true(launch:find("launcherPos", 1, true), "launcher position is saved")
print("files ok")

-- Simulated SavedVariables round-trip (file load, then SV, then ADDON_LOADED).
-- At file load, saved vars are not available; the default is Emerald.
T.ApplyStyle("emerald", true)
NockCharDB = {}  -- empty table as if the file-load or {} ran first
assert_eq(T.StyleId(), "emerald", "file load defaults to emerald")
-- Then the saved table is loaded (WoW replaces NockCharDB) and ADDON_LOADED runs.
NockCharDB = { hudStyle = "gunsmith", threatPos = { x = 40, y = 20 }, barSize = "large", nockThreat = true }
assert_true(T.LoadSavedStyle, "LoadSavedStyle exists")
local loaded = T.LoadSavedStyle()
assert_eq(loaded, "gunsmith", "LoadSavedStyle returns gunsmith")
assert_eq(T.StyleId(), "gunsmith", "style is gunsmith after the SV round-trip")
assert_true(tostring(T.tex.bow):find("\\gun\\bow.tga", 1, true), "bow path is gun after reload simulation")
assert_eq(NockCharDB.hudStyle, "gunsmith", "saved hudStyle was not overwritten by the default")
assert_eq(NockCharDB.threatPos.x, 40, "threat position survived the round-trip")
assert_eq(NockCharDB.barSize, "large", "bar size survived the round-trip")
print("savedvariables round-trip ok")


print("== Style tests ok")
STYLE_TEST_OK = true
