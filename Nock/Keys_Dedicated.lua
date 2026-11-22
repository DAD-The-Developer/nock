--[[
  Nock 3.6.0: dedicated Wing Clip and Hunter's Mark keys.

  Two hidden secure buttons cast the spell by name, so the game always
  uses the highest rank you know. Each has a real Key Bindings entry
  (Key Bindings > AddOns > Nock), and Nock suggests a left-hand key:

    Wing Clip      Caps Lock  (pinky, straight left of A)
    Hunter's Mark  `          (the key above Tab, left of 1)

  The suggested key is only used when:
    * you have not bound that Nock entry to any key yourself, and
    * the key itself is empty in your own bindings.
  It is set with SetOverrideBindingClick (never SaveBindings), so it is
  never written to your keybinds and goes away if Nock is removed. Bind
  the entry yourself in Key Bindings and Nock stops suggesting anything.
  Options > Extras > "Dedicated Wing Clip and Hunter's Mark keys" turns
  the suggestions off. Out of combat only (Blizzard protects binds).
]]

local Nock = _G.Nock
if not Nock then
  return
end

local D = {}
Nock.Dedicated = D

D.LIST = {
  { id = "wingclip", spell = "Wing Clip", button = "NockWingClipButton", key = "CAPSLOCK", keyName = "Caps Lock" },
  { id = "mark", spell = "Hunter's Mark", button = "NockMarkButton", key = "`", keyName = "`" },
}

local function DB()
  NockCharDB = NockCharDB or {}
  return NockCharDB
end

function D.Enabled()
  return DB().dedicatedKeys ~= false
end

local function InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

local function KeyDown()
  local v = GetCVar and GetCVar("ActionButtonUseKeyDown")
  return v == "1"
end

local owner
local function Owner()
  if not owner and CreateFrame then
    owner = CreateFrame("Frame", "NockDedicatedOwner", UIParent)
  end
  return owner
end

local function MakeButton(e)
  if e.btn or not CreateFrame then
    return e.btn
  end
  local ok, b = pcall(CreateFrame, "Button", e.button, UIParent, "SecureActionButtonTemplate")
  if not ok or not b or not b.SetAttribute then
    return nil
  end
  e.btn = b
  b:SetSize(1, 1)
  b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
  if b.RegisterForClicks then
    b:RegisterForClicks(KeyDown() and "AnyDown" or "AnyUp")
  end
  -- No rank in the name: the game casts the highest rank you know.
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "/cast " .. e.spell)
  return b
end

function D.Command(e)
  return "CLICK " .. e.button .. ":LeftButton"
end

-- The key you chose in Key Bindings for this entry, if any.
function D.UserKey(e)
  if not GetBindingKey then
    return nil
  end
  local k = GetBindingKey(D.Command(e))
  if k and k ~= "" then
    return k
  end
  return nil
end

-- What your own bindings put on a key (overrides ignored).
local function RealAction(key)
  if not GetBindingAction then
    return ""
  end
  return GetBindingAction(key) or ""
end

-- Returns the key this entry answers to now, and how ("yours", "nock", nil).
function D.KeyFor(e)
  local mine = D.UserKey(e)
  if mine then
    return mine, "yours"
  end
  if e.applied then
    return e.key, "nock"
  end
  return nil, nil
end

local pending = false
local current = {} -- key -> button Nock has set as an override now
function D.Apply()
  if InCombat() then
    pending = true
    return
  end
  pending = false
  local o = Owner()
  if not o then
    return
  end
  local want = {}
  for _, e in ipairs(D.LIST) do
    MakeButton(e)
    e.applied = false
    if e.btn and D.Enabled() and not D.UserKey(e) and RealAction(e.key) == "" then
      want[e.key] = e.button
      e.applied = true
    end
  end
  -- 3.6.1: only touch overrides when something changed. Clearing and setting
  -- them fires UPDATE_BINDINGS, which used to call Apply again (a loop).
  local same = true
  for k, v in pairs(want) do
    if current[k] ~= v then
      same = false
    end
  end
  for k in pairs(current) do
    if not want[k] then
      same = false
    end
  end
  if same then
    return
  end
  if ClearOverrideBindings then
    pcall(ClearOverrideBindings, o)
  end
  current = {}
  for k, btn in pairs(want) do
    if SetOverrideBindingClick and pcall(SetOverrideBindingClick, o, false, k, btn, "LeftButton") then
      current[k] = btn
    end
  end
  for _, e in ipairs(D.LIST) do
    e.applied = current[e.key] == e.button
  end
end

function D.SetEnabled(on)
  DB().dedicatedKeys = on and true or false
  D.Apply()
end

local function Label(key)
  if not key then
    return "no key"
  end
  if key == "CAPSLOCK" then
    return "Caps Lock"
  end
  if key == "`" then
    return "`"
  end
  return (key:gsub("SHIFT%-", "Shift-"):gsub("ALT%-", "Alt-"):gsub("CTRL%-", "Ctrl-"))
end
D.Label = Label

-- One line for Options / chat: "Wing Clip: Caps Lock. Hunter's Mark: `."
function D.Summary()
  local parts = {}
  for _, e in ipairs(D.LIST) do
    local k, how = D.KeyFor(e)
    local s
    if k then
      s = e.spell .. ": " .. Label(k) .. (how == "nock" and " (Nock's suggestion)" or "")
    elseif not D.Enabled() then
      s = e.spell .. ": no key (suggestions off)"
    else
      s = e.spell .. ": no key (" .. e.keyName .. " is taken)"
    end
    parts[#parts + 1] = s
  end
  return table.concat(parts, ".  ") .. "."
end

for _, e in ipairs(D.LIST) do
  MakeButton(e)
end

if CreateFrame then
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LOGIN")
  ev:RegisterEvent("UPDATE_BINDINGS")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  local busy = false
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pending then
      return
    end
    if busy then
      return
    end
    busy = true -- setting overrides can fire UPDATE_BINDINGS again
    pcall(D.Apply)
    busy = false
    -- Say once per character where the keys are.
    if event == "PLAYER_LOGIN" and not DB().dedicatedTold and DEFAULT_CHAT_FRAME then
      DB().dedicatedTold = true
      DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Nock|r: " .. D.Summary() .. " Change them in Key Bindings > AddOns > Nock.")
    end
  end)
end
