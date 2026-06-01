# NPC Sprite & Tableau Rendering (#7)

> **Status**: In Design
> **Author**: solo (autonomous batch) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — NPCs ARE the world, their actions are how meaning becomes inferable
> **System Category**: Gameplay (Feature layer)
> **Game**: Lexicon Village

## Overview

NPC Sprite & Tableau Rendering owns the per-NPC visual: the static sprite at its village position, plus the short "tableau animation" each NPC plays during their vignette (baker holds bread, blacksmith strikes hammer, fisher pulls net, etc.). The animation is the visual context that lets the player infer word meanings — the baker holds bread WHILE saying `mura`, so the player can guess `mura` = bread. This system does NOT own dialogue text (that's #11), does NOT own click-detection routing (that's #2 → #8 dispatch), and does NOT own vignette state (that's #8). It owns sprite + animation. For MVP, only the baker NPC is implemented; Vertical Slice adds 3; Full Vision adds all 7. The Elder is also rendered here (no tableau animation — Elder is static; her "action" is sitting and waiting).

## Player Fantasy

The villagers are doing their work, oblivious to whether you can read what they say. The baker bakes. The blacksmith hammers. The child runs. These tableaux are the visual half of the language puzzle — without watching what they DO, the words remain unmoored. The tableau is not theatre for the player; it's the villager being themselves, and the player just happens to be watching.

**Pillar alignment**: Pillar 2 — the village's authenticity depends on NPCs feeling like inhabitants, not puzzle-pieces. Pillar 3 — NPCs do not react to the player or to whether the player has decoded their words (anti-pillar #2 from concept doc); they simply exist.

## Detailed Design

### Core Rules

**One sprite per NPC**, authored at base resolution (320×180 viewport), placed at a hand-authored position per #6 Village scene & layout. Sprite is a 2D Sprite2D or AnimatedSprite2D node.

**Each NPC has 3 sprite states**:
- `IDLE`: default standing pose (looped or static)
- `ACTION`: tableau animation playing during vignette ACTION state (driven by #8)
- `POST_CASCADE`: post-cascade idle (may differ subtly from IDLE — e.g., baker holds bread in idle pose; concept "the village still does what it does")

**Click detection**: each NPC has a Control or Area2D child for click capture. On click, fires `npc_interaction_requested(npc_id)` via #2 Input System (per #2 Section C). #7 does NOT directly call #8; #2 routes the event.

**Tableau animation contract**: when #8 vignette state machine transitions to ACTION, it calls `play_tableau(npc_id)`. #7 plays the animation; on completion, emits `tableau_complete(npc_id)` signal that #8 listens for.

**Baker tableau (MVP)**: baker picks up bread loaf, holds it up while looking right, places it on counter. ~3 seconds. Concurrent with dialogue line `Tola mura` ("give bread"). Animation loops 0 times (one-shot).

**Elder** has no tableau animation; she sits cross-legged at village center. `play_tableau(elder_id)` is a no-op that immediately emits `tableau_complete`.

### States and Transitions

Per-NPC sprite state:

| State | Active when | Transitions to |
|---|---|---|
| `IDLE` | Default / DORMANT vignette state | `ACTION` (on `play_tableau` call) |
| `ACTION` | Vignette ACTION state | `IDLE` (on animation complete) |
| `POST_CASCADE_IDLE` | Vignette CASCADED state | terminal (replays same as IDLE on revisit) |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **#6 Village scene & layout** | Upstream | Spatial parent; provides NPC position |
| **#2 Input System** | Peer | Routes NPC click → `npc_interaction_requested(npc_id)` |
| **#8 Vignette state machine** | Downstream | #8 calls `play_tableau(npc_id)`; listens for `tableau_complete(npc_id)` |
| **#5 Glyph font** | Indirect | None (NPC sprite is art, not text) |
| **#3 Camera & viewport** | Upstream | NPC sprites scale with viewport (integer-scale) |

## Formulas

No formulas. Animation timing is per-NPC authored content (Sprite2D frames or AnimationPlayer track).

**One constant**: `BAKER_TABLEAU_DURATION ≈ 3.0s` — per MVP baker spec. Other NPCs TBD when authored.

## Edge Cases

- **If** `play_tableau(npc_id)` called while NPC is already in ACTION: ignore second call; let current animation complete (don't restart).
- **If** sprite asset is missing for an NPC: render placeholder (e.g., colored ColorRect) + `push_error`. Click still works; vignette still progresses; tableau just shows the placeholder.
- **If** AnimatedSprite2D frame data is malformed: fall back to first frame as static IDLE; `push_error`.
- **If** player clicks an NPC during its ACTION state: ignored (per #8 state semantics — already in vignette flow).
- **If** Elder is clicked: `play_tableau(elder_id)` is a no-op that emits `tableau_complete` immediately; #8 receives signal and advances state. Elder has no animation but the contract is honored.
- **If** game window is small enough that NPC sprite is < 8×8 visible pixels: NPC remains clickable (Godot Control bounds), just visually tiny. Player can resize browser.

## Dependencies

**Upstream**: #6 Village, #3 Camera, #2 Input
**Downstream**: #8 Vignette state machine (calls `play_tableau`), #15 Elder climax (clicks Elder via #2/#7 routing)

**Cross-system contracts**:
1. Each NPC sprite scene must expose: `Sprite2D` or `AnimatedSprite2D` for visual + `Control` child for click capture
2. `tableau_complete(npc_id)` signal contract — emitted by #7 when animation ends
3. Elder sprite is a special case: no tableau animation; immediate `tableau_complete` on `play_tableau` call

## Tuning Knobs

| Knob | Default | Effect |
|---|---|---|
| Baker tableau duration | ~3s | Pace of baker's bread-presentation animation |
| NPC sprite size | ~16×24 px (art-bible TBD) | NPC visual scale |
| Click hitbox padding | ~2 px around sprite bounds | Forgiveness on click target |

**Locked**:
- One static + one ACTION animation per NPC (MVP/VS); no idle animations, no looped breathing/swaying (Pillar 1 design test: shimmer is the only motion)
- No NPC reaction to player gaze / approach / hover (anti-pillar #2)

## Visual/Audio Requirements

**Visual** (REQUIRED for player-facing system):
- 16×24 px NPC sprite (placeholder dimensions; lock in art bible)
- 1 baker tableau animation (~3s, multi-frame) for MVP
- Elder static sprite (no animation)
- Parchment-palette consistent with Visual Identity Anchor
- NO breathing/swaying idle animation (Pillar 1 contract)

**Audio** — none owned by #7. Foot taps, hammer strikes, etc. could be added in VS via #4 if playtest justifies; currently silent.

**📌 Asset Spec** — Visual requirements defined. After art bible is approved, run `/asset-spec system:npc-sprite-tableau` for sprite dimensions + baker tableau frame spec.

## UI Requirements

**N/A — NPC sprite has no UI of its own.** The hover/click cursor change is owned by #2/#16 conventions.

## Acceptance Criteria

**AC-1 — NPC renders at hand-authored position**
GIVEN the village scene is loaded with the baker at world position (200, 400), WHEN the scene renders, THEN the baker sprite is visible at (200, 400) and remains there until ACTION state.

**AC-2 — Click fires npc_interaction_requested**
GIVEN baker is in IDLE and game is in NORMAL state, WHEN player clicks the baker sprite, THEN `npc_interaction_requested(baker_id)` fires via #2.

**AC-3 — play_tableau triggers ACTION animation**
GIVEN baker is in IDLE, WHEN #8 calls `play_tableau(baker_id)`, THEN sprite state transitions to ACTION and the baker's tableau animation begins playing.

**AC-4 — tableau_complete signal fires on animation end**
GIVEN baker is in ACTION mid-animation, WHEN the animation completes (~3s for baker), THEN `tableau_complete(baker_id)` is emitted.

**AC-5 — Duplicate play_tableau ignored**
GIVEN baker is in ACTION mid-animation, WHEN #8 calls `play_tableau(baker_id)` again (defensive case), THEN the second call is ignored; current animation continues; `tableau_complete` fires once.

**AC-6 — Elder play_tableau is immediate no-op**
GIVEN Elder is rendered (no animation), WHEN #8 calls `play_tableau(elder_id)`, THEN `tableau_complete(elder_id)` fires in the same frame (no animation to wait for).

**AC-7 — Missing sprite renders placeholder**
GIVEN an NPC's sprite asset file is missing, WHEN the village scene loads, THEN a ColorRect placeholder renders at the NPC's position, click still works, `push_error` logged.

**AC-8 — No idle animation (Pillar 1 contract)**
GIVEN baker is in IDLE for 10 continuous seconds, WHEN visually inspected, THEN no breathing, swaying, or other looped motion is observed. The only motion permitted on the NPC is the ACTION tableau when explicitly triggered.

**AC-9 — Sprite scales with viewport integer scale**
GIVEN viewport is at 2× scale (640×360), WHEN baker sprite renders, THEN sprite displays at 2× its base size with no sub-pixel blur (per #3 BASE_RESOLUTION + NEAREST filter contract).

**AC-10 — POST_CASCADE_IDLE renders same as IDLE (subtle differentiation TBD)**
GIVEN baker is in CASCADED vignette state, WHEN sprite renders, THEN sprite displays in POST_CASCADE_IDLE state — visually identical to IDLE for MVP; future may add subtle differentiation (e.g., baker holds bread in idle pose). MVP: IDLE = POST_CASCADE_IDLE.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Should POST_CASCADE_IDLE visually differ from IDLE (e.g., baker holds bread)? | Resolve via playtest + art bible |
| OQ-2 | Click hitbox — sprite-tight or padded? | Resolve via playtest — likely 2-4 px padding for forgiveness |
| OQ-3 | Sprite art style — graphic-novel ink (Chants of Sennaar) vs watercolor (Heaven's Vault)? | Resolve in `/art-bible` |
| OQ-4 | Should NPCs cast subtle shadows for spatial grounding? | Resolve in art bible; may violate "shimmer is only motion" if shadow length suggests time-of-day |
