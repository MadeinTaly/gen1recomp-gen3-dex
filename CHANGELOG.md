# Changelog

## 0.2.2 — the choice had no cursor

**Fixed: nothing marked the selected row of DATA / CRY / AREA.** The three
labels sat there identically and the only way to tell which one A would
take was to count keypresses.

0.2.1 drew the arrow with `Font.draw(">")`. The game's charmap has no `>`,
and `Font.encode` answers a missing character by substituting a space:

```lua
if not reported[ch] and text:byte(span.from) >= 32 then
  reported[ch] = true
  Logger.warn("font: no glyph for %q", ch)
end
code = SPACE
```

One line in the log, once per character, from inside the draw path — and a
blank where the cursor should be. The engine's own menus never had this
problem because they draw a glyph **code**, not a character:
`Theme.cursor` is `$ED`, the filled arrow from `charmap.asm`.

So the choice now draws `Font.drawCode(Theme.cursor, ...)`, spaced the way
every other menu in the game spaces it: one tile in from the border for the
cursor, one more for the label.

The test captures `Font.drawCode` and asserts a cursor glyph is drawn, that
it sits on the selected row, that it moves when the selection moves, that
it clears the label, that it stays inside the box, and that it is gone once
the choice closes.

## 0.2.1 — the menu broke the grid under it

**Fixed: opening DATA / CRY / AREA collapsed the screen.** Three columns of
five, the header cut off mid-word, cells the wrong size.

`Game:draw` sizes the canvas from the **top state**:

```lua
local top = self.stack:top()
if top and top.uiSize then Renderer:setUISize(top:uiSize())
else Renderer:setUISize(Renderer.WIDTH, Renderer.HEIGHT) end
```

0.2.0 pushed the choice as a state of its own. That made *it* the top
state — and it has no `uiSize()`, so the canvas went back to 160×144 while
this grid, still visible underneath, carried on laying itself out for
320×288.

Two fixes, because either alone would leave the trap armed:

- **The choice is drawn by this screen** instead of being pushed. Nothing
  is ever on top while the grid is showing, so the surface cannot change
  under it.
- **The layout follows the surface being drawn**, not the one this screen
  asked for. Any future overlay — a text box, another mod's prompt — now
  finds a grid that lays itself out for the canvas it actually has.

Both are assertions now: the suite shrinks the surface mid-test and checks
that nothing runs off it, and checks that A pushes nothing.

## 0.2.0 — where does it live

- **`AREA`: the map of where a species is found.** Press A and the menu now
  offers **DATA / CRY / AREA**, the three the vanilla list always had.

  AREA is not new code: it is the engine's own `LoadTownMap_Nest` —
  `TownMap` with `nestSpecies` — which blinks a nest icon on **every map
  whose wild slots hold that species**, computed from `data.encounters`. It
  is the Gen 3 "where does this live" screen, and it has been sitting in
  the engine the whole time.

- **Fixed: 0.1.0 dropped two menu entries.** Going straight to the species
  page quietly lost both `CRY` and `AREA` — a regression against the list
  this grid replaces, not a simplification. Both are back.

- **`A OPENS`** (`MENU` / `DATA`) — `MENU` is the vanilla behaviour and the
  default; `DATA` keeps 0.1.0's single press straight to the species page
  for anyone who preferred it.

## 0.1.0

First release.

- **The dex is a grid.** Five by four battle pictures instead of 151 rows
  of text. The engine's own comment calls its list *"Minimal Pokédex:
  dex-ordered list with seen/owned markers"*, and it is exactly that.

- **Every owned species in its own colours.** A palette zone binds a
  palette to a tile rectangle, and the engine draws each one scissored
  through the shade-remap shader — so the count is a loop, not a hardware
  limit. The Game Boy could show four palettes at once; this shows
  twenty-one.

  Seen-but-uncaught species are drawn dimmed, on the base palette. One you
  have met but never caught should not be advertising its colours.

- **`SELECT` filters**: ALL, OWNED, MISSING, SEEN ONLY. MISSING is the one
  that earns its place — it is the fastest answer to *what am I still
  short of*.

- **`GRID` `BIG`** asks the renderer for a 320×288 surface, so a 56×56
  battle pic draws at **scale 1**: not halved, not stretched. 56 is also
  seven tiles exactly, which is what makes the colours possible at all —
  `CLASSIC`'s 28-pixel cell is three and a half tiles and can carry no zone.

- **A opens the engine's own species page**, not a copy of it. So
  [Useful Dex](https://github.com/ShaneMcGovernIE/useful_dex) keeps
  working: its base stats, BST, evolutions and movelist pages are one
  press further in. The two mods stack.

- **`REPLACE DEX`** (on) points the START menu's POKéDEX row here; off
  leaves the engine's list untouched and adds a separate `DEX GRID` row.
