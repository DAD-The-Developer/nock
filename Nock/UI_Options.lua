--[[
  Nock 3.0: a few plain on/off toggles, plus Restore Blizzard bars.
  Nothing here uses jargon. Buttons that change keys are greyed in combat.
]]

local Nock = _G.Nock
local UI = Nock and Nock.UI
if not (UI and UI.lib) then
  return
end

local function EnsureFont(fs, sizeOrObject, flags)
  local T = _G.NockTheme
  if T and T.EnsureFont then
    return T.EnsureFont(fs, sizeOrObject, flags)
  end
  if not fs then
    return false
  end
  local path = (type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
  local size = type(sizeOrObject) == "number" and sizeOrObject or 12
  if fs.SetFont then
    local ok, res = pcall(fs.SetFont, fs, path, size, flags or "OUTLINE")
    if ok and res ~= false then
      return true
    end
  end
  return false
end
local L = UI.lib
local MR = UI.MyRot
local G = UI.Glow
local S = Nock.Setup

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function Section(page, text, x, y, width)
  local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  local header = 20
  if L.WindowMetrics then
    header = L.WindowMetrics().header or 20
  end
  EnsureFont(fs, header, "OUTLINE")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  fs:SetTextColor(0.95, 0.88, 0.55)
  local line = page:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.82, 0.70, 0.35, 0.55)
  line:SetHeight(2)
  line:SetWidth(width or 640)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
  return fs
end

local NOTES_KEY = "CTRL-N"

local function NotesKey()
  return GetBindingKey and GetBindingKey("NOCK_NOTES") or nil
end

-- Binds Ctrl-N to Hunting Notes only if nothing else uses it. Never overrides your keys.
local function UseCtrlN()
  if L.InCombat() then
    return L.Print("Leave combat first.")
  end
  if NotesKey() then
    return L.Print("Hunting Notes is already on " .. L.KeyLabel(NotesKey()) .. ". Change it in Key Bindings > AddOns > Nock.")
  end
  local cur = GetBindingAction and GetBindingAction(NOTES_KEY, true) or ""
  if cur ~= "" and cur ~= nil then
    return L.Print("Ctrl-N already does " .. tostring(cur) .. ", so Nock left it alone. Pick a key in Key Bindings > AddOns > Nock.")
  end
  if Nock.Binds then Nock.Binds.EnsureFirst() end
  if SetBinding and SetBinding(NOTES_KEY, "NOCK_NOTES") ~= false then
    if SaveBindings and GetCurrentBindingSet then
      SaveBindings(GetCurrentBindingSet())
    end
    L.Print("Ctrl-N now shows or hides Hunting Notes.")
  end
  UI.Refresh()
end

local function Build(page)
  page.footer = "These can all be turned off."
  page.checks = {}
  local scroll, child = L.MakeScroll(page, -8, 8)
  page.scroll, page.child = scroll, child
  local m = L.WindowMetrics and L.WindowMetrics() or { body = 16, content = L.CONTENT_W or 848 }
  local cw = (m.content or L.CONTENT_W or 848) - 16
  local function add(label, tip, get, set)
    local cb = L.CheckBox(child, label, tip, get, set)
    cb:SetPoint("TOPLEFT", 8, child._y)
    if cb.label then
      EnsureFont(cb.label, m.body or 16, "OUTLINE")
      cb.label:ClearAllPoints()
      cb.label:SetPoint("LEFT", cb, "RIGHT", 8, 0)
      cb.label:SetWidth(cw - 54)
      cb.label:SetJustifyH("LEFT")
      cb.label:SetWordWrap(true)
    end
    page.checks[#page.checks + 1] = cb
    -- 3.5.0: rows grow with their label so wrapped text never overlaps.
    local lh = cb.label and tonumber((cb.label:GetStringHeight())) or 0
    child._y = child._y - math.max(36, lh + 16)
    return cb
  end

  child._y = -8
  Section(child, "On screen", 8, child._y, cw - 16)
  child._y = child._y - 40

  add("Show my bar", "The bow-and-arrow bar with your shots, and a small row under it for pet, Aspects, traps and items. Click a button or press its key.",
    function() return DB().overlay ~= false end, function(on) Nock.SetOverlayShown(on) end)
  add("Nock XP bar", "A slim experience bar under your keys. Hidden at max level.",
    function() return DB().nockXP ~= false end,
    function(on)
      if Nock.SetNockXP then
        Nock.SetNockXP(on)
      else
        DB().nockXP = on
      end
    end)
  add("Nock pet bar", "Your pet's commands and skills above the bow. Active stances, commands and autocast light up; off ones stay dim. Includes Train Pet and Feed Pet when you know them, plus happiness and training points. Hidden when you have no pet.",
    function() return DB().nockPet ~= false end,
    function(on)
      if Nock.SetNockPet then
        Nock.SetNockPet(on)
      else
        DB().nockPet = on
      end
    end)
  add("Threat meter", "Two bars, you and your pet, showing how close you are to pulling your target. Hidden when you are not in a fight. The pet should keep aggro — the meter warns you if you are about to pull it off.",
    function() return DB().nockThreat ~= false end,
    function(on)
      if Nock.SetNockThreat then
        Nock.SetNockThreat(on)
      else
        DB().nockThreat = on
      end
    end)

  -- 3.9.0: quest item drop chances (tooltip + Dashboard).
  local QDrops = Nock.QuestDrops
  if QDrops then
    add("Quest item drop chances", "While a quest still needs an item that drops from mobs: the mob's tooltip shows the drop chance (Quest: Tough Wolf Meat 4/8, drop 80%), and the Dashboard shows the best mob under the objective. Classic loot data; Forever may differ. No % where no source has one. Also /nock drops on | off.",
      function() return QDrops.Enabled() end, function(on) QDrops.SetEnabled(on) end)
  end

  -- 3.7.0: the Dashboard (bags, ammo, tracked quests), for a corner of the
  -- screen or a second monitor.
  local Dash = Nock.Dash
  if Dash then
    add("Dashboard: bags, ammo and tracked quests", "A compact panel with free bag slots, ammo left (and about how many minutes of Auto Shot that is) and your tracked quests with their progress. Park it in a corner, or mirror it to a second monitor with OBS. Also /nock dash.",
      function() return Dash.IsShown() end, function(on) Dash.SetShown(on) end)
    add("   Unlock the dashboard (drag to move)", "Drag the dashboard anywhere, then turn this off to lock it. Locked, clicks pass straight through it. Also /nock dash unlock | lock | reset.",
      function() return Dash.IsUnlocked() end, function(on) Dash.SetUnlocked(on) end)
    add("   Solid dashboard background", "Fully opaque background, so it reads cleanly when mirrored to another screen. Off is the same see-through card as Nock's alerts.",
      function() return Dash.IsSolid() end, function(on) Dash.SetSolid(on) end)
    local dLab = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    EnsureFont(dLab, m.body or 16, "OUTLINE")
    dLab:SetPoint("TOPLEFT", 48, child._y)
    dLab:SetText("Size")
    dLab:SetTextColor(0.95, 0.88, 0.55)
    local dSeg = L.Segmented(child, {
      { "Small", "small" }, { "Normal", "normal" }, { "Large", "large" },
    }, function() return Dash.Size() end, function(val) Dash.SetSize(val) end,
      360, "How big the dashboard is. Large is the default.")
    dSeg:SetPoint("TOPLEFT", 120, child._y + 4)
    page.segs = page.segs or {}
    page.segs[#page.segs + 1] = dSeg
    child._y = child._y - 48
  end

  local sizeLab = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(sizeLab, m.body or 16, "OUTLINE")
  sizeLab:SetPoint("TOPLEFT", 12, child._y)
  sizeLab:SetText("Bar size")
  sizeLab:SetTextColor(0.95, 0.88, 0.55)
  local function CurSize()
    return (Nock.BarSize and Nock.BarSize()) or DB().barSize or "large"
  end
  local sizeSeg = L.Segmented(child, {
    { "Small", "small" }, { "Normal", "normal" }, { "Large", "large" },
  }, CurSize, function(val)
    if Nock.SetBarSize then
      Nock.SetBarSize(val)
    else
      DB().barSize = val
    end
    if L.ApplyWindowSize then
      L.ApplyWindowSize()
    end
  end, 360, "How big the bow, the row under it, and this window are. Large is the default. Changes apply out of combat.")
  sizeSeg:SetPoint("TOPLEFT", 120, child._y + 4)
  page.sizeSeg = sizeSeg
  child._y = child._y - 48

  local styleLab = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  EnsureFont(styleLab, m.body or 16, "OUTLINE")
  styleLab:SetPoint("TOPLEFT", 12, child._y)
  styleLab:SetText("Style")
  styleLab:SetTextColor(0.95, 0.88, 0.55)
  local function CurStyle()
    if Nock.StyleId then
      return Nock.StyleId() or "emerald"
    elseif _G.NockTheme and _G.NockTheme.StyleId then
      return _G.NockTheme.StyleId() or "emerald"
    end
    return DB().hudStyle or "emerald"
  end
  local styleSeg = L.Segmented(child, {
    { "Emerald", "emerald" }, { "Gunsmith", "gunsmith" },
  }, CurStyle, function(val, label)
    local id, why
    if Nock.SetStyle then
      id, why = Nock.SetStyle(val)
    elseif _G.NockTheme and _G.NockTheme.SetStyle then
      id, why = _G.NockTheme.SetStyle(val)
    else
      DB().hudStyle = val
    end
    if why == "combat" then
      L.Print("Style will switch to " .. (label or val) .. " when the fight ends.")
    end
  end, 360, "How the HUD looks. Emerald is the default bow. Gunsmith is the dwarven rifle. Layout and size stay the same. Changes wait until the fight ends if you are in combat.")
  styleSeg:SetPoint("TOPLEFT", 120, child._y + 4)
  page.styleSeg = styleSeg
  child._y = child._y - 48

  add("Show Nock button", "A small movable button on the screen. Left-click opens Nock. Hold Shift and drag to move it. Position is saved for this character. Also on the Escape menu, and as the Open Nock keybind.",
    function() return DB().showLauncher ~= false end,
    function(on)
      DB().showLauncher = on and true or false
      if Nock.Launcher and Nock.Launcher.Update then
        Nock.Launcher.Update()
      end
    end)

  add("Glow the next shot", "The next shot you should use lights up.",
    function() return G and G.Opt().glow end, function(on) if G then G.SetGlow(on) end end)
  add("Show 1, 2, 3 on the opening shots", "Small numbers on the first shots of your opener.",
    function() return G and G.Opt().numbers end, function(on) if G then G.SetNumbers(on) end end)
  add("Show cooldowns", "A dimmed button and a big number while it can't be used. The little pause after each shot still gets a sweep, but no number.",
    function() return DB().barCooldowns ~= false end, function(on) Nock.SetBarCooldowns(on) end)
  add("   Countdown numbers on cooldowns", "Whole seconds on a button while its cooldown runs. Off: the sweep only.",
    function() return DB().cdNumbers ~= false end, function(on) DB().cdNumbers = on and true or false end)
  add("   Soft highlight when a cooldown is ready", "One brief, calm glow when an ability with a cooldown of 8 seconds or more comes back, only if you can use it right now (mana, range, a target).",
    function() return DB().readyGlow ~= false end, function(on) DB().readyGlow = on and true or false end)
  add("Range shading on every button", "Shots turn a calm red when the target is out of range or inside the dead zone; melee skills light up only in melee range; Mend Pet and Intimidation dim when your pet can't use them. Aspects, traps and Feign Death are never shaded.",
    function() return DB().barTint ~= false end, function(on) Nock.SetBarTint(on) end)
  add("Restore Blizzard bars", "Shows the default action bars again. Nock's bar stays unless you turn it off. Waits until the fight ends if you are in combat.",
    function() return DB().hideBlizzardBars == false end,
    function(on)
      if Nock.ActionBars and Nock.ActionBars.SetEnabled then
        local ok, why = Nock.ActionBars.SetEnabled(not on)
        if why == "queued" then
          L.Print("Nock will " .. (on and "restore" or "hide") .. " the default action bars when the fight ends.")
        end
      else
        DB().hideBlizzardBars = not on
      end
    end)
  add("Mouse buttons for Wing Clip, Concussive and Feign Death", "Mouse 4 is Wing Clip, Mouse 5 is Concussive Shot, and a wheel click is Feign Death. Only empty mouse buttons are used. Scrolling still zooms the camera. Off puts Wing Clip on Shift-Z.",
    function() return DB().mouse ~= false end, function(on) if Nock.Keymap21 then Nock.Keymap21.SetMouse(on) else DB().mouse = on end end)

  child._y = child._y - 8
  Section(child, "Maps and ammo", 8, child._y, cw - 16)
  child._y = child._y - 40

  local P = Nock.Pins
  add("Hunter map pins", "Hunter trainers, pet trainers, stable masters, ammo, bow and gun, quiver and pet food vendors, hunter quests and flight paths on your minimap and world map, city and zone maps alike. Hover a vendor to see what it sells, with the best item for your level. Also /nock pins or the keybind.",
    function() return P and P.IsOn() end, function(on) if P then P.SetOn(on) end end)
  add("   On the minimap", "Pins on the minimap.",
    function() return P and P.MinimapOn() end, function(on) if P then P.SetMinimap(on) end end)
  add("   On the world map", "Pins on the big map (M) for the zone you are looking at.",
    function() return P and P.WorldOn() end, function(on) if P then P.SetWorld(on) end end)
  for _, k in ipairs(P and P.KINDS or {}) do
    local id = k.id
    add("   " .. k.label, "Show " .. string.lower(k.label) .. " on the maps.",
      function() return P.KindOn(id) end, function(on) P.SetKind(id, on) end)
    -- 3.10.0: flight path extras right under the Flight paths kind.
    local FL = Nock.Flights
    if id == "flight" and FL then
      add("      Flight routes on the continent map", "Thin lines between flight points that fly to each other on the Kalimdor and Eastern Kingdoms maps, brighter where you know both ends. Hover a point to light up its routes. Also /nock flights routes on | off.",
        function() return FL.RoutesOn() end, function(on) FL.SetRoutes(on) end)
      add("      Other faction's flight paths", "Also show the other faction's flight points and routes (grey). Off by default. Also /nock flights other on | off.",
        function() return FL.OtherOn() end, function(on) FL.SetOther(on) end)
    end
  end
  add("   Other faction too", "Also show the other faction's NPCs, greyed out. Off by default.",
    function() return P and P.HostileOn() end, function(on) if P then P.SetHostile(on) end end)
  if P and P.PetFoodAll then
    add("   Every pet food vendor", "Off: only vendors selling food your current pet eats (nothing shows without a pet). On: every pet food vendor. The tooltip always marks what your pet eats.",
      function() return P.PetFoodAll() end,
      function(on) NockCharDB.pins = NockCharDB.pins or {}; NockCharDB.pins.petfoodAll = on and true or nil; P.Refresh() end)
    local lab = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    EnsureFont(lab, m.body or 16, "OUTLINE")
    lab:SetPoint("TOPLEFT", 40, child._y)
    lab:SetText("Minimap pins per kind")
    lab:SetTextColor(0.95, 0.88, 0.55)
    local seg = L.Segmented(child, { { "Nearest 1", 1 }, { "Nearest 3", 3 }, { "All", 99 } },
      function() return P.MiniPerKind() end,
      function(v) NockCharDB.pins = NockCharDB.pins or {}; NockCharDB.pins.perKind = v; P.Refresh() end,
      300, "How many pins of each kind the minimap shows in range. Pins that would overlap fold into one; hover it to see them all.")
    seg:SetPoint("TOPLEFT", 280, child._y + 4)
    page.segs = page.segs or {}
    page.segs[#page.segs + 1] = seg
    child._y = child._y - 48
  end
  add("Quiver counter", "A quiver (or ammo pouch in Gunsmith) with your ammo count in big numbers. Green is well stocked, yellow is half, red means buy more. Hold Shift and drag to move it. Also /nock quiver.",
    function() return Nock.Quiver and Nock.Quiver.IsOn() end, function(on) if Nock.Quiver then Nock.Quiver.SetOn(on) end end)

  -- 3.5.0 alerts: global controls, then a switch per category and per alert,
  -- generated from the alert registry (Data_Alerts.lua).
  local A = Nock.Alerts
  if A then
    child._y = child._y - 8
    Section(child, "Alerts", 8, child._y, cw - 16)
    child._y = child._y - 40
    local function SegRow(label, items, get, set, tip)
      local lab = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      EnsureFont(lab, m.body or 16, "OUTLINE")
      lab:SetPoint("TOPLEFT", 12, child._y)
      lab:SetText(label)
      lab:SetTextColor(0.95, 0.88, 0.55)
      local seg = L.Segmented(child, items, get, set, 300, tip)
      seg:SetPoint("TOPLEFT", 200, child._y + 4)
      page.segs = page.segs or {}
      page.segs[#page.segs + 1] = seg
      child._y = child._y - 48
      return seg
    end
    SegRow("Alert size", { { "Small", 0.85 }, { "Normal", 1 }, { "Large", 1.15 } },
      function()
        local v = A:Scale()
        if v < 0.93 then return 0.85 elseif v > 1.07 then return 1.15 end
        return 1
      end,
      function(v) A:SetScale(v); A:Test() end,
      "How big the alert toasts are, on top of the bar size.")
    SegRow("On screen at once", { { "One", 1 }, { "Two", 2 } },
      function() return A:MaxVisible() end, function(v) A:SetMax(v) end,
      "More alerts wait their turn in a queue; critical ones always go first.")
    add("Quiet mode", "Only critical alerts (Feign Death resisted, Wing Clip fell off, dead zone in PvP). No sound. Also /nock alerts quiet.",
      function() return A:IsQuiet() end, function(on) A:SetQuiet(on) end)
    add("Sound on critical alerts", "One short warning sound, only for critical alerts.",
      function() return A:SoundOn() end, function(on) A:SetSound(on) end)
    add("Soft edge flashes", "A brief tint at the screen edge for a resisted Feign Death or the dead zone.",
      function() return not (NockCharDB.alerts and NockCharDB.alerts.flash == false) end,
      function(on)
        NockCharDB.alerts = NockCharDB.alerts or {}
        if on then NockCharDB.alerts.flash = nil else NockCharDB.alerts.flash = false end
      end)
    local test = L.PanelButton(child, "Test alerts", 160, {
      tip = "Shows a critical, a warning and an info alert where they will appear. Also /nock alerts test.",
      onClick = function() A:Test() end,
    })
    test:SetHeight(26)
    test:SetPoint("TOPLEFT", 12, child._y)
    child._y = child._y - 40
    for _, cat in ipairs(A.catOrder or {}) do
      local ids = {}
      for _, id in ipairs(A.categories[cat] or {}) do
        if not A.defs[id].hidden then
          ids[#ids + 1] = id
        end
      end
      if #ids > 0 then
        add((A.CATEGORY_LABELS and A.CATEGORY_LABELS[cat]) or cat, "Every alert in this group. /nock alerts " .. cat .. " on | off",
          function() return A:CategoryOn(cat) end, function(on) A:SetCategory(cat, on) end)
        for _, id in ipairs(ids) do
          local d = A.defs[id]
          local pr = d.priority == "critical" and "|cffe0605acritical|r" or (d.priority == "warning" and "|cfff2b84awarning|r" or "|cff7fbfefinfo|r")
          add("      " .. (d.label or d.title or id), pr .. "  ·  /nock alerts " .. id .. " on | off",
            function() return A:CategoryOn(cat) and A:AlertOn(id) end, function(on) A:SetAlert(id, on) end)
        end
      end
    end
  end

  -- 3.4.0 hunter tools: one switch per tool, then its own settings.
  local Core = Nock.Core
  if Core and Core.order and #Core.order > 0 then
    child._y = child._y - 8
    Section(child, "Hunter tools", 8, child._y, cw - 16)
    child._y = child._y - 40
    add("Unlock frames (move them)", "Outlines every movable Nock frame — tracker, quiver, threat meter, range and PvP readouts, alerts — so you can drag them. Turn off to lock. Locks itself in combat and on login. Also /nock unlock, /nock lock, /nock reset positions, or the keybind.",
      function() return Core.Unlocked and Core.Unlocked() end, function(on) if Core.SetUnlocked then Core.SetUnlocked(on) end end)
    add("Mute all hunter tool alerts", "Silences every alert toast and edge flash from the hunter tools. The readouts stay. Also /nock tools mute or the keybind.",
      function() return Core.Muted() end, function(on) if Core.Muted() ~= (on and true or false) then Core.Slash("mute") end end)
    add("Endgame mode at level 60", "At 60 the guide and tracker switch to raid-night checklists and gold per hour, and leveling-only nudges step aside. Off keeps leveling mode. /nock tools endgame auto | on | off.",
      function() return Core.EndgameSetting() ~= "off" end,
      function(on) _G.NockCharDB = _G.NockCharDB or {}; _G.NockCharDB.endgame = on and "auto" or "off"; Core.ProfileChanged("level") end)
    add("PvP mode in battlegrounds and arenas", "In a battleground or arena: pet feeding, route, trainer and tracker nags go quiet, dead zone and Wing Clip cues get louder, and the PvP readout shows enemy class, sting, slows, big buffs and your CC cooldowns. /nock tools pvp on | off.",
      function() return Core.PvPSetting() end,
      function(on) if Core.PvPSetting() ~= (on and true or false) then Core.Slash("pvp") end end)
    for _, id in ipairs(Core.order) do
      local m = Core.modules[id]
      add(m.name, (m.desc or "") .. "  /nock " .. (m.cmd and m.cmd[1] or id),
        function() return Core.Get(id, "on") ~= false end, function(on) Core.Set(id, "on", on and true or false) end)
      for _, o in ipairs(m.options or {}) do
        local key = o.key
        add("   " .. o.label, o.tip or o.label,
          function() local v = Core.Get(id, key); return v == true or (v ~= false and v ~= nil) end,
          function(on) Core.Set(id, key, on and true or false) end)
      end
    end
  end

  -- 3.8.0: keybinds: Nock layout or your own, and the keybind backup.
  local BK = Nock.Binds
  if BK then
    child._y = child._y - 8
    Section(child, "Keybind backup", 8, child._y, cw - 16)
    child._y = child._y - 40
    add("Use my own keybinds", "Nock sets no keys at all (no Ctrl-G, Ctrl-Z, Caps Lock ...). Every Nock button shows the key you already use for that spell. Off = " .. Nock.Binds.LAYOUT_TEXT .. " Also /nock binds own on | off.",
      function() return BK.Own() end, function(on) BK.SetOwn(on); UI.Refresh() end)
    local info = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    EnsureFont(info, math.max(13, (m.body or 16) - 2), "OUTLINE")
    info:SetPoint("TOPLEFT", 12, child._y + 8)
    info:SetWidth(cw - 24)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(true)
    info:SetTextColor(0.70, 0.76, 0.68)
    page.backupInfo = info
    child._y = child._y - 44
    local bw = 180
    local backup = L.PanelButton(child, "Back up now", bw, {
      lock = false,
      tip = "Saves a copy of every keybind you have now. Only reads; changes nothing. Nock keeps the first copy for good, plus your newest 5.",
      onClick = function()
        local _, msg = BK.Backup()
        L.Print(msg)
        UI.Refresh()
      end,
    })
    backup:SetHeight(28)
    backup:SetPoint("TOPLEFT", 12, child._y)
    local restore = L.PanelButton(child, "Restore...", bw, {
      lock = true,
      tip = "Puts back every keybind from the first copy, after you confirm. Out of combat only. /nock binds restore 2 picks another copy (/nock binds list).",
      onClick = function()
        BK.ConfirmRestore(1)
      end,
    })
    restore:SetHeight(28)
    restore:SetPoint("LEFT", backup, "RIGHT", 10, 0)
    page.backupBtn, page.restoreBtn = backup, restore
    child._y = child._y - 44
  end

  child._y = child._y - 8
  Section(child, "Extras", 8, child._y, cw - 16)
  child._y = child._y - 40

  add("Remind me to spend talent points", "A button under the minimap while you have points to spend.",
    function() return DB().talentReminder ~= false end, function(on) DB().talentReminder = on; if S and S.UpdateTalentButton then S.UpdateTalentButton() end end)

  -- 3.6.0: dedicated Wing Clip and Hunter's Mark keys (Keys_Dedicated.lua).
  local DK = Nock.Dedicated
  if DK then
    add("Dedicated Wing Clip and Hunter's Mark keys",
      "One key each that always casts your highest rank. Nock suggests Caps Lock for Wing Clip and ` (above Tab) for Hunter's Mark, only if those keys are empty and you have not picked your own. Pick your own in Key Bindings > AddOns > Nock. Nock never saves over your keybinds.",
      function() return DK.Enabled() end, function(on) DK.SetEnabled(on); UI.Refresh() end)
    local dk = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    EnsureFont(dk, math.max(13, (m.body or 16) - 2), "OUTLINE")
    dk:SetPoint("TOPLEFT", 12, child._y + 8)
    dk:SetWidth(cw - 24)
    dk:SetJustifyH("LEFT")
    dk:SetWordWrap(true)
    dk:SetTextColor(0.70, 0.76, 0.68)
    page.dedicatedHint = dk
    child._y = child._y - 40
  end

  local function Action(text, width, opts, dy)
    local b = L.PanelButton(child, text, width, opts)
    b:SetHeight(28)
    b:SetPoint("TOPLEFT", 12, child._y)
    child._y = child._y - (dy or 36)
    return b
  end

  local restore = Action("Restore my old keys", 220, {
    lock = true,
    tip = "Puts back the keys you had before Nock first filled them.",
    onClick = function()
      L.Confirm("NOCK_RESTORE_V2", "Put back the keys you had before Nock?", function()
        if Nock.RestoreKeys then
          Nock.RestoreKeys()
        end
      end)
    end,
  })

  local notes = Action("Show Hunting Notes", 220, {
    tip = "Shows the Hunting Notes card above the bar. Hold Alt over the bar to just peek.",
    onClick = function()
      if MR then
        MR.SetCardShown(not MR.IsCardShown())
      end
      UI.Refresh()
    end,
  })
  page.notesBtn = notes

  Action("What's new", 220, {
    tip = "What changed in this version of Nock, and earlier ones. Also /nock new.",
    onClick = function()
      if Nock.WhatsNew then
        Nock.WhatsNew.Show("news")
      end
    end,
  })

  local ctrln = Action("Use Ctrl-N", 220, {
    lock = true,
    tip = "Makes Ctrl-N show or hide Hunting Notes, only if Ctrl-N is free.",
    onClick = UseCtrlN,
  })
  page.ctrlnBtn = ctrln

  Action("Reset bar position", 220, {
    lock = true,
    tip = "Moves the bar back to the bottom center of the screen.",
    onClick = function()
      if Nock.ResetBarPosition then
        Nock.ResetBarPosition()
      end
      DB().cardFree = nil
      if MR and MR.AnchorCard then
        MR.AnchorCard()
      end
    end,
  })

  local all = Action("More options", 220, {
    tip = "Shows every tab. Click again for the simple view.",
    onClick = function()
      UI.SetView((UI.IsSimple and UI.IsSimple()) and "advanced" or "simple")
    end,
  })
  page.allBtn = all

  local hint = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  EnsureFont(hint, math.max(13, (m.body or 16) - 2), "OUTLINE")
  hint:SetPoint("TOPLEFT", 12, child._y)
  hint:SetWidth(cw - 24)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(0.70, 0.76, 0.68)
  page.keyHint = hint
  child._y = child._y - 48
  child:SetHeight(math.max(20, -child._y + 16))
  return page
end

UI.extraPages = UI.extraPages or {}
UI.extraPages.options = Build
L.RefreshPage.options = function(page)
  for _, cb in ipairs(page.checks or {}) do
    cb:Sync()
  end
  if page.sizeSeg and page.sizeSeg.Sync then
    page.sizeSeg:Sync()
  end
  if page.styleSeg and page.styleSeg.Sync then
    page.styleSeg:Sync()
  end
  for _, seg in ipairs(page.segs or {}) do
    if seg.Sync then
      seg:Sync()
    end
  end
  if page.notesBtn then
    page.notesBtn:SetText((MR and MR.IsCardShown()) and "Hide Hunting Notes" or "Show Hunting Notes")
  end
  if page.allBtn then
    page.allBtn:SetText((UI.IsSimple and UI.IsSimple()) and "More options" or "Fewer options")
  end
  if page.backupInfo and Nock.Binds then
    local BK = Nock.Binds
    local list = BK.List()
    local first = list[1]
    if first then
      page.backupInfo:SetText("First backup: " .. (first.date or "?") .. " (" .. (first.char or "?") .. ", " .. (first.count or 0)
        .. " keys, " .. BK.SetName(first.set) .. " set)." .. (#list > 1 and ("  Latest: " .. (list[#list].date or "?") .. ".  " .. (#list - 1) .. " manual.") or ""))
    else
      page.backupInfo:SetText("No backup yet. Nock makes one as soon as the game has loaded your keybinds.")
    end
  end
  if page.dedicatedHint and Nock.Dedicated then
    page.dedicatedHint:SetText(Nock.Dedicated.Summary())
  end
  if page.keyHint then
    local k = NotesKey()
    page.keyHint:SetText(k and ("Hunting Notes key: " .. L.KeyLabel(k) .. ".  Hold Alt over the key bar to peek.")
      or "Hunting Notes has no key yet. Hold Alt over the key bar to peek, or click Use Ctrl-N.")
  end
  if page.child and page.child._y then
    page.child:SetHeight(math.max(20, -page.child._y + 16))
  end
end
