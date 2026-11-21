--[[
  Nock 3.4.0: hunter field guide data (extend by adding rows or phases).

  Route bands are WoW Forever 1.60.1 zone levels (Group Finder sub-area
  levels, warcraftmaps.com route pages, checked 16-17 Nov 2026), including
  Forever's Zephras Isle, Riverglades and Mount Hyjal. Trust your quest
  colours over any table.

  Route row: { fromLevel, toLevel, "zones", "flight points", "dungeons" }
  Milestone row: { level, "text", spec }  spec: nil = everyone, or "bm",
  "marks", "survival" to show it only for that build.
  Endgame: checklists keyed by context ("raid", "dungeon", "pvp", "solo").
  Content phases: add a row to Phases when Blizzard opens something new.
]]

local Nock = _G.Nock
if not Nock then
  return
end

Nock.Data = Nock.Data or {}

Nock.Data.Route = {
  Alliance = {
    { 1, 10, "Elwynn Forest, Dun Morogh, Teldrassil or Zephras Isle", "Stormwind, Ironforge, Rut'theran Village", "" },
    { 10, 16, "Westfall, Loch Modan or Darkshore", "Sentinel Hill, Thelsamar, Auberdine", "The Hall of Thanes, Deadmines" },
    { 16, 22, "Redridge Mountains, then Stonetalon Mountains or Ashenvale", "Lakeshire, Stonetalon Peak, Astranaar", "Deadmines, Shadowfang Keep" },
    { 22, 30, "Duskwood, Wetlands, Hillsbrad Foothills", "Darkshire, Menethil Harbor, Southshore", "Blackfathom Deeps, Stockade, Excavation Site: Wetlands" },
    { 30, 36, "Arathi Highlands, Desolace, Alterac Mountains", "Refuge Pointe, Nijel's Point", "City of Dalaran, Gnomeregan, Scarlet Monastery" },
    { 36, 44, "Riverglades, Stranglethorn Vale, Dustwallow Marsh, Badlands", "Farholde Keep, Powderfuse Port, Booty Bay, Theramore", "Razorfen Downs, Uldaman" },
    { 44, 50, "Tanaris, Feralas, The Hinterlands", "Gadgetzan, Feathermoon, Aerie Peak", "Zul'Farrak, Maraudon" },
    { 50, 55, "Un'Goro Crater, Felwood, Azshara, Blasted Lands", "Marshal's Refuge, Talonbranch Glade, Talrendis Point, Nethergarde Keep", "Sunken Temple, Blackrock Depths" },
    { 55, 60, "Western and Eastern Plaguelands, Burning Steppes, Silithus, Winterspring, Mount Hyjal", "Chillwind Camp, Light's Hope Chapel, Morgan's Vigil, Cenarion Hold, Everlook", "Dire Maul, Blackrock Spire, Scholomance, Stratholme" },
  },
  Horde = {
    { 1, 10, "Durotar, Mulgore, Tirisfal Glades or Zephras Isle", "Orgrimmar, Thunder Bluff, Undercity", "" },
    { 10, 20, "The Barrens, or Silverpine Forest from Tirisfal", "Crossroads, The Sepulcher", "Ragefire Chasm, Wailing Caverns, Ruins of Lordaeron" },
    { 20, 30, "Stonetalon Mountains, Ashenvale, Hillsbrad Foothills, Thousand Needles", "Sun Rock Retreat, Splintertree Post, Tarren Mill, Freewind Post", "Shadowfang Keep, Blackfathom Deeps, Razorfen Kraul" },
    { 30, 36, "Desolace, Arathi Highlands, Alterac Mountains", "Shadowprey Village, Hammerfall", "Scarlet Monastery, City of Dalaran" },
    { 36, 44, "Riverglades first, then Stranglethorn Vale, Badlands, Swamp of Sorrows, Dustwallow Marsh", "Rog'mar, Grom'gol, Kargath, Stonard", "Razorfen Downs, Uldaman" },
    { 44, 50, "Tanaris, Feralas, The Hinterlands", "Gadgetzan, Camp Mojache, Revantusk Village", "Zul'Farrak, Maraudon" },
    { 50, 55, "Un'Goro Crater, Felwood, Azshara", "Marshal's Refuge, Bloodvenom Post, Valormok", "Sunken Temple, Blackrock Depths" },
    { 55, 60, "Burning Steppes, Eastern Plaguelands, Silithus, Winterspring, Mount Hyjal", "Flame Crest, Light's Hope Chapel, Cenarion Hold, Everlook", "Dire Maul, Blackrock Spire, Scholomance, Stratholme" },
  },
}

Nock.Data.Milestones = {
  { 4, "Buy Serpent Sting and Aspect of the Monkey. Keep Monkey on until you have Hawk." },
  { 6, "Arcane Shot and Hunter's Mark. Mark every target." },
  { 10, "Train at your hunter trainer: Aspect of the Hawk, Tame Beast, Call / Feed / Revive Pet. Do the taming quest chain from the trainer for your first pet." },
  { 10, "Feed your pet whenever it is not green (happy). An unhappy pet does less damage and can run away." },
  { 12, "Wing Clip: when something reaches melee: Wing Clip, then step back out past 8 yards and shoot. This is the core of kiting." },
  { 12, "Mend Pet. Heal the pet early; buy Great Stamina and Natural Armor from the pet trainer." },
  { 16, "Learn your first new pet ranks: tame a beast that knows the rank (Bite, Claw), fight with it until you learn it, then teach your pet in Beast Training." },
  { 20, "Aspect of the Cheetah for travel, Aimed Shot, Freezing Trap. Buy a quiver or ammo pouch upgrade." },
  { 20, "Kiting: Concussive Shot, run (do not backpedal), turn and shoot. If it catches you: Wing Clip, step back, shoot." },
  { 24, "Beast Lore shows a wild beast's abilities before you tame it." },
  { 30, "Feign Death. If it is resisted, you are still in combat; Nock warns you." },
  { 30, "Improved Wing Clip (Survival) can root on Wing Clip. Worth a point if you kite a lot.", "survival" },
  { 36, "Viper Sting for casters. Keep Serpent Sting on everything else." },
  { 40, "Aspect of the Pack and Volley. Pack is for group travel; it dazes everyone when hit." },
  { 50, "Plan your pre-raid set: ammo pouch / quiver, best ammo, and Tranquilizing Shot at 60." },
  { 60, "Tranquilizing Shot from the trainer: you remove Frenzy in Molten Core and other raids." },
  { 60, "Rhok'delar: when Molten Core is open, the Ancient Petrified Leaf (Majordomo's cache) starts the Rhok'delar bow quest with Vartrus the Ancient in Felwood." },
}

-- Phases: what is open in Forever. Add rows as content unlocks.
Nock.Data.Phases = {
  { "Launch (4 Nov 2026)", "Levels 1-60, dungeons up to Stratholme and Blackrock Spire." },
  { "Raids (from 9 Dec 2026, per Blizzard)", "Molten Core, Onyxia, Blackwing Lair, Zul'Gurub, Ahn'Qiraj and Naxxramas as Blizzard opens them." },
}

-- Endgame checklists by context. Counts are suggestions; tune with /nock supplies.
Nock.Data.Checklists = {
  raid = {
    "Ammo: two full quivers (about 3,000+) of your best arrows or bullets",
    "Pet food for 3+ hours, matched to your pet's diet",
    "Your own food and water, plus agility / attack power buffs if you use them",
    "Tranquilizing Shot on a key (Frenzy in Molten Core, Chromaggus, Princess Huhuran)",
    "Feign Death on a key you can hit without looking",
    "Repair before you zone in",
    "Freezing Trap and Aspect of the Pack off; Aspect of the Hawk on",
  },
  dungeon = {
    "Ammo for the run (1,000+), pet food, food and water",
    "Pet on Defensive or Passive; Growl off if a tank is with you",
    "Freezing Trap for crowd control; Wing Clip, step back for runners",
  },
  pvp = {
    "Wing Clip, step back, shoot. Concussive Shot and Frost Trap to hold distance",
    "Scatter Shot (talent) into Freezing Trap",
    "Viper Sting on healers and casters",
  },
  solo = {
    "Pet happy, ammo and pet food stocked",
    "Wing Clip, then step back out of the dead zone",
  },
}

-- 3.4.0 PvP: a fuller battleground checklist.
Nock.Data.Checklists.pvp = {
  "Ammo for the match (1,000+) — Nock warns when the queue pops if you are short",
  "Aspect of the Hawk on; never Cheetah or Pack in a fight",
  "Wing Clip, step back, shoot. Concussive Shot and Frost Trap to hold distance",
  "Scatter Shot (talent) into Freezing Trap; Feign Death to reset traps",
  "Viper Sting on healers and casters, Scorpid Sting on warriors and rogues",
  "Hunter's Mark and Flare against stealth",
}
