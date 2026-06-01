# Systems Index: Lexicon Village（字典村莊）

> **Status**: Draft (solo mode — directors auto-skipped)
> **Created**: 2026-05-29
> **Last Updated**: 2026-05-29
> **Source Concept**: `design/gdd/game-concept-lexicon-village.md`
> **Keystone Artifact**: `design/gdd/lexicon-village-elder-question.md`
> **Note**: Project has 3 concept docs; this index decomposes `game-concept-lexicon-village.md` (the new puzzle game), not `game-concept.md` (replaced platformer) or `game-concept-rpg.md` (Night Market, shipping at v0.53).

---

## Overview

Lexicon Village is a single-sitting (45–60 min) language-decipherment puzzle game built in Godot 4.6 for Web HTML5. The player learns ~25 words of a constructed language through 7 NPC vignettes, then reads the elder's final question and chooses one of two emotionally-valid binary answers. The mechanical scope splits across three concerns: (1) a **language layer** — phonetic-only procedural generator (Full Vision; hand-authored for MVP) + glyph rendering + dialogue display; (2) a **vignette layer** — NPCs perform tableaux that expose words contextually, with cascade-shimmer celebrating each completed vignette; (3) a **notebook layer** — the symbol-to-meaning binding UI where the player commits hypotheses, with a per-vignette progress counter that accepts sudoku-style elimination as a valid play style. The central feel system is the cascade shimmer (Pillar 1's main delivery vector); the central data system is symbol-to-meaning binding (bottleneck for 4 dependents).

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Boot & scene flow (inferred) | Core | MVP | Designed (pending /design-review) | `design/gdd/boot-scene-flow.md` | — |
| 2 | Input system (inferred) | Core | MVP | Designed (pending /design-review) | `design/gdd/input-system.md` | — |
| 3 | Camera & viewport (inferred) | Core | MVP | Approved (lean review) | `design/gdd/camera-viewport.md` | — |
| 4 | Audio system | Core | VS | Not Started | — | 1 |
| 5 | Glyph font rendering | Core | VS | Not Started | — | 1 |
| 6 | Village scene & layout (inferred) | Gameplay | MVP | Approved (lean review) | `design/gdd/village-scene-layout.md` | 1, 3 |
| 7 | NPC sprite & tableau rendering (inferred) | Gameplay | MVP | Approved (lean review) | `design/gdd/npc-sprite-tableau.md` | 6, 3, 2 |
| 8 | Vignette state machine | Gameplay | MVP | Approved (lean review) | `design/gdd/vignette-state-machine.md` | 7, 9, 11, 19, 13 |
| 9 | Symbol-to-meaning binding | Gameplay | MVP | Approved (lean review) | `design/gdd/symbol-binding.md` | 19, 2 |
| 10 | Cascade shimmer animation | Gameplay | MVP | Approved with HIGH RISK (lean review, SPIKE 1 gated) | `design/gdd/cascade-shimmer.md` | 5, 11, 8, 19, 13, 3 |
| 11 | Dialogue display (shimmer-aware) (inferred) | UI | MVP | Approved (lean review) | `design/gdd/dialogue-display.md` | 5, 21, 19 |
| 12 | Procedural language generator | Gameplay | Full Vision | Not Started | — | 19 |
| 13 | Vignette content authoring (per NPC) | Narrative | MVP→Alpha incremental | MVP Approved (baker quick-spec done; other NPCs VS+) | `design/gdd/vignette-content-baker.md` (baker only) | 8, 12, 19 |
| 14 | NPC revisit idle line | Gameplay | VS | Not Started | — | 7, 8, 11 |
| 15 | Elder climax flow | Gameplay | VS | Not Started | — | 9, 16, 18 |
| 16 | Notebook UI | UI | MVP | Approved with UX SPEC FOLLOWUP (lean review) | `design/gdd/notebook-ui.md` | 9, 19, 2, 5, 21 |
| 17 | Title screen (inferred) | UI | MVP | Approved (lean review) | `design/gdd/title-screen.md` | 1, 2, 3, 21 |
| 18 | Ending scene (inferred) | UI | VS | Not Started | — | 19, 15 |
| 19 | Game session state (inferred) | Persistence | MVP | Designed (pending /design-review) | `design/gdd/game-session-state.md` | — |
| 20 | Settings (audio/lang toggle) (inferred) | UI | VS | Not Started | — | 4, 21, 1 |
| 21 | Localization (中/英 UI strings) (inferred) | Meta | VS | Not Started | — | — |
| 22 | Accessibility motion fallback (inferred) | Meta | Alpha/FV | Not Started | — | 10 |

**Total: 22 systems. 10 MVP, 8 VS, 2 Alpha-FV, 1 Full Vision only (procedural generator). 13 explicit from concept, 9 inferred.**

---

## Categories

| Category | Description | Systems in this game |
|----------|-------------|----------------------|
| **Core** | Engine-level foundation | 1, 2, 3, 4, 5 |
| **Gameplay** | The systems that deliver the core fantasy | 6, 7, 8, 9, 10, 12, 14, 15 |
| **UI** | Player-facing displays | 11, 16, 17, 18, 20 |
| **Narrative** | Content authoring | 13 |
| **Persistence** | State management | 19 |
| **Meta** | Outside-loop systems | 21, 22 |

Categories explicitly NOT used: Combat, Economy, Progression, Audio (folded into Core), Network. Lexicon Village has no combat, no inventory, no leveling, no multiplayer.

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems |
|------|------------|------------------|---------|
| **MVP** | Required for one-vignette playable toy (1 weekend per concept tier) | Baker vignette demo loads in Web browser | 1, 2, 3, 6, 7, 8, 9, 10, 11, 13(baker only), 16, 17, 19 (13 systems) |
| **Vertical Slice** | 3 NPCs, custom 8×8 font, full climax + ending, audio (+2 weekends, cumulative 3) | 3 vignettes + elder + ending scene; ~10-word vocabulary | 4, 5, 13(3 NPCs), 14, 15, 18, 20, 21 (8 systems) |
| **Alpha** | All 7 NPCs designed and content-authored; placeholder polish OK | Full content scope, missing only generator | 13(remaining NPCs), 22 |
| **Full Vision** | Procedural language generator + full polish (+3-4 weekends, cumulative 6-7) | Re-seedable replay; full Audio mix; accessibility complete | 12, polish iterations on all above |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **#1 Boot & scene flow** — entry point and scene transition orchestrator
2. **#2 Input system** — mouse / drag / keyboard, Web cross-browser
3. **#3 Camera & viewport** — single-scene village, trivial
4. **#19 Game session state** — in-memory data structure (bound words, vignettes complete, time elapsed, language seed)
5. **#21 Localization** — UI string table (中/英)

### Core Layer (depends on foundation)

1. **#4 Audio system** — depends on: 1 (gesture-unlock at boot)
2. **#5 Glyph font rendering** — depends on: 1 (asset load); high-risk per godot-specialist (8×8 NEAREST filter on Web)
3. **#6 Village scene & layout** — depends on: 1, 3
4. **#9 Symbol-to-meaning binding** — depends on: 19; **BOTTLENECK** (4 dependents downstream)
5. **#11 Dialogue display** — depends on: 5, 21; **BOTTLENECK** (4 dependents downstream)
6. **#12 Procedural language generator** — depends on: 19

### Feature Layer (depends on core)

1. **#7 NPC sprite & tableau** — depends on: 6, 11
2. **#8 Vignette state machine** — depends on: 7, 9, 11
3. **#10 Cascade shimmer animation** — depends on: 5, 11, 8; **CENTRAL FEEL** + high-risk
4. **#13 Vignette content authoring** — depends on: 8, 12
5. **#14 NPC revisit idle line** — depends on: 7, 8, 11
6. **#15 Elder climax flow** — depends on: 9, 16, 18

### Presentation Layer (depends on features)

1. **#16 Notebook UI** — depends on: 9, 2; high-risk per godot-specialist (drag on Web)
2. **#17 Title screen** — depends on: 1
3. **#18 Ending scene** — depends on: 19, 15

### Polish Layer (depends on everything)

1. **#20 Settings** — depends on: 4, 21, 1
2. **#22 Accessibility motion fallback** — depends on: 10

---

## Recommended Design Order

Combines dependency sort + priority tier. Design and write GDDs in this order. Independent systems within the same layer + tier can be designed in parallel.

| Order | System | Priority | Layer | Agent(s) | Est. Effort | Why this order |
|-------|--------|----------|-------|----------|-------------|----------------|
| 1 | #19 Game session state | MVP | Foundation | systems-designer | S | Pure data; #9 (bottleneck) depends on it; fast win |
| 2 | #2 Input system | MVP | Foundation | gameplay-programmer | S | All UI/click systems depend; SPIKE 2 informs design |
| 3 | #1 Boot & scene flow | MVP | Foundation | engine-programmer | S | Title→game→ending shell must exist first |
| 4 | #3 Camera & viewport | MVP | Foundation | engine-programmer | S | Trivial for single-scene village |
| 5 | **#9 Symbol-to-meaning binding** | MVP | Core | systems-designer + ux-designer | M | **Bottleneck** — lock data API early; informs 8/15/16/18 |
| 6 | **#11 Dialogue display** | MVP | Core | ui-programmer + game-designer | M | **Bottleneck** — shimmer-aware contract upstream of #10 |
| 7 | #6 Village scene & layout | MVP | Core | game-designer + level-designer | S | Where baker stands |
| 8 | **#10 Cascade shimmer animation** | MVP | Feature | game-designer + technical-artist + godot-specialist | L | **CENTRAL FEEL** — design parallel with SPIKE 1; HIGH RISK |
| 9 | #8 Vignette state machine | MVP | Feature | systems-designer | M | Baker vignette flows through this; depends on 9, 11 |
| 10 | #7 NPC sprite & tableau (baker only) | MVP | Feature | game-designer + technical-artist | S | MVP needs only baker |
| 11 | **#16 Notebook UI** | MVP | Presentation | ux-designer + ui-programmer | L | HIGH RISK; SPIKE 2 first; complex spec already locked in concept doc Mechanic #2 |
| 12 | #17 Title screen | MVP | Presentation | ui-programmer | S | MVP shell complete after this |
| 13 | #13 Vignette content (baker) | MVP | Narrative | writer + narrative-director | S (quick-spec) | Concrete content for baker — could be quick-spec rather than full GDD |
| — | **MVP boundary** | — | — | — | — | After 13, MVP is design-complete. Run `/gate-check pre-production` here. |
| 14 | #4 Audio system | VS | Core | audio-director + sound-designer | S | Adds music/SFX + gesture-unlock wrapper |
| 15 | #5 Glyph font rendering | VS | Core | technical-artist + godot-shader-specialist | M | Custom 8×8 bitmap; SPIKE 3 driven |
| 16 | #13 (NPCs 2-3 content) | VS | Narrative | writer | S each | Blacksmith + Fisher vignettes |
| 17 | #14 NPC revisit idle line | VS | Feature | game-designer + writer | S | Post-cascade comprehensible lines |
| 18 | #15 Elder climax flow | VS | Feature | game-designer + narrative-director | M | Question + binary answer + closing scene (per keystone artifact) |
| 19 | #18 Ending scene | VS | Presentation | ui-programmer + writer | S | Warm / wistful goodbye |
| 20 | #21 Localization | VS | Foundation/Meta | localization-lead | S | 中/英 UI strings (constructed language is its own thing) |
| 21 | #20 Settings | VS | Polish | ui-programmer | S | Audio + language toggle |
| — | **Vertical Slice boundary** | — | — | — | — | After 21, VS is design-complete (3 NPCs + elder + ending) |
| 22 | #13 (NPCs 4-7 content) | Alpha | Narrative | writer | S each | Weaver, Child, Traveler, Storyteller |
| 23 | #22 Accessibility motion fallback | Alpha/FV | Meta | accessibility-specialist + ux-designer | S | Static fallback for cascade-confirm |
| 24 | **#12 Procedural language generator** | Full Vision | Core | systems-designer + writer | L | Phoneme inventory + syllable rules + edit-distance filter; HIGH SCOPE |

Effort key: S = 1 design session; M = 2-3 sessions; L = 4+ sessions.

**MVP design effort estimate**: 13 systems × ~S-M-L mix ≈ ~17 sessions for MVP GDDs alone.

---

## Circular Dependencies

None found. The dependency graph is a DAG.

Notable tight coupling (NOT circular but interface contracts matter):
- **#10 Cascade shimmer ↔ #11 Dialogue display** — shimmer applies to dialogue text and history. Dialogue is the substrate; shimmer wraps it. Contract: dialogue must expose a per-token rendering API that shimmer can animate. Lock this contract when designing #11 (step 6) — must not require redesign when #10 is built (step 8).
- **#15 Elder climax ↔ #16 Notebook UI** — elder's answer cards use notebook's meaning-icon vocabulary. Contract: notebook exposes "render an icon from confirmed vocab" API. Lock when designing #16 (step 11).

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **#10 Cascade shimmer** | Technical + Design | RichTextEffect per-character animation on Godot 4.6 Compatibility renderer / Web is unverified; AccessKit 4.5 may interact. Visual feel is CENTRAL to game's success per Pillar 1. | **SPIKE 1** — 40-line BBCode test in Web export, Chrome AND Firefox, with frame-time at 80 glyphs. ADR for shimmer architecture before art bible. |
| **#5 Glyph font rendering** | Technical | 8×8 bitmap font on Web defaults to LINEAR filtering → illegible. Must set `texture_filter = NEAREST` on FontFile import AND theme; verify in browser, not editor. | **SPIKE 3** — import one bitmap font, render at 8 px on Web, confirm sharp pixels. |
| **#16 Notebook UI (drag)** | Technical | Godot's `_get_drag_data` / `_drop_data` on Web has known cross-browser timing differences (Chrome vs Firefox `mouseup`). | **SPIKE 2** — 20-line Control test with drag, exported to Web. If drag breaks, click-fallback is primary (already required in concept doc Mechanic #5). |
| **#12 Procedural language generator** | Scope + Design | Phonetic distinctiveness quality filter is named in GDD but not specified. Risk of producing seeds with confusable word pairs that frustrate players. Full Vision priority — high opportunity to over-scope. | Apply systems-designer's recommended filter: Levenshtein edit distance ≥ 2 + differ on first two phonemes; reject and re-roll violations. Design as Full Vision; do not start before VS is shippable. |
| **#13 Vignette content authoring** | Design + Scope | "One bad NPC vignette breaks the whole game" (concept doc Scope Risks). Each NPC's tableau must be unambiguous; fresh-eyes playtest required per NPC. | Quick-spec per NPC; playtest each before committing the next. Don't author 7 NPCs in one batch. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 22 |
| Design docs started | 13 |
| Design docs reviewed | 10 |
| Design docs approved | 10 |
| MVP systems designed | **13/13** |
| Vertical Slice systems designed | 0/8 |

---

## Next Steps

- [ ] Run `/design-system game-session-state` (or `/map-systems next`) to begin order 1
- [ ] Run SPIKE 1 (shimmer architecture on Web) in parallel — informs system #10 design
- [ ] Run SPIKE 2 (drag on Web) in parallel — informs systems #2 and #16
- [ ] Run SPIKE 3 (8×8 font on Web) before VS work begins — informs system #5
- [ ] After step 13 (baker content), run `/gate-check pre-production` (MVP design complete)
- [ ] Run `/design-review` after each individual GDD is authored
- [ ] When SPIKE 1/2/3 complete: lock ADRs for shimmer rendering / input pipeline / font pipeline

---

## Solo-mode directors skipped

Per `production/review-mode.txt` = `solo`, the following gates were not spawned during this index creation:
- **TD-SYSTEM-BOUNDARY** (after dependency mapping) — technical-director boundary review skipped
- **PR-SCOPE** (after priority assignment) — producer scope/timeline reality check skipped
- **CD-SYSTEMS** (after index write) — creative-director set-completeness review skipped

If the project moves to `lean` or `full` review mode later, re-run `/map-systems` (or specific phase) to backfill those gates.
