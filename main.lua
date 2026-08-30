-- Gen 3 Dex
--
-- The Pokedex as a GRID of pictures instead of a list of names.
--
-- ------- what this replaces, and what it deliberately does not
--
-- The engine's Pokedex is two screens. Its own comment describes the first
-- honestly: "Minimal Pokedex: dex-ordered list with seen/owned markers" --
-- a ListMenu of 151 text rows. The second is DexEntryMenu, the species
-- page with the sprite, the height/weight and the description.
--
-- This mod replaces the FIRST and leaves the second completely alone.
-- That is not modesty, it is compatibility: ShaneMcGovernIE's Useful Dex
-- adds base stats, BST, evolutions and the movelist as extra pages on
-- DexEntryMenu, and pressing A here opens exactly that screen. The two
-- mods stack instead of fighting, and if Useful Dex is installed its pages
-- are one more press away from this grid.
--
-- ------- why a grid can work here when Gen 1's own icons cannot
--
-- Gen 1 has no per-species icons: the icon table maps a species to one of
-- four shapes. So the grid is drawn from `spriteFront`, the 151 battle
-- pictures already decoded out of the ROM -- the same choice Gen 3 Box
-- made, for the same reason.
--
-- ------- the part that makes it worth looking at
--
-- Every owned species in the grid wears ITS OWN palette. A palette zone is
-- bound to a TILE rectangle, and the engine draws each one scissored
-- through the shade-remap shader, so the count is a loop and not a
-- hardware limit: the Game Boy could show four palettes at once.
--
-- That only works on a cell that is a whole number of tiles, which is why
-- BIG exists: 56 is seven tiles exactly AND the native size of a battle
-- pic, so it draws at scale 1 -- undamaged, for the first time on a list
-- screen. A 28-pixel cell is three and a half tiles and can carry no zone
-- at all, so CLASSIC is greyscale by necessity rather than by choice.

local COLS, ROWS = 5, 4

-- CLASSIC is the Game Boy screen. BIG asks the renderer for 320x288
-- through `uiSize()`, which Game:draw reads from the TOP state every frame
-- and drops back to 160x144 the moment this screen is not on top -- so
-- there is nothing to restore and no way to strand the rest of the game on
-- a canvas it did not ask for.
--
-- Every origin here is a multiple of 8. That is not tidiness: palette
-- zones are addressed in tiles, and flooring a stray offset would not fail
-- -- it would slide each palette a few pixels off its picture, which reads
-- as a rendering fault rather than a layout mistake.
local LAYOUT = {
  classic = { cell = 28, gridX = 8, gridY = 24, w = 160, h = 144 },
  big     = { cell = 56, gridX = 16, gridY = 40, w = 320, h = 288 },
}

local FILTERS = {
  { id = "all",     label = "ALL" },
  { id = "owned",   label = "OWNED" },
  { id = "missing", label = "MISSING" },
  { id = "seen",    label = "SEEN ONLY" },
}

return function(mod)
  local Font = require("src.render.Font")
  local Assets = require("src.render.Assets")
  local Screens = require("src.ui.Screens")
  local Strings = require("src.core.Strings")
  -- The cursor is a glyph CODE, not a character. ">" is not in the game's
  -- charmap, and Font.encode answers a missing character with a space --
  -- quietly, in the draw path -- so an ASCII arrow renders as a blank.
  local Theme = require("src.ui.Theme")

  local SCREEN = "Gen3Dex"

  mod.options:define({
    { key = "grid", label = "GRID", type = "choice", default = "big",
      choices = { { "BIG", "big" }, { "CLASSIC", "classic" } } },
    -- Off leaves the engine's own list exactly where it was. The grid is
    -- still reachable from the START menu, so this is "which one does
    -- POKeDEX open", not "is the mod on".
    { key = "replace", label = "REPLACE DEX", type = "toggle", default = true },
    { key = "menu", label = "START MENU", type = "toggle", default = true },
    -- MENU is what the vanilla list did. See "what A does" below.
    { key = "action", label = "A OPENS", type = "choice", default = "menu",
      choices = { { "MENU", "menu" }, { "DATA", "data" } } },
    -- Off by default: this reaches into Wilds of Kanto
    -- (`overworld_wild_spawns`) through its `mod.find` export, an
    -- experimental cross-mod seam for a prerelease. It only ever does
    -- anything when that mod is installed and enabled, so leaving it off
    -- costs nobody else anything; anyone who has that mod and wants the
    -- CLASSIC grid drawn from its 16x16 overworld sprites instead of the
    -- halved battle pic can switch it on.
    { key = "ow_sprites", label = "OW SPRITES", type = "toggle", default = true },
    -- What is behind the list. WHITE is what shipped through 0.6.0 and is
    -- kept for anyone who wants it back; the rest are drawn here in a few
    -- lines each and cost one screen-sized rectangle plus a scatter.
    --
    -- All of them are PALE, and that is not timidity: every caption, every
    -- number and every entry name on this screen is drawn in black. A dark
    -- backdrop would mean recolouring the type, and type that changes
    -- colour with a background setting is how a screen ends up unreadable
    -- in one combination nobody tested.
    -- FULL SCREEN takes the device instead of a Game Boy screen and spends
    -- the room on MORE ROWS: the same 28-pixel cells, as many rows as fit.
    -- The box mod does the same thing with whole boxes.
    -- No WIP on the label any more: this screen is a list, and a list that
    -- fills the screen is the whole feature. The paging, the cursor and the
    -- chooser all read their shape from the layout rather than from the
    -- Game Boy constants, which is what made it hold at any size.
    -- ON by default from 0.20.0. This screen is a list, and a list that
    -- fills the glass is the whole feature; leaving it off meant most
    -- players never saw the thing the mod is for. OPTIONS puts it back.
    { key = "fullscreen", label = "FULL SCREEN", type = "toggle",
      default = true },
    -- TOUCH is off by default and, while it is off, this screen is exactly
    -- the screen it was: the hook returns early, so the grid keeps whatever
    -- shape GRID was set to and nothing here can move it.
    --
    -- A pinch does NOT invent a zoom of its own. This grid has always had
    -- two cell sizes and a setting that picks between them, so two fingers
    -- drive that same setting -- which is why the change sticks after you
    -- leave, and why "touch off" needs no special case to mean "standard".
    -- ON by default from 0.20.0 as well: the mod is played on phones, and
    -- a d-pad drawn over glass is not the way anybody reaches for a grid.
    -- Turning it off restores the buttons-only screen exactly.
    { key = "touch", label = "TOUCH", type = "toggle", default = true },
    -- BACKDROP is NOT an option row, for the same reason WHICH scene is not
    -- one: it is chosen on the screen, where you can see what you are
    -- choosing. Two ways to set one thing is two sources of truth, and the
    -- one in a settings list always loses -- you set it there, then set a
    -- scene on the screen, and the screen quietly disagrees with the menu
    -- about what you asked for. SELECT, then A on THEME.
    -- WHICH scene is not an option row. It was, for one release, and two
    -- lists of bare names in a settings menu is a worse way to pick a
    -- picture than the chooser on the screen itself -- where the Pokedex
    -- wears what the cursor is on. SELECT, then A on THEME.
    --
    -- The choice lives in the save. Nothing carries the old option rows
    -- forward: a save that has never chosen gets the first scene the box
    -- mod offers, which is what a fresh install should look like anyway.
    -- See "the game's own menu icon" below. Three settings rather than a
    -- switch, because the two reasonable answers disagree and neither of
    -- them is mine to pick for everyone:
    --
    --   UNIQUE  only an icon chosen for a SPECIFIC species -- an icon mod's
    --           art, or a dataset that carries real per-species icons. A
    --           vanilla Gen 1 boot has none, so the grid stays what it was.
    --   ALWAYS  the game's own icon even when that is one of Gen 1's nine
    --           shared shapes. Every bird the same bird, and some players
    --           want the icon look anyway -- the reporter of #1 did, having
    --           seen both.
    --   OFF     the halved battle picture, the way 0.5.0 drew it.
    { key = "menu_icons", label = "MENU ICONS", type = "choice", default = "unique",
      choices = {
        { "UNIQUE", "unique" },
        { "ALWAYS", "always" },
        { "OFF", "off" },
      } },
  })

  local Renderer = require("src.render.Renderer")

  -- ------- which generation is running
  --
  -- Off the live game, never a version allow-list. A Gen 2 save carries
  -- `generation` (src/core/gen2/Save.lua:344); before a save exists there is
  -- nothing on this screen to draw anyway.
  local function isGen2(game)
    local save = game and game.save
    return save ~= nil and save.generation == 2
  end

  -- ------- WHERE A SPECIES' FOUR COLOURS COME FROM, PER GENERATION
  --
  -- Not the same place, and asking the wrong one is why every Pokemon on
  -- Gold came out grey -- caught ones included. `PaletteFX.monPal` reads
  -- the GEN 1 pack (`data.palettes`, src/render/PaletteFX.lua:435-444) and
  -- answers nil on a Gold boot: nil colours, no shader, four DMG greys,
  -- and a file that believes it asked properly.
  --
  -- Gold keeps its own table and its own reader, and its own screens use
  -- them: `Palettes.monColors(data.gen2Palettes, species, shiny)`
  -- (src/ui/gen2/BoxMenu.lua:683-684). The answer has the same shape --
  -- four colours, lightest first -- so only the question changes.
  --
  -- A dex row has no mon to read DVs from, so shiny is false here: this
  -- screen shows the species, not an individual. The box mod, which does
  -- have one, passes it.
  local function monColours(game, species)
    if isGen2(game) then
      local okP, P = pcall(require, "src.world.gen2.Palettes")
      if not (okP and type(P) == "table"
              and type(P.monColors) == "function") then
        return nil
      end
      local ok, colours =
        pcall(P.monColors, game.data and game.data.gen2Palettes,
              species, false)
      return ok and colours or nil
    end
    -- required here rather than read as an upvalue: this helper sits above
    -- the screen closure that holds the file's own PaletteFX
    local okFX, FX = pcall(require, "src.render.PaletteFX")
    if not (okFX and type(FX) == "table") then return nil end
    return FX.monPal(game.data, species)
  end

  -- ------- the summary screen, per generation
  --
  -- Gold's builtins carry a Gen2 prefix and there is no Gen2DexEntryMenu and
  -- no Gen2TownMap: Gold folds both into ONE screen. Gen2PokedexMenu takes
  -- `entrySpecies` and opens straight onto that species' page
  -- (src/ui/gen2/PokedexMenu.lua:230), and its own AREA view is the nest map
  -- (`self.view = "area"`, :358) -- so DATA and AREA are the same push there,
  -- and AREA is one button further in rather than a screen this mod can open
  -- for you.
  local function pushEntry(game, species)
    if isGen2(game) then
      -- `onClose` is not optional, whatever the field name suggests.
      -- Gen2PokedexMenu:close() sets lastDexMode and then calls onClose --
      -- and that is ALL it does (src/ui/gen2/PokedexMenu.lua:339-341). It
      -- never pops itself. Pushed without a callback it stays on the stack
      -- for ever: B off the entry lands the player on Gold's own Pokedex
      -- list with no way out of it, which is a soft lock, not a wrong
      -- screen. The engine's own caller does exactly this
      -- (src/ui/gen2/BoxMenu.lua:309), and Gen2SummaryMenu has the same
      -- shape and the same trap.
      Screens.push(game, "Gen2PokedexMenu", {
        entrySpecies = species,
        onClose = function() game.stack:pop() end,
      })
    else
      Screens.push(game, "DexEntryMenu", species)
    end
  end

  -- What the player asked for.
  -- ------- FULL SCREEN
  --
  -- Same arithmetic as the box mod's: the engine takes a surface between
  -- 160x144 and 640x576 through uiSize() (and on Gold through
  -- drawWidescreen, which this screen already had for BIG). The scale is
  -- chosen by counting what fits rather than by making pixels as large as
  -- possible -- the largest scale gives the fewest rows, which is the
  -- opposite of the point.
  local MIN_W, MIN_H, MAX_W, MAX_H = 160, 144, 640, 576
  -- the size a battle picture is: at 28 it is drawn halved
  local FULL_CELL = 56

  -- ...and 28 when GRID says CLASSIC: same question, same two answers, on
  -- any surface. See fullLayout below.
  -- ------- WHICH GRID, AND WHERE THAT CHOICE LIVES
  --
  -- The SAVE first, the option second -- the same arrangement the backdrop
  -- already uses here, and for the same reason: `mod.options` is
  -- READ-ONLY. It has `define` and `get` and nothing else
  -- (src/mods/Loader.lua:1493-1510), so `mod.options:set` was a call to a
  -- function that does not exist, swallowed by its own pcall. That is why
  -- the pinch appeared to do nothing at all: it was writing into the void
  -- and the grid never heard about it.
  --
  -- `mod.save` is the writable one, so a pinch lands there and is read back
  -- ahead of the option. The option stays what a fresh save starts from.
  local function gridChoice()
    local okS, saved = pcall(function() return mod.save:get("grid") end)
    if okS and (saved == "big" or saved == "classic") then return saved end
    local ok, value = pcall(function() return mod.options:get("grid") end)
    return (ok and value) or "big"
  end

  local function setGridChoice(value)
    if value ~= "big" and value ~= "classic" then return false end
    if gridChoice() == value then return false end
    local ok = pcall(function() mod.save:set("grid", value) end)
    return ok and gridChoice() == value
  end

  local function fullCell()
    return gridChoice() == "classic" and 28 or FULL_CELL
  end

  local function fullOn()
    local ok, value = pcall(function() return mod.options:get("fullscreen") end)
    return ok and value == true
  end

  local function windowSize()
    local ok, w, h = pcall(function() return love.graphics.getDimensions() end)
    if ok and type(w) == "number" and w > 0 and h > 0 then return w, h end
    return MIN_W, MIN_H
  end

  local function fullLayout()
    local ww, wh = windowSize()
    -- The SMALLEST whole scale that still fits inside what the engine will
    -- take: the biggest canvas available, which is the most rows.
    --
    -- Not the largest scale (that maximises pixel size and minimises how
    -- much you see), and not a search for whichever scale fits the most
    -- cells: on a phone love.graphics.getDimensions reports LOGICAL units,
    -- so a 1080-wide screen reports about 405, and that search settled on a
    -- 160-wide canvas -- five columns, a Pokedex that looked zoomed in.
    -- The canvas takes the SHAPE OF THE SCREEN and the screen is filled:
    -- divide the window by whichever cap it busts by most, so the result
    -- has the window's proportions and is as large as the engine accepts.
    -- The scale that follows is fractional, which is why wantsFillScale is
    -- set below -- whole scales left black bands over a third of a phone.
    local k = math.max(ww / MAX_W, wh / MAX_H, 1)
    local w = math.max(MIN_W, math.min(MAX_W, math.floor(ww / k)))
    local h = math.max(MIN_H, math.min(MAX_H, math.floor(wh / k)))
    -- BIG cells: 56 is the size a battle picture actually is, and at 28 it
    -- is drawn halved. The room full screen buys goes on the Pokemon being
    -- whole first, and on showing more of them second.
    --
    -- ...unless GRID says CLASSIC, which is the same setting asking the
    -- same question -- how big is a cell -- and it has an answer on any
    -- surface. Full screen used to override it outright, and a setting that
    -- silently does nothing reads as a broken one; the box mod was reported
    -- for exactly that and this is the same code with the same fix.
    local cell = fullCell()
    -- room for at least three cells across, even on a narrow phone
    w = math.max(w, math.min(MAX_W, 3 * cell + 16))
    w, h = w - w % 8, h - h % 8
    local cols = math.max(3, math.floor((w - 16) / cell))
    local rows = math.max(2, math.floor((h - 24 - 26) / cell))
    return {
      cell = cell, w = w, h = h, full = true, cols = cols, rows = rows,
      gridX = math.floor((w - cols * cell) / 2)
        - (math.floor((w - cols * cell) / 2) % 8),
      gridY = 24,
    }
  end

  local function wanted()
    if fullOn() then return fullLayout() end
    return LAYOUT[gridChoice()] or LAYOUT.big
  end

  -- What actually fits the surface being drawn RIGHT NOW, which is not the
  -- same thing. Game:draw sizes the canvas from the TOP state, so anything
  -- pushed over this screen -- a choice menu, a text box -- puts the canvas
  -- back to 160x144 while this one is still visible underneath. Laying out
  -- for 320x288 on that surface draws three of five columns and runs the
  -- header off the edge, which is exactly what the first BIG dex did.
  --
  -- Gold reaches the same answer through a different door. src/core/Game2.lua
  -- never asks the top state for a `uiSize()` the way src/core/Game.lua:
  -- 471-475 does -- it scales ONE canvas, which is really just the window
  -- itself (Game2.lua:1336, `w, h = G.getDimensions()`), through
  -- Chrome.fitScale. A state gets a bigger surface there by opting into
  -- `drawsWidescreen()` / `drawWidescreen(w, h)` instead -- see
  -- Game2:drawScene (Game2.lua:1450-1600) for how it composites that layer,
  -- and PcMenu.lua:77-78/325, SummaryMenu.lua:230-231/1119 and
  -- PokedexMenu.lua:134-135/1462 for the pattern every one of Gold's own
  -- widescreen screens follows: fill the window, then draw the panel through
  -- an INTEGER fit-scale inside it, never a stretch. `self:drawWidescreen`
  -- below does exactly that, at ITS OWN 320x288 fit rather than the fixed
  -- 160x144 Chrome.SCREEN_W/H those three assume, so this is the same
  -- safety check as the Gen 1 one above, aimed at the window instead of the
  -- virtual canvas Renderer hands out.
  --
  -- The option is not written back either way: a Gen 1 save that chose BIG
  -- is still BIG on Red, and a Gen 2 save that chose it keeps asking for it
  -- on a window too small to grant it -- it just gets CLASSIC instead until
  -- the window grows, the same way Gen 1's own fallback works below.
  local function bigFitsGen2Window()
    local w, h = love.graphics.getDimensions()
    return w >= LAYOUT.big.w and h >= LAYOUT.big.h
  end

  local function layout(game)
    local L = wanted()
    if isGen2(game) then
      -- FULL SCREEN works on Gold, and this line was the only thing saying
      -- otherwise. Gold composes through Game2, which never asks a state for
      -- `uiSize` (there is not one mention of it in src/core/Game2.lua) --
      -- but FULL does not need it: `fullLayout` measures the real window
      -- with love.graphics.getDimensions, so its size is already right on
      -- either generation. `drawsWidescreen` below has answered true for
      -- `L.full` on Gen 2 all along; this was the one place that refused to
      -- hand a full layout back, so the option fell through to CLASSIC and
      -- Gold drew a 160x144 stamp in the middle of a white field while the
      -- toggle sat there reading ON.
      if L.full then return L end
      if L == LAYOUT.big and bigFitsGen2Window() then return L end
      return LAYOUT.classic
    end
    local w, h = Renderer.uiWidth or Renderer.WIDTH, Renderer.uiHeight or Renderer.HEIGHT
    if w >= L.w and h >= L.h then return L end
    return LAYOUT.classic
  end

  local function opt(key, fallback)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok or value == nil then return fallback end
    return value
  end

  -- ------- the dex, as data
  --
  -- Read fresh on every open: a species caught since the last visit has to
  -- show up, and the seen/owned tables are the save's own.

  -- Gold spells the caught half `caught` where Gen 1 says `owned`
  -- (src/core/gen2/Save.lua:216), and the grid asks this table for every
  -- cell it paints -- so on a Gold boot without this the whole dex reads as
  -- "seen but never caught", which is a silent, total wrong answer rather
  -- than an error.
  local function dexOf(game)
    local dex = game.save.pokedex or { seen = {}, owned = {} }
    return {
      seen = dex.seen or {},
      owned = dex.owned or dex.caught or {},
    }
  end

  local function roster(game)
    local constants = game.data.constants or {}
    local byDex = {}
    for _, def in pairs(game.data.pokemon) do
      if def.dex then byDex[def.dex] = def end
    end
    -- `constants` routes to data.gen2Constants on a Gold boot, so the Gen 1
    -- path can read nil here -- and falling back to 151 would cut Johto off
    -- at Mew. The highest dex number actually present is the honest ceiling,
    -- and it also covers a mod that adds species past the cart's own end.
    local highest = 0
    for n in pairs(byDex) do if n > highest then highest = n end end
    local size = math.max(tonumber(constants.dexSize) or 0, highest, 151)
    local out = {}
    for n = 1, size do
      if byDex[n] then out[#out + 1] = { n = n, def = byDex[n] } end
    end
    return out
  end

  local function stateOf(dex, def)
    if dex.owned[def.id] then return "owned" end
    if dex.seen[def.id] then return "seen" end
    return "unknown"
  end

  local function keep(filter, state)
    if filter == "owned" then return state == "owned" end
    if filter == "seen" then return state == "seen" end
    if filter == "missing" then return state ~= "owned" end
    return true
  end

  -- ------- the screen

  -- How faint a SEEN-but-not-caught species is drawn. It was 0.45, which
  -- over a scene reads as "caught, in slightly paler ink" -- and the one
  -- thing this grid has to say at a glance is which half of the dex a cell
  -- belongs to. A third is faint enough to be a ghost and solid enough to
  -- still be recognisably that Pokemon.
  local DIM_SEEN = 0.3

  local function newDex(game)
    local PaletteFX = require("src.render.PaletteFX")

    local self = {
      game = game,
      isOpaque = true,
      index = 0,      -- zero-based, into the filtered list
      filter = 1,
      entries = nil,
    }

    local function rebuild()
      local dex = dexOf(game)
      local all = roster(game)
      local out, seen, owned = {}, 0, 0
      for _, row in ipairs(all) do
        local state = stateOf(dex, row.def)
        if state ~= "unknown" then seen = seen + 1 end
        if state == "owned" then owned = owned + 1 end
        if keep(FILTERS[self.filter].id, state) then
          out[#out + 1] = { n = row.n, def = row.def, state = state }
        end
      end
      self.entries, self.seen, self.owned, self.total = out, seen, owned, #all
      if self.index >= #out then self.index = math.max(0, #out - 1) end
    end

    rebuild()
    self.rebuild = rebuild

    -- COLS and ROWS are the Game Boy grid; a full-screen surface says how
    -- many of each it actually has room for.
    local function gridCols()
      local L = layout(game)
      return L.cols or COLS
    end
    local function gridRows()
      local L = layout(game)
      return L.rows or ROWS
    end
    local function perPage() return gridCols() * gridRows() end

    -- exposed so the suite can assert the full-screen arithmetic -- how
    -- many rows fit in which window -- without drawing anything
    self.layout = function() return layout(game) end
    local function pageStart()
      return math.floor(self.index / perPage()) * perPage()
    end

    local function cellRect(slot)
      local L = layout(game)
      local c, r = slot % gridCols(), math.floor(slot / gridCols())
      return L.gridX + c * L.cell, L.gridY + r * L.cell
    end
    self.cellRect = cellRect

    -- ------- A FINGER, TURNED BACK INTO A CELL
    --
    -- cellRect answers "where is slot n"; this is the same arithmetic read
    -- backwards. It is deliberately the ONLY place that converts a point,
    -- so a layout change cannot leave the touch and the drawing disagreeing
    -- about where a cell is -- they are the same two lines either way.
    --
    -- Coordinates arrive as `gameX/gameY`, already local to the game
    -- viewport (docs/modding.md: "local to the active game viewport"), so
    -- nothing here has to know about window scale or the surround. That
    -- matters more than it sounds: every screen bug in this session that
    -- came from geometry came from a coordinate space nobody had checked.
    local function slotAt(px, py)
      local L = layout(game)
      if not L or not L.cell or L.cell <= 0 then return nil end
      local c = math.floor((px - L.gridX) / L.cell)
      local r = math.floor((py - L.gridY) / L.cell)
      if c < 0 or r < 0 or c >= gridCols() or r >= gridRows() then
        return nil
      end
      return r * gridCols() + c
    end
    self.slotAt = slotAt
    self.gridChoice = gridChoice
    self.setGridChoice = setGridChoice

    -- ------- A WINDOW POINT, BROUGHT ONTO THE SURFACE THE CELLS ARE ON
    --
    -- `ev.x/y` are LOVE window units, and so are `gameX/gameY`: the
    -- viewport only ever SUBTRACTS an origin from them
    -- (src/render/GameViewport.lua:127-133, no scaling anywhere). The cells
    -- are laid out on this screen's own surface, and something scales that
    -- surface into the window -- so feeding window units to slotAt asks
    -- which cell sits at pixel 700 of a 296-wide screen.
    --
    -- Two scalers, two answers. On Gold this screen scales itself in
    -- drawWidescreen and records the numbers it used. On Gen 1 the renderer
    -- does it, and frameRects hands back the UI surface's origin and draw
    -- scale -- uox/uoy and Ux/Uy -- which is this transform read forwards.
    local function toUI(x, y)
      local t = self.touchXform
      if t and t.sx and t.sx > 0 and t.sy and t.sy > 0 then
        return (x - t.ox) / t.sx, (y - t.oy) / t.sy
      end
      local okR, R = pcall(require, "src.render.Renderer")
      if not okR then return x, y end
      local ok, r = pcall(function() return R:frameRects() end)
      if ok and type(r) == "table" and r.Ux and r.Ux > 0
         and r.Uy and r.Uy > 0 then
        return (x - (r.uox or 0)) / r.Ux, (y - (r.uoy or 0)) / r.Uy
      end
      return x, y
    end
    self.toUI = toUI

    -- ------- what a finger is allowed to do
    --
    -- Two verbs, and both go through the SAME code the buttons use: the
    -- cursor is `self.index` either way and opening is `self:open`. A
    -- second, parallel way to navigate is how a screen ends up with a
    -- touch cursor and a button cursor that disagree.
    --
    -- Both answer true when they did something, so the hook knows whether
    -- to consume the event or hand it on.
    self.pageBy = function(dir)
      local per = perPage()
      local n = #self.entries
      if per <= 0 or n <= per then return false end
      local at = math.floor(self.index / per)
      local last = math.floor((n - 1) / per)
      local to = math.max(0, math.min(last, at + dir))
      if to == at then return false end
      self.index = math.max(0, math.min(n - 1, to * per))
      return true
    end

    self.touchTap = function(slot)
      local idx = pageStart() + slot
      if idx < 0 or idx >= #self.entries then return false end
      -- the first tap only moves the cursor; the second, on the cell it is
      -- already on, is A
      if idx ~= self.index then
        self.index = idx
        return true
      end
      local e = self.entries[idx + 1]
      if e and e.state ~= "unknown" then
        self:open(e.def.id)
        return true
      end
      return false
    end

    -- The scale comes from the picture the game hands over, never assumed:
    -- pics arrive through Assets.image, the seam a sprite pack shadows, so
    -- a 112x112 replacement is a thing that happens and a fixed factor
    -- would draw it over its neighbours. Whole steps only -- two-bit art
    -- survives halving and doubling and smears at 0.6.
    local function picScale(img, cell)
      local m = math.max(img:getWidth(), img:getHeight())
      if m <= 0 then return 1 end
      if m <= cell then return math.max(1, math.floor(cell / m)) end
      return 1 / math.ceil(m / cell)
    end
    self.picScale = picScale

    -- ------- the picture, through the seam a sprite pack shadows
    --
    -- This used to load `def.spriteFront` straight off the species record,
    -- which is the ONE path a mod cannot reach. Content registries freeze
    -- after load, so a pack that swaps Red's art for Crystal's -- or lets
    -- the player pick a skin mid-session -- cannot patch that field: the
    -- engine's sanctioned seam is `pokemon.sprite`, raised by
    -- Sprites.path (src/pokemon/Sprites.lua:24-42), and every battle,
    -- summary and Hall of Fame pic in the game goes through it. A dex that
    -- read the record directly was the only screen still showing the
    -- vanilla sprite while the rest of the game showed the pack's.
    --
    -- kind = "dex" tells the hook which screen is asking; trueColor comes
    -- back true when the replacement is full-colour art, which must NOT be
    -- put through the shade remap below.
    --
    -- TWO CANDIDATES, IN ORDER, and the order is the whole lesson of the box
    -- mod's 1.8.1-beta.1 -- which this screen shipped without.
    --
    -- The seam can hand back a path this screen cannot draw. A mod that
    -- renders a Pokemon some other way -- an atlas, a sheet, something that
    -- is not a plain 2D image file -- legitimately answers `pokemon.sprite`
    -- with a path Assets.image loads nothing from, and 0.16.0 read that as
    -- "no picture" and drew an empty cell. With such a mod installed that is
    -- the WHOLE GRID empty: a hundred and fifty blank squares over a scene,
    -- which is what "Pokedex rotto non si vedono sprite" looks like.
    --
    -- So a candidate that does not produce an image is not an answer, and
    -- the species record is tried next. Assets.image can also return nil
    -- WITHOUT throwing, which is why the image is tested and not just the
    -- pcall.
    local picCache = {}
    local function tryImage(path)
      if type(path) ~= "string" or path == "" then return nil end
      local ok, img = pcall(Assets.image, path)
      if ok and img then return img end
      return nil
    end

    -- ------- UNOWN, whose picture is not the species' (box mod issue #7)
    --
    -- The species record's `spriteFront` is letter A's pic; the letter lives
    -- in a MON's DVs. A dex row has no mon, so the cart shows the form the
    -- player MET FIRST -- Pokedex_LoadSelectedMonTiles copies wFirstUnownSeen
    -- into wUnownLetter before GetMonFrontpic -- and the engine's own
    -- PokedexMenu does the same off `save.firstUnownSeen`. This grid drew an
    -- A for a player who has never caught one.
    local function unownPath(def)
      local okU, Unown = pcall(require, "src.core.gen2.Unown")
      if not (okU and type(Unown) == "table") then return nil end
      if def.id ~= Unown.SPECIES then return nil end
      local first = game.save and tonumber(game.save.firstUnownSeen) or 0
      if not first or first == 0 then return nil end
      return Unown.formSprite(game.data and game.data.pokemon, first, false)
    end

    local function picOf(def)
      local hit = picCache[def.id]
      if hit ~= nil then
        if hit == false then return nil end
        return hit.img, hit.trueColor
      end
      -- 1. what the hook says this species should look like
      local ok, hooked, hookedTrue = pcall(function()
        return require("src.pokemon.Sprites").path(
          game.data, def.id, "front", { kind = "dex" })
      end)
      -- a hook that passed the record straight back does not get to
      -- overrule the Unown form the player actually met
      -- The FORM beats the pack (box mod issue #7, second report). 0.17.3
      -- only took the form when the hook had passed the record straight
      -- back, so a sprite pack overruled it -- and a pack answers the ONE
      -- Unown picture it has, because `pokemon.sprite` is keyed by species.
      -- Twenty-six forms wearing one picture reads exactly like the mod
      -- rewriting your Unown, which is how it was reported.
      --
      -- Every engine screen puts the form on top instead: the Gold box
      -- does not even ask the seam, it reads the record and overlays the
      -- form (src/ui/gen2/BoxMenu.lua:668-676). So does this now. A pack
      -- that really wants the forms has the place the engine reads them
      -- from -- the species' own `letters` table -- and formSprite looks
      -- there, so that route still works.
      local form = unownPath(def)
      if form then
        hooked, hookedTrue, ok = form, false, true
      end
      local img = ok and tryImage(hooked) or nil
      local trueColor = img and hookedTrue and true or false
      local path = img and hooked or nil
      -- 2. the species record, which is what the game shipped with
      if not img then
        img = tryImage(def.spriteFront)
        trueColor = false
        path = img and def.spriteFront or nil
      end
      if not img then
        picCache[def.id] = false
        return nil
      end
      -- the path is kept, not just the picture: it is the only thing that
      -- says whether the art that answered has more frames beside it.
      picCache[def.id] = { img = img, trueColor = trueColor, path = path }
      return img, trueColor
    end
    self.picOf = picOf

    -- ------- A CAUGHT POKEMON BREATHES
    --
    -- Sprite packs that animate -- crystal_animated_sprites_with_shiny_visuals
    -- is the one this was written against -- keep one folder per species and
    -- number the frames inside it, `.../front/normal/25/001.png`. The engine's
    -- `pokemon.sprite` hook hands back a single path and has no idea the rest
    -- exist: it always answers frame one. But that first path is the whole
    -- map. The frames beside it are the same name with the next number, so
    -- they are found by ASKING FOR THEM until the answer is no.
    --
    -- Nothing here knows the pack's name, its layout or its timings, so any
    -- pack that numbers its frames animates, and a pack that ships one
    -- picture -- or the ROM, which ships one picture -- simply has no second
    -- frame and stays as still as it did before. That is the fallback: it
    -- costs no branch, because "no siblings" and "no pack" are the same
    -- answer.
    --
    -- The guard is that the run must START at 1. A ROM sprite that happens to
    -- end in digits (`.../025.png`) would otherwise walk into 026 -- which is
    -- a DIFFERENT SPECIES' picture -- and animate a Pikachu into a Raichu.
    local animCache = {}
    local ANIM_MAX = 64      -- a bad match stops here rather than never
    local ANIM_EVERY = 6     -- drawn frames per sprite frame, about 10fps
    local function animOf(def)
      local hit = animCache[def.id]
      if hit ~= nil then return hit or nil end
      local entry = picCache[def.id]
      if not entry or entry == false or not entry.path then
        animCache[def.id] = false
        return nil
      end
      local dir, num, ext = entry.path:match("^(.*[/\\])(%d+)(%.[%a%d]+)$")
      if not dir or tonumber(num) ~= 1 then
        animCache[def.id] = false
        return nil
      end
      local pattern = "%s%0" .. #num .. "d%s"
      local frames = { entry.img }
      for i = 2, ANIM_MAX do
        local nxt = tryImage(pattern:format(dir, i, ext))
        if not nxt then break end
        frames[#frames + 1] = nxt
      end
      if #frames < 2 then
        animCache[def.id] = false
        return nil
      end
      animCache[def.id] = frames
      return frames
    end
    self.animOf = animOf

    -- ------- and the colours travel with the PICTURE, not with a rectangle
    --
    -- "lo sfondo bianco dei catturati??? orribile" -- a white card under
    -- every caught Pokemon and under no other. The picture is innocent: the
    -- extractor flood-fills the border white to alpha 0 when it rips a front
    -- pic (ImageWriter.matteColor0, src/import/ImageWriter.lua:108-133), so
    -- what is behind a Pokemon is nothing at all. Which is why a SEEN
    -- species showed no card and a caught one did.
    --
    -- The card was the palette zone. A zone is a RECTANGLE: the shader maps
    -- by the red channel, a pale sky is r > 0.83, and shade 0 of a species
    -- palette is white -- so the scene inside an owned cell was repainted
    -- white, cell-shaped, while its neighbours kept the picture. One zone
    -- per owned cell, and the grid ended up wearing a chequerboard.
    --
    -- So the zones go (see sgbPalettes) and the same remap is applied to the
    -- PICTURE instead, which is a shape rather than a rectangle:
    -- PaletteFX.shader() with the species' four colours, exactly what the
    -- zone pass would have sent, and it keeps the alpha it is given -- the
    -- keyed variant next to it does not, and would punch holes through
    -- every white belly and every eye highlight.
    --
    -- No shader (headless, or a driver that refuses one) draws the picture
    -- plainly: it comes out in DMG greys, which is what a species with no
    -- palette gets anyway, and nothing crashes.
    local function paintPic(img, x, y, k, colors, alpha)
      local g = love.graphics
      local sh = nil
      if colors and type(PaletteFX.shader) == "function" then
        local ok, made = pcall(PaletteFX.shader)
        if ok and made then
          local sent = pcall(PaletteFX.sendColors, made, colors)
          if sent and pcall(g.setShader, made) then sh = made end
        end
      end
      g.setColor(1, 1, 1, alpha or 1)
      pcall(g.draw, img, x, y, 0, k, k)
      if sh then pcall(g.setShader) end
      g.setColor(1, 1, 1, 1)
    end

    -- ------- Wilds of Kanto's overworld sprites, CLASSIC only
    --
    -- `overworld_wild_spawns` renders a per-species 16x16 overworld sprite
    -- that fits a 28-pixel CLASSIC cell whole, instead of the halved 56x56
    -- battle picture this screen falls back to everywhere else. See
    -- SEAM.md for what is verified here and what is not: reached only
    -- through the engine's own `mod.find`, never a manifest dependency,
    -- and every call into the other mod's code is `pcall`ed -- it is
    -- someone else's release cycle, and a throw in a draw loop takes the
    -- frame down.
    --
    -- `self.owHandle` rather than a bare local so a test can substitute it
    -- without a second mod on the loader.
    local OW_ID = "overworld_wild_spawns"
    local OW_BLACK = "black" -- SpriteProviders.ID.BLACK: a silhouette, not a hit

    function self.owHandle()
      local ok, handle = pcall(mod.find, OW_ID)
      if not ok then return nil end
      return handle
    end

    -- speciesId -> a table shaped for picScale (getWidth/getHeight) plus
    -- the image and quad to draw, or `false` for a species already tried
    -- and missed. Kept for the life of THIS screen: resolve() walks a
    -- provider chain, and calling it twenty times a frame is not free.
    local owCache = {}

    -- ------- why a cell fell back, said once
    --
    -- Reported (#1): the CLASSIC grid draws battle pictures where it used to
    -- draw overworld icons. Every step of the ask below is pcall'ed and
    -- every miss returns nil, which is right for a draw loop and useless for
    -- a bug report: the screen looked exactly the same whether that mod was
    -- absent, switched off, on a version without the seam, or answering with
    -- a path this machine cannot load. It had no way to say which.
    --
    -- So each distinct reason is logged ONCE per session -- not per species,
    -- not per frame; twenty cells redrawing sixty times a second must not
    -- become a log file. The next report carries the answer with it.
    local owSaid = {}
    local function owMiss(reason, detail)
      if owSaid[reason] then return nil end
      owSaid[reason] = true
      mod.log:info("OW SPRITES: %s%s", reason,
        detail and (" (" .. tostring(detail) .. ")") or "")
      return nil
    end

    local function owSprite(def)
      local cached = owCache[def.id]
      if cached ~= nil then return cached or nil end
      owCache[def.id] = false

      local handle = self.owHandle()
      if not handle then
        return owMiss("Wilds of Kanto is not there -- absent, switched off, "
          .. "or it failed to load")
      end
      if not handle.exports then
        return owMiss("Wilds of Kanto is loaded but exports nothing")
      end
      local ex = handle.exports

      -- ------- two ways to ask, in the order they are known to work
      --
      -- That mod already draws these sprites in the vanilla party menu, and
      -- it does it by patching PartyMenu.drawIcon and resolving through its
      -- follower sprite service (lib/follower/sprite_service.lua:222,384),
      -- NOT through spriteProviders. So the party-menu resolver is the code
      -- path with a screenshot behind it, and asking anything else first
      -- would be preferring the tidier seam to the working one.
      --
      -- It wants a Pokemon rather than a species id. A dex has no Pokemon,
      -- only a species, so it is handed the smallest honest stand-in: a
      -- table with the species on it. Form and shininess are absent because
      -- a dex entry has neither -- it is a species, not an individual.
      local function viaPartyIcon()
        local service = ex.follower and ex.follower.spriteService
        if not service or type(service.resolvePartyIconDef) ~= "function" then
          return nil
        end
        local okDef, sd = pcall(function()
          return service:resolvePartyIconDef({ species = def.id }, game)
        end)
        if not okDef then
          return owMiss("its party-icon resolver threw", sd)
        end
        if type(sd) ~= "table" or not sd.image then
          return owMiss("its party-icon resolver had no art for a species")
        end
        -- Its own "I could not find this one" placeholder, which it marks
        -- rather than hides. A missing-sprite box in a dex grid is worse
        -- than the halved battle picture, which at least tells you which
        -- Pokemon the cell is -- the same call the black silhouette gets
        -- below.
        if sd.fallback == true then
          return owMiss("it answered with its own missing-sprite placeholder "
            .. "-- check the SPRITE STYLE setting and that the art pack that "
            .. "style needs is installed")
        end
        return sd, service
      end

      -- spriteProviders second: the documented general seam, kept because
      -- it answers for the wild/overworld styles the party resolver has no
      -- opinion on, and because it is what survives if that mod ever
      -- retires its party-menu patch.
      --
      -- style nil takes the player's own Sprite Style setting -- whatever
      -- they picked for their followers is what they should see here.
      local function viaProviders()
        local providers = ex.spriteProviders
        if not providers or type(providers.resolve) ~= "function" then
          return nil
        end
        local ok, result = pcall(function()
          return providers:resolve(nil, def.id, nil, game)
        end)
        if not ok or type(result) ~= "table" then
          return owMiss("its provider chain threw or answered with nothing",
            ok and type(result) or result)
        end
        -- resolve() always returns a table and falls back to a black
        -- silhouette when everything else fails. A silhouette in a dex grid
        -- is worse than the halved battle picture, which at least shows you
        -- which Pokemon it is -- treat it as a miss, not a hit.
        if result.error or result.providerId == OW_BLACK then
          return owMiss("its provider chain has no art for a species",
            result.error or result.providerId)
        end
        local sd = result.def
        if not sd or not sd.image then
          return owMiss("its provider chain answered without a picture")
        end
        return sd
      end

      local sdef, service = viaPartyIcon()
      if not sdef then sdef = viaProviders() end
      if not sdef then return nil end

      -- the service's own loader when it answered, because it caches and
      -- knows about that mod's true-colour handling; Assets.image otherwise
      local img
      if service and type(service.getPartyIconImage) == "function" then
        local okOwn, own = pcall(function()
          return service:getPartyIconImage(sdef.image)
        end)
        if okOwn then img = own end
      end
      if not img then
        local okImg, loaded = pcall(Assets.image, sdef.image)
        if okImg then img = loaded end
      end
      if not img then
        -- The one that cannot be guessed from the outside: the seam answered
        -- with a path, and nothing on this machine could open it. The path
        -- is in the line because it names the art pack that is missing.
        return owMiss("the art it named could not be loaded", sdef.image)
      end

      local n = sdef.frames
      if type(n) ~= "number" or n < 1 then n = 1 end
      local okDim, iw, ih = pcall(function()
        return img:getWidth(), img:getHeight()
      end)
      if not okDim or not iw or not ih or iw <= 0 or ih <= 0 then
        return nil
      end
      -- frames stack vertically, frame 0 -- the idle/down frame -- on top.
      -- Never hardcode 16x96: other providers answer other sizes, and the
      -- mod has a "true size" feature that changes them.
      local fh = ih / n
      local okQuad, quad = pcall(love.graphics.newQuad, 0, 0, iw, fh, iw, ih)
      if not okQuad or not quad then return nil end

      local sprite = {
        image = img,
        quad = quad,
        getWidth = function() return iw end,
        getHeight = function() return fh end,
      }
      owCache[def.id] = sprite
      return sprite
    end
    self.owSprite = owSprite

    -- ------- the game's own menu icon
    --
    -- #1 was reported as "the CLASSIC grid stopped showing overworld icons",
    -- and the answer turned out to be that the reporter had no follower mod
    -- installed at all: he expected the MINI ICONS the party list draws, and
    -- reasonably so -- a 16x16 icon fits a 28-pixel cell whole, which is the
    -- entire argument the overworld sprites were added for. He was also
    -- running an icon mod of his own (menyas/unique-menu-icons).
    --
    -- That mod is the reason this needs no seam of its own. It does not
    -- patch a menu: it writes into the ENGINE's `icons` registry
    -- (mod.content.icons:override / :register), which is where the party
    -- list already reads from. So drawing the game's own icon here picks up
    -- its art, and every other icon mod's, for free -- and a player with no
    -- icon mod gets the vanilla mini icon, which is what the cell was
    -- missing in the first place.
    --
    -- Gen 1 goes through PartyMenu.drawIcon rather than a lookup of this
    -- screen's own, because that function is more than a path: it resolves
    -- icons.bySpecies, then the species record's `icon`, then the dex-indexed
    -- default, raises the `pokemon.icon` hook through Sprites.iconPath, and
    -- bakes OBP0 for the built-in 2bpp art (which drawn raw would not look
    -- like the game's icon at all). Reimplementing that here would be
    -- reimplementing four rules and getting one of them wrong.
    --
    -- Gold has no such free function -- its icons are an instance method on
    -- a live party screen -- so that boot walks the same DATA path by hand:
    -- gen2Icons.species names a sheet, gen2Icons.icons carries it, and the
    -- top 16x16 frame is the still one. The `pokemon.icon` hook is raised
    -- there too, through the same Sprites.iconPath, so one icon mod repaints
    -- both games exactly as it does in the party list.
    local iconImages = {}

    local function gen2Icon(def)
      local icons = game.data and game.data.gen2Icons
      local sheetId = icons and icons.species and icons.species[def.id]
      local sheet = sheetId and icons.icons and icons.icons[sheetId]
      local path = sheet and sheet.image
      local okPath, hooked = pcall(function()
        return require("src.pokemon.Sprites").iconPath(
          game.data, { species = def.id }, path, { name = sheetId })
      end)
      if okPath and hooked then path = hooked end
      if type(path) ~= "string" or path == "" then return nil end

      local cached = iconImages[path]
      if cached == nil then
        local ok, img = pcall(Assets.image, path)
        cached = (ok and img) or false
        iconImages[path] = cached
      end
      if not cached then return nil end

      local okDim, iw, ih = pcall(function()
        return cached:getWidth(), cached:getHeight()
      end)
      if not okDim or not iw or not ih or iw <= 0 or ih <= 0 then return nil end
      -- a 16x32 strip is two frames; the top one is the mon standing still
      local fh = ih >= iw * 2 and ih / 2 or ih
      local okQuad, quad = pcall(love.graphics.newQuad, 0, 0, iw, fh, iw, ih)
      if not okQuad or not quad then return nil end
      return { image = cached, quad = quad,
               getWidth = function() return iw end,
               getHeight = function() return fh end }
    end

    -- PER-SPECIES only, and that restriction is the whole design.
    --
    -- PartyMenu.drawIcon reads three sources in order (src/ui/PartyMenu.lua:
    -- 215-227): the per-species override, the species record's own `icon`,
    -- and then `icons.byDex` -- the vanilla default, which on Gen 1 is NINE
    -- SHARED SHAPES for a hundred and fifty-one species. BALL, BIRD, BUG,
    -- GRASS and the rest: every bird is the same bird. That is fine in a
    -- party list of six, where the name is written next to it, and it is
    -- useless in a dex grid, whose entire job is telling twenty cells apart.
    -- A grid of nine repeating shapes would be strictly worse than the
    -- halved battle picture, which at least shows you which Pokemon it is.
    --
    -- So the dex-indexed default is deliberately NOT accepted here: only an
    -- icon somebody chose for THIS species -- which is what an icon mod
    -- writes (menyas/unique-menu-icons overrides icons.bySpecies per
    -- species), and what a dataset carrying real per-species art has. With
    -- no such mod installed this answers nil for every species and the grid
    -- draws exactly what it drew in 0.5.0.
    --
    -- The hook gets the last word through Sprites.iconPath, including the
    -- right to suppress an icon entirely -- but it is only ever raised for a
    -- species that already has a per-species path, so an unhooked vanilla
    -- boot cannot be talked into the shared shapes by accident.
    local function gen1IconPath(def, mode)
      local icons = game.data and game.data.icons
      if not icons then return nil end
      local entry = (icons.bySpecies and icons.bySpecies[def.id]) or def.icon
      local name, path
      if type(entry) == "string" then
        name = entry
        path = icons.icons and icons.icons[entry]
      elseif type(entry) == "table" then
        path = entry.image
      end
      -- ALWAYS is the one setting that accepts the dex-indexed shared shape
      if not path and mode == "always" then
        name = def.dex and icons.byDex and icons.byDex[def.dex]
        path = name and icons.icons and icons.icons[name]
      end
      if not path then return nil end
      local ok, hooked = pcall(function()
        return require("src.pokemon.Sprites").iconPath(
          game.data, { species = def.id }, path, { name = name })
      end)
      if not ok then return path end
      return hooked
    end

    -- true when it drew, false when this dataset has no icon for the species
    -- and the battle picture should take the cell instead
    -- UNIQUE / ALWAYS / OFF, tolerant of the boolean 0.6.0-beta.1 and
    -- beta.2 stored under this key when it was a toggle: `false` was OFF and
    -- `true` was "draw one", which is what UNIQUE means now.
    local function iconMode()
      local value = opt("menu_icons", "unique")
      if value == false or value == "off" then return "off" end
      if value == "always" then return "always" end
      return "unique"
    end
    self.iconMode = iconMode

    local function drawMenuIcon(def, x, y, cell, dim, mode)
      mode = mode or iconMode()
      if mode == "off" then return false end
      if isGen2(game) then
        local sprite = gen2Icon(def)
        if not sprite then return false end
        local k = picScale(sprite, cell)
        local w, h = sprite:getWidth() * k, sprite:getHeight() * k
        if dim then love.graphics.setColor(1, 1, 1, DIM_SEEN) end
        local ok = pcall(love.graphics.draw, sprite.image, sprite.quad,
          x + (cell - w) / 2, y + (cell - h) / 2, 0, k, k)
        love.graphics.setColor(1, 1, 1, 1)
        return ok
      end

      local okMenu, PartyMenu = pcall(require, "src.ui.PartyMenu")
      if not okMenu or type(PartyMenu) ~= "table"
         or type(PartyMenu.drawIcon) ~= "function" then
        return false
      end

      -- PartyMenu.drawIcon returns nothing and simply STOPS when the species
      -- has no icon, so a pcall around it answers "true" for a cell it never
      -- painted -- which would leave that cell empty rather than falling back
      -- to the battle picture. So the path is resolved here first, by the
      -- same three rules in the same order, and a species with no icon is
      -- reported as a miss before anything is drawn.
      if not gen1IconPath(def, mode) then return false end
      -- selected = false is what keeps this from touching mon.hp / mon.stats:
      -- the bobbing frame is chosen from the HP bar, and a dex entry is a
      -- species with no HP to read. counter = 0 for the same reason.
      if dim then love.graphics.setColor(1, 1, 1, DIM_SEEN) end
      local drew = pcall(PartyMenu.drawIcon, game, { species = def.id },
        x + (cell - 16) / 2, y + (cell - 16) / 2, false, 0)
      love.graphics.setColor(1, 1, 1, 1)
      return drew
    end
    self.drawMenuIcon = drawMenuIcon

    -- The PREFERENCE, not the current surface. Game:draw asks this to
    -- decide how big the canvas should be, so answering with the size it
    -- happens to be right now would mean it could never grow. Gold never
    -- asks this at all (Game2.lua has no per-state `uiSize()`; BIG reaches
    -- it through `drawWidescreen` below instead), but there is no reason to
    -- special-case that generation here any more -- the honest answer is
    -- `wanted()`, same as it always was for Gen 1.
    function self:uiSize()
      local L = wanted()
      return L.w, L.h
    end

    -- ------- Gold's widescreen contract
    --
    -- `wantsFillScale` is a Gen 1 field: Game.fillScaleInStack
    -- (src/core/Game.lua:337-345) walks the stack for it and sets
    -- Renderer.uiFill (src/render/Renderer.lua:716-722), which switches the
    -- UI from a fitted letterbox to a STRETCHED fill. Game2 never reads it
    -- -- Gold's own widescreen users (PcMenu.lua:77, SummaryMenu.lua:230,
    -- PokedexMenu.lua:134, and every other file in src/ui/gen2 that declares
    -- it) define it unconditionally only because it costs them nothing on
    -- the generation that DOES read it. This screen cannot do that: Gen 1
    -- BIG already reaches its 320x288 canvas through `uiSize()` above at a
    -- fitted integer scale, and answering `wantsFillScale() == true`
    -- unconditionally would flip that to a stretch -- a real change to the
    -- one generation this mod is not supposed to touch. Gating it on
    -- `isGen2` keeps Gen 1 answering exactly what an absent method already
    -- answered (false, by omission) while still being honest for Gen 2,
    -- where it is read by nothing today but costs nothing to answer right.
    function self:wantsFillScale()
      return isGen2(game) and layout(game) == LAYOUT.big
    end

    -- Read by Game2:drawScene (src/core/Game2.lua:1450-1600) to decide
    -- whether this screen paints its own surround (`drawWidescreen` below)
    -- or falls through to the plain branch: a white rect, the
    -- `render.letterbox` hook, and `self.stack:draw()` at Chrome.fitScale --
    -- which is the ENTIRE draw path this screen used on Gen 2 before this
    -- existed, and still uses whenever this answers false. CLASSIC always
    -- answers false here, on both generations, so it never takes a step
    -- this file did not already take.
    function self:drawsWidescreen()
      local L = layout(game)
      return isGen2(game) and (L == LAYOUT.big or L.full == true)
    end

    -- Only ever called for Gen 2 BIG (see `drawsWidescreen` above), and only
    -- while this screen is the state Game2:drawScene calls it on -- which,
    -- per "Drawn by THIS screen rather than pushed as one of its own" below,
    -- is always the TOP of the stack while this grid is showing, so `winW,
    -- winH` are always the real window this frame, never a stale size left
    -- over from something else. Fits its OWN 320x288 layout to that window
    -- at an integer scale, centers it, and reuses `self:draw()` verbatim for
    -- the content -- the same "fill, then fit the panel inside it" shape
    -- PcMenu.lua:325, SummaryMenu.lua:1119 and PokedexMenu.lua:1462 use, just
    -- fit to this screen's own canvas instead of the fixed 160x144 one those
    -- three assume. `self:draw()`'s own `love.graphics.clear(1, 1, 1, 1)`
    -- paints the white surround outside the fitted panel, the same job the
    -- other three do by hand with a `rectangle("fill", ...)` first -- clear()
    -- ignores the transform below and always wipes the whole active canvas,
    -- so it reaches past the translate/scale and covers the letterbox too.
    function self:drawWidescreen(winW, winH)
      local L = layout(game)
      -- FULL fills; BIG stays on whole pixels. Flooring the ratio suits
      -- BIG, a fixed 320x288 that wants crisp whole pixels, and ruins FULL,
      -- whose size is already chosen to suit the window: a ratio of 1.37
      -- floors to 1, so Gold drew the screen at life size in the middle of
      -- the glass with a white band down each side while Gen 1 -- same
      -- option, same layout, but fitted by the renderer through uiSize() --
      -- filled it. The box mod carries the identical fix.
      local fit = math.min(winW / L.w, winH / L.h)
      local scale = (L.full and fit) or math.max(1, math.floor(fit))
      local ox = math.floor((winW - L.w * scale) / 2)
      local oy = math.floor((winH - L.h * scale) / 2)
      -- recorded for the touch layer: on Gold this screen scales ITSELF,
      -- so this is the only place that knows how a window point maps back
      -- onto the surface the cells were laid out on
      self.touchXform = { ox = ox, oy = oy, sx = scale, sy = scale }
      love.graphics.push()
      love.graphics.translate(ox, oy)
      love.graphics.scale(scale, scale)
      self:draw()
      love.graphics.pop()
    end

    -- ------- the colours
    --
    -- Zone 1 is the BASE and covers the whole surface. Without it the only
    -- remapped pixels are the cells, everything else composites black, and
    -- the header and footer -- drawn in black -- vanish into it.
    -- PaletteFX.whole() cannot serve: it is hardcoded to the 160x144 tile
    -- grid and would cover a quarter of a BIG canvas.
    --
    -- Then one zone per OWNED entry on this page. Seen-only and unknown
    -- cells stay on the base palette on purpose: a species you have met
    -- but not caught should not be advertising its colours.
    function self:sgbPalettes()
      -- Gold colours itself: it is a CGB game, and the only zone Game2 ever
      -- asks for on its own is the whole-screen present-palette one
      -- (src/core/Game2.lua:1342-1356, `render.zones`), never a per-state
      -- `sgbPalettes()` the way Gen 1's Game.lua:505 reads it -- so nothing
      -- calls this method on a Gen 2 boot today. BIG no longer forces
      -- CLASSIC on that generation, though, so this stops leaning on that
      -- happenstance and says so directly: BIG on Gold is the enlarged grid
      -- with NO per-species palette zones, full stop. Porting the zone half
      -- would mean addressing tiles inside a canvas Gold's own compositor
      -- never scissors that way (see `blitZones`, Game2.lua:1246-1280, which
      -- maps every zone rect through a fixed 160x144 space regardless of
      -- what actually drew) -- a different feature, not a missing line here.
      if isGen2(game) then return nil end
      local L = layout(game)
      if L.cell % 8 ~= 0 or L.gridX % 8 ~= 0 or L.gridY % 8 ~= 0 then
        return nil
      end
      -- A scene is painted in its OWN RGB -- this mod's six are, and a
      -- borrowed one arrives already coloured -- so running the finished
      -- picture through the shade-remap flattens it onto four greys while
      -- the Pokemon on top keep their species colours. That is precisely
      -- what gen3_box shipped in 1.10.1 and fixed in 1.10.2, and this
      -- screen inherited the same mistake by not thinking about it.
      --
      -- The base zone opts OUT when a scene is drawn: colors == false is the
      -- engine's trueColor escape (PaletteFX.trueColorZone), and it still
      -- has to be first and still has to cover everything, because the
      -- per-species cells below are drawn over it in order.
      -- not self.sceneVeil: that is only set once a frame has been drawn,
      -- and this is asked before the first one
      local onScene = self.sceneIsDrawn()
      local bare = onScene and type(PaletteFX.trueColorZone) == "function"
        and PaletteFX.trueColorZone(0, 0, L.w / 8 - 1, L.h / 8 - 1)
      local zones = {
        bare or PaletteFX.zone(PaletteFX.GRAYS, 0, 0, L.w / 8 - 1, L.h / 8 - 1),
      }
      -- On a SCENE there are no per-cell zones at all, and that is the fix
      -- for the white card rather than a saving.
      --
      -- A zone is a RECTANGLE. It recolours everything inside the cell, so
      -- with the picture's background keyed away it would map the scene
      -- showing through -- pale sky, pale grass, anything light -- onto the
      -- species' lightest shade, which is white. The card would come back,
      -- cell-sized instead of picture-sized. So when a scene is drawn the
      -- colours travel with the PICTURE (paintPic's keyed shader) and this
      -- list stays one zone long; on the plain white background the zones
      -- are still how a Pokemon gets its colours, exactly as before.
      if not onScene then
        -- A ceiling, the same one the box mod keeps (its `MAX_ZONES = 40`).
        -- Every zone costs the remap pass another blit of the whole surface,
        -- and this list had none: a full-screen grid of owned species emits
        -- one per cell, so a finished Pokedex paid eighty blits a frame to
        -- colour eighty pictures. Past the ceiling the rest keep the base
        -- palette, which is what they wore before any of this existed.
        local MAX_ZONES = 40
        local tiles = L.cell / 8
        local start = pageStart()
        for slot = 0, perPage() - 1 do
          if #zones >= MAX_ZONES then break end
          local e = self.entries[start + slot + 1]
          if e and e.state == "owned" then
            local colors = PaletteFX.monPal(game.data, e.def.id)
            if colors then
              local x, y = cellRect(slot)
              local tx, ty = x / 8, y / 8
              zones[#zones + 1] =
                PaletteFX.zone(colors, tx, ty, tx + tiles - 1, ty + tiles - 1)
            end
          end
        end
      end
      return zones
    end

    -- Drawn by THIS screen rather than pushed as one of its own. A pushed
    -- menu becomes the top state, and Game:draw sizes the canvas from the
    -- top state -- so a menu with no uiSize() of its own silently shrinks
    -- the surface back to 160x144 while this grid is still visible
    -- underneath it, laid out for 320x288. Three columns of five, and the
    -- header off the edge.
    --
    -- Keeping it inline means nothing is ever on top while the grid shows,
    -- so the surface never changes under it.
    local CHOICES = {
      { label = "DATA", act = function(species)
          pushEntry(game, species)
        end },
      -- like the original, a cry does not close the menu
      { label = "CRY", keepOpen = true, act = function(species)
          require("src.core.Sound").playCry(game.data, species)
        end },
      { label = "AREA", act = function(species)
          -- Gold has no TownMap screen of its own: its nest map is the AREA
          -- view inside the dex entry, so this lands on the entry and the
          -- player is one button from the map instead of on it.
          if isGen2(game) then
            pushEntry(game, species)
          else
            Screens.push(game, "TownMap", { nestSpecies = species })
          end
        end },
    }
    self.choices = CHOICES

    -- ------- input

    function self:update()
      -- ------- THE CLOCK TICKS ON THE LOGIC STEP, NOT ON THE FRAME
      --
      -- This lived in draw(), which is once per DRAWN frame: the scenes
      -- drifted -- and, since 0.18.0, the caught Pokemon animated -- at
      -- whatever rate the device happens to redraw at. A 120Hz phone ran
      -- everything at twice the speed of a 60Hz one, which is not a
      -- setting anybody chose. update() is the engine's fixed logic step,
      -- which is where the box mod has always counted its own drift
      -- (gen3_box main.lua, `paperTick` in its update), so the two mods
      -- now move at the same speed as each other and as the game.
      --
      -- Before every early return below, so the scene keeps breathing
      -- while a panel is open rather than freezing under it -- again the
      -- same order the box uses.
      self.sceneTick = (self.sceneTick or 0) + 1
      local input = game.input
      local n = #self.entries
      local per = perPage()

      -- WHAT'S NEW owns every key while it is open: a popup you can walk
      -- out from behind is a popup nobody reads
      if self.news then
        self.updateNews()
        return
      end

      -- the choice takes the input while it is up
      if self.choice then
        local c = self.choice
        if input:wasPressed("b") then
          self.choice = nil
        elseif input:wasPressed("up") then
          c.index = (c.index - 2) % #CHOICES + 1
        elseif input:wasPressed("down") then
          c.index = c.index % #CHOICES + 1
        elseif input:wasPressed("a") then
          local pick = CHOICES[c.index]
          if not pick.keepOpen then self.choice = nil end
          pick.act(c.species)
        end
        return
      end

      -- ------- choosing a wallpaper the way the box does
      --
      -- Up and down change the scene, left and right change the hand, and
      -- the screen behind is what you are choosing -- no panel, no preview
      -- window, the Pokedex itself wears it while you move. A keeps it, B
      -- puts back what was there. It is the box's chooser, key for key,
      -- because a player who has both mods has already learnt it once.
      if self.pick then
        local pick = self.pick
        -- self.handsFor, not the local: like viewRows, these are built
        -- further down the constructor than update() is
        local function hands() return self.handsFor(pick.scenes[pick.at]) end
        if input:wasPressed("up") then
          pick.at = (pick.at - 2) % #pick.scenes + 1
          pick.hand = math.min(pick.hand, math.max(1, #hands()))
          pick.moved = true
        elseif input:wasPressed("down") then
          pick.at = pick.at % #pick.scenes + 1
          pick.hand = math.min(pick.hand, math.max(1, #hands()))
          pick.moved = true
        elseif input:wasPressed("left") then
          local n = math.max(1, #hands())
          pick.hand = (pick.hand - 2) % n + 1
          pick.moved = true
        elseif input:wasPressed("right") then
          local n = math.max(1, #hands())
          pick.hand = pick.hand % n + 1
          pick.moved = true
        elseif input:wasPressed("a") then
          mod.save:set("scene", pick.scenes[pick.at])
          mod.save:set("hand", pick.hand)
          self.pick = nil
        elseif input:wasPressed("b") then
          mod.save:set("scene", pick.wasScene)
          mod.save:set("hand", pick.wasHand)
          self.pick = nil
        end
        return
      end

      if self.view then
        -- self.viewRows rather than the local: the rows are built further
        -- down the constructor, and update() runs long after all of it
        local rows = self.viewRows()
        local row = rows[self.view.row]
        if input:wasPressed("b") or input:wasPressed("select") then
          self.view = nil
        elseif input:wasPressed("up") then
          self.view.row = (self.view.row - 2) % #rows + 1
        elseif input:wasPressed("down") then
          self.view.row = self.view.row % #rows + 1
        elseif input:wasPressed("a") then
          if row.open then row.open() else row.step(1) end
        elseif input:wasPressed("left") then
          if row.step then row.step(-1) end
        elseif input:wasPressed("right") then
          if row.step then row.step(1) end
        end
        return
      end

      if input:wasPressed("b") then
        game.stack:pop()
        return
      end

      -- ------- the VIEW panel
      --
      -- Three things belong to the screen rather than to a species: which
      -- entries are listed, which scene is behind them, and whose hand drew
      -- it. SELECT used to cycle the filter silently -- four states, no
      -- label, and you found out by watching the list change. It opens this
      -- instead, where each row says what it is and the wallpaper behind
      -- changes AS YOU MOVE, which is the only way to choose one.
      if input:wasPressed("select") then
        self.view = { row = 1 }
        return
      end

      if n == 0 then return end

      if input:wasPressed("left") then
        self.index = (self.index - 1) % n
      elseif input:wasPressed("right") then
        self.index = (self.index + 1) % n
      elseif input:wasPressed("up") then
        self.index = (self.index - gridCols()) % n
      elseif input:wasPressed("down") then
        self.index = (self.index + gridCols()) % n
      elseif input:wasPressed("start") then
        -- page jump, the way the vanilla list uses left/right
        self.index = (self.index + per) % n
      elseif input:wasPressed("a") then
        local e = self.entries[self.index + 1]
        -- An unknown species has nothing to show, exactly as the vanilla
        -- list refuses it.
        if e and e.state ~= "unknown" then self:open(e.def.id) end
      end
    end

    -- ------- what A does
    --
    -- The vanilla list did not open the entry page directly: it offered
    -- DATA / CRY / AREA (engine/menus/pokedex.asm PokedexMenuItemsText).
    -- The first version of this grid went straight to DATA and quietly
    -- dropped the other two -- CRY, and the one worth having:
    --
    --   AREA is `TownMap` with `nestSpecies`, the engine's own
    --   LoadTownMap_Nest. It blinks a nest icon on every map whose wild
    --   slots hold the species, computed from data.encounters. It is the
    --   Gen 3 "where does this live" screen, and it has been in the engine
    --   the whole time.
    --
    -- DATA still goes to the engine's own DexEntryMenu rather than a copy,
    -- so a mod that adds pages there keeps working.
    function self:open(species)
      if opt("action", "menu") == "data" then
        pushEntry(game, species)
        return
      end
      self.choice = { species = species, index = 1 }
    end

    -- ------- drawing
    --
    -- Every coordinate below comes from the layout. A number written for a
    -- 144-tall screen is the bottom of one canvas and the middle of the
    -- other, and text drawn there prints across the grid.

    local TEXT_X = 4
    local function textMax() return layout(game).w - TEXT_X * 2 end

    local function fit(text)
      text = tostring(text or "")
      while #text > 1 and Font.width(text) > textMax() do
        text = text:sub(1, #text - 1)
      end
      return text
    end

    local function cursor(x, y, cell)
      -- Corner brackets, not an outline: a one-pixel box on a 56-pixel
      -- cell is a hairline, and it competes with the cell's own border one
      -- pixel away. These read at any size and leave the middle clear.
      local t = math.max(1, math.floor(cell / 14))
      local arm = math.floor(cell / 3)
      local x0, y0, x1, y1 = x - t, y - t, x + cell, y + cell
      love.graphics.rectangle("fill", x0, y0, arm, t)
      love.graphics.rectangle("fill", x0, y0, t, arm)
      love.graphics.rectangle("fill", x1 - arm + t, y0, arm, t)
      love.graphics.rectangle("fill", x1, y0, t, arm)
      love.graphics.rectangle("fill", x0, y1, arm, t)
      love.graphics.rectangle("fill", x0, y1 - arm + t, t, arm)
      love.graphics.rectangle("fill", x1 - arm + t, y1, arm, t)
      love.graphics.rectangle("fill", x1, y1 - arm + t, t, arm)
    end

    -- ------- this mod's OWN scenes
    --
    -- The Pokedex does not depend on the box mod, and must not: two mods
    -- that each stand alone are two mods, and one that goes blank without
    -- the other is half of one. These six are drawn here, in this file,
    -- with this mod's own art -- no files, no imports, nothing borrowed.
    --
    -- If the box mod happens to be installed its ninety-one scenes are
    -- offered as well, appended to this list. That is the right shape for a
    -- cross-mod seam: better together, whole apart.
    local function tone(c, a)
      love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, a or 1)
    end

    local function hash(i)
      return (i * 2654435761) % 4294967296
    end

    -- A ridge drawn column by column from two sines and a wobble. Triangles
    -- give a zigzag and a single sine gives a hump; this gives a horizon.
    local function ridge(w, h, baseY, amp, seed, drift)
      for x = 0, w, 2 do
        local hx = hash(x + seed)
        local y = baseY
          - math.floor(amp * math.sin((x + drift) / 37))
          - math.floor(amp * 0.45 * math.sin((x + drift) / 11))
          + (math.floor(hx / 65536) % 5) - 2
        if y < h then love.graphics.rectangle("fill", x, y, 2, h - y) end
      end
    end

    local OWN = {
      { id = "DAWN", palette = { { 254, 238, 226 }, { 246, 200, 176 },
                                 { 196, 140, 150 }, { 84, 62, 92 } },
        draw = function(w, h, t, pal)
          for i = 0, 5 do
            tone(pal[1], 1 - i * 0.07)
            love.graphics.rectangle("fill", 0, math.floor(h * i / 6), w, h / 6 + 1)
          end
          tone(pal[2], 0.9)
          love.graphics.circle("fill", math.floor(w * 0.72), math.floor(h * 0.30), 14)
          for rank = 0, 2 do
            tone(pal[2 + math.min(1, rank)], 0.5 + rank * 0.2)
            ridge(w, h, math.floor(h * (0.62 + rank * 0.11)), 5 + rank * 3,
                  rank * 29, t * (0.02 + rank * 0.01))
          end
        end },

      { id = "SEA", palette = { { 232, 246, 252 }, { 168, 214, 236 },
                                { 84, 150, 196 }, { 26, 64, 104 } },
        draw = function(w, h, t, pal)
          tone(pal[1], 1)
          love.graphics.rectangle("fill", 0, 0, w, h)
          for i = 0, 3 do
            tone(pal[2], 0.35 + i * 0.1)
            local y = math.floor(h * (0.25 + i * 0.18))
            for x = -8, w + 8, 8 do
              local wy = y + math.floor(math.sin((x + t * 0.4 + i * 13) / 15) * 2) * 2
              love.graphics.rectangle("fill", x, wy, 6, 2)
            end
          end
          -- weed along the floor, leaning with the current
          for i = 0, 13 do
            local x = (math.floor(hash(i) / 65536) % w)
            local tall = 10 + (i % 5) * 4
            local lean = math.floor(math.sin((t + i * 31) / 40) * 3)
            tone(pal[3], 0.7)
            for k = 0, tall do
              love.graphics.rectangle("fill",
                x + math.floor(lean * k / tall), h - k, 2, 1)
            end
          end
        end },

      { id = "FOREST", palette = { { 238, 248, 232 }, { 176, 214, 154 },
                                   { 88, 148, 88 }, { 34, 68, 44 } },
        draw = function(w, h, t, pal)
          tone(pal[1], 1)
          love.graphics.rectangle("fill", 0, 0, w, h)
          for rank = 0, 2 do
            tone(pal[2 + math.min(1, rank)], 0.55 + rank * 0.2)
            ridge(w, h, math.floor(h * (0.52 + rank * 0.14)), 6 + rank * 4,
                  rank * 41 + 7, t * (0.015 + rank * 0.012))
          end
          -- leaves coming down, three depths
          for i = 0, 17 do
            local speed = 0.1 + (i % 3) * 0.06
            local y = ((t * speed + i * 19) % (h + 8)) - 4
            local x = (math.floor(hash(i + 99) / 65536) % w)
              + math.floor(math.sin((t + i * 27) / 34) * 5)
            tone(pal[3], 0.6)
            love.graphics.rectangle("fill", x % w, y, 2, 2)
          end
        end },

      { id = "NIGHT", palette = { { 26, 28, 44 }, { 58, 62, 96 },
                                  { 128, 134, 178 }, { 232, 234, 248 } },
        draw = function(w, h, t, pal)
          tone(pal[1], 1)
          love.graphics.rectangle("fill", 0, 0, w, h)
          for i = 0, 47 do
            local hx = hash(i + 7)
            local x, y = math.floor(hx / 65536) % w, math.floor(hx / 13) % h
            tone(pal[4], 0.2 + 0.5 * math.sin((t + i * 51) / 90))
            love.graphics.rectangle("fill", x, y, 1, 1)
          end
          tone(pal[3], 0.9)
          love.graphics.circle("fill", math.floor(w * 0.78), 26, 11)
          tone(pal[1], 1)
          love.graphics.circle("fill", math.floor(w * 0.78) + 5, 22, 11)
          tone(pal[2], 1)
          ridge(w, h, math.floor(h * 0.84), 7, 13, t * 0.01)
        end },

      { id = "EMBER", palette = { { 32, 22, 26 }, { 86, 40, 40 },
                                 { 206, 96, 44 }, { 250, 208, 140 } },
        draw = function(w, h, t, pal)
          tone(pal[1], 1)
          love.graphics.rectangle("fill", 0, 0, w, h)
          for i = 0, 4 do
            tone(pal[2], 0.2 + i * 0.12)
            love.graphics.rectangle("fill", 0, h - (i + 1) * 8, w, 8)
          end
          tone(pal[2], 1)
          ridge(w, h, math.floor(h * 0.80), 9, 21, t * 0.008)
          tone(pal[3], 1)
          love.graphics.rectangle("fill", 0, math.floor(h * 0.93), w, h)
          for i = 0, 15 do
            local span = h
            local rise = (t * (0.12 + (i % 4) * 0.05) + i * 23) % span
            local x = (math.floor(hash(i + 3) / 65536) % w)
              + math.floor(math.sin((t + i * 31) / 28) * 5)
            tone(pal[4], 0.15 + 0.6 * (1 - rise / span))
            love.graphics.rectangle("fill", x % w, h - rise, 1, 1)
          end
        end },

      { id = "PAPER", palette = { { 246, 244, 236 }, { 226, 222, 206 },
                                  { 196, 190, 168 }, { 96, 92, 78 } },
        draw = function(w, h, t, pal)
          tone(pal[1], 1)
          love.graphics.rectangle("fill", 0, 0, w, h)
          tone(pal[2], 0.9)
          for y = 8, h, 12 do love.graphics.rectangle("fill", 0, y, w, 1) end
          tone(pal[3], 0.35)
          for x = 12, w, 12 do love.graphics.rectangle("fill", x, 0, 1, h) end
          -- a rule down the margin, and a slow shadow across the sheet
          tone(pal[3], 0.7)
          love.graphics.rectangle("fill", 18, 0, 1, h)
          local sx = ((t * 0.05) % (w + 60)) - 30
          tone(pal[2], 0.5)
          love.graphics.rectangle("fill", sx, 0, 24, h)
        end },
    }

    -- ------- and seven that somebody else drew
    --
    -- CC0 pixel art, quiet on purpose: what goes behind a list should not
    -- compete with it. Each is a seamless tile brought down to a texture
    -- and lightened towards white, because the type on top is black -- the
    -- lightening is the only thing done to them, and it is stated in
    -- THIRD_PARTY_NOTICES.md as CC BY asks even though CC0 does not.
    local ART = "mods/gen3_dex/assets/backdrops/"
    -- Four scenes, five hands. The seam of each was measured before it was
    -- given a speed: the ones that loop drift, the two that do not hold
    -- still and pan inside their own margin instead.
    local BORROWED = {
      { id = "BRICKS", by = "KENNEY",    image = "bricks_kenney.png",   speed = 0.02 },
      { id = "BRICKS", by = "GABOTTLES", image = "wall_gabottles.png",  speed = 0.02 },
      { id = "BLOCKS", by = "KENNEY",    image = "blocks_kenney.png",   speed = 0.02 },
      { id = "PEBBLES", by = "KENNEY",   image = "pebbles_kenney.png",  speed = 0.03 },
      { id = "PLANKS", by = "KENNEY",    image = "planks_kenney.png",   speed = 0.02 },
      { id = "TILES",  by = "CAELES",    image = "tiles_caeles.png",    speed = 0.02 },
      -- the parchment is a photograph of paper rather than a tile: it holds
      -- still, because sliding something that does not continue into itself
      -- drags its join across the screen. Same for the star field.
      { id = "PAPER2", by = "CRON",      image = "parchment_cron.png" },
      { id = "SPACE",  by = "ZANIN",     image = "space_zanin.png", veil = 0.55 },
    }

    local backdropImages = {}
    local function backdropImage(entry)
      local hit = backdropImages[entry.image]
      if hit ~= nil then return hit or nil end
      local ok, img = pcall(Assets.image, ART .. entry.image)
      backdropImages[entry.image] = (ok and img) or false
      return (ok and img) or nil
    end

    -- Drawn the way the box draws a strip: scaled by a whole number so the
    -- pixels stay square, tiled across, and scrolled only if it loops.
    local function drawBorrowed(entry, w, h, t)
      local img = backdropImage(entry)
      if not img then return false end
      local okDim, iw, ih = pcall(function()
        return img:getWidth(), img:getHeight()
      end)
      if not (okDim and iw and iw > 0 and ih and ih > 0) then return false end
      -- ------- HOW BIG: never "as tall as the canvas"
      --
      -- `floor(h / ih)` reads as "fill the height", and on the full-screen
      -- canvas the height is 576: one of Kenney's 64-pixel brick tiles came
      -- out at NINE times life size -- four bricks on a phone -- and a box
      -- mod strip at four. "sto sfondi fanno cacare, si vedono malissimo",
      -- and it was exactly this line.
      --
      -- A tile has a natural size and it is the Game Boy's: one pixel per
      -- pixel on a 160-wide screen, two on BIG's 320, and no more. The
      -- scale comes from the WIDTH being filled and nothing else, so a tall
      -- canvas gets MORE tiles rather than bigger ones.
      local scale = math.max(1, math.min(2, math.floor(w / 160)))
      local span = iw * scale
      local rows = ih * scale
      local ox = 0
      if (entry.speed or 0) > 0 then
        ox = math.floor(t * entry.speed) % span
      elseif span > w then
        ox = math.floor((span - w) / 2)
      end
      return pcall(function()
        love.graphics.setColor(1, 1, 1, 1)
        -- and DOWN as well as across: a tile that does not reach the foot
        -- of the screen used to leave the rest white
        local y = 0
        repeat
          local x = -ox
          while x < w do
            love.graphics.draw(img, x, y, 0, scale, scale)
            x = x + span
          end
          y = y + rows
        until y >= h
        love.graphics.setColor(1, 1, 1, 1)
      end)
    end

    local OWN_BY_ID = {}
    for _, sc in ipairs(OWN) do OWN_BY_ID[sc.id] = sc end
    -- a scene can have more than one tile behind it: BRICKS has two hands
    local BORROWED_BY_ID = {}
    for _, b in ipairs(BORROWED) do
      BORROWED_BY_ID[b.id] = BORROWED_BY_ID[b.id] or {}
      table.insert(BORROWED_BY_ID[b.id], b)
    end

    -- ------- what is behind the list
    --
    -- The screen used to be a white sheet, which is what a Game Boy list is
    -- and also what a spreadsheet is. These are the smallest thing that
    -- stops it reading as one: a wash, a horizon and something scattered
    -- over it, in tones close enough to white that black type on top loses
    -- nothing.
    local BACKDROPS = {
      soft  = { { 236, 242, 250 }, { 214, 228, 246 }, { 190, 212, 238 } },
      paper = { { 246, 244, 236 }, { 232, 228, 214 }, { 208, 202, 182 } },
      mint  = { { 234, 248, 240 }, { 208, 238, 224 }, { 176, 220, 202 } },
      peach = { { 252, 240, 232 }, { 248, 222, 208 }, { 238, 196, 178 } },
    }

    -- The SAVE is the only place this lives now that the option row is
    -- gone, and the fallback is SCENE -- what the row's default was, not
    -- what its failed-read fallback was. Those were two different values
    -- and only the first one ever reached a player: `backdropName() ~=
    -- "scene"` is what decides whether a scene is drawn at all, so
    -- inheriting the wrong one here would have quietly turned the
    -- backdrops off for everybody.
    local function backdropName()
      local okS, saved = pcall(function() return mod.save:get("backdrop") end)
      if okS and type(saved) == "string" then return saved end
      -- The row is gone from OPTIONS, but a value already sitting there
      -- from an older install is still honoured: taking a setting away
      -- should not silently change what somebody already chose.
      local ok, value = pcall(function() return mod.options:get("backdrop") end)
      if ok and type(value) == "string" then return value end
      return "scene"
    end

    -- ------- the box's wallpapers, borrowed
    --
    -- gen1recomp-gen3-boxes draws ninety-one scenes and ships the art for
    -- them. Copying either the code or the files here would mean two of
    -- everything and a slow drift between them, so this asks that mod for
    -- its painter through `mod.find` -- the same soft seam OW SPRITES uses
    -- for Wilds of Kanto, never a manifest dependency. No box mod, or an
    -- older one without the seam, and BACKDROP falls back to SOFT.
    local BOX_ID = "gen3_box"

    function self.boxHandle()
      local ok, handle = pcall(mod.find, BOX_ID)
      if not ok then return nil end
      return handle
    end

    -- A tick of its own: the Pokedex has no `paperTick`, and the scenes
    -- drift by it. One step per drawn frame is what the box does.
    self.sceneTick = 0

    -- Where the choice lives: the SAVE first, the option second.
    --
    -- The options rows still work and still travel with the install, but a
    -- background you can only change through START -> MODS -> OPTIONS is a
    -- background nobody changes. What the in-screen panel writes goes in the
    -- save, and the option is what a fresh save starts from.
    local function opt(key, fallback)
      local ok, value = pcall(function() return mod.options:get(key) end)
      if not ok or value == nil or value == "" then return fallback end
      return value
    end

    local function sceneChoice()
      -- while the chooser is open the screen wears what the cursor is on,
      -- not what was saved: that IS the preview
      if self.pick then
        return self.pick.scenes[self.pick.at], self.pick.hand
      end
      local saved = mod.save:get("scene")
      local hand = mod.save:get("hand")
      local id = type(saved) == "string" and saved ~= "" and saved or nil
      return id, math.max(1, tonumber(hand) or 1)
    end

    -- The scenes the box mod offers, in its own order, minus the two that
    -- are not places: PLAIN is the absence of a wallpaper and FAVOURITE is a
    -- pointer to one of the others, and neither means anything here.
    -- This mod's own scenes first, then the box mod's if it is installed and
    -- new enough to paint. Own first on purpose: what this mod can do by
    -- itself is what a player sees before they are asked to install
    -- anything, and the borrowed ones are a bonus rather than the point.
    local function sceneList()
      local out, seen = {}, {}
      local function add(id)
        if not seen[id] then seen[id] = true; out[#out + 1] = id end
      end
      for _, sc in ipairs(OWN) do add(sc.id) end
      for _, b in ipairs(BORROWED) do add(b.id) end
      local handle = self.boxHandle()
      local exports = handle and handle.exports
      if exports and exports.paintWallpaper then
        for _, w in ipairs(exports.wallpapers or {}) do
          if w.id ~= "PLAIN" and w.id ~= "FAVE" then add(w.id) end
        end
      end
      return out
    end

    -- Every hand on a scene, in one list: this mod's own drawing, the
    -- artist whose tile carries that name, and then the box mod's hands
    -- for the same place. A scene the box also has -- SEA, FOREST, NIGHT --
    -- used to be DROPPED here rather than merged, which quietly hid every
    -- artist the box had for it. They are all reachable now.
    local function handsFor(id)
      local out = {}
      if OWN_BY_ID[id] then out[#out + 1] = { by = "GEN3 DEX", own = true } end
      for _, b in ipairs(BORROWED_BY_ID[id] or {}) do
        out[#out + 1] = { by = b.by, borrowed = b }
      end
      local handle = self.boxHandle()
      local exports = handle and handle.exports
      if exports and exports.paintWallpaper then
        for _, a in ipairs(((exports.wallpaperArt) or {})[id] or {}) do
          out[#out + 1] = a
        end
      end
      return out
    end

    -- ------- why the scene did not draw, said out loud
    --
    -- This is the second time on this screen that a silent fallback cost an
    -- afternoon. A box mod older than 1.15.0 exports its wallpaper LIST --
    -- it has for many releases -- but not the painter, so the chooser fills
    -- with scene names and hands while the backdrop quietly stays SOFT: a
    -- pale wash with a grey horizon, on every scene, with no preview. It
    -- looks exactly like a broken preview, and it is a missing dependency.
    --
    -- So the reason is a string the screen can show, not a nil.
    function self.sceneTrouble()
      -- a scene of this mod's own never has trouble: that is the point of
      -- having them
      local id, hand = sceneChoice()
      if id == nil then return nil end
      local hands = handsFor(id)
      local chosen = hands[math.max(1, math.min(#hands, hand))]
      -- a hand this mod supplies never has trouble: that is the point of
      -- having them
      if chosen and (chosen.own or chosen.borrowed) then return nil end
      if OWN_BY_ID[id] or BORROWED_BY_ID[id] then
        -- the scene exists here; only ITS box hands are unreachable
        if #hands > 0 then return nil end
      end
      local handle = self.boxHandle()
      if not handle then return "NEEDS GEN3 BOX" end
      local exports = handle.exports
      if not (exports and exports.wallpapers and exports.wallpapers[1]) then
        return "NEEDS GEN3 BOX"
      end
      if not exports.paintWallpaper then
        return "NEEDS BOX 1.15+"
      end
      return nil
    end

    -- Returns the wallpaper record and the style to draw it with, or nil if
    -- the box mod cannot supply one.
    local function scenePaper()
      local handle = self.boxHandle()
      local exports = handle and handle.exports
      if not (exports and exports.paintWallpaper and exports.wallpapers) then
        return nil
      end
      local id, hand = sceneChoice()
      local paper
      for _, w in ipairs(exports.wallpapers) do
        if w.id == id then paper = w end
      end
      -- nothing chosen yet, or a scene that mod no longer has: the first
      -- real one rather than nothing
      if not paper then
        for _, w in ipairs(exports.wallpapers) do
          if not paper and w.id ~= "PLAIN" and w.id ~= "FAVE" then paper = w end
        end
      end
      if not paper then return nil end
      -- the hand index counts across ALL of this scene's hands, and the
      -- box's are last: take off the ones this mod supplied
      local list = (exports.wallpaperArt or {})[id] or {}
      local ahead = (OWN_BY_ID[id] and 1 or 0) + #(BORROWED_BY_ID[id] or {})
      local at = hand - ahead
      local style = list[math.max(1, math.min(#list, at))]
      return paper, style, exports.paintWallpaper
    end

    -- How much white goes over a scene before the list sits on it.
    --
    -- Every caption, number and entry name on this screen is black, and half
    -- of the box's scenes are night scenes: NIGHT, CIRCUIT, SPACE and
    -- VOLCANO would swallow the list whole. Rather than recolouring the type
    -- -- which is how a screen ends up unreadable in the one combination
    -- nobody tested -- the scene goes under a veil, and how heavy the veil
    -- is comes from the scene's own four colours. A dark room takes a lot; a
    -- pale sky takes a little; either way what you see is the scene, muted,
    -- with a list you can read on top of it.
    local function veilFor(paper, style)
      local palette = (style and style.palette) or (paper and paper.palette)
      if not palette then return 0.5 end
      local total, n, darkest = 0, 0, 255
      for i = 1, 4 do
        local c = palette[i]
        if type(c) == "table" and c[1] and c[2] and c[3] then
          local luma = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
          total, n = total + luma, n + 1
          if luma < darkest then darkest = luma end
        end
      end
      if n == 0 then return 0.5 end
      -- The DARKEST tone decides it, not the average. A night scene averages
      -- middling because its ramp ends in a bright star colour, and a veil
      -- chosen off that average leaves black text on charcoal. What has to
      -- be true is that the darkest thing in the picture ends up light
      -- enough to read black type on, so the veil is solved for exactly
      -- that: composite the scene under white until its floor reaches 180.
      local veil = (180 - darkest) / (255 - darkest)
      return math.max(0.15, math.min(0.82, veil))
    end

    -- The rows, rebuilt each frame because the hands a scene has depend on
    -- which scene is chosen -- and because the box mod can be enabled or
    -- disabled between two opens of this screen.
    local function viewRows()
      local rows = {}
      rows[#rows + 1] = {
        label = "SHOW",
        value = function() return FILTERS[self.filter].label end,
        step = function(d)
          self.filter = (self.filter - 1 + d) % #FILTERS + 1
          self.index = 0
          rebuild()
        end,
      }
      if #sceneList() > 0 then
        -- THEME is not a value to step through here: stepping a wallpaper
        -- inside a panel that covers it is choosing blind, which is what the
        -- first version of this got wrong. A opens the box's own chooser
        -- instead, where the screen itself is the preview.
        local id, hand = sceneChoice()
        rows[#rows + 1] = {
          label = "THEME",
          value = function()
            if backdropName() ~= "scene" then return "OFF" end
            -- a box mod that cannot paint says so HERE, where the choice is
            -- made, rather than leaving a chooser that changes nothing
            local trouble = self.sceneTrouble()
            if trouble then return trouble end
            local hands = handsFor(id)
            local h = hands[math.max(1, math.min(#hands, hand))]
            return (id or "-") .. ((h and h.by) and (" " .. h.by) or "")
          end,
          open = function()
            local scenes, at = sceneList(), 1
            for i, sid in ipairs(scenes) do if sid == id then at = i end end
            self.view = nil
            self.pick = { scenes = scenes, at = at, hand = hand,
                          wasScene = id, wasHand = hand }
          end,
        }
      end
      rows[#rows + 1] = {
        label = "WHAT'S NEW",
        value = function() return self.newsVersion end,
        open = function()
          self.view = nil
          self.openNews()
        end,
      }
      return rows
    end
    self.viewRows = viewRows
    self.handsFor = handsFor
    self.sceneList = sceneList

    -- ------- WHAT'S NEW: the popup nobody asked for and everybody needed
    --
    -- Three releases added a backdrop per Pokedex, a full-screen list and a
    -- contest anybody can enter, and every one of them lives behind a menu
    -- or an option: a player who never opens OPTIONS never learns that FULL
    -- SCREEN exists. So, once per version, on the first open after an
    -- update or an install, the screen says what changed and WHERE it is --
    -- pages ordered by how hard the thing is to reach, because that is the
    -- order in which somebody stops reading. It is in the VIEW panel too,
    -- so it can be read again on purpose.
    --
    -- Same shape, same keys and the same accent as the box mod's, down to
    -- the wrapping: a player with both mods learns this once.
    -- 0.18.0 changed what the screen DOES -- caught Pokemon move now -- so
    -- this moves with it. 0.17.1 through 0.17.3 did not, and did not.
    local NEWS_VERSION = "0.19.0"
    local NEWS_ACCENT = { 32, 96, 208 }
    local NEWS = {
      {
        title = "TOUCH",
        lines = {
          { "Read it with", true },
          { "your fingers.", true },
          { "" },
          { "Tap to point," },
          { "tap again to" },
          { "open." },
          { "" },
          { "Drag: page." },
          { "Pinch: zoom." },
        },
      },
      {
        title = "TURN IT ON",
        lines = {
          { "It ships OFF," },
          { "so nothing" },
          { "changes yet." },
          { "" },
          { "START - MODS -", true },
          { "OPTIONS - TOUCH", true },
          { "" },
          { "Made for" },
          { "phones." },
        },
      },
      {
        title = "THEY MOVE NOW",
        lines = {
          { "Caught Pokemon", true },
          { "animate.", true },
          { "" },
          { "Seen ones stay" },
          { "still and pale." },
          { "" },
          { "Needs a sprite" },
          { "pack that draws" },
          { "frames." },
        },
      },
      {
        title = "BACKDROPS",
        lines = {
          { "103 backdrops", true },
          { "behind the list.", true },
          { "" },
          { "Scenes drawn here" },
          { "and tiles by nine" },
          { "artists." },
          { "" },
          { "Next page: how" },
          { "to change one." },
        },
      },
      {
        title = "SET A BACKDROP",
        lines = {
          { "SELECT opens the" },
          { "VIEW panel." },
          { "" },
          { "A on THEME opens", true },
          { "the chooser.", true },
          { "" },
          { "Up, down: scene" },
          { "Left, right: who" },
          { "A: keep it" },
        },
      },
      {
        title = "FULL SCREEN",
        lines = {
          { "The list fills", true },
          { "your whole", true },
          { "device, many more", true },
          { "rows at once.", true },
          { "" },
          { "It is off until" },
          { "you turn it on." },
          { "" },
          { "Next page: where" },
        },
      },
      {
        title = "TURN IT ON",
        lines = {
          { "OPTIONS, then" },
          { "MODS, then" },
          { "GEN 3 DEX, then", true },
          { "FULL SCREEN.", true },
          { "" },
          { "GRID is there" },
          { "too: CLASSIC fits" },
          { "more rows, BIG" },
          { "draws them whole." },
        },
      },
      {
        title = "THE PICTURES",
        lines = {
          { "No more white", true },
          { "card under the", true },
          { "caught ones: the", true },
          { "scene shows.", true },
          { "" },
          { "A sprite pack is" },
          { "used here now," },
          { "Crystal art and" },
          { "the rest." },
        },
      },
      {
        title = "THE CONTEST",
        lines = {
          { "Your backdrop can", true },
          { "ship with the", true },
          { "mod.", true },
          { "" },
          { "A tile of 64x64" },
          { "that repeats, or" },
          { "a 160x144 scene." },
          { "" },
          { "See CONTEST.md", true },
          { "on the mod page." },
        },
      },
    }

    local function newsSeen()
      local ok, value = pcall(function() return mod.save:get("newsSeen") end)
      return ok and value or nil
    end

    -- ------- WHEN THE PANEL IS ALLOWED TO OPEN ITSELF
    --
    -- Two cases, and only two: a FIRST INSTALL, and an update that actually
    -- carries the thing the panel talks about. Everything else stays quiet.
    --
    -- NEWS_VERSION is NOT the manifest's version and must never be wired to
    -- it. It is the version that last changed what the mod DOES, so a
    -- release that only fixes a bug leaves it alone and nobody is
    -- interrupted. Bump it when a page below describes something a player
    -- can now do and could not before.
    --
    -- The comparison is OLDER-THAN, not DIFFERENT-FROM. `~=` was the bug: a
    -- save carrying a newer stamp than the build it is running -- somebody
    -- who tried a prerelease and went back to stable -- differs from
    -- NEWS_VERSION, so the panel opened and announced features the running
    -- build does NOT have. Older-than is false in that direction.
    local function olderThan(seen, target)
      if seen == nil or seen == "" then return true end -- first install
      if seen == target then return false end
      local function parts(v)
        local out = {}
        for n in tostring(v):gmatch("%d+") do out[#out + 1] = tonumber(n) end
        return out
      end
      local a, b = parts(seen), parts(target)
      for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y end
      end
      return false
    end

    local function closeNews()
      self.news = nil
      pcall(function() mod.save:set("newsSeen", NEWS_VERSION) end)
    end

    local function openNews() self.news = { page = 1 } end
    self.openNews = openNews
    self.closeNews = closeNews
    self.newsPages = NEWS
    self.newsVersion = NEWS_VERSION
    if olderThan(newsSeen(), NEWS_VERSION) then openNews() end
    self.newsOlderThan = olderThan

    -- written in CLASSIC pixels and drawn at whole scale, so BIG and full
    -- screen get the same page twice as big rather than the same page in a
    -- corner with tiny text
    local function newsRect(L)
      local k = math.max(1, math.floor(L.cell / 28))
      local w = math.min(L.w - 8, 152 * k)
      local h = math.min(L.h - 8, 136 * k)
      local x = math.floor((L.w - w) / 2)
      local y = math.floor((L.h - h) / 2)
      return x - x % 8, y - y % 8, w, h, k
    end
    self.newsRect = function() return newsRect(layout(game)) end
    local function newsInner(L)
      local _, _, w, _, k = newsRect(L)
      return math.floor((w - 16 * k) / k)
    end
    self.newsInner = function() return newsInner(layout(game)) end

    -- clipped to the panel, NOT to the screen: `fit` above measures against
    -- the whole surface, and this text lives inside a box in the middle of
    -- it. (The box mod's equivalent is called fitTo and takes a width;
    -- calling that name here is what crashed 0.17.0 on the first frame the
    -- popup drew -- this screen has no such function, so it was a call to
    -- nil, and the error walked straight out of draw() and closed the app.)
    local function clipTo(text, maxW)
      text = tostring(text or "")
      while #text > 1 and Font.width(text) > maxW do
        text = text:sub(1, #text - 1)
      end
      return text
    end

    local function wrapNews(text, maxW)
      local out, line = {}, nil
      for word in tostring(text or ""):gmatch("%S+") do
        local try = line and (line .. " " .. word) or word
        if Font.width(try) <= maxW or not line then
          line = try
        else
          out[#out + 1] = line
          line = word
        end
      end
      out[#out + 1] = line or ""
      return out
    end
    self.wrapNews = wrapNews

    local function drawNews()
      local page = NEWS[self.news and self.news.page or 1]
      if not page then return end
      local L = layout(game)
      local x, y, w, h, k = newsRect(L)
      local g = love.graphics
      g.setColor(1, 1, 1, 1)
      g.rectangle("fill", x, y, w, h)
      g.setColor(0, 0, 0, 1)
      g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
      g.rectangle("line", x + 2.5, y + 2.5, w - 5, h - 5)

      local inner = newsInner(L)
      local scaled = k > 1 and pcall(function()
        g.push(); g.translate(x, y); g.scale(k, k)
      end)
      local ox0, oy0 = x, y
      if scaled then ox0, oy0 = 0, 0 end
      local step = scaled and 1 or k
      local tx0 = ox0 + 8 * step
      local ty = oy0 + 8 * step
      local bottom = (scaled and (h / k) or h) + oy0
      g.setColor(0, 0, 0, 1)
      Font.draw(clipTo(Strings("%s %s", page.title, NEWS_VERSION), inner),
        tx0, ty)
      ty = ty + 14 * step
      for _, entry in ipairs(page.lines) do
        local text = type(entry) == "table" and entry[1] or entry
        local hi = type(entry) == "table" and entry[2]
        for _, line in ipairs(wrapNews(text, inner)) do
          if ty + 8 * step <= bottom - 14 * step then
            if hi then
              g.setColor(NEWS_ACCENT[1] / 255, NEWS_ACCENT[2] / 255,
                NEWS_ACCENT[3] / 255, 1)
            else
              g.setColor(0, 0, 0, 1)
            end
            Font.draw(line, tx0, ty)
            ty = ty + 10 * step
          end
        end
      end
      g.setColor(0, 0, 0, 1)
      local last = self.news.page >= #NEWS
      Font.draw(clipTo(Strings("%d/%d %s", self.news.page, #NEWS,
        last and "A:CLOSE" or "A:NEXT B:EXIT"), inner),
        tx0, bottom - 12 * step)
      if scaled then pcall(g.pop) end
      -- real colours, so the rect is reported as such: otherwise the frame's
      -- shade remap turns the accent into one of four greys
      pcall(function()
        if type(PaletteFX.markTrueColor) == "function" then
          PaletteFX.markTrueColor(x, y, w, h)
        end
      end)
      g.setColor(0, 0, 0, 1)
    end
    self.drawNews = drawNews

    local function updateNews()
      local input = game.input
      if input:wasPressed("b") then
        closeNews()
      elseif input:wasPressed("a") or input:wasPressed("right")
             or input:wasPressed("start") then
        if self.news.page >= #NEWS then
          closeNews()
        else
          self.news.page = self.news.page + 1
        end
      elseif input:wasPressed("left") then
        self.news.page = math.max(1, self.news.page - 1)
      end
    end
    self.updateNews = updateNews


    -- Whether a scene will actually be painted this frame: BACKDROP says
    -- SCENE, and either it is one of this mod's own or the box mod is there
    -- to paint its one. Both the palette zones and the cell wash ask this.
    function self.sceneIsDrawn()
      if backdropName() ~= "scene" then return false end
      local id, hand = sceneChoice()
      if id == nil then return true end
      local hands = handsFor(id)
      local chosen = hands[math.max(1, math.min(#hands, hand))]
      if chosen and (chosen.own or chosen.borrowed) then return true end
      local handle = self.boxHandle()
      local exports = handle and handle.exports
      return (exports and exports.paintWallpaper) ~= nil
    end

    local function drawScene(L)
      local id, hand = sceneChoice()
      if id == nil then id = OWN[1].id end
      -- WHICH hand decides what draws: the same place can be this mod's own
      -- drawing, somebody's tile, or one of the box mod's wallpapers, and
      -- they are three different things behind one name.
      local hands = handsFor(id)
      local chosen = hands[math.max(1, math.min(#hands, hand))]
      if chosen and chosen.own then
        local own = OWN_BY_ID[id]
        local ok = own and pcall(own.draw, L.w, L.h, self.sceneTick, own.palette)
        if ok then
          self.sceneVeil = veilFor({ palette = own.palette })
          return true
        end
        return false
      end
      if chosen and chosen.borrowed then
        if drawBorrowed(chosen.borrowed, L.w, L.h, self.sceneTick) then
          -- most of these are lightened towards white on purpose, so the
          -- wash under the cells is the lightest one. The star field is
          -- not -- a lightened space is not space -- so it names its own.
          self.sceneVeil = chosen.borrowed.veil or 0.2
          return true
        end
        return false
      end
      local paper, style, paint = scenePaper()
      if not paint then return false end
      local ok = pcall(paint, paper, L.w, L.h, style, self.sceneTick)
      if not ok then return false end
      -- The veil is NOT laid over the whole screen. Doing that was the
      -- first version and it was wrong in the way a photograph shows: a
      -- dark scene under seventy percent white is not a muted scene, it is
      -- a white screen with a grey smudge along the bottom, and the aurora
      -- it was meant to show had disappeared entirely.
      --
      -- What needs to be light is what carries black type: the cells and
      -- the two caption rows. Those get it, the scene keeps the rest, and
      -- that is the arrangement the box already uses.
      self.sceneVeil = veilFor(paper, style)
      return true
    end

    local function drawBackdrop(L)
      local name = backdropName()
      if name == "scene" then
        if drawScene(L) then return end
        -- the box mod is not installed: SOFT rather than nothing
        name = "soft"
      end
      local tones = BACKDROPS[name]
      if not tones then return end
      local function set(i, a)
        local c = tones[i]
        love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, a or 1)
      end

      -- the wash: bands rather than a true gradient, because a Game Boy
      -- screen has never had a smooth one and banding at this scale reads
      -- as deliberate
      local bands = 6
      for i = 0, bands - 1 do
        set(1, 1 - i * 0.06)
        love.graphics.rectangle("fill", 0, math.floor(L.h * i / bands),
          L.w, math.ceil(L.h / bands) + 1)
      end

      if name == "paper" then
        -- ruled paper: a grid you could have written the list on
        set(2, 0.75)
        for y = 8, L.h, 12 do
          love.graphics.rectangle("fill", 0, y, L.w, 1)
        end
        set(3, 0.35)
        for x = 12, L.w, 12 do
          love.graphics.rectangle("fill", x, 0, 1, L.h)
        end
      else
        -- a low horizon with two soft hills, and dots above it: enough for
        -- the eye to place the list ON something
        local horizon = math.floor(L.h * 0.72)
        set(2, 0.7)
        for x = 0, L.w, 2 do
          local y = horizon
            - math.floor(6 * math.sin(x / 37))
            - math.floor(3 * math.sin(x / 13))
          love.graphics.rectangle("fill", x, y, 2, L.h - y)
        end
        set(3, 0.5)
        for x = 0, L.w, 2 do
          local y = horizon + 8
            - math.floor(5 * math.sin((x + 60) / 29))
          love.graphics.rectangle("fill", x, y, 2, L.h - y)
        end
        for i = 0, 23 do
          local hx = (i * 2654435761) % 4294967296
          local x = math.floor(hx / 65536) % L.w
          local y = math.floor(hx / 7) % math.max(1, horizon - 12)
          set(2, 0.5)
          love.graphics.rectangle("fill", x, y + 6, 2 + (i % 2), 2)
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
    end

    function self:draw()
      local L = layout(game)
      -- the clock is wound in update(), on the logic step: see the note there
      love.graphics.clear(1, 1, 1, 1)
      drawBackdrop(L)
      -- the caption rows on solid bands: they carry black type, they are
      -- two thin strips, and a scene is not worth losing a title over
      if self.sceneIsDrawn() then
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.rectangle("fill", 0, 0, L.w, 14)
        love.graphics.rectangle("fill", 0, L.h - 24, L.w, 24)
      end
      love.graphics.setColor(0, 0, 0, 1)

      Font.draw(fit(Strings("POKeDEX %d/%d %s",
        self.owned, self.total, FILTERS[self.filter].label)), TEXT_X, 4)

      local start = pageStart()
      -- This grid has no margins: its cells touch, so washing every cell is
      -- washing the whole screen -- which is how the first two attempts at
      -- this ended with a white screen and a smudge. The cells take a
      -- WHISPER, 15%, exactly as the box's slots do, and the scene keeps
      -- its colour between and behind them.
      local onScene = self.sceneIsDrawn()
      local dark = onScene and (self.sceneVeil or 0) > 0.5
      for slot = 0, perPage() - 1 do
        local x, y = cellRect(slot)
        local e = self.entries[start + slot + 1]
        if onScene then
          love.graphics.setColor(1, 1, 1, 0.15)
          love.graphics.rectangle("fill", x, y, L.cell, L.cell)
        end
        -- black rules vanish on a night scene, so over a dark one they are
        -- drawn in white instead: the grid has to read either way
        if dark then
          love.graphics.setColor(1, 1, 1, 0.4)
        else
          love.graphics.setColor(0, 0, 0, 0.25)
        end
        love.graphics.rectangle("line", x + 0.5, y + 0.5, L.cell - 1, L.cell - 1)
        love.graphics.setColor(1, 1, 1, 1)
        if e then
          -- A never-met species stays a blank in EITHER path: e.state is
          -- checked before either picOf or owSprite is even asked.
          -- la cella, non la TABELLA: in pieno schermo con GRID CLASSIC
          -- la disposizione e' un'altra tabella con la stessa cella da 28,
          -- e confrontare le tabelle lasciava quelle celle senza icone --
          -- cioe' con la figura di battaglia dimezzata, che e' esattamente
          -- il caso per cui le icone esistono
          local small = L.cell == LAYOUT.classic.cell
          local drawnOw = false
          if e.state ~= "unknown" and small
             and opt("ow_sprites", false) then
            local sprite = owSprite(e.def)
            if sprite then
              local k = picScale(sprite, L.cell)
              local w, h = sprite:getWidth() * k, sprite:getHeight() * k
              if e.state == "seen" then
                love.graphics.setColor(1, 1, 1, DIM_SEEN)
              end
              drawnOw = pcall(love.graphics.draw, sprite.image, sprite.quad,
                x + (L.cell - w) / 2, y + (L.cell - h) / 2, 0, k, k)
              if not drawnOw then love.graphics.setColor(1, 1, 1, 1) end
            end
          end
          -- the game's own mini icon, when no follower sprite took the cell
          local drawnIcon = false
          if not drawnOw and e.state ~= "unknown" and small then
            drawnIcon = drawMenuIcon(e.def, x, y, L.cell, e.state == "seen")
          end
          if not drawnOw and not drawnIcon then
            local img, trueColor
            if e.state ~= "unknown" then img, trueColor = picOf(e.def) end
            -- Caught moves, seen holds still. The two halves of a dex were
            -- already told apart by ink; now they are told apart across the
            -- room, and a species with no second frame reads as seen-and-
            -- caught exactly as it did before.
            if img and e.state == "owned" then
              local frames = animOf(e.def)
              if frames then
                img = frames[1
                  + math.floor(self.sceneTick / ANIM_EVERY) % #frames]
              end
            end
            if img then
              local k = picScale(img, L.cell)
              local w, h = img:getWidth() * k, img:getHeight() * k
              -- a seen-but-uncaught species is dimmed rather than hidden:
              -- you met it, you just do not own it. A THIRD, down from 45%:
              -- over a scene the old value read as "caught, in paler ink",
              -- and the two halves of a dex have to be told apart at a
              -- glance -- that is the whole information the screen carries.
              local alpha = e.state == "seen" and DIM_SEEN or 1
              -- Only what the zone pass would have coloured, and only where
              -- the zones have stood down: an OWNED species on a Gen 1 boot
              -- over a scene. A seen one was never coloured (no zone was
              -- ever emitted for it) and stays in its own greys; full-colour
              -- replacement art is drawn as it is, since a shade remap is
              -- what ruins that art; and Gold colours its own pictures.
              -- "Gold colours its own pictures" was wrong, and it is why
              -- every Pokemon on Gold came out grey -- caught ones too.
              -- Gold composes through Game2, which never runs the palette
              -- pass at all (it does not even ask a state for uiSize), so
              -- on that boot NOTHING was coming to colour these: not the
              -- engine, and not this file either, because this line went
              -- out of its way to stand aside for it.
              --
              -- On Gen 2 the colours therefore always travel with the
              -- PICTURE, scene or no scene, which is the one route that
              -- does not depend on a zone pass ever running. Gen 1 is
              -- unchanged: zones colour it on the plain background, and
              -- the figure carries its own colours over a scene, where
              -- per-cell zones would paint that white card again.
              local colors = nil
              if not trueColor and e.state == "owned"
                 and (onScene or isGen2(game)) then
                colors = monColours(game, e.def.id)
              end
              paintPic(img, x + (L.cell - w) / 2, y + (L.cell - h) / 2, k,
                colors, alpha)
            end
          end
        end
        love.graphics.setColor(0, 0, 0, 1)
      end

      local slot = self.index - start
      if slot >= 0 and slot < perPage() then
        local cx, cy = cellRect(slot)
        cursor(cx, cy, L.cell)
      end

      local line
      local e = self.entries[self.index + 1]
      if e then
        local numFmt = ("%%0%dd"):format((game.data.constants or {}).dexDigits or 3)
        if e.state == "unknown" then
          line = (numFmt .. " -----"):format(e.n)
        else
          line = (numFmt .. " %s"):format(e.n, e.def.name)
        end
      else
        line = Strings("NOTHING HERE")
      end
      Font.draw(fit(line), TEXT_X, L.h - 22)
      Font.draw(fit(Strings("SEEN %d SEL:VIEW B:EXIT", self.seen)),
        TEXT_X, L.h - 12)

      -- ------- the VIEW panel, drawn
      --
      -- Down the left, clear of the species menu's corner, and no wider than
      -- it needs: the whole point is that the wallpaper behind it keeps
      -- showing while you choose one, so a panel that covered the screen
      -- would be a panel that hid the thing being chosen.
      if self.view then
        -- Full width, one row per line, and the value CLIPPED to whatever
        -- the label leaves. The first version was sixteen tiles wide with
        -- the value right-aligned inside it, and a hand called GEN3 EMBER
        -- simply ran back over the word THEME -- two strings sharing eight
        -- pixels of height, which is unreadable in a way a screenshot shows
        -- immediately and a test never will.
        local rows = self.viewRows()
        local tx, tw = 0, math.floor(L.w / 8)
        local th = #rows + 2
        local ty = math.floor((L.h - 26) / 8) - th
        local left, right = tx * 8 + 6, (tx + tw) * 8 - 6
        Font.drawBox(tx, ty, tw, th)
        love.graphics.setColor(0, 0, 0, 1)
        for i, row in ipairs(rows) do
          local y = (ty + i) * 8 + 2
          -- the same cursor glyph the species menu uses, so the two menus
          -- on this screen are visibly the same kind of thing
          if i == self.view.row then Font.drawCode(Theme.cursor, left, y) end
          Font.draw(row.label, left + 10, y)
          local value = tostring(row.value() or "")
          local budget = right - (left + 10 + Font.width(row.label) + 8)
          while #value > 1 and Font.width(value) > budget do
            value = value:sub(1, #value - 1)
          end
          Font.draw(value, right - Font.width(value), y)
        end
        love.graphics.setColor(0, 0, 0, 1)
      end

      -- ------- the chooser's own line
      --
      -- No panel at all: the screen IS the preview, so all it needs is a
      -- line saying which scene and whose hand, plus the arrows that say
      -- the D-pad does something here. The same shape the box uses, on the
      -- same row as this screen's own footer.
      if self.pick then
        local id = self.pick.scenes[self.pick.at]
        local hands = handsFor(id)
        local h = hands[math.max(1, math.min(#hands, self.pick.hand))]
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, L.h - 24, L.w, 24)
        love.graphics.setColor(0, 0, 0, 1)
        local trouble = self.sceneTrouble()
        if trouble then
          -- the chooser works, the painting does not, and the difference is
          -- a version. Saying nothing here is what made this look like a
          -- broken preview for an entire release.
          Font.draw(fit(Strings("%s", trouble)), TEXT_X, L.h - 22)
          Font.draw(fit(Strings("SCENES NEED THE BOX MOD")), TEXT_X, L.h - 12)
        elseif self.pick.moved then
          Font.draw(fit(Strings("%s", id)), TEXT_X, L.h - 22)
          local by = Strings("<%s>", (h and h.by) or "-")
          Font.draw(by, L.w - TEXT_X - Font.width(by), L.h - 22)
          Font.draw(fit(Strings("A:KEEP B:BACK")), TEXT_X, L.h - 12)
        else
          -- until the D-pad is touched, say what it does. The box learnt
          -- this the hard way: a chooser that only shows a name looks like
          -- a label rather than something you can move.
          Font.draw(fit(Strings("%s <%s>", id, (h and h.by) or "-")),
            TEXT_X, L.h - 22)
          Font.draw(fit(Strings("UP/DN SCENE  L/R HAND")), TEXT_X, L.h - 12)
        end
      end

      if self.choice then
        -- top-right, clear of the footer and of the first cells
        local bw = 7 * 8
        local bx, by = L.w - bw - 8, 16
        Font.drawBox(bx / 8, by / 8, bw / 8, #CHOICES + 2)
        love.graphics.setColor(0, 0, 0, 1)
        -- one tile in from the border for the cursor, one more for the
        -- label -- the spacing every other menu in the game uses
        for i, c in ipairs(CHOICES) do
          local y = by + 8 + (i - 1) * 8
          if i == self.choice.index then
            Font.drawCode(Theme.cursor, bx + 8, y)
          end
          Font.draw(c.label, bx + 16, y)
        end
      end

      -- over everything, because it has taken the keys
      if self.news then self.drawNews() end
    end

    return self
  end

  -- ------- TOUCH
  --
  -- Off by default, and while it is off this returns before it looks at
  -- anything: the grid keeps the shape GRID was set to and no finger can
  -- move it. That is the whole of "touch disabled means standard".
  --
  -- The pad keeps first refusal by contract, not by our arithmetic: a
  -- pointer that begins on a virtual control belongs to the pad for its
  -- whole life and never reaches this hook (docs/modding.md). So there is
  -- nothing here to keep the d-pad and the fingers from fighting.
  --
  -- `live` is the grid currently on screen. It is set when one is built
  -- and every use is guarded by "is it still the top of the stack", so a
  -- finger that lands while a menu or an entry is open does nothing --
  -- the state on top owns the screen, and this is not it.
  local live = nil

  do
    local TAP_SLOP = 12    -- a tap that wanders less than this is still a tap
    local DRAG_STEP = 28   -- travel that turns a drag into one page
    local DRAG_MAX = 4     -- pages one event may move; a teleported pointer
                           -- arrives as ONE huge delta and would otherwise
                           -- fling the list to the end (the voxel mod clamps
                           -- its camera for the same reason)
    local PINCH_STEP = 48  -- gap change that counts as a deliberate pinch

    local fingers = {}     -- id -> { x, y, x0, y0, moved, slot }
    local pinch = nil      -- { a, b, gap } while two fingers are measuring

    local function count()
      local n = 0
      for _ in pairs(fingers) do n = n + 1 end
      return n
    end

    local function onTop(game)
      if not live then return false end
      local ok, top = pcall(function() return game.stack:top() end)
      return ok and top == live
    end

    local function touchOn()
      local ok, v = pcall(function() return mod.options:get("touch") end)
      return ok and v == true
    end

    -- Two fingers drive the GRID setting rather than a zoom of their own:
    -- this screen has exactly two cell sizes and already has a setting that
    -- picks between them. Spreading asks for the bigger cell, pinching for
    -- the smaller, and because it is that same setting the choice survives
    -- leaving the screen -- there is no second, hidden zoom to reconcile.
    local setGrid = setGridChoice

    local function beginPinch()
      if pinch or count() < 2 then return end
      local ids = {}
      for id in pairs(fingers) do ids[#ids + 1] = id end
      local a, b = fingers[ids[1]], fingers[ids[2]]
      local dx, dy = a.x - b.x, a.y - b.y
      local gap = math.sqrt(dx * dx + dy * dy)
      if gap < 16 then return end
      pinch = { a = ids[1], b = ids[2], gap = gap }
    end

    local function updatePinch()
      if not pinch then return false end
      local a, b = fingers[pinch.a], fingers[pinch.b]
      if not (a and b) then pinch = nil; return false end
      local dx, dy = a.x - b.x, a.y - b.y
      local gap = math.sqrt(dx * dx + dy * dy)
      local moved = gap - pinch.gap
      if math.abs(moved) < PINCH_STEP then return false end
      pinch.gap = gap
      return setGrid(moved > 0 and "big" or "classic")
    end

    mod.hooks:wrap("input.pointer", function(next, game, ev)
      if not (ev and touchOn() and onTop(game)) then return next(game, ev) end

      if ev.phase == "pressed" then
        if not ev.insideGame then return next(game, ev) end
        -- onto THIS screen's surface first: gameX/gameY are window units
        -- and the cells are not laid out in window units
        local ux, uy = live.toUI(ev.gameX, ev.gameY)
        fingers[ev.id] = { x = ux, y = uy, x0 = ux, y0 = uy, moved = false }
        beginPinch()
        return next(game, ev)
      end

      local f = fingers[ev.id]
      if not f then return next(game, ev) end

      if ev.phase == "moved" then
        f.x, f.y = live.toUI(ev.gameX, ev.gameY)
        if math.abs(f.x - f.x0) > TAP_SLOP
           or math.abs(f.y - f.y0) > TAP_SLOP then
          f.moved = true
        end
        if count() >= 2 then
          if not pinch then beginPinch() end
          if updatePinch() then return true end
          return next(game, ev)
        end
        -- One finger dragged up or down pages the list. Whole pages rather
        -- than pixels because the grid has no half-scrolled state to draw:
        -- it pages, and pretending otherwise would need a scroll offset
        -- that every other part of this screen would then have to respect.
        local dy = f.y - f.y0
        local steps = math.floor(math.abs(dy) / DRAG_STEP)
        if steps > 0 then
          steps = math.min(steps, DRAG_MAX)
          f.y0 = f.y
          local dir = dy > 0 and -1 or 1
          local moved = false
          for _ = 1, steps do
            if live.pageBy and live.pageBy(dir) then moved = true end
          end
          if moved then return true end
        end
        return next(game, ev)
      end

      if ev.phase == "released" or ev.phase == "cancelled" then
        local wasPinch = pinch ~= nil
        fingers[ev.id] = nil
        if pinch and (ev.id == pinch.a or ev.id == pinch.b) then pinch = nil end
        if ev.phase == "cancelled" or f.moved or wasPinch then
          return next(game, ev)
        end
        -- A clean tap. The FIRST one on a cell only moves the cursor
        -- there; a second on the same cell is A. On a phone a cell is a
        -- few millimetres, and opening on the first touch means opening
        -- whatever you happened to land on.
        local slot = live.slotAt and live.slotAt(f.x, f.y)
        if slot == nil then return next(game, ev) end
        if live.touchTap and live.touchTap(slot) then return true end
        return next(game, ev)
      end

      return next(game, ev)
    end)
  end

  mod.content.screens:register(SCREEN, { new = function(game)
    local screen = newDex(game)
    live = screen
    return screen
  end })

  mod.exports.filters = FILTERS
  mod.exports.layouts = LAYOUT

  -- ------- ways in
  --
  -- Two, and both are optional. REPLACE DEX makes the engine's own POKeDEX
  -- row open this grid; otherwise a separate DEX GRID row is added. With
  -- START MENU off the screen is still registered and another mod can push
  -- it, which is why neither switch is called "enabled".

  if opt("menu", true) then
    mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
      local out = next(game, items)
      if type(out) ~= "table" then return out end

      -- ------- THE GAME'S OWN POKEDEX ROW IS THE PERMISSION SLIP
      --
      -- Both start menus show that row only after Oak hands the Pokedex
      -- over -- Gen 1 says so in as many words (src/ui/StartMenu.lua:30),
      -- and Gold gates it on ENGINE_POKEDEX, the flag written at Mr.
      -- Pokemon's house (src/ui/gen2/StartMenu.lua:49,161-172). So its
      -- PRESENCE answers "does this player have a Pokedex" on either
      -- generation, without this file knowing a flag number or an item
      -- name, and without it having to be told again when the engine
      -- changes how the flag is stored.
      --
      -- Matched on `id` first and on the label only as a fallback: the id
      -- is stable, the label is text and one day it will be translated.
      local row
      for _, item in ipairs(out) do
        local label = tostring(item.label or "")
        if item.id == "pokedex"
           or (label:find("POK") and label:find("DEX")) then
          row = item
          break
        end
      end

      -- No row, no Pokedex, no grid. This screen used to add a DEX GRID
      -- line whatever the game said, so on a fresh Gold -- where the row
      -- does not exist yet -- the mod handed the player a Pokedex hours
      -- before the game meant to, and on any boot it sat BESIDE the real
      -- one instead of being it.
      if not row then return out end

      if opt("replace", true) then
        row.onSelect = function() mod.ui.push(game, SCREEN) end
        -- ...and on Gold that is not enough on its own. Gen 2's menu only
        -- honours `onSelect` when the row carries NO `value`
        -- (src/ui/gen2/StartMenu.lua:216); a vanilla row carries one, so it
        -- fell straight through to the engine's own dispatch and opened the
        -- vanilla Pokedex while REPLACE DEX sat there reading ON. Clearing
        -- the value turns the row into the shape a mod's own row has --
        -- label plus onSelect -- which Gen2Compat documents as answered on
        -- both generations. Gen 1's rows never had a value, so this is a
        -- no-op there and one path serves both.
        row.value = nil
        return out
      end
      return mod.ui.insertBefore(out, "SAVE", {
        label = "DEX GRID",
        onSelect = function() mod.ui.push(game, SCREEN) end,
      })
    end)
  end
end
