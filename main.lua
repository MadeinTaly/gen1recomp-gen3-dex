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
      Screens.push(game, "Gen2PokedexMenu", { entrySpecies = species })
    else
      Screens.push(game, "DexEntryMenu", species)
    end
  end

  -- What the player asked for.
  local function wanted()
    local ok, value = pcall(function() return mod.options:get("grid") end)
    return LAYOUT[(ok and value) or "big"] or LAYOUT.big
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
      local L = layout(game)
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
        if dim then love.graphics.setColor(1, 1, 1, 0.45) end
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
      if dim then love.graphics.setColor(1, 1, 1, 0.45) end
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
      return isGen2(game) and layout(game) == LAYOUT.big
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
      local scale = math.max(1, math.floor(math.min(winW / L.w, winH / L.h)))
      local ox = math.floor((winW - L.w * scale) / 2)
      local oy = math.floor((winH - L.h * scale) / 2)
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
      local input = game.input
      local n = #self.entries
      local per = perPage()

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

    function self:draw()
      local L = layout(game)
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
          -- A never-met species stays a blank in EITHER path: e.state is
          -- checked before either picOf or owSprite is even asked.
          local drawnOw = false
          if e.state ~= "unknown" and L == LAYOUT.classic
             and opt("ow_sprites", false) then
            local sprite = owSprite(e.def)
            if sprite then
              local k = picScale(sprite, L.cell)
              local w, h = sprite:getWidth() * k, sprite:getHeight() * k
              if e.state == "seen" then love.graphics.setColor(1, 1, 1, 0.45) end
              drawnOw = pcall(love.graphics.draw, sprite.image, sprite.quad,
                x + (L.cell - w) / 2, y + (L.cell - h) / 2, 0, k, k)
              if not drawnOw then love.graphics.setColor(1, 1, 1, 1) end
            end
          end
          -- the game's own mini icon, when no follower sprite took the cell
          local drawnIcon = false
          if not drawnOw and e.state ~= "unknown" and L == LAYOUT.classic then
            drawnIcon = drawMenuIcon(e.def, x, y, L.cell, e.state == "seen")
          end
          if not drawnOw and not drawnIcon then
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
