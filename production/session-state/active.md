# Active Session State

> **Last Updated**: 2026-06-03 (post-batch: procgen Phase B + smith/fisher + web build + playtest doc + pixel font)
> **Purpose**: Living checkpoint for the current task. Read this first after compaction or new session.

## Current Task

字典村莊 + 夜市採購 launch path. User invoked "1 2 3 4 5" → all five queued items done this session.

## Session Summary (2026-06-03)

### v0.57 — five-in-one (this batch)

- ✅ **#1 ProcGen Phase B** — Wired LVProcGen into LVSessionState (`_runtime_glyphs`) + LVVignetteContent (override dict in render_slot_text + render_tokens) + LVDialogueDisplay (reads runtime glyphs from session). init_session with seed!=0 auto-generates per-run language. +7 integration tests.
- ✅ **#2 Smith + Fisher vignettes** — Full content (intro/action/closing/idle tokens + world positions), village scene now spawns all four NPCs (baker/smith/fisher/elder), LVVignetteStateMachine.is_in_dialogue() for confirm/cancel routing. +11 tests.
- ✅ **#3 L-001 Web build** — Real export via `godot --headless --export-release "Web" "../dist/index.html"`. Total gzipped delivery **~12.5 MB** (well under 20 MB sprint budget). Browser smoke deferred to user. Documented in `production/qa/web-build-2026-06-03.md`.
- ✅ **#4 L-013 Playtest protocol** — User-blocked task fully scripted in `production/qa/playtest-protocol-cascade-shimmer.md`. Includes tester recruitment, verbatim brief script, listen-for/don't-say language, results template, knob retune fallback (RIPPLE/DWELL).
- ✅ **#5 Pixel glyph font** — Pragmatic approach: clone jf-openhuninn with AA/hinting/subpixel disabled at small font size (`LVGlyphFont.PIXEL_FONT_SIZE=10`). Applied only to unresolved LEXICON_SLOT labels via LVDialogueDisplay._render_current. Resolved CJK keeps default rendering. +9 tests.

## Files Touched This Session (most recent first)

| File | Purpose |
|---|---|
| `src/lexicon/scripts/lv_glyph_font.gd` | NEW — pixel-mode font wrapper (AA off, hinting off) |
| `src/lexicon/scripts/lv_dialogue_display.gd` | +pixel font applied to unresolved LEXICON_SLOT labels |
| `src/tests/unit/lexicon/test_lv_glyph_font.gd` | NEW — 9 tests |
| `production/qa/playtest-protocol-cascade-shimmer.md` | NEW — full AC-15 protocol for user |
| `production/qa/web-build-2026-06-03.md` | NEW — build size verification doc |
| `src/lexicon/data/lv_vignette_content.gd` | +SMITH + FISHER vignettes (intro/action/closing/idle/world_position) |
| `src/lexicon/scripts/lv_village.gd` | +smith/fisher NPCs in scene, _active_npc routing, elder repositioned |
| `src/lexicon/scripts/lv_npc.gd` | +SMITH readable name |
| `src/lexicon/scripts/lv_vignette_state_machine.gd` | +is_in_dialogue() helper |
| `src/tests/unit/lexicon/test_lv_vignette_content.gd` | +11 smith/fisher tests |
| `src/lexicon/autoloads/lv_session_state.gd` | +_runtime_glyphs + get/set + auto-generate from seed |
| `src/lexicon/data/lv_vignette_content.gd` | +runtime_override param in render_slot_text + render_tokens |
| `src/tests/unit/lexicon/test_lv_proc_gen.gd` | +7 Phase B integration tests |
| `src/tests/unit/lexicon/test_lv_dialogue_display.gd` | use seed=0 to avoid procgen affecting MVP-glyph asserts |
| (built) `dist/index.{html,wasm,pck,js,png}` | Web export artifacts (gitignored) |

## Test Suite Snapshot

- **Total: 507/507** (+27 from last session 480)
- Lexicon unit: 181 (was 154)
- NM unit + integration: 326
- Runtime: ~6s headless

## Sprint-01 Status (REVIVED)

| Story | Status | Notes |
|---|---|---|
| L-001 | ✅ build delivered, ⚠ browser smoke pending user | 12.5MB gzipped, under budget |
| L-002 | pending | smoke check on built artifact |
| L-003 | pending | itch.io page assets |
| L-004 | pending | README update |
| L-005 | partial | 507 tests pass locally; fresh-clone re-run pending |
| L-006 | pending | release notes |
| L-007 | pending | git tag v1.0 (blocked by L-001..L-006) |
| L-008 | pending | audio gesture-unlock |
| L-009 | pending | mobile browsers |
| L-010 | pending | INDEX backfill |
| L-013 | protocol delivered, ⚠ execution pending user | playtest script ready |

## Open Directions (next session)

1. **ProcGen Phase C** — save/restore seed via LVSessionState persistence, share-codes
2. **More vignettes** — weaver, child, traveler, storyteller (4 more for full 7-NPC roster)
3. **Real 8×8 bitmap font** — replace pragmatic AA-off approach with true hand-encoded glyph pixel data for the ~15 lexicon ASCII chars (#5 "Phase B" — full intent)
4. **L-002 / L-008 / L-009** — actual browser smoke testing (user)
5. **L-013** — recruit + run 3 testers (user)
6. **Audio chime real asset** — replace procedural sine with hand-designed soft tone (sound-designer)
7. **L-003 / L-004 / L-006 / L-007** — release pipeline (itch.io page, README, release notes, tag)

## Solo Mode

`production/review-mode.txt` = `solo`. Director gates (TD/PR/CD) all auto-skipped.
