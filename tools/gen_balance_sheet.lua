-- Dump the BALANCE table and every recipe list as TSV, for the balance
-- sheet artifact.  Run WITHOUT any PALCRAFT_* env overrides:
--   luajit mods/palworld_crafting/tools/gen_balance_sheet.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.fresh()
local run = T.sdk.loadMod("mods/palworld_crafting", { data = Data })
assert(#run.errors == 0, tostring(run.errors[1]))
local ex = run.loader.exports.palworld_crafting

local keys = {}
for k in pairs(ex.balance) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
  local v = ex.balance[k]
  if type(v) ~= "function" then
    print(("balance\t%s\t%s"):format(k, tostring(v)))
  end
end

local function dumpRecipes(section, list)
  for _, r in ipairs(list) do
    local costs = {}
    for _, c in ipairs(r.cost) do
      costs[#costs + 1] = c[1] .. ":" .. c[2]
    end
    print(("%s\t%s\t%s\t%s\t%s\t%s"):format(
      section, r.ball, r.label, r.work or "",
      table.concat(costs, ","),
      r.badge or r.tier or r.insight or ""))
  end
end
dumpRecipes("craft", ex.recipes)
dumpRecipes("station", ex.stationRecipes)
dumpRecipes("mk2", ex.mk2Recipes)
dumpRecipes("brew", ex.brewRecipes)

for _, b in ipairs(ex.bosses) do
  print(("boss\t%s\t%s\t%s\t%s\t%s"):format(
    b.key, b.species, b.level, b.type, b.map))
end
