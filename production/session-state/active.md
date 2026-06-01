# Active Session State

> **Last Updated**: 2026-05-29 (game-session-state GDD complete)
> **Purpose**: Living checkpoint for the current task. Read this first after compaction or new session.

## Current Task

Designing individual system GDDs for Lexicon Village. Currently completed: #19 Game session state.

## Status

✅ **ALL 13 MVP SYSTEMS DESIGNED** (autonomous batch 2026-05-30).
🚀 **IMPLEMENTATION IN PROGRESS** (autonomous batch).

| # | System | impl path | tests | status |
|---|---|---|---|---|
| 19 | LVSessionState | `src/lexicon/autoloads/lv_session_state.gd` | 23 | ✅ |
| 2 | LVInput | `src/lexicon/autoloads/lv_input.gd` | 12 | ✅ |
| 1 | LVBoot | `src/lexicon/autoloads/lv_boot.gd` | 16 | ✅ |
| 3 | Camera/Viewport | (project.godot) | 5 | ✅ |
| 9 | LVSymbolBinding | `src/lexicon/scripts/lv_symbol_binding.gd` | 18 | ✅ |
| 8 | LVVignetteStateMachine | `src/lexicon/scripts/lv_vignette_state_machine.gd` | 13 | ✅ |
| 13 | LVVignetteContent (baker) | `src/lexicon/data/lv_vignette_content.gd` | 13 | ✅ |
| 11 | LVDialogueDisplay | `src/lexicon/scripts/lv_dialogue_display.gd` | 14 | ✅ |
| 7 | LVNPC | `src/lexicon/scripts/lv_npc.gd` | (scene smoke) | ✅ |
| 6 | LVVillage | `src/lexicon/scripts/lv_village.gd` | (scene smoke) | ✅ |
| 16 | LVNotebookUI | `src/lexicon/scripts/lv_notebook_ui.gd` | (scene smoke) | ✅ |
| 17 | LVTitle | `src/lexicon/scripts/lv_title.gd` | (scene smoke) | ✅ |
| 18 | LVEnding | `src/lexicon/scripts/lv_ending.gd` | (scene smoke) | ✅ |
| 10 | LVCascadeShimmer (MVP scaffold) | `src/lexicon/scripts/lv_cascade_shimmer.gd` | (SPIKE 1 deferred) | ✅ |
| — | LVMain root | `src/lexicon/scripts/lv_main.gd` + `lv_main.tscn` | (scene smoke) | ✅ |

**ALL 13 MVP SYSTEMS IMPLEMENTED**.

Total lexicon tests: **114**. NM tests intact: 324. **Full suite: 438/438**. Web export OK (~10MB gzipped).

**Entry point**: `res://lexicon/scenes/lv_main.tscn` (run via `godot --path src res://lexicon/scenes/lv_main.tscn`).

**MVP play loop**: Title → Start → Village (baker + elder) → click baker → vignette plays → press N to open notebook → place 3 icons correctly → cascade shimmer → click elder → ending scene → restart.

| # | System | ACs | Notes |
|---|---|---|---|
| 19 | Game session state | 23 | Bottleneck; complete prior session |
| 2 | Input system | 18 | Click-primary; concept Mech #5 reconciled |
| 1 | Boot & scene flow | 17 | "Arriving at the gate" fantasy |
| 3 | Camera & viewport | 9 | 320×180 base, integer scale |
| 9 | Symbol-binding | 15 | Bottleneck; gesture realizer |
| 11 | Dialogue display | 14 | Bottleneck; shimmer-aware token rendering |
| 6 | Village scene & layout | 10 | Single-screen; no player avatar |
| 10 | Cascade shimmer | 16 | **HIGH RISK + CENTRAL FEEL**; SPIKE 1 gated |
| 8 | Vignette state machine | 14 | Per-NPC 6-state machine |
| 7 | NPC sprite & tableau | 10 | Baker MVP only |
| 16 | Notebook UI | 14 | UX spec followup flagged |
| 17 | Title screen | 10 | Quiet entry |
| 13 | Vignette content (baker) | quick-spec | First authored content |

**Concept doc cross-doc corrections applied**:
- Mechanic #5: drag-primary → click-primary (post-#2)
- #19 dependency table: #11 added as direct dependent (post-#11)

**Registry updates**: `total_semantic_slots` referenced by 3 GDDs now.

**Pending all-in-fresh-session reviews**: every MVP GDD's review log notes "single-session inline review; fresh-session independent review recommended before MVP code begins."

## Files Created / Modified This Session (most recent first)

| File | Purpose |
|---|---|
| `design/gdd/systems-index.md` | 22-system enumeration, dependency map, design order, high-risk systems (just written) |
| `design/gdd/lexicon-village-elder-question.md` | Keystone artifact (~280 lines) — chosen elder question + mini-lexicon + 7 NPC tableaux |
| `design/gdd/game-concept-lexicon-village.md` | 6 edits — Mechanic #2 (counter UX), Mechanic #4 (binary climax), Session Loop, Hook, Pillar Priority, Scope Tiers, Open Questions |
| `design/gdd/reviews/game-concept-lexicon-village-review-log.md` | Multiple appends — defer reverted, keystone, counter UX, binary climax, scope re-baseline, 3 small blockers |
| `production/sprints/sprint-01.md` | Night Market launch sprint — **SHELVED** (user reverted to Lexicon Village focus) |
| `production/sprint-status.yaml` | Night Market launch sprint state — SHELVED |
| `production/qa/qa-plan-sprint-1-2026-05-28.md` | Night Market QA plan — SHELVED |

## Key Decisions Made

- **Defer Lexicon Village reverted** (2026-05-29) — user rejected CD "defer until v1.0" rec; active focus is Lexicon Village
- **Counter UX α** — "3/5 待解" includes unguessed + wrong-guessed; live update; notebook-only; distinct slot visuals; sudoku elimination accepted
- **Binary climax** — 2 candidates (not 3-4), both emotionally valid, no "correct" answer
- **Scope re-baseline** — 6-8 weekends part-time solo, procedural generator retained
- **NPC revisit pattern** — all-NPC post-cascade comprehensible idle line ≤4 tokens
- **Elder question** — `Ne sun-wo nai-an ka?` ("Will you come back to this place?")

## Systems Index Summary

- 22 total systems (13 MVP, 8 VS, 2 Alpha-FV, 1 Full Vision)
- 5 Foundation + 6 Core + 6 Feature + 3 Presentation + 2 Polish
- Bottlenecks: #9 Symbol-binding, #11 Dialogue display
- High-risk: #10 Cascade shimmer, #5 Glyph font, #16 Notebook UI, #12 Procedural generator, #13 Vignette content
- First 4 systems in design order: #19 → #2 → #1 → #3 (all Foundation, all S effort)

## Open Questions Awaiting User Input

- Whether to start `/design-system` on order 1 (#19 Game session state) now, or stop and resume later
- Whether to run SPIKEs 1-3 (shimmer/drag/font) in parallel with design work or sequence after design

## Solo Mode

`production/review-mode.txt` = `solo`. Director gates (TD/PR/CD) all auto-skipped.

## Carryover from Earlier Session

- Night Market launch sprint artifacts on disk (sprint-01.md, sprint-status.yaml, qa-plan-sprint-1-2026-05-28.md) — shelved per user; may repurpose as sprint-02 template later.
