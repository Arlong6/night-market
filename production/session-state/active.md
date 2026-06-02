# Active Session State

> **Last Updated**: 2026-06-02 (post-SPIKE 1 + audio + smoke + NM revival + VS-1)
> **Purpose**: Living checkpoint for the current task. Read this first after compaction or new session.

## Current Task

字典村莊 + 夜市採購 launch path. User invoked "1 2 3 4" → all four queued items done in this session.

## Session Summary (2026-06-02)

### v0.55 — SPIKE 1 cascade shimmer real + cleanup
- ✅ #11 LVDialogueDisplay refactored to HBoxContainer-of-Labels (per-token animation targets)
- ✅ #10 LVCascadeShimmer real implementation (Formulas 1-4, ACs 1,3,4,6-12,16 tested)
- ✅ Cleanup: removed prototypes/night-market-runner, empty src/src/, empty assets/
- ✅ Tests: +26 cascade shimmer; 464/464 total

### v0.56 — chime audio + smoke + NM revival + procedural generator (this batch)
- ✅ **#4 Audio chime asset** — LVChime procedural sine + envelope generator (1.2s, 880Hz, slow attack). Wired into shimmer via AudioStreamPlayer2D with position-based pan.
- ✅ **#1 MVP headless smoke** — boot of lv_main.tscn, NM title.tscn, NM shilin_market.tscn all clean (no parse errors, no push_error noise).
- ✅ **#3 Night Market revival** — sprint-01.md updated from SHELVED → REVIVED. New window 2026-06-06 → 2026-06-08. Scope expanded to include lexicon village. Added L-013 for AC-15 playtest. sprint-status.yaml updated.
- ✅ **#2 VS system #12 Procedural Lexicon Generator** — full GDD (8 sections, 10 ACs). LVProcGen static class (deterministic seed → glyph dict, phonologically consistent, collision-free, POS-aware syllable counts).
- ✅ Tests: +14 proc gen, +2 chime; **480/480 total**

## Files Touched This Session (most recent first)

| File | Purpose |
|---|---|
| `src/lexicon/scripts/lv_proc_gen.gd` | NEW — procedural lexicon generator |
| `design/gdd/procedural-generator.md` | NEW — #12 GDD (8 sections, 10 ACs) |
| `src/tests/unit/lexicon/test_lv_proc_gen.gd` | NEW — 14 tests covering ACs 1-7, 10 + edge cases |
| `production/sprints/sprint-01.md` | REVIVED — scope expanded to two games; new window + L-013 |
| `production/sprint-status.yaml` | Updated dates + L-013 + L-005 test count to 466→480 |
| `src/lexicon/scripts/lv_chime.gd` | NEW — procedural chime generator (AudioStreamWAV) |
| `src/lexicon/scripts/lv_cascade_shimmer.gd` | +chime wiring with pan via 2D player position |
| `src/tests/unit/lexicon/test_lv_cascade_shimmer.gd` | +2 chime tests (stream format + plays-on-ripple) |
| `src/lexicon/scripts/lv_dialogue_display.gd` | Refactored: single Label → HBoxContainer-of-Labels |
| `src/lexicon/scripts/lv_village.gd` | Removed legacy Label injection |
| (deleted) `prototypes/night-market-runner/*` | 9 files staged delete |

## Test Suite Snapshot

- **Total: 480/480** (+42 from 438 baseline)
- Lexicon unit: 154 (114 baseline + 26 cascade shimmer + 14 proc gen)
- NM unit + integration: 326
- Runtime: ~6s headless

## SPIKE 1 + VS-1 Coverage

### #10 Cascade Shimmer ACs

| AC | Coverage | Notes |
|---|---|---|
| AC-1 | ✅ test | `vignette_completed → state RIPPLE_ACTIVE` |
| AC-2 | partial | Origin projection coded; visual verification playtest |
| AC-3 | ✅ test | `t_arrive(near) < t_arrive(far)` |
| AC-4 | ✅ test | Ease-out: `t(100) < t(500)*0.5` |
| AC-5 | ⚠ manual | 3-phase tween coded; per-tick assertion playtest |
| AC-6 | ✅ test | `is_on_screen()` filter; direct resolve path |
| AC-7 | ✅ test | Second completion queues during active |
| AC-8 | ✅ test | Three completions all accounted for |
| AC-9 | ✅ test | `split_animated_vs_direct()` caps at 80 |
| AC-10 | ✅ test | `is_instance_valid` guards |
| AC-11 | ✅ test | `compute_pan()` + chime player created |
| AC-12 | ✅ test | reduced-motion → t_arrive=0 |
| AC-13 | implicit | Audio bus mute doesn't break visual |
| AC-14 | n/a | Retroactive resolve owned by #11 |
| AC-15 | ⚠ playtest | L-013 in sprint-01 |
| AC-16 | ✅ test | Notebook-open defers |

### #12 Procedural Generator ACs

| AC | Coverage | Notes |
|---|---|---|
| AC-1 | ✅ test | Same seed = same output |
| AC-2 | ✅ test | 80% diff between seeds |
| AC-3 | ✅ test | 30 seeds × 20 slots, no collisions |
| AC-4 | ✅ test | POS-respecting syllable counts |
| AC-5 | ✅ test | All consonants legal |
| AC-6 | ✅ test | All vowels legal |
| AC-7 | ✅ test | Empty slots → empty dict |
| AC-8 | trusted | LCG determinism cross-process (not directly testable in one run) |
| AC-9 | n/a | Integration phase B (next session) |
| AC-10 | ✅ test | Collision storm → numeric suffix, no crash |

## Open Directions (next session)

1. **Procedural generator integration (Phase B)** — wire LVProcGen into LVSessionState + LVVignetteContent.render_slot_text override path.
2. **More NPC vignettes** — smith, fisherman, weaver (currently baker only).
3. **L-001 Web build** — actual export and verify file size <20MB.
4. **L-013 AC-15 playtest** — 3 first-time testers describe cascade shimmer.
5. **#5 Glyph font** — 8×8 bitmap pixel font (currently CJK fallback).

## Solo Mode

`production/review-mode.txt` = `solo`. Director gates (TD/PR/CD) all auto-skipped.
