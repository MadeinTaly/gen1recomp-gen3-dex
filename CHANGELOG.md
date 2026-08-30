# Changelog

## 0.19.0 -- fingers, and two of them resize the grid

**TOUCH, off by default.** While it is off this screen is exactly the screen
it was: the pointer hook returns before it looks at anything, so the grid
keeps whatever shape GRID was set to and no finger can move it. That is the
whole of "touch disabled means standard" -- there is nothing to
special-case, because nothing is special.

**Two fingers resize the grid.** A pinch does not invent a zoom of its own:
this screen has exactly two cell sizes and already has a setting that picks
between them, so spreading asks for the bigger cell and pinching for the
smaller. Because it is that same setting, the choice survives leaving the
screen -- there is no second, hidden zoom to reconcile with the one in the
options.

**A tap moves the cursor; a second tap on the same cell opens it.** On a
phone a cell is a few millimetres across, and opening on the first touch
means opening whatever you happened to land on. Both verbs go through the
same code the buttons use -- the cursor is `self.index`, opening is
`self:open` -- because a parallel way to navigate is how a screen ends up
with a touch cursor and a button cursor that disagree.

**A vertical drag pages the list.** Whole pages rather than pixels: the grid
has no half-scrolled state to draw, and pretending otherwise would need a
scroll offset every other part of this screen would then have to respect.
Travel is clamped, because a pointer that teleports arrives as ONE enormous
delta and would otherwise fling the list to the end.

A finger is turned back into a cell by `cellRect` read backwards, in the one
place that converts a point, so the drawing and the touch cannot end up
disagreeing about where a cell is. Coordinates arrive already local to the
game viewport, so nothing here has to know about window scale or the
surround -- which matters, because every geometry bug in this run came from
a coordinate space nobody had checked.

Eleven new checks: a finger lands back on the cell it was drawn in, the
first tap only moves the cursor, the second opens, a drag pages and comes
back, and a point outside the grid is nobody's cell.

## 0.18.0 -- a caught Pokemon breathes

**FULL SCREEN did nothing on Gold.** The toggle read ON and the screen stayed
a 160x144 stamp in the middle of a white field. Gold composes through
`Game2`, which never asks a state how big it would like to be -- there is not
one mention of `uiSize` in `src/core/Game2.lua` -- and that is a real limit
for BIG. It is NOT a limit for FULL: `fullLayout` measures the actual window
through `love.graphics.getDimensions`, so its size was already right on
either generation, and `drawsWidescreen` has answered true for `L.full` on
Gen 2 all along. `layout()` was the one place that refused to hand a full
layout back on Gold, and everything downstream was waiting for one it never
got. The box mod has always done this correctly -- `if fullOn() then return
fullLayout() end` sits ABOVE its Gen 2 guard -- so this is the dex being
brought back in line with its twin rather than anything new being invented.


**Coming back from a Pokemon on Gold was a soft lock.** `pushEntry` opened
Gold's `Gen2PokedexMenu` without an `onClose`, and that screen's `close()`
sets `lastDexMode` and calls `onClose` -- that is ALL it does
(`src/ui/gen2/PokedexMenu.lua:339-341`). It never pops itself. Pushed without
a callback it stayed on the stack for ever, so B off an entry landed the
player on Gold's own Pokedex list with no way out. The engine's own caller
passes the callback (`src/ui/gen2/BoxMenu.lua:309`); so does this one now.
`Gen2SummaryMenu` has the same shape and the same trap.

**On Gold every Pokemon was grey, caught ones included.** Two faults on top
of each other. The colours were skipped on Gen 2 on the belief that "Gold
colours its own pictures" -- and when that was lifted they were still asked
for from the wrong table: `PaletteFX.monPal` reads the GEN 1 pack
(`data.palettes`, `src/render/PaletteFX.lua:435-444`) and answers nil on a
Gold boot. Gold keeps its own table and its own reader, and its own screens
use them -- `Palettes.monColors(data.gen2Palettes, species, shiny)`
(`src/ui/gen2/BoxMenu.lua:683-684`). Same answer shape, four colours
lightest first. A dex row has no mon to read DVs from, so shiny is false
here: this screen shows the species, not an individual.

As for the belief itself, Gold does not colour its own pictures. It composes
through `Game2`, which never runs the palette pass at all, so
nothing was colouring them -- not the engine, and not this file either,
because it went out of its way to stand aside for it. On Gen 2 the colours
now always travel with the PICTURE, scene or no scene, which is the one
route that does not depend on a zone pass ever running. Gen 1 is unchanged.

**No Pokedex, no grid -- and on Gold it IS the Pokedex.** This screen added
a `DEX GRID` row to the start menu whenever it could not find the game's own
POKéDEX row to replace. On a fresh Gold that row does not exist yet, so the
mod handed the player a Pokedex hours before the game meant to, and it sat
BESIDE the real one instead of being it.

Both start menus show that row only after Oak hands the Pokedex over -- Gen 1
says so in as many words (`src/ui/StartMenu.lua:30`) and Gold gates it on
`ENGINE_POKEDEX`, the flag written at Mr. Pokemon's house
(`src/ui/gen2/StartMenu.lua:49,161-172`). So its PRESENCE is the answer to
"does this player have a Pokedex", on either generation, without this file
knowing a flag number. No row now means no grid at all; a row means the grid
replaces it. Matched on `id` first and on the label only as a fallback, since
the id is stable and the label is text that will one day be translated.

**The notes popup follows a rule now.** It opens on a first install, and on
an update that actually carries the thing it describes -- nothing else. The
gate was `newsSeen() ~= NEWS_VERSION`, DIFFERENT-FROM where it should have
been OLDER-THAN: a save with a *newer* stamp than the running build --
somebody who tried a prerelease and went back -- reopened the panel and was
told about features that build does not have. It is `olderThan` now, which
is false going backwards.

`NEWS_VERSION` is not the manifest's version and must never be wired to it:
it is the version that last changed what the mod DOES. 0.17.1, 0.17.2 and
0.17.3 left it alone, so none of them interrupted anybody. This release
moves it, because this release moves the screen.

That bump also sprang a trap in the suite: this file copied `NEWS_VERSION`
into a literal of its own, the copy parted from the mod, the popup opened in
every screen the tests build and ate every keypress -- seven checks failed
in places that have nothing to do with release notes. The stamp is a
far-future version now, which survives any bump precisely because the check
is older-than.


Sprite packs that animate -- `crystal_animated_sprites_with_shiny_visuals` is
the one this was written against -- keep one folder per species and number
the frames inside it: `assets/front/normal/25/001.png`, and twenty more
beside it for Pikachu. The engine's `pokemon.sprite` seam hands back a single
string and has no idea the rest exist (`src/pokemon/Sprites.lua:24-41`), so
every screen in the game has always drawn frame one and stopped.

**The path is the map.** The frames beside the first one are the same name
with the next number, so they are found by asking for them until the answer
is no -- `Assets.image` raises on a file that is not there and the existing
`pcall` already collected it. Nothing here knows the pack's name, its folder
layout or its timings: any pack that numbers its frames animates, which is
why this is not a dependency and there is nothing in the manifest about it.

**The fallback is not a branch.** Art with no siblings -- the ROM's own
pictures, or a pack that ships one image per species -- has no second frame
and stays exactly as still as it was in 0.17.3. "No sibling" and "no pack"
are the same answer, so there is no second code path to get wrong.

**Caught moves, seen holds still.** The two halves of a dex were already told
apart by ink (`DIM_SEEN`, 30%); now they are told apart across the room. A
seen species stays on its first frame whatever the clock says.

**One guard, and it earns its place.** A run only counts as an animation if
it starts at `001`. A ROM sprite whose name happens to end in digits would
otherwise walk from `025.png` into `026.png` -- which is the NEXT SPECIES'
picture, not the next frame -- and animate a Pikachu into a Raichu.

Nine new checks, and they were run against the old code first: the frames are
found, the drawn image advances with the clock, a seen species does not move,
a run that does not start at 001 is refused, and ROM art stays still. The
suite is 199 checks.

## 0.17.3 -- the Unown row shows the form you met

The same fault the box mod was reported for (#7 there), on the other screen:
the species record's picture is letter A's, and a dex row has no mon to read
DVs from -- so the grid drew an A for a player who had never caught one.

The cart shows the form met FIRST: Pokedex_LoadSelectedMonTiles copies
wFirstUnownSeen into wUnownLetter before loading the picture, and the
engine's own PokedexMenu does the same off `save.firstUnownSeen`. So does
this grid now. A sprite pack that answered with its own art still wins; a
hook that passed the record straight back does not get to overrule the
letter.

## 0.17.2 -- the empty grid, and the backdrops at the size they were drawn

**Every cell was empty with a sprite pack installed.** 0.16.0 started
resolving pictures through `Sprites.path`, which is right -- it is the seam a
pack shadows -- but it took whatever came back as the only answer. A mod that
renders Pokemon some other way legitimately answers with a path this screen
cannot load, and the screen drew a hundred and fifty blank squares over a
scene. There are two candidates now, in order: what the hook says, and then
the species record. A candidate that does not produce an image is not an
answer. The box mod learned this in its own 1.8.1; this one had not.

**A backdrop is never magnified past twice life size.** The scale came from
the height of the canvas, and in full screen that is 576: one of Kenney's
64-pixel brick tiles came out at NINE times -- four bricks on a phone -- and
a borrowed box strip at four. It comes from the width now, capped at two,
and a tile repeats DOWN the screen as well as across instead of being blown
up to reach the bottom.

## 0.17.1 -- the popup closed the app

0.17.0 called `fitTo` inside the WHAT'S NEW popup. That is the name the box
mod uses for clipping a string to a width; THIS screen has `fit`, which
measures against the whole surface instead. So it was a call to a nil global,
on the first frame the popup drew -- which is the first frame of the Pokedex
after updating. The error walked out of draw() and the application closed.

The clip is now a local of its own, measured against the PANEL rather than
the screen, which is what the text inside a box in the middle of the screen
needs anyway.

**And the suite now draws.** Every page, in both grids, through the headless
stub -- plus the screen with no popup at all. 175 green checks said nothing
about a function that did not exist, because no test in this file had ever
called draw(). Restoring the bad name fails fourteen checks now.

## 0.17.0 -- a popup that says what changed, and where the thing is

Every release so far has added something behind a menu or an option -- the
backdrops, the chooser, FULL SCREEN -- and none of it announces itself. A
screen that looks the same as last week is a screen where nothing happened.

**WHAT'S NEW.** The first time the Pokedex opens after an update, or after
you install it, a popup says what changed and, more to the point, WHERE the
thing is: which panel, which option row, which keys. Six pages, ordered by
how hard the feature is to reach -- what you can see straight away first,
what needs two menus last -- with an accent colour on the line that names
the thing and on the contest. `A` turns the page, `B` closes, and it does
not come back until the next version.

It is written in Game Boy pixels and drawn at whole scale, so BIG and full
screen get the same page twice the size rather than the same page in a
corner in tiny text. The suite measures every line against the panel it is
drawn in: a page that overflows is exactly the kind of fault a test that
only checks "it did not crash" never sees.

`SELECT -> WHAT'S NEW` reopens it whenever you like.

**CONTEST.md**, the other half of it: the backdrop contest is now written
down. A tile of 64x64 that repeats, or a 160x144 scene; CC0, CC BY or MIT;
your name in the chooser next to your work. The rules are not the box mod's
-- a list backdrop is looked at through a hundred and fifty cells rather
than twenty, so texture wins where composition would win on a box.

## 0.16.0 -- the white card under the caught ones, and the artist's sprites

**The white card is gone.** A caught Pokemon sat on a white rectangle over
the scene and a seen-only one did not, which was the clue: the picture is
innocent. A ripped front pic has its border white flood-filled to alpha 0 by
the extractor, so nothing but the Pokemon is drawn. The card was the palette
ZONE -- a rectangle whose shade remap reads the red channel, so a pale sky
lands on shade 0, and shade 0 in a species palette is white.

Over a scene those zones are gone. The species' four colours are sent to the
PICTURE instead, through the same shader the zone pass uses, and a picture
is a shape rather than a rectangle -- so the scene between and behind the
Pokemon is left alone, which is the whole point of having painted it. On the
plain white background the zones still do the colouring, exactly as before.

**A seen-but-uncaught species is fainter**, a third rather than not-quite-a
half: the one thing this grid has to say at a glance is which half of the dex
a cell belongs to.

**The pictures come through the seam a sprite pack shadows.** This screen
read `spriteFront` off the species record, which is the one path a mod
cannot reach -- content registries freeze after load. So a pack that swaps
the art for Crystal's sprites repainted the whole game and not this screen.
Every picture is resolved through `Sprites.path` now, which raises
`pokemon.sprite` with `kind = "dex"`, the same seam the battle, the summary
and the Hall of Fame go through. Full-colour replacement art is drawn as it
is, with no shade remap.

**GRID means something in full screen**, like the box mod: CLASSIC gives
28-pixel cells (and far more rows), BIG the 56-pixel cells where a battle
picture is drawn whole. Those small cells also take the game's own menu
icons again -- the check compared layout TABLES rather than cell sizes, so
full screen at 28 was drawing halved battle pictures instead.

## 0.15.0 — FULL SCREEN, finished, with the sprites drawn whole

**The cell in full screen is 56, not 28**, for the same reason as the box
mod: that is the size a battle picture is, and at 28 it is halved. Four
columns by nine rows on a phone -- thirty-six entries you can actually look
at, rather than two hundred you cannot.

The WIP comes off here too. This screen is a list, and a list that fills the
screen is the whole feature: the paging, the cursor and the chooser all read
their shape from the layout rather than from the Game Boy constants, so the
grid holds at any size the engine will take.

## 0.14.0 — FULL SCREEN (work in progress)

**`FULL SCREEN (WIP)`**, off by default: the surface takes the shape of the
device and the room goes on **more rows** at the same cell size. Everything
else in this release is the stable mod.

The canvas is the window's own proportions, clamped to the 640x576 the
engine accepts, and `wantsFillScale` asks the renderer to blit it at a
fractional scale so it fills the screen rather than sitting in a letterbox.
Two earlier passes chased whole-number scales for square pixels and left
black bands over a third of the height; one of them also searched only
scales 8 down to 3 and settled on a 160-wide canvas, because
`getDimensions` reports logical units and a 1080-wide phone reports 405.

On Gold it goes through `drawsWidescreen` / `drawWidescreen`, the pair this
screen already used for BIG.

## 0.13.1 — the same scale bug, the same fix

FULL SCREEN chose the smallest canvas it could instead of the largest. The
scale search ran from eight down to three and never tried one or two, and a
phone reports about 405x900 in logical units -- so it settled on 160x300:
five columns, a Pokedex that looked zoomed in.

Every whole scale from one now, keeping whichever fits the most cells. At a
reported 405x900 that is thirteen columns by eighteen rows.

## 0.13.0 — FULL SCREEN: more rows, same cells

The same option the box mod grew, spent the way this screen wants it: the
surface follows the device and the room goes on **more rows**. Same
28-pixel cells, as many columns and rows as fit — on a phone that is a
dozen columns and eighteen rows instead of five by four.

The scale is chosen by counting what fits rather than by making pixels as
large as possible: the largest whole scale gives the FEWEST rows, which is
the opposite of the point. Whole scales only, and whole tiles, for the same
two reasons as ever — uneven pixels, and palette zones that start mid-tile.

On Gold it goes through `drawsWidescreen` / `drawWidescreen`, the pair this
screen already used for BIG. One condition, not a second implementation.

## 0.12.0 — eight tiles, five hands, and the box's scenes no longer hidden

**Thirteen places and fourteen backdrops with nothing else installed.** Six
are drawn here; the other eight are CC0 pixel art by five artists — Kenney,
cron, Gabottles, caeles and ZaninDevelopers — credited in
`THIRD_PARTY_NOTICES.md` and, more usefully, in the chooser itself.

Each tile is reduced until its motif reads as a texture (a 256-pixel pattern
cropped to 144 rows at 1:1 is a blob, not a pattern), lightened towards white
because the type here is black, and tiled at its own scale. `SPACE` is the
exception and keeps its night: a lightened star field is not a star field, so
it asks for a heavier wash under the cells instead.

**And the box mod's scenes are no longer dropped.** A scene both mods have —
SEA, FOREST, NIGHT — used to be skipped here, which quietly hid *every*
artist the box had for it. Hands are merged now: this mod's own drawing
first, then the tile artists, then the box's. With both mods installed the
chooser reaches **26 places and 103 backdrops**.

Which hand you are on decides what draws, rather than the scene's name: the
same place can be a drawing, a tile or a borrowed wallpaper, and those are
three different things behind one word.

## 0.11.1 — the scene keeps its colours

Reported with a photograph: the Pokedex drawing FOREST in four greys while
the Pokemon on top of it stayed orange and pink.

A scene is painted in its OWN RGB -- this mod's six are, and a borrowed one
arrives already coloured -- and on GRID BIG the engine then ran the finished
picture through the shade-remap a second time, flattening it. The base zone
opts out now, exactly as gen3_box's has since its 1.10.2: the per-species
cells are still drawn over it afterwards, so the entries keep their colours.

This is the same bug the box shipped and fixed months of work ago, in the
other mod, for the same reason. Inheriting a screen's shape without
inheriting what it learnt is how that happens, and the fix is now tested on
both sides rather than remembered.

## 0.11.0 — six scenes of its own

0.8.0 made this mod's backdrop depend on gen3_box, and that was the wrong
shape: **two mods that each stand alone are two mods; one that goes blank
without the other is half of one.** Reported as exactly that, and correctly.

**DAWN, SEA, FOREST, NIGHT, EMBER and PAPER are drawn here**, in this file,
with this mod's own art -- no files, no imports, nothing borrowed. A sun over
three ridges at first light; a shallow sea with weed leaning in the current;
a forest with leaves coming down at three depths; a starfield with a crescent
over a low hill; embers rising off a dark ridge; and ruled paper with a
shadow crossing it. Horizons are drawn from two sines and a wobble rather
than from triangles, because a triangle horizon is a zigzag and a single sine
is a hump.

**If gen3_box is installed and new enough, its ninety-one scenes are offered
too**, appended after these. That is the right shape for a cross-mod seam:
better together, whole apart. Without it, nothing is missing and nothing
complains -- `NEEDS BOX 1.15+` appears only if you pick one of ITS scenes
with an older copy installed.

`SCENE` and `HAND` are gone from the options: two lists of bare names in a
settings menu is a worse way to pick a picture than the chooser on the
screen. **SELECT, then A on THEME.**

The panel's columns also stopped overlapping -- `GEN3 EMBER` used to be drawn
over the word `THEME`, two strings sharing eight pixels of height -- and the
value is clipped to what the label leaves, with a test that measures both
widths.

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

**A box mod that cannot paint now says so.** Versions before gen3_box 1.15.0
export the wallpaper LIST but not the painter, so the chooser filled with
scene names and hands while the backdrop quietly stayed `SOFT` — a pale wash
with a grey horizon, the same on every scene, with no preview. That looks
exactly like a broken preview and is a missing dependency, and the screen
was silent about it. The THEME row and the chooser footer both say
`NEEDS BOX 1.15+` now.

**`SCENE` and `HAND` are gone from the options.** Two lists of bare names in
a settings menu is a worse way to pick a picture than the chooser on the
screen, and a stale value in there was one more thing to disagree with the
save. The choice lives in the save; a save that has never chosen gets the
first scene the box mod offers.

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
