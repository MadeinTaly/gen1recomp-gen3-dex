# Changelog

## 0.10.0 — the box's chooser, here, and the scene actually visible

0.9.0 put SCENE and HAND in a panel and let you step them there, which was
choosing a wallpaper through the thing covering it. **THEME** is one row now,
and A opens the chooser the box has: **no panel at all** -- up and down
change the scene, left and right change the hand, and the Pokedex itself
wears what the cursor is on while you move. A keeps it, B puts back what was
there before you came in.

It is the box's chooser key for key, and deliberately so: anyone with both
mods has already learnt it once. The footer says what the D-pad does until
you touch it, then gets out of the way -- the same lesson the box learnt
from a chooser that looked like a label.

The VIEW panel also has a **cursor** now, the same glyph the species menu
draws, so the two menus on this screen look like the same kind of thing.

**And the scene is no longer washed away.** 0.8.0 put the whole screen under
a veil so black type would read on it; a photograph of the chooser open on
AURORA settled what that looks like — a white screen with a grey smudge
along the bottom, and the aurora gone. Veiling every cell instead was no
better: this grid's cells touch, so washing them is washing the screen.

What carries black type is two thin caption rows, and those get solid bands.
The cells take a **whisper** — 15%, the same as the box's slots — and the
scene keeps its colour everywhere else. Over a dark scene the cell rules are
drawn in white rather than black, because a black rule on a night sky is not
a rule.

## 0.9.0 — SELECT opens a panel instead of cycling in the dark

You could only change the backdrop from `START -> MODS -> OPTIONS`, which is
a background nobody changes. **SELECT** now opens a small VIEW panel with
three rows -- **SHOW** (the filter), **SCENE** and **HAND** -- and left/right
step each one. The wallpaper behind changes **as you move**, which is the
only way to choose one: the panel is a short box low on the screen precisely
so the thing being chosen stays visible around it.

SELECT used to cycle the filter silently: four states, no label, and you
found out which one you were on by watching the list change. It is a row
with a name on it now, one keypress deeper and considerably easier to use.

What the panel sets goes in the **save**; the `SCENE` and `HAND` option rows
still work and are what a fresh save starts from.

**`tools/render_screen.lua` and `tools/rgb_to_png.py` ship with the mod.**
The Pokedex draws black text over a borrowed wallpaper, and whether that is
legible is a question about pixels: these draw the screen without a ROM or a
window and turn the frames into a contact sheet. The box mod has carried the
same pair for three releases, and this is the release where not having them
would have meant guessing.

## 0.8.0 — the box's wallpapers, behind the list

`BACKDROP` gains **SCENE**, which is now the default: the Pokedex draws one
of the ninety-one wallpapers from
[gen1recomp-gen3-boxes](https://github.com/MadeinTaly/gen1recomp-gen3-boxes)
behind the list. `SCENE` and `HAND` say which — **one choice for the whole
Pokedex**, not one per page: a box has a scene each because a box is a shelf
you assign a meaning to, and this is a single list.

It is borrowed, not copied. That mod exports its painter and the Pokedex
calls it through `mod.find`, the same soft seam OW SPRITES uses for Wilds of
Kanto — never a manifest dependency. No box mod, an older one without the
seam, or a painter that raises, and the backdrop falls back to SOFT with the
frame intact. The art ships once, in the mod that owns it.

**The scene goes under a veil, and the veil is solved rather than picked.**
Every caption, number and entry name here is black, and half of those scenes
are night scenes: NIGHT, CIRCUIT, SPACE and VOLCANO would swallow the list
whole. Recolouring the type would be the other answer, and it is the one
that ends with a screen nobody can read in the combination nobody tested.
So the scene is composited under white until its DARKEST tone reaches a
luminance of 180 — the darkest tone, not the average, because a night scene
averages middling on the strength of its star colour and a veil chosen off
that leaves black text on charcoal.

The four painted backdrops from 0.7.0 are still there, WHITE included.

## 0.7.0 — something behind the list

The screen was a white sheet, which is what a Game Boy list is and also what
a spreadsheet is. `BACKDROP` puts something behind it: **SOFT** (a pale wash
with a low horizon and dots over it), **PAPER** (ruled, the sort of grid you
would have written the list on), **MINT**, **PEACH**, and **WHITE** for the
sheet exactly as it was through 0.6.0.

All of them are pale on purpose, and that is not timidity. Every caption,
number and entry name on this screen is drawn in black: a dark backdrop
would mean recolouring the type, and type that changes colour with a
background setting is how a screen ends up unreadable in the one combination
nobody tested. The wash is banded rather than smooth, because a Game Boy
screen has never had a smooth gradient and banding at this size reads as
deliberate.

## 0.6.0 — MENU ICONS: UNIQUE, ALWAYS or OFF

Confirmed on a real screen by the reporter of #1, in all three
configurations he could put it in: with Wilds of Kanto's overworld sprites,
with menyas/unique-menu-icons, and on a vanilla boot with neither. Three
pre-releases in one evening, each one answering something he had actually
looked at -- the last of which was the discovery that his original report was
not a bug at all.

beta.2 refused Gen 1's nine shared shapes so that a boot with no icon mod
would draw what it always drew. The reporter of #1, having now seen both,
said the quiet part: with his icon mod beta.2 is right, and in vanilla he
would rather have the icons anyway, shared shapes and all. Both positions are
reasonable and neither is mine to impose, so MENU ICONS is a choice now:

- **UNIQUE** (default) — only an icon chosen for a specific species. An icon
  mod's art, or a dataset carrying real per-species icons. A vanilla Gen 1
  boot has none, so the grid is exactly what 0.5.0 drew.
- **ALWAYS** — the game's own icon even when that is one of the nine shapes.
  Every bird the same bird, and some players want the icon look regardless.
- **OFF** — the halved battle picture, always.

A value stored while this was a toggle still reads: `false` is OFF, `true` is
UNIQUE.

## 0.6.0-beta.3 — MENU ICONS: UNIQUE, ALWAYS or OFF

beta.2 refused Gen 1's nine shared shapes so that a boot with no icon mod
would draw what it always drew. The reporter of #1, having now seen both,
said the quiet part: with his icon mod beta.2 is right, and in vanilla he
would rather have the icons anyway, shared shapes and all. Both positions are
reasonable and neither is mine to impose, so MENU ICONS is a choice now:

- **UNIQUE** (default) — only an icon chosen for a specific species. An icon
  mod's art, or a dataset carrying real per-species icons. A vanilla Gen 1
  boot has none, so the grid is exactly what 0.5.0 drew.
- **ALWAYS** — the game's own icon even when that is one of the nine shapes.
  Every bird the same bird, and some players want the icon look regardless.
- **OFF** — the halved battle picture, always.

A value stored while this was a toggle still reads: `false` is OFF, `true` is
UNIQUE.

## 0.6.0-beta.2 — MENU ICONS: the mini icon the party list draws

The reporter of #1 came back with the answer 0.5.1-beta.1 was built to find,
and it was not a failure at all: he had no follower mod installed. He expected
the CLASSIC grid to show **the game's own mini icons** — and he was right to.
A 16x16 menu icon fits a 28-pixel cell whole, which is the entire argument the
overworld sprites were added for; it just never occurred to this screen to ask
for the one the game already has.

**MENU ICONS**, on by default, draws it. The order in a CLASSIC cell is now:
Wilds of Kanto's overworld sprite if that mod is there and OW SPRITES is on,
then the game's own menu icon, then the halved battle picture as before. BIG
is untouched — a 16-pixel icon has no business being blown up to fill a
56-pixel cell, which is the same trade OW SPRITES already declines there.

**A boot with no icon mod draws exactly what it drew in 0.5.0**, and that is
a rule rather than a side effect. Gen 1's own menu icons are NINE SHARED
SHAPES handed out by dex number — BALL, BIRD, BUG, GRASS and the rest; every
bird is the same bird. That is fine in a party list of six with the name
written beside it, and useless in a grid whose whole job is telling twenty
cells apart: 151 species would collapse into nine repeating pictures, which
is strictly worse than the halved battle picture. So the dex-indexed default
is refused here. Only an icon chosen for a SPECIFIC species counts — which is
what an icon mod writes, and what a vanilla Gen 1 dataset does not have.
(Gold is the exception and needs no rule: its icons are per-species already,
so that boot shows Gold's own.)

**Every icon mod comes with it, and none of them needed a seam.** He is
running [unique-menu-icons](https://github.com/menyas/unique-menu-icons),
which does not patch a menu: it writes into the engine's own `icons` registry,
the table the party list already reads. So this screen asking the game for its
icon picks up that mod's art, and any other one's, for nothing. On Gen 1 the
draw goes through `PartyMenu.drawIcon` rather than a lookup of this screen's
own, because that function is four rules and not one — the per-species
override, the species record's own icon, the dex-indexed default, and the
`pokemon.icon` hook — plus the OBP0 bake the built-in 2bpp art needs to look
like the game's icon at all. Gold has no such free function (its icons are a
method on a live party screen), so that boot walks the same data by hand and
raises the same hook.

One thing worth writing down, because it nearly shipped: `PartyMenu.drawIcon`
returns nothing and simply stops when a species has no icon, so a `pcall`
around it reports success for a cell it never painted. Left alone, that would
have blanked those cells instead of falling back to the battle picture. The
path is resolved first now, and a species with no icon is a miss before
anything is drawn — with a test that fails if that regresses.

## 0.5.1-beta.1 — the grid can say why it fell back

Reported: the CLASSIC grid draws battle pictures where it used to draw
Wilds of Kanto's overworld icons.

**What this release is not.** It is not a fix, because I have not found the
cause yet, and I would rather say so than ship a guess. What I did establish:
nothing in the seam has changed here since 0.3.0 — the diff across 0.4.0 and
0.5.0 does not touch it — and Wilds of Kanto 2.2.0 still answers both of the
ways this screen asks. Loaded next to it, its party-icon resolver returns a
sprite with a path and its provider chain agrees. So the ask is not what
broke, and the answer arrives; something between that answer and a drawn
icon is dropping it on a real install, and from here I cannot see which.

**What this release is.** Every step of that ask was `pcall`ed and every miss
returned nil — right for a draw loop, useless for a report: the grid looked
identical whether that mod was absent, switched off, on a version without the
seam, or naming art this machine cannot open. It now says which, once per
reason per visit, in the log:

- Wilds of Kanto is not there — absent, switched off, or failed to load
- its party-icon resolver threw
- its resolver had no art for a species
- it answered with its own missing-sprite placeholder
- its provider chain has no art, or answered without a picture
- the art it named could not be loaded — **with the path**, because that path
  names the art pack that is missing

**One real change of behaviour.** Wilds of Kanto's own missing-sprite
placeholder is now treated as a miss rather than as a picture, which is the
rule this screen already applied to the black silhouette: a placeholder in a
dex grid is worse than the halved battle picture, which at least tells you
which Pokémon the cell is.

A pre-release, because it is an instrument rather than a repair.

0.4.0 forced `GRID BIG` to `CLASSIC` on a Gold boot with the honest reason
that `src/core/Game2.lua` never asks the top state for a `uiSize()` the way
Gen 1's `Game:draw` does (`src/core/Game.lua:471-475`) — it scales one
160×144 canvas through `Chrome.fitScale`, so a 320×288 layout laid out for
that canvas would have drawn straight off the edge of it.

That was the whole truth about `uiSize()`, and not the whole truth about
what Gold can do. Its own full-panel screens — the PC (`PcMenu.lua:77-78`),
the summary screen (`SummaryMenu.lua:230-231`) and the Pokédex's own menu
(`PokedexMenu.lua:134-135`) — reach a bigger surface through a different
door: `drawsWidescreen()` and `drawWidescreen(w, h)`, read by
`Game2:drawScene` (`Game2.lua:1450-1600`) to decide whether a state paints
its own surround across the whole window instead of sitting fixed at
160×144 inside a letterbox.

`GRID BIG` now opts into that on a Gold save. `drawWidescreen` fits its own
320×288 layout to the real window at a whole-number scale, centers it, and
draws through the exact same `self:draw()` Red already uses — so the grid,
the header, the cursor and the DATA/CRY/AREA box all land exactly where they
do on Gen 1, just reached through Gold's own contract instead of `uiSize()`.
It falls back to `CLASSIC` only if the window itself is too small to hold
320×288 at an integer scale, the same safety check Gen 1 already made
against its own canvas.

**No per-species palette zones on Gold, in either layout.** Gold is a Game
Boy Color game and colours its own pictures; the only zone `Game2` ever asks
for on its own is a single whole-screen present-palette one
(`Game2.lua:1342-1356`), never a per-state `sgbPalettes()` the way Gen 1's
`Game.lua:505` reads it. `sgbPalettes()` now says so directly on a Gold save
instead of relying on `BIG` forcing `CLASSIC` there to keep it unreachable.

`CLASSIC` is untouched on both generations, and Gen 1's own `BIG` path is
untouched too — `wantsFillScale`, the one Gen 1 field the new methods share a
neighbourhood with, only ever answers `true` for a Gold save, because
answering `true` unconditionally (the way Gold's own widescreen screens do,
since Gen 1 never reads it from them) would have switched Gen 1's `BIG` from
a fitted letterbox to a stretched fill.

## 0.4.0 — it runs on Gold

`"games": ["gen1", "gen2"]`. Four things had to be true, and three of them
were wrong in ways that throw nothing at all:

- **The caught half of the dex.** Gold keeps it under `caught`
  (`src/core/gen2/Save.lua:216`) where Gen 1 says `owned`. Reading the Gen 1
  name on a Gold save answers nil for every species, so the grid would have
  drawn a complete dex as seen-but-never-caught — every picture dimmed, every
  count zero, and no error anywhere.

- **Johto exists.** The roster ran to `constants.dexSize or 151`, and
  `constants` routes to `data.gen2Constants` on Gold, so the Gen 1 read comes
  back nil and the fallback stopped the dex at Mew. The ceiling is now the
  highest dex number actually present, which also covers a mod that adds
  species past the cart's own end.

- **DATA and AREA.** Gold has no `DexEntryMenu` and no `TownMap`: it folds
  both into one screen. `Gen2PokedexMenu` takes `entrySpecies` and opens
  straight onto that species' page, and its own AREA view *is* the nest map —
  so both entries land there, and AREA is one button further in rather than a
  screen this mod opens for you.

- **GRID BIG is CLASSIC on Gold.** `src/core/Game2.lua` never asks the top
  state for a `uiSize()` the way `src/core/Game.lua:471` does; it scales one
  160×144 canvas. A 320×288 layout would have been drawn into a Game Boy frame
  and fallen off the edge. The option is not written back, so a Gen 1 save
  that chose BIG is still BIG on Red.

Per-species palettes are a Super Game Boy trick and Gold draws in colour of its
own, so that part simply does not apply there.

## 0.3.0 — overworld sprites, when you have them

`CLASSIC` has always halved a 56×56 battle picture into its 28-pixel cell,
because Gen 1 has nothing better to offer: its four generic party icons are
unreadable in a grid. [Wilds of Kanto](https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod)
(`overworld_wild_spawns`) builds a per-species 16×16 overworld sprite, and 16
fits that cell whole. With that mod installed and enabled, the `CLASSIC` grid
draws its sprites instead of the halved pictures.

- It is asked the way that mod is already proven to answer: through the
  follower sprite service behind the icons it draws in the vanilla party
  menu, which honours the **Sprite Style** chosen over there. Its general
  `spriteProviders` seam is tried second, so the feature survives if that
  party-menu path is ever retired.
- `BIG` is untouched. At 56 a picture already draws at scale 1, and a
  16-pixel sprite would have to be blown up four times to fill the cell.
- **A never-met species stays a blank**, and the other mod is not even asked
  about one — its sprite would reveal a Pokémon you have not encountered.
  Seen-but-not-caught keeps its dimming.
- Reached through the engine's own `mod.find`, never a manifest dependency,
  so the absence of that mod is one branch rather than a hard requirement.
  Every call into it is wrapped: it is someone else's code on someone else's
  release cycle, and a throw in a draw loop takes the frame down.
- The black silhouette that mod falls back to when it has nothing better is
  treated as a **miss**, not a hit. A silhouette in a dex grid hides which
  Pokémon it is; the halved picture does not.

**On by default**, because with that mod absent the feature is one `nil`
check and the picture this grid always drew.

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
