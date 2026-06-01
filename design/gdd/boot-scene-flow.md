# Boot & Scene Flow (#1)

> **Status**: In Design
> **Author**: solo (user-driven) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Infrastructure — enables all other systems by orchestrating scene transitions and engine init
> **System Category**: Core (Foundation layer)
> **Game**: Lexicon Village

## Overview

Boot & Scene Flow is the application's entry-point system. It runs at process start, initializes the Autoloads (Game Session State #19, Input System #2, Audio #4 once authored, Localization #21 once authored), generates the language seed via the procedural language generator (#12 when implemented; for MVP it just picks a hard-coded seed), then presents the Title screen (#17). It owns the global scene transition contract — Title → Game → Ending → Title — and is responsible for instantiating and tearing down the per-playthrough scenes at the right moments. It does NOT own gameplay logic; it owns the **shell** that gameplay logic runs inside.

The player perceives this system through three concrete moments: (1) **page load time** — how long from clicking the itch.io play button to the Title appearing (target <8s per `production/qa/qa-plan-sprint-1-2026-05-28.md` Performance criteria; locked elsewhere); (2) **scene transitions** — Title-to-Game, Game-to-Ending, Ending-to-Title — which should feel like a smooth turn-of-the-page, not a load screen, and not a jarring snap; (3) **clean restart** — clicking "play again" from Ending returns to a fully fresh Title with no stale state, satisfying Pillar 3 (no failure / no penalty / always able to begin again).

Implementation pattern (custom `SceneManager` Autoload vs `get_tree().change_scene_to_file()` directly vs PackedScene preloading) is **TBD — see ADR-TBD-scene-management when written**. The choice affects whether transitions can be cross-faded, whether Game state survives a brief async boundary, and how the Web export's initial WASM load is sequenced.

## Player Fantasy

The boot sequence is *arriving on foot at the edge of the village*. You haven't entered yet; you're standing at the threshold deciding to. The Title screen is the gate. Pressing Start is stepping through. The Ending → Title return is walking back out the same gate at dawn, the village still there, unchanged by your visit but legible now in a way it wasn't.

The fantasy names the threshold as a **place**, not as a transition to be hidden. Most boot screens try to disappear; this one gives the seam dignity. The gate is the same on the way in and on the way out — the player has changed, not the village.

This framing distinguishes Boot from #19's "quiet ledger" (which lives inside the notebook, mid-session) and from #2's "the pen hovers" (which lives at the moment of placing a hypothesis). Three fantasies at three scales: the gate (Boot), the notebook (Session State + Input), the inscription (Cascade Shimmer + Vignette). No overlap.

**Pillar alignment**: serves Pillar 3 (No Failure, Only Re-reading) most strongly — the gate is always open, the village is always there. Restart is "walking back in," not "respawning"; the player can return as many times as they want and the village is unchanged. Indirectly serves Pillar 2 (Language IS the World) — the village's persistence across boots reinforces that it is a *somewhere* with consistent linguistic identity, not a procedural puzzle generator that resets between runs.

**Player moments anchored to this fantasy**:
- **Load wait** (`<8s` target): the foot-on-path approach to the gate. Players don't watch a progress bar; they wait for the village to come into focus.
- **Press Start**: the deliberate step over the threshold.
- **Ending → Title return**: walking back out at dawn. The village is still there.

**Risk this fantasy accepts**: page load on slow connections may feel like "the gate is locked." Mitigation belongs in #20 Settings (audio preload toggle) and the Web export config (already optimized in v0.53; not this GDD's concern).

## Detailed Design

### Core Rules

**Boot sequence** (runs once at process start):
1. Godot engine initializes; `_ready()` fires on root scene
2. Autoloads load in declared order: Localization (#21) → Input System (#2) → Audio (#4) → Game Session State (#19) → Boot Manager (this system, also an Autoload OR an SceneTree custom callback — TBD)
3. Boot Manager calls Procedural Language Generator (#12) with the determined seed (MVP: hard-coded constant; Full Vision: time-based or user-provided seed)
4. Generator produces the `correct_table` and stores it (in #19 cache OR in #12's own storage — see #19 OQ-4 when ADR is written)
5. Boot Manager loads the Title scene (#17)
6. Web HTML5 only: the initial WASM module load + `index.html` first-paint must complete before this step; this is browser-paced, not Godot-paced
7. **Audio is NOT unlocked yet** — `AudioContext` waits for first user gesture per browser policy; Boot Manager flags audio as "pending"

**Scene transitions** (run during normal gameplay):
- **Title → Game**: triggered by Title screen's `confirm_pressed` event. Boot Manager (a) sets Game Session State to PLAYING phase + snapshots timer (per #19 AC-2), (b) loads the Game scene (village + NPCs + notebook overlay placeholder), (c) frees the Title scene
- **Game → Ending**: triggered by Game Session State's `session_ended` signal (per #19 AC-10). Boot Manager (a) loads the Ending scene (#18), (b) freezes Game scene OR frees it (TBD — see Open Questions); Ending scene reads from #19's frozen state
- **Ending → Title**: triggered by Ending scene's `return_to_title` action. Boot Manager (a) destroys Game Session State (per #19 AC-11), (b) loads Title scene, (c) frees Ending scene; Title is now fresh, ready for another playthrough with a new seed

**Restart contract**: clicking "play again" from Ending performs the full destroy-and-recreate cycle. No state survives. The next game generates a fresh language seed (or reuses the same seed if a "replay this seed" affordance is added in Full Vision).

### States and Transitions

| State | Active when | Owned by Boot Manager |
|---|---|---|
| `BOOTING` | First frame, Autoloads not yet ready | Yes; transitions automatically to `TITLE` once Autoloads + seed are initialized |
| `TITLE` | Title scene visible, no playthrough in progress | Yes; transitions to `GAME` on Start |
| `GAME` | Game scene active, playthrough in progress | Yes; mirrors #19's `game_phase = PLAYING`; transitions to `ENDING` on session_ended signal |
| `ENDING` | Ending scene visible, Game Session State frozen | Yes; mirrors #19's `game_phase = ENDING`; transitions to `TITLE` on return_to_title |
| `TRANSITION` | A scene swap is in flight (loading next, freeing prior) | Yes; brief — typically <300ms on desktop, may be longer on Web first load; input is locked during this state |

Boot Manager's state IS the authoritative scene phase. #19 Session State's `game_phase` is a mirror for systems that don't need to know about scene-management details.

### Interactions with Other Systems

| System | Boot's role | Direction |
|---|---|---|
| **All Autoloads (#2, #4, #19, #21)** | Boot initializes them in declared order | Boot → Autoloads (one-shot) |
| **#12 Procedural language generator** | Boot calls with seed at game-start, receives `correct_table` | Boot ↔ #12 (request/response at boot, then at each Title→Game transition) |
| **#17 Title screen** | Boot instantiates the Title scene; listens for `confirm_pressed` | Boot ↔ #17 |
| **#19 Game Session State** | Boot triggers initialization (PLAYING phase, timer snapshot) at Title→Game; triggers destruction at Ending→Title | Boot → #19 (write game_phase, write timer) |
| **#18 Ending scene** | Boot instantiates the Ending scene at Game→Ending; listens for `return_to_title` | Boot ↔ #18 |
| **#10 Cascade shimmer** | Boot must NOT trigger ending until current shimmer finishes (per #2 GDD OQ + #19 AC-10) | Boot listens to #10's `shimmer_complete` signal before allowing ENDING transition |
| **Web HTML5 browser** | Boot honors first-user-gesture audio unlock (delegates to #4 Audio); does NOT play audio before that | Boot informs #4 of gesture-received event |

**Single source of truth**: Boot Manager owns scene lifecycle; no other system swaps scenes directly. If #18 Ending scene wants to return to Title, it fires `return_to_title` signal which Boot Manager handles. Direct `get_tree().change_scene_*()` calls outside Boot Manager are forbidden.

## Formulas

**No balance formulas.** Two timing constants:

**Constant 1: `SCENE_TRANSITION_MAX_MS`** = 300 ms (target). Maximum acceptable scene swap latency on desktop. **Range**: 150–500 ms. Above 500 ms registers as a load screen, which breaks the "page-turn" feel. **Implementation note**: performance budget, not a tunable animation.

**Constant 2: `WEB_FIRST_LOAD_MAX_S`** = 8 s (target). Maximum acceptable initial WASM+pck load on Web HTML5. **Range**: 5–12 s acceptable. Above 12 s = published as Known Limitation in README. Already covered by `production/qa/qa-plan-sprint-1-2026-05-28.md` L-012 performance criteria; cross-reference, do not duplicate.

## Edge Cases

- **If** an Autoload fails to initialize: log the failure to console (Web devtools), show a "Boot Error — see console" plain-text screen, do not proceed to Title. No silent recovery.
- **If** the procedural language generator (#12) fails to produce a `correct_table`: same as above — boot halts with diagnostic. (Once #12 is designed, define what "fails" means — likely "seed produces no distinct-enough lexicon after N retries.")
- **If** the Game scene file is missing or corrupt: same boot-error pattern; Boot Manager does not attempt to render an empty Game scene.
- **If** the player clicks Start very rapidly (double-press): only the first event triggers transition; subsequent presses during `TRANSITION` state are ignored (per #2 Input system CUTSCENE-equivalent lock).
- **If** the player refreshes the browser tab mid-game: all state is lost (no save); fresh boot occurs; new language seed generated. Player effectively starts over.
- **If** the player navigates to Title via Ending while a cascade-shimmer is still animating: Boot Manager waits for `shimmer_complete` signal before processing the return_to_title; transition queued.
- **If** Boot Manager receives `return_to_title` while already in `TRANSITION` state: queue it; honor after current transition completes.
- **If** Web tab loses focus during `TRANSITION`: browser pauses Godot; on regain, transition resumes naturally (Godot's WASM loop simply continues).
- **If** the first-user-gesture audio unlock never happens (player never clicks anything after load): audio remains pending; game continues silently; not a fatal state.
- **If** an Autoload's `_ready()` fires AFTER Boot Manager's `_ready()` due to declaration order error: Boot Manager retries seed generation once with a 1-frame delay; if still missing, falls back to boot-error pattern. Cleaner fix is to ensure Autoload declaration order in project.godot is correct.

## Dependencies

**Upstream**: NONE (Foundation).

**Downstream dependents** (Boot creates or orchestrates them):

| System | Type | Interface |
|---|---|---|
| #19 Game Session State | Hard | Boot writes `game_phase` (`PLAYING`/`ENDING`/destroys) and timer snapshots |
| #2 Input System | Hard | Boot ensures #2 Autoload exists before any scene loads |
| #4 Audio system | Hard (VS) | Boot informs #4 of first-user-gesture for unlock |
| #12 Procedural language generator | Hard | Boot calls at game-start with seed; receives `correct_table` |
| #17 Title screen | Hard | Boot loads/frees the Title scene |
| #18 Ending scene | Hard (VS) | Boot loads at Game→Ending; frees at Ending→Title |
| #10 Cascade shimmer | Soft | Boot listens for `shimmer_complete` before ENDING transition |
| #21 Localization | Hard (VS) | Boot ensures #21 Autoload exists before any UI renders |

**Cross-system contracts to backfill**:
1. #17 Title GDD must define `confirm_pressed` signal
2. #18 Ending GDD must define `return_to_title` signal
3. #12 GDD must define `correct_table` return shape (per #19 OQ-1)
4. #10 GDD must define `shimmer_complete` signal timing

## Tuning Knobs

| Knob | Default | Range | Effect | Owner |
|---|---|---|---|---|
| `language_seed_source` | hard-coded (MVP) → time-based (VS) → user-input (FV) | enum | How the seed is generated at game-start | #1 Boot (this) |
| Autoload declaration order | per Section C step 2 | fixed | Init order — wrong order causes #19 to read uninitialized seed | Godot project.godot (locked by Boot design) |
| `SCENE_TRANSITION_MAX_MS` | 300 ms | 150–500 | Perf budget for scene swap | #1 (perf, not designer) |
| `WEB_FIRST_LOAD_MAX_S` | 8 s | 5–12 | Perf budget for first WASM load | #1 (perf) |
| Boot-error display style | plain text | locked | What's shown on Autoload/seed failure | #1 (UX) |

**Locked behaviors (not tunable)**:
- No save/load (single-sitting)
- No autosave (would require persistence layer)
- Boot Manager is sole scene-swap authority (no per-system scene swaps)
- Restart always destroys Session State (no "continue previous run" feature)

## Visual/Audio Requirements

**Minimal — Boot owns no in-game visuals or audio.** Two exceptions worth specifying:

- **Boot-error screen**: plain black background, parchment-palette text "Boot Error — see console", no animation, no sound. Identical look across both desktop and Web. This is the only visual Boot Manager itself renders; everything else is delegated to scene systems (#17 Title, #18 Ending).
- **Scene transition visual**: TBD (in ADR-TBD-scene-management). Recommended default: instant snap (zero animation) — matches the "page-turn" feel of the Player Fantasy and avoids load-screen connotations. Alternative under consideration: brief (~150 ms) cross-fade between scenes. Pick in ADR after SPIKE 1 (shimmer) settles to ensure stylistic consistency.

No audio cues owned by Boot. Audio is delegated to #4.

## UI Requirements

**N/A beyond the boot-error screen** (specified in Visual/Audio above). Boot Manager has no in-game UI. Title screen UI is owned by #17, Ending scene UI by #18.

## Acceptance Criteria

All in GIVEN/WHEN/THEN form, each independently testable.

**AC-1 — BOOTING to TITLE auto-transition**
GIVEN the application starts, WHEN all Autoloads initialize successfully and Boot Manager receives the language seed, THEN Boot Manager transitions from BOOTING to TITLE state and the Title scene is visible; no user action is required.

**AC-2 — TITLE to GAME on confirm**
GIVEN Boot Manager is in TITLE state, WHEN the Title scene emits `confirm_pressed`, THEN Boot Manager sets Game Session State `game_phase` to PLAYING, snapshots the timer, frees the Title scene, loads the Game scene, and sets state to GAME.

**AC-3 — GAME to ENDING on session_ended**
GIVEN Boot Manager is in GAME state, WHEN Game Session State emits `session_ended`, THEN Boot Manager loads the Ending scene, transitions to ENDING state, and the Ending scene reads session data from #19's frozen state.

**AC-4 — Shimmer blocks GAME to ENDING transition**
GIVEN a cascade-shimmer animation is in progress when `session_ended` fires, WHEN Boot Manager receives `session_ended`, THEN the ENDING transition is deferred until `shimmer_complete` is emitted by #10; the game scene remains active and responsive until that point.

**AC-5 — ENDING to TITLE on return_to_title**
GIVEN Boot Manager is in ENDING state, WHEN the Ending scene emits `return_to_title`, THEN Boot Manager destroys Game Session State, frees the Ending scene, loads a fresh Title scene, and sets state to TITLE.

**AC-6 — Restart destroys all session state**
GIVEN a playthrough has completed and ENDING to TITLE transition runs, WHEN the Title scene becomes active, THEN no data from the previous session persists; a new language seed is generated; Game Session State is freshly initialized on the next Title→Game transition.

**AC-7 — TRANSITION state locks input**
GIVEN Boot Manager is in TRANSITION state, WHEN any input event arrives, THEN the event is discarded; no scene-swap or gameplay action is triggered until the transition completes.

**AC-8 — Double-press Start is a no-op**
GIVEN the player presses Start and Boot Manager enters TRANSITION state, WHEN a second Start press arrives before the transition completes, THEN the second press is ignored; exactly one Title→Game transition occurs.

**AC-9 — Return-to-title queued during active transition**
GIVEN Boot Manager is in TRANSITION state, WHEN `return_to_title` is received, THEN the action is queued and honored after the current transition completes; it is not dropped and does not trigger a second concurrent transition.

**AC-10 — Boot Manager is sole scene-swap authority**
GIVEN any system other than Boot Manager, WHEN that system attempts to call `get_tree().change_scene_to_file()` or equivalent directly, THEN this is a code-review violation; no non-Boot code path swaps scenes; verified by grep of source tree for disallowed calls.

**AC-11 — Autoload failure halts boot with diagnostic**
GIVEN an Autoload fails to initialize during BOOTING, WHEN Boot Manager detects the failure, THEN Boot Manager displays a plain-text "Boot Error — see console" screen, logs the failure to the browser console, and does not proceed to TITLE.

**AC-12 — Missing or corrupt scene file halts with diagnostic**
GIVEN the Game scene file is missing or corrupt at transition time, WHEN Boot Manager attempts to load it, THEN Boot Manager displays the boot-error screen with a console log; it does not render an empty or partial scene.

**AC-13 — Tab refresh destroys all state**
GIVEN the player refreshes the browser tab at any point during a session, WHEN the page reloads, THEN a full BOOTING sequence begins; no prior session state is preserved; a new language seed is generated.

**AC-14 — Audio remains pending when no user gesture occurs**
GIVEN the application has booted and the Title scene is visible, WHEN the player has not yet interacted with the page, THEN audio remains locked (pending); Boot Manager has notified #4 of the pending state; the game is otherwise fully functional.

**AC-15 — Web first-load completes within budget**
GIVEN the game is served over a standard connection, WHEN measured from page request to Title scene visible, THEN elapsed time is ≤8 seconds (`WEB_FIRST_LOAD_MAX_S`); above 12 seconds is logged as a Known Limitation.

**AC-16 — Desktop scene transition completes within budget**
GIVEN Boot Manager initiates any scene transition on desktop, WHEN the transition completes (prior scene freed, next scene ready), THEN elapsed time is ≤300 ms (`SCENE_TRANSITION_MAX_MS`).

**AC-17 — No save or load path exists**
GIVEN the application runs, WHEN any boot sequence or restart occurs, THEN no file-system read or write of session data occurs; there is no "continue" path; verified by absence of persistence calls in Boot Manager source.

## Open Questions

| # | Question | Owner / Target Resolution | Why open |
|---|---|---|---|
| OQ-1 | Implementation pattern: custom `SceneManager` Autoload, vs `get_tree().change_scene_to_file()` directly, vs PackedScene preloading | Resolve in ADR-TBD-scene-management | All three feasible; choice affects cross-fade capability, async lifecycle, Web export sequencing |
| OQ-2 | When transitioning Game→Ending, does the Game scene get frozen (kept in tree) or freed entirely? Frozen allows quick return to inspect; freed releases memory | Resolve in ADR-TBD-scene-management or post-playtest | Game's memory footprint is small; default lean is **frozen** (cheap, allows ending scene to overlay) but locked in ADR |
| OQ-3 | Scene transition visual (instant snap vs ~150ms cross-fade) | Resolve in ADR-TBD-scene-management after SPIKE 1 (so cross-fade style matches shimmer style) | Player Fantasy says "page-turn"; cross-fade may be too gentle, instant may be too abrupt — playtest can decide |
| OQ-4 | When does the language seed re-roll? Default: every Title→Game transition. Alternative: only on first boot (player keeps same language until app restart) | Resolve before VS (when procedural generator is in scope) | Affects replay semantics; "same language across runs in same session" is interesting for speed-runners |
| OQ-5 | Boot-error screen i18n: in Chinese, English, or both? Pre-Localization (#21) init, neither is loaded yet — does the error fall back to English? | Resolve when #21 Localization is designed | Low stakes; default = English with copy "Boot Error — see console" |
| OQ-6 | If Web first-load exceeds `WEB_FIRST_LOAD_MAX_S` (8s), what do we show during the wait? Loading spinner? Title-with-greyed-Start? Black screen? | Resolve when #17 Title screen is designed | Currently spec'd as "browser-paced" but UX of the wait is undefined |
