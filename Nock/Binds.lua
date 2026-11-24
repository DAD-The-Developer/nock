--[[
  Nock 3.8.0: keybind backup, restore, and "Use my own keybinds".

  Backup
    The first time this version loads (and before Nock sets any layout key),
    Nock copies every keybind you have: each action's two keys from
    GetNumBindings / GetBinding, plus which set is in use (account or
    character, GetCurrentBindingSet). It is stored in NockCharDB.keyBackup
    with the date and the character name. That "first" copy is never
    overwritten. /nock binds backup (or Options > Keybind backup) adds a
    manual copy; Nock keeps the newest MAX_MANUAL of those.
    Taking a backup only reads. It never changes a key.

  Restore
    /nock binds restore [n] or the Restore button, after a confirm popup.
    Out of combat only. Every key goes back to what the copy says (keys
    bound since then are cleared), with SetBinding, then SaveBindings on the
    copy's set. Nock then switches to "Use my own keybinds" so it adds no
    keys of its own on top. Nothing else ever changes keys here.

  Use my own keybinds (NockCharDB.ownBinds)
    Nock sets no layout keys at all: no override binds (Ctrl-G, Ctrl-Z,
    Caps Lock ...), no filling of empty keys. Each Nock button shows the key
    you already use for that spell: its Nock Key Bindings entry, a direct
    spell or macro bind, or the key of the action bar slot holding it.
    Switching modes never calls SetBinding or SaveBindings.
]]

local Nock = _G.Nock
if not Nock then
  return
end

local B = {}
Nock.Binds = B

B.MAX_MANUAL = 5
B.ACCOUNT, B.CHARACTER = 1, 2

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

local function Say(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff8fd18fNock|r " .. tostring(msg))
  end
end
B.Say = Say

local function InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end
B.InCombat = InCombat

local function Store()
  local db = DB()
  db.keyBackup = db.keyBackup or {}
  db.keyBackup.manual = db.keyBackup.manual or {}
  return db.keyBackup
end

local function CharName()
  local n = UnitName and UnitName("player") or "?"
  local r = GetRealmName and GetRealmName() or nil
  if r and r ~= "" then
    return tostring(n) .. "-" .. tostring(r)
  end
  return tostring(n)
end

local function SetNow()
  if GetCurrentBindingSet then
    local ok, s = pcall(GetCurrentBindingSet)
    if ok and (s == B.ACCOUNT or s == B.CHARACTER) then
      return s
    end
  end
  return B.ACCOUNT
end

function B.SetName(s)
  return s == B.CHARACTER and "character" or "account"
end

-- GetBinding only lists named actions (Key Bindings window entries).
-- Direct spell / macro / item / click binds ("SPELL Arcane Shot") are not
-- in that list, so every key below is also read with GetBindingAction.
local BASE_KEYS = {}
do
  for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"):gmatch(".") do
    BASE_KEYS[#BASE_KEYS + 1] = c
  end
  for i = 1, 12 do
    BASE_KEYS[#BASE_KEYS + 1] = "F" .. i
  end
  for i = 0, 9 do
    BASE_KEYS[#BASE_KEYS + 1] = "NUMPAD" .. i
  end
  for _, k in ipairs({ "`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "SPACE", "TAB", "CAPSLOCK",
    "ESCAPE", "ENTER", "BACKSPACE", "INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN",
    "UP", "DOWN", "LEFT", "RIGHT", "NUMPADDIVIDE", "NUMPADMULTIPLY", "NUMPADMINUS", "NUMPADPLUS",
    "NUMPADDECIMAL", "NUMLOCK", "PRINTSCREEN", "SCROLLLOCK", "PAUSE",
    "BUTTON1", "BUTTON2", "BUTTON3", "BUTTON4", "BUTTON5", "MOUSEWHEELUP", "MOUSEWHEELDOWN" }) do
    BASE_KEYS[#BASE_KEYS + 1] = k
  end
end
local MODS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
function B.AllKeys()
  if not B.allKeys then
    local t = {}
    for _, m in ipairs(MODS) do
      for _, k in ipairs(BASE_KEYS) do
        t[#t + 1] = m .. k
      end
    end
    B.allKeys = t
  end
  return B.allKeys
end

local function BaseAction(k)
  if not GetBindingAction then
    return ""
  end
  local ok, a = pcall(GetBindingAction, k)
  if ok and type(a) == "string" then
    return a
  end
  return ""
end

-- Reads every bound key. Returns the copy, or nil when the game has not
-- loaded keybinds yet (then nothing is stored).
function B.Read()
  if not (GetNumBindings and GetBinding) then
    return nil
  end
  local okn, n = pcall(GetNumBindings)
  if not okn or type(n) ~= "number" or n <= 0 then
    return nil
  end
  local binds, count = {}, 0
  for i = 1, n do
    -- Forever 1.60.1 (as the Blizzard key binding UI): action, category, key1, key2
    local ok, cmd, _, k1, k2 = pcall(GetBinding, i)
    if ok and type(cmd) == "string" and cmd ~= "" then
      local keys = {}
      for _, k in ipairs({ k1, k2 }) do
        if type(k) == "string" and k ~= "" then
          -- Saved binds only: skip a key whose own binding is something else
          -- (an addon's temporary override, never yours).
          local base = GetBindingAction and GetBindingAction(k) or nil
          if base == nil or base == "" or base == cmd then
            keys[#keys + 1] = k
          end
        end
      end
      if #keys > 0 then
        binds[cmd] = keys
        count = count + #keys
      end
    end
  end
  -- Direct binds (spell, macro, item, click) and anything else on a key.
  local have = {}
  for cmd, keys in pairs(binds) do
    for _, k in ipairs(keys) do
      have[k] = true
    end
  end
  for _, k in ipairs(B.AllKeys()) do
    if not have[k] then
      local a = BaseAction(k)
      if a ~= "" then
        binds[a] = binds[a] or {}
        table.insert(binds[a], k)
        have[k] = true
        count = count + 1
      end
    end
  end
  if count == 0 then
    return nil
  end
  local t = time and time() or 0
  return {
    time = t,
    date = date and date("%Y-%m-%d %H:%M", t) or tostring(t),
    char = CharName(),
    set = SetNow(),
    version = Nock.Version,
    count = count,
    binds = binds,
  }
end

-- The first copy, taken once and kept for good. Safe to call any time.
function B.EnsureFirst()
  local st = Store()
  if st.first then
    return true
  end
  local snap = B.Read()
  if not snap then
    return false
  end
  snap.first = true
  st.first = snap
  Say("saved a copy of all your keybinds (" .. snap.count .. " keys, " .. B.SetName(snap.set)
    .. " set). Get them back any time: /nock binds restore")
  if not B.Own() then
    Say("Keys: Nock layout (free keys only). Rather keep your own keybinds? /nock binds own on, or Options > Keybind backup.")
  end
  return true
end

function B.Backup()
  B.EnsureFirst()
  local snap = B.Read()
  if not snap then
    return false, "Keybinds are not loaded yet. Try again in a moment."
  end
  local st = Store()
  table.insert(st.manual, snap)
  while #st.manual > B.MAX_MANUAL do
    table.remove(st.manual, 1)
  end
  return true, "Backed up " .. snap.count .. " keys (" .. snap.date .. "). /nock binds list shows every copy."
end

-- List: 1 = the first copy, 2.. = manual copies, oldest first.
function B.List()
  local st = Store()
  local out = {}
  if st.first then
    out[#out + 1] = st.first
  end
  for _, s in ipairs(st.manual) do
    out[#out + 1] = s
  end
  return out
end

function B.Get(n)
  return B.List()[tonumber(n) or 1]
end

function B.Label(s, i)
  if not s then
    return "none"
  end
  return string.format("%s%s, %s, %d keys, %s set%s", i and (i .. ". ") or "", s.date or "?",
    s.char or "?", s.count or 0, B.SetName(s.set), s.first and " (first, kept)" or "")
end

-- One saved bind back on its key. Direct binds use their own setter.
function B.Bind(k, cmd)
  local spell = cmd:match("^SPELL (.+)$")
  if spell and SetBindingSpell then
    return SetBindingSpell(k, spell)
  end
  local macro = cmd:match("^MACRO (.+)$")
  if macro and SetBindingMacro then
    return SetBindingMacro(k, macro)
  end
  local item = cmd:match("^ITEM (.+)$")
  if item and SetBindingItem then
    return SetBindingItem(k, item)
  end
  local btn, mb = cmd:match("^CLICK ([^:]+):?(.*)$")
  if btn and SetBindingClick then
    return SetBindingClick(k, btn, mb ~= "" and mb or "LeftButton")
  end
  return SetBinding(k, cmd)
end

-- Restore. The only place in this file that changes keybinds.
function B.Restore(n)
  if InCombat() then
    return false, "Leave combat first. Keybinds can only change out of combat."
  end
  local snap = B.Get(n)
  if not snap or type(snap.binds) ~= "table" then
    return false, "No keybind backup to restore."
  end
  if not (SetBinding and SaveBindings and GetNumBindings and GetBinding) then
    return false, "This game client cannot change keybinds from an addon."
  end
  -- Turn Nock's own keys off first, so it adds nothing on top afterwards.
  B.SetOwn(true, true)
  local want = {}
  for cmd, keys in pairs(snap.binds) do
    for _, k in ipairs(keys) do
      want[k] = cmd
    end
  end
  local cleared, set, failed = 0, 0, 0
  local function clear(k, cmd)
    if type(k) == "string" and k ~= "" and want[k] ~= cmd then
      SetBinding(k)
      cleared = cleared + 1
    end
  end
  local okn, n2 = pcall(GetNumBindings)
  for i = 1, (okn and n2 or 0) do
    local ok, cmd, _, k1, k2 = pcall(GetBinding, i)
    if ok and type(cmd) == "string" then
      clear(k1, cmd)
      clear(k2, cmd)
    end
  end
  for _, k in ipairs(B.AllKeys()) do
    local a = BaseAction(k)
    if a ~= "" then
      clear(k, a)
    end
  end
  for k, cmd in pairs(want) do
    if BaseAction(k) ~= cmd then
      if B.Bind(k, cmd) == false then
        failed = failed + 1
      else
        set = set + 1
      end
    end
  end
  SaveBindings(snap.set or SetNow())
  B.lastRestore = { cleared = cleared, set = set, failed = failed }
  local msg = string.format("Restored your keybinds from %s (%s set). Nock is on \"Use my own keybinds\" now.", snap.date or "?", B.SetName(snap.set))
  if failed > 0 then
    msg = msg .. " " .. failed .. " key(s) point at things this game no longer has (an addon that is gone) and were skipped."
  end
  if Nock.UpdateOverlay then
    pcall(Nock.UpdateOverlay)
  end
  return true, msg
end

function B.ConfirmRestore(n)
  if InCombat() then
    Say("Leave combat first. Keybinds can only change out of combat.")
    return
  end
  local snap = B.Get(n)
  if not snap then
    Say("No keybind backup yet. /nock binds backup makes one.")
    return
  end
  local text = "Put back every keybind from " .. (snap.date or "?") .. " (" .. (snap.char or "?") .. ", "
    .. B.SetName(snap.set) .. " set)?\n\nKeys you bound after that are cleared. Nock switches to \"Use my own keybinds\"."
  if StaticPopupDialogs and StaticPopup_Show then
    StaticPopupDialogs.NOCK_BINDS_RESTORE = {
      text = text,
      button1 = YES or "Yes",
      button2 = CANCEL or "Cancel",
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      showAlert = true,
      preferredIndex = 3,
      OnAccept = function()
        local _, msg = B.Restore(n)
        Say(msg)
        if Nock.RefreshUI then
          pcall(Nock.RefreshUI)
        end
      end,
    }
    StaticPopup_Show("NOCK_BINDS_RESTORE")
  end
end

-- Use my own keybinds -------------------------------------------------------------

function B.Own()
  return DB().ownBinds == true
end

-- Never calls SetBinding or SaveBindings: only Nock's own temporary
-- override keys go away (or come back), and the bars repaint.
function B.SetOwn(on, quiet)
  on = on and true or false
  if InCombat() then
    if not quiet then
      Say("Leave combat first. Nock switches keys out of combat.")
    end
    return false
  end
  B.EnsureFirst()
  DB().ownBinds = on
  local Book = Nock.Book
  if Book and Book.ClearBinds then
    pcall(Book.ClearBinds)
  end
  if Nock.Dedicated and Nock.Dedicated.Apply then
    pcall(Nock.Dedicated.Apply)
  end
  if Nock.UpdateOverlay then
    pcall(Nock.UpdateOverlay)
  end
  if not on and Nock.Setup and Nock.Setup.QueueKeepUp then
    pcall(Nock.Setup.QueueKeepUp) -- empty keys only, as always
  end
  if not quiet then
    Say(on and "Using your own keybinds. Nock sets no keys; each button shows the key you already use for it."
      or "Nock layout is on. It only uses keys that are free; your own keybinds stay as they are.")
  end
  if Nock.RefreshUI then
    pcall(Nock.RefreshUI)
  end
  return true
end

-- Your own key for a spell / macro / Nock button -------------------------------------

-- Action slot -> its binding command (Classic bar layout).
function B.SlotCommand(slot)
  slot = tonumber(slot)
  if not slot then
    return nil
  end
  if slot >= 1 and slot <= 12 then
    return "ACTIONBUTTON" .. slot
  elseif slot >= 61 and slot <= 72 then
    return "MULTIACTIONBAR1BUTTON" .. (slot - 60) -- bottom left
  elseif slot >= 49 and slot <= 60 then
    return "MULTIACTIONBAR2BUTTON" .. (slot - 48) -- bottom right
  elseif slot >= 25 and slot <= 36 then
    return "MULTIACTIONBAR3BUTTON" .. (slot - 24) -- right
  elseif slot >= 37 and slot <= 48 then
    return "MULTIACTIONBAR4BUTTON" .. (slot - 36) -- right 2
  end
  return nil
end

local function SpellName(id)
  if not id then
    return nil
  end
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" then
      return n
    end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and type(n) == "string" then
      return n
    end
  end
  return nil
end

-- What an action slot casts, as a spell or macro name.
function B.SlotHolds(slot, spell, macro)
  if not GetActionInfo then
    return false
  end
  local ok, kind, id = pcall(GetActionInfo, slot)
  if not ok or not kind then
    return false
  end
  if kind == "spell" and spell then
    return SpellName(id) == spell
  end
  if kind == "macro" then
    local mname = GetMacroInfo and select(1, GetMacroInfo(id)) or nil
    if macro and mname == macro then
      return true
    end
    if spell and GetMacroSpell then
      local okm, sid = pcall(GetMacroSpell, id)
      if okm and sid and SpellName(sid) == spell then
        return true
      end
    end
  end
  return false
end

local SLOT_ORDER = {}
for i = 1, 12 do SLOT_ORDER[#SLOT_ORDER + 1] = i end
for i = 61, 72 do SLOT_ORDER[#SLOT_ORDER + 1] = i end
for i = 49, 60 do SLOT_ORDER[#SLOT_ORDER + 1] = i end
for i = 25, 48 do SLOT_ORDER[#SLOT_ORDER + 1] = i end

-- Cached (range checks ask often); cleared when bars, macros or spells change.
B.slotCache = {}
function B.FindSlot(spell, macro)
  local ck = tostring(spell) .. "\0" .. tostring(macro)
  local hit = B.slotCache[ck]
  if hit ~= nil then
    return hit or nil
  end
  for _, slot in ipairs(SLOT_ORDER) do
    if B.SlotHolds(slot, spell, macro) then
      B.slotCache[ck] = slot
      return slot
    end
  end
  B.slotCache[ck] = false
  return nil
end

local function KeyOf(cmd)
  if not (cmd and GetBindingKey) then
    return nil
  end
  local ok, k = pcall(GetBindingKey, cmd)
  if ok and type(k) == "string" and k ~= "" then
    return k
  end
  return nil
end

-- opts: { button = "NockPetMend", spell = "Mend Pet", macro = "Nock:Pet", cmds = {...} }
function B.OwnKey(opts)
  if type(opts) == "string" then
    opts = { spell = opts }
  end
  opts = opts or {}
  local k = opts.button and KeyOf("CLICK " .. opts.button .. ":LeftButton")
  if k then return k end
  for _, c in ipairs(opts.cmds or {}) do
    k = KeyOf(c)
    if k then return k end
  end
  k = opts.spell and KeyOf("SPELL " .. opts.spell)
  if k then return k end
  k = opts.macro and KeyOf("MACRO " .. opts.macro)
  if k then return k end
  local slot = B.FindSlot(opts.spell, opts.macro)
  return slot and KeyOf(B.SlotCommand(slot)) or nil
end

-- Slash and events ---------------------------------------------------------------------

function B.Slash(rest)
  rest = rest or ""
  local sub, arg = rest:match("^(%S*)%s*(.-)$")
  if sub == "backup" or sub == "save" then
    local _, msg = B.Backup()
    Say(msg)
  elseif sub == "restore" then
    B.ConfirmRestore(tonumber(arg) or 1)
  elseif sub == "own" or sub == "mine" then
    if arg == "on" then
      B.SetOwn(true)
    elseif arg == "off" then
      B.SetOwn(false)
    else
      B.SetOwn(not B.Own())
    end
  elseif sub == "list" or sub == "" then
    local list = B.List()
    if #list == 0 then
      Say("No keybind backup yet. /nock binds backup makes one.")
    end
    for i, s in ipairs(list) do
      Say(B.Label(s, i))
    end
    Say("Keys: " .. (B.Own() and "your own keybinds" or "Nock layout (free keys only)")
      .. ".  /nock binds backup | restore [n] | own on|off")
  else
    Say("/nock binds list | backup | restore [n] | own on|off")
  end
end

local baseSlash = SlashCmdList and SlashCmdList.NOCK
if baseSlash then
  SlashCmdList.NOCK = function(msg, ...)
    local m = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = m:match("^(%S+)%s*(.*)$")
    if cmd == "binds" or cmd == "keybinds" or cmd == "bindings" then
      return B.Slash(rest)
    end
    baseSlash(msg, ...)
    if m == "help" then
      Say("/nock binds — keybind backup: list | backup | restore [n] | own on|off (use my own keybinds)")
    end
  end
end

if CreateFrame then
  local cache = CreateFrame("Frame")
  for _, e in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "SPELLS_CHANGED", "ACTIONBAR_PAGE_CHANGED" }) do
    pcall(cache.RegisterEvent, cache, e)
  end
  cache:SetScript("OnEvent", function()
    B.slotCache = {}
  end)
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_LOGIN", "UPDATE_BINDINGS", "BINDINGS_LOADED", "PLAYER_ENTERING_WORLD" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(self, event)
    if B.EnsureFirst() then
      pcall(self.UnregisterAllEvents, self)
    end
  end)
end
