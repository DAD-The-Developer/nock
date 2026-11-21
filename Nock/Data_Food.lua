--[[
  Nock 3.4.0: food and drink data (extend by adding rows).

  PetFood: [itemID] = diet. Diet names match GetPetFoodTypes() ("Meat",
  "Fish", "Bread", "Cheese", "Fruit", "Fungus"; raw meat/fish count as
  Meat/Fish). Items not listed are matched by name keywords below, so new
  foods mostly work without an update. Item level / required level comes
  from the client at run time.

  Your own food and water are recognised at run time from the item's use
  spell ("Food", "Drink", "Refreshment"), so no table is needed for them.
]]

local Nock = _G.Nock
if not Nock then
  return
end

Nock.Data = Nock.Data or {}

Nock.Data.PetFood = {
  -- Meat (vendor, cooked and raw)
  [117] = "Meat", [2287] = "Meat", [3770] = "Meat", [3771] = "Meat", [4599] = "Meat", [8952] = "Meat",
  [2672] = "Meat", [769] = "Meat", [1015] = "Meat", [2673] = "Meat", [2677] = "Meat", [3173] = "Meat",
  [3712] = "Meat", [3730] = "Meat", [3731] = "Meat", [5467] = "Meat", [12037] = "Meat", [12184] = "Meat",
  [12202] = "Meat", [12203] = "Meat", [12204] = "Meat", [12205] = "Meat", [12208] = "Meat", [12223] = "Meat",
  [2679] = "Meat", [2681] = "Meat", [2684] = "Meat", [2685] = "Meat", [2687] = "Meat", [3220] = "Meat",
  [3662] = "Meat", [3726] = "Meat", [3727] = "Meat", [3728] = "Meat", [4457] = "Meat", [5478] = "Meat",
  [12209] = "Meat", [12210] = "Meat", [12213] = "Meat", [12224] = "Meat", [13851] = "Meat", [18045] = "Meat",
  [21023] = "Meat", [20074] = "Meat", [5469] = "Meat", [5471] = "Meat",
  -- Fish
  [787] = "Fish", [4592] = "Fish", [4593] = "Fish", [4594] = "Fish", [6290] = "Fish", [6887] = "Fish",
  [8957] = "Fish", [13930] = "Fish", [13933] = "Fish", [13934] = "Fish", [16766] = "Fish", [21552] = "Fish",
  [6291] = "Fish", [6289] = "Fish", [6303] = "Fish", [6308] = "Fish", [6317] = "Fish", [6361] = "Fish",
  [6362] = "Fish", [8365] = "Fish", [13754] = "Fish", [13755] = "Fish", [13756] = "Fish", [13758] = "Fish",
  [13759] = "Fish", [13760] = "Fish", [13889] = "Fish", [13893] = "Fish", [5095] = "Fish", [4603] = "Fish",
  -- Bread
  [4540] = "Bread", [4541] = "Bread", [4542] = "Bread", [4544] = "Bread", [4601] = "Bread", [8950] = "Bread",
  [2683] = "Bread", [3666] = "Bread", [17119] = "Bread", [19696] = "Bread", [21033] = "Bread",
  -- Cheese
  [2070] = "Cheese", [414] = "Cheese", [422] = "Cheese", [1707] = "Cheese", [3927] = "Cheese", [8932] = "Cheese",
  [17406] = "Cheese",
  -- Fruit
  [4536] = "Fruit", [4537] = "Fruit", [4538] = "Fruit", [4539] = "Fruit", [4602] = "Fruit", [8953] = "Fruit",
  [11950] = "Fruit", [11415] = "Fruit", [19994] = "Fruit", [21030] = "Fruit", [21031] = "Fruit",
  -- Fungus
  [4604] = "Fungus", [4605] = "Fungus", [4606] = "Fungus", [4607] = "Fungus", [4608] = "Fungus", [8948] = "Fungus",
  [3448] = "Fungus",
}

-- Fallback: name keyword -> diet, checked in order (first match wins).
Nock.Data.PetFoodWords = {
  { "Mushroom", "Fungus" }, { "Morel", "Fungus" }, { "Truffle", "Fungus" }, { "Bolete", "Fungus" }, { "Cave Mold", "Fungus" },
  { "Cheese", "Cheese" }, { "Brie", "Cheese" }, { "Cheddar", "Cheese" }, { "Swiss", "Cheese" }, { "Sharp", "Cheese" },
  { "Bleu", "Cheese" }, { "Dwarven Mild", "Cheese" },
  { "Bread", "Bread" }, { "Cornbread", "Bread" }, { "Pie", "Bread" }, { "Muffin", "Bread" }, { "Biscuit", "Bread" },
  { "Apple", "Fruit" }, { "Banana", "Fruit" }, { "Melon", "Fruit" }, { "Pumpkin", "Fruit" }, { "Plantain", "Fruit" },
  { "Berries", "Fruit" }, { "Berry", "Fruit" }, { "Fruit", "Fruit" }, { "Grapes", "Fruit" }, { "Peach", "Fruit" },
  { "Fish", "Fish" }, { "Snapper", "Fish" }, { "Catfish", "Fish" }, { "Cod", "Fish" }, { "Yellowtail", "Fish" },
  { "Mackerel", "Fish" }, { "Salmon", "Fish" }, { "Eel", "Fish" }, { "Squid", "Fish" }, { "Lobster", "Fish" },
  { "Clam", "Fish" }, { "Crab", "Fish" }, { "Lightning Eel", "Fish" },
  { "Meat", "Meat" }, { "Jerky", "Meat" }, { "Haunch", "Meat" }, { "Chop", "Meat" }, { "Shank", "Meat" },
  { "Steak", "Meat" }, { "Flank", "Meat" }, { "Ham", "Meat" }, { "Quail", "Meat" }, { "Ribs", "Meat" },
  { "Sausage", "Meat" }, { "Wing", "Meat" }, { "Leg", "Meat" }, { "Kabob", "Meat" }, { "Chunk of", "Meat" },
}
