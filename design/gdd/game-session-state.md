# Game Session State (#19)

> **Status**: In Design
> **Author**: solo (user-driven) + skill orchestration
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Infrastructure — no direct pillar (enables Pillars 1/2/3 via reliable state)
> **System Category**: Persistence (Foundation layer)
> **Game**: Lexicon Village

## Overview

Game Session State is the in-memory data structure that holds everything the current playthrough has accumulated: the language seed in use, the set of bound word-to-meaning hypotheses, the set of completed vignettes, and the elapsed session time. It is **single-sitting only** — Lexicon Village explicitly does not have a save/load system, so this state is created fresh at game start and discarded on game end (no persistence layer beyond optional Settings in system #20). The system is **purely infrastructure**: players never interact with it directly, but they see its derivative outputs everywhere — the "3/5 待解" counter on each notebook vignette page, the per-vignette completion shimmer trigger, the dictionary panel on the ending scene, and the time-taken display at game end. Every gameplay system that needs to know "what has the player learned so far?" reads from this single source of truth, eliminating drift between subsystems. Implementation pattern (autoload singleton vs scoped service vs ephemeral game-scene-owned struct) is **TBD — see ADR-TBD-game-session-state when written**.

## Player Fantasy

Players never see Game Session State, but they see what it remembers for them. After ten minutes of wandering, they return to a notebook page and find "3/5 待解" still patiently waiting — not nagging, not gamifying, just *holding their place*. The fantasy here is the relief of being kept track of. Like a field linguist's notebook that stays open on the table while you make tea, the system's job is to never lose the thread of a half-formed hypothesis. The player feels: *someone is counting the small things I noticed, so I can keep noticing.*

Then, at session end, the dictionary panel opens and the player sees every word they earned, alongside "47 minutes 字典村莊." The session state was, all along, quietly assembling proof that the village existed as a coherent place with a coherent language — not a puzzle generator, but a *somewhere*. The fantasy this delivers is retrospective worldhood: the sense that the language you decoded was waiting for you, identical for the next player and the player before, a real thing you visited. The infrastructure's gift is *thereness*.

**Pillar alignment**: serves Pillar 3 (No Failure) by holding state patiently between attention bursts, and Pillar 2 (Language IS the World) by accumulating the artifacts that prove the world was real. Does NOT directly serve Pillar 1 (Discovery above Mastery) — that fantasy lives in the cascade-shimmer (system #10) and elder question (system #15), which read FROM session state but own the discovery moment themselves.

## Detailed Design

### Core Rules

Session State holds exactly these fields, initialized at game-start, mutated only by named events:

**Identity / generation**
- `language_seed: int` — generated at game-start; stable for the entire session; consumed by #12 (procedural language generator)

**Per-slot binding table** (25 entries, one per semantic slot from `lexicon-village-elder-question.md` §3)
- `binding_map[slot_id] → meaning_icon | null` — player's current hypothesis per slot; `null` = no guess placed
- `confirmed_slots: set[slot_id]` — slots that are part of a fully-cascaded vignette; **immutable once set**

**Per-vignette state** (7 entries — one per NPC)
- `vignette_cascaded[vignette_id] → bool` — `true` once all vignette slots are correctly bound AND cascade-shimmer fired; **write-once** (no un-cascade)

**Session lifecycle**
- `session_elapsed_ms: int` — wall-clock milliseconds from game-start; snapshot taken at game-start AND at game-end (gameplay-programmer-recommended pattern using `Time.get_ticks_msec()` deltas — avoids tab-suspend complications; honest "47 minutes" semantics including any breaks the player took)
- `game_phase: enum { PLAYING, ENDING, TITLE }` — governs which transitions are legal

**Derived / on-demand** (read-only, recomputed; never stored)
- `unresolved_count(vignette_id) → int` — the "3/5 待解" counter. **Owned by Session State** (not #9), because only Session State has full visibility of slot-to-vignette mapping AND the authoritative correct-binding table.

No other fields. No score, no quest flags, no NPC dialogue progress — this is a language notebook, not an RPG.

### States and Transitions

| Event | Fields changed | Notes |
|---|---|---|
| **Game starts** | All defaults applied; `language_seed` generated; `game_phase = PLAYING`; timer start-snapshot taken | Fresh creation, no loading |
| **Player places icon on slot** | `binding_map[slot_id]` updated | Replaces any previous binding. Triggers vignette-validation check. |
| **Player removes icon from slot** | `binding_map[slot_id] = null` | Same vignette-validation check |
| **Vignette validates as fully correct** | `vignette_cascaded[id] = true`; vignette's slot IDs added to `confirmed_slots` | Cascade signal emitted; both fields write-once |
| **Player reaches elder (all 7 cascaded)** | `game_phase = ENDING`; timer end-snapshot taken; `session_elapsed_ms` computed | State frozen for #18 ending scene |
| **Player returns to title** | State destroyed | Only full teardown |

**Vignette-validation check** (runs synchronously after every bind/unbind): for each vignette, compute whether all its slots have a non-null binding matching the correct mapping. If yes AND `vignette_cascaded` is currently false, fire the false→true transition + emit `vignette_completed(vignette_id)` signal. Cost is trivial (max 5 slots × 7 vignettes = 35 comparisons per check).

### Interactions with Other Systems

| System | Reads | Writes | Notes |
|---|---|---|---|
| **#9 Symbol-binding** | `binding_map`, `confirmed_slots` | `binding_map[slot_id]` (single slot per action) | Owns "icon placement" UX; delegates validation + counter to Session State. Confirmed slots should be rendered visually-locked (not drag targets) — locking enforcement lives in #9/#16. |
| **#12 Procedural language generator** | `language_seed` (once at init) | nothing | Produces `slot_id → correct_meaning_icon` table at game start. This table is the authoritative correct-binding source used by validation. **Flag**: this assumes #12's output shape is a slot-id-to-icon lookup; revisit if #12 produces a different structure (e.g., phonetic strings needing separate resolution). |
| **#18 Ending scene** | `confirmed_slots`, `binding_map`, `session_elapsed_ms`, `game_phase` (must = ENDING) | nothing | Renders dictionary + time. **Flag**: if #18 also wants to show incorrect/unconfirmed bindings ("here's what you got wrong"), it reads `binding_map` directly — currently allowed by contract. |
| **#10 Cascade shimmer animation** | listens to `vignette_completed(id)` signal | nothing | Shimmer is downstream of the data transition; if shimmer animation and data ever disagree, Session State is correct. Shimmer is presentation. |
| **#20 Settings** | nothing (Settings has its own localStorage persistence) | nothing | Explicit separation: Settings (audio/lang) persists across sessions; Game Session State does not. Keep separate. |

**Single-source-of-truth rules**:

1. **One writer per field**. `binding_map` is written only by #9. `vignette_cascaded` and `confirmed_slots` are written only by Session State's own validation logic, never by subsystems directly.
2. **Cascade is the authority boundary**. Once `vignette_cascaded[id] = true`, slots in that vignette are immutable at the data layer. Visual lock in notebook UI is enforcement; data invariant is the truth.

**Cross-system flags** (these depend on systems not yet designed):
- #12 output shape — assumed `slot_id → correct_icon` lookup
- #18 read scope — may need direct `binding_map` access if it shows incorrect bindings
- #9 drag-target locking — split between #9 and #16 (notebook UI); to be clarified when those are designed

## Formulas

This system has **no balance formulas, no scaling curves, no tuning equations**. Session State is pure data orchestration. Two derived computations exist, documented for implementation clarity:

---

**Formula 1: `unresolved_count(vignette_id)` — the "N/M 待解" counter**

The unresolved count formula is defined as:

`unresolved_count(vignette_id) = |slots_in(vignette_id)| - |slots_in(vignette_id) ∩ correctly_bound_slots|`

Where `correctly_bound_slots = { slot_id : binding_map[slot_id] == correct_table[slot_id] }`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `slots_in(vignette_id)` | S_v | set of slot_ids | 3–5 per vignette | Authored mapping of which slots belong to which vignette (stable across seeds; declared per NPC in `lexicon-village-elder-question.md` §4) |
| `binding_map[slot_id]` | b(s) | meaning_icon \| null | one of ~25 icons or null | Player's current hypothesis for slot s |
| `correct_table[slot_id]` | c(s) | meaning_icon | one of ~25 icons | Authoritative correct binding for slot s (produced by #12 at game-start) |

**Output range**: 0 to `|S_v|` (0 to 5 in practice). 0 = vignette is fully and correctly bound; equal to `|S_v|` = no slot is correctly bound (either unguessed or wrong-guessed; the counter does not distinguish).

**Example**: Baker vignette has 3 slots (NOUN_BREAD, VERB_GIVE, ADJ_WARM). Player has bound NOUN_BREAD→bread-icon (correct), VERB_GIVE→eat-icon (wrong), ADJ_WARM→null. Count = 3 - 1 = **2 (待解 2/3)**.

---

**Formula 2: `vignette_valid(vignette_id)` — the cascade-trigger predicate**

The vignette-valid predicate is defined as:

`vignette_valid(vignette_id) = ∀ slot_id ∈ slots_in(vignette_id) : binding_map[slot_id] == correct_table[slot_id]`

In words: a vignette is valid IFF every one of its slots has a non-null binding that matches the correct table.

**Output range**: boolean. `true` triggers the cascade-shimmer transition (write `vignette_cascaded[id] = true`, emit `vignette_completed` signal).

**Example**: Baker vignette with bindings as above → false (VERB_GIVE wrong, ADJ_WARM null). Player swaps VERB_GIVE→give-icon (correct) and ADJ_WARM→warm-icon (correct) → predicate becomes true → cascade fires.

---

**Implementation cost**: computing both formulas per bind/unbind = 1 set lookup + ≤5 equality checks. Trivial; can run synchronously on the input thread.

## Edge Cases

**Binding boundary conditions**

- **If** the player drags an icon to a second slot while it already occupies a first: `binding_map[slot_a]` becomes null, `binding_map[slot_b]` receives the icon. #9 must enforce "one instance per icon in palette" as a UI rule before writing (data layer permits duplicates; UI must not).
- **If** the player places an icon that is not in `correct_table` for any slot: legally held; validation never fires; counter stays non-zero. No special handling — formulas handle naturally.
- **If** the player places an icon that IS correct for a different slot than the one it was placed on: no cascade, counter stays non-zero. Handled by formula.

**Validation timing**

- **If** the player performs two rapid binds in the same frame: synchronous validation runs sequentially in the call stack. If the second bind completes a vignette, exactly one `vignette_completed` signal fires — no race.
- **If** validation runs again on an already-cascaded vignette (e.g., a neighboring vignette's bind triggers a full re-scan): the guard `if not vignette_cascaded[id]` prevents double-emit. This must be an explicit code check, not an inferred invariant.

**Counter math at extremes**

- **If** a vignette has 0 slots (malformed authored data): `unresolved_count` = 0 immediately, `vignette_valid` = true (vacuously). Vignette would cascade at game-start without player action. **Authoring constraint**: every vignette MUST have ≥1 slot. Enforced in acceptance criteria.
- **If** `unresolved_count` would go below 0: impossible by construction (intersection ≤ set size).

**Timer edge cases**

- **If** the player reaches the elder in under one second: `session_elapsed_ms` is a small valid integer (e.g., 800). #18 must format sub-minute values gracefully ("少於 1 分鐘" or similar).
- **If** the player AFKs for hours before triggering the elder: `session_elapsed_ms` reflects real wall-clock delta including AFK time. **Accepted by design** ("honest 47 minutes"). #18 must handle multi-hour values without overflow.
- **If** the browser tab is suspended mid-session (mobile / background): `Time.get_ticks_msec()` may pause or drift. Delta-snapshot pattern means the gap counts as elapsed time. **Documented known behavior, not a bug** — matches the wall-clock-honesty design intent.

**Game phase transitions**

- **If** the player triggers the elder check while the cascade-shimmer animation for vignette 7 is still playing: `game_phase = ENDING` fires at the data layer immediately; shimmer is presentation-only. **Contract**: #18 must not render until Session State emits a dedicated `session_ended` signal or checks `game_phase == ENDING` directly — NOT by listening to the cascade signal alone.
- **If** the player navigates to title (state destroyed) while a `vignette_completed` signal is in flight: listeners on #10 must disconnect (or be freed) before Session State is destroyed; alternatively use `call_deferred` with null-checks. Specified in interaction contract for #10.
- **If** `game_phase` somehow reads as ENDING before `session_elapsed_ms` is written: #18 could display 0ms. **Invariant**: the phase-transition handler must write `session_elapsed_ms` atomically BEFORE emitting any ENDING signal. Enforced in transition table.
- **If** a bind event fires while `game_phase == ENDING` (player somehow accesses notebook after ending triggered): **Session State rejects the write** — bind operations are only legal when `game_phase == PLAYING`. UI lock in #9 is enforcement; data layer is the backstop.

**Procedural seed edge cases**

- **If** `language_seed = 0`: valid integer. #12 must treat 0 as a legal seed, NOT as "uninitialized" sentinel. Do not use 0 to mean "no seed yet."
- **If** `language_seed = INT_MAX` (2⁶³-1 in GDScript): valid. #12 must document its seed-to-output collision behavior; not Session State's concern.
- **If** #12's generator produces a `correct_table` where the same icon is correct for two different slots: ambiguous — player placing icon X on slot_a satisfies slot_a but NOT slot_b (one-instance-per-icon UI rule). **Constraint on #12**: the `correct_table` must be a bijection — no icon appears as the correct answer for more than one slot.

**Write-once / undo UX**

- **If** the player wants to "undo" a completed vignette: `vignette_cascaded` is write-once. Slots are visually locked in #9/#16. There is no mechanic to undo. **UI communicates this passively** (locked visual state); no error message. Design is intentional.
- **If** somehow an icon is removed from a confirmed slot (bug / unexpected drag path): Session State must REJECT the write at the data layer, not rely solely on #9's UI. `confirmed_slots` immutability is a data invariant.

## Dependencies

**Upstream dependencies (this system depends on)**: NONE.

Game Session State is in the **Foundation layer** — it has zero upstream dependencies. It can be designed and implemented in isolation, ahead of every other system in the game.

**Downstream dependents (systems that depend on this one)** — bidirectional consistency note: these dependents' GDDs are not yet written; this list will need to be cross-checked once each is designed.

| Depending system | Dependency type | Data interface |
|---|---|---|
| **#9 Symbol-binding** | **Hard** — #9 cannot function without Session State holding the binding map | Reads `binding_map`, `confirmed_slots`; writes `binding_map[slot_id]` (single slot per action). Delegates counter + validation to Session State. |
| **#12 Procedural language generator** | **Hard** — #12 reads the seed and produces the correct_table; no seed means no language | Reads `language_seed` once at game-start; writes nothing. Produces `correct_table` consumed by Session State validation. |
| **#10 Cascade shimmer animation** | **Soft** — #10 is presentation-only; data transitions are valid without #10's animation, but the player wouldn't see them | Listens to `vignette_completed(vignette_id)` signal. Reads no other Session State fields. |
| **#18 Ending scene** | **Hard** — #18 cannot render without Session State data | Reads `confirmed_slots`, `binding_map`, `session_elapsed_ms`, `game_phase` (must = ENDING). Writes nothing. |

**Explicitly NOT dependent (worth stating for boundary clarity)**:

- **#20 Settings** — separate persistence layer (localStorage); Settings persists across sessions, Session State does not. No shared data, no signals.
- **#1 Boot, #2 Input, #3 Camera, #6 Village, #7 NPC sprite, #16 Notebook UI, #17 Title screen** — all touch player-visible layers above Session State, but none read directly from it; they go through #9, #18, or other intermediaries.

**Corrections (2026-05-30)**:
- **#11 Dialogue display** was previously listed as "NOT dependent" but the #11 GDD reads `confirmed_slots` directly from Session State at render time (per-token resolution check). Moved to direct dependent. Interaction: read-only on `confirmed_slots`.

**Cross-system contracts that need backfill when dependents are designed**:

1. #9 GDD must document: "depends on Session State for `binding_map` storage and `confirmed_slots` immutability check; calls `session_state.unresolved_count(v)` for counter UI."
2. #12 GDD must document: "depends on Session State for `language_seed`; produces `correct_table` that Session State consumes for validation."
3. #10 GDD must document: "listens to Session State's `vignette_completed(id)` signal; does not poll Session State directly."
4. #18 GDD must document: "depends on Session State for dictionary + time; reads `binding_map` if it shows incorrect bindings (per Session State's permissive contract)."

**Cross-system flags** (assumptions in this GDD that need validation when dependents are designed):

- `correct_table` shape from #12 (assumed `slot_id → icon` lookup)
- #18's read scope (currently allows both `confirmed_slots` and `binding_map`)
- Drag-target locking for cascaded slots (split between #9 and #16; needs clarification)

## Tuning Knobs

Game Session State has **no system-owned tuning knobs**. It is a structural data layer; its shape is determined by content authored in other systems, and its behavior is locked by invariants from Sections C–E.

**Knobs that affect this system, owned by other systems** (point-to-source-of-truth, no duplicates):

| Knob | Owner system | Effect on Session State | Default | Safe range |
|---|---|---|---|---|
| Total vignette count | #13 (vignette content authoring) | `vignette_cascaded[]` array size | 7 | 1–10 (design intent); array sizing is structural, not balance |
| Slots per vignette | #13 (per NPC) | `slots_in(vignette_id)` set size | 3–5 per vignette | ≥1 (zero-slot vignettes are forbidden per Edge Cases); ≤7 (UX legibility on notebook page) |
| Total semantic slot count | #13 + keystone artifact | `binding_map[]` array size | 25 | 15–35 (lower = too brief, upper = breaks 8×8 glyph legibility per systems-designer cap) |
| Language seed range | #12 (procedural generator) | `language_seed` accepted values | full int64 range | 0 to 2⁶³-1 (NOT a sentinel; 0 is legal per Edge Cases) |
| Timer precision unit | locked by `Time.get_ticks_msec()` | `session_elapsed_ms` unit | milliseconds | NOT TUNABLE — locked by engine API |

**Behavioral knobs (NOT tunable; locked by design)**:

- `game_phase` enum values = `{PLAYING, ENDING, TITLE}` — locked; adding a state is a design change, not a knob
- Validation runs synchronously on every bind/unbind — NOT deferrable (per Section C design decision)
- `vignette_cascaded` and `confirmed_slots` are write-once — invariant, not a knob

**Why so few knobs**: Session State is pure infrastructure. The game's tuning lives in content (which words, which vignettes), visual feel (#10 Cascade shimmer), and language (#12 generator). Session State just holds whatever those produce. If a dev wants to "tune" Session State, they're usually tuning one of the content systems above.

## Visual/Audio Requirements

**N/A — Session State has no direct visual or audio output.** Players perceive this system only through its derivative outputs, which are owned by other systems:

- Counter "3/5 待解" → owned by #16 Notebook UI
- Cascade-shimmer trigger → owned by #10 Cascade shimmer animation
- Dictionary panel + time display → owned by #18 Ending scene
- Signal-driven SFX (if any) → owned by #4 Audio system listening to `vignette_completed`

This GDD does not specify visual or audio because the system has none of its own. Any audio/visual budget belongs to the systems above.

## UI Requirements

**N/A — Session State has no UI of its own.** UI surfaces that display derived state (counter, dictionary, time, locked-slot visuals) are owned by the UI systems that consume Session State: #16 Notebook UI, #18 Ending scene, #17 Title screen, #20 Settings. This GDD does not specify widgets, layouts, or screen flows.

## Acceptance Criteria

All criteria in GIVEN/WHEN/THEN form, each independently testable without reading the rest of the GDD.

**AC-1 — Initialization: fresh state on game start**
GIVEN no game session is active, WHEN the player starts a new game, THEN `language_seed` holds a non-zero-sentinel integer (any int64 including 0), all 25 `binding_map` entries are null, `confirmed_slots` is empty, all 7 `vignette_cascaded` entries are false, and `game_phase` equals PLAYING.

**AC-2 — Initialization: timer snapshot taken at start**
GIVEN a new game has just started, WHEN the first frame of gameplay is entered, THEN a start-time snapshot has been recorded such that a call to `session_elapsed_ms` at any subsequent point returns a non-negative integer greater than or equal to 0.

**AC-3 — Bind: single slot updated**
GIVEN `game_phase == PLAYING` and `binding_map[slot_3] == null`, WHEN system #9 writes icon X to `slot_3`, THEN `binding_map[slot_3]` equals X and no other `binding_map` entry changes.

**AC-4 — Bind: replaces previous binding**
GIVEN `binding_map[slot_5]` holds icon A, WHEN system #9 writes icon B to `slot_5`, THEN `binding_map[slot_5]` equals B and the previous icon A is no longer in that slot.

**AC-5 — Unbind: slot set to null**
GIVEN `binding_map[slot_2]` holds icon Y, WHEN the player removes the icon from `slot_2`, THEN `binding_map[slot_2]` equals null.

**AC-6 — Phase gate: bind rejected outside PLAYING**
GIVEN `game_phase == ENDING`, WHEN system #9 attempts to write any icon to any slot, THEN `binding_map` is unchanged and no validation check fires.

**AC-7 — Vignette cascade: fires when all slots match**
GIVEN the Baker vignette has 3 slots and 2 of them are correctly bound, WHEN the player places the correct icon on the remaining slot, THEN `vignette_cascaded[baker_id]` becomes true, the Baker's slot IDs are added to `confirmed_slots`, and the `vignette_completed(baker_id)` signal is emitted exactly once.

**AC-8 — Write-once: vignette cannot un-cascade**
GIVEN `vignette_cascaded[vignette_id] == true`, WHEN validation runs again on that vignette (triggered by any subsequent bind), THEN `vignette_cascaded[vignette_id]` remains true and `vignette_completed` is NOT emitted a second time.

**AC-9 — Write-once: confirmed slot rejects removal**
GIVEN `slot_7` is a member of `confirmed_slots`, WHEN any system attempts to set `binding_map[slot_7] = null` or overwrite it, THEN Session State rejects the write and `binding_map[slot_7]` is unchanged.

**AC-10 — Atomic ordering: timer before ENDING signal**
GIVEN all 7 vignettes are cascaded and the player triggers the elder, WHEN the ENDING transition fires, THEN `session_elapsed_ms` holds a positive non-zero value AND `game_phase` is set to ENDING BEFORE any `session_ended` signal or ENDING-phase signal is emitted (observable by connecting a listener that reads `session_elapsed_ms` on signal receipt — it must never see 0).

**AC-11 — Lifecycle: state destroyed on title return only**
GIVEN the player is mid-session with 3 vignettes cascaded and `session_elapsed_ms > 0`, WHEN the player navigates to the title screen, THEN Session State is destroyed (all fields zeroed or object freed) and no prior session data is accessible.

**AC-12 — Lifecycle: state not destroyed during ENDING**
GIVEN `game_phase == ENDING` and the ending scene is rendering, WHEN the ending scene reads `session_elapsed_ms` and `confirmed_slots`, THEN both return the values set at the PLAYING→ENDING transition (state has not been destroyed or reset).

**AC-13 — Formula unresolved_count: no correct bindings**
GIVEN a 3-slot vignette where all 3 slots are null, WHEN `unresolved_count(vignette_id)` is called, THEN the return value is 3.

**AC-14 — Formula unresolved_count: partial correct bindings**
GIVEN the Baker vignette (3 slots), with NOUN_BREAD bound correctly, VERB_GIVE bound incorrectly, and ADJ_WARM null, WHEN `unresolved_count(baker_id)` is called, THEN the return value is 2.

**AC-15 — Formula unresolved_count: all correct**
GIVEN all 3 slots of a 3-slot vignette are bound to their correct icons, WHEN `unresolved_count(vignette_id)` is called, THEN the return value is 0.

**AC-16 — Formula vignette_valid: false when any slot null**
GIVEN a vignette where at least one slot is null, WHEN `vignette_valid(vignette_id)` is evaluated, THEN the result is false and no cascade transition fires.

**AC-17 — Formula vignette_valid: false when any slot wrong**
GIVEN a vignette with all slots bound but one icon is incorrect, WHEN `vignette_valid(vignette_id)` is evaluated, THEN the result is false.

**AC-18 — Formula vignette_valid: true triggers cascade**
GIVEN a vignette where every slot holds its correct icon, WHEN `vignette_valid(vignette_id)` is evaluated, THEN the result is true and the cascade transition (AC-7) fires immediately.

**AC-19 — Edge case: zero-slot vignette rejected at content load**
GIVEN authored vignette data where one NPC has 0 declared slots, WHEN Session State (or the content loader) initializes, THEN an authoring-error assertion fires (or the game refuses to start) and no vignette with 0 slots enters the active session.

**AC-20 — Edge case: seed=0 is legal**
GIVEN the procedural generator returns `language_seed = 0`, WHEN Session State stores it, THEN `language_seed` equals 0 and #12 is invoked with 0 as a valid seed (no "uninitialized" error).

**AC-21 — Edge case: correct_table bijection enforced**
GIVEN #12 produces a `correct_table` where icon X appears as the correct answer for both `slot_4` and `slot_9`, WHEN Session State or the content loader validates the table, THEN an error is raised and the session does not proceed with a non-bijective table.

**AC-22 — Signal: vignette_completed carries correct ID**
GIVEN a session with 7 distinct vignette IDs, WHEN the Weaver vignette cascades, THEN the `vignette_completed` signal is emitted with the Weaver's exact vignette ID, not a neighbor's.

**AC-23 — Performance: validation completes within budget**
GIVEN a fully populated session (7 vignettes, up to 5 slots each, all 25 binding_map entries non-null), WHEN a bind event triggers the full vignette-validation check (all 7 vignettes, max 35 comparisons), THEN the check completes in under 1ms on the target HTML5 export runtime (measurable by wrapping the call with `Time.get_ticks_usec()` before and after; delta must be < 1000).

## Open Questions

Items that this GDD does not fully resolve and must be revisited when downstream systems are designed:

| # | Question | Owner / Target Resolution | Why open |
|---|---|---|---|
| OQ-1 | What is the exact output shape of #12 procedural language generator? Is it a `slot_id → correct_icon` lookup (this GDD's assumption) or something structurally different (e.g., phonetic strings needing separate resolution)? | Resolve when #12 is designed | This GDD's validation logic depends on the shape; revisit Sections C/D/E if it differs |
| OQ-2 | Does #18 Ending scene need to display incorrect / unconfirmed bindings (a "here's what you got wrong" panel), or only confirmed dictionary? | Resolve when #18 is designed | Current contract permits direct `binding_map` read; if #18 doesn't need it, tighten the contract to `confirmed_slots` only |
| OQ-3 | Where does drag-target locking for cascaded slots live — #9 Symbol-binding (writes are blocked at input), or #16 Notebook UI (visuals don't permit drag-start)? Both? | Resolve when #9 and #16 are designed | Session State is the data-layer backstop; the UI-layer enforcement is ambiguous |
| OQ-4 | Should `correct_table` be cached inside Session State at game-start (one-shot copy from #12) or queried fresh from #12 on each validation check? | Resolve in ADR-TBD-game-session-state | Performance + ownership question; default lean is "cache at start", but #12's interface defines this |
| OQ-5 | Should the session timer pause during any in-game pause UI (settings menu, notebook overlay)? Per current design: **no** — wall-clock is honest. But once #20 Settings is designed and a pause concept exists, validate this. | Resolve when #20 Settings is designed | Currently spec'd as "no pause"; explicit confirmation needed when pause UI exists |
| OQ-6 | Implementation pattern: Autoload singleton, scoped service injected at game scene root, or ephemeral game-scene-owned struct? | Resolve in ADR-TBD-game-session-state | All three are technically feasible per gameplay-programmer feasibility check; choice affects testability and Title↔Game lifecycle handling |

**Note on OQ-4 and OQ-6**: both will be answered in the deferred ADR `ADR-TBD-game-session-state`. When that ADR is created via `/architecture-decision`, this GDD's Overview section should be updated to reference it by ID.
