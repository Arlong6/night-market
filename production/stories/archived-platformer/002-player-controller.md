# Story 002: Player Controller (run + jump + duck)

> **Status**: Done (12/12 tests pass, 2026-04-23)
> **Type**: Logic
> **Estimated**: 4h
> **Depends on**: 001
> **Unlocks**: 003, 004, 005, 006

## Goal

Implement the player `CharacterBody2D` with run, jump, and duck matching the
prototype physics baseline EXACTLY. Numbers are locked — do not re-tune.

## References
- `design/gdd/game-concept.md` § Controls, § Core Loop
- `design/art/art-bible.md` §3A — Pole Rule + duck-state exception
- `design/art/art-bible.md` §4A — player accent `#E8F542`
- `design/art/art-bible.md` §8A — player canvas 24×40 (duck 24×20)
- `design/art/art-bible.md` §8L — pixel snap + position rounding
- `prototypes/night-market-runner/REPORT.md` § Production physics baseline
- `prototypes/night-market-runner/player.gd` — reference logic (Godot version; steal algorithm, rewrite for production)
- `prototypes/night-market-runner/web-prototype.html` § updatePlayer — reference logic (web version)

## Acceptance Criteria

- [ ] Player is `CharacterBody2D` at `src/scripts/player.gd`, scene at `src/scenes/player.tscn`
- [ ] Physics constants (exact values, `@export` or `const`):
  - [ ] `MOVE_SPEED = 110.0` px/s
  - [ ] `JUMP_VELOCITY = -250.0` px/s
  - [ ] `GRAVITY = 800.0` px/s²
  - [ ] `JUMP_CUT_MULT = 0.5`
  - [ ] `COYOTE_TIME = 0.10` s
  - [ ] `JUMP_BUFFER = 0.10` s
  - [ ] `DUCK_MOVE_MULT = 0.6`
  - [ ] `STAND_H = 40`, `DUCK_H = 20`
- [ ] Horizontal movement: `move_left` / `move_right` actions, symmetric
- [ ] Jump: `jump` action, applies `JUMP_VELOCITY` on ground (or within coyote window)
- [ ] Jump-cut: releasing `jump` while `velocity.y < 0` multiplies `velocity.y` by `JUMP_CUT_MULT`
- [ ] Coyote time: jumping within 100ms after leaving ground still works
- [ ] Jump buffer: pressing `jump` up to 100ms before landing queues the jump
- [ ] Duck (on ground): `duck` held → collision shape height 40 → 20, feet position preserved (sprite top moves down 20px)
- [ ] Duck auto-stand: `duck` released → expand to 40 IF space above is clear (AABB check); if not clear, remain ducked
- [ ] Duck restrictions: cannot duck while airborne; cannot jump while ducking
- [ ] Duck movement: horizontal speed × `DUCK_MOVE_MULT` (60% of stand speed)
- [ ] Position snaps to integer pixels in `_physics_process` final step (avoid sub-pixel "swimming")
- [ ] Player emits `died` signal when `position.y > 240` (fell off world)
- [ ] Visual: ColorRect `#E8F542` at 24×40 (or 24×20 ducking) + 2×6px ink-black (`#2A1A0A`) straw spike on top, spike shrinks to 2×3px when ducking

## Implementation Notes

- Use `move_and_slide()` + gravity accumulation pattern (standard Godot 4 CharacterBody2D idiom)
- Collision shape swap (40 ↔ 20) must adjust the shape's `position.y` offset so the bottom (feet) stays at the same world y
- Auto-stand collision test: temporarily resize shape + move node up, run `test_move(Transform2D.IDENTITY, Vector2.ZERO)` or manual AABB check against nearby `StaticBody2D`s. If collides, revert
- Avoid `Thread` — HTML5 threading is unreliable per art-bible §8I knowledge gap
- Input actions are defined in Story 001 — do NOT use hardcoded `KEY_*` checks
- Pixel snap: `position = position.round()` at end of `_physics_process`; confirm `snap_2d_transforms_to_pixel` is set in project.godot from Story 001

## Out of Scope

- Collectible detection → Story 003
- Hitting obstacles / hazards → Story 004, 005
- Camera following player → Story 006
- Animation frames (run cycle, jump poses) → post-MVP; use single ColorRect for now
- Sound effects on jump/duck → Story 011

## Test Evidence (Logic)

- [ ] Automated unit test: `tests/unit/player/player_movement_test.gd` covering:
  - [ ] Jump velocity applied correctly on ground press
  - [ ] Jump-cut reduces velocity.y on release while rising
  - [ ] Coyote timer decrements when airborne, resets on ground
  - [ ] Jump buffer queues jump across frame boundary
  - [ ] Duck reduces height and preserves feet y
  - [ ] Auto-stand only succeeds when space is clear
  - [ ] Ducking prevents jump input
- [ ] Test framework: gdUnit4 (install as addon) OR GUT — pick one and document in `.claude/docs/technical-preferences.md` Testing section
