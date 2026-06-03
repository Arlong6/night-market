# Active Session State

> **Last Updated**: 2026-06-03 (post-batch: procgen Phase C + 4 NPCs + real bitmap font + harmonic chime + release drafts)
> **Purpose**: Living checkpoint for the current task. Read this first after compaction or new session.

## Current Task

字典村莊 + 夜市採購 launch path. User invoked "1 2 3 4 5" three times in a row → all 15 queued items shipped across v0.55 / v0.56 / v0.57 / v0.58.

## Session Summary (2026-06-03 — batch 2)

### v0.58 — five-in-one (this batch)

- ✅ **#1 ProcGen Phase C** — `LVShareCode` Crockford-style base32 share-code (max 7 chars). `LVSessionState.serialize()` / `deserialize()` / `to_save_json()` / `from_save_json()`. Round-trip preserves seed + bindings + cascade state + procgen runtime glyphs. +19 tests.
- ✅ **#2 4 more vignettes** — Weaver, Child, Traveler, Storyteller content tables added with new world positions. Village scene spawns all 7 NPCs. `CORRECT_TABLE` expanded to 20 slots. +9 vignette content tests.
- ✅ **#3 Real 8×8 bitmap font** — `LVBitmapGlyphs` with hand-encoded pixel data for 29 chars (vowels + 10 consonants + punct + space + 10 digits). `glyph_image()`, `render_word_image()`, `render_word_texture()`. Replaces "AA-off CJK clone" approach with true 8×8 pixel glyphs. +13 tests.
- ✅ **#4 Audio chime upgrade** — `LVChime` now a multi-harmonic stack: fundamental 440Hz + perfect 5th + octave (detuned) + 2-octave (detuned). Reads as "warm bell" rather than pure sine test tone. Same envelope. +4 chime characteristic tests.
- ✅ **#5 Release pipeline drafts** — `production/release-notes/v1.0.md` (player-facing changelog), `production/release/itch-page-draft.md` (EN+中 page text, tags, screenshot list, upload checklist), `GAMES.md` (player-facing intro at repo root), README.md top-section link to GAMES.md.

## Files Touched This Session

| File | Purpose |
|---|---|
| `src/lexicon/scripts/lv_share_code.gd` | NEW — base32 Crockford encoder/decoder |
| `src/lexicon/autoloads/lv_session_state.gd` | +serialize/deserialize/JSON round-trip |
| `src/tests/unit/lexicon/test_lv_share_code.gd` | NEW — 11 tests |
| `src/tests/unit/lexicon/test_lv_session_state_save.gd` | NEW — 8 round-trip tests |
| `src/lexicon/data/lv_vignette_content.gd` | +WEAVER/CHILD/TRAVELER/STORYTELLER content + CORRECT_TABLE expanded |
| `src/lexicon/scripts/lv_village.gd` | +4 new NPC instances + cascade tracking + active_npc routing |
| `src/tests/unit/lexicon/test_lv_vignette_content.gd` | +9 tests for new vignettes |
| `src/lexicon/scripts/lv_bitmap_glyphs.gd` | NEW — hand-encoded 8×8 font (29 chars) |
| `src/tests/unit/lexicon/test_lv_bitmap_glyphs.gd` | NEW — 13 tests |
| `src/lexicon/scripts/lv_chime.gd` | Upgraded to multi-harmonic stack |
| `src/tests/unit/lexicon/test_lv_cascade_shimmer.gd` | +4 chime-quality tests |
| `production/release-notes/v1.0.md` | NEW — player-facing release notes |
| `production/release/itch-page-draft.md` | NEW — itch.io page EN+中 draft + upload checklist |
| `GAMES.md` | NEW — player-facing two-game intro |
| `README.md` | +top-section link to GAMES.md |

## Test Suite Snapshot

- **Total: 550/550** (+43 from last session 507)
- Lexicon unit: 251 (was 181; +19 share-code/save, +9 vignettes, +13 bitmap, +4 chime, others)
- NM unit + integration: 326 (unchanged)
- Runtime: ~7.5s headless

## Sprint-01 Status (REVIVED)

| Story | Status | Notes |
|---|---|---|
| L-001 | ✅ build delivered, ⚠ browser smoke pending user | 12.5MB gzipped |
| L-002 | pending | smoke check on built artifact |
| L-003 | ✅ draft delivered | `production/release/itch-page-draft.md` |
| L-004 | ✅ partial — GAMES.md + README link delivered, screenshots pending user | |
| L-005 | partial | 550 tests pass locally; fresh-clone re-run pending |
| L-006 | ✅ delivered | `production/release-notes/v1.0.md` |
| L-007 | pending — user-only | git tag v1.0 manual |
| L-008 | pending | audio gesture-unlock |
| L-009 | pending | mobile browsers |
| L-010 | pending | INDEX backfill |
| L-013 | protocol delivered, ⚠ execution pending user | playtest script ready |

## Open Directions (next session)

1. **L-002 / L-008 / L-009** — actual cross-browser smoke (user — open `dist/index.html`)
2. **L-013** — 3-tester AC-15 playtest (user)
3. **L-007** — tag v1.0 (user, after L-001..L-006 done)
4. **Wire LVBitmapGlyphs into LVDialogueDisplay** — currently the font exists with tests but doesn't yet replace the LVGlyphFont path in dialogue rendering. Phase B of #5.
5. **Capture screenshots** — for itch.io page (NM + Lexicon Village)
6. **Audio real assets** — replace procedural chime with hand-designed asset (audio designer)
7. **NM additions / refinements** — held off since v0.53; consider what (if any) NM content for v1.1

## Solo Mode

`production/review-mode.txt` = `solo`. Director gates (TD/PR/CD) all auto-skipped.

## Session Trajectory

| Commit | Tests | Key Delivery |
|---|---|---|
| v0.54.1 baseline | 438 | 字典村莊 visuals |
| v0.55 | 464 | SPIKE 1 cascade shimmer real + cleanup |
| v0.56 | 480 | chime + smoke + NM revival + procgen |
| v0.57 | 507 | procgen Phase B + smith/fisher + web build + playtest doc + pixel font shim |
| v0.58 (this) | 550 | procgen Phase C + 4 NPCs + real bitmap font + harmonic chime + release drafts |

Total: +112 tests across 4 commits, both games shippable.
