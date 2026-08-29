# Third party notices

Most of this mod is Lua. The exception is the backdrops behind the list:
some are drawn in `main.lua` like everything else, and some are pixel art by
somebody else, shipped under a licence that allows it. The artist's name is
not buried in this file — it is the label you scroll through when you press
SELECT and open THEME.

**These are adaptations, and it is worth saying so even where the licence
does not require it.** No pixel is anybody's work but the artist's, and what
is done to each tile is mechanical:

- it is reduced until the motif reads as a texture rather than as a few
  enormous shapes — a 256-pixel tile cropped to 144 rows at 1:1 is a blob,
  not a pattern;
- it is **lightened towards white**, because every caption, number and entry
  name on this screen is drawn in black. How far is chosen per tile, and one
  of them is deliberately left dark: a lightened star field is not a star
  field, so `SPACE` keeps its night and asks for a heavier wash under the
  cells instead;
- it is tiled to the width the screen wants, at its own scale, never
  stretched.

## Public domain (CC0 1.0) — no conditions

- **Kenney** — *Pattern Pack*, used for `BRICKS < KENNEY >`,
  `BLOCKS < KENNEY >`, `PEBBLES < KENNEY >` and `PLANKS < KENNEY >`.
  https://opengameart.org/content/pattern-pack
- **cron** — *Old Parchment Paper*, used for `PAPER2 < CRON >`.
  https://opengameart.org/content/old-parchment-paper
- **Gabottles** — *Handpainted Tileable wall*, used for
  `BRICKS < GABOTTLES >`.
  https://opengameart.org/content/handpainted-tileable-wall
- **caeles** — *seamless tileset template*, used for `TILES < CAELES >`.
  https://opengameart.org/content/seamless-tileset-template
- **ZaninDevelopers** — *Pixel Space Background*, used for `SPACE < ZANIN >`.
  https://opengameart.org/content/pixel-space-background

CC0 asks for nothing at all. These credits are here because taking someone's
work without saying whose it is would be shabby, not because it is required.

## Drawn in this repository

`DAWN`, `SEA`, `FOREST`, `NIGHT`, `EMBER` and `PAPER` — the entries labelled
`GEN3 DEX` — are drawn procedurally in `main.lua`. No files, no imports,
nobody else's pixels. They can be looked at without a ROM through
`tools/render_screen.lua`, which draws the whole screen and writes the frames
out.

## Borrowed from the box mod, if it is installed

With [gen1recomp-gen3-boxes](https://github.com/MadeinTaly/gen1recomp-gen3-boxes)
1.15.0 or newer present, its wallpapers appear in the same chooser, painted
by that mod through the seam it exports. **None of that art ships here**: it
lives in the mod that owns it, with its own credits, and this one simply
asks. Without it nothing is missing — these backdrops are this mod's own.
