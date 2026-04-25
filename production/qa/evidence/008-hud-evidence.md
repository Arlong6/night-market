# HUD Evidence — Story 008

**Story**: `production/stories/008-hud.md`
**Type**: Visual/Feel (manual verification required)
**Date**: [fill in when tested]
**Tester**: Solo mode self-test

## Setup

1. Open Godot 4.6 project at `src/`
2. Temporarily attach `hud.tscn` as a child of `main.tscn` (or a level scene once Story 009 is done)
3. Press F5 to run
4. Observe the HUD in the top-left corner of the 1280×720 window

## Acceptance Criteria Checks

- [ ] **Strip position & size**: Cream receipt strip appears at approx (2, 2) with size 128×24 (on native 320×180 viewport — scales 4× in browser window)
- [ ] **Background color**: Background is cream `#F5EDDA` (not white, has a subtle warm tint)
- [ ] **Bottom border**: 1px ink-black `#2A1A0A` line at the bottom edge of the strip
- [ ] **Score label**: Shows `SCORE 0000` at start; increments to `SCORE 0100`, `SCORE 0200`... on collectible pickups
- [ ] **Time label**: Shows `TIME 0:00` at start; increments live (e.g. `TIME 0:05`, `TIME 1:23`)
- [ ] **Deaths label**: Shows `D 0` at start; increments to `D 1`, `D 2`... on enemy hit
- [ ] **Text color**: All three labels render in stamp-red `#C2241A`
- [ ] **Font size**: 10px, readable at 4× browser scale
- [ ] **Pixel crispness**: Zoom screenshot to 400% in a viewer — no gray fringe / anti-aliasing
- [ ] **Layer ordering**: HUD visible above the gameplay layer (doesn't disappear behind player/collectibles)
- [ ] **Anchor stability**: Resizing the Godot run window should keep the HUD pinned to top-left (integer scaling should handle this automatically)

## Screenshots

Save screenshots into this directory or paste filenames here:

- `hud-initial-state.png` — SCORE 0000 / TIME 0:00 / D 0
- `hud-after-pickups.png` — score advanced, time ticking
- `hud-after-deaths.png` — deaths incremented

## Known Limitations

- **Font is Godot default** (not pixel BMFont yet). Replace with BMFont in Story 011 audio/asset pass if crispness is unsatisfactory at 10px.
- **Death symbol is `D` not `✗`** — Godot's default font may not render the `✗` glyph. Swap to `✗` after BMFont arrives.
- **Label positions are best-guess within 128×24 strip** — may need visual tuning (adjust in `hud.gd` `_build_ui()`).

## Verdict

- [ ] **PASS** — HUD matches spec, ready for integration
- [ ] **PASS with notes** — functional but needs tuning (describe in Notes)
- [ ] **FAIL** — significant issue (describe in Notes)

## Notes

[Tester fills in. Any tuning changes, surprising behavior, visual issues.]

## Sign-off

- Solo mode = self sign-off. Write verbatim "looks right" or "needs fix: [description]" here.
- Signed: _____ on _____
