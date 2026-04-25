# Story 003: Collectible System

> **Status**: Done (7/7 tests pass, 2026-04-23)
> **Type**: Logic
> **Estimated**: 2h
> **Depends on**: 002
> **Unlocks**: 009

## Goal

Implement food-item collectibles as `Area2D` pickups with the float/bob animation
locked in art-bible §3B. Picking one up emits a signal with point value; the
node frees itself.

## References
- `design/gdd/game-concept.md` § Core Loop step 3
- `design/art/art-bible.md` §3B — Collectible Shape Grammar (container + spike + bob)
- `design/art/art-bible.md` §4A — `#F2A227` lantern-amber glow
- `design/art/art-bible.md` §8A — collectible canvas 20×24
- `prototypes/night-market-runner/collectible.gd` — reference

## Acceptance Criteria

- [ ] Collectible is `Area2D` at `src/scripts/collectible.gd`, scene at `src/scenes/collectible.tscn`
- [ ] Collision shape 20×24 matching canvas
- [ ] Visual: ColorRect `#F2A227` at 20×24 + 2×4 `#2A1A0A` container spike on top (art-bible §3B universal rule: every collectible has a container, and food sprites include the container)
- [ ] **Float + bob**: position.y oscillates 2px vertically on a 2-frame cycle (0.25s per phase); base y is the spawn position
- [ ] Emits `picked_up(points: int)` signal when a `CharacterBody2D` body enters the area
- [ ] Default point value: `100` (exported as `@export var points: int = 100` so level designer can override per-item if desired later)
- [ ] After emitting, calls `queue_free()` so the node removes itself
- [ ] Only player can trigger pickup — verify via `body is Player` check (avoid enemy triggering pickups accidentally)
- [ ] Scene exports `base_y` calculation from spawn position; no assumption about world origin

## Implementation Notes

- Bob animation: `sin(Time.get_ticks_msec() * 0.001 * freq)` is fine; OR discrete 2-frame step (matches art-bible §8B "Collectible bob: 2 frames, loop"). Pick discrete step for pixel-art consistency.
- Collision layer/mask: collectible on layer 1, mask includes player's layer (layer 1 by default). Confirm no cross-layer filtering needed.
- `queue_free()` is safe during signal emission — Godot defers to end of frame.
- No particle burst yet — Story 011 (audio pass) or a later juice pass adds burst; for now color disappear is sufficient per prototype playtest verdict.

## Out of Scope

- Score tracking / accumulation → Story 007 (Game State Singleton listens to this signal)
- HUD display of score → Story 008
- Variable food types (different silhouette families per art-bible §3B table) → Story 009 when laying out Shilin (use ColorRect for now; real sprites are art task post-MVP)
- Pickup SFX → Story 011

## Test Evidence (Logic)

- [ ] Automated unit test: `tests/unit/collectible/collectible_test.gd` covering:
  - [ ] `picked_up` signal emits exactly once when player body enters
  - [ ] Signal carries the configured `points` value
  - [ ] Node is queued for deletion after pickup
  - [ ] Enemy body does NOT trigger pickup (only Player)
  - [ ] Bob oscillation: after N frames, y alternates between `base_y` and `base_y - 2`
