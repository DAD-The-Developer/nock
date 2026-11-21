--[[
  Nock 3.4.0: the Tools tab ("Field Kit").

  One scrolling page, a section per hunter tool, each written by the tool's
  own Report(). New tools appear here automatically when they register with
  Nock.Core. Open with the Tools tab, /nock kit, or the keybind.
]]

local Nock = _G.Nock
local UI = Nock and Nock.UI
local Core = Nock and Nock.Core
if not (UI and UI.lib and Core) then
  return
end

local L = UI.lib
local Kit = {}
Nock.Kit = Kit

local function EnsureFont(fs, size, flags)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    return T.EnsureFont(fs, size, flags)
  end
  pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags or "OUTLINE")
end

local function Metrics()
  return (L.WindowMetrics and L.WindowMetrics()) or { body = 16, header = 20, content = L.CONTENT_W or 848 }
end

local function Build(page)
  page.footer = "Each tool: /nock <word> on | off. All switches are in Options > Hunter tools."
  local scroll, child = L.MakeScroll(page, -8, 8)
  page.scroll, page.child = scroll, child
  page.sections = {}
  return page
end

local function Section(page, i)
  local s = page.sections[i]
  if s then
    return s
  end
  local child = page.child
  local m = Metrics()
  s = {}
  s.head = child:CreateFontString(nil, "OVERLAY")
  EnsureFont(s.head, m.header or 20, "OUTLINE")
  s.head:SetTextColor(0.95, 0.88, 0.55)
  s.head:SetJustifyH("LEFT")
  s.line = child:CreateTexture(nil, "ARTWORK")
  s.line:SetColorTexture(0.82, 0.70, 0.35, 0.55)
  s.line:SetHeight(2)
  s.body = child:CreateFontString(nil, "OVERLAY")
  EnsureFont(s.body, m.body or 16, "OUTLINE")
  s.body:SetJustifyH("LEFT")
  s.body:SetJustifyV("TOP")
  if s.body.SetWordWrap then
    s.body:SetWordWrap(true)
  end
  s.body:SetTextColor(0.92, 0.97, 0.94)
  if s.body.SetSpacing then
    s.body:SetSpacing(3)
  end
  page.sections[i] = s
  return s
end

local function Refresh(page)
  if not page or not page.child then
    return
  end
  local m = Metrics()
  local cw = (m.content or 848) - 24
  local y = -8
  local i = 0
  for _, id in ipairs(Core.order) do
    local mod = Core.modules[id]
    if mod.Report then
      i = i + 1
      local s = Section(page, i)
      local on = Core.Enabled(id)
      local cmd = mod.cmd and mod.cmd[1] or id
      s.head:SetText(mod.name .. (on and "" or "  |cff9cc4b1(off)|r") .. "   |cff9cc4b1/nock " .. cmd .. "|r")
      s.head:ClearAllPoints()
      s.head:SetPoint("TOPLEFT", 8, y)
      s.line:ClearAllPoints()
      s.line:SetPoint("TOPLEFT", s.head, "BOTTOMLEFT", 0, -4)
      s.line:SetWidth(cw)
      local lines
      if on then
        local ok, out = pcall(mod.Report, mod)
        lines = ok and type(out) == "table" and out or { "(could not read this right now)" }
      else
        lines = { Core.Get(id, "on") == false and ("Off. /nock " .. cmd .. " on") or ("Steps aside at level 60. /nock " .. cmd .. " at60 keeps it on.") }
      end
      s.body:SetText(table.concat(lines, "\n"))
      s.body:SetWidth(cw - 8)
      s.body:ClearAllPoints()
      s.body:SetPoint("TOPLEFT", s.head, "BOTTOMLEFT", 4, -12)
      s.head:Show()
      s.line:Show()
      s.body:Show()
      local h = (s.body.GetStringHeight and s.body:GetStringHeight()) or (#lines * 20)
      y = y - (m.header or 20) - 16 - h - 18
    end
  end
  for j = i + 1, #page.sections do
    page.sections[j].head:Hide()
    page.sections[j].line:Hide()
    page.sections[j].body:Hide()
  end
  page.child:SetHeight(math.max(20, -y + 16))
end

UI.extraPages = UI.extraPages or {}
UI.extraPages.kit = Build
L.RefreshPage.kit = function(page)
  Refresh(page)
end

function Kit.Open()
  if Nock.ShowPanel then
    Nock.ShowPanel("kit")
  end
end
