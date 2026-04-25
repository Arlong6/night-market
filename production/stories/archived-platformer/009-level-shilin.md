# Story 009: Level 1 — Shilin (first playable)

> **Status**: Done — 6/6 tests pass + user confirmed level completable 2026-04-23 (visual polish deferred to post-MVP art pass)
> **Type**: Integration
> **Estimated**: 4h
> **Depends on**: 003, 004, 005, 006, 008
> **Unlocks**: 010, 011; Level 2 / Level 3 content (post-MVP)

## Goal

Assemble the first end-to-end playable level using all systems from prior
stories. This is **the** integration test for the game. If this runs
start-to-finish at 60fps in a browser, the production stack is validated
and levels 2 and 3 are content work (not systems work).

## References
- `design/gdd/game-concept.md` § Setting (Shilin), § Core Loop
- `design/art/art-bible.md` §4B — Shilin palette (warm red + gold)
- `design/art/art-bible.md` §1 — Pre-locked per-level palette decision
- `prototypes/night-market-runner/main.gd` § _build_level — reference layout structure
- Stories 002–008 (all dependencies)

## Acceptance Criteria

- [ ] Scene: `src/scenes/levels/level_shilin.tscn` + `src/scripts/levels/level_shilin.gd`
- [ ] Level structure (top-down):
  - [ ] Root: `Node2D`
  - [ ] Child: `ParallaxBackground` containing 3 `ParallaxLayer`s for far/mid/near per art-bible §2 Gameplay mood (speeds 0.15× / 0.4× / 1.0×)
  - [ ] Child: `TileMapLayer` (Godot 4.3+ node — NOT deprecated `TileMap`) for ground and walls
  - [ ] Child: `Node2D` "Obstacles" containing ground + hanging obstacle instances
  - [ ] Child: `Node2D` "Collectibles" containing collectible instances
  - [ ] Child: `Node2D` "Enemies" containing enemy instances
  - [ ] Child: `Area2D` "Goal" with visual + signal to trigger level-end
  - [ ] Child: `Player` instance at spawn point
  - [ ] Child: `GameCamera` instance from Story 006
  - [ ] Child: `Hud` instance from Story 008
- [ ] Level width: 960px (matches prototype); level height: 180px (viewport-equal)
- [ ] Content (Shilin theme — food items reflect Shilin specialties per game-concept):
  - [ ] ~6 collectibles placed strategically (require jumps or route choices): oyster omelette / stinky tofu / large-sausage-in-small / bubble tea (ColorRect placeholders OK; art assets are post-MVP)
  - [ ] 2–3 ground obstacles (jump-over) placed in the run path
  - [ ] 1–2 hanging sign obstacles (duck-under) placed where player must react
  - [ ] 1–2 patrol enemies (one middle, one later)
  - [ ] 1 goal zone at x ≈ 944 (16px from right edge)
- [ ] Parallax layers use Shilin palette colors only (per art-bible §4B):
  - [ ] Far layer: deep night black (`#1A0A00`) background with old-gold (`#D4920A`) sign dots at low density
  - [ ] Mid layer: vendor awning red (`#C94B2C`) stall canopies with sign-face amber (`#F0C060`) accents
  - [ ] Near layer: char-smoke brown (`#4A2010`) alley floor
- [ ] Ground floor tile uses Shilin palette (`#4A2010`) with brick-red (`#8B1A1A`) wall accents
- [ ] On goal reached → emits signal handled by level script → calls `Game.add_score(500)` bonus + loads next level (Fengjia if present, else returns to title)
- [ ] On player death → `Game.record_death()` → scene reloads
- [ ] Level runs at 60fps in browser (Chrome on mid-range laptop per art-bible §8K budget)
- [ ] Level is completable start-to-finish via player-paced movement
- [ ] No console errors during a full run

## Implementation Notes

- The 4 hours is the assembly time — no new systems. Placing ColorRect stand-ins for real sprites is fine; this is content lay-down, not art work.
- Use the Godot editor to place instances and tune positions — DON'T hand-write .tscn files beyond the skeleton. This is where the editor earns its keep.
- Parallax: Godot 4's `Parallax2D` node is the successor to `ParallaxBackground` — check engine-reference docs for which to use in 4.6. Fallback to classic `ParallaxBackground` + `ParallaxLayer` works and is well-documented.
- Goal trigger: simplest is a trigger `Area2D` at the level end that connects `body_entered` to a script that calls `Game.add_score(500)` + `Game.goto_level(next_slug)`. If next level doesn't exist yet, `goto_level` returns to title via `Game.reset_run()` + `goto_level("title")` — or emit a "game complete" signal the Menus scene handles.
- Level width constraint: 960px; camera clamps via Story 006 using the level's `@export var level_width: int = 960`

## Out of Scope

- Level 2 (Fengjia) content — post-MVP clone of this level with Fengjia palette + Fengjia food items + different obstacle placement
- Level 3 (Liouho) content — same, Liouho palette + seafood items
- Tile-based level editor tools — use Godot's built-in TileSet editor only
- Real sprite assets — ColorRect placeholders accepted; art pass after MVP
- Background music for the level — Story 011
- Victory cutscene or celebration — Story 010 handles the end-of-level menu flow

## Test Evidence (Integration)

- [ ] Integration test `tests/integration/levels/level_shilin_completable_test.gd`:
  - [ ] Headless test: spawn level scene, simulate player inputs (move_right held, jump timed), player reaches goal → Game.score >= 600 (500 bonus + at least 1 collectible)
- [ ] Playtest evidence doc `production/qa/evidence/009-level-shilin-playtest.md`:
  - [ ] Date + build hash + tester name (you)
  - [ ] Completed full run without dying — time and score
  - [ ] Completed full run dying once then recovering — time, deaths, score
  - [ ] FPS monitor screenshot confirming 60fps sustained in Chrome on target hardware
  - [ ] Any feel issues discovered (e.g., obstacle placement too hard → note for tuning pass)
