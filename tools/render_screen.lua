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
function G.getDimensions() return W, H end
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
local run = T.sdk.loadMods({ "mods/gen3_box", "mods/gen3_dex" }, { data = Data })
assert(#run.errors == 0, tostring(run.errors[1]))

local store = run.loader.modOptions.gen3_dex or {}
run.loader.modOptions.gen3_dex = store
run.loader.modOptions.gen3_box = run.loader.modOptions.gen3_box or {}
store.grid = os.getenv("GRID") or "classic"
store.backdrop = "scene"
store.hand = os.getenv("HAND") or "1"

local game = {
  data = Data,
  save = { pokedex = { seen = {}, owned = {} }, party = {} },
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
  store.scene = name
  screen.view = (os.getenv("PANEL") == "1") and { row = 2 } or nil
  clear()
  local ok, err = pcall(function() screen:draw() end)
  if not ok then print("FAILED " .. name .. ": " .. tostring(err)) end
  writeRaw(OUT .. "/" .. name .. ".rgb")
  print("rendered: " .. name)
end
