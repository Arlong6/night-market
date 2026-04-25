# Story 006: Camera System

> **Status**: Done (5/5 tests pass, 2026-04-23)
> **Type**: Integration
> **Estimated**: 2h
> **Depends on**: 002
> **Unlocks**: 009

## Goal

Implement a player-paced camera (prototype-confirmed direction — auto-scroll
is out). Camera follows player's x, clamped to level boundaries. Pixel-snaps
each frame to prevent sub-pixel jitter per art-bible §8L trap #1.

## References
- `design/gdd/game-concept.md` § Core Loop step 1 (player-paced, resolved 2026-04-22)
- `prototypes/night-market-runner/REPORT.md` § Recommendation (player-paced locked)
- `design/art/art-bible.md` §8L — camera.position.round() pattern
- `prototypes/night-market-runner/main.gd` § updateCamera / _build_camera — reference

## Acceptance Criteria

- [ ] Camera is a `Camera2D` node at `src/scripts/game_camera.gd` + `src/scenes/game_camera.tscn` (scripted Camera2D subclass so logic lives with data)
- [ ] Follows player's world x: `camera.position.x = clamp(player.position.x, VIEWPORT_W/2, level_width - VIEWPORT_W/2)` where `VIEWPORT_W = 320`
- [ ] Vertical position: locked (no vertical camera movement in MVP — ground is flat per Story 004)
- [ ] Camera position rounds to integer pixels each frame (`position = position.round()`)
- [ ] `level_width` is `@export` so each level scene can set it
- [ ] Follows via `_process` (visual, not physics) — runs after player has moved this frame; use `process_priority` or `_physics_process` to ensure ordering if jitter appears
- [ ] No smoothing / damping for MVP — rigid follow (add smoothing later if feel calls for it; prototype didn't)
- [ ] Player starts within the viewport bounds; camera snaps to correct position immediately on scene load (no first-frame lerp artifact)

## Implementation Notes

- `Camera2D.make_current()` call in `_ready()` to ensure this camera is active
- Integer rounding: use `camera.position = Vector2(round(target_x), camera.position.y)` or `position = position.round()`. The per-axis approach is cleaner here since y is fixed.
- If a post-MVP polish pass wants lerp-smoothing, it can use Godot's built-in `Camera2D.position_smoothing_enabled = true` with `position_smoothing_speed = 5.0`. Don't enable for MVP — rigid follow matches prototype where "完美" was reported.
- For clamping: `level_width` must be at least `VIEWPORT_W` (320). Document this as a level design constraint.

## Out of Scope

- Auto-scroll mode — locked out by prototype REPORT (player-paced is the decision)
- Vertical camera movement (for tall levels) — not in scope; MVP levels are horizontal
- Screen shake on enemy hit / death — part of juice pass, post-MVP
- Parallax layers — implemented as part of Story 009 (level scaffolding) as separate Sprite2D nodes with `motion_scale` on a ParallaxBackground, NOT via camera logic

## Test Evidence (Integration)

- [ ] Integration test `tests/integration/camera/camera_follow_test.gd`:
  - [ ] Player at x=200 → camera.position.x = 200 (within bounds)
  - [ ] Player at x=50 (inside left clamp) → camera.position.x = 160 (VIEWPORT_W/2)
  - [ ] Player at x = level_width - 50 (inside right clamp) → camera.position.x = level_width - 160
  - [ ] Camera position is always an integer after `_process`
  - [ ] Moving player by fractional pixel (110 * delta) doesn't cause camera to show fractional position
