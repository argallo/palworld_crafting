-- Optional-dependency eye check: with overworld_encounters installed,
-- base pals must wear its per-species walkers (SPRITE_WILD_<SPECIES>).
--
--   POKEPORT_DRIVER=mods/palworld_crafting/tests/driver_dep_check.lua \
--   POKEPORT_IDENTITY=depcheck love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1 else fail = fail + 1 end
    U.log(ok and "PASS" or "FAIL", label)
    return ok
  end

  check("overworld_encounters sprites are merged",
        game.data.sprites.SPRITE_WILD_PIDGEY ~= nil)

  -- assets-only mode: the walkers exist but none of that mod's gameplay
  -- ran (its entry chunk stamps this flag on the controller)
  local OC = require("src.world.OverworldController")
  local gameplayActive = OC.__overworldEncountersRollWrapped == true
  U.log("overworld_encounters gameplay active: " .. tostring(gameplayActive))
  if os.getenv("PALCRAFT_EXPECT_ASSETS_ONLY") == "1" then
    check("their gameplay is inactive (assets only)", not gameplayActive)
  end

  game.save.player = game.save.player or {}
  game.save.player.name = "RED"
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60),
                      Pokemon.new(game.data, "PIDGEY", 12) }
  U.teleport(game, "PALCRAFT_BASE", 5, 6, "down")

  local function topTitled(title)
    local top = game.stack:top()
    return top and top.title == title
  end
  local function waitFor(title)
    for _ = 1, 80 do
      if topTitled(title) then return true end
      U.wait(5)
    end
    return false
  end

  U.tap(game, "start")
  U.wait(20)
  local menu = game.stack:top()
  local target
  for i, it in ipairs(menu and menu.items or {}) do
    if it.label == "BASE POKéMON" then target = i end
  end
  check("PALS row present", target ~= nil)
  for _ = 1, (target or 1) - (menu and menu.index or 1) do
    U.tap(game, "down")
    U.wait(4)
  end
  U.tap(game, "a")
  check("pals screen opens", waitFor("BASE POKéMON"))
  U.tap(game, "a")               -- ADD POKéMON
  check("add list opens", waitFor("MOVE TO BASE"))
  U.tap(game, "down")            -- CHARIZARD, PIDGEY: pick PIDGEY
  U.wait(6)
  U.tap(game, "a")
  for _ = 1, 40 do               -- dismiss result text back to the list
    if topTitled("BASE POKéMON") then break end
    U.tap(game, "a")
    U.wait(12)
  end
  U.tap(game, "b")               -- close, look at the room
  U.wait(20)

  local palSprite
  for _, npc in ipairs(game.overworld.npcs) do
    local s = npc.def and tostring(npc.def.sprite) or ""
    if s:find("SPRITE_WILD_", 1, true) == 1 or s == "SPRITE_MONSTER" then
      palSprite = s
    end
  end
  check("the pal wears its species walker",
        palSprite == "SPRITE_WILD_PIDGEY")
  U.shot(game, "/tmp/palcraft_shots/20_pal_species_sprite.png")

  U.log(("dep check done: %d pass, %d fail"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
  while true do coroutine.yield() end
end
