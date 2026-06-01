# Symbol-to-Meaning Binding (#9)

> **Status**: In Design
> **Author**: solo (user-driven autonomous batch) + systems-designer + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — gesture realizer for "writing the reading of the language"; Pillar 3 (No Failure) — confirmed slots lock without ceremony
> **System Category**: Gameplay (Core layer) — **BOTTLENECK** (depended on by #8, #15, #16, #18)
> **Game**: Lexicon Village

## Overview

Symbol-to-Meaning Binding is the gesture layer that lives inside Notebook UI (#16). Its sole job is to translate the player's physical act — picking up a meaning-icon from the palette, carrying it, placing it on a glyph slot — into a write to `binding_map[slot_id]` in Game Session State (#19). The system owns the full gesture lifecycle: hover lift, pick-up animation, carry state, slot-drop settle, swap path, and confirmed-slot rejection. It is emphatically NOT responsible for the data structure being written (lives in #19), the correctness of the binding (validated by #19 synchronously on write), the cascade shimmer (owned by #10), the unresolved counter display (owned by #16 reading #19), or the event capture that detects the player's click/drag (owned by #2, which routes those events to #9 as named signals). #9 is the bridge: it takes `slot_assignment_changed(slot_id, icon_id)` from #2, reads `confirmed_slots` from #19 to decide whether to accept or reject, writes `binding_map[slot_id] = icon_id` to #19 on acceptance, and drives the visual state of every slot and carried icon to match. Implementation pattern (subscribes to #2 signals vs. called by #16's Control `_gui_input`) is **TBD — see ADR-TBD-input-routing**. The 25 semantic slots are authoritative in `lexicon-village-elder-question.md §3`.

## Player Fantasy

#2's Player Fantasy established the frame: **quiet authorship**. The player is not solving; they are writing their reading of the language. #9 is the gesture realizer for that frame. When the player lifts a meaning-icon, it rises 4px off the palette and follows the cursor like a thought held in suspension — not magnetized to slots, not cheerful. When they place it, it settles with a small drop and rests. That settle IS the utterance. The pen does not applaud the sentence; it just stops moving.

The confirmed-slot lock must carry the same quality: a locked slot looks like a completed sentence in a handwritten notebook — ink dried, the line unalterable. It does not pulse or warn. It simply does not respond to touch. The player who tries to move a confirmed icon feels what a scholar feels when they re-read a conclusion they reached an hour ago: it is not available for revision. That is not failure; that is the weight of having decided.

## Detailed Design

### Core Rules

**Icon Pick-Up**: When #2 emits `slot_assignment_changed` or the player clicks a palette icon (via #16's `_gui_input`), #9 sets the icon to CARRIED state. A carried icon follows the cursor at z-index above all other elements. Only one icon can be CARRIED at a time (enforced in #9, not #19). If an icon is already CARRIED when a second pick-up fires, the first icon is silently returned to its origin before the second is picked up (no event, no sound). Pick-up from an occupied non-confirmed slot lifts the icon out, `slot_cleared(slot_id)` fires, `binding_map[slot_id] = null`, and icon enters CARRIED.

**Icon Placement**: When a CARRIED icon is released over a valid slot:
1. #9 checks `confirmed_slots` in #19. If slot is confirmed, reject (see Confirmed-Slot Rejection).
2. If slot is OCCUPIED but not confirmed: SWAP path (existing icon returns to palette, then proceed).
3. #2 emits `slot_assignment_changed(slot_id, icon_id)`. #9 writes `binding_map[slot_id] = icon_id` to #19.
4. Icon transitions to SLOT_FILLED with settle animation (`SETTLE_DURATION_MS` = 80ms ease-out).
5. #9 does NOT trigger cascade check — that runs in #19 synchronously on the write.

Release over invalid target: snap-back via `DRAG_SNAP_BACK_DURATION_MS` (120ms ease-in-out, inherited from #2). No event fires.

**Swap Behavior**: Placing CARRIED icon onto already-filled non-confirmed slot:
1. Existing icon returns to PALETTE_IDLE at its palette grid position (instant — no float animation).
2. `slot_cleared(slot_id)` fires, `binding_map[slot_id] = null`.
3. New icon settles, `slot_assignment_changed(slot_id, new_icon_id)` fires, binding writes.

Net: two writes to #19 same frame (legal per #19 §C). Vignette validation triggers twice; the second is guarded by #19's write-once invariant.

**Confirmed-Slot Rejection**: When slot_id ∈ `confirmed_slots`:
- CARRIED icon released over confirmed slot: silent snap-back. No event, no sound, no flash.
- Click on confirmed slot without CARRIED icon: no-op (#2 AC-8 also enforces; #9 is secondary backstop).
- Keyboard Enter on confirmed slot while ICON_SELECTED: no-op (#2 AC-9).

Visual state communicates lock passively. No shake, highlight, or error.

**Deselect / Cancel**: Player can deselect CARRIED icon via Esc (#2 AC-16), clicking carried icon again (#2 AC-18), or clicking notebook background. Icon returns to origin (palette position if from palette; slot it came from if picked up from a filled slot). If from slot: slot resumes SLOT_FILLED with binding restored — #9 must track origin during carry and write the restored binding back. No events on deselect-without-placement.

### States and Transitions

**Slot States:**

| State | Condition | Visual description |
|---|---|---|
| `EMPTY` | `binding_map[slot_id] == null` and not confirmed | Bare glyph, slot outline dim, no icon |
| `HOVER_TARGET` | CARRIED icon over slot; not confirmed | Slot outline brightens slightly; icon does not snap |
| `SLOT_FILLED` | `binding_map[slot_id] != null` and not confirmed | Meaning-icon rests settled in slot |
| `CONFIRMED` | `slot_id ∈ confirmed_slots` | Icon and glyph merge visually (parchment wash); no hover lift; no pointer cursor |

Slot transitions: EMPTY ↔ HOVER_TARGET (drag enter/leave); EMPTY → SLOT_FILLED (click-place or drop); HOVER_TARGET → SLOT_FILLED (drop accepted); SLOT_FILLED → EMPTY (pick-up from slot); SLOT_FILLED → CONFIRMED (vignette_completed signal from #19); CONFIRMED is terminal.

**Icon States:**

| State | Condition | Visual description |
|---|---|---|
| `PALETTE_IDLE` | Icon in palette, not carried, not placed | Flat; 4px lift on mouse-enter hover |
| `CARRIED` | Player holding icon | Follows cursor; z-index above notebook; 4px above origin baseline |
| `SLOT_FILLED` | Icon placed in slot | Settled in slot; no hover response |
| `CONFIRMED_INSLOT` | Slot is confirmed, icon within it | Parchment-merged visual; no hover response |

An icon in `PALETTE_IDLE` that has been placed in a slot must NOT display in the palette simultaneously. Palette icon dimmed/ghosted when placed (per #16 layout). This is the "one instance per icon" rule from #19 §D.

### Interactions with Other Systems

| System | Interface |
|---|---|
| **#19 Session State** | Reads `binding_map`, `confirmed_slots`; writes `binding_map[slot_id] = icon_id`; listens to `vignette_completed(vignette_id)` to transition slots to CONFIRMED. Does NOT compute `unresolved_count` (#19 owns it). |
| **#2 Input System** | Receives `slot_assignment_changed(slot_id, icon_id)` and `slot_cleared(slot_id)` signals. #2 owns click/drag disambiguation. Inherits timing constants `DRAG_SNAP_BACK_DURATION_MS = 120` and reduced-motion flag from #22. |
| **Keystone artifact** (`lexicon-village-elder-question.md §3`) | Slot ID registry (25 entries) and vignette-to-slot mapping. #9 uses §3 column "Vignette / NPC" to know which slot_ids belong to which vignette, to transition slots to CONFIRMED on `vignette_completed`. |
| **#16 Notebook UI** | #9 lives inside #16's scene tree. #16 hosts the slot Control nodes and palette grid; #9 drives their visual states. |

## Formulas

No balance formulas. Three visual timing constants:

**Constant 1: `ICON_LIFT_PX = 4`**

| Symbol | Type | Range | Description |
|---|---|---|---|
| `ICON_LIFT_PX` | int | 2–8 px | Upward offset applied to icon sprite when CARRIED or PALETTE_IDLE hovered |

4px chosen to communicate "lifted" without jitter at 1x and 2x scale. <2px invisible; >8px overshoots "pen hovering" aesthetic.

**Constant 2: `SETTLE_DURATION_MS = 80`**

| Symbol | Type | Range | Description |
|---|---|---|---|
| `SETTLE_DURATION_MS` | int (ms) | 50–150 ms | Tween duration from CARRIED to slot rest, ease-out |

80ms is at the "instantaneous" HCI threshold (#2 `NAVIGATION_RESPONSE_TARGET_MS ≤ 80`). Settle is perceived as arrival, not animation. Ease-out, no bounce. >150ms reads as celebration (violates quiet authorship). <50ms imperceptibly different from snap.

**Constant 3: `HOVER_DWELL_BEFORE_LIFT_MS = 40`**

| Symbol | Type | Range | Description |
|---|---|---|---|
| `HOVER_DWELL_BEFORE_LIFT_MS` | int (ms) | 0–80 ms | Cursor dwell over palette icon before lift animation plays |

Prevents lift-flicker on cursor sweeps. If reduced-motion (#22) active: set to 0 and suppress lift animation entirely.

## Edge Cases

- **Rapid clicks / double-click on palette icon**: per #2 §Edge Cases — first click picks up, second click deselects. #9 tracks CARRIED state; second click on just-picked-up icon returns to PALETTE_IDLE. No intermediate events. binding_map unaffected.
- **Drag begins mid-flight when `vignette_completed` fires**: confirmed check is evaluated at drop-time, not at drag-start. Drop over newly-confirmed slot: snap-back silently. Player sees the slot shimmer-lock while hovering — visual is sufficient communication.
- **Icon picked up from slot that becomes confirmed mid-carry**: theoretically impossible per #19 §C (vignette cannot cascade unless ALL slots correctly bound; picking up icon makes one slot null), but handle defensively: deselect returns icon to PALETTE instead of the now-confirmed-but-empty slot.
- **Palette icon double-binding attempt**: if `icon_id` is already present in any slot in `binding_map`, the palette icon is not pick-up-able. Prevents bijection violation at UI, consistent with #19 §D and #2 §Edge Cases.
- **Rapid placement triggering double-cascade**: #19 §C synchronous validation and `if not vignette_cascaded[id]` guard handle data layer. #9's visual CONFIRMED transition driven by signal that fires exactly once.
- **ENDING phase write rejection**: per #19 AC-6 — if `game_phase == ENDING`, #9 locks ALL slots and palette icons to non-interactive on receiving session_ended. Belt-and-suspenders with #19 backstop.

## Dependencies

### Upstream

| System | Dependency type | Interface consumed |
|---|---|---|
| **#19 Game Session State** | Hard | Reads `binding_map`, `confirmed_slots`; writes `binding_map[slot_id]`; listens to `vignette_completed` |
| **#2 Input System** | Hard | Receives `slot_assignment_changed`, `slot_cleared`; inherits timing constants + reduced-motion flag |
| **Keystone artifact** | Hard (authored data) | Slot ID registry + vignette-to-slot mapping (§3) |

### Downstream

| System | What it needs from #9 |
|---|---|
| **#16 Notebook UI** | Hosts #9's scene tree; visual state driven by #9 (slots EMPTY/HOVER/FILLED/CONFIRMED; icons PALETTE_IDLE/CARRIED/SLOT_FILLED/CONFIRMED_INSLOT) |
| **#8 Vignette state machine** | Reads `binding_map` and `confirmed_slots` from #19 directly, NOT from #9 |
| **#15 Elder climax** | No direct interface; downstream of binding act |
| **#18 Ending scene** | Reads #19 directly; no #9 interface |

**Cross-system contracts to backfill**:
1. ADR-TBD-input-routing must clarify #9-vs-#16 wiring split (#9 subscribes #2's signals, OR #16 intercepts `_gui_input` and calls #9)
2. #16 GDD must document that visual state of slots is driven by #9 (not self-managed)
3. #8 GDD must document it reads #19 directly, not #9
4. Vignette-to-slot mapping should be added to `design/registry/entities.yaml` as cross-system authored data

## Tuning Knobs

| Knob | Default | Safe range | Effect | Owner |
|---|---|---|---|---|
| `ICON_LIFT_PX` | 4 | 2–8 px | How "picked up" feels | #9 |
| `SETTLE_DURATION_MS` | 80 | 50–150 ms | How "deliberate" placement feels | #9 |
| `HOVER_DWELL_BEFORE_LIFT_MS` | 40 | 0–80 ms | Prevents lift-flicker | #9 |
| `DRAG_SNAP_BACK_DURATION_MS` | 120 | 80–200 ms | Snap-back from invalid drop | #2 (read-only here) |

**Locked behaviors**:
- Confirmed slots permanently non-interactive (no "undo confirmed" toggle)
- One icon per slot, one instance per icon — both enforced by #9 before any write
- Deselect always available (Esc, click-carried, click-background) — no confirmation

## Visual/Audio Requirements

**Minimal — owned by #16 Notebook UI rendering**:
- Lift animation (4px upward offset on CARRIED) — pure transform, no shader needed
- Settle tween (80ms ease-out drop into slot) — pure transform
- HOVER_TARGET slot brightening (parchment outline subtly brighter, no glow) — StyleBox state
- CONFIRMED slot parchment wash — texture overlay (TBD when #16 designed)
- No audio cues by default (audio remains silent on bind per quiet-authorship pillar; #4 may add subtle bind sound in VS if playtest justifies)

## UI Requirements

**Lives inside #16 Notebook UI.** Layout, palette grid arrangement, slot positioning all owned by #16. #9 only drives state transitions on those nodes.

**📌 UX Flag — Symbol Binding**: This system's gesture flow needs UX spec validation. In Phase 4 (Pre-Production), run `/ux-design` for the notebook interaction pattern before writing implementation epics.

## Acceptance Criteria

**AC-1 — Pick-up from palette enters CARRIED**
GIVEN NOTEBOOK_OPEN and icon X is PALETTE_IDLE, WHEN the player clicks icon X, THEN X enters CARRIED, follows cursor at 4px above baseline, no `slot_assignment_changed` fires.

**AC-2 — Placement on empty slot writes binding and settles**
GIVEN CARRIED with icon X, WHEN released over empty slot S, THEN `slot_assignment_changed(S, X)` fires, `binding_map[S]` == X in #19, icon settles via 80ms ease-out, state returns to NOTEBOOK_OPEN.

**AC-3 — Placement on occupied non-confirmed slot performs swap**
GIVEN CARRIED with X, slot S contains Y (non-confirmed), WHEN released over S, THEN Y returns to PALETTE_IDLE instantly, `slot_cleared(S)` then `slot_assignment_changed(S, X)` fire in order, `binding_map[S]` ends as X.

**AC-4 — Placement on confirmed slot silently rejected**
GIVEN S ∈ `confirmed_slots`, player has CARRIED X, WHEN released over S, THEN X snap-backs via 120ms ease-in-out, no events fire, slot S unchanged, `binding_map[S]` unchanged.

**AC-5 — Confirmed slot non-interactive when nothing carried**
GIVEN S is CONFIRMED, no CARRIED icon, WHEN player clicks S, THEN no event, no state change, no pick-up animation.

**AC-6 — Pick-up from non-confirmed filled slot clears binding**
GIVEN slot S contains Y (non-confirmed), NOTEBOOK_OPEN, WHEN player clicks S, THEN Y enters CARRIED, `slot_cleared(S)` fires, `binding_map[S]` == null, slot S becomes EMPTY.

**AC-7 — Deselect returns icon to origin (from palette)**
GIVEN CARRIED with X (picked from palette pos P), WHEN player presses Esc, THEN X returns to palette pos P, state returns to NOTEBOOK_OPEN, no events fire, `binding_map` unchanged.

**AC-8 — Deselect after slot pick-up restores prior binding**
GIVEN Y was in slot S, player picked it up (S now EMPTY, Y CARRIED), WHEN player presses Esc without placing, THEN Y returns to slot S, slot resumes SLOT_FILLED, `binding_map[S]` written back to Y (single restore write that triggers validation — won't cascade since other slots unchanged).

**AC-9 — Icon double-binding rejected at palette**
GIVEN icon X is currently placed in slot S (SLOT_FILLED), WHEN player clicks X's palette position, THEN no pick-up occurs, palette icon is non-interactive while placed, no events fire.

**AC-10 — vignette_completed transitions all vignette slots to CONFIRMED**
GIVEN Baker vignette has slots S1, S2, S3 all SLOT_FILLED, WHEN #19 emits `vignette_completed(baker_id)`, THEN S1, S2, S3 all transition to CONFIRMED within the same frame, no subsequent pick-up/placement accepted.

**AC-11 — Snap-back on invalid drop uses #2 timing**
GIVEN CARRIED with X, WHEN released over notebook background, THEN X returns to origin via ease-in-out completing in exactly 120ms, no event, X returns to PALETTE_IDLE.

**AC-12 — Confirmed-slot check evaluated at drop-time**
GIVEN S is EMPTY at drag-start, AND #19 emits `vignette_completed` for S's vignette during drag (defensive case), WHEN drop releases over S, THEN #9 reads `confirmed_slots` at moment of release and snap-backs if S now confirmed.

**AC-13 — Reduced-motion: settle instant, lift suppressed**
GIVEN OS reduced-motion flag (#22) active, WHEN icon placed or picked up, THEN settle tween = 0ms, lift animation suppressed (icon does not float 4px above cursor), hover dwell = 0ms. State transitions still correct, only animations suppressed.

**AC-14 — ENDING phase locks all interactive elements**
GIVEN `game_phase == ENDING`, WHEN player clicks any palette icon or slot, THEN no pick-up, no events, all icons/slots in non-interactive state — #9 has locked the binding interface on session_ended.

**AC-15 — Second-icon replacement does not require intermediate state**
GIVEN CARRIED with X, WHEN player clicks different palette icon Z (not slot), THEN X returns to PALETTE_IDLE instantly, Z enters CARRIED, exactly one icon is CARRIED at any time.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | #9-vs-#16 wiring split — does #9 subscribe to #2's signals, or #16 intercepts `_gui_input` and calls #9? | ADR-TBD-input-routing |
| OQ-2 | Vignette-to-slot mapping — currently only in keystone artifact §3. Add to `design/registry/entities.yaml`? | Yes — defer to Phase 5b registry update batch |
| OQ-3 | Should #9 cache "icon origin" (palette position vs slot pos) for deselect-restore, or query at deselect time? | Implementation detail (ADR-TBD-input-routing) |
| OQ-4 | Audio cue on settle — silence by default, but playtest may want a subtle "page-touch" sound. Owned by #4 if added | Defer to VS playtest |
