# Night Market Runner — Stories Index

> **Scope**: Weekend project, solo developer, Godot 4.6 + GDScript + Web HTML5
> **MVP**: Stories 001–011 (Shilin playable + menus + audio)
> **Post-MVP**: Level 2 (Fengjia) + Level 3 (Liouho) content — added after Shilin is validated

## Status Legend
`Ready` = can be picked up · `In Progress` = being worked on · `Blocked` = waiting on dependency · `Done` = AC satisfied + evidence captured

## Dependency Order
```
001 → 002 → {003, 004, 005} → 006 → 007 → 008 → 009 → 010 → 011
```
Stories 003 / 004 / 005 can be done in parallel once 002 is done.

## Stories

| # | Title | Type | Status | Est. | Depends on |
|---|-------|------|--------|------|------------|
| 001 | Project Skeleton | Config/Data | Done ✓ | 2h | — |
| 002 | Player Controller (run + jump + duck) | Logic | Done ✓ | 4h | 001 |
| 003 | Collectible System | Logic | Done ✓ | 2h | 002 |
| 004 | Static Obstacles (ground + hanging) | Integration | Done ✓ | 3h | 002 |
| 005 | Enemy Patrol | Logic | Done ✓ | 2h | 002 |
| 006 | Camera System | Integration | Done ✓ | 2h | 002 |
| 007 | Game State Singleton | Logic | Done ✓ | 2h | 001 |
| 008 | HUD (receipt-style) | Visual/Feel | Code ✓ (visual defer → 009) | 3h | 007 |
| 009 | Level 1: Shilin (first playable) | Integration | Done ✓ | 4h | 003, 004, 005, 006, 008 |
| 010 | Menus (title / level select / end) | UI | Ready | 3h | 007, 009 |
| 011 | Audio (music + SFX) | Config/Data | Ready | 3h | 009, 010 |

**Total estimate**: 30h (range 22–44h with variance) — realistically 1.5–2 weekends.

## References (every story points to these)
- `design/gdd/game-concept.md` — gameplay rules, controls, scope
- `design/art/art-bible.md` — visual rules, palette, canvas sizes
- `prototypes/night-market-runner/REPORT.md` — physics baseline (locked values)
- `prototypes/night-market-runner/web-prototype.html` — working reference implementation
- `.claude/docs/technical-preferences.md` — naming conventions, engine specialists routing

## Notes on Testing

Logic stories (002, 003, 005, 007) require automated tests in `tests/unit/`.
Integration stories (004, 006, 009) require either integration tests or documented playtest.
Visual/Feel stories (008) require screenshot + lead sign-off in `production/qa/evidence/`.
UI stories (010) require manual walkthrough doc in `production/qa/evidence/`.
Config/Data stories (001, 011) require smoke check pass.

`/dev-story [path]` is the implementation skill. Start with `/dev-story production/stories/001-project-skeleton.md`.
