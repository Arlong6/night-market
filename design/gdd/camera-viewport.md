# Camera & Viewport (#3)

> **Status**: In Design
> **Author**: solo (user-driven autonomous batch) + skill orchestration
> **Last Updated**: 2026-05-30
> **Implements Pillar**: Infrastructure — enables visual presentation of the village; trivially serves Pillar 2 (Language IS the World) by framing the world legibly
> **System Category**: Core (Foundation layer)
> **Game**: Lexicon Village

## Overview

Camera & Viewport is the visual presentation layer's foundation. The village is a single-screen scene (no scrolling required for MVP / VS); the camera is therefore static, centered on the village layout, with the viewport fixed to a 16:9 aspect ratio scaled to fit the browser window. This system handles three concerns: (1) **viewport sizing** — the playable area scales to the browser window without distorting pixel-art glyphs; (2) **static camera positioning** — the village fills the viewport at a known reference resolution (proposed 320×180 base, scaled integer-multiples up); (3) **window resize response** — when the player resizes their browser window, the canvas re-fits without breaking the integer-scale pixel rendering. There is no camera follow, no zoom, no panning. The world is intentionally small and visible all at once, matching the contemplative aesthetic of the game. Implementation pattern (Godot's `Camera2D` vs `SubViewport` rescale vs project-level `stretch_mode`) is **TBD — see ADR-TBD-viewport-scaling when written**, though the existing Night Market project's `stretch_mode = viewport, aspect = keep, scale = integer` pattern (per `design/gdd/game-concept-rpg.md` line 103) is the leading candidate.

## Player Fantasy

Camera & Viewport is **pure infrastructure** with no direct player fantasy. The player perceives this system only through its results — the village is legible, the glyph font reads crisply at 8×8 pixels (per #5 Glyph font rendering), nothing wobbles when the window resizes. The Player Fantasy of "the village exists as a coherent place" lives in #6 Village scene & layout and #1 Boot's "arriving at the gate" framing; this system enables those experiences without being one itself.

**Pillar alignment**: serves Pillar 2 (Language IS the World) indirectly — clean pixel rendering preserves glyph legibility, which is the precondition for the language being readable at all. Serves Pillar 3 (No Failure) by being invisible when working correctly (a camera that does its job is one the player never thinks about).

## Detailed Design

### Core Rules

**Viewport configuration** (project-level settings, locked at boot):
- Base resolution: **320 × 180** (16:9, integer-scales cleanly to 640×360, 1280×720, 1920×1080)
- `stretch_mode = viewport` — Godot scales the rendered viewport to fit the window
- `aspect = keep` — black bars (letterbox/pillarbox) preserved if window aspect differs from 16:9
- `scale = integer` (or `scale_mode = integer` in 4.x terminology) — only integer multiples of the base resolution are rendered, preventing sub-pixel blur on the bitmap font
- `texture_filter = NEAREST` on the project default (per godot-specialist SPIKE 3 recommendation; reinforced for #5 Glyph font)

**Camera positioning**:
- Single static `Camera2D` per scene (Title, Game, Ending)
- Camera position is the center of the scene's playable area; does not follow any node
- No camera transitions between scenes; scenes simply load with their own Camera2D in place

**Window resize handling**:
- Godot's built-in `viewport` stretch_mode handles resize automatically when properly configured
- No custom resize callback required in MVP
- If the window becomes too small (< base resolution × 1), the viewport stops scaling and shows actual pixels; black bars expand. No special UI to inform the player.

### States and Transitions

This system has no runtime states. Configuration is set at boot via project settings and does not change during gameplay.

| Phase | Behavior |
|---|---|
| Project init | `stretch_mode`, `aspect`, `scale` applied from project.godot |
| Scene load (Title, Game, Ending) | Camera2D enabled on scene's designated node |
| Window resize | Engine handles via stretch_mode; no script intervention |

### Interactions with Other Systems

| System | Role | Direction |
|---|---|---|
| **#1 Boot & scene flow** | Boot ensures viewport project settings are correct at init | #1 → #3 (one-shot, at init) |
| **#5 Glyph font rendering** | Camera's integer-scale preserves glyph legibility; #5 sets per-asset NEAREST filter | #3 enables #5 |
| **#6 Village scene & layout** | Village places its Camera2D at the layout's center | #6 owns its own Camera2D, configured per this GDD's rules |
| **#10 Cascade shimmer animation** | Shimmer animates per-glyph color/transform; camera does not interfere | None directly; shimmer reads viewport coordinates for spatial origin |
| **#16 Notebook UI** | Notebook is a CanvasLayer overlay; does NOT scroll the camera | Independent — notebook lives in its own CanvasLayer above the world |

No system writes back to Camera & Viewport.

## Formulas

No balance formulas. One sizing constant:

**Constant: `BASE_RESOLUTION`** = `Vector2i(320, 180)`. Locked. All in-world art is authored at this resolution. Window scaling is integer multiples (1×=320×180, 2×=640×360, 3×=960×540, 4×=1280×720, 6×=1920×1080). Non-integer window sizes letterbox to nearest integer multiple.

## Edge Cases

- **If** the browser window is narrower or taller than 16:9: black bars (letterbox horizontal or pillarbox vertical) preserve aspect; no content stretches.
- **If** the browser window is smaller than 320×180: viewport renders at 1× (320×180) and is clipped/letterboxed; no smaller scaling occurs. Player can resize browser to see the rest.
- **If** the browser zoom is set to non-100%: browser-level scaling occurs over the rendered canvas; visual quality at non-100% zoom is best-effort. Game logic is unaffected.
- **If** the user rotates a mobile device mid-game: Godot's stretch_mode re-evaluates; viewport recenters. No state change.
- **If** a high-DPI display is detected: Godot may render at integer multiples internally; the player sees crisp pixels at any reasonable window size.
- **If** the scene file's Camera2D node is missing: scene renders without an active viewport center; Godot's default camera (top-left origin) is used. **Authoring constraint**: every scene MUST have one and only one Camera2D node.
- **If** more than one Camera2D node is active in a scene: Godot uses the last-enabled one. **Authoring constraint**: only one Camera2D per scene.

## Dependencies

**Upstream**: NONE (Foundation).

**Downstream dependents**:

| System | Type | Interface |
|---|---|---|
| #1 Boot & scene flow | Hard | Boot ensures viewport settings are correct at init |
| #5 Glyph font rendering | Hard | NEAREST filter requires viewport integer scaling to preserve crispness |
| #6 Village scene & layout | Hard | Village authoring assumes 320×180 base resolution |
| #7 NPC sprite & tableau | Hard | NPC art assumes 320×180 base; sprites authored at base scale |
| #10 Cascade shimmer | Soft | Shimmer reads viewport positions for spatial origin |
| #16 Notebook UI | Soft | Notebook CanvasLayer is independent of world camera |

**Cross-system contracts to backfill**:
- #6, #7 GDDs must declare their art at 320×180 base
- #5 GDD must enforce NEAREST filter on font asset import

## Tuning Knobs

| Knob | Default | Range | Effect | Owner |
|---|---|---|---|---|
| `BASE_RESOLUTION` | 320 × 180 | locked | Reference resolution for all in-world art | #3 (locked) |
| `stretch_mode` | viewport | viewport / 2d / disabled | How Godot scales the rendered output | Project settings (locked by #3) |
| `aspect` | keep | keep / keep_width / keep_height / ignore / expand | Aspect ratio behavior on resize | Project settings (locked by #3) |
| `scale_mode` | integer | integer / fractional | Whether non-integer scaling is permitted | Project settings (locked by #3 — integer-only to preserve pixel font) |

**Locked behaviors (not tunable)**:
- No camera follow, no zoom, no panning
- One Camera2D per scene maximum
- Integer-scale only (preserves 8×8 font legibility)

## Visual/Audio Requirements

**N/A — Camera owns no visuals or audio of its own.** It is the lens through which all other systems render.

## UI Requirements

**N/A — Camera has no UI.**

## Acceptance Criteria

**AC-1 — Viewport configured correctly at boot**
GIVEN the application starts, WHEN the first scene loads, THEN project.godot's `stretch_mode = viewport`, `aspect = keep`, `scale_mode = integer` are active.

**AC-2 — Base resolution renders correctly**
GIVEN the browser window is at exactly 640×360 (2× base), WHEN any scene is active, THEN the game renders at 2× scale with no sub-pixel blur and no aspect distortion.

**AC-3 — Non-16:9 window letterboxes**
GIVEN the browser window is at 1000×400 (wider than 16:9), WHEN any scene is active, THEN black pillarbox bars appear on left/right (or letterbox on top/bottom for taller windows); aspect ratio is preserved.

**AC-4 — Window smaller than base shows 1× with bars**
GIVEN the browser window is at 200×150 (smaller than 320×180), WHEN any scene is active, THEN the game renders at 1× (clipped); the player may need to resize to see all content. No crash.

**AC-5 — Each scene has exactly one Camera2D**
GIVEN any scene file (Title, Game, Ending), WHEN the scene is opened in the Godot editor, THEN exactly one `Camera2D` node is enabled. Multiple Camera2Ds in a single scene constitute an authoring error.

**AC-6 — No camera follow occurs**
GIVEN the player is in the Game scene, WHEN the player moves or interacts, THEN the Camera2D position does NOT change; the camera is static throughout.

**AC-7 — Window resize does not break rendering**
GIVEN the Game scene is active, WHEN the player resizes the browser window from 640×360 to 1280×720, THEN the rendered output rescales smoothly via Godot's viewport stretch; no canvas tear, no scaling artifacts, no input misalignment.

**AC-8 — Pixel font remains crisp**
GIVEN the bitmap font is rendered at 8×8 pixels at any integer scale, WHEN visually inspected, THEN no sub-pixel blur is present (every pixel is sharp).

**AC-9 — Mobile rotation does not crash**
GIVEN the game is running on a mobile browser, WHEN the device is rotated 90 degrees, THEN the viewport re-fits; no crash, no rendering corruption (visual quality at the new aspect is best-effort).

## Open Questions

| # | Question | Owner / Target Resolution | Why open |
|---|---|---|---|
| OQ-1 | Implementation pattern (Camera2D direct vs SubViewport rescale vs pure project-level stretch) | Resolve in ADR-TBD-viewport-scaling | All three feasible; choice affects shimmer effect compatibility (#10 may want SubViewport for per-tile rendering) |
| OQ-2 | Should we support an in-game zoom-to-fit affordance for accessibility (low-vision players)? | Resolve when #22 Accessibility is designed | Currently spec'd as "no zoom"; may want exception for a11y |
| OQ-3 | Mobile portrait mode — should we render rotated (force landscape via CSS) or accept the smaller viewport? | Resolve before launch (post-MVP, optional) | Touch is already "best-effort"; portrait orientation may not be worth solving |
