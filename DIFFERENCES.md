# Differences from vanilla

What this mod changes, in the format of the engine's
`docs/known-differences.md`.

## Changed

- Marts sell no Poke/Great/Ultra Balls and no evolution stones; a
  shelf left empty falls back to selling a POTION.
- Ground and hidden Poke Balls are swapped for matching apricorns;
  ground and hidden evolution stones and researchable TMs become ORE
  caches.
- Oak's three lab balls hold ZUBAT, MEOWTH, and DIGLETT. The rival
  still takes his classic counterpick, so every rival battle is
  unchanged.
- BULBASAUR dens on Route 24 and CHARMANDER on Route 7 (13/256 slot);
  SQUIRTLE is a GOOD ROD catch (25% of successful bites).
- Wild slots holding breed-only species are re-filled with the
  table's lead species; version-exclusive counterparts are healed
  into the wild at weight-split odds.
- Route 4 grass guarantees a SANDSHREW slot.
- The bag has no practical slot limit (999) and items stack to 999.
- Every catch lands at 70% stats (star 0); starters, gifts, trades
  and pre-existing mons count as star 1 (90%). Only condensing
  reaches 100% and 120%. Enemy and trainer POKeMON are untouched.
- On HARD difficulty, POKeMON not hatched from the incubator earn
  half battle EXP.
- The ITEMS list pages with LEFT/RIGHT.
- SELECT in the overworld places / offers to pack up the SECRET BASE.

## Added

- A placeable SECRET BASE (private room) with a working PC, a base
  crew of up to 12 POKeMON working typed jobs, and an east-wing
  expansion.
- Stations: CRAFT TABLE (+MK2), GENERATOR, FURNACE, MEDICINE BENCH,
  TRAINING DUMMY, RESEARCH DESK, SHRINE, WOODPILE, ORE ROCK, CHEST,
  EGG INCUBATOR, SUMMONING ALTAR, ESSENCE CONDENSER, GOOD ROD.
- Craft queues run on play time, sped by worker suitability levels;
  stations draw materials from the base chest as well as the bag.
- Breeding: same-line pairs hatch the base form; curated special
  pairings hatch new species; hatchlings roll egg moves from their
  TM list and carry a bred mark and star 1.
- Battle drops: apricorns, WOOD, ORE, GRAPE SEEDs, typed ORGANs
  (TM research at the desk).
- Twelve two-hourly overworld bosses (uncatchable, no blast moves)
  dropping RARE CANDY and typed LEGENDARY SHARDS; 8 shards fuse to a
  TABLET; six mono-type party members summon a catchable 2x-level
  form at the altar.
- Gym badges carry blueprints: Brock the INCUBATOR, Misty the
  WOODPILE, Lt. Surge the GENERATOR, each announced when the badge
  lands.
- A DIFFICULTY mod option (NORMAL / HARD).

## Known

- Link battles between peers with different star ranks or egg moves
  desync; both sides should run the same mod version
  (`affects_link` is set).
- Statics, fossils, Game Corner prizes and in-game trades still grant
  breed-only species.
- Bosses spawn on fixed street cells; an NPC standing on the cell at
  the spawn moment delays the spawn to the next map entry.
