# Story R-002: Grid-Snap Player Controller

> **Status**: Ready
> **Type**: Logic
> **Estimated**: 2h
> **Depends on**: R-001
> **Unlocks**: R-003

## Goal

A 4-direction grid-snap player. Pressing a direction key moves the visual
position from the current cell to the adjacent cell over 180ms via Tween.
Holding the key keeps stepping. Bumping a wall cancels movement but changes
facing direction. The walkability check is delegated to the level via a
`Callable` so the player class itself owns no map data.

## References
- `design/gdd/game-concept-rpg.md` §3 (Movement), §4 (Formulas), §8 (AC)
- `.claude/docs/technical-preferences.md` — static typing required
- v0.1-platformer `src/scripts/player.gd:74-100` — edge-detected input pattern
  (use the same `_was_*_pressed` technique; `is_action_just_pressed` is unreliable
  in headless tests)

## Acceptance Criteria

- [ ] `src/scripts/grid_world.gd` — `class_name GridWorld extends RefCounted`:
  - [ ] `const TILE_SIZE: int = 16`
  - [ ] `static func cell_to_px(cell: Vector2i) -> Vector2`
  - [ ] `static func px_to_cell(px: Vector2) -> Vector2i`
  - [ ] `static func in_bounds(cell: Vector2i, grid_w: int, grid_h: int) -> bool`
- [ ] `src/scripts/player_grid.gd` — `class_name PlayerGrid extends Node2D`:
  - [ ] Exports: `walkable_check: Callable` (returns bool given target cell), `start_cell: Vector2i`
  - [ ] Constants: `STEP_DURATION = 0.18`
  - [ ] State: `cell: Vector2i`, `facing: Vector2i`, `is_stepping: bool`
  - [ ] In `_process`: read held direction (last-pressed wins on ties), if not stepping AND not in dialogue, attempt step
  - [ ] Step: query `walkable_check.call(target_cell)`. If true → tween position over STEP_DURATION + flip `is_stepping`. If false → only update `facing`.
  - [ ] Tween completion: `is_stepping = false`
  - [ ] Movement is gated on `Game.in_dialogue == false` (will be wired in R-004; until then, default false)
  - [ ] `_draw()` placeholder: 14×14 yellow square centred on cell (matches platformer kid's body colour `#E8F542`)
  - [ ] Signal: `cell_changed(new_cell: Vector2i)` — emitted on tween completion

## Implementation Notes

- Use `Input.is_action_pressed("ui_*")` + frame-snapshot edge detection (NOT
  `is_action_just_pressed` — same gotcha as platformer).
- "Last-pressed wins on ties": track which direction key became pressed most
  recently this frame using a tiny ordered list of currently-pressed directions.
- Do NOT use CharacterBody2D / move_and_slide — pure Node2D + manual tween.
  Confirmed in the plan: hand-rolled grid means no physics body.
- The `walkable_check: Callable` keeps `PlayerGrid` decoupled from the level.
  The level (R-003) will pass a closure like `func(cell): return walkable_array[cell.y][cell.x]`.
- `cell_changed` signal lets the level run an "on-cell-enter" hook (e.g., for
  trigger zones in future stories).

## Tests (BLOCKING — Logic story)

`src/tests/unit/player/test_player_grid.gd` (GUT):

- [ ] `test_grid_world_cell_to_px_returns_centred_pixel` — `cell_to_px(Vector2i(2, 3))` returns `Vector2(40, 56)` (cell origin = top-left, return cell-centre = cell*16 + 8)
- [ ] `test_grid_world_px_to_cell_inverse_of_cell_to_px` — round-trip through both functions returns input
- [ ] `test_grid_world_in_bounds_inside_returns_true` — `(0,0)` and `(grid_w-1, grid_h-1)` both true
- [ ] `test_grid_world_in_bounds_outside_returns_false` — `(-1, 0)`, `(0, -1)`, `(grid_w, 0)`, `(0, grid_h)` all false
- [ ] `test_player_press_right_moves_one_cell_right` — spawn at (5,5), inject all-walkable callback, simulate `ui_right` press for one step duration, assert `cell == (6,5)`
- [ ] `test_player_blocked_target_stays_in_place` — spawn at (5,5), inject callback that returns false, simulate `ui_right` press, assert `cell == (5,5)` AND `facing == Vector2i.RIGHT`
- [ ] `test_player_releases_input_mid_step_completes_then_stops` — press `ui_down`, release before tween done, assert ends 1 cell down and not stepping further
- [ ] `test_player_held_input_continues_stepping` — press `ui_left`, hold for 2× STEP_DURATION, assert `cell.x` decreased by 2

## Out of Scope

- Real walkable map (R-003)
- NPC dialogue lock (R-004)
- Walk-animation (deferred to v0.2)
