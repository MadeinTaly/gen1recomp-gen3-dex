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

  local SCREEN = "Gen3Dex"

  mod.options:define({
    { key = "grid", label = "GRID", type = "choice", default = "big",
      choices = { { "BIG", "big" }, { "CLASSIC", "classic" } } },
    -- Off leaves the engine's own list exactly where it was. The grid is
    -- still reachable from the START menu, so this is "which one does
    -- POKeDEX open", not "is the mod on".
    { key = "replace", label = "REPLACE DEX", type = "toggle", default = true },
    { key = "menu", label = "START MENU", type = "toggle", default = true },
  })

  local function layout()
    local ok, value = pcall(function() return mod.options:get("grid") end)
    return LAYOUT[(ok and value) or "big"] or LAYOUT.big
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

  local function dexOf(game)
    return game.save.pokedex or { seen = {}, owned = {} }
  end

  local function roster(game)
    local constants = game.data.constants or {}
    local byDex = {}
    for _, def in pairs(game.data.pokemon) do
      if def.dex then byDex[def.dex] = def end
    end
    local out = {}
    for n = 1, constants.dexSize or 151 do
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

    local function perPage() return COLS * ROWS end
    local function pageStart()
      return math.floor(self.index / perPage()) * perPage()
    end

    local function cellRect(slot)
      local L = layout()
      local c, r = slot % COLS, math.floor(slot / COLS)
      return L.gridX + c * L.cell, L.gridY + r * L.cell
    end
    self.cellRect = cellRect

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

    local function picOf(def)
      if not def.spriteFront then return nil end
      local ok, img = pcall(Assets.image, def.spriteFront)
      if ok then return img end
      return nil
    end

    function self:uiSize()
      local L = layout()
      return L.w, L.h
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
      local L = layout()
      if L.cell % 8 ~= 0 or L.gridX % 8 ~= 0 or L.gridY % 8 ~= 0 then
        return nil
      end
      local zones = {
        PaletteFX.zone(PaletteFX.GRAYS, 0, 0, L.w / 8 - 1, L.h / 8 - 1),
      }
      local tiles = L.cell / 8
      local start = pageStart()
      for slot = 0, perPage() - 1 do
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
      return zones
    end

    -- ------- input

    function self:update()
      local input = game.input
      local n = #self.entries
      local per = perPage()

      if input:wasPressed("b") then
        game.stack:pop()
        return
      end

      if input:wasPressed("select") then
        self.filter = self.filter % #FILTERS + 1
        self.index = 0
        rebuild()
        return
      end

      if n == 0 then return end

      if input:wasPressed("left") then
        self.index = (self.index - 1) % n
      elseif input:wasPressed("right") then
        self.index = (self.index + 1) % n
      elseif input:wasPressed("up") then
        self.index = (self.index - COLS) % n
      elseif input:wasPressed("down") then
        self.index = (self.index + COLS) % n
      elseif input:wasPressed("start") then
        -- page jump, the way the vanilla list uses left/right
        self.index = (self.index + per) % n
      elseif input:wasPressed("a") then
        local e = self.entries[self.index + 1]
        -- DexEntryMenu is the engine's own species page, which is also
        -- where Useful Dex hangs its extra pages. An unknown species has
        -- nothing to show, exactly as the vanilla list refuses it.
        if e and e.state ~= "unknown" then
          Screens.push(game, "DexEntryMenu", e.def.id)
        end
      end
    end

    -- ------- drawing
    --
    -- Every coordinate below comes from the layout. A number written for a
    -- 144-tall screen is the bottom of one canvas and the middle of the
    -- other, and text drawn there prints across the grid.

    local TEXT_X = 4
    local function textMax() return layout().w - TEXT_X * 2 end

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

    function self:draw()
      local L = layout()
      love.graphics.clear(1, 1, 1, 1)
      love.graphics.setColor(0, 0, 0, 1)

      Font.draw(fit(Strings("POKeDEX %d/%d %s",
        self.owned, self.total, FILTERS[self.filter].label)), TEXT_X, 4)

      local start = pageStart()
      for slot = 0, perPage() - 1 do
        local x, y = cellRect(slot)
        local e = self.entries[start + slot + 1]
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, L.cell - 1, L.cell - 1)
        love.graphics.setColor(1, 1, 1, 1)
        if e then
          local img = e.state ~= "unknown" and picOf(e.def) or nil
          if img then
            local k = picScale(img, L.cell)
            local w, h = img:getWidth() * k, img:getHeight() * k
            -- a seen-but-uncaught species is dimmed rather than hidden:
            -- you met it, you just do not own it
            if e.state == "seen" then love.graphics.setColor(1, 1, 1, 0.45) end
            love.graphics.draw(img, x + (L.cell - w) / 2, y + (L.cell - h) / 2,
              0, k, k)
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
      Font.draw(fit(Strings("SEEN %d SEL:FILTER B:EXIT", self.seen)),
        TEXT_X, L.h - 12)
    end

    return self
  end

  mod.content.screens:register(SCREEN, { new = function(game)
    return newDex(game)
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
      if opt("replace", true) then
        for _, item in ipairs(out) do
          local label = tostring(item.label or "")
          if label:find("POK") and label:find("DEX") then
            item.onSelect = function() mod.ui.push(game, SCREEN) end
            return out
          end
        end
      end
      return mod.ui.insertBefore(out, "SAVE", {
        label = "DEX GRID",
        onSelect = function() mod.ui.push(game, SCREEN) end,
      })
    end)
  end
end
