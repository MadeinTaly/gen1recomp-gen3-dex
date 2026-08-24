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
local pushedStates = {}
local function fakeGame(ownedN, seenN)
  pushedStates = {}
  local owned, seen = {}, {}
  for i = 1, ownedN do owned[ordered[i]] = true; seen[ordered[i]] = true end
  for i = ownedN + 1, ownedN + seenN do seen[ordered[i]] = true end
  return {
    data = Data,
    save = { pokedex = { owned = owned, seen = seen } },
    stack = { pop = function() end,
              push = function(_, st) pushedStates[#pushedStates + 1] = st end },
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
  -- A OPENS = DATA goes straight to the engine's own species page, which
  -- is where a mod like Useful Dex hangs its extra pages
  local Screens = require("src.ui.Screens")
  store.action = "data"
  local g = fakeGame(math.min(5, #ordered), 0)
  local s = factory.new(g)
  local pushed, arg
  local realPush = Screens.push
  Screens.push = function(_, id, a) pushed, arg = id, a end
  press("a"); s:update()
  Screens.push = realPush
  store.action = "menu"
  T.eq(pushed, "DexEntryMenu",
    "A OPENS=DATA reaches the engine's own species page, not a copy of it")
  T.eq(arg, ordered[1], "for the species under the cursor")
end

-- ------- DATA / CRY / AREA
--
-- The vanilla list offered all three (PokedexMenuItemsText). The first
-- version of this grid went straight to DATA and silently dropped the
-- other two -- including AREA, which is the engine's own
-- LoadTownMap_Nest: TownMap with nestSpecies, blinking an icon on every
-- map whose wild slots hold the species. The "where does this live"
-- screen was already in the engine the whole time.
do
  local Screens = require("src.ui.Screens")
  local g = fakeGame(math.min(5, #ordered), 0)
  local s = factory.new(g)
  press("a"); s:update()

  -- The choice is drawn BY this screen, not pushed as one of its own.
  -- A pushed menu becomes the top state, and Game:draw sizes the canvas
  -- from the top state -- so a menu with no uiSize() shrinks the surface
  -- back to 160x144 while this grid is still visible underneath, laid out
  -- for 320x288. That shipped in 0.2.0 and showed three columns of five.
  T.eq(#pushedStates, 0, "A pushes nothing on top of the grid")
  T.check(s.choice ~= nil, "it opens its own choice instead")

  local byLabel = {}
  for _, c in ipairs(s.choices) do byLabel[c.label] = c end
  T.check(byLabel.DATA ~= nil, "the choice offers DATA")
  T.check(byLabel.CRY ~= nil, "and CRY, which 0.1.0 lost")
  T.check(byLabel.AREA ~= nil, "and AREA, the map of where it lives")

  -- AREA must reach the ENGINE's nest screen, not a lookalike
  local pushed, arg
  local realPush = Screens.push
  Screens.push = function(_, id, a) pushed, arg = id, a end
  byLabel.AREA.act(ordered[1])
  Screens.push = realPush
  T.eq(pushed, "TownMap", "AREA opens the town map")
  T.eq(type(arg) == "table" and arg.nestSpecies or nil, ordered[1],
    "asking it to blink the nests of this species")

  -- and the choice takes the input while it is up, rather than letting the
  -- cursor wander behind it
  local before = s.index
  press("down"); s:update()
  T.eq(s.index, before, "the grid cursor does not move while the choice is up")
  T.eq(s.choice.index, 2, "the choice cursor does")
  press("b"); s:update()
  T.check(s.choice == nil, "and B closes it")
end

-- ------- the layout follows the SURFACE, not the preference
--
-- This is the 0.2.0 bug, made into an assertion. Game:draw sizes the
-- canvas from the top state, so anything over this screen puts it back to
-- 160x144 while this one still draws underneath. Laying out for 320x288
-- on a 160-wide surface draws three of five columns and runs the header
-- off the edge.
do
  local Renderer = require("src.render.Renderer")
  local g = fakeGame(math.min(5, #ordered), 0)
  local s = factory.new(g)

  local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
  Renderer.uiWidth, Renderer.uiHeight = 320, 288
  T.eq(select(1, s:uiSize()), 320, "it still ASKS for the big surface")

  local wide = {}
  local realDraw = Font.draw
  Font.draw = function(text, x, y)
    wide[#wide + 1] = { x = x, y = y, w = Font.width(text), text = text }
  end
  s:draw()

  -- now pretend something took the canvas back, as a pushed screen does
  Renderer.uiWidth, Renderer.uiHeight = 160, 144
  local narrow = {}
  Font.draw = function(text, x, y)
    narrow[#narrow + 1] = { x = x, y = y, w = Font.width(text), text = text }
  end
  s:draw()
  Font.draw = realDraw
  Renderer.uiWidth, Renderer.uiHeight = w0, h0

  local bad = {}
  for _, l in ipairs(narrow) do
    if l.x + l.w > 160 then
      bad[#bad + 1] = ("%q runs to %d on a 160-wide surface"):format(l.text, l.x + l.w)
    end
    if l.y + 8 > 144 then
      bad[#bad + 1] = ("%q runs to %d on a 144-tall surface"):format(l.text, l.y + 8)
    end
  end
  T.eq(#bad, 0, "on a shrunken surface nothing runs off it (" ..
    table.concat(bad, "; ") .. ")")

  -- and the two layouts really are different, or the check above is empty
  local movedFooter = false
  for i = 1, math.min(#wide, #narrow) do
    if wide[i].y ~= narrow[i].y then movedFooter = true end
  end
  T.check(movedFooter, "and the layout really did change with the surface")
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
  local Renderer = require("src.render.Renderer")
  local g = fakeGame(OWNED, SEENX)
  local s = factory.new(g)
  local w, h = s:uiSize()
  T.eq(w, 320, "BIG asks for a 320-wide surface")
  T.eq(h, 288, "and 288 tall")
  T.check(w <= 640 and h <= 576, "within what setUISize will grant")

  -- Game:draw grants the surface BEFORE anything draws, so the zones are
  -- computed against 320x288. Standing in for that here rather than
  -- assuming it.
  local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
  Renderer.uiWidth, Renderer.uiHeight = w, h

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
  Renderer.uiWidth, Renderer.uiHeight = w0, h0
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

-- ------- Gen 2: BIG reaches the screen through Gold's own widescreen
-- contract, not through `uiSize()`
--
-- Game2 (src/core/Game2.lua) grants a bigger surface only to a state that
-- answers `drawsWidescreen()` true and paints itself through
-- `drawWidescreen(w, h)` -- see Game2:drawScene, Game2.lua:1450-1600, and
-- PcMenu.lua:77-78/325, SummaryMenu.lua:230-231/1119 and PokedexMenu.lua:
-- 134-135/1462 for the pattern real Gold screens follow. This checks the
-- same contract this screen now answers on a Gen 2 save, and that CLASSIC
-- never takes a single step toward it.

local function fakeGen2Game(ownedN, seenN)
  local g = fakeGame(ownedN, seenN)
  g.save.generation = 2
  return g
end

do
  store.grid = "big"
  local g = fakeGen2Game(OWNED, SEENX)
  local s = factory.new(g)
  T.check(s:drawsWidescreen(),
    "BIG on Gen 2 opts into Gold's widescreen contract")
  T.check(s:wantsFillScale(), "and answers wantsFillScale the same way")

  -- drawWidescreen must not crash, and must actually draw the wider BIG
  -- layout inside whatever window Game2 hands it -- not the 160-wide
  -- Game Boy one CLASSIC would use
  local lines = {}
  local realDraw = Font.draw
  Font.draw = function(text, x, y)
    lines[#lines + 1] = { text = text, x = x, y = y, w = Font.width(text) }
  end
  local ok, err = pcall(s.drawWidescreen, s, 640, 576)
  Font.draw = realDraw
  T.check(ok, "drawWidescreen runs clean (" .. tostring(not ok and err or "") .. ")")
  T.check(#lines > 0, "and actually draws something")
  local wide = false
  for _, l in ipairs(lines) do
    if l.x + l.w > 160 then wide = true end
  end
  T.check(wide, "using the wider BIG layout, not the 160-wide Game Boy one")

  -- Gold colours itself: porting the palette-zone half was explicitly out
  -- of scope, and BIG no longer forcing CLASSIC here must not resurrect it
  T.check(s:sgbPalettes() == nil,
    "no per-species palette zones on Gen 2, even for BIG")
end

do
  -- CLASSIC must be untouched: no widescreen opt-in, and the same answers
  -- this screen has always given on a Gen 2 save.
  store.grid = "classic"
  local g = fakeGen2Game(OWNED, SEENX)
  local s = factory.new(g)
  T.check(not s:drawsWidescreen(),
    "CLASSIC never opts into the widescreen contract, even on Gen 2")
  T.check(not s:wantsFillScale(), "or asks for a fill scale")
  T.eq(select(1, s:uiSize()), 160,
    "uiSize follows the option, which is CLASSIC here")
  T.eq(select(2, s:uiSize()), 144, "in both directions")
  T.check(s:sgbPalettes() == nil, "and CLASSIC still asks for no zones")
  store.grid = "big"
end

-- ------- nothing is drawn where it cannot be read

do
  local Renderer = require("src.render.Renderer")
  local g = fakeGame(OWNED, SEENX)
  local s = factory.new(g)
  local W, H = s:uiSize()
  local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
  Renderer.uiWidth, Renderer.uiHeight = W, H
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
  Renderer.uiWidth, Renderer.uiHeight = w0, h0
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

-- ------- Wilds of Kanto's overworld sprites: the seam, not the pixels
--
-- No graphics context in this suite and the other mod is never actually
-- installed, so this stubs the accessor the seam is funnelled through
-- (self.owHandle, which wraps mod.find in a pcall) rather than loading a
-- second mod, and checks what SEAM.md asks for: absence changes nothing,
-- a hit is drawn CLASSIC-only, a black fallback and a throwing resolve
-- both fall back silently, and the option gate means the seam is never
-- even consulted when it is off.

local function fakeOwHandle(resolveFn)
  return { id = "overworld_wild_spawns", version = "1.14.0",
           exports = { spriteProviders = { resolve = resolveFn } } }
end

do
  store.ow_sprites = true
  local sampleId = ordered[1]

  -- absence: no handle at all
  do
    local s = factory.new(fakeGame(math.min(5, #ordered), 0))
    s.owHandle = function() return nil end
    T.check(s.owSprite({ id = sampleId }) == nil,
      "no handle: the seam answers nothing")
  end

  -- a hit: def + frames stacked vertically, resolved with OUR species id,
  -- the player's own Sprite Style (style = nil), and the default variant
  do
    local s = factory.new(fakeGame(math.min(5, #ordered), 0))
    local seenArgs
    s.owHandle = function()
      return fakeOwHandle(function(_, style, speciesId, variant, game)
        seenArgs = { style = style, speciesId = speciesId, variant = variant,
                     game = game }
        return { def = { image = "assets/ow_fake.png", frames = 6 },
                 providerId = "followers_ex" }
      end)
    end
    local sprite = s.owSprite({ id = sampleId })
    T.check(sprite ~= nil, "a real def resolves to a drawable sprite")
    T.check(type(sprite.getWidth) == "function"
      and type(sprite.getHeight) == "function",
      "shaped so picScale can size it like any other picture")
    T.eq(seenArgs.style, nil, "style nil takes the player's own Sprite Style")
    T.eq(seenArgs.speciesId, sampleId, "asking for OUR species id")
    T.eq(seenArgs.variant, nil, "and the default variant")
  end

  -- black fallback: treated as a miss, not a hit
  do
    local s = factory.new(fakeGame(math.min(5, #ordered), 0))
    s.owHandle = function()
      return fakeOwHandle(function()
        return { def = { image = "assets/ow_fake.png", frames = 1 },
                 providerId = "black", error = "all providers failed" }
      end)
    end
    T.check(s.owSprite({ id = sampleId }) == nil,
      "a black-silhouette result falls back rather than drawing it")
  end

  -- a throwing resolve is caught, not propagated
  do
    local s = factory.new(fakeGame(math.min(5, #ordered), 0))
    s.owHandle = function()
      return fakeOwHandle(function() error("boom") end)
    end
    local ok, sprite = pcall(s.owSprite, { id = sampleId })
    T.check(ok, "a throwing resolve does not take the caller down with it")
    T.check(ok and sprite == nil, "and is treated as a miss")
  end

  -- a handle with no spriteProviders (an older release, say) is a miss too
  do
    local s = factory.new(fakeGame(math.min(5, #ordered), 0))
    s.owHandle = function() return { id = "overworld_wild_spawns", exports = {} } end
    T.check(s.owSprite({ id = sampleId }) == nil,
      "no spriteProviders export: a miss, not a crash")
  end

  store.ow_sprites = false
end

-- the option gate: off means the seam is never even consulted
do
  local Renderer = require("src.render.Renderer")
  store.ow_sprites = false
  store.grid = "classic"
  local s = factory.new(fakeGame(math.min(5, #ordered), 0))
  local calls = 0
  s.owHandle = function() calls = calls + 1
    return fakeOwHandle(function()
      return { def = { image = "x", frames = 1 }, providerId = "followers_ex" }
    end)
  end
  local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
  Renderer.uiWidth, Renderer.uiHeight = select(1, s:uiSize()), select(2, s:uiSize())
  s:draw()
  Renderer.uiWidth, Renderer.uiHeight = w0, h0
  T.eq(calls, 0, "OW SPRITES off: the seam is never consulted, even in CLASSIC")
  store.grid = "big"
end

-- CLASSIC only: BIG keeps the battle pictures even with a working handle
do
  local Renderer = require("src.render.Renderer")
  store.ow_sprites = true
  store.grid = "big"
  local s = factory.new(fakeGame(math.min(5, #ordered), 0))
  local calls = 0
  s.owHandle = function() calls = calls + 1
    return fakeOwHandle(function()
      return { def = { image = "x", frames = 1 }, providerId = "followers_ex" }
    end)
  end
  local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
  Renderer.uiWidth, Renderer.uiHeight = select(1, s:uiSize()), select(2, s:uiSize())
  s:draw()
  Renderer.uiWidth, Renderer.uiHeight = w0, h0
  T.eq(calls, 0, "BIG never consults the seam, option on or not")
  store.ow_sprites = false
end

-- CLASSIC, option on, a working handle: the seam IS consulted, and only
-- for species that are not a blank -- a never-met species must not have
-- the other mod asked to draw it, or its sprite would reveal a Pokemon
-- the player has not encountered
do
  local Renderer = require("src.render.Renderer")
  store.ow_sprites = true
  store.grid = "classic"
  -- Sized off the dataset rather than off 5 and 3: CI runs the engine's
  -- fixture set, which is three species, and a fixed 5/3 split made seenN
  -- NEGATIVE there -- so the "must not be asked" loop started inside the
  -- range the test had just marked owned and failed on its own arithmetic.
  -- At least one of each state, and always one never-met left over, which
  -- is the state this whole block exists to protect.
  local ownedN = math.min(5, math.max(0, #ordered - 2))
  local seenN = math.min(3, math.max(0, #ordered - ownedN - 1))
  local g = fakeGame(ownedN, seenN)
  local s = factory.new(g)
  local asked = {}
  s.owHandle = function()
    return fakeOwHandle(function(_, _, speciesId)
      asked[speciesId] = true
      return { def = { image = "x", frames = 1 }, providerId = "followers_ex" }
    end)
  end
  local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
  Renderer.uiWidth, Renderer.uiHeight = select(1, s:uiSize()), select(2, s:uiSize())
  s:draw()
  Renderer.uiWidth, Renderer.uiHeight = w0, h0

  local askedAny = false
  for _ in pairs(asked) do askedAny = true break end
  T.check(askedAny, "CLASSIC + on + a hit: the seam is actually used")

  for i = 1, ownedN + seenN do
    T.check(asked[ordered[i]], ("owned/seen species %s was asked for")
      :format(ordered[i]))
  end
  for i = ownedN + seenN + 1, math.min(#ordered, ownedN + seenN + 10) do
    T.check(not asked[ordered[i]],
      ("never-met species %s must stay a blank, not be asked for")
        :format(ordered[i]))
  end
  store.ow_sprites = false
  store.grid = "big"
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

-- ------- the choice has a visible cursor
--
-- 0.2.1 drew one with Font.draw(">"). The game's charmap has no ">", and
-- Font.encode answers a missing character with a space -- in the draw
-- path, once, to the log -- so the arrow came out blank and every row
-- looked the same. The cursor is a glyph CODE (Theme.cursor, $ED), which
-- is what every menu in the engine uses.
--
-- Last in the file on purpose: Font.load changes what Font.width answers,
-- and the width assertions above were written against the unloaded
-- fallback.
do
  local Theme = require("src.ui.Theme")
  Font.load(Data)
  T.check(Font.encode("A")[1] ~= 0x7F,
    "sanity: the font is loaded -- unloaded, EVERY glyph reads as a space "
    .. "and the check below would pass for the wrong reason")
  T.eq(Font.encode(">")[1], 0x7F,
    "\">\" is not in the charmap: it encodes to a space, which is the bug")

  store.grid = "big"
  local s = factory.new(fakeGame(math.min(5, #ordered), 0))
  press("a"); s:update()
  T.check(s.choice ~= nil, "the choice is open")

  -- Font.drawBox draws its border through drawCode too, so the corners
  -- come back in the same list -- which is what locates the box.
  local realDraw, realDrawCode = Font.draw, Font.drawCode
  local function capture()
    local texts, codes = {}, {}
    Font.draw = function(t, x, y)
      texts[#texts + 1] = { text = t, x = x, y = y, w = Font.width(t) }
      return 0
    end
    Font.drawCode = function(c, x, y) codes[#codes + 1] = { code = c, x = x, y = y } end
    s:draw()
    Font.draw, Font.drawCode = realDraw, realDrawCode
    local cursors, labels = {}, {}
    for _, c in ipairs(codes) do
      if c.code == Theme.cursor then cursors[#cursors + 1] = c end
    end
    for _, t in ipairs(texts) do
      for _, c in ipairs(s.choices) do
        if t.text == c.label then labels[c.label] = t end
      end
    end
    return cursors, labels, codes
  end

  local cursors, labels, codes = capture()
  T.eq(#cursors, 1, "exactly one cursor glyph is drawn")
  T.check(labels.DATA and labels.CRY and labels.AREA,
    "all three labels are drawn")
  -- guarded: with no cursor at all every line below would crash on nil and
  -- take the rest of the file with it, hiding the checks after this block
  if cursors[1] and labels.DATA then
    T.eq(cursors[1].y, labels.DATA.y, "it sits on the selected row")
    T.check(cursors[1].x + 8 <= labels.DATA.x,
      ("the cursor clears the label (cursor ends %d, label starts %d)")
        :format(cursors[1].x + 8, labels.DATA.x))
  end

  -- inside the box, not spilling over its right border
  local br
  for _, c in ipairs(codes) do
    if c.code == Font.BORDER.br then br = c end
  end
  T.check(br ~= nil, "the choice box is drawn")
  local widest, name = 0, nil
  for label, t in pairs(labels) do
    if t.x + t.w > widest then widest, name = t.x + t.w, label end
  end
  if br then
    T.check(widest <= br.x,
      ("the box holds its longest label: %s ends at %d, the right border is at %d")
        :format(tostring(name), widest, br.x))
  end

  -- and it follows the selection rather than being painted once
  press("down"); s:update()
  T.eq(s.choice.index, 2, "the choice moved to CRY")
  local moved = capture()
  T.eq(#moved, 1, "still exactly one cursor")
  if moved[1] and labels.CRY and cursors[1] then
    T.eq(moved[1].y, labels.CRY.y, "and it moved down with it")
    T.check(moved[1].y ~= cursors[1].y, "which is a different row than before")
  end

  press("b"); s:update()
  T.check(s.choice == nil, "B closes the choice")
  local gone = capture()
  T.eq(#gone, 0, "and no cursor is left behind on the grid")
end


-- ------- the party-menu resolver is preferred over spriteProviders
--
-- Wilds of Kanto draws the sprites a player can already see in the vanilla
-- party menu by patching PartyMenu.drawIcon and going through its follower
-- sprite service (lib/follower/sprite_service.lua:222,384), not through
-- spriteProviders. So that resolver is asked first -- it is the path with a
-- screenshot behind it -- and the never-met gate must survive the change,
-- because a sprite on an unmet species is a spoiler whichever seam drew it.

do
  local Renderer = require("src.render.Renderer")
  store.ow_sprites = true
  store.grid = "classic"

  local function handleWith(partyFn, providerFn)
    return { id = "overworld_wild_spawns", version = "1.14.0", exports = {
      follower = { spriteService = {
        resolvePartyIconDef = function(_, m, g) return partyFn(m, g) end,
      } },
      spriteProviders = providerFn and { resolve = providerFn } or nil,
    } }
  end

  local function drawWith(handle, ownedN, seenN)
    local g = fakeGame(ownedN, seenN)
    local s = factory.new(g)
    s.owHandle = function() return handle end
    local w0, h0 = Renderer.uiWidth, Renderer.uiHeight
    Renderer.uiWidth, Renderer.uiHeight = select(1, s:uiSize()), select(2, s:uiSize())
    s:draw()
    Renderer.uiWidth, Renderer.uiHeight = w0, h0
  end

  local ownedN = math.min(5, math.max(0, #ordered - 2))
  local seenN = math.min(3, math.max(0, #ordered - ownedN - 1))

  -- both offered: the party resolver answers, the provider is never reached
  do
    local partyCalls, providerCalls = 0, 0
    drawWith(handleWith(function()
      partyCalls = partyCalls + 1
      return { image = "assets/party_fake.png", frames = 1 }
    end, function()
      providerCalls = providerCalls + 1
      return { def = { image = "assets/prov_fake.png", frames = 6 },
               providerId = "pokemmo" }
    end), ownedN, seenN)
    T.check(partyCalls > 0, "the party resolver is asked")
    T.eq(providerCalls, 0, "and spriteProviders is not reached behind it")
  end

  -- the never-met gate holds on the new path too
  do
    local asked = {}
    drawWith(handleWith(function(m)
      asked[m and m.species] = true
      return { image = "assets/party_fake.png", frames = 1 }
    end), ownedN, seenN)
    for i = 1, ownedN + seenN do
      T.check(asked[ordered[i]],
        ("owned/seen species %s reaches the party resolver"):format(ordered[i]))
    end
    for i = ownedN + seenN + 1, math.min(#ordered, ownedN + seenN + 10) do
      T.check(not asked[ordered[i]],
        ("never-met species %s is not asked, on this seam either")
          :format(ordered[i]))
    end
  end

  -- a party resolver that throws is caught, and the grid still draws
  do
    local okDraw = pcall(function()
      drawWith(handleWith(function() error("boom") end), ownedN, seenN)
    end)
    T.check(okDraw, "a throwing party resolver does not take the frame down")
  end

  store.ow_sprites = false
end


run.release()

-- ------- the game's own menu icon in a CLASSIC cell (issue #1)
--
-- The reporter had no follower mod at all and expected the mini icons the
-- party list draws. Those come out of the engine's `icons` registry, which
-- is also where every icon mod writes (menyas/unique-menu-icons overrides
-- exactly this table) -- so what is asserted here is the REGISTRY being
-- honoured, not any one mod's art.
--
-- The second assertion is the one that would have shipped a bug: on Gen 1
-- the draw goes through PartyMenu.drawIcon, which returns nothing and stops
-- when a species has no icon. A pcall around it answers "true" for a cell it
-- never painted, and the grid would have left that cell EMPTY instead of
-- falling back to the battle picture.
do
  local species = ordered[1]
  local screen = factory.new(fakeGame(1, 0))
  T.eq(type(screen.drawMenuIcon), "function",
    "the screen exposes its icon draw, the way it exposes owSprite")

  Data.icons = Data.icons or {}
  Data.icons.bySpecies = Data.icons.bySpecies or {}
  local realEntry = Data.icons.bySpecies[species]

  Data.icons.bySpecies[species] = { image = "mods/gen3_dex/assets/probe.png" }
  T.check(screen.drawMenuIcon(Data.pokemon[species], 0, 0, 28, false),
    "a species the icons registry answers for is drawn as its menu icon")

  Data.icons.bySpecies[species] = nil
  T.check(not screen.drawMenuIcon(Data.pokemon[species], 0, 0, 28, false),
    "and a species with no icon anywhere is a MISS, so the battle picture "
    .. "still gets the cell rather than the cell going blank")

  -- THE RULE THAT KEEPS A VANILLA BOOT UNCHANGED: Gen 1's own icons are
  -- nine shared shapes handed out by dex number (icons.byDex), so accepting
  -- them here would turn 151 cells into nine repeating pictures -- strictly
  -- worse than the halved battle picture, which at least identifies the
  -- Pokemon. Only an icon chosen for THIS species counts, which is what an
  -- icon mod writes and what a vanilla dataset does not have.
  local realByDex = Data.icons.byDex
  local realIcons = Data.icons.icons
  local dex = Data.pokemon[species].dex
  Data.icons.icons = Data.icons.icons or {}
  Data.icons.icons.BALL = Data.icons.icons.BALL or "mods/gen3_dex/assets/probe.png"
  Data.icons.byDex = { [dex] = "BALL" }
  T.check(not screen.drawMenuIcon(Data.pokemon[species], 0, 0, 28, false),
    "the vanilla dex-indexed shape is NOT accepted -- a boot with no icon "
    .. "mod draws exactly what it drew before")
  Data.icons.byDex = realByDex
  Data.icons.icons = realIcons

  Data.icons.bySpecies[species] = realEntry
end

-- ------- runs on Gen 2, and reads Gold's own dex table
--
-- Two separate claims. The gate: a mod is loaded on a Gold boot only if the
-- manifest says so, and a skip is not an error, so the STATE is asserted.
-- The data: Gold keeps the caught half under `caught`
-- (src/core/gen2/Save.lua:216) where Gen 1 says `owned` -- read the Gen 1
-- name on a Gen 2 save and every species reads as seen-but-never-caught,
-- which is a total wrong answer that throws nothing.
do
  local D = T.fixtures.fresh()
  setmetatable(D, { __index = function(_, k)
    local v = Data[k]
    if type(v) == "function" then return v end
    return nil
  end })
  local gen2Run = T.sdk.loadMod(DIR, { data = D, generation = 2 })
  T.eq(gen2Run.mod and gen2Run.mod.state, "loaded",
    "runs on gen 2 (" .. tostring(gen2Run.mod and gen2Run.mod.skipReason) .. ")")
  T.eq(#gen2Run.errors, 0, "and loads on gen 2 with no boot errors")
  gen2Run.release()
end

T.finish("gen3_dex")
