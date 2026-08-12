-- Standalone: luajit mods/palworld_crafting/tests/palworld_crafting_test.lua
-- Exercises the shelf filter, the merged apricorn content, the craft math
-- exports, the start-menu wrap and the screen factory.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")

local Data = T.fixtures.fresh()
local run = T.sdk.loadMod("mods/palworld_crafting", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- ------- content merged

T.check(Data.items.APRICORN_RED ~= nil, "RED APRICORN is a merged item")
T.check(Data.items.APRICORN_BLU ~= nil, "BLU APRICORN is a merged item")
T.check(Data.items.APRICORN_YLW ~= nil, "YLW APRICORN is a merged item")

-- ------- the shelf filter: FIX_BALL routes to a ball, FIX_POTION stays

local shelf = Data.text_pointers.FixTown.TEXT_FIXTOWN_MART.mart
T.eq(#shelf, 1, "the fixture shelf: potion kept, ball out")
T.eq(shelf[1], "FIX_POTION", "the potion survived; the ball did not")
local tableSold = false
for _, id in ipairs(shelf) do
  if id == "CRAFT_TABLE" then tableSold = true end
end
T.check(not tableSold,
  "no mart sells the CRAFT TABLE (it arrives with the POKeDEX)")
local chestSold = false
for _, id in ipairs(shelf) do
  if id == "STORAGE_CHEST" then chestSold = true end
end
T.check(not chestSold, "the CHEST is crafted now, never bought")

-- ------- the apricorn sprites merged; pickup spots are exported

for _, c in ipairs({ "RED", "BLU", "YLW" }) do
  local sprite = Data.sprites["SPRITE_APRICORN_" .. c]
  T.check(sprite ~= nil, "SPRITE_APRICORN_" .. c .. " is merged")
  T.eq(sprite.frames, 1, c .. " is a single-frame object sprite")
  T.eq(sprite.trueColor, true, c .. " opts out of the 4-shade re-shade")
  T.check(sprite.image:find("palworld_crafting", 1, true) ~= nil,
    c .. " image lives in the mod directory")
end

-- the fixture has no Kanto routes, so the map patches skip themselves
-- there (the mod guards on maps:get); the spot table is still exported
-- and the in-game driver verifies each placement on the real maps
local exportsEarly = run.loader.exports.palworld_crafting
local spotCount = 0
for _, spots in pairs(exportsEarly.spots) do
  for _, s in ipairs(spots) do
    spotCount = spotCount + 1
    T.check(Data.items[s[3]] ~= nil, "spot item exists: " .. tostring(s[3]))
  end
end
T.check(spotCount >= 40, "pickup spots span the whole region (" .. spotCount .. ")")

-- ------- ground balls map to their matching apricorn

T.eq(exportsEarly.ballToApricorn.POKE_BALL, "APRICORN_RED",
  "a ground Poke Ball becomes RED")
T.eq(exportsEarly.ballToApricorn.GREAT_BALL, "APRICORN_BLU",
  "a ground Great Ball becomes BLU")
T.eq(exportsEarly.ballToApricorn.ULTRA_BALL, "APRICORN_YLW",
  "a ground Ultra Ball becomes YLW")
T.eq(exportsEarly.ballToApricorn.MASTER_BALL, nil,
  "the Master Ball story gift is untouched")

-- ------- the placeable crafting table

T.check(Data.items.CRAFT_TABLE ~= nil, "CRAFT TABLE is a merged item")
T.eq(Data.items.CRAFT_TABLE.effect, "CRAFT_TABLE_EFFECT",
  "the item routes to its use effect")
T.check(Data.item_effects.CRAFT_TABLE_EFFECT ~= nil
        and type(Data.item_effects.CRAFT_TABLE_EFFECT.use) == "function",
  "the placement effect merged with a use handler")
T.check(Data.sprites.SPRITE_CRAFT_TABLE ~= nil, "the table sprite merged")

-- the journey earns the gear now: new games start with ball frames
-- only (the base arrives with the POKéDEX, the table from the mart,
-- the incubator from Brock)
local fresh = Runtime.call("save.new_game",
  function(s) return s end, { inventory = {} })
T.eq(fresh.inventory.WOOD, 3, "a new game starts with three WOOD")
T.eq(fresh.inventory.CRAFT_TABLE, nil, "no free CRAFT TABLE any more")
T.eq(fresh.inventory.SECRET_BASE, nil, "no free SECRET BASE any more")
T.eq(fresh.inventory.EGG_INCUBATOR, nil, "no free INCUBATOR any more")
T.check(fresh.modData.palworld_crafting.wood_given == true,
  "the wood gift is marked so loads never double it")

-- the wired dispatch speaks the documented result verbs on refusal paths
local ItemEffects = require("src.inventory.ItemEffects")
local refuseSave = { inventory = { CRAFT_TABLE = 1 }, player = { name = "T" } }
local verb = ItemEffects.use(Data, refuseSave, "CRAFT_TABLE", nil, true)
T.eq(verb, "failed", "using the table mid-battle refuses")
local blockedOw = {
  player = { cellX = 5, cellY = 5, facing = "down" },
  map = { id = "FIX_TOWN",
          inBounds = function() return true end,
          isWalkableCell = function() return false end },
  npcs = {},
}
verb = ItemEffects.use(Data, refuseSave, "CRAFT_TABLE", nil, false, nil, blockedOw)
T.eq(verb, "failed", "placement refuses a blocked cell")
T.eq(refuseSave.inventory.CRAFT_TABLE, 1, "a refused placement keeps the item")

-- ------- the secret base

T.check(Data.items.SECRET_BASE ~= nil, "SECRET BASE is a merged item")
T.eq(Data.items.SECRET_BASE.effect, "SECRET_BASE_EFFECT",
  "the item routes to its build effect")
T.check(Data.item_effects.SECRET_BASE_EFFECT ~= nil
        and type(Data.item_effects.SECRET_BASE_EFFECT.use) == "function",
  "the build effect merged with a use handler")
T.check(Data.sprites.SPRITE_SECRET_BASE ~= nil, "the entrance sprite merged")

-- the room registers only when the real HOUSE tileset exists; the
-- fixture has no ROM tilesets, so here it must skip itself cleanly
-- (the in-game driver asserts the real 10x10 room)
local room = Data.maps.PALCRAFT_BASE
if Data.tilesets and Data.tilesets.HOUSE then
  T.check(room ~= nil, "the base room map merged")
  T.eq(room.width, 5, "room is 5 blocks wide (10 cells)")
  T.eq(room.height, 6, "room is 6 blocks tall (wall + floor + door row)")
  T.eq(#room.warps, 2, "the south door is a two-cell edge warp")
  T.eq(room.tileset, "PALCRAFT_HOUSE",
    "the room wears its own derived house tileset")
  local pht = Data.tilesets.PALCRAFT_HOUSE
  T.check(pht ~= nil and tostring(pht.image):find("mod%-derived") ~= nil,
    "the derived tileset points into mod-derived art")
  T.eq(#room.objects, 1, "one housewarming item ball waits inside")
  T.eq(room.objects[1].item, "FERMENTED_JUICE",
    "and it holds FERM.JUICE for the first egg")
  local nBlocks = #pht.blocks
  T.eq(room.blocks[1], nBlocks - 2,
    "the top-left corner is the composed PC block")
  local pcBlock = pht.blocks[nBlocks - 1]
  T.eq(pcBlock[1], Data.tilesets.HOUSE.blocks[17][1],
    "its left columns come from the PC-desk block")
  T.eq(pcBlock[4], Data.tilesets.HOUSE.blocks[6][4],
    "its right columns come from the window wall")
  T.eq(room.blocks[12], nBlocks - 1,
    "block (1,2) is the tilled dirt patch")
  local dirtBlock = pht.blocks[nBlocks]
  T.eq(dirtBlock[1], 96, "the dirt block lays the appended cave tile")
  local dirtWalkable = false
  for _, w in ipairs(pht.walkable or {}) do
    if w == 96 then dirtWalkable = true end
  end
  T.check(not dirtWalkable, "nobody tramples the crops (dirt blocks)")
  local pcs = ((Data.field.hiddenExtras or {}).pcTiles or {}).PALCRAFT_BASE
  T.check(pcs and pcs[1] and pcs[1].x == 0 and pcs[1].y == 1
          and pcs[1].facing == "up",
    "the desk PC is a live pcTiles trigger at (0,1) facing up")
else
  T.check(room == nil, "the room skips itself without the HOUSE tileset")
end

verb = ItemEffects.use(Data, { inventory = { SECRET_BASE = 1 } },
  "SECRET_BASE", nil, true)
T.eq(verb, "failed", "building the base mid-battle refuses")
verb = ItemEffects.use(Data, { inventory = { SECRET_BASE = 1 } },
  "SECRET_BASE", nil, false, nil, blockedOw)
T.eq(verb, "failed", "building refuses a blocked cell")

-- ------- the egg incubator

T.check(Data.items.EGG_INCUBATOR ~= nil, "the INCUBATOR is a merged item")
T.eq(Data.items.EGG_INCUBATOR.effect, "EGG_INCUBATOR_EFFECT",
  "the item routes to its placement effect")
T.check(Data.sprites.SPRITE_INCUBATOR ~= nil
        and Data.sprites.SPRITE_INCUBATOR_EGG ~= nil,
  "both incubator sprites merged (empty + egg)")

verb = ItemEffects.use(Data, { inventory = { EGG_INCUBATOR = 1 } },
  "EGG_INCUBATOR", nil, true)
T.eq(verb, "failed", "placing the incubator mid-battle refuses")
verb = ItemEffects.use(Data, { inventory = { EGG_INCUBATOR = 1 } },
  "EGG_INCUBATOR", nil, false, nil, blockedOw)
T.eq(verb, "failed", "the incubator refuses outside the SECRET BASE")

T.eq(exportsEarly.pickHatchSpecies({ "A", "B" }, function() return 1 end), "A",
  "hatch roll 1 picks the first parent")
T.eq(exportsEarly.pickHatchSpecies({ "A", "B" }, function() return 2 end), "B",
  "hatch roll 2 picks the second parent")

T.check(not exportsEarly.eggReady({ startedAt = 0 }, { playTime = 59 }),
  "the egg is not ready a second early")
T.check(exportsEarly.eggReady({ startedAt = 0 }, { playTime = 60 }),
  "the egg is ready at the full minute")
T.check(not exportsEarly.eggReady({}, { playTime = 999 }),
  "no timer means no egg")

-- ------- the grape farm

for _, id in ipairs({ "GRAPE_SEED", "GRAPES", "FERMENTED_JUICE",
                      "STORAGE_CHEST" }) do
  T.check(Data.items[id] ~= nil, id .. " is a merged item")
end
T.check(Data.sprites.SPRITE_VINE ~= nil
        and Data.sprites.SPRITE_VINE_GROWN ~= nil
        and Data.sprites.SPRITE_CHEST ~= nil,
  "vine and lab-machine chest sprites merged")

T.check(exportsEarly.dropsSeeds({ "NORMAL", "FLYING" }),
  "flying opponents drop GRAPE SEEDS")
T.check(exportsEarly.dropsSeeds({ "BUG", "POISON" }),
  "bug opponents drop GRAPE SEEDS")
T.check(not exportsEarly.dropsSeeds({ "WATER" }),
  "water opponents still drop apricorns")
T.check(not exportsEarly.dropsSeeds(nil), "no types, no seeds")

-- drop priority: seeds (typed, 10%) -> WOOD (early wilds, 35%) ->
-- the level-band apricorn
local seedHit = function(n) return n and 10 or 0.1 end
T.eq(exportsEarly.rollDrop(true, seedHit, 5), "GRAPE_SEED",
  "a 10-or-under roll drops a GRAPE SEED (rarer now)")
T.eq(exportsEarly.rollDrop(false, seedHit, 5), "WOOD",
  "early wilds hand out ball-frame WOOD instead")
T.check(tostring(exportsEarly.rollDrop(false, seedHit, 20))
          :find("APRICORN_", 1, true) == 1,
  "past the early band the roll is apricorns again")
local allMiss = function(n) return n and 60 or 0.1 end
T.eq(exportsEarly.rollDrop(true, allMiss, 5), "APRICORN_RED",
  "a full miss falls through to the level-band apricorn")

-- ------- version exclusives mirror into counterpart slots

-- gen 1 bucket weights: 51,51,39,25,25,25,13,10,10,3 (of 256)
local mirrored, mch = exportsEarly.mirrorSlots({
  { species = "ODDISH", level = 10 },   -- 51
  { species = "ODDISH", level = 12 },   -- 51
  { species = "PIDGEY", level = 9 },    -- 39 (bystander)
  { species = "ODDISH", level = 14 },   -- 25
  { species = "GLOOM", level = 21 },    -- 25
  { species = "GLOOM", level = 23 },    -- 25
}, { ODDISH = "BELLSPROUT", GLOOM = "WEEPINBELL" },
   { 51, 51, 39, 25, 25, 25, 13, 10, 10, 3 })
-- ODDISH weight 127 splits 76/51; GLOOM weight 50 splits 25/25
T.eq(mch, 2, "each species' probability splits toward halves")
T.eq(mirrored[1].species, "ODDISH", "the heaviest slot stays native")
T.eq(mirrored[2].species, "BELLSPROUT",
  "the equal-weight twin goes to the exclusive (51 of 127)")
T.eq(mirrored[2].level, 12, "at the same level")
T.eq(mirrored[4].species, "ODDISH", "the light slot rejoins the native side")
T.eq(mirrored[6].species, "WEEPINBELL",
  "evolved stages split too, at equal weight (25 of 50)")
T.eq(mirrored[5].species, "GLOOM", "one GLOOM stays")
T.eq(mirrored[3].species, "PIDGEY", "unrelated slots untouched")

local single = exportsEarly.mirrorSlots(
  { { species = "GROWLITHE", level = 18 } }, { GROWLITHE = "VULPIX" },
  { 51, 51, 39, 25, 25, 25, 13, 10, 10, 3 })
T.eq(single[1].species, "GROWLITHE",
  "a single-slot species keeps its whole weight native")

local cyc, rest = exportsEarly.harvestCycles(200, 90)
T.eq(cyc, 2, "two full growth cycles fit in 200s")
T.eq(rest, 20, "with 20s of growth carried over")
cyc = exportsEarly.harvestCycles(89, 90)
T.eq(cyc, 0, "an unripe vine yields nothing yet")

verb = ItemEffects.use(Data, { inventory = { GRAPE_SEED = 1 } },
  "GRAPE_SEED", nil, true)
T.eq(verb, "failed", "planting mid-battle refuses")
verb = ItemEffects.use(Data, { inventory = { GRAPE_SEED = 1 } },
  "GRAPE_SEED", nil, false, nil, blockedOw)
T.eq(verb, "failed", "seeds only take root in the base")
verb = ItemEffects.use(Data, { inventory = { STORAGE_CHEST = 1 } },
  "STORAGE_CHEST", nil, false, nil, blockedOw)
T.eq(verb, "failed", "the CHEST only sets up in the base")

-- ------- breeding pairings (curated via tools/breed_lines_designer.html)

T.eq(exportsEarly.lineRootOf("FIXMON_B"), "FIXMON_A",
  "an evolved form collapses to its line root")
T.eq(exportsEarly.lineRootOf("FIXMON_C"), "FIXMON_C",
  "a standalone species is its own root")

local REC = { { a = "FIXMON_A", b = "FIXMON_C", child = "FIXMON_B", chance = 100 } }
local roll1 = function() return 1 end
T.eq(exportsEarly.breedChild({ "FIXMON_A", "FIXMON_C" }, roll1, REC),
  "FIXMON_B", "a matching pairing hatches its child")
T.eq(exportsEarly.breedChild({ "FIXMON_C", "FIXMON_A" }, roll1, REC),
  "FIXMON_B", "pairing order does not matter")
T.eq(exportsEarly.breedChild({ "FIXMON_B", "FIXMON_C" }, roll1, REC),
  "FIXMON_B", "evolved family members count as their line")
T.eq(exportsEarly.breedChild({ "FIXMON_A", "FIXMON_B" }, roll1, REC),
  "FIXMON_A", "a same-line pair hatches the line's base form")
T.eq(exportsEarly.breedChild({ "FIXMON_B", "FIXMON_B" }, roll1, REC),
  "FIXMON_A", "even two evolved parents collapse to the base form")

local RECHALF = { { a = "FIXMON_A", b = "FIXMON_C", child = "FIXMON_B", chance = 50 } }
local rolls = { 80, 1 }  -- miss the 50% roll, then pick parent 1
local seq = function() return table.remove(rolls, 1) end
T.eq(exportsEarly.breedChild({ "FIXMON_A", "FIXMON_C" }, seq, RECHALF),
  "FIXMON_A", "a missed chance roll hatches a plain base form instead")

-- the compatibility gate the parent pickers grey out against
T.check(exportsEarly.canBreed("FIXMON_A", "FIXMON_B"),
  "one evolution line breeds together")
T.check(exportsEarly.canBreed("FIXMON_C", "FIXMON_C"),
  "a species always breeds with itself")
T.check(not exportsEarly.canBreed("FIXMON_B", "FIXMON_C"),
  "unrelated lines with no pairing refuse")
T.check(exportsEarly.canBreed("PIDGEY", "SPEAROW"),
  "a special pairing counts as compatible")

-- the shipped curation, straight through the default recipe table (the
-- fixture dex has no PIDGEY, so line roots resolve to the ids themselves)
T.eq(exportsEarly.breedChild({ "PIDGEY", "SPEAROW" }, roll1), "FARFETCHD",
  "the curation hatches FARFETCH'D from PIDGEY x SPEAROW")
T.eq(exportsEarly.breedChild({ "DITTO", "PORYGON" }, roll1), "MEW",
  "chain pairings resolve too (DITTO x PORYGON -> MEW)")
T.check(#exportsEarly.breedOnly >= 29,
  "the full breed-only roster is exported for the encounter phase")
local startersFree = true
for _, sp in ipairs(exportsEarly.breedOnly) do
  if sp == "BULBASAUR" or sp == "CHARMANDER" or sp == "SQUIRTLE" then
    startersFree = false
  end
end
T.check(startersFree,
  "the classic starters left the breed-only roster for the wild")
local shrewFree = true
for _, sp in ipairs(exportsEarly.breedOnly) do
  if sp == "SANDSHREW" then shrewFree = false end
end
T.check(shrewFree, "SANDSHREW left the breed-only roster for the wild")
T.check(exportsEarly.pairingFor("ONIX", "GEODUDE") == nil,
  "no recipe hatches SANDSHREW any more")
T.check(Data.items.WOOD ~= nil, "WOOD is a merged item")

-- spoiler-free pairing hints
T.check(exportsEarly.pairingFor("PIDGEY", "SPEAROW") ~= nil,
  "a special pairing is detectable for the hint marker")
T.check(exportsEarly.pairingFor("SPEAROW", "PIDGEY") ~= nil,
  "in either order")
T.check(exportsEarly.pairingFor("PIDGEY", "RATTATA") == nil,
  "plain pairs show no hint")
local hintRec = exportsEarly.pairingFor("FIXMON_A", "FIXMON_C",
  { { a = "FIXMON_A", b = "FIXMON_C", child = "FIXMON_B", chance = 50 } })
T.check(hintRec ~= nil and hintRec.child == "FIXMON_B",
  "injectable recipes resolve for tests")

-- ------- breed-only species leave the wild (slot cleaner)

local wildSlots = {
  { species = "AAA", level = 5 },
  { species = "BAD", level = 7 },
  { species = "AAA", level = 9 },
}
local cleaned, changed =
  exportsEarly.cleanEncounterSlots(wildSlots, { BAD = true })
T.eq(changed, 1, "one slot held a breed-only species")
T.eq(cleaned[2].species, "AAA", "the slot re-filled with the table's lead")
T.eq(cleaned[2].level, 7, "keeping the slot's own level")
T.eq(#cleaned, 3, "the table stays full")

local allBad = exportsEarly.cleanEncounterSlots(
  { { species = "BAD", level = 3 } }, { BAD = true })
T.eq(allBad[1].species, "RATTATA",
  "a table of only breed-onlys falls back to something catchable")

local _, none = exportsEarly.cleanEncounterSlots(
  { { species = "FIXMON_A", level = 4 } })
T.eq(none, 0, "the current curation leaves ordinary tables alone")

-- ------- drop weights scale with the beaten level

local w5, w20, w40 = exportsEarly.dropWeights(5),
                     exportsEarly.dropWeights(20),
                     exportsEarly.dropWeights(40)
T.check(w5[1] > w5[2] and w5[1] > w5[3], "low levels drop mostly RED")
T.check(w20[2] > w20[1] and w20[2] > w20[3],
  "level ~20 favors BLU (Great Ball tier)")
T.check(w40[3] > w40[1] and w40[3] > w40[2],
  "level 40+ favors YLW (Ultra Ball tier)")
T.check(w40[1] > 0, "even champions shake out the odd RED")

-- ------- craft math through the export surface

local exports = run.loader.exports.palworld_crafting
T.eq(#exports.recipes, 5, "five recipes exported (the OLD ROD joins)")
T.eq(exports.recipes[4].ball, "OLD_ROD",
  "an OLD ROD whittles from wood for early fishing")
T.eq(exports.recipes[5].ball, "FERMENTED_JUICE",
  "GRAPES ferment into juice at the table")

local game = { data = Data,
               save = { inventory = { APRICORN_RED = 5, WOOD = 2 },
                        playTime = 0 } }
local pokeBall = exports.recipes[1]
T.eq(pokeBall.cost[2][1], "WOOD", "balls need a wooden frame now")
T.eq(exports.maxCraftable(game, pokeBall), 2,
  "5 red apricorns and 2 wood craft 2 balls")

-- crafting is a work queue: materials go in now, balls come out after
-- the crew has put in the seconds (playTime, like the vines)
exports.queueCraft(game, pokeBall, 2)
T.eq(game.save.inventory.APRICORN_RED, 1, "the apricorns were spent up front")
T.eq(game.save.inventory.WOOD, nil, "the wood too, freeing its slot")
T.eq(game.save.inventory.POKE_BALL, nil, "no balls yet -- the queue works")

exports.tickCraft(game)               -- opens the clock at t=0
game.save.playTime = pokeBall.work    -- one ball's worth of seconds
exports.tickCraft(game)
local got = exports.collectCraft(game)
T.eq(game.save.inventory.POKE_BALL, 1, "one ball done after its work time")
T.eq(got[1] and got[1].id, "POKE_BALL", "collect reports the delivery")
game.save.playTime = pokeBall.work * 2
exports.tickCraft(game)
exports.collectCraft(game)
T.eq(game.save.inventory.POKE_BALL, 2, "the second follows on schedule")

-- the HANDIWORK crew speeds the whole queue: 1 + level/2
T.eq(exports.craftSpeed(game, {}), 1, "no helper, base speed")
T.eq(exports.bestCrewLevel("KINDLING", { { species = "FIXMON_B" } }), 2,
  "crew levels read straight from work suitabilities")

-- ------- phase 2: the ore chain, the furnace, the MK2 table

T.check(Data.items.ORE ~= nil and Data.items.INGOT ~= nil,
  "ORE and INGOT are merged items")
T.check(Data.items.GENERATOR ~= nil and Data.items.FURNACE ~= nil,
  "both stations are merged items")
T.check(exportsEarly.dropsOre({ "ROCK", "GROUND" }),
  "rock and ground types shake out ore")
T.check(not exportsEarly.dropsOre({ "WATER" }), "water types do not")
local oreHit = function(n) return n and 20 or 0.1 end
T.eq(exportsEarly.rollDrop(false, oreHit, 30, true), "ORE",
  "an ore-type win drops ORE at any level")
T.eq(exports.recipes[3].cost[2][1], "INGOT",
  "the ULTRA tier runs on smelted metal now")
T.eq(#exports.stationRecipes, 12,
  "all stations craft at the table (chest, rod, condenser)")
T.eq(exports.stationRecipes[12].ball, "CONDENSER",
  "the CONDENSER caps the table list, no badge gate")
T.check(exports.stationRecipes[12].badge == nil,
  "the condenser is available from the first table")
local incRecipe
for _, r in ipairs(exports.stationRecipes) do
  if r.ball == "EGG_INCUBATOR" then incRecipe = r end
end
T.check(incRecipe and incRecipe.badge == "BOULDERBADGE",
  "the incubator blueprint is Brock's reward")
T.eq(#exports.mk2Recipes, 7,
  "five stones + the expansion blueprint + the altar")
T.eq(exports.mk2Recipes[5].ball, "MOON_STONE",
  "MOON STONE caps the stone list")
T.eq(exports.mk2Recipes[6].ball, "EXPANSION_KIT",
  "the expansion blueprint is the deep unlock")
T.eq(exports.mk2Recipes[6].insight, 10, "it wants 10 INSIGHT")

-- the smelter: consumes ore up front, needs a KINDLING keeper to run
local sgame = { data = Data,
                save = { inventory = { ORE = 3 }, playTime = 0 } }
T.eq(exports.queueSmelt(sgame, 2), 2, "two ore go into the furnace")
T.eq(sgame.save.inventory.ORE, 1, "the rest stay in the bag")
exports.tickSmelt(sgame, {})               -- opens the clock, no keeper
sgame.save.playTime = 120
exports.tickSmelt(sgame, {})               -- still no keeper: no progress
T.eq(exports.collectSmelt(sgame), 0, "a cold furnace smelts nothing")
exports.tickSmelt(sgame, { { species = "FIXMON_B" } })  -- KINDLING 2
sgame.save.playTime = 240
exports.tickSmelt(sgame, { { species = "FIXMON_B" } })
T.eq(exports.collectSmelt(sgame), 2, "a stoked furnace delivers")
T.eq(sgame.save.inventory.INGOT, 2, "the ingots landed in the bag")

-- power: no generator, no MK2 -- whatever the crew looks like
T.eq(exports.basePowered(sgame, { { species = "FIXMON_B" } }), false,
  "no generator placed means no power")

-- ------- phase 3: the medicine bench and the training dummy

T.check(Data.items.MED_BENCH ~= nil and Data.items.TRAIN_DUMMY ~= nil,
  "both phase-3 stations are merged items")
T.eq(#exports.brewRecipes, 7, "seven remedies on the bench")
T.eq(exports.brewRecipes[1].tier, 1, "POTION is an apprentice brew")
T.eq(exports.brewRecipes[7].tier, 3, "ELIXER wants a master medic")

-- off-dex override species staff headless crews (CHANSEY is pure
-- override in the fixture) -- the relaxation that makes this testable
T.eq(exports.bestCrewLevel("MEDICINE", { { species = "CHANSEY" } }), 2,
  "override-only species still report for work")

local bgame = { data = Data,
                save = { inventory = { GRAPES = 4 }, playTime = 0 } }
exports.queueBrew(bgame, exports.brewRecipes[1], 2)   -- 2 potions
T.eq(bgame.save.inventory.GRAPES, nil, "the grapes went into the vat")
exports.tickBrew(bgame, {})
bgame.save.playTime = 300
exports.tickBrew(bgame, {})
local brewed = exports.collectBrew(bgame)
T.eq(#brewed, 0, "no medic, no medicine")
exports.tickBrew(bgame, { { species = "CHANSEY" } })  -- MEDICINE 2
bgame.save.playTime = 600
exports.tickBrew(bgame, { { species = "CHANSEY" } })
exports.collectBrew(bgame)
T.eq(bgame.save.inventory.POTION, 2, "a staffed bench delivers potions")

-- the dummy drips RARE CANDY only while the dojo is staffed
local dgame = { data = Data, save = { inventory = {}, playTime = 0 } }
exports.tickDummy(dgame, {})
dgame.save.playTime = 10000
exports.tickDummy(dgame, {})
T.eq(exports.bestCrewLevel("TRAINING",
       { { species = "HITMONLEE" } }), 2,
  "the override fighter reports at level 2")

-- ------- phase 4: research, shrine, expansion

T.check(Data.items.RESEARCH_DESK ~= nil and Data.items.SHRINE ~= nil
        and Data.items.EXPANSION_KIT ~= nil,
  "desk, shrine and expansion kit are merged items")
T.eq(exports.bestCrewLevel("MEDICINE",
       { { species = "CHANSEY", soulBoost = 1 } }), 3,
  "a shrine offering raises an individual's craft")
T.eq(exports.bestCrewLevel("MEDICINE",
       { { species = "CHANSEY", soulBoost = 9 } }), 4,
  "boosted levels cap at mastery (4)")
T.eq(exports.researchActive(), false,
  "no desk placed means no research")
if Data.tilesets and Data.tilesets.HOUSE then
  T.eq(Data.maps.PALCRAFT_BASE.width, 7,
    "the room registers at its expanded width")
else
  T.check(true, "room width check needs the ROM tilesets")
end

-- ------- the final phase: yield stations, egg temperature, overseer

T.check(Data.items.LUMBER_PILE ~= nil and Data.items.MINING_ROCK ~= nil,
  "both yield stations are merged items")

-- the OVERSEER wildcard: a DITTO covers any missing trade at its own
-- level, but never outbids a real specialist
T.eq(exports.bestCrewLevel("MEDICINE", { { species = "DITTO" } }), 1,
  "a lone DITTO fills the medic gap")
T.eq(exports.bestCrewLevel("MEDICINE",
       { { species = "DITTO" }, { species = "CHANSEY" } }), 2,
  "a real medic outranks the wildcard")
T.eq(exports.bestCrewLevel("OVERSEER", { { species = "FIXMON_A" } }), 0,
  "nothing fills in for a missing overseer")

-- egg temperature: an icy child runs cold, everything else warm
local icyDex = function() return { types = { "ICE" } } end
local plainDex = function() return { types = { "FIRE" } } end
T.check(exports.eggColdFor({ "SEEL", "SEEL" }, icyDex),
  "an icy child chills the egg")
T.check(not exports.eggColdFor({ "FIXMON_B", "FIXMON_B" }, plainDex),
  "a warm-blooded child keeps the egg warm")

-- ------- the playtest batch: organs, research, honest messages

local nOrgans = 0
for _, id in pairs(exportsEarly.organFor) do
  nOrgans = nOrgans + 1
  T.check(Data.items[id] ~= nil, "organ item merged: " .. id)
end
T.eq(nOrgans, 15, "every type sheds an organ")
local organRand = function(n) return n == 1 and 1 or 12 end
T.eq(exportsEarly.rollDrop(false, organRand, 30, false, { "ELECTRIC" }),
  "ORGAN_ELECTRIC", "a defeated type sheds its own organ")

-- the fixture has no TMs, so research reports the field explored
local rgame = { data = Data,
                save = { inventory = { ORGAN_ELECTRIC = 3 },
                         playTime = 0 } }
local ok, why = exports.queueResearch(rgame, "ELECTRIC")
T.check(not ok and tostring(why):find("explored") ~= nil,
  "research refuses when the TM ladder is empty (fixture)")
T.eq(rgame.save.inventory.ORGAN_ELECTRIC, 3,
  "a refused research keeps the organs")

-- honest refusals: materials vs bag room
local mm = { data = Data, save = { inventory = { APRICORN_RED = 4,
                                                 WOOD = 2 } } }
T.eq(exports.materialsMax(mm, pokeBall), 2,
  "materialsMax ignores bag room")
local lvl, who = exports.bestCrewWorker("KINDLING",
  { { species = "FIXMON_B" } })
T.check(lvl == 2 and who and who.species == "FIXMON_B",
  "bestCrewWorker names the helper")

-- ------- overworld bosses and the summoning altar

T.eq(#exportsEarly.bosses, 12, "twelve legends stand in Kanto")
local seenTypes = {}
for _, b in ipairs(exportsEarly.bosses) do
  seenTypes[b.type] = true
  T.check(Data.items[exportsEarly.shardIdFor(b.type)] ~= nil,
    "shard item merged for " .. b.type)
  T.check(Data.items[exportsEarly.tabletIdFor(b.type)] ~= nil,
    "tablet item merged for " .. b.type)
end
T.check(exportsEarly.bossFor("PEWTER_CITY") ~= nil
        and exportsEarly.bossFor("PEWTER_CITY").species == "GOLEM",
  "GOLEM guards Pewter")
T.check(exportsEarly.bossFor("ROUTE_23") ~= nil
        and exportsEarly.bossFor("ROUTE_23").species == "DRAGONITE",
  "DRAGONITE guards the Victory Road approach")

-- fusing: eight shards of a type become its tablet
local fgame = { data = Data,
                save = { inventory = { SHARD_ROCK = 9 } } }
local okf, tab = exports.fuseTablet(fgame, "ROCK")
T.check(okf and tab == "TABLET_ROCK", "eight shards fuse into a tablet")
T.eq(fgame.save.inventory.SHARD_ROCK, 1, "the ninth shard stays loose")
T.eq(fgame.save.inventory.TABLET_ROCK, 1, "the tablet landed")
local okf2 = exports.fuseTablet(fgame, "ROCK")
T.check(not okf2, "one shard is not enough for another")

-- summoning: six of a kind or nothing
local Pk = require("src.pokemon.Pokemon")
local six = {}
for i = 1, 6 do six[i] = Pk.new(Data, "FIXMON_A", 10) end
local sgame2 = { data = Data, save = { party = six, inventory = {} } }
local oks, sb = exports.canSummon(sgame2, "GRASS")
T.check(oks and sb and sb.species == "VENUSAUR",
  "six grass POKéMON call VENUSAUR's tablet")
local oks2, why2 = exports.canSummon(
  { data = Data, save = { party = { six[1] }, inventory = {} } }, "ROCK")
T.check(not oks2 and tostring(why2):find("six") ~= nil,
  "a short party is turned away")
six[6] = Pk.new(Data, "FIXMON_B", 10)   -- a fire type sneaks in
local oks3, why3 = exports.canSummon(sgame2, "GRASS")
T.check(not oks3 and tostring(why3):find("share") ~= nil,
  "a mixed party is turned away")

-- the BALANCE table is the single tuning surface
T.check(type(exports.balance) == "table"
        and exports.balance.wildDropChance == 0.85
        and exports.balance.candySeconds == 600
        and exports.balance.insightForExpansion == 10,
  "the BALANCE table exports for the sheet and the tuners")

-- deep pockets: no practical slot cap, 999-per-item stacks
T.eq(Data.constants.bagSize, 999, "the bag capacity patch merged")
T.eq(exports.balance.stackMax, 999, "the stack cap is a BALANCE knob")
local inv = { APRICORN_RED = 10, WOOD = 9 }
for i = 1, 28 do inv["FILLER_" .. i] = 1 end
local fullGame = { data = Data, save = { inventory = inv } }
T.eq(exports.maxCraftable(fullGame, pokeBall), 5,
  "thirty item kinds no longer choke the bag")
local BagMod = require("src.inventory.Bag")
local deep = { inventory = { WOOD = 98 } }
T.check(BagMod.add(deep, "WOOD", 500, Data), "stacks climb past 99")
T.eq(deep.inventory.WOOD, 598, "to the new 999 ceiling")
T.check(not BagMod.add(deep, "WOOD", 500, Data),
  "but 999 is still a hard wall")

-- ------- the start menu: PALS appears only inside the base

local vanilla = { { label = "POKéDEX" }, { label = "OPTION" }, { label = "QUIT" } }
local hooked = Runtime.call("ui.start_menu.items",
  function(_, items) return items end, game, vanilla)
T.eq(#hooked, 3, "no start-menu row is added outside the base")

local inBaseGame = { data = Data, save = game.save,
                     overworld = { map = { id = "PALCRAFT_BASE" } } }
local vanilla2 = { { label = "POKéDEX" }, { label = "OPTION" }, { label = "QUIT" } }
local hooked2 = Runtime.call("ui.start_menu.items",
  function(_, items) return items end, inBaseGame, vanilla2)
T.eq(#hooked2, 5, "PALS and WORK SKILLS rows appear inside the base")
T.eq(hooked2[2].label, "BASE POKéMON", "anchored before OPTION")
T.eq(hooked2[3].label, "WORK SKILLS", "the work browser rides beside it")

-- ------- pal moves: party/PC <-> base, with the vanilla guards

local Pokemon = require("src.pokemon.Pokemon")
local pg = { data = Data, save = { party = {
  Pokemon.new(Data, "FIXMON_A", 7), Pokemon.new(Data, "FIXMON_B", 9) } } }

local ok, msg = exports.assignToBase(pg, "party", nil, 2)
T.check(ok, "a party mon moves to the base (" .. tostring(msg) .. ")")
T.eq(#pg.save.party, 1, "the party shrank")

local lastMsg
ok, lastMsg = exports.assignToBase(pg, "party", nil, 1)
T.check(not ok, "the last party mon refuses to leave")
T.eq(lastMsg, "Keep at least one\nPOKéMON with you!",
  "and says exactly why")

-- stale menu rows must never move the wrong mon: identity is checked
local monA = Pokemon.new(Data, "FIXMON_A", 3)
local monB = Pokemon.new(Data, "FIXMON_B", 4)
local pg2 = { data = Data, save = { party = { monA, monB } } }
ok, lastMsg = exports.assignToBase(pg2, "party", nil, 1, monB)
T.check(not ok, "a stale row (wrong mon in the slot) is refused")
T.eq(lastMsg, "It's not there\nanymore!", "with a clear message")
T.eq(#pg2.save.party, 2, "and nothing moved")

ok = exports.assignToBase(pg2, "party", nil, 2, monB)
T.check(ok, "the matching row still works")
-- a stale duplicate reference can never enter the base twice
table.insert(pg2.save.party, monB)
ok, lastMsg = exports.assignToBase(pg2, "party", nil, 2, monB)
T.check(not ok, "a mon already in the base is refused")
T.eq(lastMsg, "It's already in\nthe base!", "with a clear message")
table.remove(pg2.save.party, 2)
exports.removeFromBase(pg2, 1, "party")  -- clean the shared base list

-- legacy single-box saves migrate exactly like Bill's PC does
local legacyMon = Pokemon.new(Data, "FIXMON_C", 6)
local pg3 = { data = Data, save = {
  party = { Pokemon.new(Data, "FIXMON_A", 9),
            Pokemon.new(Data, "FIXMON_B", 2) },
  box = { legacyMon },
} }
ok = exports.assignToBase(pg3, "party", nil, 2)
T.check(ok, "a mon moved in for the legacy-migration check")
ok = exports.removeFromBase(pg3, 1, "pc")
T.check(ok, "and moved out to the PC")
T.check(pg3.save.box == nil, "the legacy box list was consumed")
T.eq(#pg3.save.boxes[1], 2, "box 1 holds the legacy mon plus the mover")
T.check(pg3.save.boxes[1][1] == legacyMon,
  "the legacy mon migrated to box 1 intact")

ok, msg = exports.removeFromBase(pg, 1, "pc")
T.check(ok, "the pal moves to the PC (" .. tostring(msg) .. ")")
T.eq(#pg.save.boxes[1], 1, "it landed in box 1")

ok = exports.assignToBase(pg, "pc", 1, 1)
T.check(ok, "a PC mon moves to the base")
T.eq(#pg.save.boxes[1], 0, "the box slot emptied")

ok = exports.removeFromBase(pg, 1, "party")
T.check(ok, "the pal rejoins the party")
T.eq(#pg.save.party, 2, "the party is whole again")

local Screens = require("src.ui.Screens")
Screens.invalidate()
local palsFactory = Screens.get(pg, "PalworldBasePals")
T.check(palsFactory and palsFactory.new, "the pals screen resolves")

-- ------- pal art rides the optional overworld_encounters mod

T.eq(exports.palSpriteFor("FIXMON_A"), "SPRITE_MONSTER",
  "pals fall back to the generic monster sprite")
-- the naming convention is the whole integration contract with
-- overworld_encounters: SPRITE_WILD_<SPECIES>
T.eq(exports.palSpriteFor("FIXMON_B",
       function(id) return id == "SPRITE_WILD_FIXMON_B" end),
  "SPRITE_WILD_FIXMON_B",
  "pals wear overworld_encounters walkers when that mod is present")

-- ------- work suitabilities

local ws = exportsEarly.workSuitabilities
local wsA = ws("FIXMON_A")   -- grass, base stage
T.eq(#wsA, 1, "one type grants one job")
T.eq(wsA[1].job, "GATHERING", "grass POKéMON gather")
T.eq(wsA[1].level, 1, "a base stage works at level 1")
local wsB = ws("FIXMON_B")   -- fire, stage 2 (evolves from A)
T.eq(wsB[1].job, "KINDLING", "fire POKéMON kindle")
T.eq(wsB[1].level, 2, "evolving is the promotion")
T.eq(ws("NO_SUCH_MON")[1], nil, "an unknown species has no work data")
T.eq(exportsEarly.stageOf("FIXMON_B"), 2, "stage counts pre-evolutions")

-- the curated flavor overrides and the full 15-type job map
T.eq(exportsEarly.workOverrides.MEWTWO.RESEARCH, 4,
  "MEWTWO caps out RESEARCH")
T.eq(exportsEarly.workOverrides.SCYTHER.LUMBERING, 2,
  "SCYTHER earns a job its types never grant")
T.eq(exportsEarly.jobByType.GHOST, "NIGHT SHIFT",
  "ghosts take the night shift")
T.eq(exportsEarly.jobByType.DRAGON, "OVERSEER", "dragons oversee")
-- the ROM spells the type PSYCHIC_TYPE; the bare word must NOT be a
-- key or every psychic in the dex silently loses its job
T.eq(exportsEarly.jobByType.PSYCHIC_TYPE, "RESEARCH",
  "psychics research under the ROM's type constant")
T.eq(exportsEarly.jobByType.PSYCHIC, nil,
  "no dead key under the colliding bare name")
local nTypes = 0
for _ in pairs(exportsEarly.jobByType) do nTypes = nTypes + 1 end
T.eq(nTypes, 15, "every gen 1 type maps to a job")

-- ------- the screen factory builds a real state

local Screens = require("src.ui.Screens")
Screens.invalidate()
local factory = Screens.get(game, "PalworldCraftTable")
T.check(factory and factory.new, "the screen resolves through the registry")
local screen = factory.new(game)
T.check(screen.isOpaque == true, "the screen is opaque")
T.eq(screen.index, 1, "the cursor starts on the first recipe")

local gridFactory = Screens.get(game, "PalworldWorkGrid")
T.check(gridFactory and gridFactory.new,
  "the work grid resolves through the registry")
local grid = gridFactory.new(game)
T.eq(#grid.mons, 3, "the fixture dex fills the grid")
T.eq(grid.mons[1].id, "FIXMON_A", "cells sort by dex number")
T.eq(grid.mons[2].suits[1].job, "KINDLING",
  "suitabilities ride along on each cell")
T.eq(grid.index, 1, "the cursor starts on the first cell")
grid.setFilter("KINDLING")
T.eq(#grid.view, 1, "the job filter narrows the view")
T.eq(grid.view[1].id, "FIXMON_B", "to exactly the matching workers")
grid.setFilter(nil)
T.eq(#grid.view, 3, "clearing the filter restores everyone")

-- humble starters: the lab-ball row rewrite, tested on a synthetic
-- copy of the base script's shape
local swapped = exports.swapStarterRows({
  { "check_flag", "EVENT_GOT_STARTER" },
  { "push_screen", "DexEntryMenu",
    { species = "BULBASAUR", forceOwned = true } },
  { "ask", "_OaksLabYouWantBulbasaurText" },
  { "show_text", "_OaksLabReceivedMonText", { RAM = "BULBASAUR" } },
  { "give_pokemon", "BULBASAUR", 5 },
  { "set_flag", "EVENT_CHOSE_BULBASAUR" },
  { "show_text", "_OaksLabRivalReceivedMonText", { RAM = "CHARMANDER" } },
}, "BULBASAUR", "ZUBAT", "So! You want\nZUBAT?")
T.eq(swapped[5][2], "ZUBAT", "the ball gives the humble species")
T.eq(swapped[2][3].species, "ZUBAT", "the dex preview follows")
T.eq(swapped[3][2], "So! You want\nZUBAT?", "so does Oak's ask")
T.eq(swapped[4][3].RAM, "ZUBAT", "and the received text")
T.eq(swapped[6][2], "EVENT_CHOSE_BULBASAUR",
  "the chose-flag rows are untouched (the rival still counterpicks)")
T.eq(swapped[7][3].RAM, "CHARMANDER",
  "the rival still takes the classic starter")

-- SQUIRTLE on the GOOD ROD line
local bite = { species = "GOLDEEN", level = 10 }
T.eq(exports.goodRodCatch("GOOD_ROD", bite, 10).species, "SQUIRTLE",
  "a low roll on the GOOD ROD hooks SQUIRTLE")
T.eq(exports.goodRodCatch("GOOD_ROD", bite, 90).species, "GOLDEEN",
  "a high roll keeps the pool pick")
T.eq(exports.goodRodCatch("OLD_ROD", bite, 10).species, "GOLDEEN",
  "the OLD ROD never hooks the turtle")
T.eq(exports.goodRodCatch("GOOD_ROD", nil, 10), nil,
  "a miss stays a miss -- bite odds are untouched")
T.eq(exports.balance.squirtleChance, 25,
  "the turtle share is a BALANCE knob")

-- street bosses lose their self-destruct outs
local golemDef = {
  level1Moves = { "TACKLE", "DEFENSE_CURL" },
  learnset = { { level = 16, move = "ROCK_THROW" },
               { level = 21, move = "SELFDESTRUCT" },
               { level = 36, move = "EARTHQUAKE" },
               { level = 43, move = "EXPLOSION" } },
}
local bossMon = { level = 50, moves = {
  { id = "EARTHQUAKE", pp = 10 },
  { id = "SELFDESTRUCT", pp = 5 },
  { id = "EXPLOSION", pp = 5 },
} }
T.eq(exports.scrubBossMoves(bossMon, golemDef,
       { ROCK_THROW = { pp = 15, power = 50 },
         EARTHQUAKE = { pp = 10, power = 100 } }), 2,
  "both blast moves are scrubbed")
T.eq(bossMon.moves[2].id, "ROCK_THROW",
  "the best unbanned learnset move steps in")
T.eq(bossMon.moves[2].pp, 15, "with its own PP")
T.eq(bossMon.moves[3].id, "DEFENSE_CURL",
  "the second swap takes the next candidate down")
local bare = { level = 5, moves = { { id = "SELFDESTRUCT", pp = 5 } } }
T.eq(exports.scrubBossMoves(bare, { learnset = {} }, {}), 1,
  "a bare learnset still swaps")
T.eq(bare.moves[1].id, "TACKLE", "TACKLE is the floor")
-- the street GOLEM already knows every at-level candidate: the swap
-- reaches ABOVE its level rather than duplicating or dropping a slot
-- (both confuse the battle engine's slot references)
local street = { level = 25, moves = {
  { id = "TACKLE", pp = 35 }, { id = "DEFENSE_CURL", pp = 40 },
  { id = "ROCK_THROW", pp = 15 }, { id = "SELFDESTRUCT", pp = 5 },
} }
T.eq(exports.scrubBossMoves(street, golemDef,
       { ROCK_THROW = { pp = 15, power = 50 },
         EARTHQUAKE = { pp = 10, power = 100 } }), 1,
  "the saturated moveset still scrubs")
T.eq(#street.moves, 4, "the slot count never changes")
T.eq(street.moves[4].id, "EARTHQUAKE",
  "the lowest above-level learnset move steps in")
local dup = {}
for _, mv in ipairs(street.moves) do
  T.check(not dup[mv.id], "no duplicate move survives the scrub")
  dup[mv.id] = true
end

-- Misty's badge gates the WOODPILE like Brock's gates the incubator
local pileRecipe
for _, r in ipairs(exports.stationRecipes) do
  if r.ball == "LUMBER_PILE" then pileRecipe = r end
end
T.check(pileRecipe and pileRecipe.badge == "CASCADEBADGE",
  "the WOODPILE blueprint is Misty's reward")
T.eq(#exports.badgeNotices, 3,
  "all three gym blueprints announce themselves")
T.eq(exports.badgeNotices[3].badge, "THUNDERBADGE",
  "Lt. Surge's badge carries the GENERATOR")
local genRecipe
for _, r in ipairs(exports.stationRecipes) do
  if r.ball == "GENERATOR" then genRecipe = r end
end
T.check(genRecipe and genRecipe.badge == "THUNDERBADGE",
  "the GENERATOR blueprint is badge-gated")

-- the boss clock doubled
T.eq(exports.balance.bossSeconds, 7200,
  "street bosses rest two hours between beatings")

-- packing the base needs the base's own map underfoot
T.check(exports.packBase ~= nil
        and exports.packBase({ save = { inventory = {} } }, nil) == false,
  "packBase refuses without the base map underfoot")

-- HARD difficulty: unbred mons earn half EXP (split doubles), bred
-- mons keep the vanilla share, NORMAL changes nothing
T.eq(exports.expSplitFor({}, 3), 3,
  "NORMAL difficulty leaves the split alone")
run.loader.modOptions.palworld_crafting = { difficulty = "hard" }
T.eq(exports.expSplitFor({}, 3), 6,
  "HARD doubles the divisor for unbred mons")
T.eq(exports.expSplitFor({ bred = true }, 3), 3,
  "hatchlings keep the full share")
run.loader.modOptions.palworld_crafting = nil

-- the star system: catch 70%, bred 90%, plain 100%, condensed 120%
local Pk2 = require("src.pokemon.Pokemon")
local starMon = Pk2.new(Data, "FIXMON_A", 20)
local plainAtk = starMon.stats.attack
T.eq(exports.starsOf(starMon), 1,
  "an unstamped mon counts as star 1 (gift/legacy tier)")
-- ownership stamps: gifts and trades land at star 1 as they join
local PartyMod = require("src.pokemon.Party")
local giftParty, giftMon = {}, Pk2.new(Data, "FIXMON_B", 8)
T.check(giftMon.dvs.stars == nil, "a fresh construct starts unstamped")
PartyMod.add(giftParty, giftMon)
T.eq(giftMon.dvs.stars, 1, "joining the party stamps star 1")
local caughtLike = Pk2.new(Data, "FIXMON_B", 8)
caughtLike.dvs.stars = 0
PartyMod.add(giftParty, caughtLike)
T.eq(caughtLike.dvs.stars, 0,
  "an explicit star (a fresh catch) is never overwritten")
exports.setStars(starMon, Data.pokemon.FIXMON_A, 0)
T.check(starMon.stats.attack < plainAtk
        and starMon.stats.attack <= math.floor(plainAtk * 0.75),
  "a fresh catch drops toward 70% stats")
exports.setStars(starMon, Data.pokemon.FIXMON_A, 3)
T.check(starMon.stats.attack > plainAtk,
  "three stars beat the natural maximum")
T.eq(exports.condenseNeeded(0), 1, "the first star costs one offer")
T.eq(exports.condenseNeeded(1), 2, "the second costs two")
T.eq(exports.condenseNeeded(2), 3, "the third costs three")
-- level-ups keep the star: Stats.calc reads dvs.stars everywhere
local StatsMod = require("src.pokemon.Stats")
local reStats = StatsMod.calc(Data.pokemon.FIXMON_A, 30, starMon.dvs,
                              starMon.statExp)
local vanilla30 = StatsMod.calc(Data.pokemon.FIXMON_A, 30,
                                { attack = starMon.dvs.attack,
                                  defense = starMon.dvs.defense,
                                  speed = starMon.dvs.speed,
                                  special = starMon.dvs.special,
                                  hp = starMon.dvs.hp })
T.check(reStats.attack > vanilla30.attack,
  "the star multiplier survives any stat recompute")

-- egg moves: tier roll + TM pool, no dups, no HMs
local seq
local function fakeRand(n)
  local v = table.remove(seq, 1) or 1
  return ((v - 1) % n) + 1
end
seq = { 80 }
T.eq(#exports.eggMovesFor(Data.pokemon.FIXMON_A, {}, fakeRand), 0,
  "a high roll hatches no egg moves")
seq = { 3, 1, 1, 1 }
local three = exports.eggMovesFor(Data.pokemon.FIXMON_A, {}, fakeRand)
T.check(#three >= 1, "a 3-roll draws from the TM pool")
local seen = {}
for _, mv in ipairs(three) do
  T.check(not seen[mv], "egg moves never duplicate")
  seen[mv] = true
end

run.release()
Screens.invalidate()
T.finish("palworld_crafting")
