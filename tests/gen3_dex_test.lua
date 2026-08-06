-- Standalone: luajit mods/gen3_dex/tests/gen3_dex_test.lua
--
-- Written against what the last three releases of Gen 3 Box got wrong on a
-- real screen and not in a suite: text placed with numbers meant for a
-- 144-tall canvas, palette zones for a pane that was not on screen, a base
-- zone that was missing entirely so everything around the cells composited
-- black, and a picture scale that assumed the ROM's own sprite size.
--
-- So this file checks the LAYOUT and the ZONES, not only the data.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Runtime = require("src.mods.Runtime")

local DIR = os.getenv("GEN3_DEX_DIR") or "mods/gen3_dex"
local run = T.sdk.loadMod(DIR, { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- Registration, through the registry the game uses -- not by reading the
-- file. A screen that registers but cannot be opened is the failure mode
-- that shipped Modern Kanto 0.1.0 inert.
local factory = Data.screens and Data.screens.Gen3Dex
T.check(factory ~= nil, "the Gen3Dex screen is registered")

local loader = run.loader
loader.modOptions = loader.modOptions or {}
loader.modOptions.gen3_dex = loader.modOptions.gen3_dex or {}
local store = loader.modOptions.gen3_dex

-- ------- a save to look at
--
-- Three states, because the screen draws three: owned, seen, and never
-- met. Anything that only tested "owned" would miss two thirds of it.

local dexOrder = {}
for id, def in pairs(Data.pokemon) do
  if def.dex then dexOrder[def.dex] = id end
end
local ordered = {}
for n = 1, 151 do if dexOrder[n] then ordered[#ordered + 1] = dexOrder[n] end end
T.check(#ordered > 0, ("the dataset has a dex to show (%d)"):format(#ordered))

-- The counts below are taken as FRACTIONS of whatever dex this dataset
-- carries: CI boots a 3-species fixture and the ROM gives 151, and a test
-- written around "30 owned" only works on one of them.
local OWNED = math.max(1, math.floor(#ordered / 3))
local SEENX = math.max(1, math.floor(#ordered / 6))
T.check(OWNED + SEENX <= #ordered, "the sample fits the dataset")

local pressed = {}
local function fakeGame(ownedN, seenN)
  local owned, seen = {}, {}
  for i = 1, ownedN do owned[ordered[i]] = true; seen[ordered[i]] = true end
  for i = ownedN + 1, ownedN + seenN do seen[ordered[i]] = true end
  return {
    data = Data,
    save = { pokedex = { owned = owned, seen = seen } },
    stack = { pop = function() end },
    input = { wasPressed = function(_, k) return pressed[k] end },
  }
end
local function press(k) pressed = {}; pressed[k] = true end

-- ------- it opens, and it counts

store.grid = "big"
do
  local g = fakeGame(OWNED, SEENX)
  local ok, s = pcall(factory.new, g)
  T.check(ok, "the screen OPENS (" .. tostring(not ok and s or "") .. ")")
  T.eq(s.owned, OWNED, "it counts what you own")
  T.eq(s.seen, OWNED + SEENX, "and what you have seen, owned included")
  T.eq(s.total, #ordered, "against the whole dex")
  T.eq(#s.entries, #ordered, "and ALL is every entry, caught or not")
end

-- ------- the filters actually filter

do
  local g = fakeGame(OWNED, SEENX)
  local s = factory.new(g)
  local names, counts = {}, {}
  for i = 1, #run.loader.exports.gen3_dex.filters do
    names[i] = run.loader.exports.gen3_dex.filters[i].label
    counts[i] = #s.entries
    press("select"); s:update()
  end
  T.eq(counts[1], #ordered, "ALL shows everything")
  T.eq(counts[2], OWNED, "OWNED shows only what you own")
  T.eq(counts[3], #ordered - OWNED, "MISSING shows everything you do not own")
  T.eq(counts[4], SEENX, "SEEN ONLY shows what you met but never caught")
  -- and it comes back round rather than running off the end
  T.eq(#s.entries, #ordered, "and the filter cycles back to ALL")
end

-- ------- the cursor moves, wraps, and pages

do
  local g = fakeGame(#ordered, 0)
  local s = factory.new(g)
  T.eq(s.index, 0, "it starts at the first entry")
  if #s.entries < 26 then
    T.check(true, ("only %d entries here: the paging checks need a real dex")
      :format(#s.entries))
    goto skipNav
  end
  press("right"); s:update()
  T.eq(s.index, 1, "RIGHT steps one")
  press("left"); s:update()
  T.eq(s.index, 0, "LEFT steps back")
  press("left"); s:update()
  T.eq(s.index, #s.entries - 1, "and wraps to the end rather than sticking")
  press("right"); s:update()
  T.eq(s.index, 0, "and back round")
  press("down"); s:update()
  T.eq(s.index, 5, "DOWN moves a whole row")
  press("start"); s:update()
  T.eq(s.index, 25, "START jumps a page")
  ::skipNav::
end

-- ------- A opens the ENGINE's entry page, which is where Useful Dex lives

do
  local Screens = require("src.ui.Screens")
  local g = fakeGame(math.min(5, #ordered), 0)
  local s = factory.new(g)
  local pushed, arg
  local realPush = Screens.push
  Screens.push = function(_, id, a) pushed, arg = id, a end
  press("a"); s:update()
  Screens.push = realPush
  T.eq(pushed, "DexEntryMenu",
    "A opens the engine's own species page, not a copy of it")
  T.eq(arg, ordered[1], "for the species under the cursor")
end

do
  -- and refuses a species you have never met, as the vanilla list does
  local Screens = require("src.ui.Screens")
  local g = fakeGame(0, 0)
  local s = factory.new(g)
  local pushed
  local realPush = Screens.push
  Screens.push = function(_, id) pushed = id end
  press("a"); s:update()
  Screens.push = realPush
  T.check(pushed == nil, "and does nothing on a species you have never met")
end

-- ------- the surface, and the zones on it

do
  local g = fakeGame(OWNED, SEENX)
  local s = factory.new(g)
  local w, h = s:uiSize()
  T.eq(w, 320, "BIG asks for a 320-wide surface")
  T.eq(h, 288, "and 288 tall")
  T.check(w <= 640 and h <= 576, "within what setUISize will grant")

  if PaletteFX.monPal(Data, ordered[1]) then
    local zones = s:sgbPalettes()
    T.check(zones ~= nil, "BIG asks for zones")

    -- zone 1 is the BASE, and it must span the WHOLE surface. Without it
    -- only the cells are remapped and everything else composites black,
    -- header and footer included since they are drawn in black.
    -- PaletteFX.whole() cannot serve: it is hardcoded to 160x144.
    local base = zones[1]
    T.eq(base.x, 0, "the base zone starts at the origin")
    T.eq(base.y, 0, "in both axes")
    T.eq(base.w, w, "and spans the whole surface width")
    T.eq(base.h, h, "and the whole height")

    -- one per OWNED entry on the page, and nothing for the rest: a
    -- species you have not caught should not advertise its colours
    local onPage = math.min(20, OWNED)
    T.eq(#zones, 1 + onPage, "the base plus one per owned entry on the page")

    local bad = {}
    for i = 2, #zones do
      local z = zones[i]
      if z.x % 8 ~= 0 or z.y % 8 ~= 0 then
        bad[#bad + 1] = ("zone %d starts mid-tile (%d,%d)"):format(i, z.x, z.y)
      end
      if z.x + z.w > w or z.y + z.h > h then
        bad[#bad + 1] = ("zone %d runs off the canvas"):format(i)
      end
      if z.w ~= 56 or z.h ~= 56 then
        bad[#bad + 1] = ("zone %d is %dx%d, not one cell"):format(i, z.w, z.h)
      end
      for j = i + 1, #zones do
        local o = zones[j]
        if z.x < o.x + o.w and o.x < z.x + z.w
           and z.y < o.y + o.h and o.y < z.y + z.h then
          bad[#bad + 1] = ("zones %d and %d overlap"):format(i, j)
        end
      end
    end
    T.eq(#bad, 0, "every zone is aligned, on screen and alone (" ..
      table.concat(bad, "; ") .. ")")

    -- a page of nothing-but-unowned must still carry the base, or the
    -- screen goes black exactly where there is least to look at
    local empty = factory.new(fakeGame(0, math.min(5, #ordered)))
    local ez = empty:sgbPalettes()
    T.eq(#ez, 1, "a page with nothing owned still carries its base zone")
    T.eq(ez[1].w, w, "covering the surface")
  else
    T.check(true, "fixture dataset: no species palettes, zone checks skipped")
  end
end

-- ------- CLASSIC: the Game Boy surface, and no zones it cannot align

do
  store.grid = "classic"
  local g = fakeGame(OWNED, SEENX)
  local s = factory.new(g)
  T.eq(select(1, s:uiSize()), 160, "CLASSIC keeps the Game Boy surface")
  T.eq(select(2, s:uiSize()), 144, "in both directions")
  T.check(s:sgbPalettes() == nil,
    "and asks for no zones -- a 28px cell is three and a half tiles")
  store.grid = "big"
end

-- ------- nothing is drawn where it cannot be read

do
  local g = fakeGame(OWNED, SEENX)
  local s = factory.new(g)
  local W, H = s:uiSize()
  local gx, gy, cell = 16, 40, 56
  local gridBottom = gy + 4 * cell

  local lines = {}
  local realDraw = Font.draw
  Font.draw = function(text, x, y)
    lines[#lines + 1] = { text = text, x = x, y = y, w = Font.width(text) }
  end
  s:draw()
  Font.draw = realDraw

  T.check(#lines > 0, "the screen draws some text")
  local bad = {}
  for _, l in ipairs(lines) do
    if l.x + l.w > W then
      bad[#bad + 1] = ("%q runs to %d on a %d-wide surface")
        :format(l.text, l.x + l.w, W)
    end
    if l.y + 8 > H then
      bad[#bad + 1] = ("%q runs to %d on a %d-tall surface")
        :format(l.text, l.y + 8, H)
    end
    if l.y + 8 > gy and l.y < gridBottom and l.x < gx + 5 * cell then
      bad[#bad + 1] = ("%q at y=%d is inside the grid (%d..%d)")
        :format(l.text, l.y, gy, gridBottom)
    end
  end
  T.eq(#bad, 0, "no line lands on the grid or off the surface (" ..
    table.concat(bad, "; ") .. ")")

  -- and the wider surface is actually used, rather than measured as 160
  s.entries[1] = { n = 1, def = { id = "X", name = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" },
                   state = "owned" }
  s.index = 0
  local shown
  Font.draw = function(text, _, y) if y >= gridBottom then shown = text end end
  s:draw()
  Font.draw = realDraw
  T.check(shown and #shown > 19,
    ("BIG uses its width: %d glyphs (19 would be the Game Boy)")
      :format(shown and #shown or 0))
end

-- ------- a custom sprite must not spill into its neighbours

do
  local s = factory.new(fakeGame(math.min(5, #ordered), 0))
  local function img(n)
    return { getWidth = function() return n end, getHeight = function() return n end }
  end
  local over = {}
  for _, cell in ipairs({ 28, 56 }) do
    for _, size in ipairs({ 40, 56, 64, 112, 160, 168, 224 }) do
      local k = s.picScale(img(size), cell)
      if size * k > cell then
        over[#over + 1] = ("%dpx pic drawn %gpx in a %d cell")
          :format(size, size * k, cell)
      end
      local whole = (k >= 1 and k % 1 == 0) or (k < 1 and (1 / k) % 1 == 0)
      if not whole then
        over[#over + 1] = ("%dpx pic scaled by %g, not a whole step"):format(size, k)
      end
    end
  end
  T.eq(#over, 0, "no picture ever spills its cell (" ..
    table.concat(over, "; ") .. ")")
end

-- ------- the ways in

do
  local function startRows()
    return { { label = "POKéDEX" }, { label = "POKéMON" }, { label = "SAVE" } }
  end
  local rows = Runtime.call("ui.start_menu.items", function(_, i) return i end,
    {}, startRows())
  local dexRow
  for _, r in ipairs(rows) do
    local l = tostring(r.label)
    if l:find("POK") and l:find("DEX") then dexRow = r end
  end
  T.check(dexRow ~= nil, "the POKeDEX row is still there")
  T.check(type(dexRow.onSelect) == "function",
    "and REPLACE DEX gave it something to do")

  local Screens = require("src.ui.Screens")
  local pushed
  local realPush = Screens.push
  Screens.push = function(_, id) pushed = id end
  pcall(dexRow.onSelect)
  Screens.push = realPush
  T.eq(pushed, "Gen3Dex", "which is this grid")

  -- another mod's row must survive the wrap
  local shared = Runtime.call("ui.start_menu.items", function(_, items)
    table.insert(items, 1, { label = "DEXNAV" })
    return items
  end, {}, startRows())
  local kept = false
  for _, r in ipairs(shared) do if r.label == "DEXNAV" then kept = true end end
  T.check(kept, "another mod's start-menu row survives the wrap")
end

run.release()
T.finish("gen3_dex")
