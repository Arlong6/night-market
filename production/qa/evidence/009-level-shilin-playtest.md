# Level Shilin Playtest Evidence — Story 009

**Story**: `production/stories/009-level-shilin.md`
**Type**: Integration (structural + playthrough)
**Date**: [fill in when tested]
**Tester**: Solo mode self-test

## Setup

1. Open Godot 4.6 project at `src/`
2. In Project Settings → Application → Run, confirm main scene is `res://scenes/main.tscn`
   (or temporarily set it to `res://scenes/levels/level_shilin.tscn` for direct testing)
3. Press F5 (or run headless CI)

## Automated Test Gate

Run before playtesting. All 6 must pass before manual verification begins.

```
cd src
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/integration/levels -ginclude_subdirs -gexit
```

- [ ] `test_level_shilin_instantiates_without_errors` — PASS
- [ ] `test_level_shilin_has_required_children` — PASS
- [ ] `test_level_shilin_has_expected_entity_counts` — PASS
- [ ] `test_level_shilin_collectible_signals_wired_to_game_score` — PASS
- [ ] `test_level_shilin_enemy_hit_triggers_death_record` — PASS
- [ ] `test_level_shilin_player_lands_on_floor` — PASS

## Acceptance Criteria Checks

### Scene Structure
- [ ] Scene loads without console errors (F5, check Output panel)
- [ ] Player spawns at far-left of level, camera starts at left-clamped position
- [ ] HUD visible in top-left corner (0000 / 0:00 / D 0 at start)
- [ ] Floor visible as char-smoke brown `#4A2010` strip at bottom of viewport

### Gameplay — Full Run
Walk/jump from start to goal and verify each element:

- [ ] **Player movement**: runs right, jumps, ducks — all feel correct
- [ ] **Platform 1** (x≈180, y≈100): Player can jump onto it
- [ ] **Platform 2** (x≈360, y≈80): Player can jump onto it (higher jump needed)
- [ ] **Platform 3** (x≈560, y≈96): Player can jump onto it
- [ ] **Platform 4** (x≈740, y≈84): Player can jump onto it
- [ ] **Ground obstacle 1** (x≈260): Player must jump over; ground contact blocks
- [ ] **Ground obstacle 2** (x≈460): same
- [ ] **Ground obstacle 3** (x≈680): same
- [ ] **Hanging sign 1** (x≈320): Standing player blocked; ducking player passes
- [ ] **Hanging sign 2** (x≈850): same
- [ ] **Enemy 1** (x≈400): patrols; touching player increments deaths + restarts level
- [ ] **Enemy 2** (x≈700): same
- [ ] **Collectibles**: 6 present; each pickup increments HUD score by 100
- [ ] **Goal zone** (x≈944): Entering awards +500 score + restarts level

### Performance
- [ ] **60fps**: Godot Monitor shows ≥60fps throughout
- [ ] **No frame spikes**: No visible stutters
- [ ] **Browser test** (optional): Export HTML5, confirm 60fps in-browser

### Console
- [ ] **Zero errors** in Godot Output panel during full run (warnings OK, errors not)

## Known MVP Limitations

- No parallax background — solid clear color is the atmosphere
- No sprite assets — all entities are ColorRects / `_draw()` shapes
- Goal loops level (restart) — Story 010 will intercept for next-level flow
- No background music — Story 011
- No level-end screen — Story 010
- TileMapLayer not used — floor/platforms are StaticBody2D rects

## Verdict

- [ ] **PASS** — Level runs start-to-finish at 60fps, no errors, all criteria met
- [ ] **PASS with notes** — Functional but needs tuning (describe below)
- [ ] **FAIL** — Significant issue (describe below)

## Notes

[Tester fills in.]

## Sign-off

- Solo mode = self sign-off. Write "playable" or "needs fix: [description]" here.
- Signed: _____ on _____
