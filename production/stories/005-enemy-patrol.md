# Story 005: Enemy Patrol

> **Status**: Done (6/6 tests pass, 2026-04-23)
> **Type**: Logic
> **Estimated**: 2h
> **Depends on**: 002
> **Unlocks**: 009

## Goal

Implement a single shared enemy type for MVP: horizontal patroller that walks
back and forth along a configurable range. Touching the enemy from any
direction emits a `player_hit` signal (caught by Game State in Story 007 →
restart). The three concept-stated enemy types (broom owner, stray dog,
tourist) share this single logic — they differ only in sprite later. For MVP,
one rectangle logic, reusable.

## References
- `design/gdd/game-concept.md` § MVP scope "Enemies", § Win/Lose Conditions
- `design/art/art-bible.md` §3A — Pole Rule (enemy silhouette axis differentiation — deferred to art pass)
- `design/art/art-bible.md` §4A — enemies use hazard tint `#D94F2B` (no independent color per art-bible locked decision)
- `prototypes/night-market-runner/enemy.gd` — reference
- `prototypes/night-market-runner/web-prototype.html` § updateEnemies — reference

## Acceptance Criteria

- [ ] Enemy is a `Node2D` at `src/scripts/enemy.gd`, scene at `src/scenes/enemy.tscn`
  - (Not `CharacterBody2D` — we don't need physics collision with walls; patrol is on flat ground and uses simple clamped x-axis motion per prototype. Avoids the Node2D vs. CharacterBody2D collision-block bug hit in prototype.)
- [ ] Child: `Area2D` with 40×24 collision rect for hit detection
- [ ] Visual: neutral body color (`#7A3A2A` per prototype — dark sienna) at 40×24 + 1–2px hazard tint (`#D94F2B`) on TOP edge
- [ ] Patrol params (all `@export` so level designer tunes per placement):
  - [ ] `patrol_speed = 45.0` px/s
  - [ ] `patrol_range = 60.0` px (distance from origin_x to either side)
- [ ] On `_ready()`, captures `origin_x = position.x`
- [ ] In `_process(delta)`: x advances by `patrol_speed * direction * delta`; when x exceeds `origin_x ± patrol_range`, direction flips and x clamps to boundary (prevents overshoot drift)
- [ ] Emits `player_hit` signal when a body entering the Area2D `is Player`
- [ ] Position snaps to integer pixels each frame (avoid sub-pixel drift per art-bible §8L)
- [ ] Enemy does NOT collide with walls, collectibles, obstacles, or other enemies — patrol is on a well-defined ground line; the Node2D + Area2D separation is deliberate (Godot prototype bug: using CharacterBody2D for enemy blocked player movement and prevented Area2D firing)

## Implementation Notes

- The "no wall collision" choice means level designer is responsible for placing patrol_range such that enemy doesn't walk into scenery. That's acceptable for hand-placed content at weekend scope.
- Area2D `body_entered` signal fires when player's CharacterBody2D enters the area. Default collision layers (all layer 1) work.
- Single enemy script handles all three enemy types per concept doc. Art pass later swaps the ColorRect for three different sprites (broom owner = horizontal-wide T-silhouette, dog = horizontal-low, tourist = top-heavy), per art-bible §3A Pole Rule. Logic is identical.
- Speed 45 px/s < player speed 110 px/s, so player can always outrun an enemy head-on. This is intentional for the "dodge" feel — enemy is a static-ish obstacle from the player's point of view.

## Out of Scope

- Three distinguishable enemy sprites → post-MVP art pass
- Vertical-walking / jumping enemies → post-MVP
- Enemy death (player can't kill enemies per game-concept) → N/A
- Level placement of enemies → Story 009
- Hit SFX / reaction animations → Story 011

## Test Evidence (Logic)

- [ ] Automated unit test `tests/unit/enemy/enemy_patrol_test.gd`:
  - [ ] After 1 second at 45 px/s moving right from origin_x=0 with patrol_range=60, x = 45
  - [ ] After reaching origin_x + patrol_range, direction flips to -1
  - [ ] After flipping at +60, next frame moves toward -60 (i.e., x decreases)
  - [ ] `player_hit` signal emits when a Player body enters the Area2D
  - [ ] `player_hit` does NOT emit when a non-Player body (e.g., generic Node2D) enters
  - [ ] Patrol respects clamping — x never exceeds `origin_x ± patrol_range` after a frame
