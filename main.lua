-- Palworld Crafting: Poke Balls leave the mart shelves.  Apricorns hide in
-- the overworld and drop from battle wins; the CRAFT start-menu screen
-- turns them into balls.  (Roadmap: a placeable crafting table object
-- instead of the menu row -- see README.)
--
-- Loads late (priority 1000) so the shelf filter sees every earlier mod's
-- mart additions in the merged view.

local SCREEN = "PalworldCraftTable"

return function(mod)

  -- ============================= BALANCE =============================
  -- Every tunable in one place.  PALCRAFT_<X>_SECONDS env vars override
  -- individual clocks; PALCRAFT_FAST=1 divides every clock (and recipe
  -- work time) by 10 for structural playtests.  The balance sheet
  -- artifact renders from this table + the recipe tables
  -- (tools/gen_balance_sheet.lua), so tune here and regenerate.
  local FAST = os.getenv("PALCRAFT_FAST") == "1"
  local function clock(env, default)
    local v = tonumber(os.getenv(env))
    if v then return v end
    return FAST and default / 10 or default
  end
  local BALANCE = {
    -- battle drops
    wildDropChance = 0.85, -- chance a wild win drops anything at all
    trainerDrops = 1,      -- guaranteed drops per trainer win
    seedChance = 10,       -- % per drop: bug/grass/flying opponents
    oreChance = 25,        -- % per drop: rock/ground opponents
    woodChance = 35,       -- % per drop: wilds under woodMaxLevel
    woodMaxLevel = 12,
    organChance = 15,      -- % per drop: a defeated type's ORGAN

    -- clocks, in seconds of play time
    growSeconds = clock("PALCRAFT_GROW_SECONDS", 90),
    breedSeconds = clock("PALCRAFT_BREED_SECONDS", 60),
    smeltSeconds = clock("PALCRAFT_SMELT_SECONDS", 30),
    candySeconds = clock("PALCRAFT_CANDY_SECONDS", 600),
    insightSeconds = clock("PALCRAFT_INSIGHT_SECONDS", 120),
    soulSeconds = clock("PALCRAFT_SOUL_SECONDS", 300),
    lumberSeconds = clock("PALCRAFT_LUMBER_SECONDS", 240),
    mineSeconds = clock("PALCRAFT_MINE_SECONDS", 240),
    -- per-recipe work times live on the recipes; these override them
    craftSecondsOverride = tonumber(os.getenv("PALCRAFT_CRAFT_SECONDS")),
    medSecondsOverride = tonumber(os.getenv("PALCRAFT_MED_SECONDS")),

    -- piles and caps
    candyCap = 5,          -- uncollected RARE CANDY at the dummy
    yieldCap = 5,          -- uncollected WOOD/ORE at the piles
    soulCap = 9, soulCost = 3, soulBoostMax = 2,
    palsBase = 8, palsExpanded = 12,
    insightForExpansion = 10,
    workLevelMax = 4,      -- MEWTWO's mastery; soul boosts cap here
    bagSize = 999,         -- no practical slot cap (vanilla 20)
    stackMax = 999,        -- per-item stack cap (vanilla 99)

    -- the farm: one grape per vine, no seed back -- vines are
    -- one-shot, seeds are the farming bottleneck
    harvestMin = 1, harvestMax = 1,

    -- share of successful GOOD ROD bites that hook SQUIRTLE
    squirtleChance = 25,

    -- the essence condenser: stat percentages by star, and the
    -- same-species offers each condense costs (star 0 -> 1 -> 2 -> 3)
    starCaught = 70,       -- % stats for a fresh catch (star 0)
    starBred = 90,         -- % stats for a hatchling (star 1)
    starMax = 120,         -- % stats at three stars (star 2 = 100)
    condenseCost1 = 1, condenseCost2 = 2, condenseCost3 = 3,

    -- egg moves: chance tiers for 1 / 2 / 3 bonus TM-compatible moves
    eggMove1 = 50, eggMove2 = 20, eggMove3 = 5,

    -- TM research at the desk
    organsPerTm = 3,
    tmSeconds = clock("PALCRAFT_TM_SECONDS", 600),

    -- overworld bosses and the summoning altar
    bossSeconds = clock("PALCRAFT_BOSS_SECONDS", 7200),
    shardsPerTablet = 8,
    summonMultiplier = 2,
  }
  BALANCE.fast = FAST
  mod.exports.balance = BALANCE
  mod.content.constants:patch("bagSize", BALANCE.bagSize)

  -- difficulty: NORMAL leaves the game alone; HARD halves battle EXP
  -- for POKeMON that were not hatched from the incubator, pushing the
  -- economy toward breeding, the TRAINING DUMMY and RARE CANDY
  mod.options:define({
    { key = "difficulty", label = "DIFFICULTY", type = "choice",
      default = "normal",
      choices = {
        { "NORMAL (vanilla EXP)", "normal" },
        { "HARD (unbred POKeMON earn half EXP)", "hard" },
      } },
  })

  -- deep pockets: lift Bag.add's hardcoded 99 stack cap to
  -- BALANCE.stackMax (engine_internals; faithful copy of the original
  -- add semantics with only the cap swapped)
  do
    local Bag = require("src.inventory.Bag")
    if not Bag.__palcraft_stacks then
      Bag.__palcraft_stacks = true
      Bag.add = function(save, id, qty, data)
        qty = qty or 1
        local inv = save.inventory
        if not inv[id] and not Bag.isBadge(id)
            and Bag.slots(save) >= Bag.capacity(data) then
          return false
        end
        if not Bag.isBadge(id)
            and (inv[id] or 0) + qty > BALANCE.stackMax then
          return false
        end
        local isNew = not inv[id]
        inv[id] = (inv[id] or 0) + qty
        if isNew and not Bag.isBadge(id) then
          table.insert(Bag.order(save), id)
        end
        return true
      end
    end
  end

  -- star system: a mon's dvs table carries dvs.stars (it rides every
  -- Stats.calc call site AND persists in the save, like the DVs
  -- themselves).  nil means the vanilla 100% (legacy mons, gifts,
  -- starters) and equals star 2 for condensing purposes.
  do
    local Stats = require("src.pokemon.Stats")
    if not Stats.__palcraft_stars then
      Stats.__palcraft_stars = true
      local origCalc = Stats.calc
      Stats.calc = function(def, level, dvs, statExp)
        local out = origCalc(def, level, dvs, statExp)
        local stars = dvs and dvs.stars
        if stars then
          local pct = stars == 0 and BALANCE.starCaught
            or stars == 1 and BALANCE.starBred
            or stars == 3 and BALANCE.starMax
            or 100
          if pct ~= 100 then
            for k, v in pairs(out) do
              out[k] = math.max(1, math.floor(v * pct / 100))
            end
          end
        end
        return out
      end
    end
  end
  mod.exports.starsOf = function(mon)
    local s = mon and mon.dvs and mon.dvs.stars
    return s == nil and 1 or s
  end
  mod.exports.setStars = function(mon, def, stars)
    mon.dvs = mon.dvs or {}
    mon.dvs.stars = stars
    if def and def.baseStats then
      local Stats = require("src.pokemon.Stats")
      mon.stats = Stats.calc(def, mon.level or 1, mon.dvs, mon.statExp)
      mon.hp = math.max(0, math.min(tonumber(mon.hp) or mon.stats.hp,
                                    mon.stats.hp))
    end
    return mon
  end
  mod.exports.condenseNeeded = function(stars)
    if stars <= 0 then return BALANCE.condenseCost1 end
    if stars == 1 then return BALANCE.condenseCost2 end
    return BALANCE.condenseCost3
  end

  -- everything a player OWNS is on the star ladder: gifts, starters
  -- and trades stamp star 1 as they enter the party or a box (a fresh
  -- catch already carries star 0 from the catch.rate wrap, hatchlings
  -- their star 1); enemy and link mons never pass through here, so
  -- the nil-means-100% rule in Stats.calc keeps THEM at full strength
  do
    local Party = require("src.pokemon.Party")
    local Boxes = require("src.pokemon.Boxes")
    if not Party.__palcraft_stars then
      Party.__palcraft_stars = true
      local function stampOwned(mon)
        if type(mon) ~= "table" then return end
        if mon.dvs and mon.dvs.stars ~= nil then return end
        local Data = require("src.core.Data")
        mod.exports.setStars(mon,
          Data.pokemon and Data.pokemon[mon.species], 1)
      end
      local origAdd = Party.add
      Party.add = function(party, mon, ...)
        stampOwned(mon)
        return origAdd(party, mon, ...)
      end
      local origDeposit = Boxes.deposit
      Boxes.deposit = function(save, mon, ...)
        stampOwned(mon)
        return origDeposit(save, mon, ...)
      end
    end
  end

  -- pre-existing saves join the ladder too: one sweep per load stamps
  -- every unstarred party and box mon at star 1
  mod.events:on("save.loaded", function()
    if not theGame then return end
    local Data = theGame.data
    local function sweep(list)
      for _, mon in ipairs(list or {}) do
        if type(mon) == "table" and not (mon.dvs and mon.dvs.stars) then
          mod.exports.setStars(mon,
            Data.pokemon and Data.pokemon[mon.species], 1)
        end
      end
    end
    sweep(theGame.save.party)
    for _, box in ipairs(theGame.save.boxes or {}) do sweep(box) end
  end)

  -- the ITEMS list pages with left/right (ListMenu's pageJump, which
  -- the engine leaves off for the bag)
  do
    local BagMenu = require("src.ui.BagMenu")
    if not BagMenu.__palcraft_pages then
      BagMenu.__palcraft_pages = true
      local origBagNew = BagMenu.new
      BagMenu.new = function(game, opts)
        local list = origBagNew(game, opts)
        if list then list.pageJump = true end
        return list
      end
    end
  end

  -- ------------------------------------------------------------ apricorns

  -- ordered RED/BLU/YLW to line up with the drop-band weights below;
  -- price exists so they can be sold (marts pay half) once you have more
  -- than you can craft
  local APRICORNS = {
    { id = "APRICORN_RED", name = "RED APRICORN", price = 100 },
    { id = "APRICORN_BLU", name = "BLU APRICORN", price = 150 },
    { id = "APRICORN_YLW", name = "YLW APRICORN", price = 200 },
  }
  for _, a in ipairs(APRICORNS) do
    mod.content.items:register(a.id, {
      id = a.id, name = a.name, price = a.price, tossable = true,
    })
  end

  -- WOOD is the structural half of every ball: apricorns give the
  -- shell, wood gives the frame.  Early wild battles drop it (the
  -- same roll that hands out apricorns), so the first crafting session
  -- funds itself on Route 1.
  mod.content.items:register("WOOD", {
    id = "WOOD", name = "WOOD", price = 50, tossable = true,
  })
  -- the mineral half of the chain: ROCK/GROUND wilds drop ORE, the
  -- furnace smelts it, and INGOTs buy the ultra tier
  mod.content.items:register("ORE", {
    id = "ORE", name = "ORE", price = 60, tossable = true,
  })
  mod.content.items:register("INGOT", {
    id = "INGOT", name = "INGOT", price = 150, tossable = true,
  })
  mod.content.items:register("GENERATOR", {
    id = "GENERATOR", name = "GENERATOR", price = 600,
    tossable = false, effect = "GENERATOR_EFFECT",
  })
  mod.content.items:register("FURNACE", {
    id = "FURNACE", name = "FURNACE", price = 600,
    tossable = false, effect = "FURNACE_EFFECT",
  })
  mod.content.items:register("MED_BENCH", {
    id = "MED_BENCH", name = "MED.BENCH", price = 600,
    tossable = false, effect = "MED_BENCH_EFFECT",
  })
  mod.content.items:register("TRAIN_DUMMY", {
    id = "TRAIN_DUMMY", name = "TRN.DUMMY", price = 450,
    tossable = false, effect = "TRAIN_DUMMY_EFFECT",
  })
  mod.content.items:register("RESEARCH_DESK", {
    id = "RESEARCH_DESK", name = "RSCH.DESK", price = 800,
    tossable = false, effect = "RESEARCH_DESK_EFFECT",
  })
  mod.content.items:register("SHRINE", {
    id = "SHRINE", name = "SHRINE", price = 800,
    tossable = false, effect = "SHRINE_EFFECT",
  })
  mod.content.items:register("LUMBER_PILE", {
    id = "LUMBER_PILE", name = "WOODPILE", price = 400,
    tossable = false, effect = "LUMBER_PILE_EFFECT",
  })
  mod.content.items:register("MINING_ROCK", {
    id = "MINING_ROCK", name = "ORE ROCK", price = 400,
    tossable = false, effect = "MINING_ROCK_EFFECT",
  })
  mod.content.items:register("SUMMON_ALTAR", {
    id = "SUMMON_ALTAR", name = "ALTAR", price = 3000,
    tossable = false, effect = "SUMMON_ALTAR_EFFECT",
  })
  mod.content.items:register("CONDENSER", {
    id = "CONDENSER", name = "CONDENSER", price = 800,
    tossable = false, effect = "CONDENSER_EFFECT",
  })
  mod.content.items:register("EXPANSION_KIT", {
    id = "EXPANSION_KIT", name = "EXPANSION", price = 2000,
    tossable = false, effect = "EXPANSION_KIT_EFFECT",
  })

  -- cost rows are ordered { itemId, count } pairs so the screen can
  -- draw them in a stable order; work is the queue time in seconds of
  -- play (a HANDIWORK POKéMON in the base speeds it up)
  local RECIPES = {
    { ball = "POKE_BALL", label = "POKé BALL", work = 15,
      cost = { { "APRICORN_RED", 2 }, { "WOOD", 1 } } },
    { ball = "GREAT_BALL", label = "GREAT BALL", work = 30,
      cost = { { "APRICORN_BLU", 2 }, { "APRICORN_RED", 1 },
               { "WOOD", 2 } } },
    -- the ULTRA tier runs on smelted metal, not wood
    { ball = "ULTRA_BALL", label = "ULTRA BALL", work = 60,
      cost = { { "APRICORN_YLW", 2 }, { "INGOT", 1 } } },
    -- early water access: whittle a rod, fish up a MAGIKARP
    { ball = "OLD_ROD", label = "OLD ROD", work = 30,
      cost = { { "WOOD", 3 } } },
  }

  -- the stations build FROM the economy: ore and wood, at the table
  local STATION_RECIPES = {
    -- Lt. Surge's reward: the electric badge carries the blueprint
    { ball = "GENERATOR", label = "GENERATOR", work = 60,
      badge = "THUNDERBADGE",
      cost = { { "ORE", 3 }, { "WOOD", 2 } } },
    { ball = "FURNACE", label = "FURNACE", work = 60,
      cost = { { "ORE", 2 }, { "WOOD", 2 } } },
    { ball = "MED_BENCH", label = "MED.BENCH", work = 60,
      cost = { { "WOOD", 4 }, { "ORE", 1 } } },
    { ball = "TRAIN_DUMMY", label = "TRN.DUMMY", work = 45,
      cost = { { "WOOD", 3 } } },
    { ball = "RESEARCH_DESK", label = "RSCH.DESK", work = 60,
      cost = { { "WOOD", 3 }, { "INGOT", 1 } } },
    { ball = "SHRINE", label = "SHRINE", work = 90,
      cost = { { "ORE", 3 }, { "INGOT", 1 } } },
    -- Misty's reward, like the incubator is Brock's
    { ball = "LUMBER_PILE", label = "WOODPILE", work = 45,
      badge = "CASCADEBADGE",
      cost = { { "ORE", 2 }, { "WOOD", 1 } } },
    { ball = "MINING_ROCK", label = "ORE ROCK", work = 45,
      cost = { { "WOOD", 3 }, { "INGOT", 1 } } },
    { ball = "STORAGE_CHEST", label = "CHEST", work = 45,
      cost = { { "WOOD", 4 } } },
    -- Brock's reward: the blueprint, not the machine
    { ball = "EGG_INCUBATOR", label = "INCUBATOR", work = 90,
      badge = "BOULDERBADGE",
      cost = { { "WOOD", 5 }, { "ORE", 2 } } },
    -- gear tier: whittled and banded with smelted metal; SQUIRTLE
    -- strikes this line (BALANCE.squirtleChance)
    { ball = "GOOD_ROD", label = "GOOD ROD", work = 45,
      cost = { { "WOOD", 2 }, { "INGOT", 1 } } },
    -- the essence condenser: on the table from day one -- feeding it
    -- same-species offers raises a POKeMON's star (see BALANCE)
    { ball = "CONDENSER", label = "CONDENSER", work = 60,
      cost = { { "WOOD", 2 }, { "ORE", 2 } } },
  }

  -- The MEDICINE bench brews from farm goods; tier = the MEDICINE
  -- level the crew must carry before the recipe unlocks.
  local BREW_RECIPES = {
    { ball = "POTION", label = "POTION", tier = 1, work = 30,
      cost = { { "GRAPES", 2 } } },
    { ball = "ANTIDOTE", label = "ANTIDOTE", tier = 1, work = 20,
      cost = { { "GRAPES", 1 } } },
    { ball = "SUPER_POTION", label = "SUPER POTION", tier = 2, work = 45,
      cost = { { "GRAPES", 4 } } },
    { ball = "FULL_HEAL", label = "FULL HEAL", tier = 2, work = 45,
      cost = { { "GRAPES", 3 } } },
    { ball = "REVIVE", label = "REVIVE", tier = 2, work = 90,
      cost = { { "GRAPES", 4 }, { "FERMENTED_JUICE", 1 } } },
    { ball = "HYPER_POTION", label = "HYPER POTION", tier = 3, work = 60,
      cost = { { "GRAPES", 6 }, { "FERMENTED_JUICE", 1 } } },
    { ball = "ELIXER", label = "ELIXER", tier = 3, work = 120,
      cost = { { "FERMENTED_JUICE", 2 } } },
  }

  -- MK2 exclusives: a powered base table crafts evolution stones
  -- (Celadon's money-gate, farmable at last)
  local MK2_RECIPES = {
    { ball = "FIRE_STONE", label = "FIRE STONE", work = 90,
      cost = { { "INGOT", 1 }, { "APRICORN_RED", 3 } } },
    { ball = "WATER_STONE", label = "WATER STONE", work = 90,
      cost = { { "INGOT", 1 }, { "APRICORN_BLU", 3 } } },
    { ball = "THUNDER_STONE", label = "THUNDERSTONE", work = 90,
      cost = { { "INGOT", 1 }, { "APRICORN_YLW", 3 } } },
    { ball = "LEAF_STONE", label = "LEAF STONE", work = 90,
      cost = { { "INGOT", 1 }, { "GRAPES", 3 } } },
    { ball = "MOON_STONE", label = "MOON STONE", work = 120,
      cost = { { "INGOT", 2 } } },
    -- the desk's discovery: blueprints for a whole east wing.
    -- insight is the RESEARCH points the desk accrues.
    { ball = "EXPANSION_KIT", label = "EXPANSION", work = 120,
      insight = BALANCE.insightForExpansion,
      cost = { { "WOOD", 6 }, { "ORE", 4 }, { "INGOT", 2 } } },
    { ball = "SUMMON_ALTAR", label = "ALTAR", work = 120,
      cost = { { "INGOT", 3 }, { "ORE", 4 } } },
  }

  -- --------------------------------------------- marts lose their balls

  local function isBallItem(id)
    if mod.content.balls:get(id) ~= nil then return true end
    -- evolution stones are craft-only now (the MK2 table): they leave
    -- the shelves with the balls
    if id == "MOON_STONE" or id == "FIRE_STONE" or id == "WATER_STONE"
       or id == "THUNDER_STONE" or id == "LEAF_STONE" then
      return true
    end
    local def = mod.content.items:get(id)
    return def ~= nil and def.ball ~= nil
  end

  -- Collect first, patch after: don't append ops to a registry while
  -- iterating its merged view.
  local shelfPatches, shelvesTouched = {}, 0
  local martRefs = {}  -- every (group, key) with a shelf; the table joins them all
  for groupId, group in mod.content.text_pointers:each() do
    for key, entry in pairs(group) do
      if type(entry) == "table" and type(entry.mart) == "table" then
        martRefs[#martRefs + 1] = { groupId, key }
        local kept, dropped = {}, 0
        for _, itemId in ipairs(entry.mart) do
          if isBallItem(itemId) then dropped = dropped + 1
          else kept[#kept + 1] = itemId end
        end
        if dropped > 0 then
          -- a shelf that sold only balls must not end up empty: the merge
          -- treats {} as a dictionary no-op and the clerk would keep a
          -- deleted mart list
          if #kept == 0 then kept[1] = "POTION" end
          shelfPatches[#shelfPatches + 1] = { groupId, key, kept }
        end
      end
    end
  end
  for _, p in ipairs(shelfPatches) do
    -- text_pointers is a deep registry, where a bare list CONCATS onto the
    -- existing one -- tombstone the shelf first, then lay down the copy
    mod.content.text_pointers:patch(p[1], { [p[2]] = { mart = mod.DELETE } })
    mod.content.text_pointers:patch(p[1], { [p[2]] = { mart = p[3] } })
    shelvesTouched = shelvesTouched + 1
  end
  mod.log:info("removed balls from %d mart shelves", shelvesTouched)

  -- --------------------------------------- apricorns visible in the world

  -- Original 16x16 art, one tint per apricorn.  trueColor opts the
  -- sprites out of the engine's 4-shade re-shade (the shiny-palette
  -- example's trick), so the colors survive every palette zone.
  local SPRITE_FOR = {
    APRICORN_RED = "SPRITE_APRICORN_RED",
    APRICORN_BLU = "SPRITE_APRICORN_BLU",
    APRICORN_YLW = "SPRITE_APRICORN_YLW",
  }
  for item, spriteId in pairs(SPRITE_FOR) do
    mod.content.sprites:register(spriteId, {
      id = spriteId,
      image = mod.assets:path(("assets/apricorn_%s.png"):format(item:sub(-3):lower())),
      frames = 1,
      walker = false,
      trueColor = true,
    })
  end

  -- The apricorn art is a transparent CUTOUT, which trueColor sprites do
  -- not normally support: SpriteRenderer exempts the whole 16x16 cell
  -- from the palette shader, so the map showing through the holes would
  -- render as unshaded gray.  Under the declared engine_internals
  -- permission, swap that full-cell exemption for per-row rects matching
  -- each sprite's actual opaque pixels: the fruit keeps its true colors
  -- and the grass around it keeps the map palette.  Other trueColor
  -- sprites (player skins etc.) are untouched -- the mask only engages
  -- for images this mod registered.
  local cutoutMasks  -- image path -> per-frame masks, or false when unreadable

  -- Per-frame, per-row opaque spans of a 16xN sprite sheet, with a
  -- pre-mirrored variant for flipped blits (right-facing and alternate
  -- up/down steps draw the frame mirrored), so the shader exemption
  -- matches the drawn pixels exactly.
  local function maskFromImage(path, frames)
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then return false end
    local w, h = data:getWidth(), data:getHeight()
    frames = math.max(1, math.min(frames or 1, math.floor(h / 16)))
    local out = {}
    for f = 0, frames - 1 do
      local norm, flip = {}, {}
      for r = 0, 15 do
        local yy = f * 16 + r
        local x1, x2
        if yy < h then
          for x = 0, math.min(15, w - 1) do
            local _, _, _, a = data:getPixel(x, yy)
            if a >= 0.5 then
              x1 = x1 or x
              x2 = x
            end
          end
        end
        if x1 then
          norm[#norm + 1] = { x1, r, x2 - x1 + 1, 1 }
          flip[#flip + 1] = { 15 - x2, r, x2 - x1 + 1, 1 }
        end
      end
      out[f + 1] = { norm = norm, flip = flip }
    end
    return out
  end

  local function loadCutoutMasks()
    if cutoutMasks then return end
    cutoutMasks = {}
    for item in pairs(SPRITE_FOR) do
      local path = mod.assets:path(("assets/apricorn_%s.png"):format(item:sub(-3):lower()))
      cutoutMasks[path] = maskFromImage(path, 1)
    end
    for _, file in ipairs({ "assets/incubator.png", "assets/incubator_egg.png",
                            "assets/vine_young.png", "assets/vine_grown.png" }) do
      local path = mod.assets:path(file)
      cutoutMasks[path] = maskFromImage(path, 1)
    end
  end
  mod.events:on("game.ready", loadCutoutMasks)

  local PaletteFX = require("src.render.PaletteFX")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  if not SpriteRenderer.__palcraft_cutout then
    SpriteRenderer.__palcraft_cutout = true
    local origDraw = SpriteRenderer.draw
    local origMark = PaletteFX.markTrueColor
    local activeMask
    PaletteFX.markTrueColor = function(x, y, w, h)
      local m = activeMask
      if not m then return origMark(x, y, w, h) end
      for _, r in ipairs(m) do
        origMark(x + r[1], y + r[2], r[3], r[4])
      end
    end
    SpriteRenderer.draw = function(self, px, py, camX, camY,
                                   facing, walkPhase, stepFlip, topHalf)
      local def = self.def
      if cutoutMasks and def and def.trueColor and def.image then
        local m = cutoutMasks[def.image]
        -- follower walkers (base pals) resolve lazily on first draw
        if m == nil and tostring(def.image):find(
             "overworld_encounters/assets/sprites/", 1, true) then
          m = maskFromImage(def.image, def.frames)
          cutoutMasks[def.image] = m
        end
        if m then
          -- mirror the engine's own frame/flip selection exactly
          local frame, flip = 0, false
          if (def.frames or 1) > 1 then
            frame = (def.walker and walkPhase == 1)
                    and SpriteRenderer.WALK[facing]
                    or SpriteRenderer.STAND[facing]
            frame = frame or 0
            if facing == "right" then
              flip = true
            elseif (facing == "down" or facing == "up")
                   and walkPhase == 1 and stepFlip then
              flip = true
            end
          end
          local fm = m[frame + 1] or m[1]
          activeMask = fm and (flip and fm.flip or fm.norm) or nil
        end
      end
      origDraw(self, px, py, camX, camY,
               facing, walkPhase, stepFlip, topHalf)
      activeMask = nil
    end
  end

  -- Visible pickups, like vanilla's Poke Ball item objects: the engine
  -- gives the item, persists the find in save.itemsTaken, and despawns
  -- the sprite (OverworldController's item-ball branch).  One-time finds;
  -- battles are the renewable source.
  -- every coordinate verified walkable on the real maps (the eye-check
  -- driver sweeps them; tests/README explain how to re-verify after edits).
  -- Colors tier with the region: RED near home, BLU mid-Kanto, YLW in the
  -- late stretches -- matching where each ball tier earns its keep.
  -- Colors track party progression through each area, matching the drop
  -- bands: RED where wilds sit under ~L12, BLU through the L15-30 belt,
  -- YLW only along the L30+ stretches.
  local SPOTS = {
    -- Pallet to Pewter (~L3-12): RED country
    ROUTE_1         = { { 8, 12, "APRICORN_RED" }, { 16, 29, "APRICORN_RED" },
                        { 12, 20, "APRICORN_RED" } },
    ROUTE_2         = { { 3, 38, "APRICORN_RED" }, { 13, 57, "APRICORN_RED" },
                        { 7, 17, "APRICORN_RED" } },
    ROUTE_22        = { { 13, 8, "APRICORN_RED" }, { 30, 11, "APRICORN_RED" } },
    VIRIDIAN_FOREST = { { 6, 16, "APRICORN_RED" }, { 25, 29, "APRICORN_RED" },
                        { 15, 40, "APRICORN_RED" }, { 27, 9, "APRICORN_RED" } },
    -- Mt Moon through the Vermilion ring (~L12-25): BLU moves in
    ROUTE_3         = { { 18, 6, "APRICORN_RED" }, { 30, 10, "APRICORN_BLU" } },
    ROUTE_4         = { { 24, 7, "APRICORN_BLU" }, { 9, 4, "APRICORN_RED" } },
    ROUTE_24        = { { 10, 20, "APRICORN_BLU" }, { 11, 9, "APRICORN_RED" } },
    ROUTE_25        = { { 27, 7, "APRICORN_BLU" }, { 11, 4, "APRICORN_RED" } },
    ROUTE_5         = { { 12, 20, "APRICORN_RED" }, { 7, 10, "APRICORN_BLU" } },
    ROUTE_6         = { { 8, 15, "APRICORN_BLU" }, { 14, 24, "APRICORN_RED" } },
    ROUTE_7         = { { 9, 9, "APRICORN_BLU" } },
    ROUTE_8         = { { 7, 4, "APRICORN_BLU" }, { 24, 12, "APRICORN_RED" } },
    ROUTE_9         = { { 30, 7, "APRICORN_BLU" }, { 12, 12, "APRICORN_BLU" } },
    ROUTE_10        = { { 7, 20, "APRICORN_BLU" }, { 14, 59, "APRICORN_BLU" } },
    ROUTE_11        = { { 25, 11, "APRICORN_RED" }, { 35, 9, "APRICORN_BLU" } },
    -- Lavender south, the cycling road, the sea routes, Victory Road
    -- (~L25-40+): YLW appears
    ROUTE_12        = { { 10, 30, "APRICORN_BLU" }, { 11, 78, "APRICORN_YLW" } },
    ROUTE_13        = { { 24, 8, "APRICORN_BLU" }, { 44, 11, "APRICORN_YLW" } },
    ROUTE_14        = { { 9, 30, "APRICORN_YLW" } },
    ROUTE_15        = { { 20, 10, "APRICORN_BLU" }, { 40, 13, "APRICORN_YLW" } },
    ROUTE_16        = { { 12, 5, "APRICORN_BLU" } },
    ROUTE_17        = { { 9, 40, "APRICORN_YLW" }, { 14, 99, "APRICORN_BLU" } },
    ROUTE_18        = { { 30, 9, "APRICORN_BLU" } },
    ROUTE_19        = { { 13, 5, "APRICORN_YLW" } },
    ROUTE_21        = { { 5, 24, "APRICORN_YLW" } },
    ROUTE_23        = { { 13, 20, "APRICORN_YLW" }, { 7, 60, "APRICORN_YLW" } },
  }
  mod.exports.spots = SPOTS

  for mapId, spots in pairs(SPOTS) do
    -- only patch maps that exist in the merged world: keeps the mod clean
    -- on the ROM-free fixture and under total conversions that drop routes
    if mod.content.maps:get(mapId) ~= nil then
      local rows = {}
      for i, s in ipairs(spots) do
        rows[#rows + 1] = {
          -- high indexes stay clear of every vanilla object on these maps
          index = 90 + i,
          name = ("PALCRAFT_APRICORN_%s_%d"):format(mapId, i),
          x = s[1], y = s[2], item = s[3],
          sprite = SPRITE_FOR[s[3]], movement = "STAY", range = "NONE",
          text = "TEXT_PALCRAFT_APRICORN",
        }
      end
      mod.content.maps:patch(mapId, { objects = { __append = rows } })
    end
  end

  -- ------------------------- ground balls become apricorns too

  -- Vanilla leaves a few free balls lying around (Viridian Forest's Poke
  -- Ball, Cerulean Cave's Ultra Balls, and six hidden Great/Ultra Balls);
  -- with the shops dry those would undercut crafting, so each becomes the
  -- matching apricorn.  Master Ball story gifts stay untouched.
  local BALL_TO_APRICORN = {
    POKE_BALL  = "APRICORN_RED",
    GREAT_BALL = "APRICORN_BLU",
    ULTRA_BALL = "APRICORN_YLW",
  }
  mod.exports.ballToApricorn = BALL_TO_APRICORN

  -- Visible ball objects: swap item and sprite.  The whole objects array
  -- is re-laid (a bare array replaces under record semantics) because a
  -- sparse index-keyed patch reads as a dictionary -- or, patching only
  -- index 1, as a one-element array that would wipe the list.
  local swappedObjects, objectPatches = 0, {}
  for mapId, mapDef in mod.content.maps:each() do
    local touched = false
    for _, obj in ipairs(mapDef.objects or {}) do
      if obj.item and BALL_TO_APRICORN[obj.item] then
        touched = true
        break
      end
    end
    if touched then
      local objects = {}
      for i, obj in ipairs(mapDef.objects) do
        local copy = {}
        for k, v in pairs(obj) do copy[k] = v end
        local swap = obj.item and BALL_TO_APRICORN[obj.item]
        if swap then
          copy.item, copy.sprite = swap, SPRITE_FOR[swap]
          swappedObjects = swappedObjects + 1
        end
        objects[i] = copy
      end
      objectPatches[#objectPatches + 1] = { mapId, objects }
    end
  end
  for _, p in ipairs(objectPatches) do
    mod.content.maps:patch(p[1], { objects = p[2] })
  end

  -- Hidden ball finds: same trade, still hidden.  Deep-registry lists
  -- concat on patch, so tombstone-then-rewrite like the mart shelves.
  local hiddenPatches = {}
  for mapId, list in pairs(mod.content.field:get("hiddenItems") or {}) do
    local touched = false
    for _, h in ipairs(list) do
      if BALL_TO_APRICORN[h.item] then
        touched = true
        break
      end
    end
    if touched then
      local rows = {}
      for i, h in ipairs(list) do
        rows[i] = { x = h.x, y = h.y, item = BALL_TO_APRICORN[h.item] or h.item }
      end
      hiddenPatches[#hiddenPatches + 1] = { mapId, rows }
    end
  end
  for _, p in ipairs(hiddenPatches) do
    mod.content.field:patch("hiddenItems", { [p[1]] = mod.DELETE })
    mod.content.field:patch("hiddenItems", { [p[1]] = p[2] })
  end
  mod.log:info("swapped %d ground balls and %d hidden-ball maps to apricorns",
               swappedObjects, #hiddenPatches)

  -- ------------------------------------ the placeable crafting table

  -- The engine merges the documented item_effects registry but (as of
  -- this build) never dispatches it: vanilla ItemEffects.use falls
  -- through to "not the time" for unknown items.  Wire the wiki's
  -- contract in ourselves: any item whose `effect` names a registered
  -- record with a `use` function routes through it, speaking the same
  -- result verbs.  This is the engine_internals require the manifest
  -- declares; the guard flag keeps a dev hot reload from double-wrapping.
  local ItemEffects = require("src.inventory.ItemEffects")
  if not ItemEffects.__palcraft_effect_dispatch then
    ItemEffects.__palcraft_effect_dispatch = true
    local vanillaUse = ItemEffects.use
    ItemEffects.use = function(data, save, itemId, target, battle, moveIndex, ow)
      local def = data.items and data.items[itemId]
      local rec = def and def.effect and data.item_effects
                  and data.item_effects[def.effect]
      if rec and type(rec.use) == "function" then
        if (battle and not rec.battle) or (not battle and not rec.field) then
          return "failed", { "This isn't the\ntime to use that!" }
        end
        return rec.use(data, save, itemId, target, battle, moveIndex, ow)
      end
      return vanillaUse(data, save, itemId, target, battle, moveIndex, ow)
    end
  end

  mod.content.items:register("CRAFT_TABLE", {
    id = "CRAFT_TABLE", name = "CRAFT TABLE", price = 500,
    tossable = false, effect = "CRAFT_TABLE_EFFECT",
  })
  -- DMG-format on purpose (three grays, white = transparent, NO
  -- trueColor): a trueColor sprite exempts its whole 16x16 cell from the
  -- palette shader, which turns transparent pixels into an unshaded gray
  -- box.  Engine-native shades render the table's cut-out silhouette
  -- cleanly and tint it with each map's palette like vanilla furniture.
  mod.content.sprites:register("SPRITE_CRAFT_TABLE", {
    id = "SPRITE_CRAFT_TABLE",
    image = mod.assets:path("assets/craft_table.png"),
    frames = 1, walker = false,
  })

  -- the table is a gift, not a purchase: it arrives with the SECRET
  -- BASE kit when the POKeDEX lands (no mart shelf carries it)

  -- Placements persist in mod.save.  A runtime spawn lands in the merged
  -- map data and stays there for the whole session (the engine rebuilds
  -- it on every map entry), so a table is spawned exactly once per
  -- placement -- at USE time, or in one resync pass when a save is
  -- adopted.  spawnNpc returns the npc ID STRING (not the npc table the
  -- wiki sketch suggests).
  local tableNpcs = {}  -- placeKey -> runtime npc id, this session

  local function placeKey(mapId, x, y) return mapId .. "|" .. x .. "|" .. y end

  local function spawnOne(t)
    if not mod.world then return end
    local key = placeKey(t.map, t.x, t.y)
    if tableNpcs[key] then return end
    local npcId = mod.world:spawnNpc(t.map, {
      x = t.x, y = t.y,
      sprite = "SPRITE_CRAFT_TABLE", movement = "STAY", range = "NONE",
      text = "TEXT_PALCRAFT_TABLE",
    })
    if type(npcId) == "string" then tableNpcs[key] = npcId end
  end

  -- adopting a save (Continue, or a New Game skeleton) resets the world:
  -- clear this session's spawns, then re-spawn the incoming save's tables
  local function resyncTables(save)
    for key, id in pairs(tableNpcs) do
      if mod.world then mod.world:removeNpc(id) end
      tableNpcs[key] = nil
    end
    local bucket = save and save.modData and save.modData[mod.id]
    for _, t in ipairs(bucket and bucket.tables or {}) do
      spawnOne(t)
    end
  end
  mod.events:on("save.loaded", function(ev) resyncTables(ev.save) end)
  mod.events:on("save.created", function(ev) resyncTables(ev.save) end)

  local FACING_DELTA = {
    up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
  }
  local function facedCell(ow)
    local p = ow.player
    local d = FACING_DELTA[p.facing] or FACING_DELTA.down
    return p.cellX + d[1], p.cellY + d[2]
  end

  mod.content.item_effects:register("CRAFT_TABLE_EFFECT", {
    field = true, battle = false,
    use = function(data, save, itemId, target, battle, moveIndex, ow)
      if not ow or not ow.player or ow.player.surfing or not ow.map then
        return "failed", { "Can't set it up\nhere!" }
      end
      -- base furniture, like every other station
      if ow.map.id ~= "PALCRAFT_BASE" then
        return "failed", { "The CRAFT TABLE\nonly sets up in\nyour base!" }
      end
      local x, y = facedCell(ow)
      local blocked = not (ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y))
      if not blocked then
        for _, npc in ipairs(ow.npcs or {}) do
          if npc.cellX == x and npc.cellY == y then
            blocked = true
            break
          end
        end
      end
      if blocked then
        return "failed", { "Can't set it up\nhere!" }
      end
      local placement = { map = ow.map.id, x = x, y = y }
      local placements = mod.save:get("tables", {})
      placements[#placements + 1] = placement
      mod.save:set("tables", placements)
      spawnOne(placement)
      return "consumed", { (save.player and save.player.name or "You")
        .. " set up the\nCRAFT TABLE!" }
    end,
  })

  -- the table's talk menu, registered under every map so a table works
  -- wherever it lands
  mod.commands:register("palcraft_if_packup", function(ctx, label)
    if ctx.lastChoice and ctx.lastChoice.index == 2 then return label end
  end)

  mod.commands:register("palcraft_pack_up", function(ctx)
    ctx.lastCheck = false
    local ow = ctx.overworld
    if not ow then return end
    local x, y = facedCell(ow)
    local placements = mod.save:get("tables", {})
    local idx
    for i, t in ipairs(placements) do
      if t.map == ow.map.id and t.x == x and t.y == y then
        idx = i
        break
      end
    end
    if not idx then return end
    local inv = ctx.save.inventory
    if not inv.CRAFT_TABLE then
      -- a new slot only fits when the bag has room
      local slots = 0
      local cap = (ctx.game.data.constants and ctx.game.data.constants.bagSize) or 20
      for id in pairs(inv) do
        if not id:find("BADGE", 1, true) then slots = slots + 1 end
      end
      if slots >= cap then return end
    end
    table.remove(placements, idx)
    mod.save:set("tables", placements)
    -- remove by the LIVE npc's own id (robust even if this session never
    -- spawned it -- e.g. a hot reload rebuilt the map around it)
    if mod.world then
      for _, npc in ipairs(ow.npcs or {}) do
        if npc.cellX == x and npc.cellY == y and npc.def
           and npc.def.sprite == "SPRITE_CRAFT_TABLE" then
          mod.world:removeNpc(npc.id)
          break
        end
      end
    end
    tableNpcs[placeKey(ow.map.id, x, y)] = nil
    inv.CRAFT_TABLE = (inv.CRAFT_TABLE or 0) + 1
    ctx.lastCheck = true
  end)

  local TABLE_TALK = {
    { "face_player" },
    { "choice", { "CRAFT", "PACK UP", "CANCEL" }, { cancel = 3 } },
    { "jump_if_true", "craft" },
    { "palcraft_if_packup", "packup" },
    { "jump", "end" },
    { "label", "craft" },
    { "push_screen", SCREEN },
    { "jump", "end" },
    { "label", "packup" },
    { "palcraft_pack_up" },
    { "jump_if_false", "noroom" },
    { "show_text", "Packed up the\nCRAFT TABLE." },
    { "jump", "end" },
    { "label", "noroom" },
    { "show_text", "No room in the\nbag for it!" },
  }
  local talkMaps = {}
  for mapId in mod.content.maps:each() do talkMaps[#talkMaps + 1] = mapId end
  for _, mapId in ipairs(talkMaps) do
    mod.content.map_scripts:register(mapId, {
      talk = { TEXT_PALCRAFT_TABLE = TABLE_TALK },
    })
  end

  -- starter kit: one CRAFT TABLE and one SECRET BASE.  New games get them
  -- through the hook; older saves on their first load with the mod active
  -- (one-shot mod.save flags, granted only while the bag has room).
  -- The journey earns the gear now: the SECRET BASE arrives with the
  -- POKéDEX, the CRAFT TABLE comes from the mart, and the INCUBATOR
  -- is Brock's blueprint.  New games start with a few ball frames.
  local STARTER_KIT = {
    { item = "WOOD", flag = "wood_given", count = 3 },
  }

  mod.hooks:wrap("save.new_game", function(next, save)
    save = next(save)
    if type(save) == "table" then
      save.inventory = save.inventory or {}
      save.modData = save.modData or {}
      save.modData[mod.id] = save.modData[mod.id] or {}
      for _, kit in ipairs(STARTER_KIT) do
        save.inventory[kit.item] = (save.inventory[kit.item] or 0)
          + (kit.count or 1)
        save.modData[mod.id][kit.flag] = true
      end
    end
    return save
  end)

  mod.events:on("save.loaded", function(ev)
    local save = ev.save
    if not save or not save.inventory then return end
    save.modData = save.modData or {}
    save.modData[mod.id] = save.modData[mod.id] or {}
    local bucket = save.modData[mod.id]
    for _, kit in ipairs(STARTER_KIT) do
      if not bucket[kit.flag] then
        if save.inventory[kit.item] then
          bucket[kit.flag] = true
        else
          local slots = 0
          for id in pairs(save.inventory) do
            if not id:find("BADGE", 1, true) then slots = slots + 1 end
          end
          if slots < 20 then  -- full bag: retry next load
            save.inventory[kit.item] = kit.count or 1
            bucket[kit.flag] = true
          end
        end
      end
    end
  end)

  -- ------------------------------------------- the secret base

  -- A placeable, enterable hideout: USE the SECRET BASE item to build the
  -- entrance on the faced cell (one per save), press A on it for
  -- ENTER / PACK UP, and ENTER warps into a private 10x10 cave room.
  -- Stepping onto the room's bottom row walks back out to where you stood.
  -- Future work hangs off this room: placeable crafting stations inside.

  mod.content.items:register("SECRET_BASE", {
    id = "SECRET_BASE", name = "SECRET BASE", price = 0,
    tossable = false, effect = "SECRET_BASE_EFFECT",
  })
  mod.content.sprites:register("SPRITE_SECRET_BASE", {
    id = "SPRITE_SECRET_BASE",
    image = mod.assets:path("assets/secret_base.png"),
    frames = 1, walker = false,
  })

  -- The room: 5x5 blocks of plain cave floor (CAVERN block 1 = all
  -- tile-32, fully walkable) = 10x10 walkable cells.  The solid-rock
  -- border block fills the view past the edges, and the map edge itself
  -- blocks movement, so no wall blocks are needed.
  local BASE_MAP = "PALCRAFT_BASE"
  -- the room needs the real HOUSE tileset: on the ROM-free fixture it
  -- (and its song) skip themselves, like the SPOTS placements do.
  -- Layout, straight from Blue's house: 5 wide x 6 tall blocks.  Top row
  -- is the wallpaper wall (PC-desk corner 16, plain 5, corner 9 -- upper
  -- cell wall, lower cell floor), the middle is plain floor (15), and the
  -- bottom row centers the door-mat block (11, mat tile on its lower
  -- cells).  The two mat cells carry edge warps, the mart/pokecenter
  -- idiom: standing on the mat keeps the warp flag and pressing down
  local applyBaseWing   -- bound inside the tileset guard below
  -- takes the warp.  Border 10 is the interior black void.  HOUSE block
  -- 16 draws a computer on a desk; the base wants just the computer, so
  -- a composed block joins the PC's two tile columns with block 5's
  -- window-wall columns, appended as a NEW block id (vanilla HOUSE maps
  -- never see it).  The monitor fills the block's left cell column, so
  -- the PC trigger cell is (0,1), faced from (0,2) looking up.
  if mod.content.tilesets:get("HOUSE") ~= nil then
    local house = mod.content.tilesets:get("HOUSE")
    local houseBlocks = {}
    for i, row in ipairs(house.blocks) do houseBlocks[i] = row end
    local pcRow, wallRow = house.blocks[16 + 1], house.blocks[5 + 1]
    local composed = {}
    for r = 0, 3 do
      for c = 0, 3 do
        composed[r * 4 + c + 1] =
          c < 2 and pcRow[r * 4 + c + 1] or wallRow[r * 4 + c + 1]
      end
    end
    houseBlocks[#houseBlocks + 1] = composed
    local PC_CORNER = #houseBlocks - 1  -- block ids are 0-based

    -- The farm's tilled ground is a real FLOOR: transforms.lua appends
    -- CAVERN's cave-floor tile to the house sheet as tile 96, and this
    -- block lays 2x2 cells of it.  The dirt stays put when a vine npc
    -- grows on top -- and it is NOT in the walkable list, so nobody
    -- tramples the crops; you tend the patch from its edge.
    local DIRT_TILE = 96
    local dirt = {}
    for i = 1, 16 do dirt[i] = DIRT_TILE end
    houseBlocks[#houseBlocks + 1] = dirt
    local DIRT_BLOCK = #houseBlocks - 1

    -- the room wears its own derived tileset: the HOUSE sheet plus the
    -- extra tile row, written by transforms.lua into mod-derived
    local walkable = {}
    for i, t in ipairs(house.walkable or {}) do walkable[i] = t end
    mod.content.tilesets:register("PALCRAFT_HOUSE", {
      id = "PALCRAFT_HOUSE",
      image = "save/mod-derived/" .. mod.id
        .. "/tilesets/palcraft_house.png",
      imageWidth = 128, imageHeight = 56, tilesPerRow = 16,
      blocks = houseBlocks, walkable = walkable,
      counterTiles = house.counterTiles, doorTiles = house.doorTiles,
      warpTiles = house.warpTiles, animation = house.animation,
    })

    local WALL, WALL_R, DOOR, FLOOR, VOID = 5, 9, 11, 15, 10
    -- The map registers at its EXPANDED size (7 blocks wide) with the
    -- east wing (block cols 5-6) sealed as void; the EXPANSION KIT
    -- rewrites those blocks to floor at runtime.  Everything west of
    -- the wing keeps the coordinates it has always had.
    local blocks = {}
    for row = 0, 5 do
      for col = 0, 6 do
        local b = FLOOR
        if col >= 5 then b = VOID
        elseif row == 0 then
          b = col == 0 and PC_CORNER or (col == 4 and WALL_R or WALL)
        end
        blocks[row * 7 + col + 1] = b
      end
    end
    blocks[5 * 7 + 2 + 1] = DOOR       -- mat cells (4-5, 11), as ever
    blocks[2 * 7 + 1 + 1] = DIRT_BLOCK -- cells (2-3, 4-5), the patch
    mod.content.maps:register(BASE_MAP, {
      id = BASE_MAP, label = "SECRET BASE", index = 1001,
      tileset = "PALCRAFT_HOUSE", width = 7, height = 6,
      blocks = blocks, borderBlock = 10,
      warps = {
        -- self-referencing sentinel: the warp.destination hook below
        -- rewrites these to wherever the base entrance stands outside
        { destMap = BASE_MAP, destWarp = 1, x = 4, y = 11 },
        { destMap = BASE_MAP, destWarp = 1, x = 5, y = 11 },
      },
      objects = {
        -- housewarming gift: one LEMONADE in a vanilla item ball, waiting
        -- the first time the player steps in.  A static map object, so
        -- the engine handles the pickup and the once-per-save persistence
        -- (save.itemsTaken) with no code from us.
        { index = 1, item = "FERMENTED_JUICE", movement = "STAY",
          name = "PALCRAFT_BASE_JUICE", range = "NONE",
          sprite = "SPRITE_POKE_BALL", text = "TEXT_PALCRAFT_LEMONADE",
          x = 6, y = 9 },
      },
      -- the four farm plots answer A with a planting prompt
      signs = {
        { x = 2, y = 4, text = "TEXT_PALCRAFT_DIRT" },
        { x = 3, y = 4, text = "TEXT_PALCRAFT_DIRT" },
        { x = 2, y = 5, text = "TEXT_PALCRAFT_DIRT" },
        { x = 3, y = 5, text = "TEXT_PALCRAFT_DIRT" },
      },
    })
    if mod.content.music:get("Music_PalletTown") ~= nil then
      mod.content.map_songs:register(BASE_MAP, "Music_PalletTown")
    end

    -- the wing's two block columns, in both states; (4,0) trades the
    -- corner shelf for plain wall when the east wall moves out
    local WING_SEALED = { { 4, 0, WALL_R } }
    local WING_OPEN = { { 4, 0, WALL } }
    for row = 0, 5 do
      for col = 5, 6 do
        WING_SEALED[#WING_SEALED + 1] = { col, row, VOID }
        local b = FLOOR
        if row == 0 then b = col == 6 and WALL_R or WALL end
        WING_OPEN[#WING_OPEN + 1] = { col, row, b }
      end
    end
    applyBaseWing = function(level, ow)
      local def = mod.content.maps:get(BASE_MAP)
      if not def then return end
      local list = level >= 2 and WING_OPEN or WING_SEALED
      local inBase = ow and ow.map and ow.map.id == BASE_MAP
      for _, w in ipairs(list) do
        if inBase and mod.world then
          mod.world:replaceBlock(w[1], w[2], w[3])
        else
          def.blocks[w[2] * def.width + w[1] + 1] = w[3]
        end
      end
      if not inBase and mod.world then
        mod.world:invalidateMap(BASE_MAP)
      end
    end
    mod.events:on("save.loaded", function()
      applyBaseWing(mod.save:get("base_level") or 1)
    end)
    mod.events:on("save.created", function()
      applyBaseWing(mod.save:get("base_level") or 1)
    end)
    -- the desk PC is a real Pokémon Center-style PC: pcTiles entries make
    -- the engine's interact pass open the full PC menu (SOMEONE'S/BILL'S
    -- PC, item storage, LOG OFF) when the player faces that cell
    mod.content.field:patch("hiddenExtras", {
      pcTiles = { [BASE_MAP] = mod.DELETE },
    })
    mod.content.field:patch("hiddenExtras", {
      pcTiles = { [BASE_MAP] = { { x = 0, y = 1, facing = "up" } } },
    })
  end

  -- the door mats' destination is dynamic: back to where the player stood
  -- when they entered (ctx.warp is nil on scripted warps, so ENTER's own
  -- warp into the room is never rewritten)
  mod.hooks:wrap("warp.destination", function(next, destMap, x, y, ctx)
    if destMap == BASE_MAP and ctx and ctx.warp then
      local b = mod.save:get("base")
      local out = mod.save:get("base_outside")
        or (b and { map = b.map, x = b.x, y = b.y + 1 })
      if out then return out.map, out.x, out.y end
    end
    return next(destMap, x, y, ctx)
  end)
  -- The room registers without a palette of its own; the map.palette
  -- hook that paints it lives AFTER the theGame declaration (an
  -- earlier registration captured a nil global -- declaration-order
  -- upvalue capture).

  -- one base per save, spawned like the tables (runtime object persists
  -- for the session; resync when a save is adopted)
  local baseNpcId = nil

  local function spawnBase(b)
    if not mod.world or baseNpcId or not b then return end
    local npcId = mod.world:spawnNpc(b.map, {
      x = b.x, y = b.y,
      sprite = "SPRITE_SECRET_BASE", movement = "STAY", range = "NONE",
      text = "TEXT_PALCRAFT_BASE",
    })
    if type(npcId) == "string" then baseNpcId = npcId end
  end

  local function resyncBase(save)
    if baseNpcId and mod.world then mod.world:removeNpc(baseNpcId) end
    baseNpcId = nil
    local bucket = save and save.modData and save.modData[mod.id]
    if bucket and bucket.base then spawnBase(bucket.base) end
  end
  mod.events:on("save.loaded", function(ev) resyncBase(ev.save) end)
  mod.events:on("save.created", function(ev) resyncBase(ev.save) end)

  mod.content.item_effects:register("SECRET_BASE_EFFECT", {
    field = true, battle = false,
    use = function(data, save, itemId, target, battle, moveIndex, ow)
      if not ow or not ow.player or ow.player.surfing or not ow.map
         or ow.map.id == BASE_MAP then
        return "failed", { "Can't build the\nbase here!" }
      end
      local x, y = facedCell(ow)
      local blocked = not (ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y))
      if not blocked then
        for _, npc in ipairs(ow.npcs or {}) do
          if npc.cellX == x and npc.cellY == y then
            blocked = true
            break
          end
        end
      end
      if blocked then
        return "failed", { "Can't build the\nbase here!" }
      end
      if mod.save:get("base") then
        return "failed", { "You already have\na SECRET BASE!" }
      end
      local b = { map = ow.map.id, x = x, y = y }
      mod.save:set("base", b)
      spawnBase(b)
      return "consumed", { (save.player and save.player.name or "You")
        .. " built a\nSECRET BASE!" }
    end,
  })

  -- entering records where you stood, so the room's exit row can put you
  -- right back
  mod.commands:register("palcraft_enter_base", function(ctx)
    local ow = ctx.overworld
    if not ow then return "end" end
    mod.save:set("base_outside",
      { map = ow.map.id, x = ow.player.cellX, y = ow.player.cellY })
  end)

  -- shared by the tent's PACK UP row and the overworld SELECT prompt;
  -- only works from the base's own map (a runtime npc on another map
  -- can't be reached to despawn)
  mod.exports.packBase = function(game, ow)
    local b = mod.save:get("base")
    if not b or not ow or not ow.map or ow.map.id ~= b.map then
      return false
    end
    local inv = game.save.inventory
    if not inv.SECRET_BASE then
      local slots = 0
      local cap = (game.data.constants and game.data.constants.bagSize) or 20
      for id in pairs(inv) do
        if not id:find("BADGE", 1, true) then slots = slots + 1 end
      end
      if slots >= cap then return false end
    end
    mod.save:set("base", nil)
    if mod.world then
      for _, npc in ipairs(ow.npcs or {}) do
        if npc.cellX == b.x and npc.cellY == b.y and npc.def
           and npc.def.sprite == "SPRITE_SECRET_BASE" then
          mod.world:removeNpc(npc.id)
          break
        end
      end
    end
    baseNpcId = nil
    inv.SECRET_BASE = (inv.SECRET_BASE or 0) + 1
    return true
  end

  mod.commands:register("palcraft_base_pack_up", function(ctx)
    ctx.lastCheck = false
    local ow = ctx.overworld
    if not ow then return end
    local x, y = facedCell(ow)
    local b = mod.save:get("base")
    if not (b and b.map == ow.map.id and b.x == x and b.y == y) then return end
    ctx.lastCheck = mod.exports.packBase(ctx.game, ow) and true or false
  end)

  local BASE_TALK = {
    { "face_player" },
    { "choice", { "ENTER", "PACK UP", "CANCEL" }, { cancel = 3 } },
    { "jump_if_true", "enter" },
    { "palcraft_if_packup", "packup" },
    { "jump", "end" },
    { "label", "enter" },
    { "palcraft_enter_base" },
    -- arrive standing on the door mat, like walking into a mart
    { "warp", BASE_MAP, 5, 11, "up" },
    { "jump", "end" },
    { "label", "packup" },
    { "palcraft_base_pack_up" },
    { "jump_if_false", "noroom" },
    { "show_text", "Packed up the\nSECRET BASE." },
    { "jump", "end" },
    { "label", "noroom" },
    { "show_text", "No room in the\nbag for it!" },
  }
  local baseTalkMaps = {}
  for mapId in mod.content.maps:each() do
    baseTalkMaps[#baseTalkMaps + 1] = mapId
  end
  for _, mapId in ipairs(baseTalkMaps) do
    mod.content.map_scripts:register(mapId, {
      talk = { TEXT_PALCRAFT_BASE = BASE_TALK },
    })
  end
  -- the room itself was registered after the crafting-table talk loop
  -- ran, and tables can be placed inside it
  mod.content.map_scripts:register(BASE_MAP, {
    talk = { TEXT_PALCRAFT_TABLE = TABLE_TALK },
  })


  -- ------------------------- base pals: assign POKeMON to the base

  -- While inside the base, the Start menu gains a PALS row: move any
  -- POKeMON from the party or any PC box into the base, or send one
  -- back.  Assigned pals live in mod.save and wander the room as NPCs.

  local function palsMax()
    return (mod.save:get("base_level") or 1) >= 2
      and BALANCE.palsExpanded or BALANCE.palsBase
  end
  local PAL_SPOTS = { { 2, 3 }, { 7, 3 }, { 2, 6 }, { 7, 6 },
                      { 4, 5 }, { 6, 8 }, { 3, 8 }, { 8, 4 } }
  local PALS_SCREEN = "PalworldBasePals"

  local palNpcIds = {}

  local function palLabel(game, mon)
    local def = game.data.pokemon[mon.species]
    return mon.nickname or (def and def.name) or tostring(mon.species)
  end

  local function currentPals()
    return mod.save:get("base_pals", {})
  end

  -- Asset-only integration with overworld_encounters: when its CLONE
  -- sits on disk but the mod itself is disabled, register its follower
  -- walkers ourselves so pals keep per-species art without any of that
  -- mod's gameplay (roaming spawns, throw physics, HUD).  When the mod
  -- IS enabled it registers these ids first (it loads before us as an
  -- optional dependency) and every one is skipped here.  We ship none
  -- of the files; the paths point into that mod's own directory.
  local ENC_SPRITES = "mods/overworld_encounters/assets/sprites/"
  local followersRegistered = 0
  for species in mod.content.pokemon:each() do
    local id = "SPRITE_WILD_" .. species
    if mod.content.sprites:get(id) == nil then
      local file = ENC_SPRITES .. "follower_" .. species .. ".png"
      local ok, info = pcall(love.filesystem.getInfo, file, "file")
      if ok and info then
        mod.content.sprites:register(id, {
          id = id, image = file, frames = 6, walker = true, trueColor = true,
        })
        followersRegistered = followersRegistered + 1
      end
    end
  end
  if followersRegistered > 0 then
    mod.log:info("registered %d follower walkers straight from the"
      .. " overworld_encounters assets", followersRegistered)
  end

  -- Wandering-pal art: per-species walkers whenever the sprites exist
  -- (either registered by overworld_encounters itself or by the
  -- asset-only pass above); the generic monster sprite otherwise.
  -- Resolved at spawn time, so the integration costs nothing when the
  -- assets are absent.
  local function palSpriteFor(species, hasSprite)
    local wild = "SPRITE_WILD_" .. tostring(species)
    hasSprite = hasSprite
      or function(id) return mod.content.sprites:get(id) ~= nil end
    if hasSprite(wild) then return wild end
    return "SPRITE_MONSTER"
  end
  mod.exports.palSpriteFor = palSpriteFor

  -- Shared sprite-cell cache for every mon grid (the WORK SKILLS
  -- browser, the base roster, the add picker): follower image +
  -- stand-down quad (sheet top 16x16) + that frame's opaque spans for
  -- the palette-shader cutout; false = no art for that species.
  local monCells = {}
  local function monCellFor(species)
    local c = monCells[species]
    if c ~= nil then return c or nil end
    c = false
    local sdef = mod.content.sprites:get("SPRITE_WILD_" .. species)
    if sdef and sdef.image then
      local ok, img = pcall(love.graphics.newImage, sdef.image)
      if ok then
        local m = cutoutMasks and cutoutMasks[sdef.image]
        if m == nil and cutoutMasks then
          m = maskFromImage(sdef.image, sdef.frames)
          cutoutMasks[sdef.image] = m
        end
        c = { img = img,
              quad = love.graphics.newQuad(0, 0, 16, 16,
                                           img:getDimensions()),
              spans = m and m[1] and m[1].norm }
      end
    end
    monCells[species] = c
    return c or nil
  end

  -- A generic POKéMON grid screen: 8 sprite cells per row, 4 rows,
  -- dpad cursor, info panel below live-updating with the highlighted
  -- entry's name and jobs -- the WORK SKILLS look, reused by every
  -- picker.  spec: title, kind, entries ({species, label, right?,
  -- value?, suits?}), onChoose(entry, grid) [A], onMeta(grid) [SELECT],
  -- hint (bottom-border tooltip), topLabel() (top-border text),
  -- emptyText.
  local MG_COLS, MG_CELL, MG_ROWS = 8, 16, 4
  local function newMonGrid(game, spec)
    local Font = mod.ui.Font
    local self = { game = game, isOpaque = true, index = 1, topRow = 0,
                   title = spec.title, kind = spec.kind,
                   entries = spec.entries }

    function self:close()
      if game.stack:top() == self then game.stack:pop() end
    end

    function self:update(dt)
      local input = game.input
      if input:wasPressed("b") then
        game.stack:pop()
        return
      end
      if spec.onMeta and input:wasPressed("select") then
        spec.onMeta(self)
        return
      end
      if input:wasPressed("a") then
        local e = self.entries[self.index]
        if e and spec.onChoose then spec.onChoose(e, self) end
        return
      end
      local n = #self.entries
      local d = 0
      if input:wasPressed("left") then d = -1
      elseif input:wasPressed("right") then d = 1
      elseif input:wasPressed("up") then d = -MG_COLS
      elseif input:wasPressed("down") then d = MG_COLS
      end
      if d ~= 0 then
        local i = self.index + d
        if i >= 1 and i <= n then
          self.index = i
        elseif d == MG_COLS and self.index < n then
          self.index = n       -- step into a partial last row
        end
        local row = math.floor((self.index - 1) / MG_COLS)
        if row < self.topRow then self.topRow = row end
        if row > self.topRow + MG_ROWS - 1 then
          self.topRow = row - MG_ROWS + 1
        end
      end
    end

    -- border text (the top filter label, the bottom button hint) sits
    -- on a blanked strip or the ornate frame shows through it
    local function borderText(text, x, y)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", x - 2, y, #text * 8 + 4, 8)
      Font.draw(text, x, y)
    end

    function self:draw()
      Font.drawBox(0, 0, 20, 10)
      local view = self.entries
      local x0, y0 = 16, 8
      for r = 0, MG_ROWS - 1 do
        for c = 0, MG_COLS - 1 do
          local mi = (self.topRow + r) * MG_COLS + c + 1
          local e = view[mi]
          if e then
            local x = x0 + c * MG_CELL
            local y = y0 + r * MG_CELL
            local cell = monCellFor(e.species)
            love.graphics.setColor(1, 1, 1, 1)
            if cell then
              love.graphics.draw(cell.img, cell.quad, x, y)
              if cell.spans then
                for _, s in ipairs(cell.spans) do
                  PaletteFX.markTrueColor(x + s[1], y + s[2], s[3], s[4])
                end
              end
              if e.disabled then
                -- wash the cell out; the overlay lands inside the
                -- trueColor spans, so it dims the real colors
                love.graphics.setColor(1, 1, 1, 0.6)
                love.graphics.rectangle("fill", x, y, MG_CELL, MG_CELL)
                love.graphics.setColor(1, 1, 1, 1)
              end
            else
              Font.draw("?", x + 4, y + 4)
            end
            if mi == self.index then
              love.graphics.setColor(0, 0, 0, 1)
              love.graphics.rectangle("line", x + 0.5, y + 0.5,
                                      MG_CELL - 1, MG_CELL - 1)
              love.graphics.setColor(1, 1, 1, 1)
            end
          end
        end
      end
      if (self.topRow + MG_ROWS) * MG_COLS < #view then
        Font.drawCode(mod.ui.Theme.moreArrow, 146, 62)
      end
      if spec.topLabel then
        local tl = spec.topLabel(self)
        if tl then borderText(tl, 8, 0) end
      end

      -- name + up to three jobs at an even 12px; the tallest card (a
      -- three-job single like FARFETCH'D) ends at 132, inside the border
      Font.drawBox(0, 10, 20, 8)
      local e = view[self.index]
      if e then
        Font.draw(e.label, 8, 88)
        if e.disabled and e.note then
          -- the reason it's greyed, then the useful part of the card:
          -- a no-partner parent still teaches "breed with X to get Y"
          Font.draw(e.note, 16, 100)
          for i, line in ipairs(e.infoLines or {}) do
            if i >= 2 and i <= 3 then Font.draw(line, 16, 88 + i * 12) end
          end
        elseif e.infoLines then
          for i, line in ipairs(e.infoLines) do
            if i <= 3 then Font.draw(line, 16, 88 + i * 12) end
          end
        else
          for i, s in ipairs(e.suits or {}) do
            if i <= 3 then
              Font.draw(s.job, 16, 88 + i * 12)
              Font.draw(("Lv.%d"):format(s.level), 112, 88 + i * 12)
            end
          end
        end
      elseif spec.emptyText then
        Font.draw(spec.emptyText, 8, 88)
      end
      if spec.hint then
        borderText(spec.hint, 152 - #spec.hint * 8, 136)
      end
    end

    return self
  end

  local function clearPalNpcs()
    for i, id in pairs(palNpcIds) do
      if mod.world then mod.world:removeNpc(id) end
      palNpcIds[i] = nil
    end
  end

  local function refreshPalNpcs(pals)
    clearPalNpcs()
    if not mod.world then return end
    for i, mon in ipairs(pals or {}) do
      local spot = PAL_SPOTS[((i - 1) % #PAL_SPOTS) + 1]
      local id = mod.world:spawnNpc(BASE_MAP, {
        x = spot[1], y = spot[2],
        sprite = palSpriteFor(mon.species),
        movement = "WALK", range = "ANY_DIR",
        text = "TEXT_PALCRAFT_PAL",
      })
      if type(id) == "string" then palNpcIds[i] = id end
    end
  end

  local function resyncPalsFrom(save)
    local bucket = save and save.modData and save.modData[mod.id]
    refreshPalNpcs(bucket and bucket.base_pals or {})
  end
  mod.events:on("save.loaded", function(ev) resyncPalsFrom(ev.save) end)
  mod.events:on("save.created", function(ev) resyncPalsFrom(ev.save) end)

  -- talking to a pal: a token carries its display name into the text
  local lastPalName = "The POKéMON"
  mod.content.tokens:register("POKENAME", function() return lastPalName end)
  mod.commands:register("palcraft_pal_greet", function(ctx)
    lastPalName = "The POKéMON"
    local npc = ctx.npc
    if not npc then return end
    for i, id in pairs(palNpcIds) do
      if npc.id == id then
        local mon = currentPals()[i]
        if mon then lastPalName = palLabel(ctx.game, mon) end
        break
      end
    end
  end)
  mod.content.map_scripts:register(BASE_MAP, {
    talk = {
      TEXT_PALCRAFT_PAL = {
        { "face_player" },
        { "palcraft_pal_greet" },
        { "show_text", "{POKENAME} is\nsettling in!" },
      },
    },
  })

  -- ------- the moves themselves (exported for tests)

  local Stats = require("src.pokemon.Stats")  -- supported require

  -- mirror src/pokemon/Boxes.ensure exactly, legacy `save.box` migration
  -- included, so our PC view never disagrees with Bill's PC
  local function boxesOf(game)
    local save = game.save
    if not save.boxes then
      local n = (game.data.constants and game.data.constants.boxCount) or 12
      save.boxes = {}
      for i = 1, n do save.boxes[i] = {} end
      save.currentBox = save.currentBox or 1
      if save.box then
        for _, mon in ipairs(save.box) do
          table.insert(save.boxes[1], mon)
        end
        save.box = nil
      end
    end
    return save.boxes
  end

  -- expect: the exact mon table the menu row was built from.  Party and
  -- box slots shift under a stale list, and removing by a stale index
  -- moves the WRONG mon (which reads as a duplication); identity has to
  -- match before anything is touched.
  local function assignToBase(game, source, boxIdx, slot, expect)
    local pals = currentPals()
    if #pals >= palsMax() then
      return false, "The base is full!"
    end
    local container
    if source == "party" then
      if #(game.save.party or {}) <= 1 then
        return false, "Keep at least one\nPOKéMON with you!"
      end
      container = game.save.party
    else
      container = game.save.boxes and game.save.boxes[boxIdx]
    end
    local mon = container and container[slot]
    if not mon or (expect ~= nil and mon ~= expect) then
      return false, "It's not there\nanymore!"
    end
    for _, p in ipairs(pals) do
      if p == mon then
        return false, "It's already in\nthe base!"
      end
    end
    table.remove(container, slot)
    pals[#pals + 1] = mon
    mod.save:set("base_pals", pals)
    refreshPalNpcs(pals)
    return true, palLabel(game, mon) .. " now\nlives in the base!"
  end

  local function removeFromBase(game, palIdx, dest)
    local pals = currentPals()
    local mon = pals[palIdx]
    if not mon then return false, "It slipped away!" end
    if dest == "party" then
      local cap = (game.data.constants and game.data.constants.partyMax) or 6
      if #(game.save.party or {}) >= cap then
        return false, "The party is full!"
      end
      -- box-style storage may predate current stat math; same ensure the
      -- PC withdraw path runs
      Stats.ensure(game.data.pokemon[mon.species], mon)
      table.remove(pals, palIdx)
      game.save.party = game.save.party or {}
      table.insert(game.save.party, mon)
    else
      local boxes = boxesOf(game)
      local boxCount = (game.data.constants and game.data.constants.boxCount) or 12
      local boxSize = (game.data.constants and game.data.constants.boxSize) or 20
      local target
      local start = game.save.currentBox or 1
      for off = 0, boxCount - 1 do
        local i = ((start - 1 + off) % boxCount) + 1
        if boxes[i] and #boxes[i] < boxSize then
          target = i
          break
        end
      end
      if not target then return false, "The PC is full!" end
      table.remove(pals, palIdx)
      table.insert(boxes[target], mon)
    end
    mod.save:set("base_pals", pals)
    refreshPalNpcs(pals)
    return true, palLabel(game, mon) .. " left\nthe base."
  end

  mod.exports.assignToBase = assignToBase
  mod.exports.removeFromBase = removeFromBase

  -- ------- the screens

  local function showText(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function reopenPals(game, msg)
    mod.ui.push(game, PALS_SCREEN)
    if msg then showText(game, msg) end
  end

  local function pushAddList(game, parent)
    local ws = mod.exports.workSuitabilities
    local entries = {}
    local function addEntry(mon, src, value)
      entries[#entries + 1] = {
        species = mon.species,
        label = ("%s L%d [%d]"):format(palLabel(game, mon),
          mon.level or 0, mod.exports.starsOf(mon)),
        right = src, value = value,
        suits = ws and ws(mon.species) or nil,
      }
    end
    for i, mon in ipairs(game.save.party or {}) do
      addEntry(mon, "PARTY", { "party", nil, i, mon })
    end
    -- boxesOf (not raw save.boxes): runs the same legacy migration Bill's
    -- PC does, so this list never shows a different world than the PC
    for b, box in ipairs(boxesOf(game)) do
      for s, mon in ipairs(box) do
        addEntry(mon, ("BOX%d"):format(b), { "pc", b, s, mon })
      end
    end
    local list
    list = newMonGrid(game, {
      title = "MOVE TO BASE", kind = "basepals_add", entries = entries,
      emptyText = "NOTHING TO MOVE!",
      -- where the highlighted mon lives now, on the top border
      topLabel = function(grid)
        local e = grid.entries[grid.index]
        return e and e.right
      end,
      onChoose = function(e)
        local ok, msg = assignToBase(game, e.value[1], e.value[2],
                                     e.value[3], e.value[4])
        list:close()
        if parent then parent:close() end
        reopenPals(game, msg)
      end,
    })
    game.stack:push(list)
  end

  local function pushPalActions(game, palIdx, parent)
    local function moveTo(dest)
      local ok, msg = removeFromBase(game, palIdx, dest)
      if parent then parent:close() end
      reopenPals(game, msg)
    end
    game.stack:push(mod.ui.Menu.new(game, {
      { label = "TO PARTY", onSelect = function() moveTo("party") end },
      { label = "TO PC",    onSelect = function() moveTo("pc") end },
      -- defined further down the chunk; resolved through exports at
      -- press time so the declaration order doesn't matter
      { label = "SKILLS",   onSelect = function()
          local mon = currentPals()[palIdx]
          if mon then
            mod.exports.pushWorkSkills(game, mon.species,
                                       palLabel(game, mon))
          end
        end },
      { label = "CANCEL",   onSelect = function() end },
    }, { tx = 8, ty = 8 }))
  end

  mod.content.screens:register(PALS_SCREEN, {
    new = function(game)
      local ws = mod.exports.workSuitabilities
      local entries = {}
      for i, mon in ipairs(currentPals()) do
        entries[#entries + 1] = {
          species = mon.species,
          label = ("%s L%d [%d]"):format(palLabel(game, mon),
            mon.level or 0, mod.exports.starsOf(mon)),
          value = i,
          suits = ws and ws(mon.species) or nil,
        }
      end
      local grid
      grid = newMonGrid(game, {
        title = "BASE POKéMON", kind = "basepals", entries = entries,
        hint = "SELECT:ADD",
        emptyText = "NO POKéMON YET!",
        onChoose = function(e) pushPalActions(game, e.value, grid) end,
        onMeta = function() pushAddList(game, grid) end,
      })
      return grid
    end,
  })

  -- the PALS row exists only while standing in the base
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    local ow = game.overworld
    if not (ow and ow.map and ow.map.id == BASE_MAP) then return out end
    out = mod.ui.insertBefore(out, "OPTION", {
      label = "BASE POKéMON",
      onSelect = function() mod.ui.push(game, PALS_SCREEN) end,
    })
    return mod.ui.insertBefore(out, "OPTION", {
      label = "WORK SKILLS",
      onSelect = function() mod.exports.pushWorkBrowser(game) end,
    })
  end)

  -- ------------------------------------- the egg incubator

  -- A base-only station: assign two base POKéMON as parents, feed it a
  -- LEMONADE, and a real-play-time timer starts (save.playTime, so it
  -- survives saving and never touches wall clocks).  When it finishes
  -- the dome shows an egg; HATCH delivers a level-1 hatchling -- for
  -- now a random parent's species -- to the party, or the PC when the
  -- party is full.

  local BREED_SECONDS = BALANCE.breedSeconds

  -- Breeding pairings: any member of line `a` bred with any member of
  -- line `b` can hatch `child` at `chance`%.  Curate these with
  -- tools/breed_lines_designer.html and paste its export over this whole
  -- block (BREED_ONLY feeds the wild-encounter-removal phase, next up).
  local BREED_LINES = {
    { a = "PIDGEY", b = "SPEAROW", child = "FARFETCHD", chance = 100 },
    { a = "SLOWPOKE", b = "DROWZEE", child = "LICKITUNG", chance = 100 },
    { a = "SEEL", b = "HORSEA", child = "LAPRAS", chance = 100 },
    { a = "PONYTA", b = "DODUO", child = "TAUROS", chance = 100 },
    { a = "PARAS", b = "VENONAT", child = "PINSIR", chance = 100 },
    { a = "MANKEY", b = "PARAS", child = "SCYTHER", chance = 100 },
    { a = "CLEFAIRY", b = "JIGGLYPUFF", child = "CHANSEY", chance = 100 },
    { a = "SQUIRTLE", b = "MAGIKARP", child = "HORSEA", chance = 100 },
    { a = "CHARMANDER", b = "VULPIX", child = "MAGMAR", chance = 100 },
    { a = "CATERPIE", b = "WEEDLE", child = "VENONAT", chance = 100 },
    { a = "WEEDLE", b = "BULBASAUR", child = "EKANS", chance = 100 },
    { a = "SANDSHREW", b = "NIDORAN_F", child = "DIGLETT", chance = 100 },
    { a = "FARFETCHD", b = "RHYHORN", child = "AERODACTYL", chance = 100 },
    { a = "SQUIRTLE", b = "LAPRAS", child = "DRATINI", chance = 100 },
    { a = "MEW", b = "ZAPDOS", child = "MEWTWO", chance = 100 },
    { a = "PSYDUCK", b = "MACHOP", child = "ABRA", chance = 100 },
    { a = "JIGGLYPUFF", b = "DROWZEE", child = "SNORLAX", chance = 100 },
    { a = "AERODACTYL", b = "ELECTABUZZ", child = "ZAPDOS", chance = 100 },
    { a = "MAGMAR", b = "VULPIX", child = "PONYTA", chance = 100 },
    { a = "DITTO", b = "PORYGON", child = "MEW", chance = 100 },
    -- SANDSHREW left the chain (2026-08-09): it now heals into Red's
    -- wild through the EKANS/SANDSHREW exclusive pair, because the
    -- LUMBERING trade needs an early recruit
    { a = "ZUBAT", b = "DITTO", child = "GRIMER", chance = 100 },
    { a = "CLEFAIRY", b = "EEVEE", child = "DITTO", chance = 100 },
    { a = "STARYU", b = "GROWLITHE", child = "EEVEE", chance = 100 },
    { a = "GOLDEEN", b = "MAGIKARP", child = "OMASTAR", chance = 100 },
    { a = "LAPRAS", b = "OMANYTE", child = "STARYU", chance = 100 },
    { a = "GEODUDE", b = "EKANS", child = "ONIX", chance = 100 },
    { a = "KANGASKHAN", b = "GASTLY", child = "CUBONE", chance = 100 },
    { a = "HITMONCHAN", b = "HITMONLEE", child = "KANGASKHAN", chance = 100 },
    { a = "CUBONE", b = "KRABBY", child = "SHELLDER", chance = 100 },
    { a = "BULBASAUR", b = "GROWLITHE", child = "CHARMANDER", chance = 100 },
    { a = "CHARMANDER", b = "POLIWAG", child = "SQUIRTLE", chance = 100 },
    { a = "SQUIRTLE", b = "ODDISH", child = "BULBASAUR", chance = 100 },
  }
  -- the classic starters left this roster (2026-08-10): BULBASAUR
  -- dens on Route 24, CHARMANDER on Route 7, SQUIRTLE bites a GOOD ROD
  local BREED_ONLY = {
    "EKANS",
    "VENONAT", "DIGLETT", "ABRA", "PONYTA", "FARFETCHD", "GRIMER",
    "SHELLDER", "ONIX", "CUBONE", "LICKITUNG", "CHANSEY", "KANGASKHAN",
    "HORSEA", "STARYU", "SCYTHER", "MAGMAR", "PINSIR", "TAUROS",
    "LAPRAS", "DITTO", "EEVEE", "OMASTAR", "AERODACTYL", "SNORLAX",
    "ZAPDOS", "DRATINI", "MEWTWO", "MEW",
  }

  -- pre-evolution map over the merged dex: lineRootOf collapses any
  -- family member to its base form, so PIDGEOT x FEAROW matches the
  -- PIDGEY x SPEAROW pairing
  local preEvo = {}
  for id, def in mod.content.pokemon:each() do
    for _, evo in ipairs(def.evolutions or {}) do
      if evo.species then preEvo[evo.species] = id end
    end
  end
  local function lineRootOf(species)
    local cur, hops = species, 0
    while preEvo[cur] and hops < 10 do
      cur = preEvo[cur]
      hops = hops + 1
    end
    return cur
  end
  mod.exports.lineRootOf = lineRootOf

  -- ------------------------------------- work suitabilities

  -- Every type is a trade, Palworld style.  A POKéMON works every job
  -- its types grant, at a level set by its evolution stage (1-3) --
  -- evolving IS the promotion -- with a curated override list for the
  -- legendaries and the single-stage specialists that would otherwise
  -- be stuck at entry level forever.
  local JOB_BY_TYPE = {
    NORMAL = "HANDIWORK", FIGHTING = "TRAINING", FLYING = "TRANSPORT",
    POISON = "MEDICINE", GROUND = "LUMBERING", ROCK = "MINING",
    BUG = "PLANTING", GHOST = "NIGHT SHIFT", FIRE = "KINDLING",
    WATER = "WATERING", GRASS = "GATHERING", ELECTRIC = "GENERATING",
    -- the ROM's type constant is PSYCHIC_TYPE (the bare word collides
    -- with the move PSYCHIC in pokered's constant namespace)
    ICE = "COOLING", PSYCHIC_TYPE = "RESEARCH", DRAGON = "OVERSEER",
  }
  -- display order: the farm's day-to-day jobs first, specialists last
  local JOB_ORDER = {
    "HANDIWORK", "GATHERING", "PLANTING", "WATERING", "KINDLING",
    "GENERATING", "COOLING", "LUMBERING", "MINING", "TRANSPORT",
    "MEDICINE", "TRAINING", "RESEARCH", "NIGHT SHIFT", "OVERSEER",
  }
  local WORK_LEVEL_MAX = BALANCE.workLevelMax

  -- flavor beats formula for these: legendaries master their craft,
  -- single-stage adults are seasoned pros, and a few earn a job their
  -- types alone would never grant (SCYTHER fells trees, CHANSEY is a
  -- nurse's aide, PORYGON is literally software)
  local WORK_OVERRIDES = {
    ARTICUNO = { COOLING = 3, TRANSPORT = 3 },
    ZAPDOS = { GENERATING = 3, TRANSPORT = 3 },
    MOLTRES = { KINDLING = 3, TRANSPORT = 3 },
    MEWTWO = { RESEARCH = 4 },
    MEW = { RESEARCH = 3, OVERSEER = 1 },
    ONIX = { MINING = 2, LUMBERING = 2 },
    LAPRAS = { WATERING = 2, COOLING = 2 },
    SNORLAX = { HANDIWORK = 2 },
    KANGASKHAN = { HANDIWORK = 2 },
    TAUROS = { HANDIWORK = 2 },
    PINSIR = { PLANTING = 2 },
    SCYTHER = { LUMBERING = 2 },
    FARFETCHD = { GATHERING = 2 },
    CHANSEY = { MEDICINE = 2 },
    HITMONLEE = { TRAINING = 2 },
    HITMONCHAN = { TRAINING = 2 },
    MR_MIME = { RESEARCH = 2 },
    JYNX = { COOLING = 2 },
    ELECTABUZZ = { GENERATING = 2 },
    MAGMAR = { KINDLING = 2 },
    AERODACTYL = { MINING = 2, TRANSPORT = 2 },
    DITTO = { OVERSEER = 1 },
    PORYGON = { RESEARCH = 2 },
  }

  local function stageOf(species)
    local cur, hops = species, 0
    while preEvo[cur] and hops < 10 do
      cur = preEvo[cur]
      hops = hops + 1
    end
    return hops + 1
  end

  local function workSuitabilities(species)
    local def = mod.content.pokemon:get(species)
    -- overrides apply even off-dex (the test fixture's tiny dex);
    -- a species with neither dex entry nor override has no work data
    if not def and not WORK_OVERRIDES[species] then return {} end
    local level = def and math.min(3, stageOf(species)) or 0
    local byJob = {}
    for _, t in ipairs(def and def.types or {}) do
      local job = JOB_BY_TYPE[t]
      if job then byJob[job] = level end
    end
    for job, lv in pairs(WORK_OVERRIDES[species] or {}) do
      byJob[job] = math.min(WORK_LEVEL_MAX, lv)
    end
    local out = {}
    for _, job in ipairs(JOB_ORDER) do
      if byJob[job] then
        out[#out + 1] = { job = job, level = byJob[job] }
      end
    end
    return out
  end
  mod.exports.workSuitabilities = workSuitabilities
  mod.exports.workOverrides = WORK_OVERRIDES
  mod.exports.jobByType = JOB_BY_TYPE
  mod.exports.stageOf = stageOf

  -- one POKéMON's card: its jobs and levels
  local function pushWorkSkills(game, species, name)
    local rows = {}
    for _, s in ipairs(workSuitabilities(species)) do
      rows[#rows + 1] = { label = s.job,
                          right = ("Lv.%d"):format(s.level), value = s }
    end
    if #rows == 0 then
      rows[1] = { label = "NO WORK DATA", value = 0 }
    end
    local def = mod.content.pokemon:get(species)
    local title = name or (def and def.name) or tostring(species)
    game.stack:push(mod.ui.ListMenu.new(game, title, rows,
      { kind = "workskills" }))
  end

  -- The whole dex as a sprite grid, riding the shared newMonGrid
  -- component: dpad roams, the panel live-updates, SELECT filters to
  -- one job.  Sprites resolve through the same SPRITE_WILD_ registry
  -- the base pals use (overworld_encounters art when present, "?"
  -- otherwise).
  local GRID_SCREEN = "PalworldWorkGrid"

  mod.content.screens:register(GRID_SCREEN, {
    new = function(game)
      local mons = {}
      for id, def in mod.content.pokemon:each() do
        if def.dex and def.types and #def.types > 0 then
          mons[#mons + 1] = { id = id, species = id, def = def,
                              label = nil,  -- filled after the sort
                              suits = workSuitabilities(id) }
        end
      end
      table.sort(mons, function(a, b)
        return (a.def.dex or 999) < (b.def.dex or 999)
      end)
      for _, m in ipairs(mons) do
        m.label = ("%03d %s"):format(m.def.dex or 0,
                                     m.def.name or m.id)
      end

      local self
      local function pushFilterPicker()
        local items = { { label = "ALL", value = false } }
        for _, job in ipairs(JOB_ORDER) do
          items[#items + 1] = { label = job, value = job }
        end
        local list
        list = mod.ui.ListMenu.new(game, "FILTER", items, {
          kind = "workgrid_filter",
          onChoose = function(item)
            self.setFilter(item.value or nil)
            list:close()
          end,
        })
        game.stack:push(list)
      end

      self = newMonGrid(game, {
        title = "WORK SKILLS", kind = "workgrid", entries = mons,
        hint = "SELECT:FILTER",
        onMeta = pushFilterPicker,   -- A stays inert on this grid
        topLabel = function(grid)
          return grid.filter
            and ("%s:%d"):format(grid.filter, #grid.entries)
        end,
      })
      self.mons, self.view, self.filter = mons, mons, nil

      -- SELECT filters the grid to one job (nil = everyone); the
      -- picker above feeds this, and tests drive it directly
      function self.setFilter(job)
        self.filter = job
        if not job then
          self.view = mons
        else
          local view = {}
          for _, m in ipairs(mons) do
            for _, s in ipairs(m.suits) do
              if s.job == job then
                view[#view + 1] = m
                break
              end
            end
          end
          self.view = view
        end
        self.entries = self.view
        self.index, self.topRow = 1, 0
      end

      return self
    end,
  })

  local function pushWorkBrowser(game)
    mod.ui.push(game, GRID_SCREEN)
  end
  mod.exports.pushWorkSkills = pushWorkSkills
  mod.exports.pushWorkBrowser = pushWorkBrowser

  -- does this pair complete a special pairing?  (used for the hatch
  -- roll AND for the spoiler-free "?!" hints in the parent picker)
  local function pairingFor(s1, s2, recipes)
    recipes = recipes or BREED_LINES
    local r1, r2 = lineRootOf(s1), lineRootOf(s2)
    for _, rec in ipairs(recipes) do
      if (rec.a == r1 and rec.b == r2) or (rec.a == r2 and rec.b == r1) then
        return rec
      end
    end
    return nil
  end
  mod.exports.pairingFor = pairingFor

  -- The compatibility rule: a pair breeds only within one evolution
  -- line (CHARMANDER x CHARIZARD) or across one of the special
  -- pairings above.  The parent pickers grey out everything else, so
  -- there is no "nothing happened" outcome to explain.
  local function canBreed(s1, s2)
    if lineRootOf(s1) == lineRootOf(s2) then return true end
    return pairingFor(s1, s2) ~= nil
  end
  mod.exports.canBreed = canBreed

  -- the hatch roll: a matching pairing hatches its child (per its
  -- chance); otherwise -- a same-line pair, or a special pair that
  -- missed its chance roll -- the line's base form
  local function breedChild(parents, rand, recipes)
    rand = rand or function(n) return math.random(n) end
    local rec = pairingFor(parents[1], parents[2], recipes)
    if rec and rand(100) <= (rec.chance or 100) then
      return rec.child
    end
    return lineRootOf(parents[rand(2)])
  end
  mod.exports.breedChild = breedChild
  mod.exports.breedOnly = BREED_ONLY

  -- BREED_ONLY species leave the wild: every encounter slot they held is
  -- re-filled with the table's lead non-breed-only species, keeping the
  -- slot's own level, so no grass or water thins out.  (Gen 1 tables are
  -- exactly ten weighted slots -- they must stay full.)
  local breedOnlySet = {}
  for _, s in ipairs(BREED_ONLY) do breedOnlySet[s] = true end

  local function cleanEncounterSlots(slots, banned, fallback)
    banned = banned or breedOnlySet
    local lead
    for _, slot in ipairs(slots) do
      if slot.species and not banned[slot.species] then
        lead = slot.species
        break
      end
    end
    local out, changed = {}, 0
    for i, slot in ipairs(slots) do
      if slot.species and banned[slot.species] then
        out[i] = { species = lead or fallback or "RATTATA",
                   level = slot.level }
        changed = changed + 1
      else
        out[i] = slot
      end
    end
    return out, changed
  end
  mod.exports.cleanEncounterSlots = cleanEncounterSlots

  local encPatches, slotsCleaned = {}, 0
  for mapId, enc in mod.content.encounters:each() do
    local patch
    for _, terrain in ipairs({ "grass", "water" }) do
      local t = enc[terrain]
      if t and t.slots then
        local slots, changed = cleanEncounterSlots(t.slots)
        if changed > 0 then
          patch = patch or {}
          patch[terrain] = { slots = slots }
          slotsCleaned = slotsCleaned + changed
        end
      end
    end
    if patch then
      encPatches[#encPatches + 1] = { mapId, patch }
    end
  end
  for _, p in ipairs(encPatches) do
    mod.content.encounters:patch(p[1], p[2])
  end

  -- Super Rod pools (field.superRod, map -> candidate list) carry most
  -- of the water rares; same treatment, with MAGIKARP as the fallback.
  -- field is a deep registry, so each changed list is tombstoned and
  -- re-laid like the mart shelves.
  local rodPatches = {}
  for mapId, list in pairs(mod.content.field:get("superRod") or {}) do
    local cleanedList, changed = cleanEncounterSlots(list, nil, "MAGIKARP")
    if changed > 0 then
      rodPatches[#rodPatches + 1] = { mapId, cleanedList }
      slotsCleaned = slotsCleaned + changed
    end
  end
  for _, p in ipairs(rodPatches) do
    mod.content.field:patch("superRod", { [p[1]] = mod.DELETE })
    mod.content.field:patch("superRod", { [p[1]] = p[2] })
  end

  if slotsCleaned > 0 then
    mod.log:info("re-filled %d wild slots that held breed-only species",
                 slotsCleaned)
  end

  -- ------- no version exclusives

  -- Red and Blue each hide half of seven classic pairs.  Wherever one
  -- side of a pair roams in this version's wild and the other is absent
  -- (and not deliberately breed-only), the missing line moves into
  -- alternating slots of its counterpart's tables -- same levels,
  -- matching evolution stage.  Data-driven, so a Blue import heals too.
  local PAIR_LINES = {
    { { "WEEDLE", "KAKUNA", "BEEDRILL" },
      { "CATERPIE", "METAPOD", "BUTTERFREE" } },
    { { "EKANS", "ARBOK" }, { "SANDSHREW", "SANDSLASH" } },
    { { "ODDISH", "GLOOM", "VILEPLUME" },
      { "BELLSPROUT", "WEEPINBELL", "VICTREEBEL" } },
    { { "MANKEY", "PRIMEAPE" }, { "MEOWTH", "PERSIAN" } },
    { { "GROWLITHE", "ARCANINE" }, { "VULPIX", "NINETALES" } },
    { { "SCYTHER" }, { "PINSIR" } },
    { { "ELECTABUZZ" }, { "MAGMAR" } },
  }

  -- Gen 1 slots carry FIXED probability buckets (slot 1 ~20%, slot 10
  -- ~1%), so splitting by slot count would skew the odds.  Instead each
  -- mapped species' slots are partitioned by WEIGHT: the counterpart
  -- inherits as close to half that species' encounter probability as
  -- the buckets allow (a 60% native becomes ~30/30).  Single-slot
  -- species stay native.
  local ENC_BUCKETS = mod.content.constants:get("encounterBuckets")
    or { 51, 51, 39, 25, 25, 25, 13, 10, 10, 3 }

  local function mirrorSlots(slots, swapMap, buckets)
    buckets = buckets or ENC_BUCKETS
    local groups = {}
    for i, slot in ipairs(slots) do
      if slot.species and swapMap[slot.species] then
        groups[slot.species] = groups[slot.species] or {}
        table.insert(groups[slot.species], i)
      end
    end
    local swapIdx = {}
    for _, idxs in pairs(groups) do
      -- greedy halving: heaviest slot first, into whichever side is
      -- lighter; ties break on slot order for determinism
      table.sort(idxs, function(a, b)
        local wa, wb = buckets[a] or 0, buckets[b] or 0
        if wa ~= wb then return wa > wb end
        return a < b
      end)
      local wNative, wSwap = 0, 0
      for _, i in ipairs(idxs) do
        local w = buckets[i] or 0
        if wSwap + w <= wNative then
          wSwap = wSwap + w
          swapIdx[i] = true
        else
          wNative = wNative + w
        end
      end
    end
    local out, changed = {}, 0
    for i, slot in ipairs(slots) do
      if swapIdx[i] then
        out[i] = { species = swapMap[slot.species], level = slot.level }
        changed = changed + 1
      else
        out[i] = slot
      end
    end
    return out, changed
  end
  mod.exports.mirrorSlots = mirrorSlots

  local wild = {}
  for _, enc in mod.content.encounters:each() do
    for _, terrain in ipairs({ "grass", "water" }) do
      local t = enc[terrain]
      for _, slot in ipairs(t and t.slots or {}) do
        if slot.species then wild[slot.species] = true end
      end
    end
  end
  for _, list in pairs(mod.content.field:get("superRod") or {}) do
    for _, c in ipairs(list) do
      if c.species then wild[c.species] = true end
    end
  end

  local function lineWild(line)
    for _, s in ipairs(line) do
      if wild[s] then return true end
    end
    return false
  end

  local mirrorMap, healed = {}, {}
  for _, pair in ipairs(PAIR_LINES) do
    local function tryInject(from, to)
      if lineWild(from) and not lineWild(to)
         and not breedOnlySet[to[1]] then
        for i, s in ipairs(from) do
          if to[i] then mirrorMap[s] = to[i] end
        end
        healed[#healed + 1] = to[1]
      end
    end
    tryInject(pair[1], pair[2])
    tryInject(pair[2], pair[1])
  end
  if next(mirrorMap) ~= nil then
    local pairPatches = {}
    for mapId, enc in mod.content.encounters:each() do
      local patch
      for _, terrain in ipairs({ "grass", "water" }) do
        local t = enc[terrain]
        if t and t.slots then
          local slots, changed = mirrorSlots(t.slots, mirrorMap)
          if changed > 0 then
            patch = patch or {}
            patch[terrain] = { slots = slots }
          end
        end
      end
      if patch then
        pairPatches[#pairPatches + 1] = { mapId, patch }
      end
    end
    for _, p in ipairs(pairPatches) do
      mod.content.encounters:patch(p[1], p[2])
    end
    mod.log:info("version exclusives healed into the wild: %s",
                 table.concat(healed, ", "))
  end

  -- The LUMBERING trade needs its recruit whatever the curation does
  -- to the snakes (EKANS is breed-only, so its wild slots are long
  -- gone and the pair heal only reaches ARBOK's late dens): guarantee
  -- SANDSHREW an early den outright on Route 4, in slot 4 -- the
  -- 25/256 bucket, a solid-but-not-common find.
  do
    local enc = mod.content.encounters:get("ROUTE_4")
    local slots = enc and enc.grass and enc.grass.slots
    if slots and #slots >= 4 then
      local hasShrew = false
      for _, s in ipairs(slots) do
        if s.species == "SANDSHREW" then hasShrew = true end
      end
      if not hasShrew then
        local out = {}
        for i, s in ipairs(slots) do out[i] = s end
        out[4] = { species = "SANDSHREW", level = slots[4].level or 8 }
        mod.content.encounters:patch("ROUTE_4",
          { grass = { slots = out } })
        mod.log:info("SANDSHREW guaranteed a Route 4 den")
      end
    end
  end

  -- ------- humble starters, and the classics gone wild

  -- Oak's balls still READ as the classic trio to the rival (the
  -- chose-flags and his counterpick rows are untouched), but the ball
  -- the player opens holds a street urchin -- no early powerhouse.
  -- The row rewrite is verb-scanned, not index-based, so upstream
  -- edits to the lab script survive it.
  mod.exports.swapStarterRows = function(rows, fromSp, toSp, askText)
    local out = {}
    for i, row in ipairs(rows) do
      local r = row
      if type(row) == "table" then
        if row[1] == "give_pokemon" and row[2] == fromSp then
          r = { "give_pokemon", toSp, row[3] }
        elseif row[1] == "push_screen" and row[2] == "DexEntryMenu"
            and type(row[3]) == "table" and row[3].species == fromSp then
          r = { "push_screen", "DexEntryMenu",
                { species = toSp, forceOwned = true } }
        elseif row[1] == "ask" then
          r = { "ask", askText }
        elseif row[1] == "show_text" and type(row[3]) == "table"
            and row[3].RAM == fromSp then
          r = { "show_text", row[2], { RAM = toSp } }
        end
      end
      out[i] = r
    end
    return out
  end

  do
    local STARTER_SWAP = {
      { key = "TEXT_OAKSLAB_BULBASAUR_POKE_BALL",
        from = "BULBASAUR", to = "ZUBAT" },
      { key = "TEXT_OAKSLAB_CHARMANDER_POKE_BALL",
        from = "CHARMANDER", to = "MEOWTH" },
      { key = "TEXT_OAKSLAB_SQUIRTLE_POKE_BALL",
        from = "SQUIRTLE", to = "DIGLETT" },
    }
    -- the engine attaches the base lab script lazily at world setup,
    -- AFTER mod entry -- pull it in now (idempotent via package.loaded)
    -- so baseTalk has rows to copy; pcall keeps thin harnesses alive
    pcall(require, "data.scripts.init")
    local okMS, MapScripts = pcall(require, "src.script.MapScripts")
    if okMS and MapScripts.baseTalk then
      local talk = {}
      for _, s in ipairs(STARTER_SWAP) do
        local rows = MapScripts.baseTalk("OAKS_LAB", s.key)
        if rows then
          local def = mod.content.pokemon:get(s.to)
          local kind = def and def.dexEntry and def.dexEntry.kind
          local name = (def and def.name) or s.to
          local askText = kind
            and ("So! You want the\n%s POKéMON,\v%s?")
              :format(kind:lower(), name)
            or ("So! You want\n%s?"):format(name)
          talk[s.key] = mod.exports.swapStarterRows(
            rows, s.from, s.to, askText)
        end
      end
      if next(talk) then
        mod.content.map_scripts:register("OAKS_LAB", { talk = talk })
        mod.log:info("the lab balls now hold ZUBAT, MEOWTH and DIGLETT")
      end
    end
  end

  -- the classics den in the wild instead: slot 7 is the 13/256 bucket,
  -- a hair over 5%%
  do
    local WILD_STARTERS = {
      { map = "ROUTE_24", species = "BULBASAUR" },
      { map = "ROUTE_7", species = "CHARMANDER" },
    }
    for _, w in ipairs(WILD_STARTERS) do
      local enc = mod.content.encounters:get(w.map)
      local slots = enc and enc.grass and enc.grass.slots
      if slots and #slots >= 7 then
        local out = {}
        for i, s in ipairs(slots) do out[i] = s end
        out[7] = { species = w.species, level = slots[7].level or 10 }
        mod.content.encounters:patch(w.map, { grass = { slots = out } })
        mod.log:info("%s dens on %s (13/256)", w.species, w.map)
      end
    end
  end

  -- SQUIRTLE strikes the GOOD ROD line: a share of successful bites
  -- is the turtle instead of the pool pick; misses stay misses, so
  -- the bite odds themselves never change
  mod.exports.goodRodCatch = function(rod, enc, roll)
    if rod == "GOOD_ROD" and enc and roll <= BALANCE.squirtleChance then
      return { species = "SQUIRTLE", level = enc.level or 10 }
    end
    return enc
  end
  mod.hooks:wrap("encounter.fishing", function(nextFn, rod, mapId, pool)
    local enc = nextFn(rod, mapId, pool)
    return mod.exports.goodRodCatch(rod, enc, math.random(100))
  end)

  mod.content.items:register("EGG_INCUBATOR", {
    id = "EGG_INCUBATOR", name = "INCUBATOR", price = 0,
    tossable = false, effect = "EGG_INCUBATOR_EFFECT",
  })
  -- Palworld-style ornate egg device in real SGB tones (YELLOWMON golds,
  -- BLUEMON glass, PINKMON cushion); trueColor cutouts, masked by the
  -- same render patch as the apricorns
  mod.content.sprites:register("SPRITE_INCUBATOR", {
    id = "SPRITE_INCUBATOR",
    image = mod.assets:path("assets/incubator.png"),
    frames = 1, walker = false, trueColor = true,
  })
  mod.content.sprites:register("SPRITE_INCUBATOR_EGG", {
    id = "SPRITE_INCUBATOR_EGG",
    image = mod.assets:path("assets/incubator_egg.png"),
    frames = 1, walker = false, trueColor = true,
  })

  local theGame
  mod.events:on("game.ready", function(ev) theGame = ev.game end)

  -- The base room wears the palette of the map the TENT STANDS ON.
  -- The engine's interior fallback (lastOutdoor) is not enough:
  -- lastOutdoor only updates when the player exits a building door,
  -- so walking from Cerulean to Lavender and entering the tent
  -- painted the room with CERULEAN.  No recursion: the inner
  -- paletteNameFor call carries the outside map's id, which the
  -- BASE_MAP guard rejects.
  mod.hooks:wrap("map.palette", function(nextFn, name, map, extra)
    if map and map.id == BASE_MAP and theGame then
      local b = mod.save:get("base")
      local def = b and theGame.data.maps[b.map]
      local ow = theGame.overworld
      if def and ow and ow.paletteNameFor then
        local outside = ow:paletteNameFor({ id = b.map, def = def })
        if outside then name = outside end
      end
    end
    return nextFn(name, map, extra)
  end)

  local incubatorNpcId = nil

  local function incubatorState()
    return mod.save:get("incubator")
  end

  -- egg temperature, Palworld style: a warm egg wants a KINDLING
  -- POKéMON, a cold one (an icy child) wants COOLING; the matching
  -- worker halves the wait
  local function eggColdFor(parents, dexGet)
    dexGet = dexGet or function(sp)
      return mod.content.pokemon:get(sp)
    end
    local rec = pairingFor(parents[1], parents[2])
    local species = rec and rec.child or lineRootOf(parents[1])
    local def = dexGet(species)
    for _, t in ipairs(def and def.types or {}) do
      if t == "ICE" then return true end
    end
    return false
  end
  mod.exports.eggColdFor = eggColdFor

  local function eggReady(st, save)
    if not (st and st.startedAt) then return false end
    local need = BREED_SECONDS
    local lvl = mod.exports.bestCrewLevel
    if lvl and lvl(st.cold and "COOLING" or "KINDLING") > 0 then
      need = need / 2
    end
    return ((save.playTime or 0) - st.startedAt) >= need
  end
  mod.exports.eggReady = eggReady
  -- read-only state window for the in-game test driver
  mod.exports.inspect = function(key) return mod.save:get(key) end

  local function pickHatchSpecies(parents, rand)
    rand = rand or function(n) return math.random(n) end
    return parents[rand(2)]
  end
  mod.exports.pickHatchSpecies = pickHatchSpecies

  -- egg moves: 5% -> 3, 20% -> 2, 50% -> 1, else none, drawn from
  -- the species' TM compatibility list (HMs excluded), never a dup
  mod.exports.eggMovesFor = function(def, knownMoves, rand)
    rand = rand or math.random
    local r = rand(100)
    local count = r <= BALANCE.eggMove3 and 3
      or r <= BALANCE.eggMove3 + BALANCE.eggMove2 and 2
      or r <= BALANCE.eggMove3 + BALANCE.eggMove2 + BALANCE.eggMove1 and 1
      or 0
    if count == 0 then return {} end
    local known = {}
    for _, mv in ipairs(knownMoves or {}) do
      known[type(mv) == "table" and mv.id or mv] = true
    end
    local hm = {}
    for _, idef in mod.content.items:each() do
      if idef.machine and idef.machine.kind == "HM" then
        hm[idef.machine.move] = true
      end
    end
    local pool = {}
    for _, mv in ipairs((def and def.tmhm) or {}) do
      if not known[mv] and not hm[mv] then pool[#pool + 1] = mv end
    end
    local out = {}
    while #out < count and #pool > 0 do
      local i = rand(#pool)
      out[#out + 1] = table.remove(pool, i)
    end
    return out
  end

  local function spawnIncubatorFrom(st, save)
    if not mod.world or incubatorNpcId or not (st and st.placed) then return end
    -- one readiness truth: eggReady owns the temperature bonus, so the
    -- respawned sprite always agrees with the state machine
    local ready = st.shownEgg or eggReady(st, save)
    local id = mod.world:spawnNpc(BASE_MAP, {
      x = st.x, y = st.y,
      sprite = ready and "SPRITE_INCUBATOR_EGG" or "SPRITE_INCUBATOR",
      movement = "STAY", range = "NONE",
      text = "TEXT_PALCRAFT_INCUBATOR",
    })
    if type(id) == "string" then incubatorNpcId = id end
  end

  local function respawnIncubator(save)
    if incubatorNpcId and mod.world then mod.world:removeNpc(incubatorNpcId) end
    incubatorNpcId = nil
    spawnIncubatorFrom(incubatorState(), save)
  end

  mod.events:on("save.loaded", function(ev)
    if incubatorNpcId and mod.world then mod.world:removeNpc(incubatorNpcId) end
    incubatorNpcId = nil
    local bucket = ev.save and ev.save.modData and ev.save.modData[mod.id]
    spawnIncubatorFrom(bucket and bucket.incubator, ev.save)
  end)
  mod.events:on("save.created", function(ev)
    if incubatorNpcId and mod.world then mod.world:removeNpc(incubatorNpcId) end
    incubatorNpcId = nil
    local bucket = ev.save and ev.save.modData and ev.save.modData[mod.id]
    spawnIncubatorFrom(bucket and bucket.incubator, ev.save)
  end)

  -- the dome swaps to its egg sprite the moment the timer completes
  -- while you're in the room
  mod.events:on("world.stepped", function(ev)
    if ev.mapId ~= BASE_MAP or not incubatorNpcId or not theGame then return end
    local st = incubatorState()
    if st and st.placed and st.startedAt and not st.shownEgg
       and eggReady(st, theGame.save) then
      st.shownEgg = true
      mod.save:set("incubator", st)
      respawnIncubator(theGame.save)
    end
  end)

  mod.content.item_effects:register("EGG_INCUBATOR_EFFECT", {
    field = true, battle = false,
    use = function(data, save, itemId, target, battle, moveIndex, ow)
      if not ow or not ow.map or ow.map.id ~= BASE_MAP then
        return "failed", { "It only works in\nyour SECRET BASE!" }
      end
      local x, y = facedCell(ow)
      local blocked = not (ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y))
      if not blocked then
        for _, npc in ipairs(ow.npcs or {}) do
          if npc.cellX == x and npc.cellY == y then
            blocked = true
            break
          end
        end
      end
      if blocked then
        return "failed", { "No room to set\nit up there!" }
      end
      local st = incubatorState() or {}
      st.placed, st.map, st.x, st.y = true, BASE_MAP, x, y
      mod.save:set("incubator", st)
      respawnIncubator(save)
      return "consumed", { "The INCUBATOR\nis ready!" }
    end,
  })

  -- ------- the incubator's interaction flow

  local Pokemon = require("src.pokemon.Pokemon")

  local function incubatorText(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function speciesName(game, species)
    local def = game.data.pokemon[species]
    return (def and def.name) or tostring(species)
  end

  local function pushParentPick(game, which, first)
    local pals = currentPals()
    local ws = mod.exports.workSuitabilities
    local entries = {}
    for i, mon in ipairs(pals) do
      if i ~= first then
        -- a "?!" instead of the level whispers that this partner would
        -- make something interesting -- without saying what; anything
        -- that can't pair here at all greys out instead
        local tag = "L" .. tostring(mon.level or "?")
        local disabled, note, reveal
        if which == 2 then
          if pals[first]
             and not canBreed(pals[first].species, mon.species) then
            disabled, note = true, "THEY WON'T BREED"
          else
            local rec = pals[first]
              and pairingFor(pals[first].species, mon.species)
            if rec then
              tag = "?!"
              -- a staffed research desk deciphers the pairing: the
              -- top border names the child outright
              if mod.exports.researchActive
                 and mod.exports.researchActive() then
                reveal = speciesName(game, rec.child)
              end
            end
          end
        else
          -- a first parent with no possible partner is a dead end
          local hasPartner = false
          for j, other in ipairs(pals) do
            if j ~= i and canBreed(mon.species, other.species) then
              hasPartner = true
              break
            end
          end
          if not hasPartner then
            disabled, note = true, "NO PARTNER HERE"
          end
        end
        -- the panel is catalog knowledge, not a roll call: every
        -- special pairing this line completes (partner > child), even
        -- when the partner isn't in the base -- and when no mutation
        -- exists, the same-species default and its base-form child
        local root = lineRootOf(mon.species)
        local pairs_, extra = {}, 0
        for _, rec in ipairs(BREED_LINES) do
          local other
          if rec.a == root then other = rec.b
          elseif rec.b == root then other = rec.a end
          if other then
            if #pairs_ < 2 then
              -- the GB font has no ">" (or "*"): the menu arrow is
              -- the "gives" glyph.  It is 3 BYTES but one glyph, so
              -- trim the child, never the assembled string
              local pName = speciesName(game, other)
              local cName = speciesName(game, rec.child)
              cName = cName:sub(1, math.max(1, 17 - #pName))
              pairs_[#pairs_ + 1] = pName .. "\226\150\182" .. cName
            else
              extra = extra + 1
            end
          end
        end
        local infoLines = { "BREEDS WITH:" }
        if #pairs_ == 0 then
          infoLines[2] = "ITS OWN KIND"
          infoLines[3] = "\226\150\182" .. speciesName(game, root):sub(1, 17)
        else
          for _, p in ipairs(pairs_) do
            infoLines[#infoLines + 1] = p
          end
          if extra > 0 then
            infoLines[3] = ((infoLines[3] or "") .. " +" .. extra):sub(1, 18)
          end
        end
        entries[#entries + 1] = {
          species = mon.species,
          label = ("%s %s"):format(palLabel(game, mon), tag),
          right = tag, value = i,
          disabled = disabled, note = note, reveal = reveal,
          infoLines = infoLines,
        }
      end
    end
    local list
    list = newMonGrid(game, {
      title = which == 1 and "PARENT 1" or "PARENT 2",
      kind = "incubator_pick", entries = entries,
      emptyText = "NOBODY ELSE HERE!",
      -- the hint tag rides the top border, picker style; a staffed
      -- research desk swaps it for the child's actual name
      topLabel = function(grid)
        local e = grid.entries[grid.index]
        return e and (e.reveal or e.right)
      end,
      onChoose = function(e)
        if e.disabled then
          incubatorText(game, which == 1
            and "It has no\npartner here!"
            or "They wouldn't\nget along...")
          return
        end
        list:close()
        if which == 1 then
          pushParentPick(game, 2, e.value)
        else
          local p1, p2 = pals[first], pals[e.value]
          local st = incubatorState() or {}
          st.parents = { p1.species, p2.species }
          st.parentNames = { palLabel(game, p1), palLabel(game, p2) }
          mod.save:set("incubator", st)
          if pairingFor(p1.species, p2.species) then
            incubatorText(game, st.parentNames[1] .. " and "
              .. st.parentNames[2] .. " are\ngetting along famously!")
          else
            incubatorText(game, st.parentNames[1] .. " and\n"
              .. st.parentNames[2] .. " settled in.")
          end
        end
      end,
    })
    game.stack:push(list)
  end

  local function addFuel(game)
    local inv = game.save.inventory
    if not inv.FERMENTED_JUICE or inv.FERMENTED_JUICE < 1 then
      incubatorText(game, "It needs\nFERM.JUICE!")
      return
    end
    inv.FERMENTED_JUICE = inv.FERMENTED_JUICE > 1
      and inv.FERMENTED_JUICE - 1 or nil
    local st = incubatorState()
    st.startedAt = game.save.playTime or 0
    st.shownEgg = nil
    st.cold = st.parents and eggColdFor(st.parents) or false
    mod.save:set("incubator", st)
    incubatorText(game, st.cold
      and "The INCUBATOR hums.\nThis egg runs COLD--\nCOOLING would help!"
      or "The INCUBATOR\nhums to life!")
  end

  local function hatchEgg(game)
    local st = incubatorState()
    if not (st and st.parents) then return end
    local species = breedChild(st.parents)
    local mon = Pokemon.new(game.data, species, 1)
    -- hatchlings carry the bred mark for life (persists in the save
    -- like mon.traded does); HARD difficulty reads it at EXP time
    mon.bred = true
    -- and hatch at star 1 (BALANCE.starBred % stats)
    mod.exports.setStars(mon, game.data.pokemon[species], 1)
    -- egg moves: a chance at random TM-compatible bonus moves
    local rand = (love and love.math and love.math.random) or math.random
    for _, mv in ipairs(mod.exports.eggMovesFor(
        game.data.pokemon[species], mon.moves, rand)) do
      if #mon.moves < 4 then
        local mdef = game.data.moves[mv]
        mon.moves[#mon.moves + 1] = { id = mv, pp = mdef and mdef.pp or 5 }
      end
    end
    local name = speciesName(game, species)
    local msg
    local cap = (game.data.constants and game.data.constants.partyMax) or 6
    if #(game.save.party or {}) < cap then
      game.save.party = game.save.party or {}
      table.insert(game.save.party, mon)
      msg = name .. " hatched and\njoined the party!"
    else
      local boxes = boxesOf(game)
      local boxCount = (game.data.constants and game.data.constants.boxCount) or 12
      local boxSize = (game.data.constants and game.data.constants.boxSize) or 20
      local target
      local start = game.save.currentBox or 1
      for off = 0, boxCount - 1 do
        local i = ((start - 1 + off) % boxCount) + 1
        if boxes[i] and #boxes[i] < boxSize then
          target = i
          break
        end
      end
      if not target then
        incubatorText(game, "No room for the\nhatchling!")
        return
      end
      table.insert(boxes[target], mon)
      msg = name .. (" hatched!\nSent to BOX %d."):format(target)
    end
    local dex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex = dex
    dex.seen = dex.seen or {}
    dex.owned = dex.owned or {}
    dex.seen[species], dex.owned[species] = true, true
    -- fresh parents every clutch: hatching clears the assignment
    st.startedAt, st.shownEgg = nil, nil
    st.parents, st.parentNames = nil, nil
    mod.save:set("incubator", st)
    respawnIncubator(game.save)
    incubatorText(game, msg)
  end

  local function packUpIncubator(game)
    local st = incubatorState()
    if not (st and st.placed) then return end
    local inv = game.save.inventory
    if not inv.EGG_INCUBATOR then
      local slots = 0
      local cap = (game.data.constants and game.data.constants.bagSize) or 20
      for id in pairs(inv) do
        if not id:find("BADGE", 1, true) then slots = slots + 1 end
      end
      if slots >= cap then
        incubatorText(game, "No room in the\nbag for it!")
        return
      end
    end
    st.placed = false
    mod.save:set("incubator", st)
    if incubatorNpcId and mod.world then mod.world:removeNpc(incubatorNpcId) end
    incubatorNpcId = nil
    inv.EGG_INCUBATOR = (inv.EGG_INCUBATOR or 0) + 1
    incubatorText(game, "Packed up the\nINCUBATOR.")
  end

  local function openIncubatorMenu(game)
    local st = incubatorState()
    if not (st and st.placed) then return end
    if eggReady(st, game.save) then
      game.stack:push(mod.ui.Menu.new(game, {
        { label = "HATCH", onSelect = function() hatchEgg(game) end },
        { label = "CANCEL", onSelect = function() end },
      }, { tx = 8, ty = 8 }))
      return
    end
    if st.startedAt then
      local left = math.max(0, math.ceil(BREED_SECONDS
        - ((game.save.playTime or 0) - st.startedAt)))
      incubatorText(game, ("The egg is\nwarming... %ds"):format(left))
      return
    end
    local rows = {}
    if st.parents then
      rows[#rows + 1] = { label = "ADD JUICE",
                          onSelect = function() addFuel(game) end }
    end
    rows[#rows + 1] = { label = "ASSIGN", onSelect = function()
      if #currentPals() < 2 then
        incubatorText(game, "You need two\nPOKéMON in the base!")
      else
        pushParentPick(game, 1, nil)
      end
    end }
    rows[#rows + 1] = { label = "PACK UP",
                        onSelect = function() packUpIncubator(game) end }
    rows[#rows + 1] = { label = "CANCEL", onSelect = function() end }
    game.stack:push(mod.ui.Menu.new(game, rows, { tx = 6, ty = 6 }))
  end

  mod.commands:register("palcraft_incubator", function(ctx)
    openIncubatorMenu(ctx.game)
  end)

  mod.content.map_scripts:register(BASE_MAP, {
    talk = {
      TEXT_PALCRAFT_INCUBATOR = {
        { "face_player" },
        { "palcraft_incubator" },
      },
    },
  })

  -- ------------------------------------- the grape farm

  -- The incubator drinks FERMENTED JUICE now.  Juice is crafted from
  -- GRAPES at the crafting table; grapes grow on vines planted from
  -- GRAPE SEEDS (dropped by bug/grass/flying battles instead of
  -- apricorns).  A vine only grows while the base houses a GRASS or BUG
  -- POKéMON (the grower) and a WATER POKéMON (the waterer).  Ripe vines
  -- hand over a random bunch of grapes plus a seed -- or, with a
  -- FIGHTING POKéMON and a storage CHEST in the base, harvest themselves
  -- into the chest and replant on their own.

  local GROW_SECONDS = BALANCE.growSeconds

  -- The tilled 2x2 patch: farming is spatial -- seeds only take root
  -- on these four cells, so the vine cap is something you can SEE.
  -- Cells (2-3, 4-5) = map block (1,2), the DIRT_BLOCK of cave-floor
  -- tiles laid by the base map above; the ground stays visible under
  -- planted vines because it IS the floor.
  local PLOTS = { { 2, 4 }, { 3, 4 }, { 2, 5 }, { 3, 5 } }
  local function plotAt(x, y)
    for _, p in ipairs(PLOTS) do
      if p[1] == x and p[2] == y then return p end
    end
    return nil
  end

  mod.content.items:register("GRAPE_SEED", {
    id = "GRAPE_SEED", name = "GRAPE SEED", price = 40,
    tossable = true, effect = "GRAPE_SEED_EFFECT",
  })
  mod.content.items:register("GRAPES", {
    id = "GRAPES", name = "GRAPES", price = 60, tossable = true,
  })
  mod.content.items:register("FERMENTED_JUICE", {
    id = "FERMENTED_JUICE", name = "FERM.JUICE", price = 175,
    tossable = true,
  })
  mod.content.items:register("STORAGE_CHEST", {
    id = "STORAGE_CHEST", name = "CHEST", price = 300,
    tossable = false, effect = "STORAGE_CHEST_EFFECT",
  })
  -- the CHEST is crafted now, never bought

  for _, s in ipairs({
    { "SPRITE_VINE", "assets/vine_young.png" },
    { "SPRITE_VINE_GROWN", "assets/vine_grown.png" },
  }) do
    mod.content.sprites:register(s[1], {
      id = s[1], image = mod.assets:path(s[2]),
      frames = 1, walker = false, trueColor = true,
    })
  end
  -- the chest is an original lab-machine cabinet (reel deck + vents,
  -- per the lab instruments), in native DMG shades so it palette-tints
  -- like real lab equipment
  mod.content.sprites:register("SPRITE_CHEST", {
    id = "SPRITE_CHEST",
    image = mod.assets:path("assets/lab_chest.png"),
    frames = 1, walker = false,
  })

  table.insert(RECIPES, { ball = "FERMENTED_JUICE", label = "FERM.JUICE",
                          work = 45, cost = { { "GRAPES", 3 } } })

  local SEED_TYPES = { BUG = true, GRASS = true, FLYING = true }
  local function dropsSeeds(types)
    for _, t in ipairs(types or {}) do
      if SEED_TYPES[t] then return true end
    end
    return false
  end
  mod.exports.dropsSeeds = dropsSeeds

  local function harvestCycles(progress, grow)
    local n = math.floor(progress / grow)
    return n, progress - n * grow
  end
  mod.exports.harvestCycles = harvestCycles

  -- who's on the crew?  (grower, waterer, fighter)
  -- the farm crew reads the JOB system now (so shrine boosts and the
  -- OVERSEER wildcard count): GATHERING or PLANTING grows, WATERING
  -- waters, and TRANSPORT hauls -- the old FIGHTING foreman retired
  -- to the dojo when the dummy arrived
  local function baseCrew(game)
    local lvl = mod.exports.bestCrewLevel
    if not lvl then return false, false, false end
    local grower = lvl("GATHERING") > 0 or lvl("PLANTING") > 0
    local waterer = lvl("WATERING") > 0
    local hauler = lvl("TRANSPORT") > 0
    return grower, waterer, hauler
  end

  local vineNpcs = {}   -- index -> npc id, this session
  local vineSig = nil

  local function vineSignature(vines)
    local parts = {}
    for i, v in ipairs(vines) do
      parts[i] = v.x .. "," .. v.y .. ","
        .. ((v.progress or 0) >= GROW_SECONDS and 1 or 0)
    end
    return table.concat(parts, ";")
  end

  local function refreshVineSprites(force)
    if not mod.world then return end
    local vines = mod.save:get("vines", {})
    local sig = vineSignature(vines)
    if not force and sig == vineSig then return end
    vineSig = sig
    for i, id in pairs(vineNpcs) do
      mod.world:removeNpc(id)
      vineNpcs[i] = nil
    end
    for i, v in ipairs(vines) do
      local id = mod.world:spawnNpc(BASE_MAP, {
        x = v.x, y = v.y,
        sprite = (v.progress or 0) >= GROW_SECONDS
          and "SPRITE_VINE_GROWN" or "SPRITE_VINE",
        movement = "STAY", range = "NONE",
        text = "TEXT_PALCRAFT_VINE",
      })
      if type(id) == "string" then vineNpcs[i] = id end
    end
  end

  -- vines from saves that predate the patch move onto free plots
  local function migrateVinesToPlots()
    local vines = mod.save:get("vines", {})
    local changed = false
    for _, v in ipairs(vines) do
      if not plotAt(v.x, v.y) then
        for _, p in ipairs(PLOTS) do
          local free = true
          for _, w in ipairs(vines) do
            if w.x == p[1] and w.y == p[2] then
              free = false
              break
            end
          end
          if free then
            v.x, v.y = p[1], p[2]
            changed = true
            break
          end
        end
      end
    end
    if changed then mod.save:set("vines", vines) end
  end

  local function tickVines(game)
    local vines = mod.save:get("vines", {})
    if #vines == 0 then return end
    local now = game.save.playTime or 0
    local grower, waterer, fighter = baseCrew(game)
    local chest = mod.save:get("chest")
    local autoHarvest = fighter and chest and chest.placed
    -- vines are one-shot: the hauler picks the single grape into the
    -- chest and the plot goes back to bare dirt
    for i = #vines, 1, -1 do
      local v = vines[i]
      local dt = math.max(0, now - (v.lastTick or now))
      v.lastTick = now
      if grower and waterer then
        v.progress = (v.progress or 0) + dt
      end
      if (v.progress or 0) >= GROW_SECONDS then
        if autoHarvest then
          chest.items = chest.items or {}
          chest.items.GRAPES = (chest.items.GRAPES or 0)
            + math.random(BALANCE.harvestMin, BALANCE.harvestMax)
          table.remove(vines, i)
        else
          v.progress = GROW_SECONDS
        end
      end
    end
    mod.save:set("vines", vines)
    if autoHarvest then mod.save:set("chest", chest) end
    refreshVineSprites()
  end

  mod.events:on("world.stepped", function(ev)
    if ev.mapId == BASE_MAP and theGame then tickVines(theGame) end
  end)

  local chestNpcId = nil

  local function spawnChest()
    local chest = mod.save:get("chest")
    if not mod.world or chestNpcId or not (chest and chest.placed) then return end
    local id = mod.world:spawnNpc(BASE_MAP, {
      x = chest.x, y = chest.y,
      sprite = "SPRITE_CHEST", movement = "STAY", range = "NONE",
      text = "TEXT_PALCRAFT_CHEST",
    })
    if type(id) == "string" then chestNpcId = id end
  end

  local function resyncFarm(save)
    for i, id in pairs(vineNpcs) do
      if mod.world then mod.world:removeNpc(id) end
      vineNpcs[i] = nil
    end
    migrateVinesToPlots()
    vineSig = nil
    if chestNpcId and mod.world then mod.world:removeNpc(chestNpcId) end
    chestNpcId = nil
    if not mod.world then return end
    local bucket = save and save.modData and save.modData[mod.id]
    if bucket then
      local vines = bucket.vines or {}
      for i, v in ipairs(vines) do
        local id = mod.world:spawnNpc(BASE_MAP, {
          x = v.x, y = v.y,
          sprite = (v.progress or 0) >= GROW_SECONDS
            and "SPRITE_VINE_GROWN" or "SPRITE_VINE",
          movement = "STAY", range = "NONE",
          text = "TEXT_PALCRAFT_VINE",
        })
        if type(id) == "string" then vineNpcs[i] = id end
      end
      vineSig = vineSignature(vines)
      local chest = bucket.chest
      if chest and chest.placed then
        local id = mod.world:spawnNpc(BASE_MAP, {
          x = chest.x, y = chest.y,
          sprite = "SPRITE_CHEST", movement = "STAY", range = "NONE",
          text = "TEXT_PALCRAFT_CHEST",
        })
        if type(id) == "string" then chestNpcId = id end
      end
    end
  end
  mod.events:on("save.loaded", function(ev) resyncFarm(ev.save) end)
  mod.events:on("save.created", function(ev) resyncFarm(ev.save) end)

  local function farmText(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function plantSeedAt(save, x, y)
    if not plotAt(x, y) then
      return false, "Plant it in the\ntilled dirt patch!"
    end
    local vines = mod.save:get("vines", {})
    for _, v in ipairs(vines) do
      if v.x == x and v.y == y then
        return false, "Something already\ngrows there!"
      end
    end
    vines[#vines + 1] = { x = x, y = y, progress = 0,
                          lastTick = save.playTime or 0 }
    mod.save:set("vines", vines)
    refreshVineSprites(true)
    return true, "A grape vine\ntakes root!"
  end

  mod.content.item_effects:register("GRAPE_SEED_EFFECT", {
    field = true, battle = false,
    use = function(data, save, itemId, target, battle, moveIndex, ow)
      if not ow or not ow.map or ow.map.id ~= BASE_MAP then
        return "failed", { "Seeds only take\nroot in the base!" }
      end
      local x, y = facedCell(ow)
      local ok, msg = plantSeedAt(save, x, y)
      return ok and "consumed" or "failed", { msg }
    end,
  })

  -- pressing A on bare dirt offers to plant (the plot cells carry
  -- sign entries; a vine npc on the cell answers first)
  mod.commands:register("palcraft_dirt", function(ctx)
    local game, ow = ctx.game, ctx.overworld
    if not ow then return end
    local x, y = facedCell(ow)
    local inv = game.save.inventory
    if (inv.GRAPE_SEED or 0) < 1 then
      farmText(game, "Soft, tilled soil.\nA GRAPE SEED\ncould grow here.")
      return
    end
    game.stack:push(mod.ui.TextBox.new(game,
      "Plant a GRAPE\nSEED here?", function()
      game.stack:push(mod.ui.ChoiceBox.new(game, function(yes)
        if not yes then return end
        local ok, msg = plantSeedAt(game.save, x, y)
        if ok then
          inv.GRAPE_SEED = (inv.GRAPE_SEED or 0) > 1
            and inv.GRAPE_SEED - 1 or nil
        end
        farmText(game, msg)
      end))
    end))
  end)

  mod.content.item_effects:register("STORAGE_CHEST_EFFECT", {
    field = true, battle = false,
    use = function(data, save, itemId, target, battle, moveIndex, ow)
      if not ow or not ow.map or ow.map.id ~= BASE_MAP then
        return "failed", { "The CHEST belongs\nin your base!" }
      end
      local chest = mod.save:get("chest")
      if chest and chest.placed then
        return "failed", { "The base already\nhas a CHEST!" }
      end
      local x, y = facedCell(ow)
      local blocked = not (ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y))
      if not blocked then
        for _, npc in ipairs(ow.npcs or {}) do
          if npc.cellX == x and npc.cellY == y then
            blocked = true
            break
          end
        end
      end
      if blocked then
        return "failed", { "No room to set\nit down there!" }
      end
      chest = chest or {}
      chest.placed, chest.x, chest.y = true, x, y
      chest.items = chest.items or {}
      mod.save:set("chest", chest)
      spawnChest()
      return "consumed", { "The CHEST is\nready!" }
    end,
  })

  mod.commands:register("palcraft_vine", function(ctx)
    local game, ow = ctx.game, ctx.overworld
    if not ow then return end
    tickVines(game)
    local x, y = facedCell(ow)
    local vines = mod.save:get("vines", {})
    local idx
    for i, v in ipairs(vines) do
      if v.x == x and v.y == y then
        idx = i
        break
      end
    end
    if not idx then return end
    local v = vines[idx]
    if (v.progress or 0) < GROW_SECONDS then
      local grower, waterer = baseCrew(game)
      if not grower then
        farmText(game, "It needs GATHERING\nor PLANTING work!")
      elseif not waterer then
        farmText(game, "It needs WATERING\nwork to grow!")
      else
        local left = math.ceil(GROW_SECONDS - (v.progress or 0))
        farmText(game, ("Growing well...\n%ds to ripen."):format(left))
      end
      return
    end
    -- ripe: one grape, no seed back -- the vine is spent (seeds are
    -- the farming bottleneck now)
    local inv = ctx.save.inventory
    local slots, cap = 0,
      (game.data.constants and game.data.constants.bagSize) or 20
    for id in pairs(inv) do
      if not id:find("BADGE", 1, true) then slots = slots + 1 end
    end
    if not inv.GRAPES and slots + 1 > cap then
      farmText(game, "No room in the\nbag to harvest!")
      return
    end
    local grapes = math.random(BALANCE.harvestMin, BALANCE.harvestMax)
    inv.GRAPES = (inv.GRAPES or 0) + grapes
    table.remove(vines, idx)
    mod.save:set("vines", vines)
    refreshVineSprites(true)
    farmText(game, grapes > 1
      and ("Picked %d GRAPES!"):format(grapes) or "Picked a GRAPE!")
  end)

  mod.commands:register("palcraft_chest", function(ctx)
    local game = ctx.game
    local chest = mod.save:get("chest")
    if not (chest and chest.placed) then return end
    -- settle any due auto-harvests first, like the vine talk does:
    -- world.stepped ticks can starve when npcs block the walkway, and
    -- the chest must never show stale contents (#flake in the driver)
    tickVines(game)
    chest = mod.save:get("chest")
    local items = {}
    for id, count in pairs(chest.items or {}) do
      local def = game.data.items[id]
      items[#items + 1] = { label = (def and def.name) or id,
                            right = "x" .. count, value = id }
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    table.insert(items, 1, { label = "DEPOSIT..", value = "__deposit" })
    items[#items + 1] = { label = "PACK UP", value = "__pack" }
    local list
    list = mod.ui.ListMenu.new(game, "CHEST", items, {
      kind = "palcraft_chest",
      onChoose = function(item)
        if item.value == "__deposit" then
          list:close()
          local bagRows = {}
          for id, count in pairs(game.save.inventory or {}) do
            if not id:find("BADGE", 1, true) then
              local def = game.data.items[id]
              bagRows[#bagRows + 1] = { label = (def and def.name) or id,
                                        right = "x" .. count, value = id }
            end
          end
          table.sort(bagRows, function(a, b) return a.label < b.label end)
          if #bagRows == 0 then
            farmText(game, "Nothing in the\nbag to store!")
            return
          end
          local picker
          picker = mod.ui.ListMenu.new(game, "DEPOSIT", bagRows, {
            kind = "palcraft_deposit",
            onChoose = function(row)
              picker:close()
              local have = game.save.inventory[row.value] or 0
              game.stack:push(mod.ui.QuantityBox.new(game, {
                max = have,
                onDone = function(qty)
                  if qty and qty > 0 then
                    local inv = game.save.inventory
                    local left = have - qty
                    inv[row.value] = left > 0 and left or nil
                    chest.items = chest.items or {}
                    chest.items[row.value] =
                      (chest.items[row.value] or 0) + qty
                    mod.save:set("chest", chest)
                    farmText(game, ("Stored %s x%d."):format(
                      row.label, qty))
                  end
                end,
              }))
            end,
          })
          game.stack:push(picker)
          return
        end
        if item.value == "__pack" then
          list:close()
          local inv = game.save.inventory
          if next(chest.items or {}) ~= nil then
            farmText(game, "Empty the CHEST\nbefore packing it!")
            return
          end
          if not inv.STORAGE_CHEST then
            local slots = 0
            local cap = (game.data.constants and game.data.constants.bagSize) or 20
            for id in pairs(inv) do
              if not id:find("BADGE", 1, true) then slots = slots + 1 end
            end
            if slots >= cap then
              farmText(game, "No room in the\nbag for it!")
              return
            end
          end
          chest.placed = false
          mod.save:set("chest", chest)
          if chestNpcId and mod.world then mod.world:removeNpc(chestNpcId) end
          chestNpcId = nil
          inv.STORAGE_CHEST = (inv.STORAGE_CHEST or 0) + 1
          farmText(game, "Packed up the\nCHEST.")
          return
        end
        -- withdraw the whole stack to the bag
        local inv = game.save.inventory
        local count = chest.items[item.value] or 0
        if count < 1 then return end
        if not inv[item.value] then
          local slots = 0
          local cap = (game.data.constants and game.data.constants.bagSize) or 20
          for id in pairs(inv) do
            if not id:find("BADGE", 1, true) then slots = slots + 1 end
          end
          if slots >= cap then
            list:close()
            farmText(game, "No room in the\nbag!")
            return
          end
        end
        local take = math.min(count, 99 - (inv[item.value] or 0))
        if take < 1 then
          list:close()
          farmText(game, "The bag can't\nhold any more!")
          return
        end
        inv[item.value] = (inv[item.value] or 0) + take
        chest.items[item.value] = count - take
        if chest.items[item.value] < 1 then chest.items[item.value] = nil end
        mod.save:set("chest", chest)
        list:close()
        farmText(game, ("Took %d %s."):format(take,
          (game.data.items[item.value] and game.data.items[item.value].name)
          or item.value))
      end,
    })
    game.stack:push(list)
  end)

  mod.content.map_scripts:register(BASE_MAP, {
    talk = {
      TEXT_PALCRAFT_VINE = {
        { "face_player" },
        { "palcraft_vine" },
      },
      TEXT_PALCRAFT_DIRT = {
        { "palcraft_dirt" },
      },
      TEXT_PALCRAFT_CHEST = {
        { "face_player" },
        { "palcraft_chest" },
      },
      TEXT_PALCRAFT_GENERATOR = {
        { "face_player" },
        { "palcraft_generator" },
      },
      TEXT_PALCRAFT_FURNACE = {
        { "face_player" },
        { "palcraft_furnace" },
      },
      TEXT_PALCRAFT_MEDBENCH = {
        { "face_player" },
        { "palcraft_medbench" },
      },
      TEXT_PALCRAFT_DUMMY = {
        { "face_player" },
        { "palcraft_dummy" },
      },
      TEXT_PALCRAFT_DESK = {
        { "face_player" },
        { "palcraft_desk" },
      },
      TEXT_PALCRAFT_SHRINE = {
        { "face_player" },
        { "palcraft_shrine" },
      },
      TEXT_PALCRAFT_LUMBER = {
        { "face_player" },
        { "palcraft_lumber" },
      },
      TEXT_PALCRAFT_MINE = {
        { "face_player" },
        { "palcraft_mine" },
      },
      TEXT_PALCRAFT_ALTAR = {
        { "face_player" },
        { "palcraft_altar" },
      },
      TEXT_PALCRAFT_CONDENSER = {
        { "face_player" },
        { "palcraft_condenser" },
      },
    },
  })

  -- ------------------------------------------------- battle-win drops

  -- The color tracks the beaten level, mirroring the ball tiers: low
  -- levels shake out RED (Poke Ball territory), the teens-twenties favor
  -- BLU (where a Great Ball earns its keep), 30+ skews YLW (Ultra tier).
  -- Weights are { RED, BLU, YLW } per band.
  local DROP_BANDS = {
    { maxLevel = 12,  weights = { 75, 20, 5 } },
    { maxLevel = 22,  weights = { 35, 55, 10 } },
    { maxLevel = 32,  weights = { 20, 50, 30 } },
    { maxLevel = 999, weights = { 10, 35, 55 } },
  }
  local function dropWeights(level)
    for _, band in ipairs(DROP_BANDS) do
      if level <= band.maxLevel then return band.weights end
    end
    return DROP_BANDS[#DROP_BANDS].weights
  end
  mod.exports.dropWeights = dropWeights

  local function rollApricorn(rand, level)
    local w = dropWeights(level or 5)
    local pick = rand() * (w[1] + w[2] + w[3])
    for i, a in ipairs(APRICORNS) do
      pick = pick - w[i]
      if pick < 0 then return a.id end
    end
    return APRICORNS[1].id
  end

  -- Drops wait here until the overworld script queue is free: right after
  -- a trainer battle the defeat script may still hold the runner.
  local pending = nil

  -- every type sheds an ORGAN for the research desk (item 23):
  -- defeated POKéMON have a chance to drop one of THEIR types' organs
  local ORGAN_FOR = {}
  do
    local shorts = {
      NORMAL = "NORMAL", FIGHTING = "FIGHT", FLYING = "FLYING",
      POISON = "POISON", GROUND = "GROUND", ROCK = "ROCK", BUG = "BUG",
      GHOST = "GHOST", FIRE = "FIRE", WATER = "WATER", GRASS = "GRASS",
      ELECTRIC = "ELEC", ICE = "ICE", PSYCHIC_TYPE = "PSY",
      DRAGON = "DRAGON",
    }
    for t, short in pairs(shorts) do
      local id = "ORGAN_" .. (t == "PSYCHIC_TYPE" and "PSYCHIC" or t)
      ORGAN_FOR[t] = id
      mod.content.items:register(id, {
        id = id, name = short .. " ORGAN", price = 100, tossable = true,
      })
    end
  end
  mod.exports.organFor = ORGAN_FOR

  local SEED_CHANCE = BALANCE.seedChance
  local ORE_CHANCE = BALANCE.oreChance
  local WOOD_CHANCE = BALANCE.woodChance
  local WOOD_MAX_LEVEL = BALANCE.woodMaxLevel
  local function rollDrop(seedy, rand, level, orey, types)
    if seedy and rand(100) <= SEED_CHANCE then
      return "GRAPE_SEED"
    end
    -- a defeated POKéMON sheds one of its own types' organs
    if types and #types > 0 and rand(100) <= BALANCE.organChance then
      local organ = ORGAN_FOR[types[rand(#types)]]
      if organ then return organ end
    end
    -- rock and ground types shake out ORE for the furnace
    if orey and rand(100) <= ORE_CHANCE then
      return "ORE"
    end
    -- the RED-apricorn band doubles as lumber country: low-level
    -- wilds keep the craft table stocked with ball frames
    if (level or 5) < WOOD_MAX_LEVEL and rand(100) <= WOOD_CHANCE then
      return "WOOD"
    end
    return rollApricorn(rand, level)
  end
  mod.exports.rollDrop = rollDrop

  local ORE_TYPES = { ROCK = true, GROUND = true }
  local function dropsOre(types)
    for _, t in ipairs(types or {}) do
      if ORE_TYPES[t] then return true end
    end
    return false
  end
  mod.exports.dropsOre = dropsOre

  -- The SECRET BASE arrives with the POKéDEX: watch the flag, gift
  -- once.  Delivered DIRECTLY (bag write + plain TextBox), never via
  -- the script runner -- a runner-held gift text deadlocks scripted
  -- warps that are waiting for the runner to go idle.
  mod.events:on("world.stepped", function()
    if not theGame then return end
    local save = theGame.save
    if not save or not save.flags or not save.flags.EVENT_GOT_POKEDEX then
      return
    end
    if mod.save:get("base_given") then return end
    local inv = save.inventory
    if not inv then return end
    if not inv.SECRET_BASE then
      local slots, cap = 0,
        (theGame.data.constants and theGame.data.constants.bagSize) or 20
      for id in pairs(inv) do
        if not id:find("BADGE", 1, true) then slots = slots + 1 end
      end
      if slots >= cap then return end   -- full bag: retry next step
    end
    mod.save:set("base_given", true)
    inv.SECRET_BASE = (inv.SECRET_BASE or 0) + 1
    inv.CRAFT_TABLE = (inv.CRAFT_TABLE or 0) + 1
    if theGame.stack:top() == theGame.overworld then
      theGame.stack:push(mod.ui.TextBox.new(theGame,
        "The POKéDEX came\nwith a SECRET BASE\nkit and a CRAFT\nTABLE!"))
    end
  end)

  -- gym rewards double as blueprints: say so when the badge lands
  mod.exports.badgeNotices = {
    { badge = "BOULDERBADGE", key = "told_incubator",
      text = "BROCK's badge came\nwith the INCUBATOR\nblueprint!\fBuild it at the\nCRAFT TABLE." },
    { badge = "CASCADEBADGE", key = "told_lumber",
      text = "MISTY's badge came\nwith the WOODPILE\nblueprint!\fBuild it at the\nCRAFT TABLE." },
    { badge = "THUNDERBADGE", key = "told_generator",
      text = "LT.SURGE's badge\ncame with the\nGENERATOR\nblueprint!\fBuild it at the\nCRAFT TABLE." },
  }
  mod.events:on("world.stepped", function()
    if not theGame then return end
    local inv = theGame.save and theGame.save.inventory
    if not inv then return end
    if theGame.stack:top() ~= theGame.overworld then return end
    for _, n in ipairs(mod.exports.badgeNotices) do
      if inv[n.badge] and not mod.save:get(n.key) then
        mod.save:set(n.key, true)
        theGame.stack:push(mod.ui.TextBox.new(theGame, n.text))
        return
      end
    end
  end)

  -- HARD difficulty: unbred POKeMON earn half EXP.  battle.exp_award
  -- hands us the same applyShare vanilla uses; split is the divisor,
  -- so doubling it halves the share (and the announced number follows)
  mod.exports.expSplitFor = function(mon, split)
    if mod.options:get("difficulty") ~= "hard" then return split end
    if mon and mon.bred then return split end
    return split * 2
  end
  mod.hooks:wrap("battle.exp_award", function(nextFn, ctx)
    if mod.options:get("difficulty") ~= "hard" then return nextFn(ctx) end
    local orig = ctx.applyShare
    ctx.applyShare = function(m, split, announce)
      return orig(m, mod.exports.expSplitFor(m, split), announce)
    end
    return nextFn(ctx)
  end)

  local WILD_DROP_CHANCE = BALANCE.wildDropChance
  mod.events:on("battle.ended", function(ev)
    local b = ev.battle
    local kind = b and b.kind
    if ev.result ~= "win" or kind == "link" then return end
    local level = (b and b.enemy and b.enemy.mon and b.enemy.mon.level) or 5
    local rand = (love and love.math and love.math.random) or math.random
    local rolls
    if kind == "trainer" then rolls = BALANCE.trainerDrops
    else rolls = rand() < WILD_DROP_CHANCE and 1 or 0 end
    -- bug/grass/flying opponents have a 20% shot at a GRAPE SEED per
    -- drop; every other roll falls through to the usual apricorn
    local species = b and b.enemy and b.enemy.mon and b.enemy.mon.species
    local seedy, orey, foeTypes = false, false, nil
    if species and theGame then
      local sdef = theGame.data.pokemon[species]
      seedy = dropsSeeds(sdef and sdef.types)
      orey = dropsOre(sdef and sdef.types)
      foeTypes = sdef and sdef.types
    end
    for _ = 1, rolls do
      local id = rollDrop(seedy, rand, level, orey, foeTypes)
      pending = pending or {}
      pending[id] = (pending[id] or 0) + 1
    end
  end)

  local function settleDrops()
    if not pending or not mod.world then return end
    -- give_item halts its script on a full bag AFTER pending is
    -- cleared, eating the drops -- hold them until there's room
    if theGame then
      local Bag = require("src.inventory.Bag")
      local inv = theGame.save.inventory
      local fresh = 0
      for id in pairs(pending) do
        if not inv[id] then fresh = fresh + 1 end
      end
      if Bag.slots(theGame.save) + fresh > Bag.capacity(theGame.data) then
        return
      end
    end
    local rows = {}
    for id, count in pairs(pending) do
      rows[#rows + 1] = { "give_item", id, count }
    end
    if mod.world:queueScript(rows) then pending = nil end
  end

  -- NEVER settle on screen.popped: engine UI-close callbacks may start
  -- their own script AFTER the pop event (the POKe FLUTE's Snorlax wake
  -- does), and stealing the runner in that window crashes the game on
  -- ScriptRunner's "script already running" assert.  Instead the
  -- overworld-update poll below delivers on the first QUIET frame --
  -- the drops follow whatever dialog or script is in flight, because
  -- queueScript refuses while the runner is busy and the poll only
  -- runs when the overworld itself is the active screen.
  mod.exports.settlePending = function()
    if pending then settleDrops() end
  end
  mod.events:on("map.entered", function() if pending then settleDrops() end end)


  -- --------------------------------------------------- crafting helpers

  -- ============== overworld bosses & the summoning altar ==============
  -- One per gym town (and a few road legends): hourly, uncatchable,
  -- and they pay in RARE CANDY plus typed LEGENDARY SHARDs.  Eight
  -- shards fuse into a tablet at the altar; a full mono-type party of
  -- six summons the empowered version -- and THAT one can be caught.
  -- (One namespace table: the entry chunk flirts with LuaJIT's
  -- 200-local ceiling.)
  local Boss = {
    LIST = {
      { key = "pewter", species = "GOLEM", level = 25, type = "ROCK",
        map = "PEWTER_CITY", x = 26, y = 27 },
      { key = "cerulean", species = "BLASTOISE", level = 30,
        type = "WATER", map = "CERULEAN_CITY", x = 13, y = 8 },
      { key = "route5", species = "MACHAMP", level = 35,
        type = "FIGHTING", map = "ROUTE_5", x = 4, y = 35 },
      { key = "vermilion", species = "RAICHU", level = 35,
        type = "ELECTRIC", map = "VERMILION_CITY", x = 29, y = 7 },
      { key = "route11", species = "SNORLAX", level = 40,
        type = "NORMAL", map = "ROUTE_11", x = 51, y = 14 },
      { key = "lavender", species = "GENGAR", level = 40,
        type = "GHOST", map = "LAVENDER_TOWN", x = 0, y = 2 },
      { key = "celadon", species = "VENUSAUR", level = 40,
        type = "GRASS", map = "CELADON_CITY", x = 9, y = 3 },
      { key = "saffron", species = "ALAKAZAM", level = 45,
        type = "PSYCHIC_TYPE", map = "SAFFRON_CITY", x = 17, y = 3 },
      { key = "fuchsia", species = "MUK", level = 40, type = "POISON",
        map = "FUCHSIA_CITY", x = 27, y = 21 },
      { key = "route21", species = "CHARIZARD", level = 45,
        type = "FIRE", map = "ROUTE_21", x = 11, y = 88 },
      { key = "viridian", species = "RHYDON", level = 50,
        type = "GROUND", map = "VIRIDIAN_CITY", x = 5, y = 29 },
      { key = "route23", species = "DRAGONITE", level = 55,
        type = "DRAGON", map = "ROUTE_23", x = 8, y = 6 },
    },
    npcIds = {},
  }

  function Boss.suffix(t)
    return t == "PSYCHIC_TYPE" and "PSYCHIC" or t
  end
  function Boss.shardId(t) return "SHARD_" .. Boss.suffix(t) end
  function Boss.tabletId(t) return "TABLET_" .. Boss.suffix(t) end
  function Boss.forMap(mapId)
    for _, b in ipairs(Boss.LIST) do
      if b.map == mapId then return b end
    end
    return nil
  end
  function Boss.byKey(key)
    for _, b in ipairs(Boss.LIST) do
      if b.key == key then return b end
    end
    return nil
  end
  function Boss.due(b)
    local down = mod.save:get("boss_down_" .. b.key)
    if not down then return true end
    if not theGame then return false end
    return ((theGame.save.playTime or 0) - down) >= BALANCE.bossSeconds
  end
  function Boss.spawn(b)
    if not mod.world or Boss.npcIds[b.key] then return end
    if not mod.content.maps:get(b.map) then return end
    if not Boss.due(b) then return end
    local id = mod.world:spawnNpc(b.map, {
      x = b.x, y = b.y,
      sprite = mod.exports.palSpriteFor(b.species),
      movement = "STAY", range = "NONE",
      text = "TEXT_PALCRAFT_BOSS",
    })
    if type(id) == "string" then Boss.npcIds[b.key] = id end
  end
  function Boss.resync()
    for key, id in pairs(Boss.npcIds) do
      if mod.world then mod.world:removeNpc(id) end
      Boss.npcIds[key] = nil
    end
    for _, b in ipairs(Boss.LIST) do Boss.spawn(b) end
  end
  mod.exports.bosses = Boss.LIST
  mod.exports.respawnBosses = function() Boss.resync() end
  mod.exports.bossFor = Boss.forMap
  mod.exports.shardIdFor = Boss.shardId
  mod.exports.tabletIdFor = Boss.tabletId

  do
    local shardShorts = { ROCK = "ROCK", WATER = "WATER",
      FIGHTING = "FIGHT", ELECTRIC = "ELEC", NORMAL = "NORMAL",
      GHOST = "GHOST", GRASS = "GRASS", PSYCHIC_TYPE = "PSY",
      POISON = "POISON", FIRE = "FIRE", GROUND = "GROUND",
      DRAGON = "DRAGON" }
    local tabShorts = { ROCK = "RCK", WATER = "WTR", FIGHTING = "FGT",
      ELECTRIC = "ELC", NORMAL = "NRM", GHOST = "GHT", GRASS = "GRS",
      PSYCHIC_TYPE = "PSY", POISON = "PSN", FIRE = "FIR",
      GROUND = "GRD", DRAGON = "DRG" }
    for t, s in pairs(shardShorts) do
      mod.content.items:register(Boss.shardId(t), {
        id = Boss.shardId(t), name = s .. " SHARD", price = 300,
        tossable = true,
      })
      mod.content.items:register(Boss.tabletId(t), {
        id = Boss.tabletId(t), name = tabShorts[t] .. " TABLET",
        price = 5000, tossable = false,
      })
    end
    for _, b in ipairs(Boss.LIST) do
      if mod.content.maps:get(b.map) then
        mod.content.map_scripts:register(b.map, {
          talk = {
            TEXT_PALCRAFT_BOSS = {
              { "face_player" },
              { "palcraft_boss" },
            },
          },
        })
      end
    end
  end

  mod.events:on("save.loaded", Boss.resync)
  mod.events:on("save.created", Boss.resync)

  -- present the moment you arrive, and back on the hour if you wait
  -- around (spawn() itself guards against duplicates and cooldowns)
  mod.events:on("map.entered", function(ev)
    local b = ev.mapId and Boss.forMap(ev.mapId)
    if b and not Boss.npcIds[b.key] then Boss.spawn(b) end
  end)
  mod.events:on("world.stepped", function(ev)
    local b = ev.mapId and Boss.forMap(ev.mapId)
    if b and not Boss.npcIds[b.key] then Boss.spawn(b) end
  end)

  mod.commands:register("palcraft_boss", function(ctx)
    local game, ow = ctx.game, ctx.overworld
    local b = ow and ow.map and Boss.forMap(ow.map.id)
    if not b then return end
    local def = game.data.pokemon[b.species]
    local name = (def and def.name) or b.species
    game.stack:push(mod.ui.TextBox.new(game,
      ("%s looms here,\nradiating power!\n(Lv.%d)\fChallenge it?")
        :format(name, b.level),
      function()
        game.stack:push(mod.ui.ChoiceBox.new(game, function(yes)
          if not yes then return end
          mod.save:set("boss_fight", b.key)
          mod.world:queueScript({
            { "start_battle", "wild", b.species, b.level },
          })
        end))
      end))
  end)

  -- street bosses bat every ball aside; the altar's summons don't
  -- no cheap outs: a boss that SELFDESTRUCTs hands over the bounty
  -- for free.  Swap banned moves for the best non-banned learnset move
  -- the mon could know at its level (TACKLE as the floor).
  mod.exports.scrubBossMoves = function(mon, def, movesData)
    if not (mon and mon.moves) then return 0 end
    local banned = { SELFDESTRUCT = true, EXPLOSION = true }
    local known = {}
    for _, mv in ipairs(mon.moves) do known[mv.id] = true end
    local pool = {}
    for _, id in ipairs((def and def.level1Moves) or {}) do
      pool[#pool + 1] = id
    end
    for _, e in ipairs((def and def.learnset) or {}) do
      if e.level <= (mon.level or 1) then pool[#pool + 1] = e.move end
    end
    local swapped = 0
    for _, mv in ipairs(mon.moves) do
      if banned[mv.id] then
        -- prefer a DAMAGING unknown candidate (a boss left with only
        -- stat moves turns into an unkillable turtle): at/below level
        -- first, then the lowest above-level learnset move; then any
        -- unknown move; TACKLE only for degenerate dexes.  Strictly
        -- in-place id/pp swaps -- the battle engine holds references
        -- into these slot tables.
        local pick
        local function damaging(id)
          local mdef2 = movesData and movesData[id]
          return (mdef2 and (mdef2.power or 0) > 0) or false
        end
        for pass = 1, 2 do
          local want = pass == 1
          for i = #pool, 1, -1 do
            if not banned[pool[i]] and not known[pool[i]]
               and damaging(pool[i]) == want then
              pick = pool[i]
              break
            end
          end
          if pick then break end
          for _, e in ipairs((def and def.learnset) or {}) do
            if e.level > (mon.level or 1) and not banned[e.move]
               and not known[e.move] and damaging(e.move) == want then
              pick = e.move
              break
            end
          end
          if pick then break end
        end
        pick = pick or "TACKLE"
        known[pick] = true
        mv.id = pick
        local mdef = movesData and movesData[pick]
        if mdef and mdef.pp then mv.pp = mdef.pp end
        swapped = swapped + 1
      end
    end
    return swapped
  end
  mod.events:on("battle.started", function(ev)
    if not (mod.save:get("boss_fight") or mod.save:get("summon_fight")) then
      return
    end
    local mon = ev.battle and ev.battle.enemy and ev.battle.enemy.mon
    if not mon or not theGame then return end
    mod.exports.scrubBossMoves(mon, theGame.data.pokemon[mon.species],
                               theGame.data.moves)
  end)

  mod.hooks:wrap("catch.rate", function(next, ball, mon, def, opts)
    if mod.save:get("boss_fight") then
      return false, 0
    end
    local caught, shakes = next(ball, mon, def, opts)
    if caught and mon then
      -- a fresh catch lands weakened at star 0 -- the condenser (or
      -- the incubator's star-1 hatchlings) is the road back up
      mod.exports.setStars(mon, def, 0)
    end
    return caught, shakes
  end)

  mod.events:on("battle.ended", function(ev)
    local key = mod.save:get("boss_fight")
    if key then
      mod.save:set("boss_fight", nil)
      local b = Boss.byKey(key)
      if b and ev.result == "win" then
        mod.save:set("boss_down_" .. b.key,
          (theGame and theGame.save.playTime) or 0)
        -- remove the LIVE npc: map reloads rebuild the list, so the
        -- stored id can be stale -- find it by cell and text
        local removed = false
        local ow = theGame and theGame.overworld
        if ow and ow.map and ow.map.id == b.map and mod.world then
          for _, npc in ipairs(ow.npcs or {}) do
            if npc.cellX == b.x and npc.cellY == b.y and npc.def
               and npc.def.text == "TEXT_PALCRAFT_BOSS" then
              mod.world:removeNpc(npc.id)
              removed = true
            end
          end
        end
        if not removed and Boss.npcIds[b.key] and mod.world then
          mod.world:removeNpc(Boss.npcIds[b.key])
        end
        Boss.npcIds[b.key] = nil
        pending = pending or {}
        pending.RARE_CANDY = (pending.RARE_CANDY or 0) + 1
        local sh = Boss.shardId(b.type)
        pending[sh] = (pending[sh] or 0) + 1
      end
      return
    end
    if mod.save:get("summon_fight") then
      -- the tablet burned at summon time; win, catch or lose, the
      -- audience is over
      mod.save:set("summon_fight", nil)
    end
  end)

  -- fuse and summon logic, exported so the tests can drive it headless
  mod.exports.fuseTablet = function(game, typeKey)
    local inv = game.save.inventory
    local sh = Boss.shardId(typeKey)
    if (inv[sh] or 0) < BALANCE.shardsPerTablet then
      return false, ("It takes %d shards\nof one type!")
        :format(BALANCE.shardsPerTablet)
    end
    local left = inv[sh] - BALANCE.shardsPerTablet
    inv[sh] = left > 0 and left or nil
    local tab = Boss.tabletId(typeKey)
    inv[tab] = (inv[tab] or 0) + 1
    return true, tab
  end

  mod.exports.canSummon = function(game, typeKey)
    local party = game.save.party or {}
    if #party ~= 6 then
      return false, "The altar demands\na full party of six!"
    end
    for _, mon in ipairs(party) do
      local pdef = game.data.pokemon[mon.species]
      local match = false
      for _, t in ipairs(pdef and pdef.types or {}) do
        if t == typeKey then match = true end
      end
      if not match then
        return false, "All six must share\nthe tablet's type!"
      end
    end
    for _, b in ipairs(Boss.LIST) do
      if b.type == typeKey then return true, b end
    end
    return false, "No legend answers\nthat tablet!"
  end

  local function bagCount(save, id) return save.inventory[id] or 0 end

  -- materials can come from the bag AND the base chest (bag first);
  -- outputs still land bag-side, so only COST math uses this
  mod.exports.craftCount = function(save, id)
    local n = save.inventory[id] or 0
    local chest = mod.save:get("chest")
    if chest and chest.placed and chest.items then
      n = n + (chest.items[id] or 0)
    end
    return n
  end

  local function bagCapacity(game)
    local c = game.data.constants and game.data.constants.bagSize
    if type(c) == "number" and c >= 1 then return math.floor(c) end
    return 20
  end

  local function bagSlots(save)
    local n = 0
    for id in pairs(save.inventory) do
      if not id:find("BADGE", 1, true) then n = n + 1 end
    end
    return n
  end

  local function maxCraftable(game, recipe)
    local save = game.save
    local n = 99 - bagCount(save, recipe.ball)   -- one order tops at 99
    for _, c in ipairs(recipe.cost) do
      n = math.min(n,
        math.floor(mod.exports.craftCount(save, c[1]) / c[2]))
    end
    -- a ball the bag doesn't hold yet needs a free slot
    if n > 0 and bagCount(save, recipe.ball) == 0
        and bagSlots(save) >= bagCapacity(game) then
      n = 0
    end
    return math.max(0, n)
  end

  -- Direct inventory writes are the save-editor path the engine defends
  -- (Bag.order rebuilds itself around them); zero-count ids must leave the
  -- table or they'd hold a bag slot forever.
  -- the bag pays first; the base chest covers the remainder
  local function payCost(game, recipe, qty)
    local inv = game.save.inventory
    local chest = mod.save:get("chest")
    for _, c in ipairs(recipe.cost) do
      local need = c[2] * qty
      local fromBag = math.min(inv[c[1]] or 0, need)
      local left = (inv[c[1]] or 0) - fromBag
      inv[c[1]] = left > 0 and left or nil
      need = need - fromBag
      if need > 0 and chest and chest.items then
        local ch = (chest.items[c[1]] or 0) - need
        chest.items[c[1]] = ch > 0 and ch or nil
      end
    end
    if chest then mod.save:set("chest", chest) end
  end

  -- Crafting is a WORK QUEUE now, Palworld style: an order consumes its
  -- materials up front, then completes over play-time (the vines'
  -- clock), sped up by the best HANDIWORK level in the base crew.
  local function workFor(recipe)
    local base = recipe.work or 15
    return BALANCE.craftSecondsOverride
      or (BALANCE.fast and base / 10 or base)
  end

  local function bestCrewLevel(job, pals)
    pals = pals or mod.save:get("base_pals", {})
    local best, overseer = 0, 0
    for _, mon in ipairs(pals) do
      -- shrine offerings raise an individual's craft (cap 4, like
      -- MEWTWO's mastery)
      local boost = mon.soulBoost or 0
      for _, s in ipairs(workSuitabilities(mon.species)) do
        local lvl = math.min(WORK_LEVEL_MAX, s.level + boost)
        if s.job == job and lvl > best then best = lvl end
        if s.job == "OVERSEER" and lvl > overseer then overseer = lvl end
      end
    end
    -- the wildcard: a DRAGON (or DITTO, or MEW) covers any job the
    -- crew is missing outright
    if best == 0 and job ~= "OVERSEER" then best = overseer end
    return best
  end

  -- like bestCrewLevel, but also reports WHO -- the screens call the
  -- helper out by name
  mod.exports.bestCrewWorker = function(job, pals)
    pals = pals or mod.save:get("base_pals", {})
    local best, who = 0, nil
    for _, mon in ipairs(pals) do
      local boost = mon.soulBoost or 0
      for _, s in ipairs(workSuitabilities(mon.species)) do
        local lvl = math.min(WORK_LEVEL_MAX, s.level + boost)
        if s.job == job and lvl > best then best, who = lvl, mon end
      end
    end
    return best, who
  end

  -- speed = 1 + level/2: a Lv1 helper is 1.5x, a Lv3 master 2.5x;
  -- a placed GENERATOR adds the best GENERATING level the same way
  local function craftSpeed(game, pals)
    local speed = 1 + bestCrewLevel("HANDIWORK", pals) / 2
    local gen = mod.save:get("generator")
    if gen and gen.placed then
      speed = speed + bestCrewLevel("GENERATING", pals) / 2
    end
    return speed
  end

  -- how many a recipe's materials alone would allow, ignoring bag
  -- room -- so the screens can tell BAG FULL apart from NEED MATERIALS
  mod.exports.materialsMax = function(game, recipe)
    local n = 99
    for _, c in ipairs(recipe.cost) do
      n = math.min(n,
        math.floor(mod.exports.craftCount(game.save, c[1]) / c[2]))
    end
    return math.max(0, n)
  end

  local function queueCraft(game, recipe, qty)
    payCost(game, recipe, qty)
    local q = mod.save:get("craftq", {})
    q[#q + 1] = { item = recipe.ball, label = recipe.label,
                  count = qty, each = workFor(recipe),
                  left = workFor(recipe) }
    mod.save:set("craftq", q)
  end

  -- lazy clock, one unit at a time; finished goods pile in craftdone
  -- until a visit to any craft table collects them
  local function tickCraft(game)
    local now = game.save.playTime or 0
    local last = mod.save:get("craft_last")
    mod.save:set("craft_last", now)
    local q = mod.save:get("craftq", {})
    if #q == 0 or not last then return end
    local budget = math.max(0, now - last) * craftSpeed(game)
    local done = mod.save:get("craftdone", {})
    local finished = 0
    while budget > 0 and q[1] do
      local o = q[1]
      if budget >= o.left then
        budget = budget - o.left
        done[o.item] = (done[o.item] or 0) + 1
        finished = finished + 1
        o.count = o.count - 1
        if o.count <= 0 then table.remove(q, 1) else o.left = o.each end
      else
        o.left = o.left - budget
        budget = 0
      end
    end
    mod.save:set("craftq", q)
    mod.save:set("craftdone", done)
    if finished > 0 then
      -- the workshop chimes when an order comes off the queue
      pcall(function()
        require("src.core.Sound").play(game.data, "Get_Item1")
      end)
    end
  end

  -- goods move to the bag when there's room; the rest keep waiting
  local function collectCraft(game)
    local done = mod.save:get("craftdone", {})
    local inv = game.save.inventory
    local got, waiting = {}, false
    for id, n in pairs(done) do
      if (inv[id] or 0) > 0 or bagSlots(game.save) < bagCapacity(game) then
        inv[id] = (inv[id] or 0) + n
        got[#got + 1] = { id = id, count = n }
        done[id] = nil
      else
        waiting = true
      end
    end
    mod.save:set("craftdone", done)
    return got, waiting
  end

  mod.events:on("world.stepped", function()
    if theGame then tickCraft(theGame) end
  end)

  -- what other mods may read (treat as read-only) and the tests exercise
  mod.exports.recipes = RECIPES
  mod.exports.maxCraftable = maxCraftable
  mod.exports.queueCraft = queueCraft
  mod.exports.tickCraft = tickCraft
  mod.exports.collectCraft = collectCraft
  mod.exports.craftSpeed = craftSpeed
  mod.exports.bestCrewLevel = bestCrewLevel
  mod.exports.stationRecipes = STATION_RECIPES
  mod.exports.mk2Recipes = MK2_RECIPES

  -- ------------------------------------------- the power grid (phase 2)

  for _, s in ipairs({
    { "SPRITE_GENERATOR", "assets/generator.png" },
    { "SPRITE_FURNACE", "assets/furnace.png" },
    { "SPRITE_MED_BENCH", "assets/med_bench.png" },
    { "SPRITE_TRAIN_DUMMY", "assets/train_dummy.png" },
    { "SPRITE_RESEARCH_DESK", "assets/research_desk.png" },
    { "SPRITE_SHRINE", "assets/shrine.png" },
    { "SPRITE_LUMBER_PILE", "assets/lumber_pile.png" },
    { "SPRITE_MINING_ROCK", "assets/mining_rock.png" },
    { "SPRITE_SUMMON_ALTAR", "assets/summon_altar.png" },
  }) do
    mod.content.sprites:register(s[1], {
      id = s[1], image = mod.assets:path(s[2]),
      frames = 1, walker = false,
    })
  end

  local STATIONS = {
    generator = { sprite = "SPRITE_GENERATOR",
                  text = "TEXT_PALCRAFT_GENERATOR", item = "GENERATOR" },
    furnace = { sprite = "SPRITE_FURNACE",
                text = "TEXT_PALCRAFT_FURNACE", item = "FURNACE" },
    medbench = { sprite = "SPRITE_MED_BENCH",
                 text = "TEXT_PALCRAFT_MEDBENCH", item = "MED_BENCH" },
    dummy = { sprite = "SPRITE_TRAIN_DUMMY",
              text = "TEXT_PALCRAFT_DUMMY", item = "TRAIN_DUMMY" },
    desk = { sprite = "SPRITE_RESEARCH_DESK",
             text = "TEXT_PALCRAFT_DESK", item = "RESEARCH_DESK" },
    shrine = { sprite = "SPRITE_SHRINE",
               text = "TEXT_PALCRAFT_SHRINE", item = "SHRINE" },
    altar = { sprite = "SPRITE_SUMMON_ALTAR",
              text = "TEXT_PALCRAFT_ALTAR", item = "SUMMON_ALTAR" },
    lumber = { sprite = "SPRITE_LUMBER_PILE",
               text = "TEXT_PALCRAFT_LUMBER", item = "LUMBER_PILE" },
    mine = { sprite = "SPRITE_MINING_ROCK",
             text = "TEXT_PALCRAFT_MINE", item = "MINING_ROCK" },
    condenser = { sprite = "SPRITE_CONDENSER",
                  text = "TEXT_PALCRAFT_CONDENSER", item = "CONDENSER" },
  }
  local stationNpcs = {}   -- key -> npc id, this session

  local function spawnStations()
    if not mod.world then return end
    for key, def in pairs(STATIONS) do
      local st = mod.save:get(key)
      if st and st.placed and not stationNpcs[key] then
        local id = mod.world:spawnNpc(BASE_MAP, {
          x = st.x, y = st.y, sprite = def.sprite,
          movement = "STAY", range = "NONE", text = def.text,
        })
        if type(id) == "string" then stationNpcs[key] = id end
      end
    end
  end
  local function resyncStations()
    for key, id in pairs(stationNpcs) do
      if mod.world then mod.world:removeNpc(id) end
      stationNpcs[key] = nil
    end
    spawnStations()
  end
  mod.events:on("save.loaded", resyncStations)
  mod.events:on("save.created", resyncStations)

  -- the base is POWERED when a generator stands in it and an ELECTRIC
  -- type is on the crew: that upgrades base craft tables to MK2
  local function basePowered(game, pals)
    local gen = mod.save:get("generator")
    if not (gen and gen.placed) then return false end
    return bestCrewLevel("GENERATING", pals) > 0
  end

  -- the moment the grid first comes alive, say what it unlocked --
  -- covers both orders: generator placed then electrician assigned,
  -- or the crew already waiting when the generator lands
  mod.events:on("world.stepped", function()
    if not theGame or mod.save:get("told_mk2") then return end
    if not basePowered(theGame) then return end
    if theGame.stack:top() ~= theGame.overworld then return end
    mod.save:set("told_mk2", true)
    theGame.stack:push(mod.ui.TextBox.new(theGame,
      "The GENERATOR hums\nto life!\fMK2 recipes are\nlive at the CRAFT\nTABLE."))
  end)

  local function stationPlaceEffect(key, label, readyText)
    return {
      field = true, battle = false,
      use = function(data, save, itemId, target, battle, moveIndex, ow)
        if not ow or not ow.map or ow.map.id ~= BASE_MAP then
          return "failed", { "The " .. label .. "\nbelongs in your base!" }
        end
        local st = mod.save:get(key)
        if st and st.placed then
          return "failed", { "The base already\nhas a " .. label .. "!" }
        end
        local x, y = facedCell(ow)
        local blocked = not (ow.map:inBounds(x, y)
                             and ow.map:isWalkableCell(x, y))
        if not blocked then
          for _, npc in ipairs(ow.npcs or {}) do
            if npc.cellX == x and npc.cellY == y then
              blocked = true
              break
            end
          end
        end
        if blocked then
          return "failed", { "No room to set\nit up there!" }
        end
        mod.save:set(key, { placed = true, x = x, y = y })
        spawnStations()
        return "consumed",
          { type(readyText) == "function" and readyText() or readyText }
      end,
    }
  end
  mod.content.sprites:register("SPRITE_CONDENSER", {
    id = "SPRITE_CONDENSER",
    image = mod.assets:path("assets/condenser.png"),
    frames = 1, walker = false,
  })
  mod.content.item_effects:register("CONDENSER_EFFECT",
    stationPlaceEffect("condenser", "CONDENSER",
                       "The CONDENSER\ngurgles, ready!"))
  mod.content.item_effects:register("GENERATOR_EFFECT",
    stationPlaceEffect("generator", "GENERATOR", function()
      if bestCrewLevel("GENERATING") > 0 then
        mod.save:set("told_mk2", true)
        return "The GENERATOR hums\nto life!\fMK2 recipes are\nlive at the CRAFT\nTABLE."
      end
      return "The GENERATOR\nis bolted down!\fIt needs a\nGENERATING POKéMON\nto come alive."
    end))
  mod.content.item_effects:register("FURNACE_EFFECT",
    stationPlaceEffect("furnace", "FURNACE",
                       "The FURNACE is\nbricked in!"))
  mod.content.item_effects:register("MED_BENCH_EFFECT",
    stationPlaceEffect("medbench", "MED.BENCH",
                       "The MEDICINE\nBENCH is set!"))
  mod.content.item_effects:register("TRAIN_DUMMY_EFFECT",
    stationPlaceEffect("dummy", "TRN.DUMMY",
                       "The TRAINING\nDUMMY is staked!"))
  mod.content.item_effects:register("RESEARCH_DESK_EFFECT",
    stationPlaceEffect("desk", "RSCH.DESK",
                       "The RESEARCH\nDESK is set up!"))
  mod.content.item_effects:register("SHRINE_EFFECT",
    stationPlaceEffect("shrine", "SHRINE",
                       "The SHRINE is\nconsecrated!"))
  mod.content.item_effects:register("LUMBER_PILE_EFFECT",
    stationPlaceEffect("lumber", "WOODPILE",
                       "The WOODPILE is\nstacked!"))
  mod.content.item_effects:register("MINING_ROCK_EFFECT",
    stationPlaceEffect("mine", "ORE ROCK",
                       "The ORE ROCK is\nhauled in!"))
  mod.content.item_effects:register("SUMMON_ALTAR_EFFECT",
    stationPlaceEffect("altar", "ALTAR",
                       "The ALTAR hums\nwith old power!"))
  mod.content.item_effects:register("EXPANSION_KIT_EFFECT", {
    field = true, battle = false,
    use = function(data, save, itemId, target, battle, moveIndex, ow)
      if not ow or not ow.map or ow.map.id ~= BASE_MAP then
        return "failed", { "Unroll the plans\ninside the base!" }
      end
      if (mod.save:get("base_level") or 1) >= 2 then
        return "failed", { "The base is fully\nexpanded already!" }
      end
      mod.save:set("base_level", 2)
      if applyBaseWing then applyBaseWing(2, ow) end
      return "consumed", { "The east wing\nopens up!" }
    end,
  })

  -- SELECT in the overworld pitches the SECRET BASE wherever you
  -- stand facing, as long as the kit is in the bag and no base is up
  -- (engine_internals: the overworld has no registered-item slot)
  do
  local OverworldState = require("src.world.OverworldController")
  if not OverworldState.__palcraft_select then
    OverworldState.__palcraft_select = true
    local origUpdate = OverworldState.update
    -- dev spot marker (PALCRAFT_MARK=1): stand on the cell, tap M,
    -- and the spot lands in palcraft_spots.txt in the save directory
    local marking = os.getenv("PALCRAFT_MARK") == "1"
    local markHeld = false
    OverworldState.update = function(self, dt)
      origUpdate(self, dt)
      local game = theGame
      if not game or game.stack:top() ~= self then return end
      -- pending battle drops follow the dialog: deliver on the first
      -- frame the overworld is quiet (see the drops section)
      if mod.exports.settlePending then mod.exports.settlePending() end
      if marking and love.keyboard then
        local down = love.keyboard.isDown("m")
        if down and not markHeld then
          local line = ("%s\t%d\t%d\n"):format(
            self.map and self.map.id or "?",
            self.player and self.player.cellX or -1,
            self.player and self.player.cellY or -1)
          pcall(love.filesystem.append, "palcraft_spots.txt", line)
          game.stack:push(mod.ui.TextBox.new(game,
            ("Marked %s\n(%d, %d)"):format(
              self.map and self.map.id or "?",
              self.player and self.player.cellX or -1,
              self.player and self.player.cellY or -1)))
        end
        markHeld = down
      end
      if not game.input:wasPressed("select") then return end
      local inv = game.save and game.save.inventory
      if not inv then return end
      local b = mod.save:get("base")
      if b then
        -- a base is down: offer to pack it back up
        if not self.map or self.map.id ~= b.map then
          game.stack:push(mod.ui.TextBox.new(game,
            ("The SECRET BASE\nis pitched on\n%s."):format(b.map)))
          return
        end
        game.stack:push(mod.ui.TextBox.new(game,
          "Pack the SECRET\nBASE back up?", function()
          game.stack:push(mod.ui.ChoiceBox.new(game, function(yes)
            if not yes then return end
            if mod.exports.packBase(game, self) then
              game.stack:push(mod.ui.TextBox.new(game,
                "Packed up! The\nkit is back in\nthe bag."))
            end
          end))
        end))
        return
      end
      if (inv.SECRET_BASE or 0) < 1 then return end
      local ItemEffects = require("src.inventory.ItemEffects")
      local verb, texts = ItemEffects.use(game.data, game.save,
        "SECRET_BASE", nil, false, nil, self)
      if verb == "consumed" then
        inv.SECRET_BASE = (inv.SECRET_BASE or 0) > 1
          and inv.SECRET_BASE - 1 or nil
      end
      if texts and texts[1] then
        game.stack:push(mod.ui.TextBox.new(game,
          table.concat(texts, "\f")))
      end
    end
  end
  end

  -- station outputs ride to the chest when a hauler is on the crew
  local function haulToChest(item, n)
    local chest = mod.save:get("chest")
    if not (chest and chest.placed) then return false end
    if bestCrewLevel("TRANSPORT") < 1 then return false end
    chest.items = chest.items or {}
    chest.items[item] = (chest.items[item] or 0) + n
    mod.save:set("chest", chest)
    return true
  end

  -- ------- the smelter: ORE -> INGOT while a KINDLING type stokes it

  local SMELT_SECONDS = BALANCE.smeltSeconds

  local function queueSmelt(game, qty)
    local inv = game.save.inventory
    local n = math.min(qty or 0, mod.exports.craftCount(game.save, "ORE"))
    if n < 1 then return 0 end
    local fromBag = math.min(inv.ORE or 0, n)
    local left = (inv.ORE or 0) - fromBag
    inv.ORE = left > 0 and left or nil
    local rest = n - fromBag
    if rest > 0 then
      local chest = mod.save:get("chest")
      if chest and chest.items then
        local ch = (chest.items.ORE or 0) - rest
        chest.items.ORE = ch > 0 and ch or nil
        mod.save:set("chest", chest)
      end
    end
    local sq = mod.save:get("smeltq") or { count = 0 }
    if (sq.count or 0) <= 0 then sq.left = SMELT_SECONDS end
    sq.count = (sq.count or 0) + n
    mod.save:set("smeltq", sq)
    return n
  end

  -- the same lazy clock as the craft queue, but the fire pauses cold:
  -- no KINDLING POKéMON on the crew, no progress at all
  local function tickSmelt(game, pals)
    local now = game.save.playTime or 0
    local last = mod.save:get("smelt_last")
    mod.save:set("smelt_last", now)
    local sq = mod.save:get("smeltq")
    if not sq or (sq.count or 0) <= 0 or not last then return end
    local lvl = bestCrewLevel("KINDLING", pals)
    if lvl < 1 then return end
    local budget = math.max(0, now - last) * (1 + (lvl - 1) / 2)
    local done = mod.save:get("smeltdone") or 0
    while budget > 0 and sq.count > 0 do
      if budget >= sq.left then
        budget = budget - sq.left
        sq.count = sq.count - 1
        sq.left = SMELT_SECONDS
        if haulToChest("INGOT", 1) then
          -- the flier carried it over; nothing waits at the furnace
        else
          done = done + 1
        end
      else
        sq.left = sq.left - budget
        budget = 0
      end
    end
    mod.save:set("smeltq", sq)
    mod.save:set("smeltdone", done)
  end

  local function collectSmelt(game)
    local done = mod.save:get("smeltdone") or 0
    if done < 1 then return 0 end
    local inv = game.save.inventory
    if not ((inv.INGOT or 0) > 0
            or bagSlots(game.save) < bagCapacity(game)) then
      return 0
    end
    inv.INGOT = (inv.INGOT or 0) + done
    mod.save:set("smeltdone", 0)
    return done
  end

  mod.events:on("world.stepped", function()
    if theGame then tickSmelt(theGame) end
  end)

  mod.exports.basePowered = basePowered
  mod.exports.queueSmelt = queueSmelt
  mod.exports.tickSmelt = tickSmelt
  mod.exports.collectSmelt = collectSmelt

  local function stationText(game, text)
    game.stack:push(mod.ui.TextBox.new(game, text))
  end

  local function packStation(game, key, label)
    local sq = mod.save:get("smeltq")
    if key == "furnace" and sq and (sq.count or 0) > 0 then
      stationText(game, "The FURNACE is\nstill working!")
      return
    end
    if key == "medbench" and #(mod.save:get("brewq", {})) > 0 then
      stationText(game, "The BENCH is\nmid-brew!")
      return
    end
    local inv = game.save.inventory
    local item = STATIONS[key].item
    if not ((inv[item] or 0) > 0
            or bagSlots(game.save) < bagCapacity(game)) then
      stationText(game, "No room in the\nbag for it!")
      return
    end
    mod.save:set(key, nil)
    if stationNpcs[key] and mod.world then
      mod.world:removeNpc(stationNpcs[key])
      stationNpcs[key] = nil
    end
    inv[item] = (inv[item] or 0) + 1
    stationText(game, "Packed up the\n" .. label .. ".")
  end

  mod.commands:register("palcraft_generator", function(ctx)
    local game = ctx.game
    local powered = bestCrewLevel("GENERATING") > 0
    game.stack:push(mod.ui.TextBox.new(game, powered
      and "The GENERATOR\nhums with power!"
      or "It sits dark. It\nneeds an ELECTRIC\nPOKéMON on the\ncrew!",
      function()
        game.stack:push(mod.ui.Menu.new(game, {
          { label = "PACK UP", onSelect = function()
              packStation(game, "generator", "GENERATOR")
            end },
          { label = "CANCEL", onSelect = function() end },
        }, { tx = 8, ty = 8 }))
      end))
  end)

  -- ------- the medicine bench: farm goods -> remedies, tier-gated

  local function brewWork(recipe)
    local base = recipe.work or 30
    return BALANCE.medSecondsOverride
      or (BALANCE.fast and base / 10 or base)
  end

  local function queueBrew(game, recipe, qty)
    payCost(game, recipe, qty)
    local q = mod.save:get("brewq", {})
    q[#q + 1] = { item = recipe.ball, label = recipe.label,
                  count = qty, each = brewWork(recipe),
                  left = brewWork(recipe) }
    mod.save:set("brewq", q)
  end

  -- pauses cold without a MEDICINE type, like the furnace's fire
  local function tickBrew(game, pals)
    local now = game.save.playTime or 0
    local last = mod.save:get("brew_last")
    mod.save:set("brew_last", now)
    local q = mod.save:get("brewq", {})
    if #q == 0 or not last then return end
    local lvl = bestCrewLevel("MEDICINE", pals)
    if lvl < 1 then return end
    local budget = math.max(0, now - last) * (1 + (lvl - 1) / 2)
    local done = mod.save:get("brewdone", {})
    while budget > 0 and q[1] do
      local o = q[1]
      if budget >= o.left then
        budget = budget - o.left
        if not haulToChest(o.item, 1) then
          done[o.item] = (done[o.item] or 0) + 1
        end
        o.count = o.count - 1
        if o.count <= 0 then table.remove(q, 1) else o.left = o.each end
      else
        o.left = o.left - budget
        budget = 0
      end
    end
    mod.save:set("brewq", q)
    mod.save:set("brewdone", done)
  end

  local function collectBrew(game)
    local done = mod.save:get("brewdone", {})
    local inv = game.save.inventory
    local got, waiting = {}, false
    for id, n in pairs(done) do
      if (inv[id] or 0) > 0 or bagSlots(game.save) < bagCapacity(game) then
        inv[id] = (inv[id] or 0) + n
        got[#got + 1] = { id = id, count = n }
        done[id] = nil
      else
        waiting = true
      end
    end
    mod.save:set("brewdone", done)
    return got, waiting
  end

  mod.exports.brewRecipes = BREW_RECIPES
  mod.exports.queueBrew = queueBrew
  mod.exports.tickBrew = tickBrew
  mod.exports.collectBrew = collectBrew

  -- the brew screen: the craft screen's shape with tier locks
  local MED_SCREEN = "PalworldMedBench"
  mod.content.screens:register(MED_SCREEN, {
    new = function(game)
      local Font, Theme = mod.ui.Font, mod.ui.Theme
      local self = { game = game, isOpaque = true, index = 1, top = 0,
                     recipes = BREW_RECIPES, isMedBenchScreen = true }
      tickBrew(game)
      local got, waiting = collectBrew(game)
      if got[1] then
        local def = mod.content.items:get(got[1].id)
        self.message = ("GOT %s x%d!"):format(
          def and def.name or got[1].id, got[1].count)
      elseif waiting then
        self.message = "BAG FULL!"
      end

      function self:update(dt)
        tickBrew(game)
        local input = game.input
        if input:wasPressed("b") then
          collectBrew(game)
          game.stack:pop()
        elseif input:wasPressed("up") then
          self.index = self.index > 1 and self.index - 1
                       or #BREW_RECIPES
          self.message = nil
        elseif input:wasPressed("down") then
          self.index = self.index < #BREW_RECIPES and self.index + 1
                       or 1
          self.message = nil
        elseif input:wasPressed("a") then
          local recipe = BREW_RECIPES[self.index]
          local lvl = bestCrewLevel("MEDICINE")
          if lvl < recipe.tier then
            self.message = ("NEEDS MEDICINE Lv.%d!"):format(recipe.tier)
          else
            local max = maxCraftable(game, recipe)
            if max < 1 then
              self.message = mod.exports.materialsMax(game, recipe) > 0
                and "BAG FULL!" or "NEED MATERIALS!"
            else
              game.stack:push(mod.ui.QuantityBox.new(game, {
                max = max,
                onDone = function(qty)
                  if qty then
                    queueBrew(game, recipe, qty)
                    self.message = ("%s x%d SET!"):format(recipe.label,
                                                          qty)
                  end
                end,
              }))
            end
          end
        end
        if self.index <= self.top then self.top = self.index - 1 end
        if self.index > self.top + 4 then self.top = self.index - 4 end
      end

      function self:draw()
        Font.drawBox(0, 0, 20, 10)
        local lvl = bestCrewLevel("MEDICINE")
        Font.draw(("MEDICINE  Lv.%d"):format(lvl), 16, 8)
        for row = 1, 4 do
          local i = self.top + row
          local r = BREW_RECIPES[i]
          if r then
            local y = 20 + (row - 1) * 14
            if i == self.index then
              Font.drawCode(Theme.cursor, 8, y)
            end
            Font.draw(r.label, 16, y)
            Font.draw(lvl >= r.tier
              and ("x%02d"):format(bagCount(game.save, r.ball))
              or ("Lv%d"):format(r.tier), 120, y)
          end
        end
        if self.top + 4 < #BREW_RECIPES then
          Font.drawCode(mod.ui.Theme.moreArrow, 148, 66)
        end

        Font.drawBox(0, 10, 20, 8)
        local recipe = BREW_RECIPES[self.index]
        Font.draw("NEEDS:", 8, 86)
        for i, c in ipairs(recipe.cost) do
          local def = mod.content.items:get(c[1])
          Font.draw(("%s %d/%d"):format(def and def.name or c[1],
            mod.exports.craftCount(game.save, c[1]), c[2]), 16, 86 + i * 10)
        end
        local status = self.message
        if not status then
          local q = mod.save:get("brewq", {})
          local o = q[1]
          if o then
            local totalLeft = o.left + (o.count - 1) * o.each
            for j = 2, #q do
              totalLeft = totalLeft + q[j].count * q[j].each
            end
            local lvl2 = bestCrewLevel("MEDICINE")
            status = lvl2 < 1 and "BREW PAUSED: NO MEDIC"
              or ("%s x%d.. %ds"):format(o.label, o.count,
                   math.ceil(totalLeft / (1 + (lvl2 - 1) / 2)))
          end
        end
        if status then Font.draw(status, 8, 128) end
      end

      return self
    end,
  })

  mod.commands:register("palcraft_medbench", function(ctx)
    local game = ctx.game
    game.stack:push(mod.ui.Menu.new(game, {
      { label = "BREW", onSelect = function()
          mod.ui.push(game, MED_SCREEN)
        end },
      { label = "PACK UP", onSelect = function()
          packStation(game, "medbench", "MED.BENCH")
        end },
      { label = "CANCEL", onSelect = function() end },
    }, { tx = 8, ty = 8 }))
  end)

  -- ------- the research desk: INSIGHT while a scholar studies

  local INSIGHT_SECONDS = BALANCE.insightSeconds

  local function tickInsight(game, pals)
    local now = game.save.playTime or 0
    local last = mod.save:get("insight_last")
    mod.save:set("insight_last", now)
    local st = mod.save:get("desk")
    if not (st and st.placed) or not last then return end
    local lvl = bestCrewLevel("RESEARCH", pals)
    if lvl < 1 then return end
    local progress = (mod.save:get("insight_progress") or 0)
      + math.max(0, now - last) * lvl
    local total = mod.save:get("insight") or 0
    while progress >= INSIGHT_SECONDS do
      progress = progress - INSIGHT_SECONDS
      total = total + 1
    end
    mod.save:set("insight_progress", progress)
    mod.save:set("insight", total)
  end
  mod.exports.tickInsight = tickInsight

  -- research also deciphers the daycare: with a scholar on duty the
  -- "?!" hint names the actual child (the parent picker reads this)
  local function researchActive()
    local st = mod.save:get("desk")
    return (st and st.placed and bestCrewLevel("RESEARCH") > 0) or false
  end
  mod.exports.researchActive = researchActive

  -- ------- TM research: feed organs, learn machines (item 23).
  -- Each type's TM ladder is data-driven: every merged TM whose move
  -- matches the type, weakest first -- research the same type again
  -- and the next, stronger machine comes out.
  mod.exports.tmOrderFor = function(typeKey)
    local list = {}
    for id, def in mod.content.items:each() do
      local m = def.machine
      if m and m.kind == "TM" and m.move then
        local mv = mod.content.moves:get(m.move)
        if mv and mv.type == typeKey then
          list[#list + 1] = { id = id, move = m.move,
                              power = mv.power or 0,
                              number = m.number or 99 }
        end
      end
    end
    table.sort(list, function(a, b)
      if a.power ~= b.power then return a.power < b.power end
      return a.number < b.number
    end)
    return list
  end

  mod.exports.queueResearch = function(game, typeKey)
    if mod.save:get("research") then
      return false, "Research is\nalready underway!"
    end
    local organ = ORGAN_FOR[typeKey]
    if not organ then return false, "Nothing to study!" end
    local inv = game.save.inventory
    if (inv[organ] or 0) < BALANCE.organsPerTm then
      return false, ("It takes %d organs\nof one type!")
        :format(BALANCE.organsPerTm)
    end
    local tiers = mod.save:get("research_tier", {})
    local order = mod.exports.tmOrderFor(typeKey)
    local nextTm = order[(tiers[typeKey] or 0) + 1]
    if not nextTm then
      return false, "That field is\nfully explored!"
    end
    local left = inv[organ] - BALANCE.organsPerTm
    inv[organ] = left > 0 and left or nil
    mod.save:set("research", { type = typeKey, tm = nextTm.id,
                               move = nextTm.move,
                               left = BALANCE.tmSeconds })
    return true, nextTm
  end

  mod.exports.tickResearch = function(game, pals)
    local now = game.save.playTime or 0
    local last = mod.save:get("research_last")
    mod.save:set("research_last", now)
    local r = mod.save:get("research")
    local st = mod.save:get("desk")
    if not r or not (st and st.placed) or not last then return end
    local lvl = bestCrewLevel("RESEARCH", pals)
    if lvl < 1 then return end
    r.left = r.left - math.max(0, now - last) * (1 + (lvl - 1) / 2)
    if r.left <= 0 then
      local tiers = mod.save:get("research_tier", {})
      tiers[r.type] = (tiers[r.type] or 0) + 1
      mod.save:set("research_tier", tiers)
      mod.save:set("research_done", { tm = r.tm, move = r.move })
      mod.save:set("research", nil)
    else
      mod.save:set("research", r)
    end
  end

  mod.events:on("world.stepped", function()
    if theGame then mod.exports.tickResearch(theGame) end
  end)

  -- researched machines leave the overworld: every ground or hidden
  -- TM that the desk can produce becomes an ORE cache instead
  do
    local researchable = {}
    for typeKey in pairs(ORGAN_FOR) do
      for _, tm in ipairs(mod.exports.tmOrderFor(typeKey)) do
        researchable[tm.id] = true
      end
    end
    local objectPatches, swapped = {}, 0
    for mapId, mapDef in mod.content.maps:each() do
      if mapDef.objects then
        local touched = false
        for _, obj in ipairs(mapDef.objects) do
          if obj.item and researchable[obj.item] then
            touched = true
            break
          end
        end
        if touched then
          local objects = {}
          for i, obj in ipairs(mapDef.objects) do
            local copy = {}
            for k, v in pairs(obj) do copy[k] = v end
            if copy.item and researchable[copy.item] then
              copy.item = "ORE"
              swapped = swapped + 1
            end
            objects[i] = copy
          end
          objectPatches[#objectPatches + 1] = { mapId, objects }
        end
      end
    end
    for _, p in ipairs(objectPatches) do
      mod.content.maps:patch(p[1], { objects = p[2] })
    end
    local hiddenPatches = {}
    for mapId, list in pairs(mod.content.field:get("hiddenItems") or {}) do
      local touched = false
      for _, h in ipairs(list) do
        if researchable[h.item] then
          touched = true
          break
        end
      end
      if touched then
        local rows = {}
        for i, h in ipairs(list) do
          rows[i] = { x = h.x, y = h.y,
                      item = researchable[h.item] and "ORE" or h.item }
        end
        hiddenPatches[#hiddenPatches + 1] = { mapId, rows }
      end
    end
    for _, p in ipairs(hiddenPatches) do
      mod.content.field:patch("hiddenItems", { [p[1]] = mod.DELETE })
      mod.content.field:patch("hiddenItems", { [p[1]] = p[2] })
    end
    if swapped + #hiddenPatches > 0 then
      mod.log:info("researchable TMs left the overworld: %d finds -> ORE",
                   swapped + #hiddenPatches)
    end
  end

  -- evolution stones are craft-only: every ground or hidden stone
  -- becomes an ORE cache, exactly like the researchable TMs above
  do
    local stones = { MOON_STONE = true, FIRE_STONE = true,
                     WATER_STONE = true, THUNDER_STONE = true,
                     LEAF_STONE = true }
    local objectPatches, swapped = {}, 0
    for mapId, mapDef in mod.content.maps:each() do
      if mapDef.objects then
        local touched = false
        for _, obj in ipairs(mapDef.objects) do
          if obj.item and stones[obj.item] then
            touched = true
            break
          end
        end
        if touched then
          local objects = {}
          for i, obj in ipairs(mapDef.objects) do
            local copy = {}
            for k, v in pairs(obj) do copy[k] = v end
            if copy.item and stones[copy.item] then
              copy.item = "ORE"
              swapped = swapped + 1
            end
            objects[i] = copy
          end
          objectPatches[#objectPatches + 1] = { mapId, objects }
        end
      end
    end
    for _, p in ipairs(objectPatches) do
      mod.content.maps:patch(p[1], { objects = p[2] })
    end
    local hiddenPatches = {}
    for mapId, list in pairs(mod.content.field:get("hiddenItems") or {}) do
      local touched = false
      for _, h in ipairs(list) do
        if stones[h.item] then
          touched = true
          break
        end
      end
      if touched then
        local rows = {}
        for i, h in ipairs(list) do
          rows[i] = { x = h.x, y = h.y,
                      item = stones[h.item] and "ORE" or h.item }
        end
        hiddenPatches[#hiddenPatches + 1] = { mapId, rows }
      end
    end
    for _, p in ipairs(hiddenPatches) do
      mod.content.field:patch("hiddenItems", { [p[1]] = mod.DELETE })
      mod.content.field:patch("hiddenItems", { [p[1]] = p[2] })
    end
    if swapped + #hiddenPatches > 0 then
      mod.log:info("stones left the overworld: %d finds -> ORE",
                   swapped + #hiddenPatches)
    end
  end

  mod.commands:register("palcraft_desk", function(ctx)
    local game = ctx.game
    tickInsight(game)
    mod.exports.tickResearch(game)
    local inv = game.save.inventory

    -- a finished machine is handed over first
    local lead
    local done = mod.save:get("research_done")
    if done then
      local canCarry = (inv[done.tm] or 0) > 0
        or bagSlots(game.save) < bagCapacity(game)
      if canCarry then
        inv[done.tm] = (inv[done.tm] or 0) + 1
        mod.save:set("research_done", nil)
        local def = mod.content.items:get(done.tm)
        lead = ("Research complete!\nGot %s (%s)!"):format(
          def and def.name or done.tm,
          tostring(done.move):gsub("_", " "))
      else
        lead = "A finished TM\nwaits -- bag full!"
      end
    end

    local r = mod.save:get("research")
    local status
    if r then
      local lvl = bestCrewLevel("RESEARCH")
      status = lvl < 1
        and "Research is paused:\nno PSYCHIC on the\ncrew!"
        or ("Researching %s..\nabout %ds left."):format(
            tostring(r.move):gsub("_", " "),
            math.ceil(math.max(0, r.left) / (1 + (lvl - 1) / 2)))
    else
      status = researchActive()
        and "Notes everywhere!"
        or "The desk sits idle.\nIt needs a PSYCHIC\nPOKéMON!"
    end
    status = status .. ("\fINSIGHT: %d"):format(mod.save:get("insight") or 0)
    if lead then status = lead .. "\f" .. status end

    game.stack:push(mod.ui.TextBox.new(game, status, function()
      game.stack:push(mod.ui.Menu.new(game, {
        { label = "RESEARCH", onSelect = function()
            local rows = {}
            for typeKey, organId in pairs(mod.exports.organFor) do
              local n = inv[organId] or 0
              if n > 0 then
                local def = mod.content.items:get(organId)
                local tiers = mod.save:get("research_tier", {})
                local nextTm =
                  mod.exports.tmOrderFor(typeKey)[(tiers[typeKey] or 0) + 1]
                rows[#rows + 1] = {
                  label = (def and def.name or organId),
                  right = nextTm
                    and ("x%d"):format(n) or "DONE",
                  value = typeKey,
                }
              end
            end
            table.sort(rows, function(a, b) return a.label < b.label end)
            if #rows == 0 then
              stationText(game,
                "No organs in the\nbag to study!")
              return
            end
            local picker
            picker = mod.ui.ListMenu.new(game, "RESEARCH", rows, {
              kind = "palcraft_research",
              onChoose = function(row)
                picker:close()
                local ok, res = mod.exports.queueResearch(game, row.value)
                if not ok then
                  stationText(game, res)
                else
                  stationText(game, ("The desk hums:\n%s underway!")
                    :format(tostring(res.move):gsub("_", " ")))
                end
              end,
            })
            game.stack:push(picker)
          end },
        { label = "PACK UP", onSelect = function()
            packStation(game, "desk", "RSCH.DESK")
          end },
        { label = "CANCEL", onSelect = function() end },
      }, { tx = 8, ty = 8 }))
    end))
  end)

  mod.events:on("world.stepped", function()
    if theGame then tickInsight(theGame) end
  end)

  -- ------- the shrine: SOULs while the night shift keeps vigil

  local SOUL_SECONDS = BALANCE.soulSeconds
  local SOUL_CAP = BALANCE.soulCap
  local SOUL_COST = BALANCE.soulCost
  local SOUL_BOOST_MAX = BALANCE.soulBoostMax

  local function tickSouls(game, pals)
    local now = game.save.playTime or 0
    local last = mod.save:get("soul_last")
    mod.save:set("soul_last", now)
    local st = mod.save:get("shrine")
    if not (st and st.placed) or not last then return end
    local lvl = bestCrewLevel("NIGHT SHIFT", pals)
    if lvl < 1 then return end
    local souls = mod.save:get("souls") or 0
    if souls >= SOUL_CAP then return end
    local progress = (mod.save:get("soul_progress") or 0)
      + math.max(0, now - last) * lvl
    while progress >= SOUL_SECONDS and souls < SOUL_CAP do
      progress = progress - SOUL_SECONDS
      souls = souls + 1
    end
    mod.save:set("soul_progress", progress)
    mod.save:set("souls", souls)
  end
  mod.exports.tickSouls = tickSouls

  local function pushOfferPicker(game)
    local ws = mod.exports.workSuitabilities
    local entries = {}
    for i, mon in ipairs(mod.save:get("base_pals", {})) do
      entries[#entries + 1] = {
        species = mon.species,
        label = ("%s L%d"):format(palLabel(game, mon), mon.level or 0),
        right = mon.soulBoost and ("+%d"):format(mon.soulBoost) or nil,
        value = i,
        suits = ws and ws(mon.species) or nil,
      }
    end
    local list
    list = newMonGrid(game, {
      title = "OFFER TO", kind = "shrine_offer", entries = entries,
      emptyText = "NOBODY LIVES HERE!",
      topLabel = function(grid)
        local e = grid.entries[grid.index]
        return e and e.right
      end,
      onChoose = function(e)
        local pals = mod.save:get("base_pals", {})
        local mon = pals[e.value]
        if not mon then return end
        if (mon.soulBoost or 0) >= SOUL_BOOST_MAX then
          stationText(game, "It can hold no\nmore spirit!")
          return
        end
        mod.save:set("souls", (mod.save:get("souls") or 0) - SOUL_COST)
        mon.soulBoost = (mon.soulBoost or 0) + 1
        mod.save:set("base_pals", pals)
        list:close()
        stationText(game, ("%s's work\nglows with spirit!\n(+%d)")
          :format(palLabel(game, mon), mon.soulBoost))
      end,
    })
    game.stack:push(list)
  end

  mod.commands:register("palcraft_shrine", function(ctx)
    local game = ctx.game
    tickSouls(game)
    local souls = mod.save:get("souls") or 0
    local vigil = bestCrewLevel("NIGHT SHIFT") > 0
    local status = (vigil
      and "The candle burns\nwith a cold light."
      or "The candle is out.\nIt needs a GHOST\nPOKéMON's vigil!")
      .. ("\fSOULS: %d"):format(souls)
    game.stack:push(mod.ui.TextBox.new(game, status, function()
      game.stack:push(mod.ui.Menu.new(game, {
        { label = "OFFER", onSelect = function()
            if (mod.save:get("souls") or 0) < SOUL_COST then
              stationText(game,
                ("It takes %d SOULS\nto make an offering."):format(SOUL_COST))
              return
            end
            pushOfferPicker(game)
          end },
        { label = "PACK UP", onSelect = function()
            packStation(game, "shrine", "SHRINE")
          end },
        { label = "CANCEL", onSelect = function() end },
      }, { tx = 8, ty = 8 }))
    end))
  end)

  mod.events:on("world.stepped", function()
    if theGame then tickSouls(theGame) end
  end)

  mod.commands:register("palcraft_altar", function(ctx)
    local game = ctx.game
    game.stack:push(mod.ui.Menu.new(game, {
      { label = "SUMMON", onSelect = function()
          local rows = {}
          for _, b in ipairs(Boss.LIST) do
            local tab = Boss.tabletId(b.type)
            if (game.save.inventory[tab] or 0) > 0 then
              local def = game.data.items[tab]
              rows[#rows + 1] = { label = (def and def.name) or tab,
                                  value = b.type }
            end
          end
          if #rows == 0 then
            stationText(game, "No tablet in the\nbag to offer!")
            return
          end
          local picker
          picker = mod.ui.ListMenu.new(game, "SUMMON", rows, {
            kind = "palcraft_summon",
            onChoose = function(row)
              picker:close()
              local ok, res = mod.exports.canSummon(game, row.value)
              if not ok then
                stationText(game, res)
                return
              end
              local tab = Boss.tabletId(row.value)
              local inv = game.save.inventory
              inv[tab] = (inv[tab] or 0) > 1 and inv[tab] - 1 or nil
              mod.save:set("summon_fight", res.key)
              local lvl = math.min(100,
                res.level * BALANCE.summonMultiplier)
              mod.world:queueScript({
                { "start_battle", "wild", res.species, lvl },
              })
            end,
          })
          game.stack:push(picker)
        end },
      { label = "FUSE", onSelect = function()
          local rows = {}
          for _, b in ipairs(Boss.LIST) do
            local sh = Boss.shardId(b.type)
            local n = game.save.inventory[sh] or 0
            if n > 0 then
              local def = game.data.items[sh]
              rows[#rows + 1] = { label = (def and def.name) or sh,
                                  right = "x" .. n, value = b.type }
            end
          end
          if #rows == 0 then
            stationText(game, "No shards in the\nbag to fuse!")
            return
          end
          local picker
          picker = mod.ui.ListMenu.new(game, "FUSE", rows, {
            kind = "palcraft_fuse",
            onChoose = function(row)
              picker:close()
              local ok, res = mod.exports.fuseTablet(game, row.value)
              if not ok then
                stationText(game, res)
              else
                local def = game.data.items[res]
                stationText(game, ("The shards sing\nand fuse: %s!")
                  :format((def and def.name) or res))
              end
            end,
          })
          game.stack:push(picker)
        end },
      { label = "PACK UP", onSelect = function()
          packStation(game, "altar", "ALTAR")
        end },
      { label = "CANCEL", onSelect = function() end },
    }, { tx = 8, ty = 8 }))
  end)

    -- ------- the training dummy: RARE CANDY while the dojo is staffed

  local CANDY_SECONDS = BALANCE.candySeconds
  local CANDY_CAP = BALANCE.candyCap

  local function tickDummy(game, pals)
    local now = game.save.playTime or 0
    local last = mod.save:get("candy_last")
    mod.save:set("candy_last", now)
    local st = mod.save:get("dummy")
    if not (st and st.placed) or not last then return end
    local lvl = bestCrewLevel("TRAINING", pals)
    if lvl < 1 then return end
    local done = mod.save:get("candydone") or 0
    if done >= CANDY_CAP then return end
    local progress = (mod.save:get("candy_progress") or 0)
      + math.max(0, now - last) * lvl
    while progress >= CANDY_SECONDS and done < CANDY_CAP do
      progress = progress - CANDY_SECONDS
      if not haulToChest("RARE_CANDY", 1) then
        done = done + 1
      end
    end
    mod.save:set("candy_progress", progress)
    mod.save:set("candydone", done)
  end
  mod.exports.tickDummy = tickDummy

  mod.commands:register("palcraft_dummy", function(ctx)
    local game = ctx.game
    tickDummy(game)
    local done = mod.save:get("candydone") or 0
    local inv = game.save.inventory
    local took = 0
    if done > 0 and ((inv.RARE_CANDY or 0) > 0
                     or bagSlots(game.save) < bagCapacity(game)) then
      inv.RARE_CANDY = (inv.RARE_CANDY or 0) + done
      mod.save:set("candydone", 0)
      took = done
    end
    local lvl = bestCrewLevel("TRAINING")
    local status = lvl > 0
      and "The dojo rings\nwith training!"
      or "The dummy stands\nuntouched. It needs\na FIGHTING\nPOKéMON!"
    if took > 0 then
      status = ("Took RARE CANDY\nx%d!\f"):format(took) .. status
    end
    game.stack:push(mod.ui.TextBox.new(game, status, function()
      game.stack:push(mod.ui.Menu.new(game, {
        { label = "PACK UP", onSelect = function()
            packStation(game, "dummy", "TRN.DUMMY")
          end },
        { label = "CANCEL", onSelect = function() end },
      }, { tx = 8, ty = 8 }))
    end))
  end)

  mod.events:on("world.stepped", function()
    if theGame then tickDummy(theGame) end
  end)

  -- ------- the yield stations: WOOD and ORE while their trades work

  local function yieldStation(spec)
    local secs = spec.seconds
    local progressKey = spec.key .. "_progress"
    local doneKey = spec.key .. "_done"
    local lastKey = spec.key .. "_last"
    local function tick(game, pals)
      local now = game.save.playTime or 0
      local last = mod.save:get(lastKey)
      mod.save:set(lastKey, now)
      local st = mod.save:get(spec.key)
      if not (st and st.placed) or not last then return end
      local lvl = bestCrewLevel(spec.job, pals)
      if lvl < 1 then return end
      local done = mod.save:get(doneKey) or 0
      if done >= spec.cap then return end
      local progress = (mod.save:get(progressKey) or 0)
        + math.max(0, now - last) * lvl
      while progress >= secs and done < spec.cap do
        progress = progress - secs
        if not haulToChest(spec.item, 1) then
          done = done + 1
        end
      end
      mod.save:set(progressKey, progress)
      mod.save:set(doneKey, done)
    end
    mod.commands:register(spec.command, function(ctx)
      local game = ctx.game
      tick(game)
      local done = mod.save:get(doneKey) or 0
      local inv = game.save.inventory
      local took = 0
      if done > 0 and ((inv[spec.item] or 0) > 0
                       or bagSlots(game.save) < bagCapacity(game)) then
        inv[spec.item] = (inv[spec.item] or 0) + done
        mod.save:set(doneKey, 0)
        took = done
      end
      local lvl = bestCrewLevel(spec.job)
      local status = lvl > 0 and spec.busyText or spec.idleText
      status = status .. ("\f%ds per %s,\n\194\183 %s level\n(now \194\183%d).")
        :format(secs, spec.itemName, spec.job, math.max(lvl, 1))
      if took > 0 then
        status = ("Took %s x%d!\f"):format(spec.itemName, took) .. status
      end
      game.stack:push(mod.ui.TextBox.new(game, status, function()
        game.stack:push(mod.ui.Menu.new(game, {
          { label = "PACK UP", onSelect = function()
              packStation(game, spec.key, spec.label)
            end },
          { label = "CANCEL", onSelect = function() end },
        }, { tx = 8, ty = 8 }))
      end))
    end)
    mod.events:on("world.stepped", function()
      if theGame then tick(theGame) end
    end)
    return tick
  end

  mod.exports.tickLumber = yieldStation({
    key = "lumber", job = "LUMBERING", item = "WOOD",
    itemName = "WOOD", label = "WOODPILE",
    command = "palcraft_lumber",
    seconds = BALANCE.lumberSeconds, cap = BALANCE.yieldCap,
    busyText = "Chips fly! The\npile grows.",
    idleText = "The axe rests. It\nneeds a GROUND\nPOKéMON's muscle!",
  })
  mod.exports.tickMine = yieldStation({
    key = "mine", job = "MINING", item = "ORE",
    itemName = "ORE", label = "ORE ROCK",
    command = "palcraft_mine",
    seconds = BALANCE.mineSeconds, cap = BALANCE.yieldCap,
    busyText = "The rock face\nsparkles with ore!",
    idleText = "The rock sits\nunworked. It needs\na ROCK POKéMON!",
  })

  -- ------- the essence condenser: feed same-species offers, gain stars

  -- every mon from the target's EVOLUTION LINE that could be offered
  -- up: party mates (never the target itself) and every box mon -- a
  -- CHARMANDER feeds a CHARIZARD's essence just fine
  local function condenseOffers(game, target)
    local root = lineRootOf(target.species)
    local out = {}
    for i, m in ipairs(game.save.party or {}) do
      if m ~= target and lineRootOf(m.species) == root then
        out[#out + 1] = { mon = m, where = "PARTY", idx = i }
      end
    end
    for bi, box in ipairs(boxesOf(game)) do
      for i, m in ipairs(box) do
        if lineRootOf(m.species) == root then
          out[#out + 1] = { mon = m, where = "BOX" .. bi, idx = i }
        end
      end
    end
    return out
  end

  -- remove by REFERENCE: indices shift as offers are consumed
  local function releaseOffer(game, mon)
    for i, m in ipairs(game.save.party or {}) do
      if m == mon then
        table.remove(game.save.party, i)
        return true
      end
    end
    for _, box in ipairs(boxesOf(game)) do
      for i, m in ipairs(box) do
        if m == mon then
          table.remove(box, i)
          return true
        end
      end
    end
    return false
  end
  mod.exports.condenseOffers = condenseOffers

  local function pickOffers(game, target, needed, taken)
    if needed <= 0 then
      local def = game.data.pokemon[target.species]
      local stars = mod.exports.starsOf(target) + 1
      mod.exports.setStars(target, def, stars)
      stationText(game, ("%s shines with\nessence! Now [%d].")
        :format(speciesName(game, target.species), stars))
      return
    end
    local offers = condenseOffers(game, target)
    local entries = {}
    for _, o in ipairs(offers) do
      entries[#entries + 1] = {
        species = o.mon.species,
        label = ("%s L%d"):format(speciesName(game, o.mon.species),
                                  o.mon.level or 1),
        right = o.where, value = o.mon,
      }
    end
    local picker
    picker = newMonGrid(game, {
      title = ("OFFER x%d"):format(needed),
      kind = "condense_offer", entries = entries,
      emptyText = "NO OFFERS LEFT!",
      onChoose = function(e)
        if not e then return end
        releaseOffer(game, e.value)
        picker:close()
        pickOffers(game, target, needed - 1, (taken or 0) + 1)
      end,
    })
    game.stack:push(picker)
  end

  local function openCondense(game)
    local entries = {}
    for _, m in ipairs(game.save.party or {}) do
      local stars = mod.exports.starsOf(m)
      local disabled, note
      local needed = mod.exports.condenseNeeded(stars)
      if stars >= 3 then
        disabled, note = true, "FULLY CONDENSED"
      elseif #condenseOffers(game, m) < needed then
        disabled, note = true,
          ("NEEDS %s LINE x%d"):format(
            speciesName(game, lineRootOf(m.species)), needed)
      end
      entries[#entries + 1] = {
        species = m.species,
        label = ("%s [%d]"):format(speciesName(game, m.species), stars),
        right = "[" .. stars .. "]", value = m,
        disabled = disabled, note = note,
        infoLines = { "NEXT STAR:",
          ("OFFER %s x%d"):format(
            speciesName(game, lineRootOf(m.species)), needed),
          "(ANY OF ITS LINE)" },
      }
    end
    local picker
    picker = newMonGrid(game, {
      title = "CONDENSE",
      kind = "condense_target", entries = entries,
      emptyText = "NO PARTY HERE!",
      onChoose = function(e)
        if not e then return end
        if e.disabled then
          stationText(game, e.note .. "!")
          return
        end
        picker:close()
        pickOffers(game, e.value,
                   mod.exports.condenseNeeded(mod.exports.starsOf(e.value)))
      end,
    })
    game.stack:push(picker)
  end

  mod.commands:register("palcraft_condenser", function(ctx)
    local game = ctx.game
    game.stack:push(mod.ui.TextBox.new(game,
      "Essence swirls in\nthe vat.", function()
      game.stack:push(mod.ui.Menu.new(game, {
        { label = "CONDENSE", onSelect = function()
            openCondense(game)
          end },
        { label = "PACK UP", onSelect = function()
            packStation(game, "condenser", "CONDENSER")
          end },
        { label = "CANCEL", onSelect = function() end },
      }, { tx = 8, ty = 8 }))
    end))
  end)

  mod.commands:register("palcraft_furnace", function(ctx)
    local game = ctx.game
    tickSmelt(game)
    local got = collectSmelt(game)
    local sq = mod.save:get("smeltq")
    local progress
    if sq and (sq.count or 0) > 0 then
      local lvl = bestCrewLevel("KINDLING")
      progress = lvl < 1
        and ("ORE x%d loaded, but\nthe fire is out!"):format(sq.count)
        or ("SMELT x%d underway..\nabout %ds left."):format(sq.count,
            math.ceil((sq.left + (sq.count - 1) * SMELT_SECONDS)
                      / (1 + (lvl - 1) / 2)))
    end
    local function menu()
      game.stack:push(mod.ui.Menu.new(game, {
        { label = "SMELT", onSelect = function()
            local ore = mod.exports.craftCount(game.save, "ORE")
            if ore < 1 then
              stationText(game, "No ORE in the bag\nor the chest!")
              return
            end
            game.stack:push(mod.ui.QuantityBox.new(game, {
              max = ore,
              onDone = function(qty)
                if qty and qty > 0 then
                  queueSmelt(game, qty)
                  stationText(game,
                    bestCrewLevel("KINDLING") > 0
                    and "The FURNACE\nroars to work!"
                    or "The ORE is loaded,\nbut the fire needs\na KINDLING\nPOKéMON!")
                end
              end,
            }))
          end },
        { label = "PACK UP", onSelect = function()
            packStation(game, "furnace", "FURNACE")
          end },
        { label = "CANCEL", onSelect = function() end },
      }, { tx = 8, ty = 8 }))
    end
    local lead
    if got > 0 then
      lead = ("Took INGOT x%d\nfrom the FURNACE!"):format(got)
    end
    if progress then
      lead = lead and (lead .. "\f" .. progress) or progress
    end
    if lead then
      game.stack:push(mod.ui.TextBox.new(game, lead, menu))
    else
      menu()
    end
  end)

  -- ------------------------------------------------------- the screen

  local CRAFT_VISIBLE = 3
  mod.content.screens:register(SCREEN, {
    new = function(game)
      local Font, Theme = mod.ui.Font, mod.ui.Theme
      -- a powered base table is the MK2: the stone recipes appear and
      -- the title says so.  Tables outside the base stay MK1 -- the
      -- power doesn't reach.
      local ow = game.overworld
      local mk2 = ow and ow.map and ow.map.id == BASE_MAP
                  and basePowered(game) or false
      local recipes = {}
      for _, r in ipairs(RECIPES) do recipes[#recipes + 1] = r end
      for _, r in ipairs(STATION_RECIPES) do
        recipes[#recipes + 1] = r
      end
      if mk2 then
        for _, r in ipairs(MK2_RECIPES) do recipes[#recipes + 1] = r end
      end
      local self = { game = game, isOpaque = true, index = 1, top = 0,
                     recipes = recipes, mk2 = mk2,
                     speed = craftSpeed(game),
                     isPalcraftScreen = true }

      -- settle the clock, then hand over anything the crew finished
      tickCraft(game)
      local got, waiting = collectCraft(game)
      if got[1] then
        local def = mod.content.items:get(got[1].id)
        self.message = ("GOT %s x%d!"):format(
          def and def.name or got[1].id, got[1].count)
      elseif waiting then
        self.message = "BAG FULL!"
      end

      function self:update(dt)
        tickCraft(game)
        local input = game.input
        if input:wasPressed("b") then
          collectCraft(game)   -- sweep anything that just finished
          game.stack:pop()
        elseif input:wasPressed("up") then
          self.index = self.index > 1 and self.index - 1 or #recipes
          self.message = nil
        elseif input:wasPressed("down") then
          self.index = self.index < #recipes and self.index + 1 or 1
          self.message = nil
        elseif input:wasPressed("a") then
          local recipe = recipes[self.index]
          if recipe.insight
             and (mod.save:get("insight") or 0) < recipe.insight then
            self.message = ("NEEDS INSIGHT %d!"):format(recipe.insight)
            return
          end
          if recipe.badge
             and not (game.save.inventory or {})[recipe.badge] then
            self.message = "NEEDS " .. recipe.badge .. "!"
            return
          end
          local max = maxCraftable(game, recipe)
          if max < 1 then
            self.message = mod.exports.materialsMax(game, recipe) > 0
              and "BAG FULL!" or "NEED MATERIALS!"
          else
            game.stack:push(mod.ui.QuantityBox.new(game, {
              max = max,
              onDone = function(qty)
                if qty then
                  queueCraft(game, recipe, qty)
                  self.message = ("%s x%d SET!"):format(recipe.label, qty)
                end
              end,
            }))
          end
        end
        -- keep the cursor's row inside the visible window
        if self.index <= self.top then self.top = self.index - 1 end
        if self.index > self.top + CRAFT_VISIBLE then
          self.top = self.index - CRAFT_VISIBLE
        end
      end

      function self:draw()
        Font.drawBox(0, 0, 20, 10)
        local speed = craftSpeed(game)
        self.speed = speed
        local q = mod.save:get("craftq", {})
        local o = q[1]
        -- the header is live: the running order, its progress bar, and
        -- who on the crew is speeding it
        if o then
          local totalLeft = o.left + (o.count - 1) * o.each
          for j = 2, #q do
            totalLeft = totalLeft + q[j].count * q[j].each
          end
          Font.draw(("%s x%d  %ds"):format(o.label, o.count,
            math.ceil(totalLeft / speed)), 8, 6)
          love.graphics.setColor(0, 0, 0, 1)
          love.graphics.rectangle("line", 8.5, 16.5, 143, 5)
          love.graphics.rectangle("fill", 10, 18,
            140 * (1 - o.left / o.each), 2)
          love.graphics.setColor(1, 1, 1, 1)
        else
          Font.draw(self.mk2 and "CRAFTING MK2" or "CRAFTING", 8, 6)
        end
        local lvl, who = mod.exports.bestCrewWorker("HANDIWORK")
        local helper = who and palLabel(game, who) or "NO HELPER"
        Font.draw(("%s x%.1f"):format(helper, speed), 8, 24)
        for row = 1, CRAFT_VISIBLE do
          local i = self.top + row
          local r = recipes[i]
          if r then
            local y = 36 + (row - 1) * 14
            if i == self.index then
              Font.drawCode(Theme.cursor, 8, y)
            end
            Font.draw(r.label, 16, y)
            local tag
            if r.insight
               and (mod.save:get("insight") or 0) < r.insight then
              tag = ("IN%d"):format(r.insight)
            elseif r.badge
               and not (game.save.inventory or {})[r.badge] then
              tag = "BADGE"
            else
              tag = ("x%02d"):format(bagCount(game.save, r.ball))
            end
            Font.draw(tag, 120, y)
          end
        end
        if self.top + CRAFT_VISIBLE < #recipes then
          Font.drawCode(mod.ui.Theme.moreArrow, 148, 62)
        end

        Font.drawBox(0, 10, 20, 8)
        local recipe = recipes[self.index]
        Font.draw("NEEDS:", 8, 86)
        for i, c in ipairs(recipe.cost) do
          local def = mod.content.items:get(c[1])
          Font.draw(("%s %d/%d"):format(def and def.name or c[1],
            mod.exports.craftCount(game.save, c[1]), c[2]), 16, 86 + i * 10)
        end
        -- the header carries the queue now; this line is for messages
        if self.message then Font.draw(self.message, 8, 128) end
      end

      return self
    end,
  })

  -- No start-menu shortcut: crafting happens at a placed CRAFT TABLE,
  -- the full settle-down-and-craft loop.  The screen stays in the
  -- registry and opens through the table's push_screen row.
end
