-- dump every species' work suitabilities using the mod's own rules,
-- run against a real dex dump (fixture data everywhere else):
--
--   luajit mods/palworld_crafting/tools/gen_work_table.lua \
--     <path to the generated pokemon.lua>
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.fresh()
local dexPath = assert(arg and arg[1],
  "usage: gen_work_table.lua <path to generated pokemon.lua>")
local realDex = dofile(dexPath)
for k in pairs(Data.pokemon) do Data.pokemon[k] = nil end
for k, v in pairs(realDex) do Data.pokemon[k] = v end
local run = T.sdk.loadMod("mods/palworld_crafting", { data = Data })
assert(#run.errors == 0, tostring(run.errors[1]))
local ex = run.loader.exports.palworld_crafting

local mons = {}
for id, def in pairs(realDex) do
  if def.dex and def.types then mons[#mons + 1] = { id = id, def = def } end
end
table.sort(mons, function(a, b) return a.def.dex < b.def.dex end)

for _, m in ipairs(mons) do
  local suits = ex.workSuitabilities(m.id)
  local parts = {}
  for _, s in ipairs(suits) do
    parts[#parts + 1] = s.job .. ":" .. s.level
  end
  local overridden = ex.workOverrides[m.id] and 1 or 0
  print(table.concat({
    m.def.dex, m.id, m.def.name or m.id,
    table.concat(m.def.types, "/"),
    ex.stageOf(m.id), table.concat(parts, ","), overridden,
  }, "|"))
end
