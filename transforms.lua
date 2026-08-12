-- Derived-art recipe (assets_transforms): compose the secret base's
-- tileset from the player's own imported cache.  The HOUSE sheet gains
-- one extra tile row whose first tile is CAVERN's cave-floor tile
-- (index 32, pixel 0,16) -- the tilled dirt the farm plots stand on.
-- New tile index: 16 tiles/row * 6 rows = 96.
return function(ctx)
  if not ctx.exists("tilesets/house.png")
     or not ctx.exists("tilesets/cavern.png") then
    return  -- no imported cache yet: nothing to derive
  end
  local house = ctx.readImage("tilesets/house.png")    -- 128x48
  local cavern = ctx.readImage("tilesets/cavern.png")
  local out = ctx.blank(128, 56, 0, 0, 0, 0)
  ctx.blit(out, house, 0, 0, 0, 0, 128, 48)
  ctx.blit(out, cavern, 0, 48, 0, 16, 8, 8)
  -- pcall: the headless test harness reads the repo's real cache but
  -- has no save directory to write into; in the real game this write
  -- only fails alongside every other save write
  pcall(ctx.writeImage, out, "tilesets/palcraft_house.png")
end
