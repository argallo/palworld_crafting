-- One-shot: builds the "marking tour" save -- a L60 PIDGEOT with FLY,
-- all eight badges, every fly town visited, a stack of MAX REPELs.
--   POKEPORT_IDENTITY=marking \
--   POKEPORT_DRIVER=mods/palworld_crafting/tools/driver_make_fly_save.lua \
--   POKEPORT_DEV=1 love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  U.newGame(game)
  U.log("new game booted; outfitting the tour")

  local save = game.save
  local bird = Pokemon.new(game.data, "PIDGEOT", 60)
  table.insert(bird.moves, 1, { id = "FLY", pp = 15 })
  while #bird.moves > 4 do table.remove(bird.moves) end
  save.party = { bird }

  save.inventory = save.inventory or {}
  for _, b in ipairs({ "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE",
      "RAINBOWBADGE", "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE",
      "EARTHBADGE" }) do
    save.inventory[b] = 1
  end
  save.inventory.MAX_REPEL = 9
  save.money = 99999
  save.flags = save.flags or {}
  save.flags.EVENT_GOT_POKEDEX = true
  save.visited = save.visited or {}
  for _, t in ipairs({ "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY",
      "CERULEAN_CITY", "VERMILION_CITY", "LAVENDER_TOWN", "CELADON_CITY",
      "FUCHSIA_CITY", "SAFFRON_CITY", "CINNABAR_ISLAND",
      "INDIGO_PLATEAU" }) do
    if game.data.maps[t] then save.visited[t] = true end
  end

  -- the intro's runner can still hold the overworld: wait it out
  for _ = 1, 200 do
    local ow = game.overworld
    if game.stack:top() == ow
       and not (ow.runner and ow.runner:isRunning()) then
      break
    end
    U.tap(game, "a")
    U.wait(10)
  end
  U.wait(30)

  -- save through the START menu, like a player would; settle until
  -- the menu is really up
  local menu, target
  for attempt = 1, 10 do
    U.tap(game, "start")
    U.wait(25)
    menu = game.stack:top()
    for i, it in ipairs(menu and menu.items or {}) do
      if tostring(it.label):find("SAVE", 1, true) then target = i end
    end
    if target then break end
    local labels = {}
    for _, it in ipairs(menu and menu.items or {}) do
      labels[#labels + 1] = tostring(it.label)
    end
    U.log("attempt " .. attempt .. " top rows: "
          .. table.concat(labels, ","))
    U.tap(game, "b")
    U.wait(15)
  end
  if not target then
    U.log("FAIL: no SAVE row on the start menu")
    love.event.quit(1)
    while true do coroutine.yield() end
  end
  local cur = menu.index or 1
  for _ = 1, math.abs(target - cur) do
    U.tap(game, target > cur and "down" or "up")
    U.wait(4)
  end
  U.tap(game, "a")        -- open the SAVE flow
  local function slotOnDisk()
    return love.filesystem.getInfo("saves/red/slot1.lua")
      or love.filesystem.getInfo("save.lua")
  end
  local saved = false
  for _ = 1, 60 do
    U.wait(15)
    if slotOnDisk() then
      saved = true
      break
    end
    U.tap(game, "a")      -- prompt text, YES, jingle -- keep confirming
  end
  for _ = 1, 8 do
    U.tap(game, "a")
    U.wait(10)
  end
  U.log(saved and "fly-tour save written"
        or "FAIL: no slot file appeared")
  love.event.quit(saved and 0 or 1)
  while true do coroutine.yield() end
end
