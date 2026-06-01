# Dialogue Display (#11)

> **Status**: In Design
> **Author**: solo (autonomous batch) + ui-programmer + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Pillar 2 (Language IS the World) — dialogue is the village's voice; shimmer-aware rendering is the moment language becomes legible
> **System Category**: UI (Core layer) — **BOTTLENECK** (depended on by #7, #8, #10, #14)
> **Game**: Lexicon Village

## Overview

Dialogue Display is the text-rendering layer responsible for presenting NPC speech in the village. Unlike a conventional dialogue box that renders raw strings, this system stores all dialogue lines as **typed token sequences** and renders them just-in-time by querying Session State (#19) at display time. Each token is either a LEXICON_SLOT (rendered as foreign glyph when unresolved, decoded UI string when confirmed), a UI_TEXT (static localised string, never foreign), or a PUNCTUATION mark. The system is shimmer-aware: when Cascade Shimmer (#10) notifies that a slot has resolved, every currently-visible token bearing that slot_id transitions through the shimmer animation; closed or freed dialogue history panels skip animation and render the decoded form directly. Implementation path is **HBoxContainer-of-Labels (provisional, pending SPIKE 1 confirmation of Web RichTextEffect viability)** — see Detailed Design §3.7 for alternatives.

## Player Fantasy

The dialogue panel is the village's voice — the first thing you see is a wall of alien glyphs, stacked and motionless. When the cascade shimmer rolls through and one of those glyph-clusters turns into a word you recognise, the panel is no longer showing you a wall. It's showing you a sentence with a hole in it that just closed. That moment — a live glyph cluster shimmering into legibility while you're still reading the line — is the tactile proof that your notebook work changed something real. The display surface holds the before and after in the same frame, so the player feels the transition directly rather than inferring it.

## Detailed Design

### Core Rules

#### Token Data Structure

NPC dialogue lines are not strings. They are arrays of typed tokens:

```
DialogueToken:
  type: enum { LEXICON_SLOT, UI_TEXT, PUNCTUATION }
  value: Variant
    # LEXICON_SLOT → slot_id: StringName (e.g. &"NOUN_BREAD")
    # UI_TEXT      → loc_key: StringName (e.g. &"NPC_BAKER_IDLE_SUFFIX")
    # PUNCTUATION  → literal: String (e.g. "?", "!")
```

**LEXICON_SLOT** is the only type with two possible rendered forms. **UI_TEXT** always renders in the player's UI language via Localization (#21) — never as foreign glyph, never shimmer-animated. **PUNCTUATION** is always a literal character.

Rationale: storing slot_ids rather than raw glyphs decouples dialogue content from the language seed. When the procedural generator (#12) produces a new seed, the same token sequence renders different glyph strings without authoring change.

#### Rendering Decision Per Token

At render time, for each LEXICON_SLOT token:

```
if slot_id in session_state.confirmed_slots:
    render resolved_string(slot_id)   # player's UI language, via #21
else:
    render glyph_string(slot_id)      # 8×8 foreign script via #5
```

`resolved_string` via Localization (#21) key `LOC_SLOT_{slot_id}`. `glyph_string` via Language Generator (#12) / hand-authored table mapping slot_id to current seed's phonetic form in glyph font. Both are dictionary reads; non-blocking.

#### Typewriter Playback

`CHARS_PER_SECOND = 30` (matches Night Market RPG precedent). Token-aware: does not split mid-glyph inside a LEXICON_SLOT token. If a LEXICON_SLOT has 4 glyph characters, all 4 appear at the typewriter rate — but the typewriter never breaks the token boundary mid-render.

Player skips typewriter via advance input (Space / Enter / primary click / touch tap), completing the full current line immediately.

#### Shimmer Contract with #10

**Rule 1 — Visible instances only.** When #10 notifies `slot_resolved(slot_id)`, Dialogue Display animates shimmer only on token nodes currently visible on screen. Off-screen or freed panels do not receive animation calls.

**Rule 2 — Freed history renders resolved directly.** Dialogue history that has been closed (panel freed or pooled) is NOT re-instantiated to animate. When a history entry is next displayed, it renders all previously-resolved slots in decoded form immediately, with a quiet glow-in fade (~0.3s) per GDD Shimmer Spec "Retroactive resolve" — no ripple, no audio.

**Rule 3 — Multiple instances of same slot in one line.** If a line contains NOUN_BREAD at token positions 0 and 3, both Label nodes receive shimmer calls independently. They animate in sequence or parallel as #10 chooses within its 80-glyph cap — Dialogue Display does not coordinate order.

**Rule 4 — Notification interface.** #10 calls via signal: `cascade_shimmer.slot_resolved.connect(dialogue_display._on_slot_resolved)`. Dialogue Display's `_on_slot_resolved(slot_id: StringName)` iterates `_active_tokens` registry and triggers per-node shimmer playback for matching slot_ids.

**Rule 5 — Shimmer does not change data.** Shimmer animation is presentation only. `confirmed_slots` is source of truth (#19). Interrupted shimmer leaves slot confirmed in data; no re-animation needed (Rule 2 covers reopen path).

#### Godot Implementation: HBoxContainer-of-Labels (provisional, pending SPIKE 1)

Three options evaluated:

- **Option A — RichTextLabel + BBCode effects**: GDD concept doc names this for SPIKE 1. Gives per-character control but no native per-word node registry. Cross-browser RichTextEffect reliability on Compatibility renderer unverified. If SPIKE 1 passes, viable for shimmer rendering inside #10's system, but Dialogue Display should not be the RichTextLabel owner for token-level shimmer.
- **Option B — HBoxContainer-of-Labels (RECOMMENDED for MVP/VS)**: Each token is a Label inside an HBoxContainer (or FlowContainer for multi-line). LEXICON_SLOT tokens get Label with glyph font; UI_TEXT tokens get Label with CJK/UI font. Natural first-class Control nodes per token; shimmer manipulates `modulate` or calls `play_shimmer()` on each Label directly. ~10–20 nodes per line × 3 lines = 30–60 nodes in active panel (well within budget).
- **Option C — Custom Control + shader**: Maximum control. Defer to #10 post-SPIKE-1.

**Recommended Option B for MVP/VS. If SPIKE 1 confirms RichTextEffect Web viability, #10 may adopt Option A internally for shimmer rendering while using #11's HBoxContainer nodes as targets — not mutually exclusive. Implementation choice is provisional; final lock awaits SPIKE 1 results.**

Font per token type: LEXICON_SLOT → glyph bitmap font (8×8, NEAREST, per #5); UI_TEXT → CJK-supporting font (per #21); PUNCTUATION → CJK font. Both fonts coexist in same HBoxContainer row via per-Label `add_theme_font_override`.

#### Token Node Registry

```
_active_tokens: Dictionary  # slot_id → Array[Control]
```

When a line is displayed, each LEXICON_SLOT token's Label is registered: `_active_tokens[slot_id].append(node)`. When line is dismissed (DIALOGUE_FREED), registry is cleared / nodes pooled. Structure #10 queries via `_on_slot_resolved`.

#### Dialogue History

Stored as ordered Array of token sequences (NOT rendered nodes), capped at `HISTORY_CAPACITY = 20`. When a history entry is displayed, rendered on demand using same `_render_line(tokens)` logic, except: no typewriter playback (instant); resolved slots render decoded; slots that resolved AFTER the line was first shown get glow-in fade (~0.3s).

History owned by Dialogue Display, NOT by Vignette State Machine (#8).

### States and Transitions

| State | Description | Entry | Exit |
|---|---|---|---|
| **DIALOGUE_HIDDEN** | Panel invisible; no active line | Boot / after FREED clears | NPC interaction begins |
| **DIALOGUE_SHOWING** | Active line playing or complete; player can advance | NPC trigger | Player advances past final line, or cascade fires + phase transitions |
| **DIALOGUE_FREED** | Panel closed; content in history pool (not in scene tree) | Player closes panel / vignette completes | History entry opened, or session ends |

Sub-phases of DIALOGUE_SHOWING (intro / action / closing lines) are owned by #8 Vignette State Machine. Dialogue Display exposes `show_line(tokens)`, `advance()`, `hide()` API.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **#5 Glyph font rendering** | Upstream | Provides FontFile resource for LEXICON_SLOT Labels |
| **#21 Localization** | Upstream | Provides `tr(loc_key)` for UI_TEXT tokens + `resolved_string(slot_id)` |
| **#19 Game session state** | Upstream | Read-only: `confirmed_slots` queried per token at render time |
| **#10 Cascade shimmer** | Peer (contract) | #10 calls `_on_slot_resolved(slot_id)`; #11 exposes `_active_tokens` registry |
| **#7 NPC sprite & tableau** | Downstream | #7 calls `show_line()` at tableau moments |
| **#8 Vignette state machine** | Downstream | #8 orchestrates line sequences; calls `show_line()`, `advance()`, `hide()` |
| **#14 NPC revisit idle line** | Downstream | #14 supplies post-cascade token sequences via normal `show_line()` |

**⚠️ Cross-doc correction note**: #19 GDD's "Explicitly NOT dependent" table lists #11 as going through intermediaries. **This design reads #19 directly.** The #19 GDD's dependency table should be updated to reflect #11 as direct dependent. Tracked as housekeeping for Phase 5b.

## Formulas

**Formula 1 — Typewriter character output rate**

`chars_visible(t) = floor(CHARS_PER_SECOND × t)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Time elapsed since line shown | t | float | 0..∞ | Seconds |
| Typewriter rate | CHARS_PER_SECOND | int | 10–60 (default 30) | Characters per second |
| Characters visible | chars_visible | int | 0..line_char_count | Clamps at line end |

Example: at t=0.5s, chars_visible = floor(30 × 0.5) = 15 characters visible.

Token boundary rule: if `chars_visible` falls mid-glyph-cluster inside a LEXICON_SLOT, the whole token renders as hidden until count reaches token's end index. Tokens never split mid-render.

**Formula 2 — History render budget (informational)**

`max_active_nodes = HISTORY_CAPACITY × AVG_TOKENS_PER_LINE × AVG_CHARS_PER_TOKEN`

At defaults (20 × 5 × 4) = 400 Label nodes maximum if all history is open simultaneously. History is collapsible — only visible entries instantiate nodes.

## Edge Cases

- **EC-1 — Dialogue closes mid-cascade**: `_active_tokens` cleared on DIALOGUE_FREED. #10's pending shimmer callbacks fire into freed objects — Dialogue Display must use `is_instance_valid(node)` guards in `_on_slot_resolved`. No crash, no re-instantiation.
- **EC-2 — Resolve happens mid-typewriter (slot at not-yet-revealed token)**: shimmer is deferred to the moment that token becomes visible. `_on_slot_resolved` marks slot dirty; per-token reveal checks dirty set and applies glow-in fade on first reveal.
- **EC-3 — Multiple instances of same slot in one line**: `_active_tokens[&"NOUN_BREAD"]` holds both Label nodes. Both receive shimmer calls. If 80-glyph cap is near, #10 queues — Dialogue Display does not coordinate.
- **EC-4 — Font fallback CJK + glyph simultaneously**: each token's Label has its font explicitly overridden. CJK Label uses bundled CJK TTF; glyph Label uses bitmap font. Both render correctly in same HBoxContainer row. Token-level Labels eliminate fallback ambiguity.
- **EC-5 — History opened before any cascade (all unresolved)**: all LEXICON_SLOT tokens render as foreign glyphs. No special case — empty `confirmed_slots` means all glyphs.
- **EC-6 — Player skips typewriter on first frame**: `advance()` called, `chars_visible = line_char_count`. All tokens render fully. Dirty slots apply glow-in fade immediately upon full reveal.
- **EC-7 — NPC revisit idle line post-cascade**: #14 supplies token sequence where all LEXICON_SLOT tokens are in `confirmed_slots`. Renders decoded with no animation. Normal render path; no #14-specific code.
- **EC-8 — Zero-token line (authoring error)**: `show_line([])` called. Empty panel; immediately completes (no typewriter tick). `push_error` logs authoring error. No crash.

## Dependencies

| System | Direction | Interface |
|---|---|---|
| #5 Glyph font rendering | Upstream Hard | FontFile resource |
| #21 Localization | Upstream Hard | `tr(loc_key)`, `resolved_string(slot_id)` |
| #19 Session State | Upstream Hard (direct read) | `confirmed_slots` query per render |
| #10 Cascade shimmer | Peer (contract) | `slot_resolved(slot_id)` signal in; `_active_tokens` registry exposed |
| #7 NPC sprite & tableau | Downstream Hard | `show_line()` API |
| #8 Vignette state machine | Downstream Hard | `show_line()`, `advance()`, `hide()` API |
| #14 NPC revisit idle line | Downstream Hard | Post-cascade `show_line()` |

**Cross-system contracts to backfill**:
1. #19 GDD dependency table needs #11 added as direct dependent (correction noted)
2. #10 GDD must define `slot_resolved(slot_id)` signal signature and timing
3. #8 GDD must use `show_line()` / `advance()` / `hide()` API exactly as spec'd here
4. #14 GDD must structure idle lines as token sequences (not raw strings)

## Tuning Knobs

| Knob | Constant | Default | Safe Range | Effect |
|---|---|---|---|---|
| Typewriter rate | `CHARS_PER_SECOND` | 30 | 10–60 | Slower = more dramatic; faster = less theatrical |
| Line dwell time | `LINE_DWELL_SEC` | 0.5 | 0.0–2.0 | Seconds after typewriter completes before auto-advance enabled |
| History capacity | `HISTORY_CAPACITY` | 20 | 5–40 | Past lines stored |
| Glow-in fade | `RETROACTIVE_FADE_SEC` | 0.3 | 0.1–0.8 | Quiet glow-in for resolved-in-history |
| Panel auto-hide | `PANEL_AUTOHIDE_SEC` | 0.0 | 0.0–3.0 | 0.0 = never auto-hide |

## Visual/Audio Requirements

- Dialogue panel chrome: parchment-style box (per #16 Notebook UI direction; same visual family)
- Glyph rendering: 8×8 bitmap NEAREST per #5
- CJK rendering: bundled TTF per #21
- Typewriter sound: TBD per #4 (audio system) — concept doc mentions "dialogue blip" as one of the 3 sound assets
- Shimmer animation visual: owned by #10
- Glow-in fade visual: simple alpha/modulate tween, no shader

**📌 Asset Spec** — Visual requirements are defined. After art bible is approved, run `/asset-spec system:dialogue-display` for panel chrome dimensions and visual treatment specs.

## UI Requirements

Dialogue panel layout: bottom-center of viewport, occupies ~30% of screen height. Multi-line wrapping via FlowContainer (TBD validated in SPIKE 1 alongside RichTextEffect). Player advance prompt indicator ("press space" or "▾" arrow) appears after typewriter completes + `LINE_DWELL_SEC`.

**📌 UX Flag — Dialogue Display**: Dialogue panel layout + history scroll UX need full spec. In Phase 4 (Pre-Production), run `/ux-design dialogue-panel` before writing implementation epics.

## Acceptance Criteria

**AC-1 — Unresolved slot renders as foreign glyph**
GIVEN `NOUN_BREAD` is not in `confirmed_slots`, WHEN a dialogue line containing a LEXICON_SLOT token for `NOUN_BREAD` is shown, THEN the token node renders using the glyph bitmap font and the slot's seed-derived glyph string.

**AC-2 — Resolved slot renders as decoded UI string**
GIVEN `NOUN_BREAD` is in `confirmed_slots`, WHEN the same line is shown or re-rendered from history, THEN the token node renders using the CJK/UI font and the localised `LOC_SLOT_NOUN_BREAD` string.

**AC-3 — Typewriter rate correct**
GIVEN `CHARS_PER_SECOND = 30` and a line with 15 total characters, WHEN the line begins displaying, THEN at t=0.5s exactly 15 characters are visible; at t=0.25s no more than 8 are visible.

**AC-4 — Typewriter does not split tokens mid-render**
GIVEN a LEXICON_SLOT token whose glyph string is 4 characters, WHEN typewriter count reaches token's start index, THEN 0 characters of the token are visible until count reaches end index, then all 4 appear simultaneously.

**AC-5 — Typewriter skip**
GIVEN a line is mid-typewriter, WHEN the player presses advance input, THEN all tokens become immediately fully visible with no further typewriter ticks.

**AC-6 — Visible token receives shimmer on slot resolve**
GIVEN a dialogue line is visible in DIALOGUE_SHOWING and contains a LEXICON_SLOT for `VERB_GIVE`, WHEN #10 emits `slot_resolved(VERB_GIVE)`, THEN the token node in the active panel receives a shimmer animation call.

**AC-7 — Freed panel does not crash on slot resolve**
GIVEN a dialogue panel that has been dismissed (DIALOGUE_FREED) and whose nodes are freed, WHEN `slot_resolved` fires for a slot that was in that panel, THEN no crash occurs and no freed node is accessed (via `is_instance_valid` guards).

**AC-8 — History retroactive resolve renders with glow-in fade**
GIVEN `NOUN_BREAD` resolved after baker's intro line was dismissed, WHEN the player opens history and the baker intro is displayed, THEN `NOUN_BREAD`'s token renders decoded with a 0.3s glow-in fade and NO cascade ripple sound or animation.

**AC-9 — Unresolved history slots render as glyphs**
GIVEN `VERB_GIVE` is not yet confirmed, WHEN a history entry containing `VERB_GIVE` is displayed, THEN that token renders as a foreign glyph, identical to its live rendering.

**AC-10 — Multiple same-slot instances each shimmer**
GIVEN a dialogue line containing two LEXICON_SLOT tokens for `NOUN_BREAD` (positions 0 and 3), WHEN `slot_resolved(NOUN_BREAD)` fires, THEN both Label nodes are individually called into `_on_slot_resolved`, both registered in `_active_tokens[&"NOUN_BREAD"]`.

**AC-11 — No CJK/glyph font collision in same line**
GIVEN a dialogue line with a UI_TEXT token (Chinese characters) adjacent to a LEXICON_SLOT token, WHEN the line is rendered, THEN the CJK token's Label has only CJK font override; the glyph token's Label has only bitmap font override; no Label renders both fonts simultaneously.

**AC-12 — show_line / advance / hide API**
GIVEN #8 calls `show_line([token_a, token_b])`, WHEN typewriter completes and `advance()` is called, THEN `hide()` transitions to DIALOGUE_FREED and clears `_active_tokens`.

**AC-13 — History capacity cap**
GIVEN `HISTORY_CAPACITY = 20` and 21 lines shown, WHEN history queried, THEN at most 20 entries are stored (oldest dropped).

**AC-14 — Phase guard: no show_line during ENDING**
GIVEN `game_phase == ENDING`, WHEN `show_line()` is called (e.g., stale #8 event), THEN Dialogue Display ignores the call and logs `push_error`; panel remains hidden.

## Open Questions

| # | Question | Owner / Resolution |
|---|---|---|
| OQ-1 | RichTextLabel vs HBoxContainer-of-Labels final lock | Resolve post SPIKE 1 (shimmer architecture on Web) |
| OQ-2 | FlowContainer wrapping behaviour on Web export — does multi-line dialogue wrap correctly? | Verify in SPIKE 1 |
| OQ-3 | Should advance input also dismiss the panel after final line, or require an explicit close gesture? | Resolve when #8 Vignette State Machine designed |
| OQ-4 | History UI affordance — modal scroll? Slide-in drawer? Always-visible mini? | Resolve via `/ux-design dialogue-panel` |
| OQ-5 | Dialogue blip SFX per character vs per token vs muted | Owned by #4 Audio when designed |
| OQ-6 | Token authoring tooling — Godot Inspector vs JSON file vs custom resource | Implementation detail; defer to ADR or first vignette content authoring (#13) |
