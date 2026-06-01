# Vignette State Machine (#8)

> **Status**: In Design
> **Author**: solo (autonomous batch) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — orchestrates the 5-minute vignette short-term loop
> **System Category**: Gameplay (Feature layer)
> **Game**: Lexicon Village

## Overview

Vignette State Machine orchestrates the per-NPC short-term loop: from approach → intro line → action tableau → closing line → vignette-complete cascade trigger. Each of the 7 NPCs (Baker, Blacksmith, Fisher, Weaver, Child, Traveler, Storyteller) follows the same state machine; the content differs per NPC but the flow is identical. The system reads NPC content (token sequences + tableau action references) from #13 Vignette content authoring, drives Dialogue Display (#11) via `show_line() / advance() / hide()` API, and observes #19 Session State to detect when the player has correctly bound all the vignette's slots (which triggers Session State's own `vignette_completed` signal — picked up by #10 Cascade shimmer for the celebration). This system does NOT own correctness validation (#19 does), does NOT own the cascade animation (#10 does), and does NOT own the per-NPC visual sprite (#7 does). It owns the *sequence* of those events.

## Player Fantasy

A vignette is the village showing you a small scene: the baker holds bread and offers it to a passing customer; she says three lines you cannot read; she goes back to her counter. You watch, you think, you open your notebook. The vignette state machine is the invisible director that ensures the baker's three lines arrive in the right order, paced to the action you see her perform, and that the system knows when you have decoded enough of what she said to mark her vignette as understood.

**Pillar alignment**: Pillar 2 — the vignette is the player's primary contact with the language and the village; orchestrating its rhythm well is the difference between "the village told me something" and "a UI fired events." Pillar 3 — vignettes can be left and returned to indefinitely; no failure state inside the machine.

## Detailed Design

### Core Rules

**Per-NPC state machine** — each NPC has an instance of this state machine, driven by player interaction:

```
DORMANT → INTRO → ACTION → CLOSING → COMPLETE_PENDING → CASCADED
```

State semantics:
- **DORMANT**: NPC has not been interacted with yet OR interaction ended without cascade. Click triggers INTRO.
- **INTRO**: showing intro line(s) via `dialogue_display.show_line(intro_tokens)`. Player advances; transitions to ACTION.
- **ACTION**: NPC sprite plays its tableau animation (baker holds bread, blacksmith strikes hammer, etc.). May overlap with action-line dialogue if authored. Auto-advances on animation complete.
- **CLOSING**: showing closing line(s). Player advances; dialogue panel dismisses; transitions to COMPLETE_PENDING.
- **COMPLETE_PENDING**: vignette interaction sequence has played; the system now WAITS for the player to bind all this vignette's slots (work done in #9 Symbol-binding via notebook). The player may revisit the NPC during this state; re-interaction replays from INTRO.
- **CASCADED**: triggered by Session State's `vignette_completed` signal. Terminal state. Re-interaction shows the post-cascade idle line (#14).

**Replay behavior**: from any state (except CASCADED), re-clicking the NPC restarts at INTRO. The player can re-watch the vignette as many times as needed. This is intentional — re-listening to the dialogue with newly-bound words is a Discovery mechanic (player notices a previously-opaque word is now legible mid-replay because shimmer applied to history).

**No skip-to-end**: the player advances dialogue manually (Enter/Space/click); there is no "skip vignette" button. Per Pillar 3, no friction — but the player is expected to engage with each vignette at least once to see the tableau and hear the dialogue.

### States and Transitions

| State | Triggers transition | Next state |
|---|---|---|
| `DORMANT` | NPC clicked (via #2 → #7 → #8) | `INTRO` |
| `INTRO` | Player advances past final intro line | `ACTION` |
| `ACTION` | Sprite animation complete (signal from #7) | `CLOSING` |
| `CLOSING` | Player advances past final closing line | `COMPLETE_PENDING` |
| `COMPLETE_PENDING` | NPC clicked again | `INTRO` (replay) |
| `COMPLETE_PENDING` | #19 emits `vignette_completed(this_vignette_id)` | `CASCADED` |
| `CASCADED` | NPC clicked | shows #14 revisit idle line; no state change |
| Any except CASCADED | `game_phase == ENDING` | freeze in current state (input locked) |

Per-NPC instances of the state machine are independent — Baker's state and Blacksmith's state do not interact except via shared #19 data.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **#2 Input System** | Upstream | Listens for `npc_interaction_requested(npc_id)` to start INTRO |
| **#7 NPC sprite & tableau** | Peer | Drives sprite animation during ACTION; listens for `tableau_complete(npc_id)` signal |
| **#11 Dialogue display** | Downstream | Calls `show_line(tokens)`, `advance()`, `hide()` per state |
| **#13 Vignette content** | Upstream (data) | Reads intro_tokens, action_tokens, closing_tokens per NPC |
| **#14 NPC revisit idle line** | Downstream | After CASCADED, NPC clicks dispatch to #14's idle line provider |
| **#19 Session State** | Upstream (signal) | Listens for `vignette_completed(vignette_id)` to enter CASCADED |
| **#10 Cascade shimmer** | Indirect | #10 listens to #19's signal independently; #8 does not call #10 directly |
| **#15 Elder climax** | Downstream | When all 7 instances are CASCADED, the Elder click becomes meaningful (#15 owns the detection) |

## Formulas

No formulas. State transitions are event-driven.

## Edge Cases

- **If** player closes dialogue panel mid-INTRO (via Esc): state returns to DORMANT; the partial intro is discarded. Next click restarts at INTRO from line 1.
- **If** sprite animation fails to complete in ACTION (no signal received within timeout): force-advance to CLOSING after `ACTION_TIMEOUT_SEC = 8s`. Log `push_error`. Prevents soft-lock from missing/broken NPC animation.
- **If** player binds all this vignette's slots while in ACTION (notebook open during dialogue is allowed per #2): cascade does NOT fire mid-action; #19's validation runs synchronously on bind, but #10's trigger is gated by the notebook-closed condition (#10 EC-10). State machine enters COMPLETE_PENDING on dialogue close (CLOSING → COMPLETE_PENDING), and `vignette_completed` is already true → immediate transition to CASCADED.
- **If** player binds all slots BEFORE ever interacting with the NPC (theoretically possible via cross-vignette word inference): NPC remains DORMANT until clicked, then runs through INTRO → ACTION → CLOSING. On CLOSING completion, COMPLETE_PENDING immediately transitions to CASCADED (vignette is already validated). Player gets the shimmer reward without the suspense — acceptable per design ("you figured it out before you even heard her").
- **If** player attempts NPC interaction during `game_phase == ENDING`: ignored (per #2 modal lock).
- **If** vignette content authoring (#13) is missing token data for an NPC: state machine refuses to enter INTRO; logs `push_error`; NPC click is a no-op. Authoring-error visibility.
- **If** the player replays a vignette in COMPLETE_PENDING and binds during replay: same path as above (validation runs, cascade fires when dialogue dismisses).

## Dependencies

**Upstream**:
- #2 Input System — npc_interaction_requested signal
- #7 NPC sprite & tableau — sprite, tableau_complete signal
- #11 Dialogue display — show_line/advance/hide API
- #13 Vignette content authoring — per-NPC token sequences
- #19 Session State — vignette_completed signal

**Downstream**:
- #14 NPC revisit idle line — post-cascade dispatch
- #15 Elder climax — observes all-7-cascaded condition (likely via #19 not #8)
- #10 Cascade shimmer — indirect (via #19 signal)

**Cross-system contracts to backfill**:
1. #13 GDD must define token field schema: `{intro_tokens, action_tokens, closing_tokens}` per NPC
2. #7 GDD must emit `tableau_complete(npc_id)` signal when sprite animation ends
3. #14 GDD must expose `get_idle_line(npc_id)` for post-cascade lookup

## Tuning Knobs

| Knob | Default | Range | Effect | Owner |
|---|---|---|---|---|
| `ACTION_TIMEOUT_SEC` | 8.0 | 4–15 | Force-advance if tableau animation never completes | #8 (safety net) |
| Per-NPC intro line count | 1–2 | 1–3 | Per-NPC authoring decision | #13 |
| Per-NPC action line count | 0–2 | 0–3 | 0 = silent action, 1-2 = words during action | #13 |
| Per-NPC closing line count | 1 | 1–2 | Per-NPC authoring | #13 |
| Replay enabled? | true | locked | Re-interaction restarts vignette | #8 (locked) |

**Locked behaviors**:
- Replay is always available (no "lock after first view")
- No skip button
- State is per-NPC instance, not shared
- COMPLETE_PENDING → CASCADED transition is fully automatic (no player confirmation)

## Visual/Audio Requirements

**N/A — Vignette State Machine has no direct visuals or audio.** It coordinates other systems that own those concerns: #11 (dialogue text + typewriter blip), #7 (sprite animation), #10 (cascade shimmer + chime).

## UI Requirements

**N/A — no UI of its own.** Visible artifacts (dialogue panel, NPC sprite, cascade shimmer) are owned by other systems.

## Acceptance Criteria

**AC-1 — DORMANT to INTRO on NPC click**
GIVEN baker's state is DORMANT, WHEN #2 emits `npc_interaction_requested(baker_id)`, THEN baker state transitions to INTRO and `dialogue_display.show_line(baker_intro_tokens)` is called.

**AC-2 — INTRO to ACTION on advance**
GIVEN baker is in INTRO showing the final intro line, WHEN player presses advance, THEN state transitions to ACTION, sprite animation begins.

**AC-3 — ACTION to CLOSING on sprite signal**
GIVEN baker is in ACTION state, WHEN #7 emits `tableau_complete(baker_id)`, THEN state transitions to CLOSING, `show_line(baker_closing_tokens)` called.

**AC-4 — CLOSING to COMPLETE_PENDING on advance**
GIVEN baker is in CLOSING showing final line, WHEN player advances, THEN dialogue dismisses (`hide()`), state transitions to COMPLETE_PENDING.

**AC-5 — Esc mid-INTRO returns to DORMANT**
GIVEN baker is in INTRO with first line showing, WHEN player presses Esc, THEN dialogue dismisses, state returns to DORMANT, no partial-progress is retained.

**AC-6 — Re-click in COMPLETE_PENDING restarts at INTRO**
GIVEN baker is in COMPLETE_PENDING (vignette played but not cascaded), WHEN player clicks baker again, THEN state transitions to INTRO and replays from line 1.

**AC-7 — vignette_completed signal triggers CASCADED**
GIVEN baker is in COMPLETE_PENDING and not yet cascaded, WHEN #19 emits `vignette_completed(baker_id)`, THEN state transitions to CASCADED.

**AC-8 — CASCADED click dispatches to #14**
GIVEN baker is in CASCADED state, WHEN player clicks baker, THEN #14 `get_idle_line(baker_id)` is invoked and the idle line is shown via #11 (state remains CASCADED).

**AC-9 — Bind during ACTION defers cascade until dialogue close**
GIVEN baker is in ACTION state and player opens notebook + binds all baker slots correctly (without first dismissing dialogue), WHEN player closes notebook and advances dialogue to CLOSING, THEN cascade fires on CLOSING-to-COMPLETE_PENDING transition (immediately moves to CASCADED).

**AC-10 — Bind before any NPC interaction works**
GIVEN baker is in DORMANT and player binds all baker slots correctly via cross-vignette inference, WHEN player clicks baker, THEN state runs DORMANT → INTRO → ACTION → CLOSING → COMPLETE_PENDING → CASCADED in sequence (final transition automatic).

**AC-11 — ACTION timeout protects against soft-lock**
GIVEN baker is in ACTION state and `tableau_complete(baker_id)` is not emitted within `ACTION_TIMEOUT_SEC`, WHEN timeout elapses, THEN state force-advances to CLOSING, `push_error` logged, dialogue closing line shown.

**AC-12 — Per-NPC state independence**
GIVEN baker is in CASCADED and blacksmith is in INTRO, WHEN player interacts with fisher (clicks), THEN fisher state transitions to INTRO independently; baker and blacksmith states are unaffected.

**AC-13 — Missing content authoring rejected gracefully**
GIVEN an NPC has no token data in #13's authoring, WHEN player clicks that NPC, THEN state remains DORMANT, `push_error` logged, no crash, no broken dialogue.

**AC-14 — Phase ENDING freezes state**
GIVEN `game_phase == ENDING`, WHEN player clicks any NPC, THEN no state transition occurs (input is locked per #2).

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Does ACTION state require an explicit "advance" input from player, or does it auto-advance on sprite signal alone? Current spec: auto on signal | Resolve via playtest of baker MVP — players may want to dwell on tableau |
| OQ-2 | What is `ACTION_TIMEOUT_SEC` calibrated against? Current 8s default is arbitrary | Set after baker tableau animation is authored (likely 2× expected animation length as safety buffer) |
| OQ-3 | Should COMPLETE_PENDING be visually distinguished from DORMANT? (e.g., NPC has a subtle visual change indicating "you've talked to me but I'm not yet decoded") | Resolve via playtest; may help player remember which NPCs they've engaged |
| OQ-4 | If all 7 vignettes are CASCADED but the player clicks an NPC instead of the Elder, what happens? Currently spec'd as #14 idle line; should it also subtly hint "the Elder waits"? | Resolve via playtest |
