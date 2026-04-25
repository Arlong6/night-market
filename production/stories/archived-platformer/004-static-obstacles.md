# Story 004: Static Obstacles (ground + hanging)

> **Status**: Done (5/5 tests pass, 2026-04-23)
> **Type**: Integration
> **Estimated**: 3h
> **Depends on**: 002
> **Unlocks**: 009

## Goal

Implement the two obstacle classes the player must navigate around:
**ground obstacles** (scooter / trash bag / crate — jump over) and
**hanging hazards** (low sign — duck under). Both are `StaticBody2D` walls
that block player movement; colliding with the hazard-tint edge in a way
that can't be cleared = player dies (but player only dies on ENEMY contact;
obstacles merely block — hazard tint is just visual communication).

Clarification: in scope for this story, touching an obstacle does NOT kill
the player — it just blocks. Enemies (Story 005) kill. Obstacles are there
to force jumping or ducking, not to punish. This matches the game-concept
core loop ("jump over obstacles" = routing, not death).

## References
- `design/gdd/game-concept.md` § MVP scope "Obstacles" sub-list
- `design/art/art-bible.md` §3C — Environment Geometry (angular = hazard safety grammar)
- `design/art/art-bible.md` §3C — Hanging hazard obstacles spec (added 2026-04-22)
- `design/art/art-bible.md` §4A — hazard tint `#D94F2B`
- `design/art/art-bible.md` §8A — obstacle canvas 32×32 (ground), ~40×22 (hanging)
- `prototypes/night-market-runner/web-prototype.html` § drawSolid — reference

## Acceptance Criteria

**Ground obstacle (jump-over class)**:
- [ ] `src/scripts/obstacle_ground.gd` + `src/scenes/obstacle_ground.tscn`
- [ ] `StaticBody2D` with 24×24 or 32×32 collision (configurable via @export)
- [ ] Visual: gray body (`#555555` or similar) + 1–2px hazard tint (`#D94F2B`) on TOP edge (the side player would hit if undercooking a jump)
- [ ] Physically blocks player movement in all directions (it's a solid wall)
- [ ] Placed on ground plane; bottom of obstacle sits on ground top

**Hanging hazard (duck-under class)**:
- [ ] `src/scripts/obstacle_hanging.gd` + `src/scenes/obstacle_hanging.tscn`
- [ ] `StaticBody2D` with ~40×22 collision (configurable via @export)
- [ ] Visual: old-gold body (`#D4920A`) + 1–2px hazard tint (`#D94F2B`) on BOTTOM edge (the head-bump contact side) + two 1px ink-black ropes drawn from y=0 (top of viewport / awning) down to the hanging sign top
- [ ] Physically blocks standing player (height 40); clears ducking player (height 20)
- [ ] Positioned with top edge at world y≈115 (absolute; level designer can override)
- [ ] The ropes are visual-only — they are NOT colliders

**Shared**:
- [ ] Both obstacles snap to integer pixel positions (art-bible §8L)
- [ ] Both emit no signals on contact — they are passive walls

## Implementation Notes

- Do NOT make these `CharacterBody2D` — they never move. `StaticBody2D` is correct.
- Rope visuals can be drawn as `ColorRect` children of the hanging obstacle, stretching from y = -(world_y_of_obstacle_top) up to y = 0 (scene origin). Simpler: draw via `_draw()` using `draw_line()` for cleaner integer-pixel lines.
- Hazard tint edge is visual only — it has no separate collider. The tint color communicates "this side hurts" (per art-bible §3C safety grammar: hard corner = danger) but the collision is just the body AABB.
- Collision layer: both on layer 1. Masks: standard 1 (player will collide).
- No hazard kill logic here — Story 005 handles enemy kill; obstacles only block.

## Out of Scope

- Enemy (moving hazard) → Story 005
- Level layout placing these obstacles → Story 009
- Animated obstacles (swaying ropes, flickering sign lights) → post-MVP juice pass
- Variation sprites per market → post-MVP art pass

## Test Evidence (Integration)

- [ ] Integration test `tests/integration/obstacles/obstacle_collision_test.gd`:
  - [ ] Player moving right into ground obstacle → stops at obstacle's left edge, velocity.x zeroed
  - [ ] Player jumping with JUMP_VELOCITY = -250 clears a 24h ground obstacle (produces ≥2px vertical margin over its top at apex)
  - [ ] Player standing (height 40) walking into hanging obstacle → blocked
  - [ ] Player ducking (height 20) walking under hanging obstacle at y=115 → passes freely
  - [ ] Player ducking then entering under hanging obstacle and releasing duck key → auto-stand FAILS; player remains ducked until clear
- [ ] Manual test (doc in `production/qa/evidence/004-obstacles-evidence.md`): visually verify the hazard tint edge appears on the correct side (top for ground, bottom for hanging) and rope lines render correctly
