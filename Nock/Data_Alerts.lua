--[[
  Nock 3.5.0: every hunter alert, declared in one place.

  Add a row and Options > Alerts gets a switch for it automatically. Fire
  it from any module with Nock.Alerts:Fire(id, vars). Fields: id, category,
  priority (critical | warning | info), icon ("spell:Name", "item:ID" or a
  texture path), title and sub ("{var}" templates), cooldown (seconds),
  contexts ({ pvp = false } to skip in PvP; { only = true, pvp = true } for
  PvP only), minLevel / maxLevel, spec ({ bm = true }), condition(vars),
  label (Options text). Keep titles short; sub is one line.
]]

local Nock = _G.Nock
local A = Nock and Nock.Alerts
if not A then
  return
end

local ALERTS = {
  -- Critical: act now.
  { id = "feign.resisted", category = "feign", priority = "critical", icon = "spell:Feign Death",
    title = "Feign Death resisted", sub = "Still in combat — trap, run or feign again", cooldown = 2, label = "Feign Death resisted" },
  { id = "range.clipoff", category = "range", priority = "critical", icon = "spell:Wing Clip",
    title = "Wing Clip fell off", sub = "Still in melee — clip again, then step back", cooldown = 4,
    contexts = { dungeon = false, raidinstance = false }, label = "Wing Clip fell off in melee" },
  { id = "range.deadzone", category = "range", priority = "critical", icon = "spell:Auto Shot",
    title = "Dead zone", sub = "Wing Clip, then step back past 8 yards", cooldown = 6,
    contexts = { only = true, pvp = true }, label = "Dead zone (PvP)" },

  -- Warning: fix it soon.
  { id = "aspect.daze", category = "aspects", priority = "warning", icon = "spell:Aspect of the Cheetah",
    title = "{aspect} is on in combat", sub = "You will be dazed — switch to {want}", cooldown = 6, label = "Cheetah or Pack on in combat" },
  { id = "aspect.none", category = "aspects", priority = "warning", icon = "spell:Aspect of the Hawk",
    title = "No aspect", sub = "Turn on {want}", cooldown = 30, label = "Fighting without an aspect" },
  { id = "supplies.leave", category = "supplies", priority = "warning", icon = "item:2512",
    title = "Leaving town low", sub = "{list}", cooldown = 120, label = "Leaving town short on supplies" },
  { id = "supplies.queue", category = "supplies", priority = "warning", icon = "item:2512",
    title = "Queue popped — low supplies", sub = "{list}", cooldown = 60, label = "Battleground queue pops while short" },
  { id = "pet.unhappy", category = "pet", priority = "warning", icon = "spell:Feed Pet",
    title = "{pet} is unhappy", sub = "Feed it — Feed pet key", cooldown = 45, contexts = { pvp = false }, label = "Pet is unhappy" },
  { id = "pet.nofood", category = "pet", priority = "warning", icon = "spell:Feed Pet",
    title = "No food your pet eats", sub = "It eats {diet}", cooldown = 600, contexts = { pvp = false }, label = "No suitable pet food" },
  { id = "pvp.trinket", category = "pvp", priority = "warning", icon = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01",
    title = "{name}", sub = "They broke free — re-apply Concussive or trap", cooldown = 3, label = "Enemy used a PvP trinket" },

  -- Info: worth knowing.
  { id = "pet.content", category = "pet", priority = "info", icon = "spell:Feed Pet",
    title = "{pet} is content", sub = "Feed it to get back to happy", cooldown = 180, contexts = { pvp = false }, label = "Pet is only content" },
  { id = "pet.lowfood", category = "pet", priority = "info", icon = "spell:Feed Pet",
    title = "Pet food is too low level", sub = "{food} will not cheer up a level {level} pet", cooldown = 900, contexts = { pvp = false }, label = "Pet food too low level" },
  { id = "supplies.town", category = "supplies", priority = "info", icon = "item:2512",
    title = "Low supplies", sub = "{list}", cooldown = 300, label = "Low supplies in town or near a vendor" },
  { id = "supplies.ok", category = "supplies", priority = "info", icon = "item:2512",
    title = "Supplies look good", sub = "{list}", cooldown = 0, label = "Supply check result (keybind)" },
  { id = "aspect.travel", category = "aspects", priority = "info", icon = "spell:Aspect of the Cheetah",
    title = "Travelling? {pick}", sub = "Back to Hawk before you pull", cooldown = 120, label = "Cheetah when travelling" },
  { id = "train.levelup", category = "train", priority = "info", icon = "Interface\\Icons\\INV_Misc_Book_09",
    title = "New at your trainer", sub = "{list}", cooldown = 0, contexts = { pvp = false }, label = "New ranks on level up" },
  { id = "train.pet", category = "train", priority = "info", icon = "spell:Tame Beast",
    title = "New at the pet trainer", sub = "{list}", cooldown = 0, contexts = { pvp = false }, label = "New pet trainer ranks" },
  { id = "tame.nearby", category = "tame", priority = "info", icon = "spell:Tame Beast",
    title = "{name} is nearby", sub = "Rare {family}, level {level} — {yards} yards", cooldown = 900, contexts = { pvp = false }, label = "Rare tameable beast nearby" },
  { id = "vendor.summary", category = "vendor", priority = "info", icon = "Interface\\Icons\\INV_Misc_Coin_02",
    title = "{title}", sub = "{sub}", cooldown = 0, label = "Junk sold / repaired" },
  { id = "gold.drop", category = "gold", priority = "info", icon = "Interface\\Icons\\INV_Misc_Coin_01",
    title = "{item}", sub = "{why}  ·  {worth}", cooldown = 0, label = "Valuable loot (over the keep value, green+, recipes)" },
  { id = "gold.train", category = "gold", priority = "info", icon = "Interface\\Icons\\INV_Misc_Note_01",
    title = "Profession rank ready", sub = "{text}", cooldown = 0, contexts = { pvp = false }, label = "Next profession rank can be trained" },
  { id = "route.levelup", category = "route", priority = "info", icon = "Interface\\Icons\\INV_Misc_Map_01",
    title = "Level {level}", sub = "{zones}", cooldown = 0, contexts = { pvp = false }, label = "Where to level next" },
  { id = "pvp.enter", category = "pvp", priority = "info", icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    title = "PvP mode{arena}", sub = "PvE reminders off, range cues up", cooldown = 60, label = "Entering a battleground" },
}

for _, def in ipairs(ALERTS) do
  A:Register(def)
end
