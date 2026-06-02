# Active Session State

> **Last Updated**: 2026-06-02 (cleanup + SPIKE 1 cascade shimmer complete)
> **Purpose**: Living checkpoint for the current task. Read this first after compaction or new session.

## Current Task

字典村莊 (Lexicon Village) SPIKE 1 — cascade shimmer real implementation. **DONE.**
Next direction undecided: VS systems / MVP playtest / Night Market revival.

## Status

✅ **CLEANUP (this session)**: removed orphan `src/src/`, empty `assets/`, retired `prototypes/night-market-runner/` (staged).
✅ **SPIKE 1 cascade shimmer (this session)**: real per-glyph wavefront, all formulas, queue/defer/cap/reduced-motion.
✅ **#11 LVDialogueDisplay refactored** to HBoxContainer-of-Labels (per-token Labels — shimmer's animation set).
✅ Full suite: **464/464** (140 lexicon + 324 NM + integration). Previously 438; +26 cascade shimmer tests.

## Files Touched This Session

| File | Purpose |
|---|---|
| `src/lexicon/scripts/lv_dialogue_display.gd` | Refactored: single Label → HBoxContainer-of-Labels; new `get_token_labels()` + `get_lexicon_slot_labels()` API |
| `src/lexicon/scripts/lv_cascade_shimmer.gd` | Replaced placeholder scaffold with real implementation (Formulas 1-4, ACs 1-16) |
| `src/lexicon/scripts/lv_village.gd` | Removed legacy Label injection (dialogue display owns its own TokenBox now) |
| `src/tests/unit/lexicon/test_lv_cascade_shimmer.gd` | NEW — 26 tests covering formulas, state machine, queue, cap, reduced-motion, defer |
| (deleted) `prototypes/night-market-runner/*` | Staged deletion via `git rm` — 9 files |
| (deleted) `src/src/`, `assets/` | Untracked empty dir orphans |

## SPIKE 1 Coverage

### Acceptance Criteria status

| AC | Coverage | Notes |
|---|---|---|
| AC-1 | ✅ test | `vignette_completed → state RIPPLE_ACTIVE` |
| AC-2 | partial | Origin projection coded; visual verification deferred to playtest |
| AC-3 | ✅ test | `t_arrive(near) < t_arrive(far)` |
| AC-4 | ✅ test | Ease-out: `t(100) < t(500)*0.5` |
| AC-5 | ⚠ manual | 3-phase tween coded; per-tick assertion deferred to playtest |
| AC-6 | ✅ test | `is_on_screen()` filter; direct resolve path |
| AC-7 | ✅ test | Second completion queues during active |
| AC-8 | ✅ test | Three completions all accounted for (1 active + 2 queued) |
| AC-9 | ✅ test | `split_animated_vs_direct()` caps at 80, picks nearest |
| AC-10 | ✅ test | `is_instance_valid` guards in `_apply_modulate` |
| AC-11 | ✅ test | `compute_pan()` Formula 4; chime asset stub (game muted-OK per design) |
| AC-12 | ✅ test | `set_reduced_motion(true) → t_arrive == 0` |
| AC-13 | implicit | Audio is no-op for MVP; visual path doesn't depend on audio |
| AC-14 | n/a | Retroactive resolve owned by #11 (history reopen — unchanged) |
| AC-15 | ⚠ playtest | Requires ≥3 first-time testers |
| AC-16 | ✅ test | Notebook-open → defer; close → drain |

### Known limitations (carry to playtest)

- Audio chime: no asset bundled (per AC-13 design — game must work muted). Wire real chime in audio pipeline.
- World→screen projection uses `Camera2D.global_position`; assumes default Camera2D; not battle-tested with custom transforms.
- `_active_tokens` registry split (OQ-2): currently dialogue-only via `get_lexicon_slot_labels()`. Notebook tokens not in shimmer scope.

## Cleanup Summary

Removed/staged:
- `src/src/` (empty untracked orphan)
- `assets/` (empty untracked dir — NM/lexicon both draw procedurally, font is in `src/assets/fonts/`)
- `prototypes/night-market-runner/` (superseded by NM in `src/`)

Kept (intentional):
- `dist/web/` — gitignored 41 MB web build (rebuild on demand)
- `production/stories/archived-platformer/` — historical record
- `CCGS Skill Testing Framework/` — referenced by `.claude/skills/skill-test/SKILL.md`
- `production/sprints/sprint-01.md` — NM launch sprint (shelved, may revive)

## Open Directions (next session)

1. **MVP playtest** — verify v0.54.1 visuals + new shimmer end-to-end. Need human eyes (AC-15).
2. **VS system pick** — 8 VS systems pending. High-leverage candidates:
   - #12 Procedural generator (lexicon → seed glyphs runtime-generated)
   - More NPC vignettes (smith, fisherman, weaver, child, traveler — currently baker only)
   - #5 Glyph font (8×8 bitmap pixel font — currently using jf-openhuninn)
3. **Night Market revival** — `sprint-01.md` shelved launch sprint. NT$10/NT$2/NT$5 stalls all live.
4. **Audio chime asset** — finish AC-11 audibly (currently silent pan calc only).

## Solo Mode

`production/review-mode.txt` = `solo`. Director gates (TD/PR/CD) all auto-skipped.

## Test Suite Snapshot

- Total: 464/464
- Lexicon unit: 140 (was 114; +26 cascade shimmer)
- NM unit + integration: 324
- Runtime: ~6s headless
