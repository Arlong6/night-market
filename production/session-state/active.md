# Active Session State

> **Last Updated**: 2026-06-27 (session: pivoted to new game 橫衝直撞 / Road Rage)
> **Purpose**: Living checkpoint. Read this first after compaction or new session.

## Current build: 橫衝直撞 (Road Rage) — top-down vehicle destruction sandbox

User's direction: "想做無腦破壞的遊戲 … 勁量去突破極限". Chose **vehicle rampage** (top-down GTA-flavored mindless destruction). New standalone project `road-rage/`.

- **Spec**: `docs/superpowers/specs/2026-06-27-road-rage-design.md`
- **Plan**: `docs/superpowers/plans/2026-06-27-road-rage.md` (16 tasks, 6 phases, TDD)

### Progress (inline execution, verified on Godot 4.6.2)

| Phase | Tasks | Status |
|---|---|---|
| 0 Scaffold | 1–2 | ✅ project + GUT + CJK theme + RRTuning |
| 1 Driving | 3–4 | ✅ RRPhysics (TDD) + drivable arcade car + camera + title |
| 2 Destruction | 5–7 | ✅ FX debris/particles + RRAudio (TDD) + Destructible (impact→break→debris+audio+shake) |
| 3 Combo/Score/HUD | 8–10 | ⏳ next |
| 4 City | 11–12 | ⏳ |
| 5 Wanted/Police | 13–14 | ⏳ |
| 6 Juice | 15–16 | ⏳ |

**Tests: 8/8 green** (smoke, RRPhysics×4, RRAudio×3). Both scenes boot clean headless.
**Playable now**: drive a heavy car, smash scattered props/cars/peds → debris + impact/explosion audio + screenshake. (combo/score/city/police/juice not yet wired.)

### How to playtest (feel needs a real run)
```
~/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot --path road-rage
```
WASD/arrows to drive. **Validate: does the car feel heavy/satisfying? does smashing feel good?** Tuning knobs in `road-rage/scripts/rr_tuning.gd` (ACCEL, TURN_RATE, FRICTION, MAX_SPEED, break thresholds).

### Next (resume here)
Phase 3: ComboSystem (TDD) → ScoreSystem (TDD) → HUD wired into main.gd. Then city (CityGen TDD), wanted/police, juice pass. Follow the plan task-by-task; each pure-logic unit is TDD, each phase ends with a green suite + clean boot + commit.

## Other games (paused, intact)
- **Night Market (夜市)** — boot game in `src/`, ship-prep done (v0.59), 553 tests green. Remaining: user playtest balance + web build + screenshots + itch.
- **word-suika (一字一句)** — juiced + title screen. Standalone.
- **Lexicon Village** — shelved; core loop needs rebuild next cycle.

## Solo Mode
`production/review-mode.txt` = `solo`. Director gates auto-skipped.
