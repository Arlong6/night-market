# Active Session State

> **Last Updated**: 2026-06-28 (Road Rage v1 vertical slice COMPLETE)
> **Purpose**: Living checkpoint. Read this first after compaction or new session.

## Current build: 橫衝直撞 (Road Rage) — top-down vehicle destruction sandbox

User direction: "想做無腦破壞的遊戲 … 勁量去突破極限". Standalone project `road-rage/`.
- **Spec**: `docs/superpowers/specs/2026-06-27-road-rage-design.md`
- **Plan**: `docs/superpowers/plans/2026-06-27-road-rage.md`

### Progress — v1 vertical slice COMPLETE (all 6 phases, verified on Godot 4.6.2)

| Phase | Tasks | Status |
|---|---|---|
| 0 Scaffold | 1–2 | ✅ project + GUT + CJK theme + RRTuning |
| 1 Driving | 3–4 | ✅ RRPhysics (TDD) + arcade car + camera + title |
| 2 Destruction | 5–7 | ✅ FX debris/particles + RRAudio (TDD) + Destructible (impact→break) |
| 3 Combo/Score/HUD | 8–10 | ✅ ComboSystem + ScoreSystem (TDD) + HUD |
| 4 City | 11–12 | ✅ CityGen (TDD determinism) + buildings/roads/props render |
| 5 Wanted/Police | 13–14 | ✅ WantedSystem (TDD) + police chase/ram + game-over/restart |
| 6 Juice | 15–16 | ✅ score popups + hit-stop + milestone slow-mo + title best-score |

**Tests: 23/23 green** (RRPhysics×4, RRAudio×3, Combo×4, Score×3, City×4, Wanted×4, smoke). Title + main boot clean headless.

**Full v1 loop playable**: title → drive a heavy car through a procedural city → smash props/cars/peds (debris + audio + shake + popups) → combo multiplier → wanted ★ rises with heat → police spawn & chase & ram → vehicle wrecked → score + new-best → restart.

### How to run
```
~/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot --path road-rage
```
Tuning knobs: `road-rage/scripts/rr_tuning.gd` (driving feel, break thresholds, heat/star curve, police, combo, score, city density).

### Next candidates (post-v1, from spec "Later")
Vehicle upgrades / nitro pickups · army tier (helicopter/tank) · chain-reaction gas stations · engine-note audio tracking speed · escalating music by wanted level · web export (export_presets + HTML5) · balance/feel tuning from user playtest.

## Other games (paused, intact)
- **Night Market (夜市)** — boot game in `src/`, ship-prep done (v0.59), 553 tests green. Remaining: user playtest balance + web build + screenshots + itch.
- **word-suika (一字一句)** — juiced + title screen.
- **Lexicon Village** — shelved; core loop needs rebuild.

## Solo Mode
`production/review-mode.txt` = `solo`. Director gates auto-skipped.
