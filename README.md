# Palworld Crafting

A Palworld-style survival economy inside Gen 1 Pokemon Red, for
[gen1recomp](https://github.com/bryanthaboi/gen1recomp): build a
secret base, put your POKeMON to work by type, breed for egg moves
and stars, craft everything, and duel hourly street bosses.

## Install

1. Grab the latest `palworld_crafting-<version>.zip` from
   [Releases](https://github.com/argallo/palworld_crafting/releases)
   (or use **Import mod .zip** in the launcher's mod manager).
2. Unpack it into your `mods/` folder so it sits at
   `mods/palworld_crafting/`.
3. Enable it in the mod manager. A **DIFFICULTY** option (NORMAL /
   HARD) lives in the mod's options.

Best experienced on a fresh save. It loads fine mid-save too: your
existing POKeMON join the star ladder at star 1.

## The pitch

Poke Balls leave the shops. Marts no longer sell any ball; instead you
gather **Apricorns** and craft balls yourself at a **CRAFT TABLE** you
place in the world.

## Where apricorns come from

- **Battle wins.** Beating a wild Pokemon has an 85% chance to drop one
  apricorn; beating a trainer always drops two. **The color scales with
  the beaten level**, mirroring the ball tiers: under L12 it's mostly RED,
  the teens-twenties favor BLU (Great Ball territory), and past L30 YLW
  takes over. Drops are handed over as soon as you're back on the road.
- **Growing in the overworld.** 48 visible apricorn pickups (original
  16x16 sprite art, color-coded red/blue/yellow) spread across every
  land route in Kanto plus Viridian Forest — walk up and press A, like a
  vanilla item ball. Colors tier with the region: RED near home, BLU
  mid-Kanto, YLW along the late stretches. One-time finds.
- **Ground balls are apricorns now.** The few free balls vanilla leaves
  lying around (Viridian Forest's Poke Ball, Cerulean Cave's Ultra Balls,
  and the six hidden Great/Ultra Balls) hand over the matching apricorn
  instead — Poke→RED, Great→BLU, Ultra→YLW. The Master Ball story gift
  is untouched.
- **WOOD drops from early wilds.** Beating anything under L12 has a
  35% shot at dropping WOOD instead of an apricorn — every ball needs
  a wooden frame, so Route 1 funds your first crafting session (new
  games start with 3 WOOD and nothing else; the gear is earned).
- **TYPE ORGANS** (15%): every defeated POKéMON can shed an organ of
  one of its own types — the RESEARCH DESK turns them into TMs.
- Trainers hand over one guaranteed drop.
- Apricorns can be **sold** at any mart (half price) once you have more
  than you can craft.

## The CRAFT TABLE

Crafting happens at a **placeable crafting table**, Palworld style:

- The CRAFT TABLE arrives with the SECRET BASE kit when Oak hands
  over the POKéDEX — no mart sells it. Like every station it
  **only sets up inside your SECRET BASE** now.
- **USE it from the bag** to set it up on the tile you're facing (needs
  an open cell). Walk up and press A for **CRAFT / PACK UP / CANCEL** —
  CRAFT opens the crafting screen, PACK UP returns the table to your bag.
- **The screen is live**: the running order sits in the header with a
  progress bar and an ETA, and the helper line names who on the crew
  is speeding the queue (and by how much). BAG FULL and NEED MATERIALS
  are told apart honestly.
- An **OLD ROD** whittles from 3 WOOD — early water access, one
  MAGIKARP at a time.
- **Crafting is a work queue now**, Palworld style: an order swallows
  its materials up front and completes over play time (POKé BALL 15s,
  GREAT 30s, ULTRA 60s, FERM.JUICE 45s each). A **HANDIWORK POKéMON in
  your base speeds every queue** — 1 + level/2, so a Lv.3 helper runs
  2.5x (the screen title shows the multiplier). Visit any craft table
  to collect finished goods; the status line tracks the running order.
- **Recipes:** POKé BALL = 2 RED apricorns + 1 WOOD; GREAT BALL =
  2 BLU + 1 RED + 2 WOOD; ULTRA BALL = 2 YLW + **1 INGOT**.

## The POWER GRID

The base industrializes in three crafts (both stations are **built at
the table from ore and wood**, never bought):

- **ORE drops from ROCK and GROUND wilds** (25% per drop, any level) —
  Geodude country is mining country.
- The **FURNACE** (2 ORE + 2 WOOD) smelts ORE into INGOTs on its own
  work queue — but the fire only burns while a **KINDLING POKéMON**
  is on the crew (higher levels smelt faster). Talk to it to SMELT,
  collect, or PACK UP.
- The **GENERATOR** (3 ORE + 2 WOOD) powers the base while a
  **GENERATING POKéMON** is home. Power does two things: every craft
  queue gains the generating level as extra speed (stacking with
  HANDIWORK), and base craft tables become the **CRAFT TABLE MK2** —
  five new recipes appear: **FIRE / WATER / THUNDER / LEAF STONE**
  (1 INGOT + 3 matching apricorns, grapes for LEAF) and **MOON STONE**
  (2 INGOTs). Celadon's evolution-stone money-gate, farmable at last.
- Tables outside the base stay MK1 — the power doesn't reach.

## The MEDICINE BENCH and the DOJO

- The **MEDICINE BENCH** (4 WOOD + 1 ORE at the table) brews remedies
  from farm goods on its own work queue — and the vat only bubbles
  while a **MEDICINE POKéMON** (poison types, or CHANSEY) is on the
  crew. **Worker level gates the shelf**: Lv.1 brews POTION and
  ANTIDOTE, Lv.2 unlocks SUPER POTION, FULL HEAL, and REVIVE, Lv.3
  masters HYPER POTION and ELIXER. Grapes and FERM.JUICE are the
  ingredients, so the farm feeds the pharmacy.
- The **TRAINING DUMMY** (3 WOOD) turns the dojo loose: while a
  **FIGHTING POKéMON** trains, the base slowly produces **RARE
  CANDY** — level sets the pace, and up to five pile up at the dummy
  until you collect. The dojo makes the candy; you choose who eats it.

- **The CHEST is the base's warehouse**: DEPOSIT anything from the
  bag, and with a TRANSPORT POKéMON on the crew every station's output
  — ingots, candies, brews, lumber, ore, harvests — is hauled straight
  to it as it finishes. Check the chest, not six stations.
- The bag itself carries **30 slots** now (up from 20).

## RESEARCH, the SHRINE, and the EAST WING

- The **RESEARCH DESK** (3 WOOD + 1 INGOT) is the tech tree. It
  accrues **INSIGHT** while a **PSYCHIC POKéMON** studies (the
  **EXPANSION** blueprint unlocks at INSIGHT 10), deciphers the
  daycare's "?!" hint into the actual child's name — and it **turns
  TYPE ORGANS into TMs**: feed it 3 organs of one type and the
  scholar researches that type's next machine, weakest first,
  stronger every round. Researchable TMs no longer lie around the
  overworld (those caches hold ORE now) — the desk is the way.
- The **SHRINE** (3 ORE + 1 INGOT) gathers **SOULS** while a **GHOST
  POKéMON** keeps vigil. **OFFER** 3 souls to a chosen base POKéMON and
  every work skill it has rises one level (up to +2, capped at
  mastery 4) — the shrine turns your night shift into promotions.
- The **EXPANSION KIT** (6 WOOD + 4 ORE + 2 INGOT at the MK2 table,
  INSIGHT 10) unrolls inside the base and **opens the east wing**:
  four more columns of floor, live, no re-entry needed — and the
  bigger base houses **12 POKéMON instead of 8**.

## The full worksite: every job employed

- The **WOODPILE** (2 ORE + 1 WOOD) and the **ORE ROCK** (3 WOOD +
  2 ORE) are passive producers: a **GROUND POKéMON** chops WOOD and a
  **ROCK POKéMON** mines ORE on the play clock, level setting the
  pace, five units piling up until you collect. The base now feeds its
  own building materials.
- **Egg temperature:** a **KINDLING POKéMON halves every hatch** — and
  pairs whose child is an ice type lay **COLD eggs** that want a
  **COOLING POKéMON** instead (the incubator tells you when it's
  chilly).
- **TRANSPORT hauls the farm**: the auto-harvest foreman is a
  **FLYING POKéMON** now (Fighting types retired to the dojo).
- **The OVERSEER wildcard**: a DRAGON (or DITTO, or MEW) counts as
  any job the crew is missing, at its own Overseer level — one Dratini
  plugs whatever gap your roster has. A real specialist always
  outranks the stand-in.

All fifteen work suitabilities are live.
- Placements are saved and respawn when you re-enter the map. Place as
  many tables as you can carry.
- Tables are the **only** place to craft — there is no Start-menu
  shortcut.

Engine note: this mod declares the `engine_internals` permission for one
thing — the engine merges the documented `item_effects` registry but does
not yet dispatch it on item use, so the mod wires that documented contract
in (any mod's `items.effect` handler benefits).

## The SECRET BASE

The **SECRET BASE** arrives with the POKéDEX — Oak's gift comes with
a housing upgrade:

- **Press SELECT in the overworld** to pitch it on the tile you're
  facing (or USE it from the bag; one base per save; PACK UP moves
  it). With a base already down, **SELECT asks whether to pack it
  back up** — from the base's own map; elsewhere it just tells you
  where the tent stands. The room's colors follow whatever region the
  doorstep stands in.
- Press A on the entrance for **ENTER / PACK UP / CANCEL**. ENTER takes
  you into your own private 10x10 room — a proper house interior with
  wallpapered walls, windows, and a wooden floor. Leave through
  the two-cell door mat at the south edge — step on it and press down,
  exactly like walking out of a mart — and you're back where you stood.
- A **POKéMON PC** sits in the top-left corner — a real, fully working
  PC: face it and press A for the same menu as any Pokémon Center
  (BILL's PC boxes, your item storage, PROF.OAK's rating once you have
  the POKéDEX). No more trekking to town to juggle boxes.
- A housewarming gift waits inside on your first visit: an item ball
  holding a **FERM.JUICE** — exactly what the INCUBATOR drinks.
- Crafting tables can be placed inside the base, and **the room's
  contents travel with it**: pack the base up, pitch it on the other side
  of Kanto, and everything you placed inside is exactly where you left
  it. (Roadmap: more placeable stations for the room.)
- **Work suitabilities.** Every POKéMON is a worker, Palworld style:
  each of its types grants a job (NORMAL handiwork, GRASS gathering,
  BUG planting, WATER watering, FIRE kindling, ELECTRIC generating,
  ICE cooling, GROUND lumbering, ROCK mining, FLYING transport,
  POISON medicine, FIGHTING training, PSYCHIC research, GHOST the
  night shift, DRAGON overseeing) at a level set by its evolution
  stage — evolving is the promotion. Legendaries master their craft,
  single-stage adults work at Lv.2, and a few earn off-type jobs
  (SCYTHER fells trees; CHANSEY is a nurse's aide; PORYGON is
  literally software). Inside the base the Start menu's **WORK
  SKILLS** row opens a sprite grid of all 151 — roam it with the dpad
  and the panel below live-updates with the highlighted POKéMON's jobs,
  no clicking in. **Press SELECT to filter** the grid to a single job
  (the hint sits in the bottom-right border; the active filter and its
  worker count ride the top border; pick ALL to clear). Every base POKéMON's action menu also gains a **SKILLS**
  entry showing its own card.
- **Base POKéMON.** While inside the base, the Start menu gains a
  **BASE POKéMON** row — the same sprite-grid look as WORK SKILLS: your
  base crew as roaming-sprite cells, the highlighted one's level and
  jobs in the panel below. **SELECT adds** a POKéMON: the picker grids
  your party and every PC box (source shown on the top border), with
  each candidate's work skills in view before you commit — hire on the
  spot. Press A on a base POKéMON for TO PARTY / TO PC / SKILLS (up to
  8 in the base). Assigned POKéMON wander the room — talk to them! The usual
  rules hold: you always keep at least one POKéMON on you, and full
  parties/boxes refuse politely. Base POKéMON wear real per-species
  overworld sprites courtesy of
  [Overworld Encounters](https://github.com/gamecorner-033/Gen1PC-OverworldEncounters):
  keep that mod's folder in `mods/` and this mod reads its follower art
  directly — **even with the mod itself disabled**, so you get the
  sprites without its roaming-encounter gameplay. Enable it in the MODS
  menu if you want the full experience; delete the folder and base
  POKéMON fall back to a generic monster sprite. Nothing here requires
  it.

## The EGG INCUBATOR

The **INCUBATOR** is **Brock's blueprint**: beating Pewter's gym
unlocks its recipe at the craft table (5 WOOD + 2 ORE). It only works
inside your SECRET BASE:

- **USE it from the bag** while in the base to set it up. Press A on it
  to interact.
- **ASSIGN** two of your base POKéMON as parents, then **ADD JUICE**
  (FERM.JUICE) to start the brew — one minute of play time, and the
  timer survives saving.
- When the dome shows an egg, interact and **HATCH**: a level-1
  hatchling joins your party (or the PC when the party is full) and is
  recorded in the POKéDEX.
- **Breeding pairings**: certain line combinations hatch something
  rarer — PIDGEY line x SPEAROW line hatches FARFETCH'D. Any family
  member counts (PIDGEOT x FEAROW works). Curate the pairing table with
  `tools/breed_lines_designer.html` (open it in a browser, design, copy
  the Lua export over the BREED_LINES block in `main.lua`).
- Parent picking uses the same sprite grid as everything else — your
  base crew as cells, the highlighted candidate's jobs below.
- **Who can breed:** a pair must share an evolution line (CHARMANDER x
  CHARIZARD works) or complete one of the special pairings. Anything
  else is **greyed out in the picker** — no guessing, no wasted juice.
  Same-line pairs hatch the line's base form.
- **Spoiler-free hints**: while picking the second parent, a partner
  that completes a special pairing shows **?!** instead of its level,
  and a matched pair "gets along famously!" when assigned — the game
  tells you *these two* are onto something, never *what* the egg holds.
- **Breed-only species leave the wild.** Everything in the BREED_ONLY
  list is stripped from grass/water encounter tables; each freed slot is
  re-filled with that table's lead species at the same level, so no
  route thins out. (Farfetch'd was already trade-only in RED's wild
  tables — the machinery is live for everything you curate next.)
- **Every clutch needs fresh parents** — hatching clears the
  assignment, so breeding stays a deliberate choice.
- Hovering a candidate in the parent picker lists **who it can breed
  with** right in the panel.

## The GRAPE FARM

The incubator drinks **FERM.JUICE**, and juice comes from farming:

- **GRAPE SEEDS** are rare (10% from bug/grass/flying wins) — they
  gate breeding, and **vines are one-shot now**: one seed grows one
  grape, no seed back, then the plot clears. Press **A on bare dirt**
  to plant straight from the patch.
- Your base has a **tilled 2x2 dirt patch** (mid-left of the room,
  real cave-floor tiles derived from your own ROM cache) — **seeds
  only take root in the dirt**, one vine per plot, four plots. The
  soil stays visible under whatever grows on it, and nobody walks on
  the crops — tend the patch from its edge.
- A vine only grows while your base houses a **GRASS or BUG POKéMON**
  (the grower) and a **WATER POKéMON** (the waterer) — about 90 seconds
  of play time per harvest, and progress pauses whenever the crew is
  missing.
- Ferment **3 GRAPES into FERM.JUICE** at the crafting table — three
  seeds' worth, so every juice is a real investment.
- **Automation:** craft a **CHEST** (4 WOOD at the table) and keep a
  **TRANSPORT POKéMON** around — ripe vines then harvest
  themselves into the chest and replant on their own, forever. Open the
  chest to collect.
- The housewarming ball now holds one FERM.JUICE, so your first egg
  never waits on the farm.

## Humble starts, classic hunts

Oak's three lab balls now hold **ZUBAT, MEOWTH, and DIGLETT** — no
early powerhouse. The balls still *read* as the classic trio to the
story: pick any ball and the rival takes his usual counterpick, so
every rival fight down the line is untouched.

The classics moved out into the world instead:

- **BULBASAUR** dens in the Route 24 grass at ~5% (the 13/256 slot).
- **CHARMANDER** dens on Route 7, same odds.
- **SQUIRTLE** strikes a **GOOD ROD** line — the rod is craftable at
  the table (2× WOOD + 1× INGOT), and a share of its successful bites
  (`BALANCE.squirtleChance`, 25%) is the turtle instead of the usual
  GOLDEEN/POLIWAG. Misses stay misses, so bite odds never change.

All three left the breed-only roster; their breeding pairings still
work as a second path.

## LEGENDS on the streets

Every **two hours** a boss POKéMON stalks each gym town (and a few
routes),
type-matched to the local gym and favoring trade evolutions you can't
otherwise get solo — GOLEM in Pewter, ALAKAZAM in Saffron, GENGAR in
Lavender, MACHAMP on Route 5, plus SNORLAX, RAICHU, BLASTOISE,
VENUSAUR, CHARIZARD, MUK, RHYDON, and DRAGONITE. Twelve in all,
level 25 in Pewter climbing to 55 on Route 23.

Street bosses **cannot be caught** — balls just bounce off — and
they **never carry SELFDESTRUCT or EXPLOSION** (a boss that blows
itself up hands over its bounty for free; banned moves are swapped
for real attacks from its own learnset). Beat one
and it drops a **RARE CANDY** plus a typed **LEGENDARY SHARD** (ROCK
SHARD, PSY SHARD, ...), then leaves the square until the hour rolls
over. If your bag is full the bounty waits until you make room.

Fuse **8 shards of one type** into that type's **TABLET** at the
**SUMMONING ALTAR** — a craftable MK2 station (3× INGOT + 4× ORE).
Bring the tablet back with a party of **six POKéMON all sharing that
type** and the altar summons an **empowered boss at double its street
level** (capped at 100). The summon *is* catchable — win or catch,
the tablet burns either way.

Clocks and numbers live in `BALANCE`: `bossSeconds` (two-hourly,
`PALCRAFT_BOSS_SECONDS` to taste), `shardsPerTablet` (8), and
`summonMultiplier` (2).

## No version exclusives

Red and Blue each hide half of seven classic pairs (Weedle/Caterpie,
Ekans/Sandshrew, Oddish/Bellsprout, Mankey/Meowth, Growlithe/Vulpix,
Scyther/Pinsir, Electabuzz/Magmar). Whichever side your cartridge is
missing moves into its counterpart's grass with **the encounter odds
split down the middle** — slots are partitioned by their real Gen 1
probability buckets, so a species found 60% of the time becomes two
species at ~30% each, at the same levels and matching evolution stages.
Skipped for anything deliberately breed-only. On Red that heals
**Bellsprout, Meowth, and Vulpix** into the wild.

## Recipes

| Ball | Cost |
|---|---|
| POKé BALL | 2× RED APRICORN |
| GREAT BALL | 2× BLU APRICORN + 1× RED APRICORN |
| ULTRA BALL | 2× YLW APRICORN + 1× BLU APRICORN |

Drop weights: RED 60 / BLU 28 / YLW 12.

Story gifts and scripted balls (Oak's tutorial, etc.) are untouched — only
mart *shelves* change, and other mods' shelf additions survive (this mod
loads late and filters the merged view; only items that route into the
`balls` registry are removed).

## The ESSENCE CONDENSER and the star system

Every POKéMON carries a hidden **star rank** that scales its stats:

| Stars | Stats | Who |
|---|---|---|
| ★0 | 70% | fresh catches — every wild catch lands weakened |
| ★1 | 90% | hatchlings, starters, gifts, trades, and pre-existing mons |
| ★2 | 100% | condensed once past star 1 |
| ★3 | 120% | fully condensed |

Only condensing reaches 100% and beyond — enemy and trainer POKéMON
are untouched and always fight at full strength. The rank shows as
`[n]` next to every name on the BASE POKéMON roster, the MOVE TO BASE
picker, and the CONDENSER's own screens (the GB font has no star
glyph, so brackets carry the rank).

The **CONDENSER** (craftable at the table from day one, 2× WOOD +
2× ORE) raises a party POKéMON's star by consuming offers from **anywhere in
its evolution line** (a CHARMANDER feeds a CHARIZARD), drawn from
your party and boxes: 1 offer for the first star, 2 for the second,
3 for the third. Surplus hatchlings and duplicate catches
finally have a job.

**Egg moves**: hatchlings roll bonus moves from their species' TM
compatibility list (HMs excluded, never a duplicate) — 50% chance of
one, 20% of two, 5% of three. A hatched MAGMAR can open with EMBER
*and* BODY SLAM instead of waiting until level 36 for its second move.

The incubator's ASSIGN screens now show the full **pairing catalog**
for whoever you hover: every special pairing and its child
(`SPEAROW>FARFETCH'D`) even when the partner isn't in the base — and
when a line has no mutation, the same-species default and its
base-form child.

## Difficulty

The mod options screen carries a **DIFFICULTY** choice:

- **NORMAL** — vanilla EXP, nothing changes.
- **HARD** — POKéMON that were not hatched from the incubator earn
  **half EXP** from every battle. Stacked with the star system (wild
  catches start at 70% stats), breeding becomes the main engine. Hatchlings carry a permanent `bred`
  mark (like the trade boost, it lives on the save), so the intended
  loop is: breed at the incubator, raise the hatchling on TRAINING
  DUMMY rare candies, and field bred teams — wild catches stay usable
  but level slowly.

## Quality of life

- **Deep pockets**: no practical bag-slot limit and every item stacks
  to **999** (`BALANCE.bagSize` / `stackMax`).
- The **ITEMS list pages** with LEFT/RIGHT.
- Crafting stations **chime** when an order comes off the queue.
- Every station **draws materials from the base CHEST** as well as the
  bag (bag pays first) — craft table, MK2, furnace, and medicine bench
  alike.
- **Gym badges announce their blueprints**: Brock's badge unlocks the
  INCUBATOR recipe, Misty's the WOODPILE, Lt. Surge's the GENERATOR —
  and each says so the moment the badge lands.
- Placing the GENERATOR with a GENERATING POKéMON on the crew (or
  assigning one later) announces **"MK2 recipes are live at the CRAFT
  TABLE"** the moment the grid comes alive.
- Battle drops **follow the dialog**: they arrive on the first quiet
  overworld frame after any running script or text finishes, never in
  the middle of one.
- **Evolution stones are craft-only**: no shelf sells them and every
  ground or hidden stone in Kanto became an ORE cache — the MK2 table
  is the one source.
- The WOODPILE and ORE ROCK talk text spells out the **crew speedup**
  (clock ÷ best job level).

## Notes for tuning

- Pickup coordinates live in one `SPOTS` table in `main.lua`. The eye-check
  driver sweeps every spot and fails if one lands on a non-walkable cell,
  so move them freely and re-run it.
- A shelf that sold *only* balls falls back to selling a POTION rather
  than going empty.

## Roadmap

- A **placeable crafting table** overworld object (interact to open the
  same screen) instead of / alongside the Start-menu row.
- Apricorn **trees** that respawn daily rather than one-time hidden spots.
- Kurt-style specialty balls (LEVEL, LURE, MOON...) on the `balls`
  registry's real Gen 1 catch math.

## Tests

```
luajit mods/palworld_crafting/tests/palworld_crafting_test.lua
python3 tools/modkit.py validate palworld_crafting
# with overworld_encounters installed: base POKéMON wear per-species walkers
POKEPORT_DRIVER=mods/palworld_crafting/tests/driver_dep_check.lua \
  POKEPORT_IDENTITY=depcheck love .
```
