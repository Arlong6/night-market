# Vignette Content: Baker (#13 — MVP Quick-Spec)

> **Status**: In Design (Quick-Spec)
> **Author**: solo (autonomous batch) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — concrete content per NPC; Pillar 1 (Discovery) — baker is first vignette, defines the "aha factory" baseline
> **System Category**: Narrative (Feature layer) — **MVP CONTENT** (baker only; other NPCs in VS+)
> **Game**: Lexicon Village

> **Note on scope**: This is a **quick-spec** for the baker only (MVP scope per systems-index). Full vignette-content authoring (all 7 NPCs) is a Vertical Slice / Alpha incremental task. Each NPC will have its own quick-spec document following this template.

## Overview

This document defines the **baker vignette content** — the concrete data the Vignette State Machine (#8) and Dialogue Display (#11) need to play out the baker's interaction. The baker is the **MVP-only** vignette: the first NPC the player meets, the system's proof-of-concept, the demo for the "aha factory" claim. Baker vignette exposes 3 semantic slots: `NOUN_BREAD`, `VERB_GIVE`, `ADJ_WARM` (per `lexicon-village-elder-question.md §3 row Baker`). Tableau: baker holds bread, gives it to a silent customer NPC, touches the warm bread.

## Baker Vignette Spec

### Semantic Slots (3)

| Slot ID | Meaning | Glyph (seed-derived; placeholder string for design) |
|---|---|---|
| `NOUN_BREAD` | bread / staple food | `mura` |
| `VERB_GIVE` | give / offer | `tola` |
| `ADJ_WARM` | warm | `ven` |

### Tableau (visual sequence)

1. **Baker holds bread** (0.0–1.0s) — baker sprite lifts a bread loaf into view, looks at it
2. **Customer approaches, baker gives bread** (1.0–2.5s) — silent customer NPC walks in from screen edge; baker hands bread; customer nods, walks off
3. **Baker touches warm bread on counter** (2.5–3.0s) — baker rests hand on a second loaf, slight reaction (subtle wave or eye-close to suggest warmth)

Total: ~3 seconds. Owned by #7 NPC sprite & tableau; this document specifies WHAT happens, not HOW it animates.

### Dialogue Token Sequences

**INTRO line** (played during state INTRO per #8):
```
tokens = [
  { type: LEXICON_SLOT, value: &"NOUN_BREAD" },     # "mura"
  { type: PUNCTUATION, value: "." }
]
```
Translation when fully resolved: "Bread."

**ACTION lines** (played during state ACTION per #8, concurrent with tableau):
```
# Line 1 (concurrent with "baker gives bread to customer"):
tokens = [
  { type: LEXICON_SLOT, value: &"VERB_GIVE" },      # "tola"
  { type: LEXICON_SLOT, value: &"NOUN_BREAD" },     # "mura"
  { type: PUNCTUATION, value: "." }
]
# Translation when resolved: "Give bread."

# Line 2 (concurrent with "baker touches warm bread"):
tokens = [
  { type: LEXICON_SLOT, value: &"ADJ_WARM" },       # "ven"
  { type: LEXICON_SLOT, value: &"NOUN_BREAD" },     # "mura"
  { type: PUNCTUATION, value: "." }
]
# Translation when resolved: "Warm bread."
```

**CLOSING line** (state CLOSING per #8):
```
tokens = [
  { type: LEXICON_SLOT, value: &"VERB_GIVE" },      # "tola"
  { type: LEXICON_SLOT, value: &"NOUN_BREAD" },     # "mura"
  { type: PART_Q, value: "ka" },                    # question particle "ka?"
  { type: PUNCTUATION, value: "?" }
]
# Translation when resolved: "Give bread?" (invitational — "for you?")
```

Note: `PART_Q` is grammar particle "ka" — taught via cross-vignette context (per keystone §3). Not a baker slot, but appears in baker dialogue as exposure. Players who later encounter `ka` in other NPC questions can infer "ka = ?" via triangulation.

### Post-Cascade Revisit Idle Line (per #14 contract)

```
tokens = [
  { type: LEXICON_SLOT, value: &"VERB_GIVE" },      # "tola"
  { type: LEXICON_SLOT, value: &"NOUN_BREAD" },     # "mura"
  { type: PART_Q, value: "ka" },
  { type: PUNCTUATION, value: "?" }
]
# Translation when resolved: "Give bread?" (offered as invitation — baker keeps offering)
```

This is the same as CLOSING line — baker continues to offer bread to anyone passing, regardless of decoded state. This is **not** a state change in response to the player (anti-pillar #2); it's the baker continuing to be herself. The same line is shown every revisit.

### World Position (for #10 Cascade shimmer origin)

```
baker_world_position = Vector2(120, 100)  # within 320×180 village; ~left-third, mid-height
```

This is the ripple origin for baker's cascade per #10 Formula 2.

### Vignette ID & Slot Mapping (per #19 + keystone §3)

```
vignette_id = &"BAKER"
slots = [&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM"]
```

`unresolved_count(BAKER)` returns 0–3 based on how many of these slots are correctly bound (per #19 Formula 1).

## Authoring Constraints (per cross-system specs)

- **Per #10 EC-11**: baker MVP scene MUST include ≥2 on-screen instances of at least one decoded word for cascade to feel like "spreading." Achieved via: 3 dialogue lines (INTRO + 2 ACTION + CLOSING) all featuring `NOUN_BREAD`. On cascade, `NOUN_BREAD` shimmers in all visible instances simultaneously. Cascade origin (baker position) + multiple text positions = visible spread.
- **Per #8 AC-13**: each vignette content entry must have non-null token sequences. This baker entry satisfies that.
- **Per #19 zero-slot edge case**: baker has 3 slots (>0). No zero-slot violation.
- **Per #12 bijection rule (when generator implemented)**: each slot's glyph string must be unique. For MVP hand-authored: `mura ≠ tola ≠ ven`. Verified.

## Dependencies on Other Systems

| System | What this content needs from it |
|---|---|
| **#8 Vignette state machine** | Consumes intro/action/closing tokens; reads `slots` list for `vignette_completed` triggering |
| **#11 Dialogue display** | Renders tokens via `show_line()` |
| **#10 Cascade shimmer** | Uses `baker_world_position` for ripple origin |
| **#19 Session State** | Validates baker slots against `correct_table` |
| **#12 Procedural language generator** | Currently provides hard-coded `mura/tola/ven` for MVP; later seeds will re-roll these strings |
| **#7 NPC sprite & tableau** | Plays the baker tableau animation |
| **#21 Localization** | Provides decoded UI strings: `LOC_SLOT_NOUN_BREAD = "麵包"` / `"bread"`, etc. |

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Should silent customer NPC have a distinct sprite, or be a "ghost" silhouette? | Resolve in `/art-bible` |
| OQ-2 | "ven" appears only once in baker dialogue (ACTION line 2). Is one exposure enough for player to infer "warm"? Or does the player need to revisit the line in history? | Resolve via playtest of baker MVP |
| OQ-3 | Customer's nod / reaction — does customer have dialogue? Spec says silent (no tokens). Confirm. | Confirmed silent per concept doc + this spec |
| OQ-4 | Localization of decoded forms — "麵包" vs "bread" — language toggle in #20 Settings? | Resolve in #21 Localization design |

## Future NPCs (VS / Alpha placeholders)

| NPC | Vignette ID | Slots | Status |
|---|---|---|---|
| Baker | `BAKER` | NOUN_BREAD, VERB_GIVE, ADJ_WARM | **MVP — this document** |
| Blacksmith | `BLACKSMITH` | NOUN_IRON, NOUN_HAMMER, VERB_MAKE | VS quick-spec TBD |
| Fisher | `FISHER` | NOUN_WATER, NOUN_FISH, VERB_COME | VS quick-spec TBD |
| Weaver | `WEAVER` | NOUN_CLOTH, VERB_WEAVE, ADJ_LONG | Alpha quick-spec TBD |
| Child | `CHILD` | ADJ_SMALL, VERB_PLAY, NOUN_FRIEND | Alpha quick-spec TBD |
| Traveler | `TRAVELER` | NOUN_PATH, ADJ_FAR, NOUN_STRANGER | Alpha quick-spec TBD |
| Storyteller | `STORYTELLER` | VERB_REMEMBER, NOUN_PLACE, PREFIX_PAST | Alpha quick-spec TBD |

Each future NPC quick-spec follows this baker template structure.
