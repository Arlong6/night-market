# Input System (#2)

> **Status**: In Design
> **Author**: solo (user-driven) + skill orchestration
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Infrastructure — indirectly serves Pillar 3 (No Failure, Only Re-reading) by ensuring no input is rejected with a penalty
> **System Category**: Input (Foundation layer)
> **Game**: Lexicon Village

## Overview

Input System is the data layer that captures raw input events (keyboard, mouse, touch, optional gamepad) and routes them to consumer systems via Godot 4.6's standard `InputEvent` pipeline. It owns no UI of its own; instead, it provides the contract that Notebook UI (#16), Title screen (#17), Symbol-binding (#9), and Settings (#20) consume. The system is responsible for **input-method abstraction** — a click and a tap should reach #16 as the same "place icon" event; an arrow-key press and a mouse click on a NPC sprite should reach #7 as the same "interact with this NPC" event. It also owns the **drag/click duality** required by GDD Mechanic #5: drag-to-bind is primary on desktop where the gesture is fluid; click-to-select + click-to-place is the fallback for trackpads and touch. The Web HTML5 export adds a cross-browser timing concern around HTML5 drag-and-drop's `mouseup` behavior — **SPIKE 2 is upstream of this GDD's implementation phase** to determine whether drag works reliably enough to be primary, or whether click should be promoted. Implementation pattern (single autoload event hub vs per-consumer direct binding vs Godot's built-in `_unhandled_input` chain) is **TBD — see ADR-TBD-input-routing when written**.

## Player Fantasy

Input in Lexicon Village is unusual: it is the act of COMMITTING a hypothesis, not the act of moving an object. When the player drags `mura` onto bread-icon, they are not transporting a token across the screen — they are saying *this is what I think she meant*. The gesture is utterance, not manipulation.

The canonical drag moment is **the pen hovering**: the player holds a meaning-icon under the cursor, drifts it toward `mura`'s slot, pauses, moves it back, hovers again, finally releases. The icon clicks into place — not snapped, not celebrated, just *placed*. The hypothesis is now on the page. The fantasy lives in the gap between *thinking it* and *saying it*, not in the release.

The frame for all of input is **quiet authorship**. The player is not solving the language; they are writing their reading of it. Every gesture is a sentence in their personal translation. Later, if they were wrong, they will return and overwrite it, just as quietly. No chime, no green flash, no haptic celebration on success — only the icon settling, and the glyph now bearing the player's mark. A scholar does not need confirmation to know they wrote something.

The keyboard layer (navigation between notebook pages, Esc to close, arrow keys to scroll) has its own quiet rhythm — pages turn at the speed of attention, no scroll juice, no animation gating. The player feels read-to, not flashed-at.

**Pillar alignment**: serves Pillar 2 (Language IS the World) most strongly — input is the surface where the player participates IN the language; their gesture becomes part of the linguistic act. Serves Pillar 3 (No Failure) by being trust-based — the pen never slips, you can always pick it back up, navigation never punishes a wrong key. Does NOT directly serve Pillar 1 — the "small private fireworks of comprehension" lives in the cascade-shimmer (#10), not in input.

**Risk this fantasy accepts**: players coming from snappier puzzle games may initially read "deliberate" as "unresponsive." Mitigation belongs in feel-tuning (response timing constants in #16 Notebook UI), not in this GDD.

## Detailed Design

### Core Rules

**Input methods enumerated**, with the canonical events each produces:

**Keyboard** (a11y floor: keyboard-only can complete the game)
- `Tab` / `Shift-Tab`: cycle focus through all interactive elements in reading order (palette icons → glyph slots → close button)
- `Arrow keys`: navigate within the meaning-icon palette grid (palette is a 5-column grid; arrows are more natural than 25-Tab cycle)
- `Enter` / `Space`: confirm focused dialogue; pick up focused palette icon; place carried icon onto focused slot
- `Esc`: deselect carried icon; close dialogue; close notebook
- Focus indicators are custom parchment-palette (NOT browser default blue outline)

**Mouse** (click-primary; drag is enhancement)
- Left-click (village scene): fire `npc_interaction_requested(npc_id)` for NPC under cursor
- Left-click (palette icon): pick up the icon (enters ICON_SELECTED sub-state)
- Left-click (empty slot, while icon selected): place icon; emit `slot_assignment_changed(slot_id, icon_id)`
- Left-click (occupied slot): swap — return the existing icon to palette, place the carried one
- Left-click (carried icon again, OR notebook background): deselect with no penalty
- Left-click (filled slot, nothing carried): pick up that slot's icon
- Left-drag (palette icon): **enhancement** — if SPIKE 2 confirms reliability, drag fires identical `slot_assignment_changed` events as click-place; drop on invalid target snap-backs silently with ~120ms ease

**Touch** (partial / Web mobile best-effort)
- Tap = left-click (all contexts above)
- **No touch-drag** — touch always uses click-mode (touch drag on Web has scroll-vs-drag disambiguation issues on mobile Safari; not worth implementing for non-primary platform)
- Enable Godot's "Emulate Mouse From Touch" project setting

**Gamepad** (partial / bonus only — minimal spec)
- D-pad navigates focus; A/Cross = confirm; B/Circle = cancel
- If Godot's Web Gamepad API fails to fire, system degrades gracefully (gamepad events simply don't arrive)

### States and Transitions

State transitions are mutually exclusive — only one state at a time. Opening one modal layer (dialogue, notebook) closes the other.

| State | Active when | Permitted input |
|---|---|---|
| `NORMAL` | Village scene, no dialogue, no notebook | Mouse click on NPC; keyboard has no effect |
| `DIALOGUE_OPEN` | NPC dialogue panel visible | Enter/Space to advance; Esc to dismiss; mouse click on panel to advance |
| `NOTEBOOK_OPEN` | Notebook visible, no icon carried | Tab/Shift-Tab; arrow keys; click to pick up icon; Esc to close |
| `ICON_SELECTED` | Player has picked up an icon, not yet placed | Click slot to place; click empty area / Esc to deselect; keyboard nav to slots, Enter to place |
| `DRAG_IN_PROGRESS` | Player is mid-drag (mouse button held; only if drag enabled post-SPIKE 2) | Mouse position drives icon; mouse-up on valid slot places; elsewhere snap-back |
| `CUTSCENE` | Shimmer cascade animating (1.5s sweep) | All notebook interactions LOCKED; NPC navigation + notebook open/close remain free; Esc allowed (skip shimmer behavior — see Open Questions) |

### Interactions with Other Systems

| Consumer | Event from Input System | Notes |
|---|---|---|
| **#7 NPC interaction** | `npc_interaction_requested(npc_id)` on NPC click in NORMAL state | Output-only; #7 owns dialogue trigger logic |
| **#9 Symbol-binding** | `slot_assignment_changed(slot_id, icon_id)` on every drop OR click-place; `slot_cleared(slot_id)` on icon pick-up from occupied slot | #19 Session State actually owns binding_map writes; #9 owns the UI gesture; this Input System fires events that #9 routes to #19 |
| **#16 Notebook UI** | `notebook_page_changed(direction)` on Tab/Shift-Tab; `notebook_close_requested()` on Esc; drag/click events routed through #16's own Control nodes via `_gui_input` (Input System does not duplicate that routing) | #16 owns its own internal selection state (`selected_icon` variable per gameplay-programmer's recommendation — do NOT use engine `has_focus()` due to 4.6 dual-focus) |
| **#17 Title screen** | `confirm_pressed()`, `menu_navigate(direction)` — standard menu contract | Trivial |
| **#10 Cascade shimmer** | `cutscene_skip_requested()` on Esc during CUTSCENE state | Passive consumer of skip event |

**Single source of truth**: Input System is output-only toward consumers. No consumer writes back to input state. State transitions driven by Input System observing scene state (e.g., it detects whether the notebook node is visible).

**Layered overlay routing**: use Godot's `_unhandled_input` chain with explicit `get_viewport().set_input_as_handled()` to stop propagation. Highest priority: DialogueOverlay → NotebookOverlay → GameLayer → TitleLayer. Modal layers set `mouse_filter = MOUSE_FILTER_STOP` on root Control when active.

**InputMap actions** (leave room for Settings remap in VS): use named actions (`action_confirm`, `action_notebook_open`, `action_clear_selection`) from day one, never hardcode `KEY_ENTER` or `MOUSE_BUTTON_LEFT` in `_unhandled_input`. Zero cost now, avoids rework when Settings (#20) is built.

**Reconciliation with concept doc Mechanic #5** (logged 2026-05-29): concept doc currently says "drag-to-bind is primary; click-to-select/place is fallback". This GDD inverts that — **click is primary in MVP code; drag is enhancement layered after SPIKE 2 verification**. The concept doc Mechanic #5 should be updated to match this revised primacy. Reason: Web HTML5 `_get_drag_data` / `_drop_data` cross-browser unreliability (Chrome vs Firefox `mouseup` divergence) makes drag-first risky for MVP; click-first is more honest about the platform reality.

## Formulas

This system has **no balance formulas, no scaling curves**. Input is event-driven. Three timing constants are documented for implementation clarity:

---

**Constant 1: `LONG_PRESS_THRESHOLD_MS`** — touch long-press detection (touch-drag fallback, only if touch drag is ever enabled)

The constant is defined as:

`LONG_PRESS_THRESHOLD_MS = 350`

**Variables:** None — fixed timing value.
**Range tolerance:** 250–500 ms. Below 250 ms causes accidental drags on intended taps; above 500 ms feels sluggish.
**Note:** Currently unused — touch is locked to click-only per Section C. Reserved for future touch-drag if SPIKE 2 results justify it.

---

**Constant 2: `DRAG_SNAP_BACK_DURATION_MS`** — duration of the snap-back tween when a drag is released over an invalid target

The constant is defined as:

`DRAG_SNAP_BACK_DURATION_MS = 120`

**Easing:** ease-in-out. The icon returns to its origin position smoothly, no overshoot.
**Range tolerance:** 80–200 ms. Below 80 ms feels abrupt; above 200 ms feels heavy and delays the next attempt.
**Rationale:** matches "the pen hovering" Player Fantasy — the icon retracts as if the player's hand hesitated. Should NOT communicate failure (no shake, no flash, no sound).

---

**Constant 3: `NAVIGATION_RESPONSE_TARGET_MS`** — maximum perceived latency for any keyboard navigation (Tab page change, arrow key palette move)

The constant is defined as:

`NAVIGATION_RESPONSE_TARGET_MS <= 80`

**Rationale:** under 80 ms is the threshold for "instantaneous" perception in HCI literature. Pillar 3 + Player Fantasy ("pages turn at the speed of attention") require navigation to feel reactionless. Above 100 ms registers as "the game is thinking"; this game must never feel like it is thinking when navigation is requested.
**Implementation note:** This is a PERFORMANCE BUDGET, not a tunable animation duration. Animation duration on Tab/page-change should be **zero** — no slide transitions, no fade. The page snaps. This constant exists so QA can measure perceived response and flag regression.

---

**Why this section is short**: Input System mediates events; it does not compute. Output of any formula would be either (a) immediate action (no math) or (b) a timing constant (3 listed above). Tuning logic lives in consumer systems (e.g., #10 Cascade shimmer's 1.5s sweep duration is owned by #10, not #2).

## Edge Cases

**Drag-related**

- **If** the player releases a dragged icon over an invalid target (notebook background, outside notebook, non-slot Control): snap-back tween (120ms ease-in-out) returns icon to origin. No sound, no flash. Player Fantasy's "pen hovers" moment.
- **If** the browser tab loses focus mid-drag (alt-tab, app switch): browser pauses; on resume, drag state is considered cancelled and icon snap-backs to origin.
- **If** the drag is on Firefox and `mouseup` fires on the drag origin instead of the target (Chrome vs Firefox divergence): `_drop_data` never fires → treated as snap-back (silent failure). SPIKE 2 must verify; if Firefox is unreliable, drag is disabled in production and click is sole path.
- **If** a dialogue or modal opens mid-drag: drag is cancelled, icon snap-backs.

**Click-mode**

- **If** the player clicks the carried icon again: deselect with no penalty (icon returns to palette, no sound).
- **If** the player clicks a different palette icon while carrying: drop carried icon back to palette, pick up new icon (no intermediate deselect step required).
- **If** the player clicks an empty slot without carrying: no-op (does nothing; clicking an empty slot without intent should not produce a state change).
- **If** the player clicks a confirmed slot (vignette cascaded, per #19 GDD AC-9): no-op. Slot is data-layer immutable; UI must visually communicate locked state (rendered as locked icon, no hover lift). Click attempt is silently rejected by Input System AND backstopped by Session State.
- **If** the player double-clicks a palette icon: first click picks up, second click is "click on carried icon" → deselect. No special double-click behavior.

**Keyboard**

- **If** the player presses Tab in NORMAL state (no notebook, no dialogue open): no-op. Tab requires a focusable context.
- **If** the player presses Esc in NORMAL state: no-op (no penalty, no popup, no quit confirmation).
- **If** two direction keys are held simultaneously: use last-pressed (standard convention from existing project's platformer code pattern).
- **If** the player presses Enter on a slot without carrying: pick up that slot's icon (re-arrangement intent).
- **If** the player presses Enter on a confirmed slot: no-op (locked, same as click rule above).
- **If** the player Tabs past the last focusable element: wrap to first (cycle, not dead-end).

**Cross-state**

- **If** the player clicks an NPC during DIALOGUE_OPEN: ignored (modal layer absorbs click via `MOUSE_FILTER_STOP`).
- **If** the player clicks a slot during CUTSCENE (shimmer animating 1.5s): ignored (input locked per States table).
- **If** the player presses Esc during CUTSCENE: fires `cutscene_skip_requested()` to #10; #10's Open Question OQ decides whether to honor or require confirmation (see #10 GDD when designed).
- **If** the notebook is opened while a dialogue is already open: close the dialogue first, then open notebook (mutual exclusion enforced by Input System's state observer).
- **If** the game transitions to ENDING phase while notebook is open: notebook closes automatically; Input System enters CUTSCENE-equivalent locked state for the ending scene.

**Web-specific**

- **If** the browser tab loses focus during any input state: drag cancels (per above); held keys are released by browser; on regain, all input states reset to clean (no stuck keys, no carried-icon ghost).
- **If** the player right-clicks anywhere: ignored by game. Browser default context menu may appear; not Input System's concern. (Future: suppress browser context menu via JS bridge if it interferes with UX.)
- **If** the player attempts pinch-zoom on touch device: browser-handled (changes viewport zoom). Game does not interfere. Visual quality at non-100% zoom is best-effort.

**Accessibility**

- **If** the user enables OS-level reduced-motion preference: snap-back animation is INSTANT (no tween); shimmer-skip is offered earlier in the cascade. (Reduced-motion handling owned by #22 Accessibility motion fallback; Input System honors that system's flag.)
- **If** the user is in a high-contrast mode: parchment-palette focus indicator must remain visible. Test on both light and dark high-contrast.
- **If** keyboard-only player completes binding: every slot must be reachable by Tab; the 25-icon palette must be arrow-navigable; no slot is gated behind a mouse-only interaction.

## Dependencies

**Upstream**: NONE. Foundation layer.

**Downstream dependents**:

| System | Type | Interface |
|---|---|---|
| **#7 NPC interaction** | Hard | Receives `npc_interaction_requested(npc_id)` events |
| **#9 Symbol-binding** | Hard | Receives `slot_assignment_changed(slot_id, icon_id)` and `slot_cleared(slot_id)` events |
| **#10 Cascade shimmer** | Soft | Receives optional `cutscene_skip_requested()` if implemented |
| **#16 Notebook UI** | Hard | Receives `notebook_page_changed(direction)`, `notebook_close_requested()`; routes its own internal `_gui_input` for drag/click on icons & slots |
| **#17 Title screen** | Hard | Standard menu contract: `confirm_pressed()`, `menu_navigate(direction)` |
| **#20 Settings** | Hard (VS) | Reads `InputMap` for remap UI; writes back via `InputMap.action_*_event` API |
| **#22 Accessibility motion fallback** | Soft | Input System reads accessibility flag; honors reduced-motion (instant snap-back, no tween) |

**Cross-system contracts to backfill when dependents are designed**:
1. #9 GDD must document its `_gui_input`-vs-Input-System split (UI gesture detection vs event routing)
2. #16 GDD must document its `selected_icon` state ownership (NOT engine `has_focus()`)
3. #10 GDD must document whether `cutscene_skip_requested()` is honored or requires confirmation
4. #20 GDD must define which actions are user-remappable vs locked

**Cross-system flags** (assumptions to validate):
- SPIKE 2 result determines whether drag is included in production code (otherwise click-only)
- Godot's "Emulate Mouse From Touch" project setting works alongside drag attempt (verify in SPIKE 2)
- Web Gamepad API browser-gate (player must press a button to register gamepad) — handled via `Input.joy_connection_changed` signal, not `_ready()` check

## Tuning Knobs

**Input System has minimal designer-tunable knobs.** Mostly hard rules from Pillar 3 (no failure, no friction). The few knobs:

| Knob | Default | Safe range | Effect | Owner |
|---|---|---|---|---|
| `LONG_PRESS_THRESHOLD_MS` | 350 | 250–500 | Touch-drag detection (currently unused) | #2 |
| `DRAG_SNAP_BACK_DURATION_MS` | 120 | 80–200 | Drag-cancel ease duration | #2 |
| `NAVIGATION_RESPONSE_TARGET_MS` | ≤80 | Hard budget | Performance budget for keyboard nav | #2 (perf, not designer) |
| **InputMap action bindings** | engine-default | per-action | Which keys map to which actions | #20 Settings (eventual) |
| Reduced-motion flag | OS-detected | bool | Whether snap-back is instant or tweened | #22 Accessibility |
| Pause UI behavior | N/A in MVP | — | Whether input pauses session timer | #20 Settings (locked NO per #19 GDD) |

**Locked behaviors (not tunable)**:
- Drag/click are co-equal modes (no toggle, no auto-detect)
- Input is ALWAYS-locked during CUTSCENE state (1.5s shimmer)
- Esc always available (never blocked)
- No confirmation dialogs anywhere (Pillar 3 hard rule)

## Visual/Audio Requirements

**N/A — Input System has no direct visual or audio output.** Players perceive input feedback via systems Input drives:

- Cursor change on draggable icons → owned by #16 Notebook UI (uses Godot built-in `CURSOR_DRAG`)
- Focus indicator (parchment-palette ring) → owned by #16 Notebook UI (`StyleBox` resource)
- Icon-settle "drop" feedback (2px settle, no sound) → owned by #16 Notebook UI
- Snap-back tween → animated by Input System but visually owned by #16
- Any audio cue (none currently — design is silent on click/drag) → owned by #4 Audio system

This GDD does not specify visuals or audio. Any budget belongs to consumer systems.

## UI Requirements

**N/A — Input System has no UI of its own.** It is an event router. UI elements that consume input (palette, slots, focus indicators, dialogue panel, title menu) are owned by #16 Notebook UI, #11 Dialogue display, and #17 Title screen.

## Acceptance Criteria

All criteria in GIVEN/WHEN/THEN form, each independently testable.

**AC-1 — Click NPC fires interaction event**
GIVEN the game is in NORMAL state, WHEN the player left-clicks an NPC sprite, THEN `npc_interaction_requested(npc_id)` is emitted with the correct npc_id and no other state change occurs.

**AC-2 — Click palette icon enters ICON_SELECTED**
GIVEN NOTEBOOK_OPEN state with no icon carried, WHEN the player left-clicks a palette icon, THEN state transitions to ICON_SELECTED and the icon is marked as carried.

**AC-3 — Click empty slot places icon**
GIVEN ICON_SELECTED state, WHEN the player left-clicks an empty glyph slot, THEN `slot_assignment_changed(slot_id, icon_id)` is emitted and state returns to NOTEBOOK_OPEN.

**AC-4 — Drag-drop produces identical event to click-place**
GIVEN SPIKE 2 has confirmed drag enabled, and the player begins dragging a palette icon, WHEN the player releases over a valid empty slot, THEN `slot_assignment_changed(slot_id, icon_id)` is emitted — same event signature as AC-3 — and no additional event fires.

**AC-5 — Keyboard-only bind: pick up, navigate, place**
GIVEN NOTEBOOK_OPEN state, keyboard-only (no mouse), WHEN the player presses Enter on a focused palette icon, presses Tab to move focus to a glyph slot, then presses Enter, THEN the icon is placed in that slot, `slot_assignment_changed(slot_id, icon_id)` is emitted, and state returns to NOTEBOOK_OPEN.

**AC-6 — Tab navigation wraps around**
GIVEN NOTEBOOK_OPEN state with focus on the last focusable element, WHEN the player presses Tab, THEN focus moves to the first focusable element (wrap, not dead-end).

**AC-7 — Notebook opening closes dialogue (mutual exclusion)**
GIVEN DIALOGUE_OPEN state, WHEN the `action_notebook_open` action fires, THEN the dialogue panel closes, the notebook opens, and the state is NOTEBOOK_OPEN — DIALOGUE_OPEN state is no longer active.

**AC-8 — Confirmed-slot click is a no-op**
GIVEN NOTEBOOK_OPEN or ICON_SELECTED state, and a slot whose binding has been confirmed (locked per #19 Session State), WHEN the player left-clicks that slot, THEN no event is emitted, no state change occurs, and the slot's locked visual state remains unchanged.

**AC-9 — Confirmed-slot keyboard Enter is a no-op**
GIVEN ICON_SELECTED state and a confirmed slot focused via Tab, WHEN the player presses Enter, THEN no event is emitted and the icon remains carried — identical outcome to AC-8 via keyboard.

**AC-10 — CUTSCENE locks slot input, preserves navigation and Esc**
GIVEN CUTSCENE state (shimmer cascade active), WHEN the player clicks a glyph slot, THEN no event is emitted and no state change occurs; AND pressing Tab still moves focus; AND pressing Esc emits `cutscene_skip_requested()`.

**AC-11 — Drag snap-back completes within timing budget**
GIVEN DRAG_IN_PROGRESS state, WHEN the player releases over an invalid target, THEN the icon returns to its origin via ease-in-out tween completing in ≤120ms, with no sound, no flash, and no error event emitted.

**AC-12 — Keyboard navigation response meets latency budget**
GIVEN NOTEBOOK_OPEN state, WHEN the player presses Tab or an arrow key, THEN the focus change is visually reflected within 80ms of the key event (measured frame-to-frame; no slide or fade animation permitted).

**AC-13 — Reduced-motion: snap-back is instant**
GIVEN the OS reduced-motion preference is enabled (accessibility flag active per #22), WHEN a drag is released over an invalid target, THEN the icon returns to origin instantly (0ms tween, no ease) — the `DRAG_SNAP_BACK_DURATION_MS` constant is bypassed.

**AC-14 — InputMap actions used, not hardcoded keys**
GIVEN any keyboard-triggered behavior in this system, WHEN inspecting the implementation source, THEN all key checks reference named InputMap actions (`action_confirm`, `action_notebook_open`, `action_clear_selection`, etc.) — no literal `KEY_*` or `MOUSE_BUTTON_*` constants appear in `_unhandled_input` handlers.

**AC-15 — Web Gamepad registered via signal, not poll**
GIVEN the game is running in a Web export, WHEN a gamepad is connected for the first time, THEN the connection is detected via `Input.joy_connection_changed` signal — no `_ready()` poll or frame-loop check is used.

**AC-16 — Esc deselects carried icon without penalty**
GIVEN ICON_SELECTED state, WHEN the player presses Esc, THEN the carried icon returns to the palette, state returns to NOTEBOOK_OPEN, no event other than state change is emitted, and no penalty or sound plays.

**AC-17 — Esc in NORMAL state is a no-op**
GIVEN NORMAL state, WHEN the player presses Esc, THEN no event is emitted, no state change occurs, and no dialogue or confirmation panel appears.

**AC-18 — Click-mode click on carried icon deselects**
GIVEN ICON_SELECTED state, WHEN the player left-clicks the currently carried icon, THEN the icon returns to the palette and state returns to NOTEBOOK_OPEN — no `slot_assignment_changed` event fires.

**Story type classification**: Logic + Integration. AC-1–AC-18 require automated unit or integration test evidence. AC-11, AC-12, AC-13 are timing-sensitive and need a performance measurement harness or documented timed playtest as supplemental evidence.

## Open Questions

| # | Question | Owner / Target Resolution | Why open |
|---|---|---|---|
| OQ-1 | SPIKE 2 outcome — does `_get_drag_data` / `_drop_data` work reliably on Chrome AND Firefox? | Resolve via SPIKE 2 (separate task) before #16 Notebook UI implementation begins | If Firefox fails, drag is cut from production; click becomes sole input path; tutorial wording must change |
| OQ-2 | Esc-during-CUTSCENE behavior — does pressing Esc immediately skip the 1.5s shimmer, or does it require a deliberate second Esc to confirm skip? | Resolve when #10 Cascade shimmer is designed | Pillar 3 says "no friction" (single Esc); but accidentally skipping the emotional payoff is a real risk; playtest-decidable |
| OQ-3 | Gamepad scope confirmation — concept doc says "partial bonus"; GDD enumerates d-pad/A/B as minimal spec. Cut entirely, or keep at minimal? | Resolve before Vertical Slice begins | If gamepad is cut, the State table can drop gamepad mentions; if kept, ensure browser join-via-button-press handled correctly |
| OQ-4 | Concept doc Mechanic #5 wording — currently says "drag-to-bind is primary; click is fallback". This GDD inverts: click-primary, drag-as-enhancement. **Update concept doc to match** for consistency, OR keep concept doc as "design intent" and treat GDD as "implementation reality"? | Resolve immediately (small copy edit either way) | Cross-doc inconsistency; should be reconciled before #16 GDD references either |
| OQ-5 | Implementation pattern (autoload event hub vs per-consumer direct binding vs Godot built-in `_unhandled_input` chain) — defer to ADR? | Resolve in ADR-TBD-input-routing | All three are technically feasible per gameplay-programmer; choice affects testability + how consumer systems subscribe |
| OQ-6 | Touch long-press threshold (350ms) — currently spec'd but unused (touch is click-only per Section C). Keep the constant defined for future, or remove? | Resolve when touch-drag is reconsidered (post-MVP) | Cost of keeping the constant is zero; mark as "future-reserved" |
