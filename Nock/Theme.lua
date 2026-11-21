--[[
  Nock 2.0: Emerald Dream theme (moonwood, silver and emerald, Rhok'delar-style bow).
  Palette, texture paths and small helpers shared by the key bar, the Hunting
  Notes card, the glow and the Nock window. Art only: nothing here reads the game.
  Every texture call falls back to a flat color if the file can't be loaded.
]]

local T = {}
_G.NockTheme = T

local MEDIA = "Interface\\AddOns\\Nock\\Media\\"
T.MEDIA = MEDIA
local TEX = MEDIA .. "Textures\\"
T.TEX = TEX
T.tex = {
  -- 2.1 art (mist map, crests) still used where the new sheet has no stand-in.
  -- 2.3: Benjamin's longbow and arrow caps. Older Media/bow.tga and
  -- Media/cap_*.tga stay on disk as unused fallbacks.
  bar = MEDIA .. "bar.tga",
  bow = TEX .. "bow.tga",
  fletch = TEX .. "cap_fletch.tga",
  head = TEX .. "cap_head.tga",
  keybadge = MEDIA .. "keybadge.tga",
  paw = MEDIA .. "paw.tga",
  reticle = MEDIA .. "reticle.tga",
  map = MEDIA .. "map.tga",
  mist = MEDIA .. "mist.tga",
  vine = MEDIA .. "vine.tga",
  crest = MEDIA .. "crest.tga",
  moon = MEDIA .. "moon.tga",
  header = MEDIA .. "header.tga",
  -- Key-bar vertical arrow (the new divider is a horizontal vine).
  divider_v = MEDIA .. "divider.tga",
  -- 2.2: Benjamin's carved moonwood sheet.
  tile = TEX .. "tile.tga",
  glow = TEX .. "glow.tga",
  token = TEX .. "badge.tga",
  badge = TEX .. "badge.tga",
  divider = TEX .. "divider.tga",
  corner = TEX .. "corner.tga",
  edge = TEX .. "edge.tga",
  edge_v = TEX .. "edge_v.tga",
  ornament = TEX .. "edge_ornament.tga",
  ornamentWide = TEX .. "edge_ornament512.tga",
  bg = TEX .. "bg.tga",
  title = TEX .. "title.tga",
  close = TEX .. "close.tga",
  closeHover = TEX .. "close_hover.tga",
  barwood = TEX .. "barwood.tga",
  -- 3.0.5 custom XP bar (Ben's art).
  xp_frame = TEX .. "xp_frame.tga",
  xp_bg = TEX .. "xp_bg.tga",
  xp_fill = TEX .. "xp_fill.tga",
  xp_rested = TEX .. "xp_rested.tga",
  xp_ticks = TEX .. "xp_ticks.tga",
  xp_spark = TEX .. "xp_spark.tga",
  xp_badge = TEX .. "xp_badge.tga",
}

-- r, g, b (0-1)
T.color = {
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
}
T.hex = {
  key = "|cffc9ffe1",
  emerald = "|cff40e39a",
  sub = "|cff9cc4b1",
  silver = "|cffbfe3cf",
}

local function C(name)
  local c = T.color[name] or T.color.text
  return c[1], c[2], c[3]
end
T.C = C

-- Sets a texture file; falls back to a flat color (r, g, b, a) if the client refuses it.
-- Forever errors with "FontString:SetText(): Font not set" if a FontString
-- has no font. CreateFontString without a font object (and sometimes even
-- with one, if that object is missing) starts blank. Call this immediately
-- after creating a FontString, before the first SetText.
local FONT_SIZES = {
  GameFontNormalHuge = 20, GameFontHighlightHuge = 20,
  GameFontNormalLarge = 16, GameFontHighlightLarge = 16,
  GameFontNormal = 13, GameFontHighlight = 13, GameFontDisable = 13,
  GameFontNormalSmall = 11, GameFontHighlightSmall = 11, GameFontDisableSmall = 11,
  NumberFontNormal = 13, NumberFontNormalSmall = 11, NumberFontNormalLarge = 16,
}

function T.DefaultFontPath()
  if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
    return STANDARD_TEXT_FONT
  end
  return "Fonts\\FRIZQT__.TTF"
end

local function FontApplied(fs)
  if not fs then
    return false
  end
  if fs.GetFont then
    local ok, path = pcall(fs.GetFont, fs)
    if ok and type(path) == "string" and path ~= "" then
      return true
    end
  end
  return fs._nockFont and true or false
end

function T.EnsureFont(fs, sizeOrObject, flags)
  if not fs then
    return false
  end
  local object, size
  if type(sizeOrObject) == "string" then
    object = sizeOrObject
  elseif type(sizeOrObject) == "number" then
    size = sizeOrObject
  end
  if type(flags) == "number" and not size then
    size = flags
    flags = "OUTLINE"
  end
  flags = flags or "OUTLINE"
  size = size or (object and FONT_SIZES[object]) or 12

  if object and fs.SetFontObject then
    local ok, res = pcall(fs.SetFontObject, fs, object)
    if ok and res ~= false and FontApplied(fs) then
      fs._nockFont = true
      return true
    end
  end

  local function try(path, fl)
    if not fs.SetFont then
      return false
    end
    local ok, res = pcall(fs.SetFont, fs, path, size, fl)
    if ok and res ~= false then
      fs._nockFont = true
      return true
    end
    return false
  end

  local path = T.DefaultFontPath()
  if try(path, flags) or try(path, nil) then
    return true
  end
  if path ~= "Fonts\\FRIZQT__.TTF" then
    if try("Fonts\\FRIZQT__.TTF", flags) or try("Fonts\\FRIZQT__.TTF", nil) then
      return true
    end
  end
  return false
end

function T.SetTex(tex, key, r, g, b, a)
  local path = T.tex[key] or key
  local ok, res = pcall(tex.SetTexture, tex, path)
  if not ok or res == false then
    if tex.SetColorTexture then
      tex:SetColorTexture(r or 0.07, g or 0.12, b or 0.10, a or 0.9)
    end
    return false
  end
  return true
end

function T.Tint(tex, name, a)
  local r, g, b = C(name)
  tex:SetVertexColor(r, g, b, a or 1)
end

function T.TextColor(fs, name)
  if fs and fs.SetTextColor then
    fs:SetTextColor(C(name))
  end
end

-- A 1-pixel line texture.
local function Line(f, layer, r, g, b, a)
  local t = f:CreateTexture(nil, layer or "BORDER")
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

-- Silver outer line + emerald inner line on all four edges.
function T.Border(f, inset)
  inset = inset or 0
  local lines = {}
  local function edge(r, g, b, a, d)
    local top = Line(f, "BORDER", r, g, b, a)
    top:SetPoint("TOPLEFT", d, -d)
    top:SetPoint("TOPRIGHT", -d, -d)
    top:SetHeight(1)
    local bot = Line(f, "BORDER", r, g, b, a)
    bot:SetPoint("BOTTOMLEFT", d, d)
    bot:SetPoint("BOTTOMRIGHT", -d, d)
    bot:SetHeight(1)
    local l = Line(f, "BORDER", r, g, b, a)
    l:SetPoint("TOPLEFT", d, -d)
    l:SetPoint("BOTTOMLEFT", d, d)
    l:SetWidth(1)
    local rt = Line(f, "BORDER", r, g, b, a)
    rt:SetPoint("TOPRIGHT", -d, -d)
    rt:SetPoint("BOTTOMRIGHT", -d, d)
    rt:SetWidth(1)
    lines[#lines + 1] = { top, bot, l, rt }
  end
  edge(0.02, 0.05, 0.04, 1, inset)
  edge(0.61, 0.79, 0.70, 1, inset + 1)
  edge(0.04, 0.08, 0.06, 1, inset + 2)
  edge(0.31, 0.63, 0.48, 0.9, inset + 3)
  f.nockBorder = lines
  return lines
end

-- Leaf-and-vine filigree in the four corners (one texture, mirrored).
function T.Corners(f, size, offset)
  size, offset = size or 30, offset or -2
  local spec = {
    { "TOPLEFT", offset, -offset, 0, 1, 0, 1 },
    { "TOPRIGHT", -offset, -offset, 1, 0, 0, 1 },
    { "BOTTOMLEFT", offset, offset, 0, 1, 1, 0 },
    { "BOTTOMRIGHT", -offset, offset, 1, 0, 1, 0 },
  }
  f.nockCorners = {}
  for i, s in ipairs(spec) do
    local t = f:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetSize(size, size)
    t:SetPoint(s[1], s[2], s[3])
    if T.SetTex(t, "corner") or T.SetTex(t, "vine") then
      t:SetTexCoord(s[4], s[5], s[6], s[7])
    else
      t:Hide()
    end
    f.nockCorners[i] = t
  end
  return f.nockCorners
end

-- Misty Emerald Dream page: mist gradient, faint hunting-map lines, border, vines.
function T.MistPanel(f, opts)
  opts = opts or {}
  local layer = opts.layer or "BACKGROUND"
  -- 2.2: tiled bark fill (falls back to the older mist texture).
  T.TileFill(f, "bg", 256, 256, layer, -7, opts.alpha or 0.96)
  if not f.nockWood then
    local bg = f:CreateTexture(nil, layer, nil, -7)
    bg:SetAllPoints()
    T.SetTex(bg, "mist", 0.06, 0.16, 0.13, 0.95)
    bg:SetAlpha(opts.alpha or 0.96)
    f.nockMist = bg
  end
  local map = f:CreateTexture(nil, layer, nil, -6)
  map:SetAllPoints()
  if T.SetTex(map, "map") then
    map:SetAlpha(opts.mapAlpha or 0.10)
  else
    map:Hide()
  end
  f.nockMap = map
  if opts.border ~= false then
    T.CarveBorder(f, {
      cornerSize = opts.cornerSize or 48,
      edge = opts.edge or 22,
      cornerOffset = opts.cornerOffset or -2,
      ornament = opts.ornament,
    })
  elseif opts.corners ~= false then
    T.Corners(f, opts.cornerSize or 30, opts.cornerOffset or -3)
  end
  return f.nockWood or f.nockMist
end

-- Alias used by the settings window: same carved bark panel as MistPanel.
function T.WoodPanel(f, opts)
  opts = opts or {}
  if opts.map == nil then
    opts.map = false
  end
  return T.MistPanel(f, opts)
end


-- Tiled fill. Uses SetHorizTile/SetVertTile when the client has them; otherwise
-- lays out cropped tiles so nothing paints past the frame edge.
function T.TileFill(f, key, tw, th, layer, sub, alpha)
  alpha = alpha or 0.96
  local t = f:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -7)
  t:SetAllPoints()
  local ok = T.SetTex(t, key, 0.12, 0.08, 0.05, 1)
  t:SetAlpha(alpha)
  f.nockWood = t
  f.nockMist = t
  if not ok then
    return t
  end
  local tiled = false
  if t.SetHorizTile and t.SetVertTile then
    tiled = pcall(function()
      t:SetHorizTile(true)
      t:SetVertTile(true)
    end)
  end
  if tiled then
    return t
  end
  -- Fallback: a pool of tiles sized to the frame (last row/column is cropped).
  t:Hide()
  f.nockTiles = f.nockTiles or {}
  local pool = f.nockTiles
  local function layout()
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w < 2 or h < 2 then
      return
    end
    local nx, ny = math.max(1, math.ceil(w / tw)), math.max(1, math.ceil(h / th))
    local n = 0
    for row = 0, ny - 1 do
      for col = 0, nx - 1 do
        n = n + 1
        local tile = pool[n]
        if not tile then
          tile = f:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -7)
          T.SetTex(tile, key, 0.12, 0.08, 0.05, 1)
          pool[n] = tile
        end
        local x, y = col * tw, row * th
        local rw = math.min(tw, w - x)
        local rh = math.min(th, h - y)
        tile:ClearAllPoints()
        tile:SetSize(rw, rh)
        tile:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
        tile:SetTexCoord(0, rw / tw, 0, rh / th)
        tile:SetAlpha(alpha)
        tile:Show()
      end
    end
    for i = n + 1, #pool do
      pool[i]:Hide()
    end
  end
  if f.HookScript then
    f:HookScript("OnSizeChanged", layout)
  end
  layout()
  return t
end

-- Horizontal or vertical carved edge, tiled between two points and cropped to fit.
local function TileEdge(f, key, tileW, tileH, vertical, thickness)
  local pool = {}
  local function layout(x0, y0, x1, y1)
    local span = vertical and math.abs(y1 - y0) or math.abs(x1 - x0)
    local step = vertical and tileH or tileW
    if span < 2 or step < 2 then
      for _, t in ipairs(pool) do t:Hide() end
      return
    end
    local nNeed = math.max(1, math.ceil(span / step))
    for i = 1, nNeed do
      local tex = pool[i]
      if not tex then
        tex = f:CreateTexture(nil, "BORDER", nil, 3)
        T.SetTex(tex, key, 0.35, 0.28, 0.16, 1)
        pool[i] = tex
      end
      local along = (i - 1) * step
      local remain = math.min(step, span - along)
      tex:ClearAllPoints()
      if vertical then
        tex:SetSize(thickness, remain)
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y0 - along)
        tex:SetTexCoord(0, 1, 0, remain / tileH)
      else
        tex:SetSize(remain, thickness)
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + along, -y0)
        tex:SetTexCoord(0, remain / tileW, 0, 1)
      end
      tex:Show()
    end
    for i = nNeed + 1, #pool do
      pool[i]:Hide()
    end
  end
  return layout, pool
end

-- Nine-slice from the L-corner, a tileable beam, and a centered gemmed ornament.
function T.CarveBorder(f, opts)
  opts = opts or {}
  local cs = opts.cornerSize or 52
  local eh = opts.edge or 24
  local off = opts.cornerOffset or -1
  T.Corners(f, cs, off)
  f.nockEdgeLayout = f.nockEdgeLayout or {}
  if not f.nockEdgeLayout.top then
    f.nockEdgeLayout.top = TileEdge(f, "edge", 256, 64, false, eh)
    f.nockEdgeLayout.bot = TileEdge(f, "edge", 256, 64, false, eh)
    f.nockEdgeLayout.left = TileEdge(f, "edge_v", 64, 256, true, eh)
    f.nockEdgeLayout.right = TileEdge(f, "edge_v", 64, 256, true, eh)
    local orn = f:CreateTexture(nil, "OVERLAY", nil, 4)
    f.nockOrnament = orn
    local ornB = f:CreateTexture(nil, "OVERLAY", nil, 4)
    ornB:SetTexCoord(0, 1, 1, 0)
    f.nockOrnamentBot = ornB
  end
  local function layout()
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w < 8 or h < 8 then
      return
    end
    local inset = math.max(0, -off)
    local x0 = inset + cs - 2
    local x1 = w - inset - cs + 2
    local y0 = inset
    local y1 = h - inset - eh
    if x1 > x0 then
      f.nockEdgeLayout.top(x0, y0, x1, y0 + eh)
      f.nockEdgeLayout.bot(x0, y1, x1, y1 + eh)
    end
    local ey0 = inset + cs - 2
    local ey1 = h - inset - cs + 2
    if ey1 > ey0 then
      f.nockEdgeLayout.left(inset, ey0, inset + eh, ey1)
      f.nockEdgeLayout.right(w - inset - eh, ey0, w - inset, ey1)
    end
    local orn = f.nockOrnament
    local ornB = f.nockOrnamentBot
    if opts.ornament == false then
      if orn then orn:Hide() end
      if ornB then ornB:Hide() end
      return
    end
    local ow = math.max(64, math.min(512, (x1 - x0) - 8))
    local key = ow >= 360 and "ornamentWide" or "ornament"
    if orn then
      orn:ClearAllPoints()
      orn:SetSize(ow, eh + 8)
      orn:SetPoint("TOP", f, "TOP", 0, -inset + 2)
      T.SetTex(orn, key)
      orn:Show()
    end
    if ornB then
      ornB:ClearAllPoints()
      ornB:SetSize(ow, eh + 8)
      ornB:SetPoint("BOTTOM", f, "BOTTOM", 0, inset - 2)
      T.SetTex(ornB, key)
      ornB:Show()
    end
  end
  if f.HookScript then
    f:HookScript("OnSizeChanged", layout)
  end
  layout()
  f.nockCarveLayout = layout
  return f
end

-- Title plaque with a label in the empty wood field.
function T.TitlePlate(f, text, opts)
  opts = opts or {}
  local plate = f:CreateTexture(nil, "ARTWORK", nil, 5)
  plate:SetSize(opts.width or 480, opts.height or 58)
  plate:SetPoint("TOP", f, "TOP", 0, opts.y or 4)
  T.SetTex(plate, "title", 0.18, 0.12, 0.07, 1)
  f.nockTitlePlate = plate
  local fs = f:CreateFontString(nil, "OVERLAY", opts.font or "GameFontNormalLarge")
  T.EnsureFont(fs, opts.fontSize or opts.font or "GameFontNormalLarge")
  if opts.fontSize and fs.SetFont then
    T.EnsureFont(fs, opts.fontSize, "OUTLINE")
  end
  fs:SetPoint("CENTER", plate, "CENTER", 0, 1)
  fs:SetText(text or "Nock")
  local tc = (T.color and T.color.title) or { 0.96, 0.93, 0.82 }
  fs:SetTextColor(tc[1] or 0.96, tc[2] or 0.93, tc[3] or 0.82)
  f.nockTitleFS = fs
  return plate, fs
end

-- Solid underlay so a leftover Blizzard backdrop can never show through.
function T.SolidFill(f, r, g, b, a)
  if not f.nockSolidFill then
    local tex = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    tex:SetAllPoints(f)
    f.nockSolidFill = tex
  end
  local c = T.color and T.color.panel
  f.nockSolidFill:SetColorTexture(
    r or (c and c[1]) or 0.07,
    g or (c and c[2]) or 0.05,
    b or (c and c[3]) or 0.03,
    a or 1
  )
  f.nockSolidFill:Show()
  return f.nockSolidFill
end

-- Hide a Portrait/Button frame's default chrome so our carved border can sit on top.
function T.HideDefaultChrome(f)
  if not f then
    return
  end
  -- Drop any BackdropTemplate skin first; leftover tan TitleBg is what
  -- showed through the old Gunsmith window.
  if f.SetBackdrop then
    pcall(f.SetBackdrop, f, nil)
  end
  local names = {
    "NineSlice", "Bg", "TitleBg", "TopTileStreaks", "PortraitContainer",
    "portrait", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft",
    "InsetBorderRight", "CloseButtonBorder", "Background", "Backdrop",
    "Center", "Overlay",
  }
  for _, name in ipairs(names) do
    local r = f[name]
    if type(r) == "table" and r.Hide then
      pcall(r.Hide, r)
      if r.SetAlpha then pcall(r.SetAlpha, r, 0) end
    end
  end
  local tc = f.TitleContainer
  if type(tc) == "table" then
    if tc.Hide then pcall(tc.Hide, tc) end
    if tc.TitleText and tc.TitleText.Hide then pcall(tc.TitleText.Hide, tc.TitleText) end
  end
  local tt = f.TitleText
  if type(tt) == "table" and tt.Hide then
    pcall(tt.Hide, tt)
  end
  -- Forever can leave unnamed tan regions on ButtonFrameTemplate.
  if f.GetRegions then
    local regions = { f:GetRegions() }
    for _, r in ipairs(regions) do
      if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetDrawLayer then
        local layer = r:GetDrawLayer()
        local isOurs = r._nockTexKey or (f.nockSolidFill and r == f.nockSolidFill)
          or (f.nockTitlePlate and r == f.nockTitlePlate)
          or (f.nockOrnament and r == f.nockOrnament)
          or (f.nockOrnamentBot and r == f.nockOrnamentBot)
        if not isOurs and (layer == "BACKGROUND" or layer == "BORDER") and r.Hide then
          -- Don't hide textures we later parent as fills; those are tagged.
          pcall(r.Hide, r)
        end
      end
    end
  end
end

-- Replace a Blizzard close button's art with the carved X (normal + hover).
function T.SkinClose(btn, size)
  if not btn then
    return
  end
  size = size or 24
  pcall(btn.SetSize, btn, size, size)
  pcall(btn.SetNormalTexture, btn, T.tex.close)
  pcall(btn.SetPushedTexture, btn, T.tex.closeHover)
  pcall(btn.SetDisabledTexture, btn, T.tex.close)
  if btn.SetHighlightTexture then
    pcall(btn.SetHighlightTexture, btn, T.tex.closeHover, "BLEND")
  end
  local function tidy(tex, alpha)
    if not tex then
      return
    end
    pcall(tex.SetTexCoord, tex, 0, 1, 0, 1)
    pcall(tex.ClearAllPoints, tex)
    pcall(tex.SetAllPoints, tex, btn)
    if alpha and tex.SetAlpha then
      pcall(tex.SetAlpha, tex, alpha)
    end
  end
  if btn.GetNormalTexture then tidy(btn:GetNormalTexture()) end
  if btn.GetPushedTexture then tidy(btn:GetPushedTexture()) end
  if btn.GetHighlightTexture then tidy(btn:GetHighlightTexture()) end
  if btn.GetDisabledTexture then tidy(btn:GetDisabledTexture(), 0.45) end
  -- Some Forever/retail close buttons are atlas-driven; hide leftover regions.
  if btn.GetRegions then
    local regions = { btn:GetRegions() }
    for _, r in ipairs(regions) do
      if r and r.GetObjectType and r:GetObjectType() == "Texture" then
        local ntex = btn.GetNormalTexture and btn:GetNormalTexture()
        local ptex = btn.GetPushedTexture and btn:GetPushedTexture()
        local htex = btn.GetHighlightTexture and btn:GetHighlightTexture()
        if r ~= ntex and r ~= ptex and r ~= htex and r.Hide then
          -- leave it; hiding unknown regions can kill the hit script
        end
      end
    end
  end
  return btn
end

-- Tint every region of a Blizzard NineSlice border silver-green (safe no-op if absent).
function T.TintNineSlice(f)
  local ns = type(f) == "table" and f.NineSlice
  if type(ns) ~= "table" or type(ns.GetRegions) ~= "function" then
    return
  end
  local regions = { ns:GetRegions() }
  for _, r in ipairs(regions) do
    if r and r.SetVertexColor then
      pcall(r.SetVertexColor, r, 0.62, 0.80, 0.72)
    end
  end
end

-- Keybind for the Hunting Notes card (Bindings.xml).
BINDING_HEADER_NOCK = "Nock"
BINDING_NAME_NOCK_NOTES = "Show or hide Hunting Notes"
BINDING_NAME_NOCK_WINDOW = "Open Nock"
BINDING_NAME_NOCK_STYLE = "Switch HUD style (Emerald / Gunsmith)"
BINDING_NAME_NOCK_THREAT_UNLOCK = "Unlock or lock the threat meter"
BINDING_NAME_NOCK_PINS = "Show or hide hunter map pins"
BINDING_NAME_NOCK_QUIVER = "Show or hide the quiver counter"
_G["BINDING_NAME_CLICK NockFeedButton:LeftButton"] = "Feed pet (best food in your bags)"
BINDING_NAME_NOCK_KIT = "Open Hunter Tools (Field Kit)"
BINDING_NAME_NOCK_SUPPLIES = "Check ammo, pet food, food and water"
BINDING_NAME_NOCK_TRAIN = "What is waiting at the trainer"
BINDING_NAME_NOCK_TAME_PINS = "Show or hide rare tameable beast pins"
BINDING_NAME_NOCK_TRACKER = "Show or hide the kill / XP tracker"
BINDING_NAME_NOCK_UNLOCK = "Unlock or lock all Nock frames (move them)"
BINDING_NAME_NOCK_TEST_ALERTS = "Show test alerts"
BINDING_NAME_NOCK_MUTE_TOOLS = "Mute or unmute hunter tool alerts"

function _G.Nock_ToggleNotes()
  local Nock = _G.Nock
  local MR = Nock and Nock.UI and Nock.UI.MyRot
  if MR and MR.SetCardShown then
    MR.SetCardShown(not MR.IsCardShown())
  end
end

function _G.Nock_ToggleWindow()
  local Nock = _G.Nock
  if Nock and Nock.UI and Nock.UI.Toggle then
    Nock.UI.Toggle()
  end
end

