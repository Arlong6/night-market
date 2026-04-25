# 夜市採購大作戰 — Stories Index

> **Project**: Night Market Shopping (top-down grid RPG)
> **Scope**: Weekend slice, solo developer, Godot 4.6 + GDScript + Web HTML5
> **MVP**: Stories R-001 → R-009 (single-area shopping demo, no combat)
> **Predecessor**: v0.1-platformer (archived in `archived-platformer/`)

## Status Legend
`Ready` = can be picked up · `In Progress` = being worked on · `Blocked` = waiting on dependency · `Done` = AC satisfied + evidence captured

## Dependency Order
```
R-001 → R-002 → R-003 → R-004 → R-005 → R-006 → R-007 → R-008 → R-009
```
Roughly linear. R-005 (Inventory) can be done in parallel with R-004 (Dialogue) once R-001 is complete, but writing them serially is fine for a solo run.

## Stories

| # | Title | Type | Status | Est. | Depends on |
|---|-------|------|--------|------|------------|
| R-001 | Project Skeleton (rebuild src/, input map, autoloads stub) | Config/Data | Ready | 1h | — |
| R-002 | Grid-snap Player Controller (4-dir, 180ms tween) | Logic | Ready | 2h | R-001 |
| R-003 | Shilin Market World (ColorRect tiles, walkable array, camera) | Integration | Ready | 2h | R-002 |
| R-004 | Dialogue Box + NPC (typewriter, bump-to-talk) | Integration | Ready | 2h | R-003 |
| R-005 | Inventory Autoload (money + ingredient set) | Logic | Ready | 1h | R-001 |
| R-006 | Stall NPCs (buy choice → Inventory.buy + FX) | Integration | Ready | 2h | R-004, R-005 |
| R-007 | HUD (money + N/5 ingredients) | UI | Ready | 1h | R-005 |
| R-008 | Mom NPC + Win Condition (deliver 5 → end scene) | Logic | Ready | 1h | R-005, R-006 |
| R-009 | Title + Restart Flow | UI | Ready | 1h | R-008 |

**Total estimate**: 13h dev = realistic 2–3 day weekend with test+verify cycle.

## References (every story points to these)
- `design/gdd/game-concept-rpg.md` — game rules, formulas, AC, tuning knobs
- `.claude/docs/technical-preferences.md` — naming, engine, testing
- `docs/engine-reference/godot/VERSION.md` — Godot 4.6 API gotchas
- v0.1-platformer code (git tag) for reusable patterns:
  - `src/scripts/fx/particle_burst.gd` — restored verbatim, ready to use
  - `src/scripts/fx/flash_overlay.gd` — restored verbatim, ready to use
  - Programmatic scene-build pattern from `level_shilin.gd`
  - Edge-detected input pattern from `player.gd` (use `Input.is_action_pressed` + `_was_*` snapshots)

## Notes on Testing

Per `coding-standards.md`:
- **Logic** (R-002, R-005, R-008) → BLOCKING unit tests in `src/tests/unit/[system]/`
- **Integration** (R-003, R-004, R-006) → integration tests in `src/tests/integration/` OR documented playtest
- **UI** (R-007, R-009) → manual walkthrough doc in `production/qa/evidence/`
- **Config/Data** (R-001) → smoke check in `production/qa/smoke-YYYY-MM-DD.md`

## Run Commands

```bash
# Headless test run (from src/)
/Users/arlong/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Class cache refresh after adding a new class_name
/Users/arlong/Downloads/Godot.app/Contents/MacOS/Godot --headless --editor --quit

# Manual playtest
/Users/arlong/Downloads/Godot.app/Contents/MacOS/Godot --path src res://scenes/menus/title.tscn
```

`/dev-story production/stories/R-001-project-skeleton.md` to begin.
