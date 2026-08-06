# gen1recomp-gen3-dex

The Pokédex as a **grid of pictures** instead of a list of names, for
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) — and every species
you own wearing **its own colours**.

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
| **A** | the species page — the engine's own, so other dex mods still apply |
| **START** | jump a page |
| **SELECT** | filter: `ALL` / `OWNED` / `MISSING` / `SEEN ONLY` |
| **B** | out |

**START → MODS → Gen 3 Dex → OPTIONS..**

| Row | Values | Meaning |
| --- | --- | --- |
| `GRID` | `BIG` / `CLASSIC` | 320×288 with colour, or the Game Boy screen |
| `REPLACE DEX` | on / off | off leaves the vanilla list and adds a separate `DEX GRID` row |
| `START MENU` | on / off | whether either row is added at all |

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

`BIG` asks the renderer for its surface through the engine's own `uiSize()`
hook, which `Game:draw` reads from the top state every frame — so the
moment this screen is not on top the game is back on 160×144, with nothing
to restore.

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
