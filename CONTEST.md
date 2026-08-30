# Backdrop contest

The Pokédex grid is a wall of Pokémon over a picture. That picture can be
yours: entries are taken as they arrive, and the artist's name goes in the
chooser next to their work — `SKY < YOURNAME >` — which is where credit
actually gets read.

This is the same contest [gen3_box](https://github.com/MadeinTaly/gen1recomp-gen3-boxes)
runs for wallpapers, on the other side of the seam: a box wallpaper already
shows up in this mod's chooser, so a strip entered there wins twice. Enter
here for art meant for a **list** rather than for a grid of twenty boxes.

## Entering

Open a pull request adding your art to `assets/backdrops/` and a row to the
`BORROWED` table in `main.lua`. Say the only three things that matter:
**who made it, under what licence, and where it came from.** Only CC0, CC BY
and MIT are accepted. Without that line the PR does not merge — not
pedantry, it is what keeps the mod distributable.

## What the art has to be

A list backdrop is not a box wallpaper, and the difference is the reason
this file exists:

- **it is looked at through a grid of a hundred and fifty cells.** The box
  shows twenty; this screen shows up to two hundred. Anything with a subject
  in it — a building, a horizon, a face — is chopped into squares. **Texture
  wins here, composition wins there**
- **it repeats.** A tile of 16, 32 or 64 pixels is drawn across the whole
  screen at a whole-number scale, so it stays sharp: 64×64 is the sweet spot
- **quiet.** The mod washes each cell with 15% white and draws the rules over
  the top; art that is already busy leaves nothing for the Pokémon. Low
  contrast, few colours, no hard black lines
- **either dark or light, not both.** The screen solves one veil for the
  whole picture and writes its captions in black or white from it. A
  backdrop that is half night sky and half snow makes one of the two
  unreadable
- a full **160×144** picture is accepted too, and is treated as a scene: it
  is drawn once rather than tiled. Same rules, more room

## What the check does

CI measures the **seam** — the mean difference between the first and last
column — and reports whether the tile actually repeats. A tile that does not
join shows a line down the screen every time it wraps, and the measurement
says so before anybody has to squint at it. It is a measurement, not an
opinion: it never says whether the art is good.

## Who decides, and how

**There is no deadline.** Open the pull request when the art is ready; if it
is good and the licence line is there, it is merged and ships in the next
release with your name in the chooser.

The repository owner ([@MadeinTaly](https://github.com/MadeinTaly)) merges,
and that is the whole approval process today. If it is close but not there,
the PR says what would fix it and stays open rather than being closed.

**Two things get an entry turned down**, and both are avoidable:

- a licence that is not CC0, CC BY or MIT, or a source that cannot be
  checked;
- art that swallows the grid. A backdrop is looked at **with a hundred and
  fifty Pokémon on top of it**, and something gorgeous that hides them is a
  bad backdrop.

## Credit

Every artist is named in `THIRD_PARTY_NOTICES.md`, in the chooser in game,
and in the release notes. The mod is MIT; your art keeps its own licence, and
that licence travels with it in the notices file.
