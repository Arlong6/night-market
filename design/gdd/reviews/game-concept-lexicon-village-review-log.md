# Review Log — game-concept-lexicon-village.md

Tracks revision history of the Lexicon Village concept doc across `/design-review` runs.

---

## Review — 2026-05-28 — Verdict: NEEDS REVISION → Revised in-session
Scope signal: L
Specialists: game-designer, systems-designer, ux-designer, narrative-director, godot-specialist, creative-director
Blocking items: 5 | Recommended: 5+
Summary: Concept vision is coherent and the dev has proven scope (Night Market shipped to v0.53 / 324 tests), but three concept-stage holes blocked downstream decomposition — shimmer was the central feel moment yet under-specified, the soft-confirmation mechanism produced a "4-of-5 silence" feedback dead zone, and the procedural-language ↔ hand-authored-vignette coupling was undefined. Creative-director called for "decide three things, then proceed" rather than rejecting the design.

### Blockers resolved in-session

| # | Issue | Resolution |
|---|---|---|
| 1 | "4-of-5 silence" — soft-confirmation had no signal between silence and shimmer | Added vignette progress counter in notebook ("3/5 待解"); reveals distance, not which guess is wrong. Codified in Core Mechanics #2, Flow State Design, and MVP Required #3. |
| 2 | Procedural ↔ authored coupling undefined | Committed to **phonetic-only procedural**: semantic slots hand-authored per vignette (NOUN_BREAD = bread always); only glyph-sequence carrying that meaning changes per seed. Re-seed = new cipher, not new content. Trade-off (recognition not first-contact discovery on re-run) explicitly acknowledged. |
| 3 | Shimmer spec missing — Pillar 1 + 3's central mechanism was a one-liner | Added full **Shimmer Specification** section: ripple-propagation tone (1.5s sweep from triggering NPC), single-ripple concurrency cap, retroactive resolves use quiet glow not ripple, 80-glyph performance budget, playtest acceptance test ("testers describe as sweep/wave/spreading not flash/pop"). |
| 4 | Final question interaction undefined | Committed to **multiple-choice** — 3-4 candidate answers composed of meaning-icons, no penalty for wrong picks. Captured in Core Mechanics #4 and Session-Level loop. |
| 5 | Anti-Pillar #2 conflicted with *Arrival* reference | Rewrote to "NOT plot- or branching-driven — character is implied through vignette tableau, not stated." Preserves design discipline (no dialogue trees, romance, quests, state changes) while acknowledging player will project personality onto NPCs. Arrival reference kept with emotional-tableau framing. |

### Recommended items also applied

- Meaning-icon vocabulary: culture-neutral pictograms (not English words), abstract words via context triangulation
- Click-to-select / click-to-place fallback for drag-to-bind (Fitts's Law on 8×8 px trackpad targets)
- Language design estimate corrected: 1–2 days → 3–5 focused days for MVP language, 1–2 weeks for Full Vision
- Technical Considerations expanded: shimmer architecture spike, drag cross-browser test, font antialiasing on font AND theme, audio-gesture guard
- Next Steps reordered: 3 spikes (shimmer/drag/font) precede `/art-bible`; ADR for shimmer architecture between spikes and art bible

### Prior verdict resolved: First review (no prior)

### Awaiting

User selected `/clear` + re-run `/design-review design/gdd/game-concept-lexicon-village.md` in a fresh session. Re-review will validate whether the 5 blocking resolutions are coherent and whether new issues surfaced.

---

## Review — 2026-05-28 (re-review) — Verdict: MAJOR REVISION NEEDED → Concept deferred
Scope signal: XL (revised up from L — convergent scope-infeasibility finding)
Specialists: game-designer, systems-designer, ux-designer, narrative-director, godot-specialist, creative-director
Blocking items: 6 | Recommended: 9 | Nice-to-have: 6
Summary: The 5 prior resolutions were structurally present but two of them introduced problems worse than the originals they replaced. Five specialists independently triangulated three structural wounds: (A) the multiple-choice climax + progress counter + 20-word vocabulary collectively convert the comprehension test into a slot-elimination sudoku — a zero-comprehension player can finish in ≤4 button-presses, structurally betraying Pillar 1; (B) the narrative thesis is undefined because the elder's question has never been written, making *Arrival* / Voynich references decorative borrowings the design cannot deliver; (C) scope is structurally infeasible — the doc's own Scope Risks admit language design alone consumes 2–4 weekends, but Full Vision claims 4 total weekends. Anti-Pillar #2 was over-tightened, leaving the baker as a vending machine after `krunta` resolves. Unique Hook ("true re-playability") directly contradicts Long-Term Progression ("casual players will play once") in the same document.

### Blockers (NOT resolved — concept deferred)

| # | Issue | CD's call |
|---|---|---|
| 1 | Multiple-choice climax allows brute-force completion without comprehension | Switch to free-composition OR document pillar-conflict resolution |
| 2 | No worked elder-question example exists; entire narrative payload undefined | **THE keystone artifact — write this before any other decision** |
| 3 | Progress counter unspecified as UX system (data model, timing, wording, binary-search exploit) | Full spec required |
| 4 | Anti-Pillar #2 over-tightened — baker cannot witness comprehension | Pick: silent post-vignette OR one revisit line using decoded vocabulary |
| 5 | Scope infeasible: 4-weekend Full Vision vs 2–4 weekends for language alone | Re-baseline to 6–8 weekends OR cut procedural generator |
| 6 | Unique Hook / Long-Term Progression self-contradiction on replay value | Reframe hook to sell single-sitting completeness |

### Specialist convergence (unusual cleanliness)

- Issue A (climax mechanic) hit by game-designer, ux-designer, narrative-director from three disciplines
- Issue C (scope) hit independently by systems-designer and godot-specialist
- No specialist disagreements of substance — creative-director called it "three views of the same wound"

### CD's keystone recommendation

> Write the elder's final question, in the lexicon language, with a worked solution path showing which 5 NPCs/vignettes teach the words required to comprehend it. One sentence in a made-up language is the load-bearing artifact the entire concept rests on — it defines the narrative thesis, sets minimum vocabulary, determines free-composition vs multiple-choice, reveals if 20 words is enough, and shows whether Pillar 1 and Pillar 3 truly conflict.

### Studio context call

Solo dev's parallel concept while Night Market Shopping ships at v0.53 / 324 tests. Convergent scope-infeasibility finding means this is not a *side* project — it is a *second project* dressed as one. CD recommendation: **defer concept until Night Market reaches v1.0 / content-complete.** If parallel work is later resumed: cap at one weekend per month of *exploration only* — no production commitment, just a sketchbook for the elder's question and one playable language-fragment toy. No further GDD work until Night Market ships.

### Prior verdict resolved: Partial
Surface gaps (silence problem, procedural commitment, shimmer spec, multiple-choice climax, anti-pillar #2 wording) were addressed by the 2026-05-28 in-session revision. Re-review revealed the fixes themselves created new structural problems. Prior review's "decide N things and proceed" stance is no longer appropriate at this depth.

### Status: DEFERRED (reverted 2026-05-29)
User initially accepted CD recommendation to defer 2026-05-28. **Reverted 2026-05-29**: user explicitly rejected the defer recommendation ("我還是要做字典村莊 — 不接受 'defer until v1.0' 這個建議") and chose to pursue Lexicon Village as active design focus instead of Night Market launch.

---

## Keystone artifact authored — 2026-05-29

In response to CD's keystone recommendation (from the 2026-05-28 re-review), the elder's final question was drafted as `design/gdd/lexicon-village-elder-question.md`.

### Chosen question
**`Ne sun-wo nai-an ka?`** — "Will you come back to this place?"

### What this artifact resolves (5 of 8 review findings now addressable)

| Blocker | Resolution |
|---|---|
| [game-designer #1] Multiple-choice brute-force | Binary y/n with both options emotionally valid; comprehension lives in question, not answer |
| [game-designer #6] 20 words can't carry meaningful question | 6 tokens + 4 grammar particles = working question; 21 content slots reserve |
| [narrative-director #4] No sample elder question | Exists |
| [narrative-director #7] No narrative thesis | Thesis: "the small kindness of being asked to return" |
| [systems-designer #3 partial] Phoneme cap | 16 phonemes within 17–20 cap |
| [systems-designer #6 partial] Vocab-to-vignette math | 7 NPCs × 3 content + 4 grammar = exactly 25 slots, no shared-word ambiguity |
| [narrative-director #2 partial] Baker on revisit | Recommended path proposed (comprehensible idle line using decoded words); needs design lock |
| [narrative-director #6] Cultural neutrality | Question's social act is universal; partial mitigation |

### What remains open (NOT resolved by keystone)

- [game-designer #2] Per-vignette progress counter UX spec
- [game-designer #3] Replay marketing/reality gap in Unique Hook
- [game-designer #4] Pillar 1 vs 3 conflict explicit acknowledgment
- [game-designer #5 / narrative-director #2 full] Baker revisit behavior — needs design lock, not just recommendation
- [systems-designer #7] 4-weekend Full Vision scope re-baseline
- [systems-designer #2] Shimmer behavior on screen-space UI
- [ux-designer all 8 findings] Notebook UX workstream entirely untouched
- [godot-specialist #3] WebGL2 NEAREST filter — deferred to SPIKE 3

### Next session recommendations (from keystone §7)

Choose one of:
- (a) Resolve per-vignette progress counter UX (highest risk to climax)
- (b) Lock multiple-choice vs free-composition in main GDD (now downstream-decidable)
- (c) Run SPIKE 1 (shimmer architecture on Web)

### Status: ACTIVE (defer reverted, keystone in place)
Lexicon Village is the active design focus. The GDD still carries 5 unaddressed blockers + 9 recommended items; do not treat as production-ready. Next concrete action: see recommendations above.

---

## Counter UX locked — 2026-05-29 (same day, post-keystone)

After the keystone, attacked the highest-priority remaining blocker per the keystone §7 recommendation (a): per-vignette progress counter UX. Locked the following sub-decisions:

| Decision | Choice | Rationale |
|---|---|---|
| Counter semantics | α — "still-unsolved" includes both unguessed AND wrong-guessed | Preserves GDD original intent; player accepts elimination as path |
| Update timing | Live (per swap) | Player chose instant feedback over deliberate hypothesis batching |
| Visibility | Notebook → per-vignette page only | Keeps NPC interactions free of "find N things" framing |
| Slot visuals | Distinct (placed shows icon, empty shows "?") | Eliminates ux-designer #5 (wrong-state = no-state ambiguity) |
| Sudoku-style swap-and-check | Accepted as valid play style | Conscious Pillar 1 vs Pillar 3 trade-off; Pillar 3 wins in this micro-context |

GDD Mechanic #2 rewritten to embed full spec. Open Questions table updated (counter question + elder-question question both marked RESOLVED).

### Additional blockers resolved by this session

| Blocker | Status |
|---|---|
| [game-designer #2] Progress counter as sudoku elimination | RESOLVED — accepted as valid play style with explicit pillar trade-off acknowledgment |
| [ux-designer #1] Counter redundant/floating | RESOLVED — distinct slot visuals + counter together; data model spec'd |
| [ux-designer #2] Counter leaks binary-search affordance | RESOLVED — leak accepted as feature, not bug |
| [ux-designer #3] Counter update timing unspecified | RESOLVED — live update locked |
| [ux-designer #4] "待解" wording ambiguous | RESOLVED — wording accepted as accurate for α semantics (both unguessed and wrong-guessed are literally "to-resolve") |
| [ux-designer #5] Wrong-guess vs no-guess visual state | RESOLVED — distinct visuals locked |
| [game-designer #4 partial] Pillar 1 vs 3 conflict | PARTIALLY RESOLVED — explicit acknowledgment at counter sub-system; full-game pillar priority still needs statement |

### Cumulative resolution status (post-2026-05-29 session)

**Resolved**: 5 (keystone) + 6 (counter) = **11 of original 15 findings** (6 blockers + 9 recommended, treating partials as 0.5)

**Still open**:
- [game-designer #3] Unique Hook replay marketing/reality gap (text rewrite needed)
- [game-designer #4 full] Pillar 1 vs 3 at full game level (not just counter)
- [game-designer #5 / narrative-director #2] Baker revisit behavior — design lock needed
- [systems-designer #7] 4-weekend Full Vision scope re-baseline
- [systems-designer #2] Shimmer behavior on screen-space UI
- [godot-specialist] Multiple engineering risks (SPIKE 3 NEAREST filter etc.) — engineering, not design
- Various nice-to-have items (Voynich clarification, accessibility fallback, etc.)

### Next session recommendation

Concept is now substantially more solid. Options:
- (b) Lock multiple-choice vs free-composition fully in GDD (downstream of keystone, ~15 min)
- Resolve Baker revisit behavior (cleanup)
- Run SPIKE 1 (shimmer architecture) — moves into engineering
- Address Unique Hook replay text gap (~15 min copy edit)

---

## Final-question binary mechanic locked — 2026-05-29 (option b executed)

Followed up on the keystone artifact's downstream recommendation. GDD updated:
- **Mechanic #4** rewritten: 3–4 multiple-choice candidates → **2 candidate answers (binary)**, both emotionally valid, neither "correct"; closing scene fires on either pick (warm vs wistful)
- **Session-Level Loop** updated: same — 2 candidates, both trigger ending
- **Open Questions table**: "multiple-choice quizzy?" question marked RESOLVED — the quiz-vs-revelation framing dissolves when decoys are removed

### Blocker promoted from partial to full

| Blocker | Prior | Now |
|---|---|---|
| [game-designer #1] Multiple-choice climax allows brute-force | Partial (binary y/n softens) | **FULL** — no decoy candidates to brute-force; answer is naming a kind of departure, not eliminating wrong options |

### Cumulative resolution status (end of 2026-05-29 session)

**Resolved**: 11 (after counter) + 1 promotion to full = **12 of 15 original findings** (treating partials as 0.5)

**Still open** (carry to next session):
- [game-designer #3] Unique Hook replay marketing/reality gap (text rewrite)
- [game-designer #4 full] Pillar 1 vs 3 at full game level (partial micro-acknowledgment exists)
- [game-designer #5 / narrative-director #2] Baker revisit behavior — design lock needed
- [systems-designer #7] 4-weekend Full Vision scope re-baseline (user has not agreed to re-baseline; defer to next session)
- [systems-designer #2] Shimmer behavior on screen-space UI
- [godot-specialist] Engineering items (deferred to SPIKE phases)
- Nice-to-haves: Voynich clarification, accessibility fallback, cultural-neutrality acknowledgment

### Session end state

- Multi-write session: keystone artifact + GDD Mechanic #2 rewrite + GDD Mechanic #4 rewrite + Session-Level Loop update + 3 Open-Questions resolutions + Core Identity scope label + Scope Tiers re-baseline + multiple review-log appends + 1 memory entry
- Concept is materially more shippable than at session start

---

## Scope re-baselined to 6–8 weekends — 2026-05-29 (continued same session)

User accepted the systems-designer + godot-specialist + creative-director convergent finding that prior 4-weekend Full Vision estimate failed scope arithmetic. Chosen path: **Option A** — accept honest 6–8 weekend timeline AND keep procedural language generator (no scope cut).

GDD edits applied:
- **Core Identity table**: `Estimated Scope` changed from "Small (2–4 weekends, solo)" to "Medium (6–8 weekends part-time solo)" with re-baseline note
- **Scope Tiers table**: cumulative timelines now Vertical Slice = 3 weekends, Full Vision = 6–7 weekends, + spike contingency row added (+1 weekend per failed spike, worst case +3)
- Explicit user-acknowledged trade-off captured in GDD

### Blocker resolved

| Blocker | Status |
|---|---|
| [systems-designer #7] 4-weekend Full Vision scope infeasible | **RESOLVED** — re-baselined to 6–8 weekends, user accepted full ambition with honest timeline |

### Cumulative status (post-2026-05-29 session, final)

**Resolved**: 13 of 15 original findings (treating partials as 0.5)

**Still open** (carry to next session):
- [game-designer #3] Unique Hook replay marketing/reality gap (text rewrite) — partly mitigated by scope re-baseline framing ("6–8 weekend project, not weekend project") but Hook text still has the contradiction
- [game-designer #4 full] Pillar 1 vs Pillar 3 at full game level (only counter sub-context covered)
- [game-designer #5 / narrative-director #2] Baker revisit behavior — design lock still open
- [systems-designer #2] Shimmer behavior on screen-space UI (notebook overlay) — engineering proximate
- [godot-specialist] Engineering items (SPIKE phases — deferred by design)
- Nice-to-haves: Voynich aesthetic-only clarification, accessibility motion fallback, cultural-neutrality acknowledgment

### Verdict at end of session

Concept moved from MAJOR REVISION NEEDED → roughly equivalent to NEEDS REVISION (lower severity). Three remaining design items (Hook text, Baker behavior, Pillar 1-vs-3 explicit) are each small (<30 min each). After those + screen-space shimmer spec, concept will be ready for `/map-systems` decomposition.

---

## Three small blockers resolved — 2026-05-29 (continued)

User chose to push through remaining quick-win design items in single batch.

### Resolutions

| Blocker | Resolution |
|---|---|
| [game-designer #3] Hook replay marketing/reality gap | Hook re-ordered (single-sitting hoisted to primary; procedural hoisted to qualified replay). "True re-playability" wording removed. Honest framing explicit: "casual players play once; that one playthrough IS the complete intended experience." Replay framed as cipher-recracking for puzzle veterans. |
| [game-designer #4 full] Pillar 1 vs 3 conflict at full game level | New "Pillar Priority" subsection added between Pillar 3 and Anti-Pillars. Locks 3 cases: counter loop = P3 wins; elder climax = both held via binary; everywhere else = P1 wins. Future design choices must surface in GDD if defaulting to P3. |
| [game-designer #5 / narrative-director #2] Baker revisit behavior | Locked all-NPC pattern: post-cascade single comprehensible idle line ≤4 tokens, using only decoded vocabulary, invitational not new info, same every revisit. Baker example: `Tola mura ka?` Explicitly NOT an anti-pillar #2 violation — NPC unchanged; player's eyes changed. |

### Cumulative status (final, end of 2026-05-29)

**Resolved**: 15 of 15 original design findings (treating partials as 0.5; now all promoted to full)

**Still open** (engineering only, deferred to SPIKE phases):
- [systems-designer #2] Shimmer behavior on screen-space UI (notebook overlay) — engineering proximate, address during SPIKE 1
- [godot-specialist] All 8 engineering items — addressed by SPIKE 1 / 2 / 3
- Nice-to-haves: Voynich aesthetic-only clarification, accessibility motion fallback (could be small GDD adds at any time but not blocking)

### Final verdict

**Concept is now ready for `/map-systems` decomposition** (or at worst, ready after Voynich + accessibility nice-to-haves which take <15 min combined).

The path from MAJOR REVISION NEEDED (2026-05-28) → READY-FOR-MAP-SYSTEMS (2026-05-29) was a single full-day design session that:
- Reverted CD's defer recommendation per user judgment
- Wrote the load-bearing keystone artifact (elder question)
- Locked counter UX (accepting sudoku trade-off explicitly)
- Locked binary climax (eliminating brute-force problem at root)
- Re-baselined scope honestly (6–8 weekends, full ambition retained)
- Locked NPC revisit pattern (resolving anti-pillar #2 tension)
- Rewrote Hook to match GDD self-honesty
- Locked pillar conflict resolution (explicit precedence cases)

**Recommended next session entry point**: `/map-systems game-concept-lexicon-village.md` — break the concept into individual systems (notebook UI, dialogue system, language generator, vignette state machine, shimmer animation) per CD's pre-existing Next Steps recommendation. Note: the systems-index.md doesn't exist yet; `/map-systems` will create it.

**Alternative entry point**: SPIKE 1 (shimmer architecture on Web) — moves into engineering before design decomposition. Acceptable per GDD Next Steps original ordering.
