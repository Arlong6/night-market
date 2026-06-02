# Procedural Lexicon Generator (#12)

> **Status**: In Design (VS scope, first implementation)
> **Author**: solo (autonomous batch) + skill orchestration
> **Last Updated**: 2026-06-02
> **Implements Pillar**: Pillar 2 (Language IS the World) — every playthrough generates a fresh lexicon, so the world's language feels truly invented, not a fixed asset
> **System Category**: Gameplay (Feature layer) — **VS SCOPE** (MVP uses hard-coded SEED_GLYPHS)
> **Game**: Lexicon Village

## Overview

The Procedural Lexicon Generator produces a deterministic mapping `slot_id → glyph_string` from an integer seed. MVP hard-codes 20 glyphs in `LVVignetteContent.SEED_GLYPHS`. VS introduces this generator to make every playthrough's "made-up language" different while preserving phonological consistency (so glyphs feel like a single coherent language, not random noise). The generator runs once at session start, populates a runtime dictionary stored on Session State, and Dialogue Display + Notebook UI consult that runtime dict instead of the const SEED_GLYPHS.

## Player Fantasy

You start a new run. The baker greets you with `kelo mura.` Three runs ago she said `nato mura.` Five runs ago `mira pora.` It's a different language each time — and yet every time it FEELS like a language, with its own consonant cadence, its own vowel weight. You start to recognize the *shape* of how this run's language thinks: this one is heavy on `k` and `o`, last run was thin and full of `i`. The procedural generator is invisible work; what the player feels is "this world has its own native language, and I'm learning a fragment of it."

## Detailed Design

### Core Rules

**Rule 1 — Deterministic from seed.** Same seed + same slot_id set → identical glyph dictionary, bit-for-bit. Required for save/restore, share-codes, and reproducible bug reports.

**Rule 2 — Phonologically consistent within a run.** All 20 glyphs in a single generation share the same phoneme inventory and syllable rules. (Different seeds may pick different inventories.)

**Rule 3 — Collision-free.** No two slot_ids map to the same glyph string. Retry with seed perturbation up to MAX_COLLISION_RETRIES; if exceeded, push_error and fall back to numeric suffixes.

**Rule 4 — Stable POS shape.** Nouns are 2-3 syllables. Verbs are 1-2 syllables. Adjectives are 1 syllable. POS is inferred from slot_id prefix (`NOUN_*`, `VERB_*`, `ADJ_*`, `PART_*`).

**Rule 5 — Pronounceable.** Each generated word follows a simple (C)V(C)V(C) syllable structure — no consonant clusters, no triple vowels. Player-readable at first glance.

**Rule 6 — Does not mutate MVP fallback.** `LVVignetteContent.SEED_GLYPHS` remains the design-time / unit-test fallback. The generator produces an alternative runtime dictionary that takes priority when present.

### Phonology

**Consonant inventory** (10 phonemes; per-seed picks 5-7):
`m, n, t, k, p, v, s, r, l, d`

**Vowel inventory** (5 phonemes; per-seed picks 3-5):
`a, e, i, o, u`

**Syllable patterns**:
- `CV`  (default, most common — 70%)
- `CVC` (closing consonant; 20%; only certain consonants — `n, l, m, k, t` — can close)
- `V`   (vowel-initial; 10%; word-start only)

**Word patterns by POS**:
- Noun: `CV + CV` or `CV + CV + CV` (2-3 syllables)
- Verb: `CV` or `CV + CV` (1-2 syllables)
- Adjective: `CV` or `CVC` (1 syllable)
- Particle (e.g. `ka`): `CV` (1 syllable)

### States and Transitions

The generator is stateless (pure function). Holds no state; the result Dictionary lives on LVSessionState.

## Formulas

**Formula 1 — Per-slot seed**
`slot_seed = hash(global_seed) ^ hash(slot_id)`

Where `hash()` is `String.hash()` for stable cross-platform behavior.

**Formula 2 — Phoneme pick**
`phoneme = inventory[slot_seed % inventory.size()]; slot_seed = slot_seed * 1103515245 + 12345` (linear congruential PRNG step)

LCG constants chosen for simplicity and adequate distribution at lexicon scale.

**Formula 3 — Syllable count by POS**
| POS | min | max |
|---|---|---|
| NOUN | 2 | 3 |
| VERB | 1 | 2 |
| ADJ | 1 | 1 |
| PART | 1 | 1 |

`syllable_count = min + (slot_seed % (max - min + 1))`

**Formula 4 — Collision retry**
On collision, perturb `slot_seed = slot_seed * 2654435769 + 1` and re-generate that single slot. Up to `MAX_COLLISION_RETRIES = 16` attempts. If exhausted, append `_N` numeric suffix where N is the collision count.

## Edge Cases

- **EC-1 — Empty slot set**: returns empty Dictionary; no error.
- **EC-2 — Unknown POS prefix** (e.g., `MYS_FOO`): defaults to ADJ shape (1 syllable, CVC allowed). Logs a `push_warning`.
- **EC-3 — Seed = 0**: legal seed; produces a deterministic output. Not treated as "no seed."
- **EC-4 — Collision storm** (e.g., inventory too small for slot count): on `MAX_COLLISION_RETRIES` exhaustion, suffix-with-N as fallback (`mura`, `mura_2`, `mura_3`). Logs `push_error` once per affected slot.
- **EC-5 — Negative seed**: `abs(seed)` then proceed normally.
- **EC-6 — Inventory minimum**: if random pick selects a vowel set smaller than 3, force-include `a, i, u` as defaults to guarantee minimum diversity.

## Anti-Patterns (DO NOT IMPLEMENT)

- ❌ **NO real-language dictionaries.** No actual Finnish, Hawaiian, Esperanto roots — generator must produce strings that look invented, not derivative. (Players who recognize "tolto" as Hungarian for "filled" lose the fantasy.)
- ❌ **NO mid-run regeneration.** Glyph dict is built once at session start. Re-running with same seed midrun is wasted work and risks identity drift if Session State changes phase.
- ❌ **NO collision-fix-by-renaming-known-slot.** Always retry the *new* slot; never alter an already-assigned glyph (would invalidate prior dialogue history).

## Dependencies

| System | Direction | Interface | Type |
|---|---|---|---|
| **#19 Session State** | Downstream | Stores generated dict in `_runtime_glyphs: Dictionary` | Hard |
| **#13 Vignette content** | Downstream | `render_slot_text()` consults runtime dict before SEED_GLYPHS const | Hard |
| **#11 Dialogue display** | Indirect | Re-renders via #13 paths | Soft |
| **#16 Notebook UI** | Indirect | Re-renders via #13 paths | Soft |

**Integration contract**:
1. LVSessionState.init_session(seed, ...) calls `LVProcGen.generate_glyphs(seed, slot_ids)` and stores result.
2. LVVignetteContent.render_slot_text(slot_id, is_confirmed, runtime_override: Dictionary = {}) consults override first, falls back to SEED_GLYPHS.
3. LVDialogueDisplay passes `_session_state.get_runtime_glyphs()` (empty dict default) to render path.

## Tuning Knobs

| Knob | Default | Range | Effect |
|---|---|---|---|
| `CONSONANT_INVENTORY_SIZE_MIN` | 5 | 4–10 | Smaller = more glyph repetition feel |
| `CONSONANT_INVENTORY_SIZE_MAX` | 7 | 5–10 | Larger = wider phoneme palette |
| `VOWEL_INVENTORY_SIZE_MIN` | 3 | 3–5 | Smaller = denser sound texture |
| `VOWEL_INVENTORY_SIZE_MAX` | 5 | 3–5 | Larger = airier sound texture |
| `MAX_COLLISION_RETRIES` | 16 | 4–64 | Higher = better collision avoidance at cost of generation time |
| `CV_PROB` | 0.7 | 0.5–0.9 | Probability of CV (vs CVC) syllable; lower = more closed syllables |
| `V_INITIAL_PROB` | 0.1 | 0.0–0.3 | Probability a word starts with bare vowel |

## Visual/Audio Requirements

None — generator is pure data.

## UI Requirements

None directly. The runtime glyphs surface through #11 / #16 once integrated.

## Acceptance Criteria

**AC-1 — Same seed produces same output**
GIVEN seed=42 and 20 slot_ids, WHEN generate is called twice, THEN both Dictionaries are equal.

**AC-2 — Different seeds produce different outputs**
GIVEN seed=42 and seed=43 on the same 20 slot_ids, WHEN both generate, THEN at least 80% of generated glyphs differ.

**AC-3 — No collisions in default cases**
GIVEN 20 slot_ids and 100 different seeds, WHEN generate runs for each, THEN no two slots within the same seed map to the same glyph (assert across all 100 runs).

**AC-4 — POS-respecting syllable counts**
GIVEN a slot_id starting with `NOUN_`, WHEN generate runs, THEN the glyph has 2 or 3 syllables (2-3 vowels by count).
GIVEN slot_id `VERB_X`, glyph has 1-2 syllables. GIVEN `ADJ_X`, glyph has 1 syllable.

**AC-5 — All consonants from picked inventory**
GIVEN a seed-derived consonant inventory, WHEN generate runs, THEN every consonant in every generated glyph appears in the picked inventory.

**AC-6 — All vowels from picked inventory**
Same as AC-5 for vowels.

**AC-7 — Empty slots returns empty dict**
GIVEN slot_ids = [], WHEN generate runs, THEN result is empty Dictionary.

**AC-8 — Determinism crosses platform / engine restart**
GIVEN seed=42 stored from session A, WHEN session B (separate process) regenerates with seed=42, THEN result is bit-identical.

**AC-9 — MVP fallback intact**
GIVEN LVVignetteContent.SEED_GLYPHS const, WHEN procedural generator is not invoked, THEN render_slot_text uses SEED_GLYPHS exactly as today (no regression).

**AC-10 — Collision storm gracefully degrades**
GIVEN 100 slot_ids and a deliberately narrow inventory (2 consonants, 2 vowels), WHEN generate runs, THEN no crash; collided slots use `_N` suffix; push_error logged per affected slot.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Should the resolved-form Chinese localization also be procedural (e.g., `麵包` → `麵食`)? | NO — resolved form is the player's UI language; only the un-decoded glyph is procedural. (Closed.) |
| OQ-2 | Does Particle slot (`PART_Q` "ka") need fancier handling — should it stay a true particle vs becoming a CV? | MVP: treat as CV (1-syllable). Revisit if cadence reads wrong in playtest. |
| OQ-3 | Integration with #16 Notebook UI's icon palette — should icons change per-seed too, or only glyphs? | Defer to VS+ — icons stay fixed for MVP (player-side visual palette consistency). |
| OQ-4 | Should the CV_PROB/V_INITIAL_PROB themselves be seed-derived (each run has its own "phonological style") or globally fixed? | **MVP: seed-derived** — that's where most of the per-run identity comes from. |

## Integration Plan (this implementation deliverable)

Phase A (this session — VS-1):
- ✅ Static generator API: `LVProcGen.generate_glyphs(seed, slot_ids) -> Dictionary`
- ✅ Phonology constants + helpers
- ✅ Unit tests covering ACs 1-7 + 10

Phase B (next session):
- Wire `_runtime_glyphs` into LVSessionState
- Update LVVignetteContent.render_slot_text to consult override
- Update LVDialogueDisplay + LVNotebookUI render paths
- Integration test with baker vignette using a non-default seed

Phase C (Alpha/Full Vision):
- Per-seed CV_PROB / V_INITIAL_PROB derivation
- Save/restore seed via LVSessionState persistence
- Share-code UX (player can share their "language" with another player)
