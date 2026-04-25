# Night Market Runner — Prototype

> **PROTOTYPE — NOT FOR PRODUCTION**
> Throwaway code. If the results say PROCEED, the production version will be
> rewritten from scratch.

## Core question

**Does auto-scroll or player-paced feel right for Night Market Runner?**

Secondary questions:
1. What jump height / gravity / run speed feels good at 320×180?
2. Do art-bible sizes (24×40 player, 20×24 collectible, 32×32 tile) read in-game?
3. Does a color-pop pickup feel juicy enough, or does it need particles / SFX / screen-shake?

## How to run

1. Open **Godot 4.6** (stable).
2. From the Project Manager: **Import** → select this folder
   (`prototypes/night-market-runner/`) → **Import & Edit**.
3. Press **F5** (or the Play button). The first time Godot will prompt to set
   the main scene — pick `main.tscn`.

Window scales to ~1280×720 (native 320×180 at 4× integer scale).

## Controls

| Key | Action |
|---|---|
| ← / → or A / D *(A/D not yet mapped — arrows only for now)* | Move |
| Space or ↑ | Jump (hold for higher jump, release early for short hop) |
| `1` | Switch to PLAYER-PACED mode (default — camera follows you) |
| `2` | Switch to AUTO-SCROLL mode (camera forces right at 80 px/s) |
| `R` | Restart level |

## What to test (15–20 min total)

1. **Pure player-paced run** (press 1, play through). Try to grab all collectibles.
   - Does jumping feel right? Too floaty? Too heavy?
   - Are the gaps over obstacles the right difficulty?
   - Does collecting feel satisfying, or flat?

2. **Auto-scroll run** (press 2, play through).
   - Can you keep up at 80 px/s?
   - Does being pushed forward add stress (good) or frustration (bad)?
   - Do missed collectibles feel like losses you can recover, or forced cuts?

3. **A/B comparison**. Restart a few times in each mode. Which did you prefer
   after 3–5 runs?

4. **Tune values if a dial feels wrong**. Open `player.gd`, modify these:
   - `MOVE_SPEED` (default 110) — higher = faster run
   - `JUMP_VELOCITY` (default -230, negative = up) — more negative = higher jump
   - `GRAVITY` (default 800) — higher = snappier fall
   - `JUMP_CUT_MULT` (default 0.5) — 1.0 = no cut (full jump always), 0.3 = aggressive cut
   Reload the scene with R to see changes.

   In `main.gd`, `AUTO_SCROLL_SPEED` (default 80) controls how fast the camera
   pushes in auto-scroll mode.

## Scope of placeholder art

All visuals are flat `ColorRect` nodes at canonical art-bible sizes using the
locked palette (`#E8F542` player, `#F2A227` collectibles, `#D94F2B` hazards).
No sprites, no animation beyond the collectible bob. This is deliberate — the
prototype tests FEEL, not visual polish. If feel works with rectangles, it
will work better with art.

## What is intentionally missing

- All sounds
- All animation cycles (run/jump/enemy patrol)
- Particle effects on pickup
- Screen shake / camera effects
- Title, menu, level select
- Multiple levels
- Score persistence across deaths (deaths reset to 0 on restart — track in your head)
- Mobile / touch controls
- Web export (run desktop for prototyping; feel is identical)

## Reporting results

When done, report back with:
- Which mode felt better and why (specific — "auto-scroll felt panicky at 80 px/s" not "bad")
- Any numbers that felt wrong (jump too floaty? gravity too hard?)
- Whether the color-pop pickup felt satisfying enough or needs more juice
- Any bugs you hit (movement glitches, stuck geometry, etc.)
