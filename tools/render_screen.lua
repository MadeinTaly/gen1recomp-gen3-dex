-- Draws the Pokedex screen to a file, without a ROM and without a window.
--
-- The sister of gen3_box's tools/render_wallpapers.lua, and here for the
-- same reason: a screen that only exists as code cannot be judged by reading
-- it. This one matters more than most, because 0.8.0 draws a borrowed
-- wallpaper behind black text -- whether that is legible is a question about
-- pixels, and the only honest way to answer it is to look at them.
--
--   cd <engine>
--   OUT=/tmp/dex SCENES=SKY,NIGHT,VOLCANO PANEL=1 \
--     POKEPORT_DATA_DIR=tests/fixture_data \
--     luajit mods/gen3_dex/tools/render_screen.lua
--
-- Writes <SCENE>.rgb per scene; tools/rgb_to_png.py turns those into PNGs
-- and a contact sheet. DW/DH set the canvas (default 160x144), PANEL=1
-- draws with the VIEW panel open, HAND picks the artist.

package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local W = tonumber(os.getenv("DW") or "160")
local H = tonumber(os.getenv("DH") or "144")
local OUT = os.getenv("OUT") or "/tmp/dex"

local buf, cur = {}, { 1, 1, 1, 1 }

local function clear()
  for i = 1, W * H * 3 do buf[i] = 255 end
end

local function blend(x, y, r, g, b, a)
  x, y = math.floor(x), math.floor(y)
  if x < 0 or y < 0 or x >= W or y >= H then return end
  a = math.max(0, math.min(1, a or 1))
  local i = (y * W + x) * 3 + 1
  local function mix(old, new)
    return math.max(0, math.min(255, math.floor(old * (1 - a) + new * 255 * a)))
  end
  buf[i], buf[i + 1], buf[i + 2] = mix(buf[i], r), mix(buf[i + 1], g), mix(buf[i + 2], b)
end

local function px(x, y) blend(x, y, cur[1], cur[2], cur[3], cur[4]) end

local sc, stack = 1, {}
local G = {}
function G.push() stack[#stack + 1] = sc end
function G.pop() sc = table.remove(stack) or 1 end
function G.scale(s) sc = sc * (s or 1) end
function G.setColor(r, g, b, a) cur = { r or 1, g or 1, b or 1, a or 1 } end
-- La FINESTRA non e' la tela: il pieno schermo calcola la superficie
-- dividendo la finestra del dispositivo, quindi qui si dichiarano
-- separatamente (WINW/WINH, per default tre volte la tela).
local WINW = tonumber(os.getenv("WINW") or tostring(W * 3))
local WINH = tonumber(os.getenv("WINH") or tostring(H * 3))
function G.getDimensions() return WINW, WINH end
function G.clear(r, g, b)
  cur = { r or 1, g or 1, b or 1, 1 }
  for y = 0, H - 1 do for x = 0, W - 1 do px(x, y) end end
end

function G.rectangle(mode, x, y, w, h)
  x, y, w, h = x * sc, y * sc, w * sc, h * sc
  if mode == "fill" then
    for yy = y, y + h - 1 do for xx = x, x + w - 1 do px(xx, yy) end end
  else
    for xx = x, x + w - 1 do px(xx, y); px(xx, y + h - 1) end
    for yy = y, y + h - 1 do px(x, yy); px(x + w - 1, yy) end
  end
end

function G.circle(mode, cx, cy, r)
  cx, cy, r = cx * sc, cy * sc, r * sc
  for yy = math.floor(cy - r), math.ceil(cy + r) do
    for xx = math.floor(cx - r), math.ceil(cx + r) do
      local dx, dy = xx - cx, yy - cy
      if dx * dx + dy * dy <= r * r then px(xx, yy) end
    end
  end
end

function G.line(x1, y1, x2, y2)
  x1, y1, x2, y2 = x1 * sc, y1 * sc, x2 * sc, y2 * sc
  local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1), 1)
  for i = 0, steps do
    px(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
  end
end

function G.polygon(mode, ...)
  local p = { ... }
  for i = 1, #p do p[i] = p[i] * sc end
  local minY, maxY = math.huge, -math.huge
  for i = 2, #p, 2 do minY = math.min(minY, p[i]); maxY = math.max(maxY, p[i]) end
  for yy = math.floor(minY), math.ceil(maxY) do
    local xs, n = {}, #p / 2
    for i = 1, n do
      local x1, y1 = p[(i - 1) * 2 + 1], p[(i - 1) * 2 + 2]
      local j = (i % n) + 1
      local x2, y2 = p[(j - 1) * 2 + 1], p[(j - 1) * 2 + 2]
      if (y1 <= yy and y2 > yy) or (y2 <= yy and y1 > yy) then
        xs[#xs + 1] = x1 + (yy - y1) / (y2 - y1) * (x2 - x1)
      end
    end
    table.sort(xs)
    for k = 1, #xs - 1, 2 do
      for xx = math.floor(xs[k]), math.ceil(xs[k + 1]) do px(xx, yy) end
    end
  end
end

-- ------- the Pokemon themselves, and the shader that keys them
--
-- A front pic is a four-shade picture with an OPAQUE lightest shade behind
-- it, and over a scene that shade is a white card under every caught
-- Pokemon. The fix draws the picture through PaletteFX.keyedShader, which
-- maps the four shades to the species' colours and keys shade 0 away in one
-- pass -- and none of that is visible from a stub that ignores both images
-- and shaders. So this one does neither.
--
-- RAW points at a dump made by the box mod's tool:
--   python3 mods/gen3_box/tools/check_wallpaper.py <dir of pngs> --raw <out>
-- Without it the sprites render as nothing, which is what they did before.
local RAW = os.getenv("RAW")

local function u32(s, i)
  local a, b, c, d = s:byte(i, i + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local images = {}
function G.newImage(path)
  local key = tostring(path)
  if images[key] ~= nil then return images[key] end
  local name = key:match("([^/\\]+)%.png$")
  local f = RAW and name and io.open(RAW .. "/" .. name .. ".rgba", "rb")
  local img
  if f then
    local d = f:read("*a"); f:close()
    img = { _w = u32(d, 1), _h = u32(d, 5), _d = d,
            getWidth = function(self) return self._w end,
            getHeight = function(self) return self._h end }
  else
    img = setmetatable({},
      { __index = function() return function() return 0 end end })
  end
  images[key] = img
  return img
end

-- the same arithmetic as the real shader, in software: shade by RED
-- channel, and shade 0 keyed to nothing (src/render/PaletteFX.lua:198-212)
local shaderOn = nil
function G.newShader()
  return { _c = {}, send = function(self, k, v) self._c[k] = v end }
end
function G.setShader(sh) shaderOn = sh end
function G.getShader() return shaderOn end

local function through(r, g, b, a)
  local sh = shaderOn
  if not sh then return r, g, b, a end
  local c = sh._c["c0"] and sh._c or nil
  if not c then return r, g, b, a end
  local pick = (r > 0.83 and c.c0) or (r > 0.5 and c.c1)
    or (r > 0.17 and c.c2) or c.c3
  local keyed = (r > 0.83 and g > 0.83 and b > 0.83) and 0 or a
  return pick[1], pick[2], pick[3], keyed
end

function G.draw(img, x, y, _, sx, sy)
  if not (img and img._d) then return end
  sx = sx or 1; sy = sy or sx
  x, y = (x or 0) * sc, (y or 0) * sc
  local step = math.max(1, sx * sc)
  for iy = 0, img._h - 1 do
    for ix = 0, img._w - 1 do
      local o = 8 + (iy * img._w + ix) * 4
      local r, g, b, a = img._d:byte(o + 1) / 255, img._d:byte(o + 2) / 255,
                         img._d:byte(o + 3) / 255, img._d:byte(o + 4) / 255
      r, g, b, a = through(r, g, b, a)
      a = a * (cur[4] or 1)
      if a > 0 then
        for py = 0, step - 1 do
          for pxx = 0, step - 1 do
            blend(x + ix * step + pxx, y + iy * step + py, r, g, b, a)
          end
        end
      end
    end
  end
end

love.graphics = setmetatable(G, { __index = function() return function() end end })

-- Raw RGB out, converted by tools/rgb_to_png.py. A PNG needs a CRC and a
-- deflate stream, and writing both in 5.1 Lua without bitwise operators is
-- forty lines of arithmetic nobody should have to review to trust a
-- screenshot. Python already has zlib.

local function writeRaw(path)
  local f = assert(io.open(path, "wb"))
  local bytes = {}
  for i = 1, W * H * 3 do bytes[i] = string.char(buf[i]) end
  f:write(table.concat(bytes))
  f:close()
end

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()
-- both mods on ONE loader: that is what lets the Pokedex find the box mod
-- through mod.find, which is the whole thing being looked at
-- SOLO=1 carica il Pokedex da solo: e' cosi' che si guarda se sta in piedi
-- senza la mod delle box
local paths = (os.getenv("SOLO") == "1") and { "mods/gen3_dex" }
  or { "mods/gen3_box", "mods/gen3_dex" }
local run = T.sdk.loadMods(paths, { data = Data })
assert(#run.errors == 0, tostring(run.errors[1]))

local store = run.loader.modOptions.gen3_dex or {}
run.loader.modOptions.gen3_dex = store
run.loader.modOptions.gen3_box = run.loader.modOptions.gen3_box or {}
store.grid = os.getenv("GRID") or "classic"
store.fullscreen = os.getenv("FULL") == "1"
if store.fullscreen then
  -- il gioco onora uiSize() e POI disegna: qui si fa lo stesso a mano,
  -- altrimenti layout() ricade su CLASSIC e si guarda la cosa sbagliata
  local Renderer = require("src.render.Renderer")
  Renderer.uiWidth, Renderer.uiHeight = W, H
end
store.backdrop = "scene"

-- which scene lives in the SAVE now, not in an option
run.loader.modSave = run.loader.modSave or {}
run.loader.modSave.gen3_dex = run.loader.modSave.gen3_dex or {}
local dexSave = run.loader.modSave.gen3_dex
dexSave.hand = tonumber(os.getenv("HAND") or "1")

-- le immagini dei fondali passano da Assets.image: nel banco di prova
-- love.graphics.newImage e' uno stub che non legge file, quindi qui si
-- fornisce un caricatore che legge davvero i PNG a 8 bit del pack
local function readPng(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  f:close()
  return nil
end

-- Un dex VUOTO non disegna nessun Pokemon, e i Pokemon sono meta' di quello
-- che c'e' da guardare: il cartoncino bianco sotto i catturati si vede solo
-- se qualcuno e' catturato. Cosi': tutte le specie viste, una su due presa.
-- OWNED=none / all cambia la proporzione.
local seen, owned = {}, {}
do
  local ids = {}
  for id, def in pairs(Data.pokemon) do
    if def.dex then ids[#ids + 1] = id end
  end
  table.sort(ids, function(a, b) return Data.pokemon[a].dex < Data.pokemon[b].dex end)
  local mode = os.getenv("OWNED") or "half"
  for i, id in ipairs(ids) do
    seen[id] = true
    if mode == "all" or (mode == "half" and i % 2 == 1) then owned[id] = true end
  end
end

local game = {
  data = Data,
  save = { pokedex = { seen = seen, owned = owned }, party = {} },
  stack = { push = function() end, pop = function() end, top = function() end },
  input = { wasPressed = function() return false end },
}
local screen = Data.screens.Gen3Dex.new(game)

os.execute("mkdir -p " .. OUT)
local scenes = {}
for name in (os.getenv("SCENES") or "SKY,NIGHT,VOLCANO,SAKURA"):gmatch("[^,]+") do
  scenes[#scenes + 1] = name
end

for _, name in ipairs(scenes) do
  dexSave.scene = name
  screen.view = (os.getenv("PANEL") == "1") and { row = 2 } or nil
  -- PICK=1 draws the chooser: no panel, the screen itself wearing the scene
  if os.getenv("PICK") == "1" then
    screen.view = nil
    local scenes = screen.sceneList()
    local at = 1
    for i, id in ipairs(scenes) do if id == name then at = i end end
    screen.pick = { scenes = scenes, at = at, hand = 1,
                    wasScene = name, wasHand = 1, moved = os.getenv("MOVED") == "1" }
  else
    screen.pick = nil
  end
  clear()
  local ok, err = pcall(function() screen:draw() end)
  if not ok then print("FAILED " .. name .. ": " .. tostring(err)) end
  writeRaw(OUT .. "/" .. name .. ".rgb")
  print("rendered: " .. name)
end
