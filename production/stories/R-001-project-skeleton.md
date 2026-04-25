# Story R-001: Project Skeleton

> **Status**: Ready
> **Type**: Config/Data
> **Estimated**: 1h
> **Depends on**: —
> **Unlocks**: R-002, R-005

## Goal

Rebuild `src/` for the top-down RPG. The wipe already happened in the pivot
commit; this story creates `project.godot`, the directory tree, the new input
map, the empty `Game` autoload, and a placeholder title scene that opens
without errors.

## References
- `design/gdd/game-concept-rpg.md` §3 — input requirements, viewport rules
- `.claude/docs/technical-preferences.md` — snake_case files, PascalCase classes
- v0.1-platformer `src/project.godot` (recoverable via `git show v0.1-platformer:src/project.godot`) — steal viewport / render / stretch settings; replace input map

## Acceptance Criteria

- [ ] `src/project.godot` exists with:
  - [ ] Viewport 320×180, stretch mode `viewport`, aspect `keep`, scale mode `integer`
  - [ ] Renderer `gl_compatibility` (default + `.web` override)
  - [ ] `default_texture_filter = 0` (Nearest)
  - [ ] `snap_2d_transforms_to_pixel = true`, `snap_2d_vertices_to_pixel = true`
  - [ ] Window override 1280×720
  - [ ] `default_clear_color` = `#1A0A00` (Shilin night tone)
- [ ] Input map (replaces all platformer actions):
  - [ ] `ui_up` / `ui_down` / `ui_left` / `ui_right` — built-in arrows + WASD
  - [ ] `interact` → Space + Z + Enter
  - [ ] `restart` → R
- [ ] Directory tree (empty placeholders OK):
  - [ ] `src/autoloads/` (will hold `game.gd`, `inventory.gd`, `dialogue.gd`)
  - [ ] `src/scenes/` + `src/scenes/menus/` + `src/scenes/levels/`
  - [ ] `src/scripts/` + `src/scripts/menus/` + `src/scripts/levels/`
  - [ ] `src/scripts/fx/` (already populated — particle_burst.gd, flash_overlay.gd)
  - [ ] `src/tests/unit/` + `src/tests/integration/`
- [ ] `src/autoloads/game.gd` — empty Node script (just `class_name Game extends Node`) registered as autoload
- [ ] `src/scenes/menus/title.tscn` — bare Control with one `Label` "夜市採購大作戰"
- [ ] `run/main_scene = res://scenes/menus/title.tscn`
- [ ] Pressing F5 runs the title scene at 1280×720, dark background, label visible, no console errors

## Implementation Notes

- The `ui_up/down/left/right` defaults in Godot 4.6 already cover arrow keys;
  re-bind to also accept WASD via `[input]` overrides.
- `interact` action: include both Space (default jump-style) and Enter (Pokémon
  GBA "A button" feel) and Z (also Pokémon GBA convention).
- `Game` autoload stays minimal — content arrives in R-002+. Just register so
  later stories can extend without touching project.godot again.
- Do NOT include any of the platformer scripts (player.gd, enemy.gd, etc.) —
  they were wiped intentionally.

## Out of Scope

- Player script → R-002
- Inventory autoload → R-005
- Dialogue autoload → R-004
- World content → R-003

## Test Evidence (Config/Data)

- [ ] Smoke check: launch via `Godot --path src res://scenes/menus/title.tscn`,
  verify 1280×720 window opens with `#1A0A00` background and the title label
  visible. No console errors.
- [ ] Record in `production/qa/smoke-2026-04-25-R-001.md`.
