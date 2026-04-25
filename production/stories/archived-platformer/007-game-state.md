# Story 007: Game State Singleton

> **Status**: Done (7/7 tests pass, 2026-04-23)
> **Type**: Logic
> **Estimated**: 2h
> **Depends on**: 001
> **Unlocks**: 008, 010

## Goal

Autoload singleton that tracks score, deaths, current level, and session
elapsed time. Listens to signals from collectible pickups and enemy hits.
Exposes a `restart_level()` method that reloads the current scene and
resets per-level state. Deaths and score persist across restarts within
a session (so player can see their running total).

## References
- `design/gdd/game-concept.md` § Win/Lose Conditions, § Score system
- `prototypes/night-market-runner/main.gd` § state variables, `_restart()` — reference logic

## Acceptance Criteria

- [ ] Autoload name: `Game` (accessible globally as `Game.score`, `Game.deaths`, etc.)
- [ ] Script: `src/autoloads/game.gd`
- [ ] Registered in `project.godot` under `[autoload]` (Story 001 created directory; this story wires it in)
- [ ] State:
  - [ ] `score: int = 0` — total points this session
  - [ ] `deaths: int = 0` — total deaths this session
  - [ ] `current_level: String = "shilin"` — slug of the current level scene
  - [ ] `level_scene_paths: Dictionary` — maps slug → resource path (e.g., `"shilin" → "res://src/scenes/levels/level_shilin.tscn"`)
  - [ ] `session_time: float = 0.0` — accumulated time played (for level-end bonus calc)
- [ ] Signals:
  - [ ] `score_changed(new_score: int)` — emitted when score changes
  - [ ] `deaths_changed(new_deaths: int)` — emitted when deaths changes
  - [ ] `level_changed(new_level: String)` — emitted when current_level changes
- [ ] Methods:
  - [ ] `add_score(points: int)` → increments, emits `score_changed`
  - [ ] `record_death()` → increments deaths, emits `deaths_changed`, then calls `restart_level()`
  - [ ] `restart_level()` → reloads the current scene via `get_tree().reload_current_scene()`; does NOT reset score or deaths
  - [ ] `goto_level(slug: String)` → loads `level_scene_paths[slug]` via `get_tree().change_scene_to_file()`, updates `current_level`, emits `level_changed`
  - [ ] `reset_run()` → zeros score, deaths, session_time (called when player returns to title / starts fresh run)
- [ ] Score and deaths ARE preserved across `restart_level()` calls (running tally)
- [ ] Score and deaths ARE NOT preserved across `goto_level()` — each level fresh or → decide: spec says PRESERVE across levels within the same run so the final total represents the whole session. Confirm and implement: **PRESERVE across goto_level within a session.** Only `reset_run()` zeros them.
- [ ] `_process(delta)` accumulates `session_time += delta`

## Implementation Notes

- Singleton pattern: define as Autoload, not as static class — Godot 4 idiom prefers Autoload Node
- Listen to child signals via code in individual scenes (not here) — Game singleton is the destination, not the subscriber. Collectibles in the level call `Game.add_score(points)`; enemies call `Game.record_death()`. This keeps Game decoupled from scene structure.
- `level_scene_paths` can be a const `Dictionary` at top of script — three entries for MVP (shilin, fengjia, liouho); fengjia and liouho point to empty placeholder scenes or `null` until Story 009 content exists.
- Consider adding `best_score_per_level` as a `Dictionary` for future high-score display — noted as post-MVP.

## Out of Scope

- High-score persistence to disk (FileAccess / IndexedDB for HTML5) — post-MVP
- Multiple save slots → N/A (concept says "no save system for MVP")
- Level unlocking progression (finishing level 1 unlocks 2) → handled in Story 010 (menus) reading Game state
- Settings / audio volume → post-MVP (when audio is added in Story 011)

## Test Evidence (Logic)

- [ ] Automated unit test `tests/unit/game_state/game_state_test.gd`:
  - [ ] `add_score(100)` increments score by 100 and emits `score_changed(100)`
  - [ ] `record_death()` increments deaths and emits `deaths_changed`
  - [ ] `restart_level()` does not reset score or deaths
  - [ ] `reset_run()` zeros score, deaths, session_time
  - [ ] `goto_level("shilin")` updates `current_level`
  - [ ] Invalid `goto_level("invalid_slug")` does NOT crash — emits a warning and leaves state unchanged
  - [ ] `session_time` accumulates across frames (simulate with manual `_process(0.1)` × 5 calls → session_time ≈ 0.5)
