# Cascade Shimmer Animation (#10)

> **Status**: In Design
> **Author**: solo (autonomous batch) + technical-artist + game-designer + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 1 (Discovery above Mastery) — **CENTRAL FEEL system, main delivery vector for "small private fireworks of comprehension"**
> **System Category**: Gameplay (Feature layer) — **HIGH RISK** (CENTRAL FEEL + SPIKE 1 gated)
> **Game**: Lexicon Village

## Overview

Cascade Shimmer Animation animates the per-glyph color and transform transition that celebrates vignette completion. When Session State (#19) emits `vignette_completed(vignette_id)`, this system reads the triggering NPC's world-space position, computes a radial ripple wavefront that expands outward from that origin across the viewport over ~1.5 seconds (ease-out), and drives each visible LEXICON_SLOT token node registered in Dialogue Display (#11)'s `_active_tokens` through a color transition: faded parchment baseline → warm sun-yellow overshoot → fresh ink resolved. It fires a single soft chime audio cue spatially panned to the ripple origin. Off-screen tokens skip animation and are marked resolved directly. At most one ripple is active; additional `vignette_completed` signals queue behind a 0.3-second delay. The system has no data responsibilities — Session State is the authority; shimmer is presentation only. **Implementation path is Option B (per-Label modulate Tween, provisional pending SPIKE 1)**.

## Player Fantasy

You have been staring at the baker's three foreign words for ten minutes. You swap the last icon into place and close the notebook. Nothing happens for a beat.

Then it begins at the baker's feet.

A warmth spreads outward across the dialogue panel, across the shop sign, across the memory of her first line — not all at once, not a flash, but a wave you can track with your eyes. The glyphs you have been staring at long enough to memorize their shapes briefly flare sun-yellow — vivid, a little startling — and then settle into something legible. Words you know now. Every instance, simultaneously untangled.

This is the small private fireworks of comprehension. The shimmer is not a reward delivered to you; it is **comprehension made physically visible**. The wave spreading across the world IS the understanding spreading across your mind. The brevity of it — 1.5 seconds and done — is intentional. You don't watch it, you witness it; and then the world is slightly more legible than it was before.

## Detailed Design

### Core Rules

**Rule 1 — When Shimmer Fires.** Listens to `session_state.vignette_completed(vignette_id)`. Resolves the NPC's world position via `vignette_id → world_position: Vector2` lookup (authored in #13 vignette content). Does NOT poll Session State or independently validate binding correctness.

**Trigger gate (per game-designer warning)**: shimmer SHOULD fire only when the notebook is closed and the player is back in the world view. If notebook is open at trigger time, defer shimmer start until notebook closes. (If wave's spatial spread has nowhere visible to spread, the cascade collapses to "one text field updated" — kills the fantasy. See AC-16.)

**Rule 2 — Ripple Propagation.** Radial wavefront expanding from NPC's projected screen position. Tokens animate in arrival-order (nearest first). Wavefront eases out (fast near origin, slow at edges). Screen-space distance computed at shimmer start; not recomputed per frame.

**Rule 3 — Per-Glyph Three-Phase Animation.** Each glyph passes through:
1. **Approach** (`APPROACH_DURATION` = 0.1s): `COLOR_FADED` → `COLOR_PEAK` (the rising warmth — NOT a flash)
2. **Dwell** (`DWELL_DURATION` = 0.4s): hold at `COLOR_PEAK` — **this dwell is the perceptual barrier between "flash" and "wave"; must remain ≥0.3s**
3. **Settle** (`SETTLE_DURATION` = 0.15s): `COLOR_PEAK` → `COLOR_RESOLVED`

Per game-designer warning: **the approach + dwell + settle MUST read as a three-act color transition, not a single brightness spike**. If implementer collapses them into one tween, the cascade reads as a pop. The dwell phase is load-bearing for the "wave" percept.

**Implementation (Option B, provisional)**: each LEXICON_SLOT token Label gets a chained Tween on `modulate`. No shader, no RichTextEffect. Compatible with #11's HBoxContainer-of-Labels.

**Rule 4 — Concurrency Queue.** Max 1 active ripple. Additional `vignette_completed` queued behind `QUEUE_GAP_DELAY` = 0.3s after current wavefront's end (not after all glyphs fully settle — dwell/settle of earlier glyphs may overlap with next wavefront's propagation; visually readable because wavefronts have different spatial origins).

**Rule 5 — Visible-Only Animation.** Animates only tokens with `visible == true` AND `get_global_rect()` intersecting `get_viewport_rect()` at shimmer start. Off-screen tokens set `modulate = COLOR_RESOLVED` immediately (single frame, no Tween). Active panel only (per #11's `_active_tokens` registry).

**Rule 6 — Retroactive Resolve (history reopen)**: NOT this system's responsibility. Per #11 Rule 2, history reopen renders decoded with quiet glow-in fade (0.3s, no `COLOR_PEAK` overshoot, no chime). #10 only fires on the original `vignette_completed`; not on history re-render.

### States and Transitions

| State | Description |
|---|---|
| IDLE | No ripple active, queue empty |
| RIPPLE_ACTIVE | Wavefront propagating; queued ripples wait |
| QUEUE_GAP | Wavefront ended; waiting `QUEUE_GAP_DELAY` before next ripple |

### Interactions with Other Systems

| System | Direction | Interface | Type |
|---|---|---|---|
| **#19 Session State** | Upstream (signal) | `vignette_completed(vignette_id: StringName)` | Hard |
| **#11 Dialogue display** | Peer (registry) | Reads `_active_tokens`; calls `play_shimmer()` on Label nodes | Hard |
| **#13 Vignette content** | Upstream (data) | `vignette_id → world_position: Vector2` lookup | Hard |
| **#5 Glyph font rendering** | Upstream (asset) | Token Label uses glyph font; shimmer drives `modulate` | Soft |
| **#4 Audio system** | Downstream | Plays chime via `AudioStreamPlayer2D.play()` with pan | Soft — NOT load-bearing |
| **#3 Camera & viewport** | Upstream (spatial) | Camera2D transform for world→screen projection | Hard |
| **#22 Accessibility motion fallback** | Peer (override) | Reduced-motion → simultaneous resolve, no wavefront stagger | Soft |
| **SPIKE 1 result** | BLOCKING gate | Web RichTextEffect viability; determines Option A vs B vs C lock | Implementation gate |

## Formulas

**Formula 1 — Ease-Out Wavefront Radius**

`r(t) = R_MAX × (1 - (1 - t/RIPPLE_DURATION)²)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `t` | float | 0..RIPPLE_DURATION | Seconds since shimmer start |
| `RIPPLE_DURATION` | float | 0.8–1.8s (default 1.2s) | Wavefront travel time |
| `R_MAX` | float | viewport diagonal | `sqrt(W² + H²)` at shimmer start |
| `r(t)` | float | 0..R_MAX | Wavefront radius in pixels |

**Formula 2 — Token Arrival Delay** (invert Formula 1)

`t_arrive(token) = RIPPLE_DURATION × (1 - sqrt(1 - dist/R_MAX))`

Where `dist = distance(origin_screen, token.get_global_rect().get_center())`.

**Example** at viewport 1024×768 (R_MAX≈1280px), `RIPPLE_DURATION=1.2s`:
- Token at dist=412px → `t_arrive ≈ 0.21s`
- Token at dist=1100px → `t_arrive ≈ 0.73s`
- Wavefront palpably decelerates at periphery (correct ease-out behavior)

**Formula 3 — Total Shimmer Timeline**

`SHIMMER_TOTAL_DURATION = RIPPLE_DURATION + APPROACH_DURATION + DWELL_DURATION + SETTLE_DURATION ≈ 1.85s`

System considers shimmer "complete" when last glyph's Tween finishes.

**Formula 4 — Audio Pan**

`pan = (origin_screen.x / VIEWPORT_WIDTH - 0.5) × 2.0 × PAN_RANGE`

Default `PAN_RANGE = 0.6`. NPC at screen x=200 on 1024px viewport → pan ≈ -0.366 (slightly left).

## Edge Cases

- **EC-1 — Off-screen tokens**: set `modulate = COLOR_RESOLVED` immediately, no Tween. If scrolls into view later, already correct.
- **EC-2 — Notebook overlay tokens (screen-space, no world origin)**: screen-space distance math works uniformly. Notebook tokens registered separately from dialogue tokens (see OQ-2). Both registries queried at shimmer start.
- **EC-3 — Two vignettes complete same frame**: synchronous signal emissions; first ripple begins immediately, second queued per Rule 4. No dropped signals.
- **EC-4 — Shimmer fires while typewriter active**: unrevealed tokens not in visible rendering. Per Rule 5: skipped. When typewriter reveals later, #11's deferred-resolve fires `RETROACTIVE_FADE_SEC` glow-in.
- **EC-5 — Reduced-motion (#22 active)**: wavefront propagation suppressed. All visible tokens resolve simultaneously with single `DWELL_DURATION` hold at `COLOR_PEAK` then settle. Audio chime still fires. Preserves color payoff while removing spatial motion.
- **EC-6 — Audio muted**: shimmer visual fires normally; system never gates on audio state. Game remains meaningful (per concept doc Shimmer Spec).
- **EC-7 — Vignette origin missing (authoring error)**: default to viewport center; log `push_error`. Animation proceeds; no crash.
- **EC-8 — 80-glyph cap exceeded**: excess tokens (largest `t_arrive`) resolve directly without animation. The 80 nearest animate. Cap is safety ceiling for pathological cases.
- **EC-9 — Node freed mid-shimmer**: Tweens use `is_instance_valid()` guards (mirroring #11 EC-1 pattern). On `NOTIFICATION_PREDELETE`, kill the Tween.
- **EC-10 — Trigger fires while notebook open**: defer shimmer start until notebook closes (per game-designer warning Rule 1). Player must see the wave spread across the world view, not collapse to one in-notebook update.
- **EC-11 — First-vignette (baker) must have ≥2 on-screen instances**: authoring constraint — baker's vignette must include at least one dialogue line AND one world-space sign/banner with shared decoded words. If only one glyph would animate, the cascade is not a "spread" — it's "one word changed." MVP baker scene authoring constraint.

## Anti-Patterns (DO NOT IMPLEMENT)

Per game-designer game-feel review — these violate the contemplative/quiet aesthetic and will fail the playtest acceptance test (AC-15):

- ❌ **NO particle systems, sparkles, or secondary VFX on glyphs during transition.** Any particle burst turns cascade into celebration explosion. The world is otherwise static — shimmer is the only motion (Pillar 1 design test).
- ❌ **NO screen shake or camera shake**, even subtle (1-2px). Shake maps to impact/force — opposite of comprehension spreading like light.
- ❌ **NO percussive transient on the audio chime.** No click, ping, or bright attack. Must be pure tone or soft harmonic with slow attack. Otherwise it registers as "ding! you got points!" — achievement feedback, not comprehension.
- ❌ **NO collapsing the 3-phase color transition into 1 tween.** Approach + Dwell + Settle MUST execute as distinct phases or the percept collapses from "wave" to "pop."

## Dependencies

See Interactions table. Critical contracts:
1. #19 must formally type `vignette_completed(vignette_id: StringName)` signal
2. #11 must expose `_active_tokens` for direct read access (per #11 Rule 4)
3. #13 must include `world_position: Vector2` per NPC vignette entry
4. #16 must register notebook tokens (separate registry; see OQ-2)

**SPIKE 1 is BLOCKING for final implementation lock.**

## Tuning Knobs

| Knob | Default | Range | Effect |
|---|---|---|---|
| `RIPPLE_DURATION` | 1.2s | 0.8–1.8s | Wavefront duration; shorter = faster sweep |
| `APPROACH_DURATION` | 0.1s | 0.05–0.3s | Per-glyph rise into COLOR_PEAK |
| `DWELL_DURATION` | 0.4s | 0.2–0.8s | Hold at COLOR_PEAK; **load-bearing for wave percept** |
| `SETTLE_DURATION` | 0.15s | 0.1–0.4s | Per-glyph fade COLOR_PEAK → COLOR_RESOLVED |
| `QUEUE_GAP_DELAY` | 0.3s | 0.1–0.8s | Gap between queued ripples |
| `COLOR_PEAK` | warm sun-yellow `Color(1.0, 0.9, 0.5, 1.0)` | art-directed | **HIGH RISK** — at 16-bit pixel palette, may read as white flash, not warmth (see OQ-6) |
| `COLOR_FADED` | parchment glyph `Color(0.7, 0.65, 0.55, 0.8)` | art-directed | Baseline unresolved |
| `COLOR_RESOLVED` | fresh ink `Color(0.15, 0.1, 0.05, 1.0)` | art-directed | Final decoded color |
| `MAX_ANIMATED_GLYPHS` | 80 | 40–120 | Performance safety cap |
| `PAN_RANGE` | 0.6 | 0.0–1.0 | Audio stereo width |

## Visual/Audio Requirements

**Visual** (REQUIRED for this CENTRAL FEEL system):
- `COLOR_FADED` / `COLOR_PEAK` / `COLOR_RESOLVED` palette must be locked in art bible
- Glyph rendering driven by #5 (8×8 bitmap, NEAREST filter)
- NO particle effects, NO screen shake, NO sprite VFX layered on glyph

**Audio** (`#4` Audio system owns the asset):
- Soft chime tone, ~1.2s duration
- Pure tone or soft harmonic, SLOW ATTACK (no percussive transient)
- Spatially panned per Formula 4
- Same sample used for all 7 cascades (no escalation; concept doc Shimmer Spec line 286 explicit)
- NOT load-bearing — game must remain meaningful muted

**📌 Asset Spec** — Visual + audio requirements are defined. After art bible is approved, run `/asset-spec system:cascade-shimmer` for color palette locks + chime audio spec.

## UI Requirements

No standalone UI. Shimmer drives existing token nodes owned by #11.

## Acceptance Criteria

**AC-1 — Shimmer fires on vignette_completed signal**
GIVEN baker vignette is not yet cascaded, WHEN Session State emits `vignette_completed(baker_id)`, THEN Cascade Shimmer begins a ripple within the same frame (if notebook is closed) OR defers until notebook closes (per Rule 1 trigger gate).

**AC-2 — Ripple origin is NPC world position projected to screen**
GIVEN baker NPC is at world position (200, 400), WHEN shimmer fires, THEN ripple origin screen position equals Camera2D-projected (200, 400), NOT viewport center.

**AC-3 — Tokens animate in distance order (nearest first)**
GIVEN two visible tokens at screen distances 100px and 600px from origin, WHEN shimmer fires, THEN `t_arrive(100px) < t_arrive(600px)`.

**AC-4 — Ease-out: near tokens animate disproportionately earlier**
GIVEN tokens at distances 100px, 500px, 900px from origin, WHEN shimmer fires, THEN `t_arrive(100px) < t_arrive(500px) × 0.5` (confirms ease-out curvature, not linear spacing).

**AC-5 — Per-glyph 3-phase color animation completes correctly**
GIVEN a visible token begins shimmer at its `t_arrive`, WHEN time `APPROACH_DURATION` elapses, THEN `label.modulate == COLOR_PEAK`; WHEN `APPROACH + DWELL` elapses, THEN still `COLOR_PEAK` (dwell holds); WHEN `APPROACH + DWELL + SETTLE` elapses, THEN `modulate == COLOR_RESOLVED`.

**AC-6 — Off-screen tokens resolve directly (no animation)**
GIVEN a token whose `get_global_rect()` does not intersect viewport at shimmer start, WHEN shimmer fires, THEN that token's `modulate = COLOR_RESOLVED` in same frame, NO Tween created for it.

**AC-7 — Max 1 concurrent ripple**
GIVEN a ripple is active with 0.6s wavefront remaining, WHEN second `vignette_completed` fires, THEN second ripple does NOT begin until first wavefront ends + `QUEUE_GAP_DELAY`.

**AC-8 — Queue does not drop completions**
GIVEN three `vignette_completed` signals within 0.1s, WHEN processed, THEN all three ripples eventually animate sequentially (none dropped).

**AC-9 — 80-glyph cap: excess resolve directly**
GIVEN test scene with 90 visible LEXICON_SLOT tokens, WHEN shimmer fires, THEN exactly 80 receive Tween animation; remaining 10 have `modulate == COLOR_RESOLVED` immediately. Total Tweens ≤ 80.

**AC-10 — Freed node mid-shimmer: no crash**
GIVEN a shimmer Tween targeting a Label, WHEN that Label is freed (panel dismissed), THEN no crash, no orphaned running Tween (verified via `is_instance_valid()` guards).

**AC-11 — Audio chime fires once per ripple, panned correctly**
GIVEN vignette completes with NPC origin at screen x=256 on 1024px viewport, WHEN shimmer fires, THEN chime plays once with negative pan value (left channel dominant, pan ≈ −0.366 per Formula 4).

**AC-12 — Reduced-motion fallback: simultaneous resolve**
GIVEN accessibility reduced-motion (#22) active, WHEN shimmer fires, THEN all visible tokens receive `t_arrive = 0` (simultaneous); color phases still execute; no wavefront stagger.

**AC-13 — Audio muted: visual still plays**
GIVEN audio bus muted, WHEN shimmer fires, THEN per-glyph color animation executes normally (AC-5 holds); no error; no frame skipped.

**AC-14 — Retroactive resolve is NOT a ripple**
GIVEN `NOUN_BREAD` resolved in earlier playthrough segment, WHEN player reopens dialogue history showing a line containing it, THEN NO cascade ripple, NO chime. Token renders decoded with #11's glow-in fade (~0.3s).

**AC-15 — PLAYTEST ACCEPTANCE TEST: spread description (CRITICAL)**
GIVEN baker vignette completes in MVP playtest with ≥3 first-time testers, WHEN each tester independently describes what they saw, THEN ≥3 of 3 testers use language in {sweep, wave, spreading, rippling, rolling, radiating}; NONE use {flash, pop, blink, burst, explosion} as primary description. If language suggests dramatic burst, `RIPPLE_DURATION` must lengthen and/or `DWELL_DURATION` must shorten before further vignette development proceeds.

**AC-16 — Notebook-open defers shimmer start**
GIVEN player has notebook open, WHEN `vignette_completed` fires, THEN shimmer does NOT begin until notebook is closed (player back in world view). The wavefront must have visible spatial extent to spread across; in-notebook firing collapses the fantasy.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | **SPIKE 1 gate**: RichTextEffect Web viability on Chrome + Firefox; AccessKit interaction risk in 4.5+ | SPIKE 1 (`prototypes/shimmer-spike/`) — BLOCKING for Option A/B/C final lock |
| OQ-2 | Notebook overlay token registry — separate from `_active_tokens` (which is dialogue-only)? Unified Token Registry Service? | Resolve when #16 Notebook UI designed |
| OQ-3 | Reduced-motion fallback (EC-5) — is simultaneous-resolve sufficient, or also remove color-peak overshoot for motion-sensitive players? | Resolve when #22 designed |
| OQ-4 | World-space signs/banners — MVP scope or Vertical Slice? Who owns the world-sign token registry? | Resolve at start of shimmer implementation sprint; may affect AC-11 (baker on-screen instance count) |
| OQ-5 | `vignette_completed` signal signature — formal GDScript declaration; does it carry slot list to avoid #10 lookup? | Resolve via cross-doc backfill with #19 |
| OQ-6 | **SUN-YELLOW OVERSHOOT RISK** (game-designer biggest risk): at 16-bit pixel palette, sun-yellow may read as white flash, not warmth. Must validate on Web export at native display brightness on ≥2 displays. Editor preview will NOT reveal this. | **SPIKE 1 acceptance criterion** — add to spike scope |
| OQ-7 | Per game-designer cadence note: cascade #7 (later vignettes) may animate more glyphs than #1 (baker, MVP). Should later cascades feel proportionally more dramatic (intentional escalation), or budgeted equally? | Resolve via playtest of full 7-vignette run in VS+ |
