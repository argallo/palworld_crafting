-- In-game eye check for palworld_crafting, against the real imported data:
--
--   POKEPORT_DRIVER=mods/palworld_crafting/tests/driver_eyecheck.lua \
--   POKEPORT_IDENTITY=palcraft love .
--
-- Walks the four features end to end: ball-free mart shelves (Pewter's
-- BUY list), battle-win apricorn drops, a hidden apricorn on Route 1,
-- and the CRAFT screen from the Start menu.  Screenshots land in
-- /tmp/palcraft_shots/; exits 0 when every check passes.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")

  local SHOTS = "/tmp/palcraft_shots/"
  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1 else fail = fail + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  local function apricornCount(save)
    return (save.inventory.APRICORN_RED or 0)
         + (save.inventory.APRICORN_BLU or 0)
         + (save.inventory.APRICORN_YLW or 0)
  end

  local function mashToOverworld(cap)
    for _ = 1, cap or 800 do
      if game.stack:top() == game.overworld
         and not (game.overworld.runner and game.overworld.runner:isRunning()) then
        return true
      end
      U.tap(game, "a")
      U.wait(3)
    end
    return false
  end

  -- ------------------------------------------------ 1. merged data checks

  local shelves, ballsLeft = 0, 0
  for groupId, group in pairs(game.data.text_pointers) do
    for key, entry in pairs(group) do
      if type(entry) == "table" and type(entry.mart) == "table" then
        shelves = shelves + 1
        for _, itemId in ipairs(entry.mart) do
          local def = game.data.items[itemId]
          if def and def.ball then
            ballsLeft = ballsLeft + 1
            U.log("  ball still on shelf:", groupId, key, itemId)
          end
        end
      end
    end
  end
  check(("no balls left on any of %d mart shelves"):format(shelves),
        shelves > 0 and ballsLeft == 0)
  local tablesSold, stonesSold = 0, 0
  for _, group in pairs(game.data.text_pointers) do
    for _, entry in pairs(group) do
      if type(entry) == "table" and type(entry.mart) == "table" then
        for _, itemId in ipairs(entry.mart) do
          if itemId == "CRAFT_TABLE" then tablesSold = tablesSold + 1 end
          if itemId == "MOON_STONE" or itemId == "FIRE_STONE"
             or itemId == "WATER_STONE" or itemId == "THUNDER_STONE"
             or itemId == "LEAF_STONE" then
            stonesSold = stonesSold + 1
          end
        end
      end
    end
  end
  check("no shelf sells the CRAFT TABLE or a stone",
        tablesSold == 0 and stonesSold == 0)
  local stonesGround = 0
  for _, mapDef in pairs(game.data.maps) do
    for _, obj in ipairs(mapDef.objects or {}) do
      if obj.item == "MOON_STONE" or obj.item == "FIRE_STONE"
         or obj.item == "WATER_STONE" or obj.item == "THUNDER_STONE"
         or obj.item == "LEAF_STONE" then
        stonesGround = stonesGround + 1
      end
    end
  end
  for _, list in pairs((game.data.field and game.data.field.hiddenItems)
                       or {}) do
    for _, h in ipairs(list) do
      if h.item == "MOON_STONE" or h.item == "FIRE_STONE"
         or h.item == "WATER_STONE" or h.item == "THUNDER_STONE"
         or h.item == "LEAF_STONE" then
        stonesGround = stonesGround + 1
      end
    end
  end
  check("every ground and hidden stone became an ORE cache",
        stonesGround == 0)
  check("apricorns are merged items", game.data.items.APRICORN_RED ~= nil
        and game.data.items.APRICORN_BLU ~= nil
        and game.data.items.APRICORN_YLW ~= nil)
  check("all three apricorn sprites are merged",
        game.data.sprites.SPRITE_APRICORN_RED ~= nil
        and game.data.sprites.SPRITE_APRICORN_BLU ~= nil
        and game.data.sprites.SPRITE_APRICORN_YLW ~= nil)

  -- a party that wins fast, and a clean bag
  game.save.player = game.save.player or {}
  game.save.player.name = "RED"
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60) }
  game.save.inventory = {}
  game.save.bagOrder = nil

  -- ------------------------------------------------ 2. the Pewter shelf

  U.teleport(game, "PEWTER_MART", 3, 5, "up")
  local ow = game.overworld

  -- find the clerk (the NPC whose TEXT entry carries a mart list) and a
  -- legal stand cell: adjacent, or two away across a counter tile
  local stand
  for _, npc in ipairs(ow.npcs) do
    local entry = game.data:textEntry(ow.map.def.label, npc.def.text)
    if entry and entry.mart then
      local c = {
        { npc.cellX, npc.cellY + 1, "up" }, { npc.cellX, npc.cellY - 1, "down" },
        { npc.cellX - 1, npc.cellY, "right" }, { npc.cellX + 1, npc.cellY, "left" },
        { npc.cellX, npc.cellY + 2, "up", npc.cellX, npc.cellY + 1 },
        { npc.cellX, npc.cellY - 2, "down", npc.cellX, npc.cellY - 1 },
        { npc.cellX - 2, npc.cellY, "right", npc.cellX - 1, npc.cellY },
        { npc.cellX + 2, npc.cellY, "left", npc.cellX + 1, npc.cellY },
      }
      for _, s in ipairs(c) do
        local counterOk = s[4] == nil or ow.map:isCounterCell(s[4], s[5])
        if counterOk and ow.map:inBounds(s[1], s[2])
           and ow.map:isWalkableCell(s[1], s[2]) then
          stand = s
          break
        end
      end
    end
  end
  check("found the Pewter clerk", stand ~= nil)

  if stand then
    U.teleport(game, "PEWTER_MART", stand[1], stand[2], stand[3])
    U.tap(game, "a")   -- talk
    for _ = 1, 60 do   -- greet text -> BUY/SELL/QUIT -> BUY list
      local top = game.stack:top()
      if top and top.title == "BUY" then break end
      U.tap(game, "a")
      U.wait(8)
    end
    local top = game.stack:top()
    local isBuy = top ~= nil and top.title == "BUY"
    U.shot(game, SHOTS .. "01_mart_buy_list.png")
    local clean = isBuy
    if isBuy then
      for _, it in ipairs(top.items) do
        local def = game.data.items[it.value]
        if def and def.ball then clean = false end
      end
    end
    check("Pewter BUY list opens and sells no balls", clean)
    for _ = 1, 4 do U.tap(game, "b") U.wait(8) end  -- back out of the shop
    mashToOverworld(60)
  end

  -- ------------------------------------------------ 3. battle-win drops

  U.teleport(game, "ROUTE_1", 10, 30, "down")
  ow = game.overworld
  -- wilds drop wood, seeds, ore or type organs besides apricorns
  local function dropCount(save)
    local n = apricornCount(save) + (save.inventory.WOOD or 0)
      + (save.inventory.GRAPE_SEED or 0) + (save.inventory.ORE or 0)
    for id, c in pairs(save.inventory) do
      if id:find("ORGAN_", 1, true) == 1 then n = n + c end
    end
    return n
  end
  local beforeBattle = dropCount(game.save)
  ow.runner:run({ { "start_battle", "wild", "PIDGEY", 3 } })
  U.wait(30)
  check("battle mashed to a win", mashToOverworld(800))

  -- a synthetic trainer win guarantees two more drops even if the wild
  -- roll came up empty (it is an 85% chance by design)
  Runtime.emit("battle.ended",
    { battle = { kind = "trainer" }, result = "win" })

  -- one step fires world.stepped, which settles the pending drops into
  -- give_item rows -- the "PAL got X APRICORN!" boxes
  U.hold(game, "down", 12)
  U.wait(40)
  U.shot(game, SHOTS .. "02_battle_drop_text.png")
  mashToOverworld(120)
  check("battle drops reached the bag",
        dropCount(game.save) >= beforeBattle + 1)

  -- ------------------------------- 4. visible apricorns on every map

  -- sweep every placed spot (read straight from the merged map data):
  -- the cell must be walkable (nothing floats on a tree) and the
  -- apricorn object must have spawned there
  local spots, spotTotal = {}, 0
  for mapId, mapDef in pairs(game.data.maps) do
    for _, obj in ipairs(mapDef.objects or {}) do
      if tostring(obj.sprite):find("SPRITE_APRICORN", 1, true) == 1 then
        spots[mapId] = spots[mapId] or {}
        table.insert(spots[mapId], { obj.x, obj.y, obj.item })
        spotTotal = spotTotal + 1
      end
    end
  end
  check("apricorn objects merged onto the maps (" .. spotTotal .. ")",
        spotTotal >= 40)
  local badSpots = 0
  for mapId, list in pairs(spots) do
    U.teleport(game, mapId, list[1][1], list[1][2] + 1, "up")
    ow = game.overworld
    for _, s in ipairs(list) do
      local walkable = ow.map:isWalkableCell(s[1], s[2])
      local spawned = false
      for _, npc in ipairs(ow.npcs) do
        if npc.def and tostring(npc.def.sprite):find("SPRITE_APRICORN", 1, true) == 1
           and npc.cellX == s[1] and npc.cellY == s[2] then
          spawned = true
        end
      end
      if not (walkable and spawned) then
        badSpots = badSpots + 1
        U.log(("  bad spot %s (%d,%d) walkable=%s spawned=%s")
          :format(mapId, s[1], s[2], tostring(walkable), tostring(spawned)))
      end
    end
  end
  check("every apricorn spot is walkable and spawned", badSpots == 0)

  -- no free store-tier balls anywhere in the world: every visible ball
  -- object and hidden ball find swapped to the matching apricorn
  local looseBalls = 0
  local isBallId = { POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true }
  for mapId, mapDef in pairs(game.data.maps) do
    for _, obj in ipairs(mapDef.objects or {}) do
      if obj.item and isBallId[obj.item] then
        looseBalls = looseBalls + 1
        U.log("  loose ball object:", mapId, obj.name or "?", obj.item)
      end
    end
  end
  for mapId, list in pairs(game.data.field.hiddenItems or {}) do
    for _, h in ipairs(list) do
      if isBallId[h.item] then
        looseBalls = looseBalls + 1
        U.log("  hidden ball left:", mapId, h.item)
      end
    end
  end
  check("no loose Poke/Great/Ultra Balls remain in the world", looseBalls == 0)

  -- the Viridian Forest Poke Ball is now a red apricorn: see it, grab it
  U.teleport(game, "VIRIDIAN_FOREST", 1, 32, "up")
  U.wait(10)
  U.shot(game, SHOTS .. "03c_forest_ball_swap.png")
  local beforeSwap = game.save.inventory.APRICORN_RED or 0
  U.tap(game, "a")
  U.wait(40)
  mashToOverworld(60)
  check("the swapped forest ball hands over a RED APRICORN",
        (game.save.inventory.APRICORN_RED or 0) > beforeSwap)

  -- pick one up on Route 1: stand under it, face it, press A
  U.teleport(game, "ROUTE_1", 8, 13, "up")
  U.wait(10)
  U.shot(game, SHOTS .. "03a_apricorn_visible.png")
  local beforePickup = game.save.inventory.APRICORN_RED or 0
  U.tap(game, "a")
  U.wait(40)
  U.shot(game, SHOTS .. "03b_apricorn_pickup.png")
  mashToOverworld(60)
  check("visible apricorn picked up at ROUTE_1 (8,12)",
        (game.save.inventory.APRICORN_RED or 0) > beforePickup)
  check("the picked apricorn despawned", (function()
    for _, npc in ipairs(game.overworld.npcs) do
      if npc.def and tostring(npc.def.sprite):find("SPRITE_APRICORN", 1, true) == 1
         and npc.cellX == 8 and npc.cellY == 12 then return false end
    end
    return true
  end)())

  -- ------------------------------------------------ 5. CRAFT

  -- the Start menu carries no CRAFT row anymore: tables are the only
  -- place to craft
  U.tap(game, "start")
  U.wait(20)
  U.shot(game, SHOTS .. "04_start_menu.png")
  local menu = game.stack:top()
  local hasCraftRow = false
  for _, it in ipairs(menu and menu.items or {}) do
    if it.label == "CRAFT" then hasCraftRow = true end
  end
  check("no CRAFT row in the Start menu (table-only crafting)",
        not hasCraftRow)
  U.tap(game, "b")
  U.wait(15)

  -- ------------------------------------------- 6. the placeable table

  local Screens = require("src.ui.Screens")

  local function tableNpcAt(x, y)
    for _, npc in ipairs(game.overworld.npcs) do
      if npc.def and npc.def.sprite == "SPRITE_CRAFT_TABLE"
         and npc.cellX == x and npc.cellY == y then
        return npc
      end
    end
    return nil
  end

  -- rows sort alphabetically in a rebuilt bag: `downs` walks the cursor
  -- to the CRAFT TABLE row
  local function placeViaBag(downs)
    Screens.push(game, "BagMenu")
    U.wait(20)
    for _ = 1, downs or 0 do
      U.tap(game, "down")
      U.wait(6)
    end
    U.tap(game, "a")      -- select CRAFT TABLE
    U.wait(15)
    U.tap(game, "a")      -- USE
    U.wait(50)            -- let the "set up!" text finish typing
    -- B advances text and closes menus but never activates an item, so
    -- mashing it is a deterministic way back to the overworld
    for _ = 1, 30 do
      if game.stack:top() == game.overworld then break end
      U.tap(game, "b")
      U.wait(10)
    end
    U.wait(10)
  end

  -- the table is base furniture now: the overworld refuses it
  game.save.inventory = { CRAFT_TABLE = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "ROUTE_1", 10, 30, "down")
  placeViaBag(0)
  check("the overworld refuses the CRAFT TABLE",
        game.save.inventory.CRAFT_TABLE == 1
        and tableNpcAt(10, 31) == nil)

  -- ------------------------------------------- 7. the secret base

  local function baseNpcAt(x, y)
    for _, npc in ipairs(game.overworld.npcs) do
      if npc.def and npc.def.sprite == "SPRITE_SECRET_BASE"
         and npc.cellX == x and npc.cellY == y then
        return npc
      end
    end
    return nil
  end

  -- the base kit arrives with the POKéDEX, through the drop-settle path
  game.save.inventory = {}
  game.save.bagOrder = nil
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_POKEDEX = true
  U.teleport(game, "ROUTE_1", 11, 23, "down")
  U.hold(game, "down", 20)
  U.wait(40)
  mashToOverworld(120)
  check("the POKéDEX brought the SECRET BASE kit and CRAFT TABLE",
        game.save.inventory.SECRET_BASE == 1
        and game.save.inventory.CRAFT_TABLE == 1)

  -- gym badges announce their blueprints, one notice per step
  game.save.inventory.BOULDERBADGE = 1
  game.save.inventory.CASCADEBADGE = 1
  game.save.inventory.THUNDERBADGE = 1
  for _ = 1, 3 do
    U.hold(game, "down", 30)
    U.wait(20)
    mashToOverworld(120)
    U.hold(game, "up", 30)
    U.wait(20)
    mashToOverworld(120)
  end
  check("all three badges announced their blueprints",
        game.mods.exports.palworld_crafting.inspect("told_incubator") == true
        and game.mods.exports.palworld_crafting.inspect("told_lumber") == true
        and game.mods.exports.palworld_crafting.inspect("told_generator") == true)

  -- SELECT pitches it on the faced cell, no bag trip needed
  U.teleport(game, "ROUTE_1", 11, 24, "down")
  check("the base target cell is open",
        game.overworld.map:isWalkableCell(11, 25))
  U.tap(game, "select")
  U.wait(40)
  mashToOverworld(120)
  check("SELECT built the base on the faced cell",
        baseNpcAt(11, 25) ~= nil)
  check("building consumed the item", game.save.inventory.SECRET_BASE == nil)
  U.shot(game, SHOTS .. "13_base_placed.png")

  -- a second base is refused (face an open cell so the one-per-save
  -- check is what fires)
  game.save.inventory = { SECRET_BASE = 1 }
  game.save.bagOrder = nil
  U.tap(game, "left")   -- a short tap turns without stepping
  U.wait(10)
  placeViaBag(0)
  check("a second base is refused",
        game.save.inventory.SECRET_BASE == 1)

  -- enter the base
  game.save.inventory = {}
  game.save.bagOrder = nil
  U.tap(game, "down")   -- face the entrance again
  U.wait(10)
  U.tap(game, "a")
  U.wait(30)
  U.shot(game, SHOTS .. "14_base_menu.png")
  U.tap(game, "a")      -- ENTER
  for _ = 1, 40 do
    if game.overworld and game.overworld.map
       and game.overworld.map.id == "PALCRAFT_BASE" then
      break
    end
    U.wait(10)
  end
  U.wait(30)
  local entered = game.overworld.map.id == "PALCRAFT_BASE"
  check("ENTER warps into the base room", entered)

  if entered then
    local m = game.overworld.map
    check("the room is a walled house interior with a south door mat",
          m.widthCells == 14 and m.heightCells == 12
          and m:isWalkableCell(2, 2) and m:isWalkableCell(7, 7)
          and m:isWalkableCell(5, 9)
          and not m:isWalkableCell(1, 0)    -- wallpaper wall row
          and not m:isWalkableCell(5, 0)
          and not m:isWalkableCell(11, 5)   -- the east wing starts sealed
          and m:isWalkableCell(1, 11)       -- open floor beside the door
          and m:isWalkableCell(4, 11) and m:isWalkableCell(5, 11)) -- the mat
    check("the player arrives standing on the door mat",
          game.overworld.player.cellX == 5
          and game.overworld.player.cellY == 11)

    -- step into the room proper for the screenshot
    mashToOverworld(60)
    U.hold(game, "up", 60)
    U.wait(10)
    U.shot(game, SHOTS .. "15_base_room.png")

    -- the housewarming LEMONADE ball waits on the first visit
    local function lemonadeBall()
      for _, npc in ipairs(game.overworld.npcs) do
        if npc.def and npc.def.item == "FERMENTED_JUICE" then return npc end
      end
      return nil
    end
    check("a FERM.JUICE item ball waits in the new base",
          lemonadeBall() ~= nil)
    U.teleport(game, "PALCRAFT_BASE", 6, 8, "down")
    U.wait(10)
    U.tap(game, "a")
    U.wait(50)
    mashToOverworld(60)
    check("the FERM.JUICE went into the bag",
          game.save.inventory.FERMENTED_JUICE == 1)
    check("the item ball is gone for good", lemonadeBall() == nil)

    -- the CRAFT TABLE at home: place, queue, collect, pack
    game.save.inventory = { CRAFT_TABLE = 1, APRICORN_RED = 6, WOOD = 3 }
    game.save.bagOrder = nil
    U.teleport(game, "PALCRAFT_BASE", 7, 3, "up")
    placeViaBag(1)          -- APRICORN, CRAFT TABLE, WOOD
    check("the table sets up in the base", tableNpcAt(7, 2) ~= nil)
    U.tap(game, "a")
    U.wait(30)
    U.shot(game, SHOTS .. "09_table_menu.png")
    U.tap(game, "a")        -- CRAFT
    U.wait(30)
    local top = game.stack:top()
    check("CRAFT at the table opens the crafting screen",
          top ~= nil and top.isPalcraftScreen == true)
    U.shot(game, SHOTS .. "10_table_craft.png")
    U.tap(game, "a")        -- POKe BALL -> quantity
    U.wait(15)
    U.tap(game, "up")
    U.tap(game, "up")       -- x03: 6 apricorns + 3 wood, the max
    U.wait(10)
    U.tap(game, "a")        -- queue it
    U.wait(15)
    U.shot(game, SHOTS .. "12_table_crafted.png")
    check("the order consumed its materials up front",
          game.save.inventory.APRICORN_RED == nil
          and game.save.inventory.WOOD == nil
          and (game.save.inventory.POKE_BALL or 0) == 0)
    U.tap(game, "b")
    U.wait(15)
    mashToOverworld(120)
    U.wait(420)             -- three 2s orders at test speed, plus slack
    U.teleport(game, "PALCRAFT_BASE", 7, 3, "up")
    U.wait(10)
    U.tap(game, "a")
    U.wait(30)
    U.tap(game, "a")        -- CRAFT reopens; the visit collects
    U.wait(30)
    check("the queue delivered 3 POKE BALLs",
          (game.save.inventory.POKE_BALL or 0) == 3)
    U.shot(game, SHOTS .. "12b_table_collected.png")
    U.tap(game, "b")
    U.wait(15)
    mashToOverworld(120)
    U.tap(game, "a")        -- talk again: PACK UP
    U.wait(30)
    U.tap(game, "down")
    U.wait(8)
    U.tap(game, "a")
    U.wait(30)
    mashToOverworld(120)
    check("PACK UP returned the table",
          game.save.inventory.CRAFT_TABLE == 1
          and tableNpcAt(7, 2) == nil)

    game.save.inventory = {}
    game.save.bagOrder = nil
    U.teleport(game, "PALCRAFT_BASE", 5, 9, "down")
    U.wait(10)

    -- walk back down through the door: pressing down on the mat at the
    -- map edge takes the warp, like leaving a mart
    U.hold(game, "down", 90)
    for _ = 1, 40 do
      if game.overworld and game.overworld.map
         and game.overworld.map.id == "ROUTE_1" then
        break
      end
      U.hold(game, "down", 10)
    end
    U.wait(20)
    check("the south door exits back to the overworld spot",
          game.overworld.map.id == "ROUTE_1"
          and game.overworld.player.cellX == 11
          and game.overworld.player.cellY == 24)
  end

  -- pack it up
  mashToOverworld(60)
  U.tap(game, "a")
  U.wait(30)
  U.tap(game, "down")
  U.wait(8)
  U.tap(game, "a")      -- PACK UP
  U.wait(30)
  mashToOverworld(120)
  check("PACK UP returned the SECRET BASE item",
        game.save.inventory.SECRET_BASE == 1)
  check("the base entrance despawned", baseNpcAt(11, 25) == nil)

  -- --------------------- 8. base contents survive a move

  local function craftTableInRoom()
    if game.overworld.map.id ~= "PALCRAFT_BASE" then return false end
    for _, npc in ipairs(game.overworld.npcs) do
      if npc.def and npc.def.sprite == "SPRITE_CRAFT_TABLE" then
        return true
      end
    end
    return false
  end

  local function enterBase()
    U.tap(game, "a")
    U.wait(30)
    U.tap(game, "a")      -- ENTER
    for _ = 1, 40 do
      if game.overworld.map.id == "PALCRAFT_BASE" then break end
      U.wait(10)
    end
    U.wait(20)
    return game.overworld.map.id == "PALCRAFT_BASE"
  end

  -- pitch the base again and furnish it with a crafting table
  game.save.inventory = { CRAFT_TABLE = 1, SECRET_BASE = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "ROUTE_1", 11, 24, "down")
  placeViaBag(1)          -- rows sort: CRAFT_TABLE first, SECRET_BASE second
  check("base re-placed for the move test", baseNpcAt(11, 25) ~= nil)
  check("entered the base to furnish it", enterBase())

  U.hold(game, "up", 60)  -- off the mat, into the room
  U.wait(10)
  placeViaBag(0)          -- CRAFT_TABLE is the only item left
  check("a crafting table stands in the base", craftTableInRoom())

  -- leave, pack the whole base up, pitch it somewhere else entirely
  U.hold(game, "down", 120)
  for _ = 1, 40 do
    if game.overworld.map.id == "ROUTE_1" then break end
    U.hold(game, "down", 10)
  end
  U.wait(20)
  check("back outside the furnished base",
        game.overworld.map.id == "ROUTE_1")
  U.tap(game, "a")
  U.wait(30)
  U.tap(game, "down")
  U.wait(8)
  U.tap(game, "a")        -- PACK UP
  U.wait(30)
  mashToOverworld(120)
  check("the furnished base packed up",
        game.save.inventory.SECRET_BASE == 1)

  -- the old red-apricorn cell (8,12) was picked up in section 4, so it
  -- is a verified-walkable, now-empty spot on the far side of the route
  game.save.bagOrder = nil
  U.teleport(game, "ROUTE_1", 8, 13, "up")
  placeViaBag(0)
  check("the base pitched at the new spot", baseNpcAt(8, 12) ~= nil)
  check("the move kept the furniture placement", (function()
    local n = 0
    for _, obj in ipairs(game.data.maps.PALCRAFT_BASE.objects or {}) do
      if obj.sprite == "SPRITE_CRAFT_TABLE" then n = n + 1 end
    end
    return n == 1
  end)())

  check("entering at the new spot works", enterBase())
  U.hold(game, "up", 40)
  U.wait(10)
  check("the crafting table survived the move", craftTableInRoom())
  U.shot(game, SHOTS .. "16_base_furniture_kept.png")

  -- the desk PC in the top-left corner is a real Pokémon Center-style
  -- PC: face the monitor cell (0,1) from below and press A
  U.teleport(game, "PALCRAFT_BASE", 0, 2, "up")
  U.wait(10)
  U.shot(game, SHOTS .. "29_base_pc_corner.png")
  U.tap(game, "a")
  U.wait(30)
  local pcMenu = game.stack:top()
  local pcRows = {}
  for _, it in ipairs(pcMenu and pcMenu.items or {}) do
    pcRows[it.label] = true
  end
  check("facing the base PC opens the PC menu",
        pcRows["SOMEONE'S PC"] or pcRows["BILL'S PC"])
  check("the PC menu carries LOG OFF", pcRows["LOG OFF"] ~= nil)
  U.shot(game, SHOTS .. "29_base_pc.png")
  U.tap(game, "b")   -- cancel = LOG OFF
  U.wait(20)
  check("logged off the base PC",
        game.stack:top() == game.overworld)

  -- --------------------- 9. base pals (we are inside the base after §8)

  local function palNpcCount()
    local n = 0
    for _, npc in ipairs(game.overworld.npcs) do
      local s = npc.def and tostring(npc.def.sprite) or ""
      if s == "SPRITE_MONSTER" or s:find("SPRITE_WILD_", 1, true) == 1 then
        n = n + 1
      end
    end
    return n
  end

  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60),
                      Pokemon.new(game.data, "PIDGEY", 12) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  game.save.boxes[1][1] = Pokemon.new(game.data, "RATTATA", 5)
  game.save.currentBox = 1

  -- state-aware navigation: never tap into a widget we haven't confirmed
  local function isPalsList(t) return t.title == "BASE POKéMON" end
  local function isAddList(t) return t.title == "MOVE TO BASE" end
  local function isActionMenu(t)
    return t.items and t.items[1] and t.items[1].label == "TO PARTY"
  end

  -- station talks end in a PACK UP menu: dismiss the text pages with
  -- A, then B out of the menu -- an A-mash would pack the station up!
  local function talkAndCancel()
    for _ = 1, 30 do
      local top = game.stack:top()
      if top == game.overworld then return true end
      if top and top.items and top.items[1] then
        U.tap(game, "b")
      else
        U.tap(game, "a")
      end
      U.wait(10)
    end
    return game.stack:top() == game.overworld
  end

  local function waitFor(pred)
    for _ = 1, 80 do
      local top = game.stack:top()
      if top and pred(top) then return true end
      U.wait(5)
    end
    return false
  end

  -- after a move the menus close, the pals list reopens, and a result
  -- text box sits on top: dismiss text until the list is in front
  local function dismissToPals()
    for _ = 1, 40 do
      local top = game.stack:top()
      if top and isPalsList(top) then return true end
      U.tap(game, "a")
      U.wait(12)
    end
    return false
  end

  U.tap(game, "start")
  U.wait(20)
  local menu9 = game.stack:top()
  local palsRow
  for i, it in ipairs(menu9 and menu9.items or {}) do
    if it.label == "BASE POKéMON" then palsRow = i end
  end
  check("PALS row appears in the base start menu", palsRow ~= nil)
  U.shot(game, SHOTS .. "17_pals_menu_row.png")

  -- the start menu remembers its cursor between opens: navigate by the
  -- live index, not a fixed count
  local function openPalsFromStartMenu()
    local menu = game.stack:top()
    if not (menu and menu.items) then return false end
    local target
    for i, it in ipairs(menu.items) do
      if it.label == "BASE POKéMON" then target = i end
    end
    if not target then return false end
    local cur = menu.index or 1
    local key = target > cur and "down" or "up"
    for _ = 1, math.abs(target - cur) do
      U.tap(game, key)
      U.wait(4)
    end
    U.tap(game, "a")
    return waitFor(isPalsList)
  end
  check("PALS opens the base pals screen", openPalsFromStartMenu())

  -- party mon -> base (SELECT opens the add grid)
  U.tap(game, "select")
  check("the add list opens", waitFor(isAddList))
  U.shot(game, SHOTS .. "18_pals_add_list.png")
  U.tap(game, "right")                   -- CHARIZARD, PIDGEY, RATTATA
  U.wait(6)
  U.tap(game, "a")                       -- pick PIDGEY
  check("back on the pals list after the move", dismissToPals())
  check("the party mon moved in", #game.save.party == 1)
  check("the pal wanders the room", palNpcCount() == 1)

  -- PC mon -> base
  U.tap(game, "select")
  check("the add list reopens", waitFor(isAddList))
  U.tap(game, "right")                   -- CHARIZARD, RATTATA(BOX1)
  U.wait(6)
  U.tap(game, "a")                       -- pick RATTATA
  check("back on the pals list again", dismissToPals())
  check("the PC mon moved in", #game.save.boxes[1] == 0)
  check("two pals wander the room", palNpcCount() == 2)

  -- the last party mon refuses
  U.tap(game, "select")
  check("the add list opens once more", waitFor(isAddList))
  U.tap(game, "a")                       -- only CHARIZARD is listed
  check("refusal returns to the pals list", dismissToPals())
  check("the last party mon stays put", #game.save.party == 1)

  U.tap(game, "b")                       -- close, walk up to the pals
  U.wait(20)
  U.hold(game, "up", 50)
  U.wait(15)
  U.shot(game, SHOTS .. "19_pals_in_room.png")

  -- send one home to the party, the other to the PC
  U.tap(game, "start")
  U.wait(20)
  check("PALS reopens", openPalsFromStartMenu())
  U.tap(game, "a")                       -- cursor starts on the first pal
  check("the pal action menu opens", waitFor(isActionMenu))
  U.tap(game, "a")                       -- TO PARTY
  check("back on the pals list after TO PARTY", dismissToPals())
  check("the pal rejoined the party", #game.save.party == 2)

  U.tap(game, "a")                       -- the remaining pal is cell 1
  check("the action menu opens again", waitFor(isActionMenu))
  U.tap(game, "down")
  U.wait(6)
  U.tap(game, "a")                       -- TO PC
  check("back on the pals list after TO PC", dismissToPals())
  local boxTotal = 0
  for _, box in ipairs(game.save.boxes) do boxTotal = boxTotal + #box end
  check("the pal went back to the PC", boxTotal == 1)
  check("the room is empty of pals again", palNpcCount() == 0)
  U.tap(game, "b")
  U.wait(15)
  mashToOverworld(60)

  -- --------------------- 10. the egg incubator
  -- (run with PALCRAFT_BREED_SECONDS=5 so the brew fits a test run)

  local function incubatorAt(x, y, sprite)
    for _, npc in ipairs(game.overworld.npcs) do
      local s = npc.def and tostring(npc.def.sprite) or ""
      if npc.cellX == x and npc.cellY == y then
        if sprite then
          if s == sprite then return npc end
        elseif s:find("SPRITE_INCUBATOR", 1, true) == 1 then
          return npc
        end
      end
    end
    return nil
  end

  local function isIncMenu(t)
    return t.items and t.items[1]
      and (t.items[1].label == "ASSIGN" or t.items[1].label == "ADD JUICE"
           or t.items[1].label == "HATCH")
  end

  -- refused outside the base
  game.save.inventory = { EGG_INCUBATOR = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "ROUTE_1", 10, 28, "down")
  placeViaBag(0)
  check("the INCUBATOR refuses outside the base",
        game.save.inventory.EGG_INCUBATOR == 1)

  -- placed inside (before pals wander in and can block the cell)
  U.teleport(game, "PALCRAFT_BASE", 5, 5, "up")
  placeViaBag(0)
  check("the INCUBATOR set up in the base", incubatorAt(5, 4) ~= nil)
  check("placement consumed the item",
        game.save.inventory.EGG_INCUBATOR == nil)
  U.shot(game, SHOTS .. "21_incubator_placed.png")

  -- three residents: a curated pairing (PIDGEY x SPEAROW hatches
  -- FARFETCH'D) plus a CHARIZARD that matches neither -- the pickers
  -- must grey it out
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60),
                      Pokemon.new(game.data, "PIDGEY", 12),
                      Pokemon.new(game.data, "SPEAROW", 9),
                      Pokemon.new(game.data, "RATTATA", 5) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS reachable for parent setup", openPalsFromStartMenu())
  for _ = 1, 2 do
    U.tap(game, "select")
    waitFor(isAddList)
    U.tap(game, "right")  -- cell 2: PIDGEY first pass, SPEAROW second
    U.wait(6)
    U.tap(game, "a")
    dismissToPals()
  end
  U.tap(game, "select")   -- and CHARIZARD, cell 1
  waitFor(isAddList)
  U.tap(game, "a")
  dismissToPals()
  U.tap(game, "b")
  U.wait(20)
  check("three POKéMON live in the base", palNpcCount() == 3)

  -- assign the parents at the incubator
  U.tap(game, "a")
  check("the incubator menu opens", waitFor(isIncMenu))
  U.tap(game, "a")        -- ASSIGN
  check("parent 1 list opens",
        waitFor(function(t) return t.title == "PARENT 1" end))
  local p1list = game.stack:top()
  check("the loner greys out even as parent 1",
        p1list.entries and #p1list.entries == 3
        and p1list.entries[3].species == "CHARIZARD"
        and p1list.entries[3].disabled == true
        and p1list.entries[1].disabled == nil)
  check("the panel shows partner and child, catalog style",
        p1list.entries[1].infoLines
        and p1list.entries[1].infoLines[1] == "BREEDS WITH:"
        and tostring(p1list.entries[1].infoLines[2] or "")
              :find("\226\150\182", 1, true) ~= nil)
  check("even a no-partner cell teaches its pairings",
        p1list.entries[3].disabled == true
        and p1list.entries[3].infoLines
        and tostring(p1list.entries[3].infoLines[2] or "")
              :find("\226\150\182", 1, true) ~= nil)
  U.tap(game, "a")        -- PIDGEY
  check("parent 2 list opens",
        waitFor(function(t) return t.title == "PARENT 2" end))
  local p2list = game.stack:top()
  check("the promising partner wears the ?! hint",
        p2list.entries and p2list.entries[1]
        and p2list.entries[1].right == "?!")
  check("the incompatible partner greys out",
        p2list.entries[2] and p2list.entries[2].species == "CHARIZARD"
        and p2list.entries[2].disabled == true)
  U.tap(game, "right")    -- cursor onto the greyed CHARIZARD
  U.wait(6)
  U.shot(game, SHOTS .. "28_pair_hint.png")
  U.tap(game, "a")        -- refused with a gentle letdown
  local backOnPicker = false
  for _ = 1, 20 do
    U.wait(10)
    if game.stack:top() == p2list then
      backOnPicker = true
      break
    end
    U.tap(game, "a")      -- finish typing, then dismiss
  end
  check("the grey cell refused the pick", backOnPicker)
  U.tap(game, "left")     -- back to SPEAROW
  U.wait(6)
  U.tap(game, "a")        -- SPEAROW
  U.wait(50)
  U.tap(game, "a")        -- dismiss "settled in!"
  U.wait(20)
  mashToOverworld(60)

  -- fuel it: refused dry, then a LEMONADE starts the brew
  U.tap(game, "a")
  check("the fueled menu opens", waitFor(isIncMenu))
  U.tap(game, "a")        -- ADD LEMONADE (none yet)
  U.wait(50)
  U.tap(game, "a")        -- dismiss "needs a LEMONADE"
  U.wait(15)
  mashToOverworld(60)
  game.save.inventory.FERMENTED_JUICE = 1
  U.tap(game, "a")
  waitFor(isIncMenu)
  U.tap(game, "a")        -- ADD LEMONADE
  U.wait(50)
  U.tap(game, "a")        -- dismiss "hums to life!"
  U.wait(15)
  mashToOverworld(60)
  check("the FERM.JUICE was consumed",
        game.save.inventory.FERMENTED_JUICE == nil)

  -- pace around until the egg appears in the dome; four directions,
  -- so a wandering pal parked on one neighbor can't starve the steps
  local eggShown = false
  for lap = 1, 30 do
    U.hold(game, "down", 18)
    U.hold(game, "up", 18)
    U.hold(game, "left", 18)
    U.hold(game, "right", 18)
    if incubatorAt(5, 4, "SPRITE_INCUBATOR_EGG") then
      eggShown = true
      break
    end
    if lap % 10 == 0 then
      local ex = game.mods.exports.palworld_crafting
      local st = ex.inspect("incubator") or {}
      U.log("  dome lap", lap, "startedAt:", tostring(st.startedAt),
            "cold:", tostring(st.cold),
            "shownEgg:", tostring(st.shownEgg),
            "kindler:", ex.bestCrewLevel("KINDLING"),
            "playTime:", math.floor(game.save.playTime or 0))
    end
  end
  U.teleport(game, "PALCRAFT_BASE", 5, 5, "up")
  U.wait(10)
  if not eggShown then
    eggShown = incubatorAt(5, 4, "SPRITE_INCUBATOR_EGG") ~= nil
  end
  check("an egg appeared in the dome", eggShown)
  -- the pacing loop can end mid-step or drifted: reset to the exact
  -- interaction spot before talking
  U.teleport(game, "PALCRAFT_BASE", 5, 5, "up")
  U.wait(15)
  U.shot(game, SHOTS .. "22_incubator_egg.png")

  -- hatch it
  local partyBefore = #game.save.party
  U.tap(game, "a")
  check("the hatch menu opens", waitFor(isIncMenu))
  U.tap(game, "a")        -- HATCH
  U.wait(60)
  U.shot(game, SHOTS .. "23_hatched.png")
  U.tap(game, "a")        -- dismiss the hatch text
  U.wait(20)
  mashToOverworld(60)
  check("the hatchling joined the party",
        #game.save.party == partyBefore + 1)
  local baby = game.save.party[#game.save.party]
  check("it hatched at level 1", baby and baby.level == 1)
  check("the hatchling carries the bred mark",
        baby and baby.bred == true)
  check("the hatchling hatches at one star",
        baby and baby.dvs and baby.dvs.stars == 1)
  check("the pairing hatched a FARFETCH'D",
        baby and baby.species == "FARFETCHD")
  check("the pokedex recorded it",
        game.save.pokedex.owned.FARFETCHD == true)
  check("the dome is empty again",
        incubatorAt(5, 4, "SPRITE_INCUBATOR") ~= nil)

  -- pack it up (the menu reshapes once parents clear: find the row)
  U.tap(game, "a")
  waitFor(isIncMenu)
  local incMenu = game.stack:top()
  local packRow
  for i, it in ipairs(incMenu.items or {}) do
    if it.label == "PACK UP" then packRow = i end
  end
  for _ = 1, (packRow or 1) - 1 do
    U.tap(game, "down")
    U.wait(6)
  end
  U.tap(game, "a")
  U.wait(50)
  U.tap(game, "a")        -- dismiss
  U.wait(15)
  mashToOverworld(60)
  check("PACK UP returned the INCUBATOR",
        game.save.inventory.EGG_INCUBATOR == 1)
  check("the incubator despawned", incubatorAt(5, 4) == nil)

  -- --------------------- 11. breed-only species left the wild

  -- snapshot of main.lua's BREED_ONLY list: update alongside curation
  local breedOnly = {}
  for _, sp in ipairs({
    "EKANS",
    "VENONAT", "DIGLETT", "ABRA", "PONYTA", "FARFETCHD", "GRIMER",
    "SHELLDER", "ONIX", "CUBONE", "LICKITUNG", "CHANSEY", "KANGASKHAN",
    "HORSEA", "STARYU", "SCYTHER", "MAGMAR", "PINSIR", "TAUROS",
    "LAPRAS", "DITTO", "EEVEE", "OMASTAR", "AERODACTYL", "SNORLAX",
    "ZAPDOS", "DRATINI", "MEWTWO", "MEW",
  }) do breedOnly[sp] = true end
  local wildBad, brokenTables = 0, 0
  for mapId, enc in pairs(game.data.encounters) do
    for _, terrain in ipairs({ "grass", "water" }) do
      local t = enc[terrain]
      if t and t.slots then
        if #t.slots ~= 10 then brokenTables = brokenTables + 1 end
        for _, s in ipairs(t.slots) do
          if not s.species then brokenTables = brokenTables + 1 end
          if s.species and breedOnly[s.species] then
            wildBad = wildBad + 1
            U.log("  breed-only in the wild:", mapId, terrain, s.species)
          end
        end
      end
    end
  end
  check("no breed-only species roam the wild", wildBad == 0)
  check("every encounter table is still ten full slots", brokenTables == 0)

  local rodBad, rodBroken = 0, 0
  for mapId, list in pairs(game.data.field.superRod or {}) do
    if #list < 1 then rodBroken = rodBroken + 1 end
    for _, c in ipairs(list) do
      if not c.species then rodBroken = rodBroken + 1 end
      if c.species and breedOnly[c.species] then
        rodBad = rodBad + 1
        U.log("  breed-only on the SUPER ROD:", mapId, c.species)
      end
    end
  end
  check("no breed-only species bite the SUPER ROD", rodBad == 0)

  -- SANDSHREW left the breeding chain to staff the LUMBERING trade:
  -- the EKANS/SANDSHREW healing must now put it in Red's early grass
  local shrewEarly = false
  for _, mapId in ipairs({ "ROUTE_4", "ROUTE_8", "ROUTE_9",
                           "ROUTE_10", "ROUTE_11" }) do
    local enc = game.data.encounters[mapId]
    for _, s in ipairs(enc and enc.grass and enc.grass.slots or {}) do
      if s.species == "SANDSHREW" then shrewEarly = true end
    end
  end
  check("SANDSHREW prowls the early routes", shrewEarly)
  check("every rod pool is intact", rodBroken == 0)

  -- version-exclusive pairs: if one side is wild, its counterpart must
  -- be wild too (unless deliberately breed-only)
  local wildNow = {}
  for _, enc in pairs(game.data.encounters) do
    for _, terrain in ipairs({ "grass", "water" }) do
      local t = enc[terrain]
      for _, s in ipairs(t and t.slots or {}) do
        if s.species then wildNow[s.species] = true end
      end
    end
  end
  for _, list in pairs(game.data.field.superRod or {}) do
    for _, c in ipairs(list) do
      if c.species then wildNow[c.species] = true end
    end
  end
  local PAIRS = {
    { "WEEDLE", "CATERPIE" }, { "EKANS", "SANDSHREW" },
    { "ODDISH", "BELLSPROUT" }, { "MANKEY", "MEOWTH" },
    { "GROWLITHE", "VULPIX" }, { "SCYTHER", "PINSIR" },
    { "ELECTABUZZ", "MAGMAR" },
  }
  local pairBad = 0
  for _, p in ipairs(PAIRS) do
    for k = 1, 2 do
      local here, there = p[k], p[3 - k]
      if wildNow[here] and not wildNow[there] and not breedOnly[there] then
        pairBad = pairBad + 1
        U.log("  version exclusive:", there, "missing while", here, "roams")
      end
    end
  end
  check("no version-exclusive gaps in the wild", pairBad == 0)

  -- --------------------- 12. the grape farm (PALCRAFT_GROW_SECONDS=5)

  local function farmNpcAt(x, y, prefix)
    for _, npc in ipairs(game.overworld.npcs) do
      local s = npc.def and tostring(npc.def.sprite) or ""
      if npc.cellX == x and npc.cellY == y
         and s:find(prefix, 1, true) == 1 then
        return s
      end
    end
    return nil
  end
  local function pace(n)
    for _ = 1, n do
      U.hold(game, "down", 18)
      U.hold(game, "up", 18)
    end
    U.wait(30)   -- let the last step land before any menu input
  end

  -- plant with no grower/waterer in the base: the vine must stall
  -- (current residents are PIDGEY and SPEAROW -- flying, no help at all)
  game.save.inventory = { GRAPE_SEED = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", 2, 6, "up")
  placeViaBag(0)
  check("a vine took root", farmNpcAt(2, 5, "SPRITE_VINE") ~= nil)
  -- the tilled patch is real floor: cave tiles that stay visible
  -- under a planted vine, and seeds refuse anything that is not dirt
  check("the patch is cave-floor tile underfoot",
        game.overworld.map:cellTile(3, 4) == 96
        and game.overworld.map:cellTile(3, 5) == 96)
  check("the crops can't be trampled",
        not game.overworld.map:isWalkableCell(3, 5)
        and not game.overworld.map:isWalkableCell(2, 4))
  game.save.inventory = { GRAPE_SEED = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", 5, 6, "up")
  placeViaBag(0)
  check("seeds refuse plain floor",
        game.save.inventory.GRAPE_SEED == 1)
  game.save.inventory.GRAPE_SEED = nil

  -- pressing A on bare dirt: hint without a seed, prompt with one
  U.teleport(game, "PALCRAFT_BASE", 3, 5, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(40)
  mashToOverworld(60)     -- just a hint text, no menu
  check("bare dirt asks for a seed first",
        farmNpcAt(3, 4, "SPRITE_VINE") == nil)
  game.save.inventory.GRAPE_SEED = 1
  U.tap(game, "a")
  U.wait(40)
  U.tap(game, "a")        -- "Plant a GRAPE SEED here?" -> YES
  U.wait(30)
  mashToOverworld(60)
  check("A on the dirt plants the seed",
        farmNpcAt(3, 4, "SPRITE_VINE") ~= nil
        and game.save.inventory.GRAPE_SEED == nil)

  U.teleport(game, "PALCRAFT_BASE", 2, 6, "up")
  pace(10)
  check("without a crew the vine stalls",
        farmNpcAt(2, 5, "SPRITE_VINE_GROWN") == nil)

  -- crew up: ODDISH grows, SQUIRTLE waters
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60),
                      Pokemon.new(game.data, "ODDISH", 10),
                      Pokemon.new(game.data, "SQUIRTLE", 10) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS opens for the farm crew", openPalsFromStartMenu())
  for _ = 1, 2 do
    U.tap(game, "select")
    waitFor(isAddList)
    U.tap(game, "right")
    U.wait(6)
    U.tap(game, "a")
    dismissToPals()
  end
  U.tap(game, "b")
  U.wait(15)

  local grown = false
  for _ = 1, 30 do
    pace(2)
    if farmNpcAt(2, 5, "SPRITE_VINE_GROWN") then
      grown = true
      break
    end
  end
  check("with a crew the vine ripened", grown)
  U.teleport(game, "PALCRAFT_BASE", 2, 6, "up")
  U.wait(15)
  U.shot(game, SHOTS .. "24_vine_grown.png")

  -- harvest by hand
  U.tap(game, "a")
  U.wait(50)
  U.tap(game, "a")        -- dismiss "Picked N GRAPES..."
  U.wait(15)
  mashToOverworld(60)
  local picked = game.save.inventory.GRAPES or 0
  check("the harvest paid out its one grape", picked == 1)
  check("no seed comes back -- vines are one-shot",
        game.save.inventory.GRAPE_SEED == nil)
  check("the trellis cleared",
        farmNpcAt(2, 5, "SPRITE_VINE") == nil)

  -- ferment three grapes at the crafting table from section 8
  local tx, ty
  for _, npc in ipairs(game.overworld.npcs) do
    if npc.def and npc.def.sprite == "SPRITE_CRAFT_TABLE" then
      tx, ty = npc.cellX, npc.cellY
    end
  end
  check("the crafting table still stands in the base", tx ~= nil)
  game.save.inventory = { GRAPES = 3 }   -- topped up: harvests pay 1 now
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT
  U.wait(25)
  for _ = 1, 4 do         -- down to the FERM.JUICE recipe (row 5)
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- quantity x01
  U.wait(15)
  U.tap(game, "a")        -- queue the brew
  U.wait(20)
  U.shot(game, SHOTS .. "25_juice_crafted.png")
  check("the GRAPES went into the vat up front",
        game.save.inventory.GRAPES == nil)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(160)             -- 2s of brewing at test speed, plus slack
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT again; the visit collects the juice
  U.wait(25)
  check("three GRAPES fermented into juice",
        game.save.inventory.FERMENTED_JUICE == 1)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- automation: CHEST + a FIGHTING foreman = self-harvesting vines
  game.save.inventory = { GRAPE_SEED = 1, STORAGE_CHEST = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", 8, 6, "up")
  placeViaBag(1)          -- GRAPE_SEED sorts first; row 2 is the CHEST
  check("the CHEST is set", farmNpcAt(8, 5, "SPRITE_CHEST") ~= nil)
  U.teleport(game, "PALCRAFT_BASE", 2, 6, "up")
  placeViaBag(0)          -- the seed is the only item left
  check("a new vine took root", farmNpcAt(2, 5, "SPRITE_VINE") ~= nil)

  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60),
                      Pokemon.new(game.data, "MACHOP", 12) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS opens for the foreman", openPalsFromStartMenu())
  U.tap(game, "select")
  waitFor(isAddList)
  U.tap(game, "right")
  U.wait(6)
  U.tap(game, "a")
  dismissToPals()
  U.tap(game, "b")
  U.wait(15)

  pace(16)                -- one full cycle plus the auto-harvest
  check("the hauler cleared the spent vine",
        farmNpcAt(2, 5, "SPRITE_VINE") == nil
        and farmNpcAt(2, 5, "SPRITE_VINE_GROWN") == nil)

  U.teleport(game, "PALCRAFT_BASE", 8, 6, "up")
  U.wait(10)
  U.tap(game, "a")
  check("the CHEST opens",
        waitFor(function(t) return t.title == "CHEST" end))
  U.shot(game, SHOTS .. "26_chest_contents.png")
  local chestTop = game.stack:top()
  local grapesIdx
  for i, it in ipairs(chestTop.items or {}) do
    if it.value == "GRAPES" then grapesIdx = i end
  end
  check("the TRANSPORT worker stashed grapes in the CHEST",
        grapesIdx ~= nil)
  for _ = 1, (grapesIdx or 1) - 1 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- withdraw the GRAPES stack
  U.wait(50)
  U.tap(game, "a")        -- dismiss "Took N GRAPES."
  U.wait(15)
  mashToOverworld(60)
  check("the automated grapes reached the bag",
        (game.save.inventory.GRAPES or 0) >= 1)

  -- --------------------- 13. work suitabilities

  U.tap(game, "start")
  U.wait(20)
  local function openWorkFromStartMenu()
    local menu = game.stack:top()
    if not (menu and menu.items) then return false end
    local target
    for i, it in ipairs(menu.items) do
      if it.label == "WORK SKILLS" then target = i end
    end
    if not target then return false end
    local cur = menu.index or 1
    local key = target > cur and "down" or "up"
    for _ = 1, math.abs(target - cur) do
      U.tap(game, key)
      U.wait(4)
    end
    U.tap(game, "a")
    return waitFor(function(t) return t.title == "WORK SKILLS" end)
  end
  check("WORK SKILLS opens from the base start menu",
        openWorkFromStartMenu())

  local grid = game.stack:top()
  check("the browser is the sprite grid", grid.kind == "workgrid")
  check("all 151 POKéMON are on the grid",
        grid.mons and #grid.mons == 151)
  check("the grid leads with BULBASAUR",
        grid.mons and grid.mons[1].id == "BULBASAUR")
  check("BULBASAUR gathers and brews (both types work)",
        grid.mons and #grid.mons[1].suits == 2
        and grid.mons[1].suits[1].job == "GATHERING"
        and grid.mons[1].suits[1].level == 1
        and grid.mons[1].suits[2].job == "MEDICINE")
  -- entries exist in data whether or not they're scrolled into view
  check("MEWTWO shows its capped RESEARCH",
        grid.mons and grid.mons[150].id == "MEWTWO"
        and grid.mons[150].suits[1].job == "RESEARCH"
        and grid.mons[150].suits[1].level == 4)
  -- a NON-override psychic: the job must come from the type itself
  -- (the ROM spells it PSYCHIC_TYPE; a bare-PSYCHIC key never matches)
  check("ALAKAZAM researches from its own type",
        grid.mons and grid.mons[65].id == "ALAKAZAM"
        and grid.mons[65].suits[1].job == "RESEARCH"
        and grid.mons[65].suits[1].level == 3)
  U.shot(game, SHOTS .. "30_work_grid.png")

  -- the info panel follows the cursor with no A press at all
  U.tap(game, "right")
  U.wait(6)
  U.tap(game, "right")
  U.wait(6)
  check("the cursor roamed to VENUSAUR without a click",
        grid.index == 3 and grid.mons[3].id == "VENUSAUR")
  U.tap(game, "down")
  U.wait(6)
  check("a down press moves a full grid row",
        grid.index == 11 and grid.mons[11].id == "METAPOD")
  U.shot(game, SHOTS .. "31_work_grid_moved.png")

  -- the tallest card: a three-job single must fit the panel uncut
  for _ = 1, 9 do
    U.tap(game, "down")
    U.wait(5)
  end
  check("scrolled down to FARFETCH'D",
        grid.index == 83 and grid.mons[83].id == "FARFETCHD")
  check("its three jobs are all on the card",
        #grid.mons[83].suits == 3
        and grid.mons[83].suits[2].job == "GATHERING"
        and grid.mons[83].suits[2].level == 2)
  U.shot(game, SHOTS .. "33_work_grid_three_jobs.png")

  -- SELECT opens the job filter; COOLING is Kanto's scarcest trade
  U.tap(game, "select")
  check("the filter picker opens on SELECT",
        waitFor(function(t) return t.title == "FILTER" end))
  for _ = 1, 7 do
    U.tap(game, "down")
    U.wait(4)
  end
  U.tap(game, "a")           -- COOLING
  U.wait(15)
  check("the grid filtered to the five COOLING workers",
        grid.filter == "COOLING" and #grid.view == 5
        and grid.view[1].id == "DEWGONG"
        and grid.view[5].id == "ARTICUNO")
  U.shot(game, SHOTS .. "34_work_grid_filtered.png")
  U.tap(game, "select")      -- picker again; row 1 is ALL
  U.wait(10)
  U.tap(game, "a")
  U.wait(10)
  check("ALL restores the full grid",
        grid.filter == nil and #grid.view == 151)
  U.tap(game, "a")           -- A is inert on the grid now
  U.wait(10)
  check("A no longer opens anything on the grid",
        game.stack:top() == grid)
  -- B never activates a menu row, so mashing it is the safe way out
  for _ = 1, 12 do
    if game.stack:top() == game.overworld then break end
    U.tap(game, "b")
    U.wait(8)
  end

  -- the same card hangs off every base POKéMON's action menu
  U.tap(game, "start")
  U.wait(20)
  check("PALS reopens for the skills check", openPalsFromStartMenu())
  U.tap(game, "a")           -- cursor starts on the first pal
  U.wait(15)
  local acts = game.stack:top()
  local skillsRow
  for i, it in ipairs(acts and acts.items or {}) do
    if it.label == "SKILLS" then skillsRow = i end
  end
  check("the action menu grew a SKILLS row", skillsRow ~= nil)
  for _ = 1, (skillsRow or 1) - 1 do
    U.tap(game, "down")
    U.wait(4)
  end
  U.tap(game, "a")
  U.wait(15)
  local palCard = game.stack:top()
  check("the pal's card shows leveled jobs",
        palCard.items and palCard.items[1]
        and tostring(palCard.items[1].right):find("^Lv%.%d$") ~= nil)
  U.shot(game, SHOTS .. "32_pal_skills.png")
  for _ = 1, 12 do
    if game.stack:top() == game.overworld then break end
    U.tap(game, "b")
    U.wait(8)
  end

  -- --------------------- 14. the power grid: generator, furnace, MK2

  -- craft both stations at the base table (still standing from §8)
  game.save.inventory = { ORE = 5, WOOD = 4, THUNDERBADGE = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT
  U.wait(25)
  local mk1 = game.stack:top()
  check("the base table is plain MK1 without power",
        mk1.isPalcraftScreen and mk1.mk2 == false
        and #mk1.recipes == 17)
  for _ = 1, 5 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- GENERATOR -> quantity
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "down")
  U.wait(5)
  U.tap(game, "a")        -- FURNACE -> quantity
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(300)             -- two 2s orders at test speed, plus slack
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT collects the finished stations
  U.wait(25)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  check("both stations came off the queue",
        (game.save.inventory.GENERATOR or 0) == 1
        and (game.save.inventory.FURNACE or 0) == 1)

  -- place them along the wall row
  game.save.bagOrder = nil     -- FURNACE, GENERATOR sort in that order
  U.teleport(game, "PALCRAFT_BASE", 6, 6, "up")
  placeViaBag(1)               -- GENERATOR
  check("the GENERATOR is bolted down",
        farmNpcAt(6, 5, "SPRITE_GENERATOR") ~= nil)
  U.teleport(game, "PALCRAFT_BASE", 7, 6, "up")
  placeViaBag(0)               -- FURNACE, the only item left
  check("the FURNACE is bricked in",
        farmNpcAt(7, 5, "SPRITE_FURNACE") ~= nil)
  U.shot(game, SHOTS .. "35_stations_placed.png")

  -- a generator without an ELECTRIC type is furniture
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  local still = game.stack:top()
  check("no ELECTRIC crew, no MK2", still.mk2 == false)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- PIKACHU reports for GENERATING duty
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 20),
                      Pokemon.new(game.data, "RATTATA", 5) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS opens for the electrician", openPalsFromStartMenu())
  U.tap(game, "select")
  waitFor(isAddList)
  local addList = game.stack:top()
  check("the add picker shows each POKéMON's star",
        addList.entries and addList.entries[1]
        and tostring(addList.entries[1].label):find("[1]", 1, true) ~= nil)
  U.tap(game, "a")             -- PIKACHU, cell 1
  dismissToPals()
  U.tap(game, "b")
  U.wait(15)

  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  local mk2scr = game.stack:top()
  check("the powered base table is the MK2",
        mk2scr.mk2 == true and #mk2scr.recipes == 24
        and mk2scr.recipes[18].ball == "FIRE_STONE")
  U.shot(game, SHOTS .. "36_mk2_table.png")
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- the grid coming alive announces the unlock, once, on the next step
  U.hold(game, "down", 30)
  U.wait(20)
  mashToOverworld(120)
  U.hold(game, "up", 30)
  U.wait(20)
  mashToOverworld(120)
  check("the powered grid announced the MK2 unlock",
        game.mods.exports.palworld_crafting.inspect("told_mk2") == true)

  -- smelt two ORE with CHARIZARD stoking (KINDLING 3 -> 2x)
  game.save.inventory.ORE = 2
  U.teleport(game, "PALCRAFT_BASE", 7, 6, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(30)
  local fmenu = game.stack:top()
  check("the furnace menu opens",
        fmenu.items and fmenu.items[1]
        and fmenu.items[1].label == "SMELT")
  U.tap(game, "a")        -- SMELT
  U.wait(15)
  U.tap(game, "up")       -- x02
  U.wait(6)
  U.tap(game, "a")
  U.wait(40)
  mashToOverworld(120)
  check("the ore went into the furnace",
        game.save.inventory.ORE == nil)
  U.wait(300)             -- the lazy clock covers the wait on revisit
  U.teleport(game, "PALCRAFT_BASE", 7, 6, "up")
  U.wait(10)
  U.tap(game, "a")        -- the visit ticks; the hauler banks the bars
  U.wait(40)
  talkAndCancel()
  local exd = game.mods.exports.palworld_crafting
  local bank = exd.inspect("chest") or {}
  check("the hauler banked the INGOTs in the CHEST",
        (bank.items and bank.items.INGOT or 0) >= 2)
  -- withdraw them for the stone craft
  U.teleport(game, "PALCRAFT_BASE", 8, 6, "up")
  U.wait(10)
  U.tap(game, "a")
  check("the CHEST opens for the bars",
        waitFor(function(t) return t.title == "CHEST" end))
  local bars = game.stack:top()
  local barIdx
  for i, it in ipairs(bars.items or {}) do
    if it.value == "INGOT" then barIdx = i end
  end
  for _ = 1, (barIdx or 1) - 1 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")
  U.wait(50)
  U.tap(game, "a")
  U.wait(15)
  mashToOverworld(60)
  check("the furnace delivered 2 INGOTs",
        (game.save.inventory.INGOT or 0) >= 2)
  U.shot(game, SHOTS .. "37_ingots_smelted.png")

  -- a FIRE STONE from the MK2 list closes the loop
  game.save.inventory.APRICORN_RED = 3
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  for _ = 1, 17 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- FIRE STONE -> quantity x01
  U.wait(15)
  U.tap(game, "a")
  U.wait(15)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(200)
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  check("the MK2 table forged a FIRE STONE",
        (game.save.inventory.FIRE_STONE or 0) == 1)
  U.shot(game, SHOTS .. "38_fire_stone.png")
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- --------------------- 15. the medicine bench and training dummy

  -- craft both at the (still MK2) base table
  game.save.inventory = { WOOD = 7, ORE = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT
  U.wait(25)
  for _ = 1, 7 do
    U.tap(game, "down")   -- MED.BENCH is row 8 of the MK2 list
    U.wait(5)
  end
  U.tap(game, "a")
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "down")     -- TRN.DUMMY, row 8
  U.wait(5)
  U.tap(game, "a")
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(300)
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  check("bench and dummy came off the queue",
        (game.save.inventory.MED_BENCH or 0) == 1
        and (game.save.inventory.TRAIN_DUMMY or 0) == 1)

  -- place them on the lower floor
  game.save.bagOrder = nil   -- MED.BENCH sorts before TRN.DUMMY
  U.teleport(game, "PALCRAFT_BASE", 6, 8, "up")
  placeViaBag(0)
  check("the MEDICINE BENCH is set",
        farmNpcAt(6, 7, "SPRITE_MED_BENCH") ~= nil)
  U.teleport(game, "PALCRAFT_BASE", 7, 8, "up")
  placeViaBag(0)
  check("the TRAINING DUMMY is staked",
        farmNpcAt(7, 7, "SPRITE_TRAIN_DUMMY") ~= nil)

  -- brew: ODDISH is the medic (MEDICINE 1); tier 2 stays locked
  game.save.inventory.GRAPES = 4
  U.teleport(game, "PALCRAFT_BASE", 6, 8, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(30)
  U.tap(game, "a")        -- BREW
  U.wait(25)
  local med = game.stack:top()
  check("the brew screen opens", med.isMedBenchScreen == true)
  U.tap(game, "a")        -- POTION -> quantity
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  check("the potion went into the vat",
        (game.save.inventory.GRAPES or 0) == 2)
  U.tap(game, "down")     -- ANTIDOTE
  U.wait(6)
  U.tap(game, "down")     -- SUPER POTION, tier 2
  U.wait(6)
  U.tap(game, "a")        -- locked: ODDISH is only Lv.1
  U.wait(10)
  check("tier 2 refuses an apprentice medic",
        med.message == "NEEDS MEDICINE Lv.2!")
  U.shot(game, SHOTS .. "39_med_bench.png")
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(200)             -- 2s brew at test speed, plus slack
  U.teleport(game, "PALCRAFT_BASE", 6, 8, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(30)
  U.tap(game, "a")        -- BREW: the visit ticks the vat
  U.wait(25)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  local exb = game.mods.exports.palworld_crafting
  local bank2 = exb.inspect("chest") or {}
  check("the hauler shelved the POTION in the CHEST",
        (bank2.items and bank2.items.POTION or 0) >= 1)

  -- the dummy: MACHOP trains, candy drips on the play clock
  U.wait(300)             -- PALCRAFT_CANDY_SECONDS=2 in the test env
  U.teleport(game, "PALCRAFT_BASE", 7, 8, "up")
  U.wait(10)
  U.tap(game, "a")        -- collects on talk
  U.wait(40)
  for _ = 1, 30 do        -- dismiss text, B out of the PACK UP menu
    local top = game.stack:top()
    if top == game.overworld then break end
    if top and top.items and top.items[1] then
      U.tap(game, "b")
    else
      U.tap(game, "a")
    end
    U.wait(10)
  end
  local exc = game.mods.exports.palworld_crafting
  local candyBank = exc.inspect("chest") or {}
  check("the dojo paid out RARE CANDY",
        (game.save.inventory.RARE_CANDY or 0) >= 1
        or ((candyBank.items and candyBank.items.RARE_CANDY) or 0) >= 1)
  U.shot(game, SHOTS .. "40_dummy_candy.png")

  -- --------------------- 16. research, shrine, and the east wing

  -- the wing starts sealed
  check("the east wing starts sealed",
        not game.overworld.map:isWalkableCell(11, 5))

  -- nine residents wander this floor and one may be parked exactly on
  -- the target cell: walk the candidate list until a placement lands,
  -- and report where it did
  local function placeUntilSet(candidates, downs, sprite)
    for _ = 1, 3 do
      for _, c in ipairs(candidates) do
        U.teleport(game, "PALCRAFT_BASE", c[1], c[2] + 1, "up")
        U.wait(10)
        placeViaBag(downs)
        if farmNpcAt(c[1], c[2], sprite) then return c[1], c[2] end
        local why = "clear"
        if not game.overworld.map:isWalkableCell(c[1], c[2]) then
          why = "unwalkable"
        end
        for _, npc in ipairs(game.overworld.npcs or {}) do
          if npc.cellX == c[1] and npc.cellY == c[2] then
            why = tostring(npc.def and npc.def.sprite)
          end
        end
        U.log("  refused at", c[1], c[2], "->", why)
      end
      U.wait(60)
    end
    return nil
  end

  -- craft the desk and the shrine (rows 9 and 10)
  game.save.inventory = { WOOD = 3, ORE = 3, INGOT = 2 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT
  U.wait(25)
  for _ = 1, 9 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- RSCH.DESK
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "down")
  U.wait(5)
  U.tap(game, "a")        -- SHRINE
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(300)
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  check("desk and shrine came off the queue",
        (game.save.inventory.RESEARCH_DESK or 0) == 1
        and (game.save.inventory.SHRINE or 0) == 1)

  game.save.bagOrder = nil     -- RSCH.DESK sorts before SHRINE
  local dkx, dky = placeUntilSet(
    { { 8, 7 }, { 8, 8 }, { 8, 9 } }, 0, "SPRITE_RESEARCH_DESK")
  check("the RESEARCH DESK is set up", dkx ~= nil)
  local shx, shy = placeUntilSet(
    { { 3, 8 }, { 2, 8 }, { 1, 8 }, { 2, 9 }, { 1, 9 } }, 0,
    "SPRITE_SHRINE")
  check("the SHRINE is consecrated", shx ~= nil)

  -- the expansion stays locked until the desk has done its reading
  game.save.inventory = { WOOD = 6, ORE = 4, INGOT = 2 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  local exp = game.stack:top()
  for _ = 1, 22 do
    U.tap(game, "down")
    U.wait(5)
  end
  check("the cursor found the EXPANSION blueprint",
        exp.recipes[exp.index].ball == "EXPANSION_KIT")
  U.tap(game, "a")
  U.wait(10)
  check("no INSIGHT, no blueprint",
        exp.message == "NEEDS INSIGHT 10!")
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- ABRA reports for RESEARCH duty (8th resident, at the old cap)
  game.save.party = { Pokemon.new(game.data, "ABRA", 15),
                      Pokemon.new(game.data, "RATTATA", 5) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS opens for the scholar", openPalsFromStartMenu())
  U.tap(game, "select")
  waitFor(isAddList)
  U.tap(game, "a")
  dismissToPals()
  U.tap(game, "b")
  U.wait(15)

  U.wait(800)             -- INSIGHT accrues at 1s/point in the test env
  U.teleport(game, "PALCRAFT_BASE", dkx, dky + 1, "up")
  U.wait(10)
  U.tap(game, "a")        -- the desk talk ticks the ledger
  U.wait(40)
  check("the desk visit leaves it standing", talkAndCancel()
        and farmNpcAt(dkx, dky, "SPRITE_RESEARCH_DESK") ~= nil)

  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  for _ = 1, 22 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- EXPANSION -> quantity x01
  U.wait(15)
  U.tap(game, "a")
  U.wait(15)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(300)
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  check("the blueprint came off the queue",
        (game.save.inventory.EXPANSION_KIT or 0) == 1)

  -- unroll it: the east wing opens live
  game.save.bagOrder = nil
  placeViaBag(0)
  check("the east wing opened",
        game.overworld.map:isWalkableCell(11, 5)
        and game.overworld.map:isWalkableCell(12, 8))
  U.teleport(game, "PALCRAFT_BASE", 11, 5, "down")
  U.wait(10)
  check("the player stands in the new wing",
        game.overworld.player.cellX == 11)
  U.shot(game, SHOTS .. "41_east_wing.png")

  -- the bigger base holds a bigger crew: GASTLY is resident #9
  game.save.party = { Pokemon.new(game.data, "GASTLY", 15),
                      Pokemon.new(game.data, "RATTATA", 5) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS opens for the night shift", openPalsFromStartMenu())
  U.tap(game, "select")
  waitFor(isAddList)
  U.tap(game, "a")
  dismissToPals()
  U.tap(game, "b")
  U.wait(15)
  check("the expanded base holds nine", palNpcCount() == 9)

  -- souls accrue on GASTLY's vigil; an offering boosts PIDGEY's craft
  U.wait(700)             -- 2s per soul in the test env; 3 needed
  local speedBefore = 0
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  speedBefore = game.stack:top().speed or 0
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  U.teleport(game, "PALCRAFT_BASE", shx, shy + 1, "up")
  U.wait(10)
  U.tap(game, "a")        -- shrine: vigil text, then the menu
  local shrineMenu = false
  for _ = 1, 30 do
    U.wait(10)
    local top = game.stack:top()
    if top and top.items and top.items[1]
       and top.items[1].label == "OFFER" then
      shrineMenu = true
      break
    end
    U.tap(game, "a")
  end
  check("the shrine menu opens", shrineMenu)
  U.tap(game, "a")        -- OFFER
  U.wait(20)
  local offer = game.stack:top()
  check("the offering picker is the grid",
        offer.kind == "shrine_offer")
  U.tap(game, "a")        -- PIDGEY, resident #1
  U.wait(30)
  mashToOverworld(200)
  U.shot(game, SHOTS .. "42_shrine_offer.png")

  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  local speedAfter = game.stack:top().speed or 0
  check("the offering raised the crew's craft speed",
        speedAfter > speedBefore)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- the staffed desk deciphers the daycare hint
  game.save.inventory.EGG_INCUBATOR = 1
  game.save.bagOrder = nil
  local inx, iny = placeUntilSet(
    { { 9, 4 }, { 10, 4 }, { 11, 4 }, { 10, 5 } }, 0,
    "SPRITE_INCUBATOR")
  check("the incubator found a clear spot", inx ~= nil)
  U.teleport(game, "PALCRAFT_BASE", inx, iny + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  -- the menu remembers the parents from §10, so ASSIGN is not row 1:
  -- find it by label
  local assignRow
  for _ = 1, 30 do
    U.wait(10)
    local top = game.stack:top()
    if top and top.items then
      for i, it in ipairs(top.items) do
        if it.label == "ASSIGN" then assignRow = i end
      end
      if assignRow then
        local cur = top.index or 1
        local key = assignRow > cur and "down" or "up"
        for _ = 1, math.abs(assignRow - cur) do
          U.tap(game, key)
          U.wait(4)
        end
        U.tap(game, "a")
        break
      end
    end
    U.tap(game, "a")
  end
  check("parent 1 opens for the reveal",
        waitFor(function(t) return t.title == "PARENT 1" end))
  U.tap(game, "a")        -- PIDGEY
  check("parent 2 opens for the reveal",
        waitFor(function(t) return t.title == "PARENT 2" end))
  local p2 = game.stack:top()
  check("research names the child outright",
        p2.entries and p2.entries[1]
        and p2.entries[1].reveal == "FARFETCH'D")
  U.shot(game, SHOTS .. "43_research_reveal.png")
  U.tap(game, "b")
  U.wait(10)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)

  -- --------------------- 17. the yield stations and the wildcard

  -- craft the woodpile and the ore rock (rows 11 and 12)
  game.save.inventory = { WOOD = 4, ORE = 2, INGOT = 1,
                          CASCADEBADGE = 1 }
  game.save.bagOrder = nil
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- CRAFT
  U.wait(25)
  for _ = 1, 11 do
    U.tap(game, "down")
    U.wait(5)
  end
  U.tap(game, "a")        -- WOODPILE
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "down")
  U.wait(5)
  U.tap(game, "a")        -- ORE ROCK
  U.wait(15)
  U.tap(game, "a")        -- x01
  U.wait(15)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  U.wait(300)
  U.teleport(game, "PALCRAFT_BASE", tx, ty + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(120)
  check("woodpile and ore rock came off the queue",
        (game.save.inventory.LUMBER_PILE or 0) == 1
        and (game.save.inventory.MINING_ROCK or 0) == 1)

  -- the east wing has room for industry; stash one station so each
  -- placement works from a single-row bag (collection order is not
  -- deterministic, so blind row counts are not either)
  local stash = game.save.inventory.MINING_ROCK
  game.save.inventory.MINING_ROCK = nil
  game.save.bagOrder = nil
  local lmx, lmy = placeUntilSet(
    { { 11, 7 }, { 12, 7 }, { 11, 8 } }, 0, "SPRITE_LUMBER_PILE")
  check("the WOODPILE is stacked", lmx ~= nil)
  game.save.inventory.MINING_ROCK = stash
  game.save.bagOrder = nil
  local mnx, mny = placeUntilSet(
    { { 12, 5 }, { 11, 6 }, { 12, 6 } }, 0, "SPRITE_MINING_ROCK")
  check("the ORE ROCK is hauled in", mnx ~= nil)
  mnx, mny = mnx or 12, mny or 5   -- keep the tail running on a miss

  -- SANDSHREW digs, GEODUDE mines: residents 10 and 11
  game.save.party = { Pokemon.new(game.data, "SANDSHREW", 10),
                      Pokemon.new(game.data, "GEODUDE", 10),
                      Pokemon.new(game.data, "RATTATA", 5) }
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  U.tap(game, "start")
  U.wait(20)
  check("PALS opens for the work gangs", openPalsFromStartMenu())
  U.tap(game, "select")
  waitFor(isAddList)
  U.tap(game, "a")             -- SANDSHREW
  dismissToPals()
  U.tap(game, "select")
  waitFor(isAddList)
  U.tap(game, "a")             -- GEODUDE
  dismissToPals()
  U.tap(game, "b")
  U.wait(15)
  check("the wing crew moved in", palNpcCount() == 11)

  -- the piles fill on the play clock (2s per unit in the test env);
  -- with fliers on the crew the yields ride straight to the chest
  U.wait(500)
  local exy = game.mods.exports.palworld_crafting
  local before = exy.inspect("chest") or {}
  local woodBefore = (before.items and before.items.WOOD) or 0
  local oreBefore = (before.items and before.items.ORE) or 0
  U.teleport(game, "PALCRAFT_BASE", lmx, lmy + 1, "up")
  U.wait(10)
  U.tap(game, "a")        -- the talk ticks; the hauler banks
  U.wait(40)
  talkAndCancel()
  U.teleport(game, "PALCRAFT_BASE", mnx, mny + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(40)
  talkAndCancel()
  local after = exy.inspect("chest") or {}
  check("the WOODPILE's lumber reached the CHEST",
        ((after.items and after.items.WOOD) or 0) > woodBefore)
  check("the ORE ROCK's ore reached the CHEST",
        ((after.items and after.items.ORE) or 0) > oreBefore)
  U.shot(game, SHOTS .. "44_yield_stations.png")

  -- --------------------- 18. TM research at the desk

  local exr = game.mods.exports.palworld_crafting
  -- every researchable TM left the ground
  local researchable = {}
  for typeKey in pairs(exr.organFor) do
    for _, tm in ipairs(exr.tmOrderFor(typeKey)) do
      researchable[tm.id] = true
    end
  end
  local groundTms = 0
  for _, mapDef in pairs(game.data.maps) do
    for _, obj in ipairs(mapDef.objects or {}) do
      if obj.item and researchable[obj.item] then
        groundTms = groundTms + 1
      end
    end
  end
  for _, list in pairs(game.data.field.hiddenItems or {}) do
    for _, h in ipairs(list) do
      if researchable[h.item] then groundTms = groundTms + 1 end
    end
  end
  check("researchable TMs left the overworld", groundTms == 0)

  -- feed three ELEC organs; ABRA does the reading
  local firstElectric = exr.tmOrderFor("ELECTRIC")[1]
  check("the ELECTRIC ladder starts with a weak machine",
        firstElectric ~= nil)
  game.save.inventory.ORGAN_ELECTRIC = 3
  U.teleport(game, "PALCRAFT_BASE", dkx, dky + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  local deskMenu = false
  for _ = 1, 30 do
    U.wait(10)
    local top = game.stack:top()
    if top and top.items and top.items[1]
       and top.items[1].label == "RESEARCH" then
      deskMenu = true
      break
    end
    U.tap(game, "a")
  end
  check("the desk menu leads with RESEARCH", deskMenu)
  U.tap(game, "a")        -- RESEARCH
  U.wait(20)
  local rpick = game.stack:top()
  check("the organ picker lists the ELEC stock",
        rpick.title == "RESEARCH" and rpick.items
        and rpick.items[1] ~= nil)
  U.tap(game, "a")        -- the only organ type in the bag
  U.wait(30)
  mashToOverworld(120)
  check("the organs went into the research",
        game.save.inventory.ORGAN_ELECTRIC == nil)

  U.wait(250)             -- 2s research at test speed, plus slack
  U.teleport(game, "PALCRAFT_BASE", dkx, dky + 1, "up")
  U.wait(10)
  U.tap(game, "a")        -- the visit hands the machine over
  U.wait(40)
  talkAndCancel()
  check("the desk produced the first ELECTRIC TM",
        (game.save.inventory[firstElectric.id] or 0) >= 1)
  U.shot(game, SHOTS .. "45_tm_research.png")

  -- --------------------- 19. overworld bosses and the altar

  -- the Pewter legend: spawned on entry, hourly, uncatchable
  game.save.party = { Pokemon.new(game.data, "MEWTWO", 90) }
  -- MEWTWO at 90 knows only stat moves (BARRIER/RECOVER/MIST/AMNESIA)
  -- and the scrubbed boss no longer self-destructs the fight short:
  -- force a real attack so the duel actually ends
  game.save.party[1].moves = { { id = "PSYCHIC_M", pp = 32 } }
  game.save.inventory = { POKE_BALL = 1 }
  game.save.bagOrder = nil
  local function bossAt(x, y)
    for _, npc in ipairs(game.overworld.npcs or {}) do
      if npc.cellX == x and npc.cellY == y then return npc end
    end
    return nil
  end
  -- map.entered spawns the legend on arrival: just show up
  U.teleport(game, "PEWTER_CITY", 26, 28, "up")
  U.wait(20)
  check("GOLEM looms in Pewter", bossAt(26, 27) ~= nil)

  -- a stuffed bag would swallow the bounty; travel light to the duel
  game.save.inventory = { POKE_BALL = 3 }
  game.save.bagOrder = nil
  U.shot(game, SHOTS .. "46_boss_pewter.png")

  U.tap(game, "a")        -- challenge text -> pages -> YES
  local began = false
  for lap = 1, 60 do
    U.wait(10)
    local top = game.stack:top()
    if top and top.enemy and top.enemy.mon then
      began = true
      break
    end
    U.tap(game, "a")
  end
  local btl = game.stack:top()
  check("the boss battle began at its street level",
        began and btl.enemy.mon.species == "GOLEM"
        and btl.enemy.mon.level == 25)
  local blast = false
  for _, mv in ipairs((btl.enemy.mon and btl.enemy.mon.moves) or {}) do
    if mv.id == "SELFDESTRUCT" or mv.id == "EXPLOSION" then blast = true end
  end
  check("the street boss carries no blast moves", not blast)

  -- a thrown ball just bounces off (catch.rate hook)
  U.tap(game, "down")     -- FIGHT -> ITEM
  U.wait(10)
  U.tap(game, "a")
  U.wait(20)
  U.tap(game, "a")        -- POKé BALL
  U.wait(15)
  U.tap(game, "a")        -- USE
  U.wait(120)             -- toss anim + break-free text
  mashToOverworld(600)    -- fight it out: MEWTWO 90 ends this fast
  check("the street boss shrugged the ball off",
        #game.save.party == 1)

  for lap = 1, 20 do          -- steps settle the pending drops
    U.hold(game, "down", 30)
    U.wait(10)
    U.hold(game, "up", 30)
    U.wait(10)
    mashToOverworld(60)
    if (game.save.inventory.RARE_CANDY or 0) >= 1
       and (game.save.inventory.SHARD_ROCK or 0) >= 1 then break end
  end
  check("the bounty arrived: candy and a ROCK SHARD",
        (game.save.inventory.RARE_CANDY or 0) >= 1
        and (game.save.inventory.SHARD_ROCK or 0) >= 1)
  check("the beaten boss left the square", bossAt(26, 27) == nil)

  -- the hourly clock (6s in the test env) brings it back: leave and
  -- return so map.entered rolls the respawn
  U.wait(400)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(15)
  U.teleport(game, "PEWTER_CITY", 26, 28, "up")
  U.wait(20)
  check("the legend returns on the hour", bossAt(26, 27) ~= nil)

  -- the altar: craft is proven for stations; place from a single-row
  -- bag (rows sort by item ID, so blind row counts lie otherwise)
  game.save.inventory = { SUMMON_ALTAR = 1 }
  game.save.bagOrder = nil
  local alx, aly = placeUntilSet(
    { { 10, 9 }, { 11, 9 }, { 12, 9 }, { 13, 9 } }, 0,
    "SPRITE_SUMMON_ALTAR")
  check("the ALTAR is raised in the base", alx ~= nil)
  alx, aly = alx or 10, aly or 9
  game.save.inventory.SHARD_ROCK = 8
  game.save.bagOrder = nil

  U.teleport(game, "PALCRAFT_BASE", alx, aly + 1, "up")
  U.wait(10)
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "down")     -- SUMMON, FUSE
  U.wait(6)
  U.tap(game, "a")        -- FUSE
  U.wait(20)
  U.tap(game, "a")        -- ROCK SHARD x8
  U.wait(40)
  mashToOverworld(120)
  check("eight shards fused into the ROCK TABLET",
        game.save.inventory.TABLET_ROCK == 1
        and game.save.inventory.SHARD_ROCK == nil)

  -- a wrong party is turned away at the stone
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- SUMMON
  U.wait(20)
  U.tap(game, "a")        -- RCK TABLET
  U.wait(40)
  mashToOverworld(120)
  check("a lone MEWTWO cannot open the summons",
        game.save.inventory.TABLET_ROCK == 1)

  -- six of stone: the empowered GOLEM answers, and can be caught
  game.save.party = {}
  for i = 1, 6 do
    -- six of stone, but sturdy: the empowered GOLEM one-shots
    -- GEODUDEs with its own scrubbed-in EARTHQUAKE, which made the
    -- fight's length a coin flip against the mash budget
    game.save.party[i] = Pokemon.new(game.data, "GRAVELER", 55)
    game.save.party[i].moves = { { id = "EARTHQUAKE", pp = 15 } }
  end
  U.tap(game, "a")
  U.wait(25)
  U.tap(game, "a")        -- SUMMON
  U.wait(20)
  U.tap(game, "a")        -- RCK TABLET
  for _ = 1, 60 do
    local top = game.stack:top()
    if top and top.enemy and top.enemy.mon then break end
    U.tap(game, "a")
    U.wait(10)
  end
  local sbtl = game.stack:top()
  check("the empowered GOLEM answered at double level",
        sbtl and sbtl.enemy and sbtl.enemy.mon
        and sbtl.enemy.mon.species == "GOLEM"
        and sbtl.enemy.mon.level == 50)
  blast = false
  for _, mv in ipairs((sbtl and sbtl.enemy and sbtl.enemy.mon
                       and sbtl.enemy.mon.moves) or {}) do
    if mv.id == "SELFDESTRUCT" or mv.id == "EXPLOSION" then blast = true end
  end
  check("the summon carries no blast moves either", not blast)
  check("the tablet burned in the summons",
        game.save.inventory.TABLET_ROCK == nil)
  -- shoot once the FIGHT menu is up: both HUDs drawn, the boss's
  -- level and our own POKeMON in frame
  for _ = 1, 80 do
    local t19 = game.stack:top()
    if t19 and t19.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(10)
  end
  U.wait(10)
  U.shot(game, SHOTS .. "47_summon_battle.png")
  mashToOverworld(2000)   -- the stone crew grinds it out
  check("the summons cleared cleanly", (function()
    local ex19 = game.mods.exports.palworld_crafting
    return ex19.inspect("summon_fight") == nil
  end)())

  -- --------------------- 20. humble starters and the classics gone wild

  local MS20 = require("src.script.MapScripts")
  local Flags20 = require("src.script.Flags")

  local function ballGives(textConst)
    local rows = MS20.talkScript("OAKS_LAB", textConst)
    local given, rivalTakes
    for _, row in ipairs(rows or {}) do
      if row[1] == "give_pokemon" then given = row[2] end
      if row[1] == "show_text" and row[2] == "_OaksLabRivalReceivedMonText"
         and type(row[3]) == "table" then
        rivalTakes = row[3].RAM
      end
    end
    return given, rivalTakes
  end
  local g1, r1 = ballGives("TEXT_OAKSLAB_BULBASAUR_POKE_BALL")
  local g2, r2 = ballGives("TEXT_OAKSLAB_CHARMANDER_POKE_BALL")
  local g3, r3 = ballGives("TEXT_OAKSLAB_SQUIRTLE_POKE_BALL")
  check("the lab balls hold ZUBAT, MEOWTH and DIGLETT",
        g1 == "ZUBAT" and g2 == "MEOWTH" and g3 == "DIGLETT")
  check("the rival still takes a classic from each ball",
        r1 == "CHARMANDER" and r2 == "SQUIRTLE" and r3 == "BULBASAUR")

  local r24 = game.data.encounters.ROUTE_24
  local r7 = game.data.encounters.ROUTE_7
  check("BULBASAUR dens on Route 24 in the 13/256 slot",
        r24 and r24.grass and r24.grass.slots[7].species == "BULBASAUR")
  check("CHARMANDER dens on Route 7 in the 13/256 slot",
        r7 and r7.grass and r7.grass.slots[7].species == "CHARMANDER")

  local ex20 = game.mods.exports.palworld_crafting
  local bite20 = { species = "GOLDEEN", level = 10 }
  check("a lucky GOOD ROD bite is the turtle",
        ex20.goodRodCatch("GOOD_ROD", bite20, 10).species == "SQUIRTLE"
        and ex20.goodRodCatch("GOOD_ROD", bite20, 90).species == "GOLDEEN"
        and ex20.goodRodCatch("OLD_ROD", bite20, 10).species == "GOLDEEN")
  local rodRow
  for _, r in ipairs(ex20.stationRecipes) do
    if r.ball == "GOOD_ROD" then rodRow = r end
  end
  check("the GOOD ROD is craftable at the table",
        rodRow ~= nil and rodRow.cost[2][1] == "INGOT")

  -- live at the lab: open the BULBASAUR ball, receive the bat
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60) }
  Flags20.set(game.save, "EVENT_FOLLOWED_OAK_INTO_LAB")
  Flags20.clear(game.save, "EVENT_GOT_STARTER")
  Flags20.clear(game.save, "EVENT_CHOSE_BULBASAUR")
  U.teleport(game, "OAKS_LAB", 8, 4, "up")
  U.wait(15)
  -- state-driven: A answers YES on the asks and pages the text;
  -- when the nickname grid appears, START confirms the empty name
  for _ = 1, 100 do
    local top = game.stack:top()
    if top and top.glyphs and top.onDone then
      U.tap(game, "start")
      U.wait(20)
    elseif top == game.overworld and #game.save.party >= 2
        and not (game.overworld.runner
                 and game.overworld.runner:isRunning()) then
      break
    else
      U.tap(game, "a")
      U.wait(20)
    end
  end
  check("the humble starter joined the party",
        #game.save.party == 2
        and game.save.party[2].species == "ZUBAT")
  check("the lab still thinks a classic was chosen",
        Flags20.get(game.save, "EVENT_GOT_STARTER") == true
        and Flags20.get(game.save, "EVENT_CHOSE_BULBASAUR") == true)
  U.shot(game, SHOTS .. "48_humble_starter.png")
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  -- ------- 21. deep pockets, bag pages, chest mats, SELECT pack-up

  local ex21 = game.mods.exports.palworld_crafting

  -- 999-deep stacks through the real Bag API
  game.save.inventory = { WOOD = 98 }
  game.save.bagOrder = nil
  local Bag21 = require("src.inventory.Bag")
  check("stacks climb past 99 to the 999 wall",
        Bag21.add(game.save, "WOOD", 500, game.data)
        and game.save.inventory.WOOD == 598
        and not Bag21.add(game.save, "WOOD", 500, game.data))

  -- the ITEMS list pages with left/right
  game.save.inventory = { APRICORN_RED = 1, APRICORN_BLU = 1,
    APRICORN_YLW = 1, WOOD = 1, ORE = 1, INGOT = 1, GRAPES = 1,
    GRAPE_SEED = 1, POTION = 1, RARE_CANDY = 1 }
  game.save.bagOrder = nil
  local bag21 = require("src.ui.BagMenu").new(game, {})
  check("the bag list pages with left/right", bag21.pageJump == true)
  game.stack:push(bag21)
  U.wait(5)
  U.tap(game, "right")
  U.wait(10)
  local jumped = bag21.index > 1
  U.tap(game, "left")
  U.wait(10)
  check("RIGHT jumps a page and LEFT comes back",
        jumped and bag21.index == 1)
  U.tap(game, "b")
  U.wait(10)
  mashToOverworld(60)

  -- crafting drinks from the chest: the bag pays first, the chest
  -- covers the rest of the OLD ROD's 3 WOOD
  local chest21 = ex21.inspect("chest")
  local chestWood = (chest21 and chest21.items and chest21.items.WOOD) or 0
  check("the chest still holds hauled WOOD", chestWood >= 1)
  game.save.inventory = { WOOD = 2 }
  game.save.bagOrder = nil
  local rod21 = ex21.recipes[4]
  check("bag + chest cover the OLD ROD",
        rod21.ball == "OLD_ROD" and ex21.materialsMax(game, rod21) >= 1)
  ex21.queueCraft(game, rod21, 1)
  local after21 = ex21.inspect("chest")
  check("the bag paid first, the chest covered the rest",
        game.save.inventory.WOOD == nil
        and ((after21.items and after21.items.WOOD) or 0) == chestWood - 1)

  -- the essence condenser: same-species offers buy stars
  game.save.inventory = { CONDENSER = 1 }
  game.save.bagOrder = nil
  local cnx, cny = placeUntilSet(
    { { 4, 9 }, { 5, 9 }, { 6, 9 }, { 4, 8 } }, 0, "SPRITE_CONDENSER")
  check("the CONDENSER gurgles in the base", cnx ~= nil)
  cnx, cny = cnx or 4, cny or 9

  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60) }
  local tgt = game.save.party[1]
  local ex22 = game.mods.exports.palworld_crafting
  ex22.setStars(tgt, game.data.pokemon.CHARIZARD, 1)  -- gift tier
  local atkBefore = tgt.stats.attack
  game.save.boxes = {}
  for i = 1, 12 do game.save.boxes[i] = {} end
  for i = 1, 2 do
    -- pre-evolutions feed the line: CHARMANDERs for a CHARIZARD
    game.save.boxes[1][i] = Pokemon.new(game.data, "CHARMANDER", 10)
  end
  U.teleport(game, "PALCRAFT_BASE", cnx, cny + 1, "up")
  U.wait(10)
  U.tap(game, "a")        -- talk: essence text
  U.wait(20)
  U.tap(game, "a")        -- -> menu
  U.wait(15)
  U.tap(game, "a")        -- CONDENSE -> target grid
  U.wait(20)
  U.tap(game, "a")        -- CHARIZARD, cell 1 (star 2 -> needs 3)
  U.wait(20)
  for _ = 1, 2 do         -- two offers (star 1 -> 2); picker reopens
    U.tap(game, "a")
    U.wait(20)
  end
  mashToOverworld(120)
  check("the essence rose a star and the stats followed",
        tgt.dvs and tgt.dvs.stars == 2
        and tgt.stats.attack > atkBefore)
  check("the offers were consumed", #game.save.boxes[1] == 0)

  -- a fresh catch lands dimmed at star 0 (the real catch.rate chain)
  local caught22 = Pokemon.new(game.data, "PIDGEY", 10)
  local preAtk = caught22.stats.attack
  local ok22 = Runtime.call("catch.rate",
    function() return true, 3 end,
    "POKE_BALL", caught22, game.data.pokemon.PIDGEY)
  check("a fresh catch lands at star 0 with dimmed stats",
        ok22 == true and caught22.dvs.stars == 0
        and caught22.stats.attack < preAtk)

  -- SELECT offers to pack the pitched base back up
  local b21 = ex21.inspect("base")
  check("the base still stands for the pack-up test", b21 ~= nil)
  if b21 then
    U.teleport(game, b21.map, b21.x, b21.y - 1, "down")
    U.wait(10)
    U.tap(game, "select")
    U.wait(20)
    for _ = 1, 12 do
      if ex21.inspect("base") == nil then break end
      U.tap(game, "a")
      U.wait(15)
    end
    mashToOverworld(60)
    check("SELECT packed the base back up",
          ex21.inspect("base") == nil
          and (game.save.inventory.SECRET_BASE or 0) >= 1)
  end

  U.log(("eye check done: %d pass, %d fail"):format(pass, fail))
  U.log("screenshots in " .. SHOTS)
  love.event.quit(fail == 0 and 0 or 1)
  while true do coroutine.yield() end
end
