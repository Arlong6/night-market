# Village Scene & Layout (#6)

> **Status**: In Design
> **Author**: solo (autonomous batch) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — the village's spatial form is the world's first artifact; Pillar 3 (No Failure) — no platforming, no failable navigation
> **System Category**: Gameplay (Core layer)
> **Game**: Lexicon Village

## Overview

Village Scene & Layout is the spatial container for the game's playable world. It is a single screen showing all 7 NPC positions (Baker, Blacksmith, Fisher, Weaver, Child, Traveler, Storyteller) plus the Elder at the village center. There is no scrolling, no exploration mechanic, no platforming — the player sees the whole village from minute one and navigates it via simple click-to-approach NPC interactions. The layout is **hand-authored** (not procedural); each NPC has a fixed position chosen to make the village legible as a *place* (the baker near the market, the fisher near water, the storyteller in shade, etc.). The Elder waits at the village center from boot, visible but only meaningfully interactable once all 7 vignettes have cascaded (the "elder waits for you to be ready" framing from concept doc). MVP includes only the Baker position + the Elder placeholder; Vertical Slice adds 3 NPCs; Full Vision adds all 7.

## Player Fantasy

The village should feel like an old painting that you can walk into — the kind that's small enough to know completely by the time you leave. Players see the whole world at once on first load: a shallow valley with a bakery, a forge, a riverbank, a weaver's porch, a child running between buildings, a traveler at the gate, an old woman under a tree, and an elder at the center waiting. Nothing is hidden behind exploration; the *language* is what's hidden. The space is just the room in which the language is spoken.

**Pillar alignment**: serves Pillar 2 (Language IS the World) — the spatial composition reinforces "this is a real place with people doing things." Serves Pillar 3 (No Failure) by having no traversal failure modes (no falling, no getting lost, no maze).

## Detailed Design

### Core Rules

**Single-screen composition**: village fits entirely within the 320×180 base viewport (#3). No scrolling, no camera follow. The whole village is always visible.

**Hand-authored NPC positions**: each NPC has a fixed `(x, y)` position authored in the scene file. Positions reflect their role (baker near oven, fisher at river edge, etc.) and ensure no two NPCs overlap visually.

**NPC click-to-interact**: clicking an NPC sprite fires `npc_interaction_requested(npc_id)` via #2 Input System. #7 NPC sprite & tableau owns the click-detection on each sprite Control; #6 owns the spatial layout.

**Elder visibility from minute one** (per concept Retention Hooks line 165): the Elder is always rendered at the village center. Pre-cascade-completion, clicking the Elder produces a single line of dialogue (e.g., elder says one untranslatable word — `nai` perhaps? or simply nods silently). Post-all-7-cascade, clicking the Elder triggers #15 Elder climax flow.

**Background composition**: village background is a static painted layer (parchment/sun-bleached palette per Visual Identity Anchor). No animated background elements (per Pillar 1 design test "shimmer is the only motion").

**No collision, no walkable grid**: this is a click-to-interact game, not a walk-around RPG. The player doesn't move a character through the village. The player's "presence" is the cursor + their attention. (This is a major departure from the Night Market RPG, which had grid-snap player movement. Lexicon Village has no avatar.)

### States and Transitions

The village scene has no runtime states beyond being loaded or not (managed by #1 Boot). Per-NPC state (talked-to / vignette-complete) is owned by #8 Vignette state machine and #19 Session State, not by the village layout itself.

| Phase | Behavior |
|---|---|
| Scene loaded (PLAYING) | All NPC sprites + Elder visible; clicks routed via #2 |
| Mid-cascade | NPCs remain visible; cascade animates over background + dialogue (per #10) |
| Phase = ENDING | Village scene frozen or freed by #1 Boot; #18 Ending scene takes over |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **#1 Boot & scene flow** | Upstream | Boot instantiates the Village scene at Title→Game |
| **#3 Camera & viewport** | Upstream | Village fits 320×180; Camera2D placed at village center |
| **#7 NPC sprite & tableau** | Peer | Each NPC is a child scene of Village; positions hand-authored |
| **#2 Input System** | Peer | Routes click events to NPC sprite Controls |
| **#10 Cascade shimmer** | Peer | Shimmer animates over village layer (text on signs, banners — Full Vision); MVP has no in-world text instances |
| **#15 Elder climax** | Downstream | Elder click post-7-cascade triggers climax |
| **#18 Ending scene** | Peer | Village scene freed or frozen when ENDING begins |

## Formulas

No formulas. The village is hand-composed visual content.

**One sizing constant**: `VILLAGE_DIMENSIONS = Vector2i(320, 180)` — matches #3 BASE_RESOLUTION exactly. No oversize, no scroll.

## Edge Cases

- **If** the village scene file is missing or corrupt: #1 Boot's boot-error handling fires (per #1 AC-12).
- **If** an NPC sprite Control overlaps with another at runtime (authoring error): the click hits whichever is z-ordered on top. **Authoring constraint**: NPC positions must not overlap; manual visual inspection during scene authoring.
- **If** the player clicks an empty area of the village background: no event fires. No "movement target" interpretation. Click is consumed by background Control's default no-op.
- **If** the player clicks the Elder before all 7 vignettes are cascaded: Elder fires its pre-climax line (a brief `nai?` or equivalent untranslatable nod). Does NOT trigger #15.
- **If** the player clicks an NPC during DIALOGUE_OPEN with another NPC: ignored (per #2 modal layer absorption).
- **If** the village renders before all NPC sprites are loaded (race condition during boot): scene shows background only momentarily; NPCs appear as they ready. Acceptable visual; no crash.
- **If** the player resizes the browser window: village scales per #3 (integer-multiple letterboxing). Click coordinates auto-adjust through Godot's input system; no manual scaling needed.

## Dependencies

**Upstream**:
- #1 Boot — instantiates this scene
- #3 Camera & viewport — defines the rendering frame

**Peer / Concurrent**:
- #7 NPC sprite & tableau — each NPC is a child node
- #2 Input System — routes clicks to NPCs

**Downstream**:
- #10 Cascade shimmer — animates over village layer (Full Vision)
- #15 Elder climax — Elder click triggers
- #18 Ending scene — replaces village on ENDING

**Cross-system contracts**:
1. #7 GDD must define NPC sprite Control structure that fits the village's hand-authored positions
2. #15 GDD must define how Elder click is routed (likely directly via NPC click → #15 listens for `npc_interaction_requested(elder_id)` after detecting all-7-cascaded)

## Tuning Knobs

| Knob | Default | Range | Effect | Owner |
|---|---|---|---|---|
| NPC positions | hand-authored per NPC | locked to 320×180 viewport | Visual composition of the village | #6 (per-NPC scene file) |
| Elder position | viewport center (160, 90) | (~140-180, ~80-100) | Anchors the "central waiting figure" | #6 |
| Number of NPCs | 1 (MVP) → 3 (VS) → 7 (FV) | per tier | Scope tier progression | #6 + #13 Vignette content authoring |
| Background visual | hand-painted parchment scene | locked to art bible | Visual identity of village | Art Bible (when authored) |

**Locked behaviors (not tunable)**:
- Single screen, no scrolling
- No player avatar / no character movement
- No procedural generation (every playthrough has identical village)
- Hand-authored NPC positions (no procedural placement)

## Visual/Audio Requirements

**Visual** — REQUIRED, owned jointly with art bible:
- **Background art**: 320×180 painted scene showing village layout (bakery, forge, river, weaver's porch, gate, central area). Parchment palette per Visual Identity Anchor. Static, no animated elements.
- **NPC positions visible**: each NPC's sprite (~16×24 px, per art-bible-TBD) placed so all 8 figures (7 NPCs + Elder) are visible without overlap.
- **No animated background**: trees don't sway, water doesn't ripple, no smoke from forge. Per Pillar 1 design test "shimmer is the only motion."

**Audio** — NONE in MVP. Optional ambient track (#4) plays over the scene in VS+.

**📌 Asset Spec** — Visual requirements are defined. After art bible is approved, run `/asset-spec system:village-scene-layout` for the background painting + NPC position grid spec.

## UI Requirements

**N/A — Village has no UI of its own.** UI elements (HUD-like indicators, if any) are owned by #16 Notebook UI (overlay) and #11 Dialogue display (overlay).

## Acceptance Criteria

**AC-1 — Village fits viewport without scrolling**
GIVEN the Village scene is loaded, WHEN rendered at any integer scale of 320×180, THEN all 7 NPCs + Elder + background fit entirely within the viewport with no scroll, no clipping, no out-of-bounds elements.

**AC-2 — All NPCs visible without overlap**
GIVEN the Village scene is loaded, WHEN visually inspected, THEN no two NPC sprites overlap; each NPC's clickable bounding box is unambiguous.

**AC-3 — Elder visible from boot**
GIVEN the player has just entered the Game scene (Title→Game transition completed), WHEN the village renders, THEN the Elder sprite is visible at the village center; player can see it on first frame.

**AC-4 — NPC click fires npc_interaction_requested**
GIVEN the player is in NORMAL state (no dialogue, no notebook), WHEN they click an NPC sprite (e.g., the Baker), THEN `npc_interaction_requested(baker_id)` fires via #2 with the correct NPC id.

**AC-5 — Empty background click is a no-op**
GIVEN the player is in NORMAL state, WHEN they click an empty area of the village background (not on any NPC), THEN no event fires, no animation plays, no state change.

**AC-6 — Elder pre-cascade returns minimal dialogue**
GIVEN fewer than 7 vignettes have cascaded, WHEN the player clicks the Elder, THEN the Elder shows a single placeholder line (e.g., one untranslatable token or silent nod) and does NOT trigger #15 Elder climax flow.

**AC-7 — Elder post-cascade triggers climax**
GIVEN all 7 vignettes are in `confirmed_slots` (`game_phase == PLAYING` still), WHEN the player clicks the Elder, THEN #15 Elder climax flow is triggered (Elder asks the final question, binary answer cards appear).

**AC-8 — Window resize preserves click accuracy**
GIVEN the player resizes the browser from 640×360 to 1280×720, WHEN they click on the Baker's sprite position, THEN the click maps to the correct in-world coordinates (no off-by-scale errors); `npc_interaction_requested(baker_id)` fires as expected.

**AC-9 — No animated background elements**
GIVEN the village scene is loaded and rendering at 60fps, WHEN inspected over 5 seconds with no player interaction, THEN no background element animates (no swaying, no rippling, no breathing). The only motion permitted is the cascade-shimmer when triggered by a vignette completion.

**AC-10 — Village frozen during ENDING phase**
GIVEN `game_phase == ENDING`, WHEN the player attempts to click any NPC (including the Elder), THEN no `npc_interaction_requested` event fires; the village layer is non-interactive (per #1 Boot's CUTSCENE-equivalent lock).

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Should the Elder's pre-cascade dialogue be a single untranslatable glyph token, or silent (just nods)? | Resolve via playtest of MVP + #13 vignette content authoring |
| OQ-2 | Village background art style — closer to *Chants of Sennaar*'s graphic-novel ink, or to *Heaven's Vault*'s watercolor wash? | Resolve in `/art-bible` when authored |
| OQ-3 | Does the village have any environmental text (signs, shop banners)? Concept doc mentions shimmer applying to "signs and shop banners" but MVP scope omits them | Resolve at VS scope decision (likely add 1-2 banner instances for shimmer demo) |
| OQ-4 | NPC sprite scale — 16×24 px is a placeholder; actual scale TBD with art bible | Resolve in art bible |
| OQ-5 | Click affordance on NPCs — cursor change on hover? Visible name label? Or pure visual silence (player learns by trial)? | Resolve via playtest; default lean = cursor change only, no label |
