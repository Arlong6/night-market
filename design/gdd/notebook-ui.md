# Notebook UI (#16)

> **Status**: In Design
> **Author**: solo (autonomous batch, synthesized from #2/#9/#11 contracts) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 1 (Discovery), Pillar 2 (Language IS the World), Pillar 3 (No Failure) — the notebook is where all three pillars meet
> **System Category**: UI (Presentation layer) — **HIGH RISK** (drag-on-Web cross-browser per SPIKE 2; complex UX spec)
> **Game**: Lexicon Village

## Overview

Notebook UI is the player's primary interaction surface — a parchment-style overlay accessed by pressing a notebook key (or button) that shows: (1) a meaning-icon **palette** (25 icons in a 5-column grid), (2) a per-vignette **page** with 3–5 glyph slots arranged for that vignette, (3) the **"3/5 待解" counter** for the active vignette, (4) **vignette page tabs** to switch between the 7 NPC vignettes. The notebook hosts #9 Symbol-binding's gesture logic (placing icons on slots) inside its layout. It does NOT own binding data (#19 does), does NOT own gesture logic (#9 does), does NOT own input routing (#2 does). It owns the *layout, visual presentation, and per-vignette page navigation* — the surface the gestures happen on. **Implementation path: HBoxContainer-of-Labels + grid Control nodes; click-primary, drag-as-enhancement (provisional pending SPIKE 2)**.

## Player Fantasy

The notebook is the player's workspace — a single parchment page they can open at any time, that holds everything they've noticed about the village's words so far. Opening it is like sitting down at a desk in the inn after a day in the village; closing it is standing up to look around again. The page shows a quiet grid of glyphs to decipher and meaning-icons to deploy. The 待解 counter is the page's private bookkeeper — telling you how far you have left without pretending to know more than you do. The notebook never celebrates, never warns, never explains; it just stays open under your hand while you work.

**Pillar alignment**: serves all three pillars at once — Discovery (the workspace where insights happen), Language IS the World (the surface where language becomes manipulable), No Failure (no penalties, all gestures reversible, can re-edit indefinitely).

## Detailed Design

### Core Rules

**Layout** (320×180 base resolution, CanvasLayer overlay):
- **Vignette tabs** along the top (7 tabs, one per NPC; locked tabs for not-yet-visited NPCs visually distinct)
- **Active vignette page** (center): shows 3–5 glyph slots horizontally laid out, each ~32×40 px (slot + label space below for placed icon)
- **Counter** ("3/5 待解") top-right of the active page, small text
- **Meaning-icon palette** (bottom panel): 5×5 grid showing 25 meaning-icons (~16×16 px each), scrollable if VS+ adds more
- **Close button** (Esc-equivalent) in top-right corner

**Vignette tab states**:
- LOCKED: NPC not yet visited (vignette in DORMANT state per #8); tab shows placeholder glyph, click does nothing
- ACTIVE: currently selected tab; bordered, page rendered
- AVAILABLE: NPC visited but vignette not cascaded (COMPLETE_PENDING per #8); tab shows NPC silhouette
- CASCADED: vignette confirmed; tab shows NPC name (in decoded language) in CONFIRMED visual style

**Per-vignette page**:
- Each glyph slot displays the vignette's glyph form (~16×24 px) above an icon-receptacle area (~16×16 px square)
- Receptacle is EMPTY (shows '?' placeholder), SLOT_FILLED (shows placed icon, per #9 state), or CONFIRMED (icon + glyph merge in parchment-wash visual)
- Counter "N/M 待解" rendered top-right per #19 unresolved_count

**Palette grid**:
- 5×5 grid of meaning-icon slots
- Each slot displays the meaning-icon or a "placed" ghost state (dimmed) per #9 §3.5
- Hover lifts icon 4px (`ICON_LIFT_PX` per #9); click picks up (CARRIED state per #9)

**Page navigation**:
- Click vignette tab → switch active page
- Tab/Shift-Tab cycle through tabs (per #2 keyboard navigation)
- Switching pages does NOT cancel CARRIED state — icon remains held; player can switch to a different vignette page and place there

**Open/close**:
- `action_notebook_open` (default mapped to N or notebook button) toggles
- Esc closes (per #2)
- Closing notebook while CARRIED: icon returns to PALETTE_IDLE silently (per #9 deselect)

### States and Transitions

| State | Active when | Visual |
|---|---|---|
| `HIDDEN` | Default; not in `NOTEBOOK_OPEN` per #2 | Notebook not rendered |
| `OPEN` | Player has triggered `action_notebook_open` | Parchment overlay visible; active vignette page shown |
| `OPEN_CARRYING` | OPEN + ICON_SELECTED per #9 | Same as OPEN; carried icon follows cursor |

State transitions driven by #2 input events and #9 gesture state.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **#9 Symbol-binding** | Peer (lives inside) | #9 drives slot/icon visual states; #16 hosts the Control nodes #9 mutates |
| **#19 Session State** | Upstream | Reads `binding_map`, `confirmed_slots`, calls `unresolved_count(vignette_id)` for counter |
| **#2 Input System** | Upstream | Receives `notebook_page_changed(direction)`, `notebook_close_requested()` |
| **#10 Cascade shimmer** | Peer | Notebook overlay tokens registered (separate from #11 `_active_tokens`); shimmer applies on cascade per #10 OQ-2 |
| **#11 Dialogue display** | Sibling | Both render glyph tokens; share #5 glyph font; coexist in scene tree (notebook is overlay above dialogue) |
| **#5 Glyph font** | Upstream | Uses 8×8 bitmap font for glyph rendering |
| **#21 Localization** | Upstream | "待解" UI text + decoded slot strings via `tr(loc_key)` |
| **#22 Accessibility** | Peer | Reduced-motion: no hover lift animation, no settle tween (per #9 AC-13) |

## Formulas

No formulas. Layout dimensions are tuning knobs.

**Layout constants**:
- `SLOT_SIZE = Vector2i(32, 40)` — per glyph slot (16x24 glyph + 16x16 receptacle)
- `ICON_SIZE = Vector2i(16, 16)` — per meaning-icon
- `PALETTE_GRID = Vector2i(5, 5)` — 5 columns × 5 rows (room for 25)
- `TAB_HEIGHT = 20` — vignette tab strip height
- All constants in 320×180 base resolution; scale via #3 viewport.

## Edge Cases

- **If** notebook is opened with no vignettes visited yet (all DORMANT): show empty active page with placeholder text "(no vignettes yet — talk to an NPC)" + all 7 tabs LOCKED. Palette grid still visible (25 meaning-icons accessible).
- **If** notebook is opened mid-cascade (shimmer animating on dialogue): notebook overlay renders above the world view; shimmer continues underneath. Notebook tokens for the shimmering slot also receive shimmer animation per #10 (notebook overlay registry).
- **If** player switches vignette tab while CARRIED: icon persists; new page renders; player can place on new page's slots.
- **If** active vignette page has 3 slots but player has placed 4 icons (impossible by design but defensive): only first 3 slots accept placement; "extra" icons cannot be placed (palette doesn't offer a 4th slot anyway).
- **If** screen too small to fit all 25 palette icons: palette scrolls vertically (mouse wheel + Tab navigation per #2).
- **If** player presses notebook key during DIALOGUE_OPEN: per #2 — dialogue closes first, then notebook opens (mutual exclusion). Per #2 AC-7.
- **If** player presses notebook key during CUTSCENE (shimmer animating): blocked per #2 (input locked in CUTSCENE). Notebook does not open.
- **If** player presses notebook key during `game_phase == ENDING`: blocked (per #19 + #1 ENDING lockout).
- **If** SPIKE 2 reveals drag unreliable on Firefox: drag is disabled; UI shows only click-based affordances. No "drag here" hint text.
- **If** SPIKE 2 confirms drag works: drag added as alternative; click-mode remains primary visual affordance (no "drag preferred" coaching).

## Dependencies

**Upstream**:
- #9 Symbol-binding — gesture realization
- #19 Session State — counter data + confirmed_slots reads
- #2 Input System — input events
- #5 Glyph font — bitmap glyph rendering
- #21 Localization — UI text
- #11 Dialogue display — sibling for glyph rendering consistency
- SPIKE 2 — drag viability

**Downstream**:
- #10 Cascade shimmer — animates notebook tokens on cascade (overlay registry)

**Cross-system contracts**:
1. #9 GDD documents that #16 hosts the Control nodes #9 mutates — already noted in #9 §7
2. #10 must support notebook overlay token registry (OQ-2)
3. ADR-TBD-input-routing determines whether #16 dispatches `_gui_input` to #9 or #9 subscribes directly to #2

## Tuning Knobs

| Knob | Default | Range | Effect | Owner |
|---|---|---|---|---|
| `SLOT_SIZE` | 32×40 | art-locked | Per glyph slot footprint | #16 |
| `ICON_SIZE` | 16×16 | art-locked | Per meaning-icon footprint | #16 |
| `PALETTE_GRID` | 5×5 | locked | 25-icon palette layout | #16 |
| `TAB_HEIGHT` | 20 | 16–24 | Vignette tab strip height | #16 |
| Notebook open key | N (configurable via #20 InputMap) | per #20 | Toggle binding | #20 |
| Open/close animation | none (instant) | locked | Per Player Fantasy "speed of attention" | #16 (locked) |

**Locked**:
- Click-primary input mode (drag is enhancement, per #2 reconciliation)
- No celebration animations on successful binds (per Pillar 3 + quiet authorship)
- No "tutorial popup" explaining the notebook (player learns by trial; baker MVP onboarding is the only guidance)
- Counter wording: "待解" (Chinese-default; English equivalent via #21)

## Visual/Audio Requirements

**Visual** (REQUIRED — UI system):
- Parchment-style panel chrome (consistent with Visual Identity Anchor)
- 8×8 bitmap glyph font for slot glyphs (#5)
- CJK font for "N/M 待解" counter + UI text (#21)
- Hover lift on palette icons (4px upward; per #9 ICON_LIFT_PX)
- Slot states: EMPTY shows '?' placeholder; SLOT_FILLED shows icon settled in slot; CONFIRMED shows merged parchment wash
- Tab states: LOCKED (placeholder), AVAILABLE (NPC silhouette), CASCADED (decoded name in parchment style)
- NO loading spinner on notebook open (instant)

**Audio** — minimal. Optional subtle paper-flip sound on tab switch (TBD via #4 + playtest).

**📌 Asset Spec** — Visual requirements extensive. After art bible is approved, run `/asset-spec system:notebook-ui` for full panel chrome + slot/icon/tab visual specs.

## UI Requirements

**📌 UX Flag — Notebook UI**: This is the most complex UX surface in the game. Before implementation:
- Run `/ux-design notebook` for full layout spec + interaction pattern library
- Validate with 2-3 testers on click-vs-drag preferences (informs SPIKE 2 priorities)

## Acceptance Criteria

**AC-1 — Notebook opens via input action**
GIVEN game is in NORMAL state, WHEN player presses `action_notebook_open`, THEN state transitions to NOTEBOOK_OPEN per #2, parchment panel renders, active vignette page is shown.

**AC-2 — Notebook closes via Esc**
GIVEN notebook is open (no carried icon), WHEN player presses Esc, THEN notebook closes, state returns to NORMAL.

**AC-3 — Counter displays correct unresolved count**
GIVEN baker vignette has 3 slots, player has bound 1 correctly and 1 incorrectly, WHEN notebook shows baker page, THEN counter displays "2/3 待解" (1 correct + 1 unguessed = 2 unresolved per #19 unresolved_count formula).

**AC-4 — Tab switch changes active page**
GIVEN notebook is open showing baker page, WHEN player clicks blacksmith tab, THEN blacksmith page renders; baker tokens removed from active rendering; blacksmith's slots shown.

**AC-5 — Locked tab non-interactive**
GIVEN fisher NPC has never been clicked (DORMANT per #8), WHEN player clicks fisher tab, THEN no page transition occurs; tab shows LOCKED visual.

**AC-6 — Carry state persists across tab switch**
GIVEN player is in ICON_SELECTED (CARRIED) on baker page, WHEN player switches to blacksmith tab, THEN icon remains CARRIED; player can place it on a blacksmith slot.

**AC-7 — Notebook overlay tokens shimmer on cascade**
GIVEN player has baker page open and baker cascade fires, WHEN #10 cascade shimmer animates, THEN notebook tokens for baker's slots receive shimmer animation per #10 (notebook overlay registry); slots transition to CONFIRMED visual.

**AC-8 — Open during DIALOGUE_OPEN closes dialogue first**
GIVEN DIALOGUE_OPEN with baker dialogue panel showing, WHEN player presses `action_notebook_open`, THEN dialogue panel closes (per #2 AC-7), notebook opens. State is NOTEBOOK_OPEN.

**AC-9 — Cannot open during CUTSCENE**
GIVEN cascade-shimmer animation is in progress (CUTSCENE state per #2), WHEN player presses `action_notebook_open`, THEN no state change; notebook does not open.

**AC-10 — Cannot open during ENDING**
GIVEN `game_phase == ENDING`, WHEN player presses `action_notebook_open`, THEN no state change; notebook does not open.

**AC-11 — Empty state on first open**
GIVEN no NPCs have been visited (all DORMANT), WHEN player opens notebook, THEN all 7 tabs show LOCKED, active page shows placeholder text "(no vignettes yet — talk to an NPC)", palette still displays 25 icons.

**AC-12 — Palette icon hover lift respects reduced-motion**
GIVEN OS reduced-motion flag (#22) active, WHEN player hovers over a palette icon, THEN icon does NOT lift 4px (animation suppressed); cursor still changes to indicate clickable.

**AC-13 — Page rendering meets navigation latency budget**
GIVEN notebook is open, WHEN player switches tab (Tab key or click), THEN new page is visible within 80ms (`NAVIGATION_RESPONSE_TARGET_MS` per #2); no slide animation, no fade.

**AC-14 — Click-primary affordance regardless of drag availability**
GIVEN SPIKE 2 has confirmed drag working OR drag is disabled, WHEN notebook renders, THEN UI affordances display the click pattern (hover lift, cursor change, no "drag me" hint text). Drag is silently supported as alternative if enabled.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | Notebook overlay token registry — does #10 query a separate registry, or does #16 register its tokens in a unified service? | Resolve when #10 implementation begins (see #10 OQ-2) |
| OQ-2 | Tab visual for CASCADED state — show decoded NPC name? Or just a check mark? Or both? | Resolve via `/ux-design notebook` + playtest |
| OQ-3 | Palette layout for VS+ — when icon count grows beyond 25 (if it does), how does the palette scale? Scroll? Multi-page? | Resolve when content scope expands; MVP 25-icon grid is sufficient |
| OQ-4 | Counter wording localization — "待解" in Chinese; "Remaining" or "To resolve" in English? Confirm phrasing with translator | Resolve in #21 Localization design |
| OQ-5 | First-open onboarding — does the baker dialogue line implicitly teach notebook use, or is a one-time hint needed? | Resolve via playtest of baker vignette + notebook MVP |
| OQ-6 | UX spec gap — full screen-layout + interaction pattern library needed before implementation | Resolve via `/ux-design notebook` (UX flag above) |
