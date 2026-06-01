# Title Screen (#17)

> **Status**: In Design
> **Author**: solo (autonomous batch) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — the title is the first glimpse of the world's visual identity; Pillar 3 (No Failure) — entry-only screen, no failable choices
> **System Category**: UI (Presentation layer)
> **Game**: Lexicon Village

## Overview

Title Screen is the player's entry point — the first scene loaded by #1 Boot after Autoloads complete. It displays the game title in parchment-style typography, a "Start" button (and optional Settings access for VS+), and minimal art (one establishing image of the village from the gate, matching the "arriving at the gate" Player Fantasy from #1 Boot). The player presses Start (or Enter / Space / click), which triggers `confirm_pressed` signal that #1 Boot listens for to transition Title → Game. The screen has no animation beyond the cursor; no music in MVP (audio via #4 in VS+).

## Player Fantasy

The title is the threshold. You see the village from outside — a small painted scene of a gate, a few rooftops behind it, the title hand-lettered in parchment ink above. There is a single Start button below. Nothing pulses, nothing animates, nothing demands attention. The screen waits for you to decide. When you press Start, you cross the threshold — that's the moment from #1 Boot's "arriving at the gate" fantasy.

**Pillar alignment**: Pillar 2 — establishes the visual identity in the first frame the player sees. Pillar 3 — no penalty, no choice with consequence; the only action is enter the game.

## Detailed Design

### Core Rules

**Layout** (320×180 base):
- **Title text** (top half): "字典村莊" (Chinese default) in parchment-style typography. English subtitle "Lexicon Village" below in smaller text (VS+ when #21 Localization is active).
- **Establishing art** (background): single painted scene of village gate. Static, no animation.
- **Start button** (lower-center): rendered as parchment-style button. Default-focused on load (keyboard "Enter to start").
- **Settings button** (lower-right corner): hidden in MVP; appears in VS+ when #20 Settings exists. Click opens settings overlay.

**Interaction**:
- Press Start (click, Enter, Space, or Touch tap): fires `confirm_pressed()` signal listened by #1 Boot.
- Esc: no-op (no quit confirmation; player closes browser tab to quit).
- Tab: navigate between Start and Settings buttons (when Settings visible).

**Audio**:
- MVP: silent
- VS+: optional ambient music track from #4 (1 loop, low volume, ~30s); gated by audio gesture-unlock (#4 / #1 audio pending flag)

### States and Transitions

Title screen is a single state — TITLE_VISIBLE. Transitions out via `confirm_pressed` (handled by #1 Boot which manages scene change).

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **#1 Boot & scene flow** | Upstream | Boot instantiates Title scene at BOOTING→TITLE; listens for `confirm_pressed` |
| **#2 Input System** | Upstream | Receives click/Enter/Space/Tab events |
| **#3 Camera & viewport** | Upstream | Static Camera2D centered on Title scene |
| **#4 Audio system** | Downstream (VS+) | Plays ambient music when audio unlocked |
| **#20 Settings** | Downstream (VS+) | Settings button opens overlay |
| **#21 Localization** | Upstream (VS+) | English subtitle text via `tr()` |

## Formulas

No formulas. Static screen.

## Edge Cases

- **If** player presses Start very rapidly (double-press): only first fires `confirm_pressed`; subsequent presses during TRANSITION ignored (per #1 AC-8).
- **If** browser tab loses focus on Title: nothing to pause; static screen continues to render.
- **If** audio is muted at gesture-unlock time: Title remains silent (per #1 AC-14); no error.
- **If** player resizes browser at Title: per #3 viewport rescales; layout reflows correctly.
- **If** Localization (#21) is not yet loaded when Title renders (race condition): English subtitle falls back to literal string "Lexicon Village" (no `tr()` call); push_error logged.

## Dependencies

**Upstream**: #1 Boot, #2 Input, #3 Camera, #21 Localization (VS+)
**Downstream**: #4 Audio (VS+ music), #20 Settings (VS+ overlay)

**Cross-system contracts**:
1. `confirm_pressed()` signal — per #1 AC-2 contract
2. Settings button visibility gated by #20 existence (MVP hides; VS+ shows)

## Tuning Knobs

| Knob | Default | Range | Effect |
|---|---|---|---|
| Background art | painted village gate scene | art-locked | Visual first impression |
| Title typography | parchment-style hand-letter font | art-locked | Visual identity anchor |
| Start button label | "開始" / "Start" | per #21 | Localization-driven |
| Music volume (VS+) | 0.3 (low) | 0.0–0.5 | Soft ambient; not load-bearing |

**Locked**:
- No title screen animation (parchment is static; matches "shimmer is only motion" rule)
- No splash screen / studio logo before Title (MVP)
- Default-focused element is Start button

## Visual/Audio Requirements

**Visual** (REQUIRED for first-impression):
- Background art: 320×180 painted scene, village gate composition
- Title typography: hand-lettered parchment style, ~24px height
- Start button: parchment-bordered, ~80×24 px
- Color palette: full parchment / sun-bleached per Visual Identity Anchor

**Audio**:
- MVP: silent
- VS+: 1 ambient music loop (~30s), low volume, audio-gesture-unlock gated

**📌 Asset Spec** — Visual requirements defined. Run `/asset-spec system:title-screen` after art bible.

## UI Requirements

Minimal UI elements (title text, art, 1-2 buttons). Layout is static. UX spec not needed for this surface (low complexity).

## Acceptance Criteria

**AC-1 — Title renders on first frame after BOOTING**
GIVEN application has just started and Boot Manager transitions to TITLE state, WHEN Title scene loads, THEN title text "字典村莊" and Start button are visible within `WEB_FIRST_LOAD_MAX_S` (8s).

**AC-2 — Start button default-focused**
GIVEN Title scene is loaded, WHEN inspected, THEN Start button has keyboard focus (Enter / Space would activate it).

**AC-3 — Start press fires confirm_pressed**
GIVEN Title is in TITLE_VISIBLE state, WHEN player clicks Start (or presses Enter or Space), THEN `confirm_pressed()` signal is emitted exactly once.

**AC-4 — Double-press protected**
GIVEN player rapidly clicks Start twice, WHEN events fire, THEN `confirm_pressed()` is emitted exactly once; second event is consumed by #1 Boot's TRANSITION lock (per #1 AC-8).

**AC-5 — Esc is no-op**
GIVEN Title is visible, WHEN player presses Esc, THEN no event fires, no quit confirmation dialog appears, Title remains visible.

**AC-6 — Browser tab focus loss does not crash**
GIVEN Title is visible, WHEN player switches browser tabs (loses focus) and returns, THEN Title remains rendered; no state corruption.

**AC-7 — Audio remains pending in MVP (silent OK)**
GIVEN MVP build (no #4 audio system implemented), WHEN Title is visible, THEN no audio plays; no audio-pending error; Title is fully functional silent.

**AC-8 — Localization fallback graceful**
GIVEN #21 Localization is not yet implemented (MVP) or fails to load (VS+), WHEN Title renders, THEN English subtitle uses literal string fallback "Lexicon Village"; `push_error` logged; Title remains visible.

**AC-9 — Settings button hidden in MVP**
GIVEN MVP build (no #20 Settings system), WHEN Title is visible, THEN Settings button is NOT rendered; Tab navigation cycles only the Start button.

**AC-10 — Window resize preserves layout**
GIVEN player resizes browser from 640×360 to 1280×720, WHEN Title rerenders, THEN title text and Start button remain centered, no clipping, no overflow.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Title text — Chinese-default with English subtitle, or English-default? | Resolve via #21 Localization design + target audience confirmation |
| OQ-2 | Background art — single painted scene, or layered (parchment + village silhouette)? | Resolve in `/art-bible` |
| OQ-3 | Should the Title display the player's prior dictionary (if any) from prior playthrough? | Out of scope — single-sitting only; no cross-run continuity (per #19) |
| OQ-4 | Splash screen / studio logo before Title — needed? | MVP no; VS+ optional |
