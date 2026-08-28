# gen1recomp-gen3-dex

The Pokédex as a **grid of pictures** instead of a list of names, for
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) — and every species
you own wearing **its own colours**.

## On Gold

Runs on Pokémon Gold as well as Red, Blue and Yellow. The dex covers Johto
rather than stopping at Mew, the caught half is read where Gold actually keeps
it, and **DATA** and **AREA** both open Gold's own dex entry — its AREA view is
the nest map, so the map is one button further in.

`GRID BIG` draws its full 320×288 grid there too, the same size as on Red —
Gold has no `uiSize()` a screen can ask for, so it gets there through Gold's
own **widescreen contract** instead: the same `drawsWidescreen()` /
`drawWidescreen(w, h)` pair the PC, the summary screen and the Pokédex's own
menu already use to fill the window instead of sitting in a small letterboxed
box. It falls back to `CLASSIC` only if the window itself is too small to fit
320×288 at a whole-number scale. It draws **without** the per-species
palettes described below — Gold is a Game Boy Color game and colours its own
pictures, so that half of `BIG` is a Super Game Boy trick that does not
apply there.

## Install

Download `gen3_dex-<version>.zip` from [Releases](../../releases), then
**Launcher → MODS → Import mod .zip**. The launcher keeps it updated on its
own, and it can be installed from the **Find mods** tab without touching a
file.

## Use

**START → POKéDEX.**

| | |
| --- | --- |
| D-pad | move the cursor |
| **A** | `DATA` / `CRY` / `AREA` — see below |
| **START** | jump a page |
| **SELECT** | filter: `ALL` / `OWNED` / `MISSING` / `SEEN ONLY` |
| **B** | out |

**START → MODS → Gen 3 Dex → OPTIONS..**

| Row | Values | Meaning |
| --- | --- | --- |
| `GRID` | `BIG` / `CLASSIC` | 320×288 with colour, or the Game Boy screen |
| `REPLACE DEX` | on / off | off leaves the vanilla list and adds a separate `DEX GRID` row |
| `START MENU` | on / off | whether either row is added at all |
| `A OPENS` | `MENU` / `DATA` | the three-way menu, or straight to the species page |
| `OW SPRITES` | on / off | draw Wilds of Kanto's overworld sprites in the `CLASSIC` grid (on by default; does nothing without that mod — see below) |
| `BACKDROP` | `SCENE` / `SOFT` / `PAPER` / `MINT` / `PEACH` / `WHITE` | what is behind the list. `SCENE` (the default) borrows a wallpaper from the box mod; the rest are drawn here, and all of them are pale because every caption on this screen is black type |
| `SCENE` | SEA, FOREST, SKY, CAVE, CITY, SNOW, NIGHT, DESERT, VOLCANO, SPACE, CASTLE, SAKURA, STORM, CIRCUIT, TRAIN, 90S | which wallpaper, when `BACKDROP` is `SCENE` — one choice for the whole Pokédex. **In game: press SELECT**, which opens a panel where SCENE and HAND change with left/right and the wallpaper behind changes as you move |
| `HAND` | 1 – 7 | which hand drew it: the artists and the drawn variants that scene has, in menu order. Past the end of a scene's list it falls back to the last one that exists |

## Where does it live

**A → AREA** puts the species on the town map, blinking on every place it
can be found.

That is not new code: it is the engine's own `LoadTownMap_Nest` — `TownMap`
with `nestSpecies` — which walks `data.encounters` and marks every map
whose wild slots hold the species. It is the Gen 3 *where does this live*
screen, and it has been in the engine the whole time; the vanilla dex list
reached it through the same DATA / CRY / AREA menu this one now offers.

0.1.0 went straight to the species page and quietly lost both `CRY` and
`AREA`. That was a regression against the list this grid replaces, not a
simplification.

## Twenty-one colours

The Game Boy could show **four palettes** on a screen. This shows
twenty-one.

A palette zone binds a palette to a *tile rectangle*, and the engine draws
each one scissored through the shade-remap shader — so the number of them
is a loop, not a hardware limit. Each owned species gets a zone carrying
its own palette, the same table the summary screen and the battle use.

Species you have **seen but not caught** are drawn dimmed, on the base
palette: one you have met but never owned should not be advertising its
colours. Ones you have never met are blanks.

## The one number this is built on

**56.**

A Gen 1 battle picture is 56×56, and in `BIG` the cell is 56 — so the
picture draws at **scale 1**. Not halved, not stretched: every pixel of the
sprite is one pixel of the canvas.

56 is also **seven tiles exactly**, and that is what makes the colours
possible: a palette zone is addressed in tiles. `CLASSIC`'s 28-pixel cell
is three and a half tiles and can carry no zone at all, so `CLASSIC` is
greyscale by necessity rather than by choice.

On Red, Blue and Yellow, `BIG` asks the renderer for its surface through the
engine's own `uiSize()` hook, which `Game:draw` reads from the top state
every frame — so the moment this screen is not on top the game is back on
160×144, with nothing to restore. Gold has no such hook to ask; it grants a
bigger surface only to a screen that paints its own through
`drawWidescreen()`, and this screen does exactly that when `BIG` is picked
there, at the same 320×288.

## What it does not do

**It does not replace the species page.** Pressing A opens the engine's own
`DexEntryMenu`, which is where
[Useful Dex](https://github.com/ShaneMcGovernIE/useful_dex) hangs its base
stats, BST, evolutions and movelist. That is deliberate: the two mods stack
instead of fighting, and if you have both, those pages are one press
further in.

**It does not make the Pokémon sharper.** The pictures are the ROM's own
art and cannot be redrawn. The larger surface buys room and colour, never
detail.

**It does not change what you have caught.** It reads `save.pokedex` and
writes nothing.

## OW SPRITES

**On by default, and it does nothing without that mod.** `CLASSIC` halves a 56×56 battle picture into a 28-pixel
cell, which is the best Gen 1 offers on its own — its four generic party
icons are unreadable in a grid, so there was never a third option.
[Wilds of Kanto](https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod)
(`overworld_wild_spawns`) changes that: it builds a per-species 16×16
overworld sprite, and 16 is a whole sprite in a 28-pixel cell rather than a
halved one.

With that mod installed and enabled and the layout set to `CLASSIC`, the
grid draws its sprites instead of the halved pictures. Without that mod, or
in `BIG`, nothing changes at all.

It is asked the same way that mod already draws the icons you see in the
vanilla party menu: through its follower sprite service, which honours
whatever **Sprite Style** you picked over there. Its general
`spriteProviders` seam is tried second, so the feature survives if that
party-menu path is ever retired.

`BIG` keeps the battle pictures for the reason the whole screen is built on:
at 56 they draw at scale 1, and a 16-pixel sprite would have to be blown up
four times to fill the cell.

**A never-met species stays a blank.** The other mod is never even asked
about one, because its sprite would reveal a Pokémon you have not
encountered. Seen-but-not-caught keeps its dimming.

It reaches that mod through the engine's own `mod.find`, not a manifest
dependency, and every call into it is wrapped — it is someone else's code on
someone else's release cycle, and a throw in a draw loop takes the frame
down. If it answers with the black silhouette it falls back to when it has
nothing better, that counts as a miss and the battle picture is drawn
instead: a silhouette in a dex grid hides which Pokémon it is, and the
halved picture does not.

It is **on by default** because it cannot change anything for anyone who
does not have Wilds of Kanto installed — without it the whole feature is one
`nil` check and the picture this grid always drew. If it ever misbehaves
against a future release of that mod, turning it off restores exactly that.

## Ideas, and help building them

**Got an idea for something this should do?** Open an issue — there is a
template for it. You do not need to know any Lua, and you do not need to
have worked out how it would be built. Describe what you want and why.

**Want to build it yourself?** Open a pull request. Collaboration is welcome
on any part of this.

Anything you send that includes art has to be your own work — nothing
traced, edited or recoloured from a ROM, a fan game, a wiki or another mod.

## Requirements and legal

Lua source only: **no ROM, no ROM-derived data, and no game assets** —
`modkit lint` reports `no ROM-derived content`. The pictures in the grid are
read at runtime from the cache the engine builds from *your own* legally
obtained cartridge dump, and a sprite pack that shadows `Assets.image` is
honoured rather than overridden.

You need Gen1Recomp and your own legally obtained Pokémon Red or Blue ROM.
Neither is provided here, and no help obtaining one will be given.

Not affiliated with, endorsed by, or connected to Nintendo, Game Freak, or
The Pokémon Company. Pokémon and all related names are trademarks of their
respective owners, used here only to describe what this software does.

## Support

<https://linktr.ee/made_in_taly>

## Licence

[MIT](LICENSE)
