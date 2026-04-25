# Story R-003: Shilin Market World

> **Status**: Ready
> **Type**: Integration
> **Estimated**: 2h
> **Depends on**: R-002
> **Unlocks**: R-004

## Goal

Build the Shilin Night Market level scene programmatically. Place a floor of
ColorRect tiles, walls around the border, 5 stall positions (still empty —
NPCs come in R-006), a "home" cell where the player spawns, and a 2D walkable
boolean array consulted by the player. A Camera2D follows the player.

## References
- `design/gdd/game-concept-rpg.md` §3, §6 (Dependencies)
- v0.1-platformer `src/scripts/levels/level_shilin.gd:75-272` — programmatic
  scene-build pattern (steal the `_add_static_rect` helper concept)

## Acceptance Criteria

- [ ] `src/scripts/levels/shilin_market.gd` — `class_name ShilinMarket extends Node2D`:
  - [ ] `const GRID_W: int = 20`, `const GRID_H: int = 11`
  - [ ] `var walkable: Array[Array]` — 2D bool array `walkable[y][x]`
  - [ ] `_ready()` orchestration: `_build_walkable_map()`, `_draw_floor_tiles()`, `_spawn_player()`, `_spawn_camera()`
  - [ ] Floor tiles drawn as ColorRect 16×16 in alternating shades (`#3A1A0A` / `#4A2412`) for grid visibility
  - [ ] Walls around the perimeter (cell row 0, row GRID_H-1, col 0, col GRID_W-1) marked unwalkable + drawn in `#2A1408`
  - [ ] Player spawned at `home_cell = Vector2i(2, 9)`; PlayerGrid's `walkable_check` wired to `_is_walkable(cell)`
  - [ ] Camera2D centred on player; `make_current()`; integer pixel snap on its position each frame
  - [ ] 5 reserved cells for stalls flagged unwalkable (positions in `STALL_CELLS` constant — actual NPCs in R-006)
  - [ ] 1 reserved cell for mum (at home tile area; NPC spawned in R-008)
- [ ] `src/scenes/levels/shilin_market.tscn` — minimal wrapper of the script

## Implementation Notes

- Define `_is_walkable(cell)` as a method on the level; pass it as a `Callable`
  to `PlayerGrid.walkable_check`.
- Use bounds check first: `if not GridWorld.in_bounds(cell, GRID_W, GRID_H): return false`
  then `return walkable[cell.y][cell.x]`.
- For the floor, batch-draw via `_draw()` on the level node (cheaper than
  spawning 220 ColorRects). Single `_draw()` call, loop the 20×11 grid, draw
  one rect per cell. Walls are part of the same draw pass — different colour,
  same shape.
- Camera2D: simplest possible — set `position = player.position` each `_process`
  frame, snap to integer pixels. No clamping for now (single-screen level fits
  exactly in viewport: 20×16=320 = viewport width, 11×16=176 ≈ 180). Actually
  with 11×11=176 height we have 4px play room — fine.

## Tests (Integration)

`src/tests/integration/levels/test_shilin_market.gd` (GUT):

- [ ] `test_market_loads_and_has_player` — instantiate scene, await one frame, assert a PlayerGrid child exists
- [ ] `test_market_walkable_perimeter_is_blocked` — cells in row 0 / row GRID_H-1 / col 0 / col GRID_W-1 all return false
- [ ] `test_market_walkable_centre_is_walkable` — cell (10, 5) returns true
- [ ] `test_market_walkable_stall_cells_blocked` — every cell in `STALL_CELLS` returns false
- [ ] `test_market_player_spawned_on_home_cell` — player's `cell` equals `Vector2i(2, 9)`
- [ ] `test_market_camera_follows_player` — move player one step, advance one frame, assert camera position equals player position (or matches within rounding)

## Out of Scope

- NPCs (chatter and stall) → R-004 / R-006
- Win check (mum NPC) → R-008
- Real tile art (TileMapLayer + sprite tiles) → v0.2
- Multi-screen camera scrolling → not needed for single-screen MVP
