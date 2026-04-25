# Night Market Runner — Art Bible

> **Status**: In Design
> **Scope**: Sections 1–4 + 8 (weekend-project scope; sections 5/6/7/9 deferred until prototype validates core feel)
> **Last Updated**: 2026-04-22
> **Pillars served**: Taste of home / Snackable joy / Juicy feedback

## 1. Visual Identity Statement

### Visual Rule (one sentence)

> Every frame should look like you're eight years old, holding a 珍奶, staring
> up at a wall of neon signs and paper lanterns — warm light from below,
> chaos above, but you know exactly where to run.

This sentence locks four things: light direction (warm, low-source), vertical
density (signs and banners overhead), player legibility (you always know where
to run), and cultural specificity (not Tokyo, not Hong Kong — Taiwan
street-level warmth).

### Supporting Principles

**P1. Lantern Light Beats Fluorescent Light**
Every light source reads as warm (amber, soft red, golden yellow) unless it is
a vendor's neon sign, which is the only permitted cool accent. No clinical
white fills, no blue sky ambience.
*Design test*: When choosing the ambient fill color for a level section, if
it does not read as "lit by paper lanterns or charcoal grill smoke," replace
it with a warmer value. Neon cyan or purple is only valid as a small sign
accent, never as fill.
*Pillars served*: Taste of home.

**P2. Sign Density is Depth**
Backgrounds have three layers: far (dense hanging banners and signage, low
contrast, desaturated), mid (stall canopies, crates, vendor silhouettes,
mid contrast), near (hazards, collectibles, platforms, full contrast and
saturation). The eye is always pulled forward by contrast gradient, not by
blank space.
*Design test*: When a background feels "empty," the answer is always more
signs and banners in the far layer — never a larger or brighter sprite in
the mid or near layer. Background complexity lives in the far layer;
gameplay lives in contrast.
*Pillars served*: Taste of home, Juicy feedback.

**P3. Silhouette First, Taiwan Second**
Every character and interactive object must be readable as a black silhouette
at 32×32. Cultural detail (stinky tofu cart shape, scooter outline, oyster
omelette griddle) is added only after the silhouette passes thumbnail.
Authenticity lives in the shape, not the texture.
*Design test*: When designing a new hazard or collectible, render it as a
solid black shape first. If you cannot identify what it is in three seconds,
redesign the silhouette before adding color or cultural detail.
*Pillars served*: Snackable joy, Juicy feedback, Taste of home.

### Pre-locked decision
Per-level palette is assigned before any asset work begins:
- **Shilin**: warm red + gold (classic Taipei night market)
- **Fengjia**: cooler neon pink + teal (Taichung foodie energy)
- **Liouho**: deep navy + amber (Kaohsiung coastal night)

Locked here as a weekend-scope forcing function — full palette specs in
Section 4 (Color System).

## 2. Mood & Atmosphere

Mood targets for each major game state. Gameplay mood is unified across all
three markets — per-market palette differentiation lives in Section 4.

### Gameplay
- **Emotional target**: The electric second before you spot your favorite
  stall across a crowd — repeated, sustained, never resolved; the loop itself
  is the reward.
- **Lighting**: Warm amber ground-level fill (~2700K equivalent). Constant
  low-intensity glow pulses from passing neon signs (200ms cycle, never
  synchronized). Light sources always below or beside the player, never
  overhead. Steam wisps catch the light in the mid layer.
- **Atmospheric descriptors**: Kinetic, dense, luminous, immediate, alive
- **Energy level**: Frenetic
- **Mood-carrying element**: Parallax speed differential — foreground rails
  past at 1.0× while mid-layer stalls scroll at 0.4× and background signage
  drifts at 0.15×. Remove parallax and the world becomes a poster; with it,
  you're running through something.
- **Pillars served**: Snackable joy, Juicy feedback, Taste of home

### Level Start
- **Emotional target**: The moment the vendor lifts the bamboo steamer lid —
  fragrant anticipation, you already know it's going to be good, you're just
  waiting for the signal.
- **Lighting**: Warm amber held static, then a single animated light swell
  (lanterns brightening over 1.5 seconds) that crests on "GO." The swell is
  slow; the GO is instant. No flicker during countdown — stillness earns
  the burst.
- **Atmospheric descriptors**: Coiling, expectant, warm, hushed, building
- **Energy level**: Measured
- **Mood-carrying element**: Countdown digits rendered as vendor stall
  price tags (handwritten style, hung on string).
- **Pillars served**: Taste of home, Snackable joy

### Level End
- **Emotional target**: Setting down an empty cup and immediately wanting
  the next one — full, satisfied, hand already reaching.
- **Lighting**: Warm fill intensifies 20–30% (lanterns "celebrating"), score
  elements pop with a brief golden rim light. No color temperature shift —
  same warmth, more of it.
- **Atmospheric descriptors**: Bright, generous, punchy, inviting, complete
- **Energy level**: Breathless
- **Mood-carrying element**: Score digits that bounce and settle like coins
  dropping into a bowl.
- **Pillars served**: Snackable joy, Juicy feedback

### Death / Restart
- **Emotional target**: Bumping into a stranger at the market — "oops,
  sorry!" — and immediately continuing without losing your place in the
  crowd.
- **Lighting**: Single 2-frame white flash (not black), then instant return
  to full gameplay lighting. Zero sustained dim. The world does not mourn.
- **Atmospheric descriptors**: Breezy, instant, forgiving, unbroken, light
- **Energy level**: A beat (under 0.5 seconds total)
- **Mood-carrying element**: Player sprite pops into a small star-burst
  of food particles (dumplings, bubbles) and respawns in place — the
  particle cloud IS the entire death animation. No screen change. No void.
  Just confetti, then running.
- **Pillars served**: Snackable joy

## 3. Shape Language

The geometric vocabulary for Night Market Runner. Every rule serves
P3 (Silhouette First) from Section 1 and must be readable at 32×32 scale
during the frenetic gameplay tempo from Section 2.

### A. Character Silhouette — The Pole Rule

Every moving entity is identified by its **dominant axis** at 32×32. No two
entities share the same axis:

| Entity | Dominant axis | Silhouette cue |
|---|---|---|
| Player (young Taiwanese guy) | Vertical-slim + upward spike | Boba tea straw poking up from cup at hip; feet close together mid-run; reads as a forward-tilted lightning bolt |
| Broom-wielding owner | Horizontal-wide | Broom held at chest height creates a T-crossbar; stocky torso, apron bulk; reads as "barrier coming" |
| Stray dog | Horizontal-low | Body hugs the ground plane, head forward, tail up; the only entity that occupies the bottom third of the tile |
| Careless tourist | Top-heavy | Camera at eye level creates an oversized rectangular head-cluster; taller than player, slower |

**Rule**: No two enemies/NPCs may share a dominant axis (vertical-slim,
horizontal-wide, horizontal-low, top-heavy). This is the distinguishing-trait
test every future character design must pass.

**Player duck-state exception** (added 2026-04-22 post-prototype): When
ducking (↓/S), the player collapses from vertical-slim (40h) to low-wide
(20h, feet position preserved). The boba straw spike shortens from 6px to
3px but remains visible — silhouette still reads as "player" not "crate."
Duck-state is the **only** time the player silhouette axis changes. This is
a deliberate production rule — validated in prototype when the user
intuitively reached for duck without being told it existed.

### B. Collectible Shape Grammar

**Universal rule — all food is presented in a container.** No bare
ingredients as pickups. Oyster omelette on a folded paper plate; stinky
tofu in a small cup with toothpick spike; skewer grilled squid; bubble
tea cup. This container device differentiates **grabbable** food from
**décor** food in stall backgrounds.

**Three silhouette families** — every collectible must fit one:

| Family | Examples | Key silhouette |
|---|---|---|
| Tall-with-spike | Bubble tea, grilled squid skewer, seafood skewer | Vertical rectangle + upward spike |
| Irregular blob | Oyster omelette, hot-star chicken, milkfish soup | Wide irregular oval, no hard edges |
| Tight sphere cluster | Octopus balls, stinky tofu in cup | 2–3 circles in diagonal arrangement |

Items in the same family must differentiate by **container type + proportion**.
Pepper bun and papaya milk both read as circular — bun is wider-than-tall and
bare; papaya milk is taller-than-wide with cup silhouette.

**Décor vs. collectible distinction**:
- Collectibles float 4px above the ground plane
- Collectibles have a warm inner glow (lantern-amber, echoes P1)
- Collectibles bob on a 2-frame oscillation
- Stall background food is dark, static, recessed into the mid/far layer

The float + glow + bob is the **only gameplay-plane animation that is not a
character**. Seeing that animation = it's grabbable.

### C. Environment Geometry

**Foreground gameplay plane = rectangular and angular.** Tiled alley floors
(horizontal grid lines), scooter bodies (boxy, low), trash bags (rounded
trapezoid), overturned crates (hard square). **Hard corners can hurt you.**
This creates a wordless safety grammar.

**Background layers = verticals and organic curves.** Bamboo poles, hanging
banner strips, corrugated awning ribs (parallel diagonal lines), paper
lanterns (circles), neon sign housings (rounded rectangles). Organic/curved
shapes recede; angular hard shapes advance.

**Taiwan-specific anchors**:
- Corrugated metal awnings: parallel diagonal hatching at mid-distance
- 騎樓 (arcade colonnade) pillars: repeating vertical dark bars framing the alley
- Hanging banners and laundry lines: horizontal curves across upper layers

**Hanging hazard obstacles (duck-under class)** (added 2026-04-22 post-prototype):
A special category of foreground hazard — hanging signs, low banners, awning
ropes — that hang from the mid-layer awning down into the gameplay plane.
Player must duck to pass. Visual spec:
- Canvas: ~40w × 22h (width varies by sign content; height fixed)
- Position: top-edge at y≈115 in 180-tall viewport (clears 20h ducking player at y=140; blocks 40h standing player at y=120)
- Body color: old-gold lantern (`#D4920A`) — reuses per-market palette accent
- **Hazard-red underside edge** (`#D94F2B`, 1–2px) on the bottom — this is the "head-bump" contact line, mirroring the top-edge hazard tint used on ground obstacles (inversion tells the player "danger is on the other side here")
- Two ropes from awning to sign top (1px wide, ink near-black `#2A1A0A`)

Hanging hazard silhouette rule: rectangle + rope lines. Sits visually apart
from round/curved background lantern and banner shapes. The rope detail is
what distinguishes a **gameplay** hanging sign from a **background** banner
— backgrounds never have the rope-down visual.

### D. UI Shape Grammar

**Diegetic — receipt and lunchbox language.** The pillar (Taste of home)
forces this; a cold geometric HUD breaks the eight-years-old-at-a-market
fantasy.

- **Score + timer**: torn receipt paper strip pinned to the corner; warm
  cream background, red stamp font
- **Food-collected indicator**: paper lunchbox with item slots
- **Title / menu buttons**: rubber-stamp rectangles with inked borders
- **Forbidden**: rounded-corner mobile-game buttons, clean sans-serif HUDs,
  anything that looks like a modern app UI

### E. Hero Shapes vs. Supporting Shapes

**Circles and spikes draw the eye; horizontal bands recede.**

- Collectibles (circles + spikes on containers) and the player (single
  upward spike) are the only pure-circle + spike silhouettes on the
  gameplay plane
- Obstacles are rectangular
- Backgrounds are vertical bands with circular lantern accents that are
  visually suppressed by low contrast against the warm ambient fill

**P2 in shape terms**: background layers stack thin verticals so tightly
they merge into texture. Midground introduces legible individual shapes
(awning, single banner). Foreground is sparse — **3–5 hard shapes max per
screen width**. Eye fills the background clutter and snaps to isolated
hard-edged foreground shapes.

## 4. Color System

### A. Global Semantic Palette (7 colors, constant across all levels)

| Role | Hex | Usage | Colorblind backup |
|---|---|---|---|
| Collectible Glow | `#F2A227` | Lantern-amber inner glow on all food pickups | Float + bob + 2-frame oscillation animation; shape family |
| Player Accent | `#E8F542` | Boba straw stripe + shoe sole; the visible player ID color | Vertical-slim silhouette + upward spike is unique on screen |
| Hazard Tint | `#D94F2B` | 1–2px edge highlight on active obstacles only (NOT main body color) | Angular shape grammar is primary hazard signal |
| Enemy Accent | `#D94F2B` | Same burnt sienna. Enemies = hazards, deliberate unification | Each enemy has unique silhouette + motion pattern |
| UI Cream | `#F5EDDA` | Receipt strip and lunchbox background | — |
| UI Stamp Red | `#C2241A` | Menu buttons, score numerals, "GO" text | — |
| Score-Pop Gold | `#FFD966` | Coin-drop score bounce at level end ONLY | Appears only at level end (temporal separation from collectible glow) |

**Enemy color decision (locked)**: Enemies use the hazard tint, not an
independent color. Night Market Runner is dodge-and-collect, not combat.
Separate enemy coloration would imply strategic differentiation that does
not exist. One danger color — learn it once, trust silhouette for type.

### B. Per-Market Environment Palettes (environment ONLY — semantic overlays unchanged)

**Shilin (士林) — Taipei classic, Red Building warmth**

```
#8B1A1A  Deep brick red       — wall tones, 紅樓-era architecture
#C94B2C  Vendor-awning red    — mid-layer canvas awnings, banner fabric
#D4920A  Old-gold lantern     — hanging lanterns, overhead string lights
#4A2010  Char-smoke brown     — alley floor
#F0C060  Sign-face amber      — large illuminated sign lettering backlight
#1A0A00  Deep night black     — far-layer building mass silhouette
```

*Anchor*: Shilin's 紅樓 architecture sets a brick-and-wood-beam tone.
Warmest of the three — everything orange-to-red, no cool note.

**Fengjia (逢甲) — Taichung college-town neon youth**

```
#D44FA0  Hot neon pink        — dominant sign color, canopy fabric accents
#29B8B0  Electric teal        — secondary sign color, plastic tarp vendors
#2D1A3A  Deep purple-black    — night sky backdrop, building mass far layer
#7A3060  Dusty rose-purple    — mid-layer wall tone, awning underside
#F07030  Street-grill orange  — charcoal grill light, warm ambient ground
#1A2A28  Dark teal-black      — alley floor in teal-lit zones
```

*Anchor*: Fengjia serves 逢甲大學 students — denser, younger, more
plastic/LED than Shilin. Pink bubble tea signage and teal LED trim are
real visual facts. Purple-black sky makes the neon readable.

**Liouho (六合) — Kaohsiung coastal, navy and amber**

```
#0D1B3E  Deep harbor navy     — far-layer sky and building silhouette
#1B3A5C  Mid-blue             — building walls, night atmosphere fill
#D4660A  Warm coastal amber   — lanterns, vendor light spill, sign glow
#7A4010  Burnt sienna-brown   — alley floor, wood-plank stall surfaces
#C87030  Coral-amber          — mid-layer canvas, sunset residual warmth
#A8C4D4  Faint sea haze       — far-layer atmospheric desaturation ONLY
                                (near-zero opacity — P1 compliant)
```

*Anchor*: Liouho sits near the 愛河 in Kaohsiung. Harbor-navy night quality
absent from landlocked Taichung. Kaohsiung's coral-orange sunsets leave
residual warmth in low ambient. `#A8C4D4` is the ONLY cool color in the
entire bible, used at near-zero opacity as atmospheric haze only.

### C. Semantic Color Vocabulary

| Color | Says to the player |
|---|---|
| Lantern-amber `#F2A227` | "This is yours — grab it." |
| Stamp red `#C2241A` | "This is the game speaking to you." |
| Hazard/enemy tint `#D94F2B` | "This ends your run." |
| Cream `#F5EDDA` | "This is information, not game world." |
| Near-black / deep night | "This is the world receding — keep moving forward." |
| Per-market neon | "You are here specifically — not a generic arcade." |

### D. UI Palette (diegetic receipt/lunchbox, 4 colors)

```
#F5EDDA  Receipt cream       — base surface for all UI panels
#C2241A  Stamp red           — primary text, score numerals, button ink
#D4920A  Old-gold            — secondary accent, lunchbox slot rim, timer pip
#2A1A0A  Ink near-black      — text body, receipt border lines
```

No market-specific variation — receipt is a Taiwan receipt regardless of
which market you run. Consistency reinforces Snackable joy.

### E. Colorblind Safety Review

| Risk pair | Condition | Verdict | Backup cue |
|---|---|---|---|
| Collectible glow `#F2A227` vs Shilin old-gold `#D4920A` | Deuteranopia | Moderate clash | Float + bob animation (no static env element animates) |
| Hazard tint `#D94F2B` vs Shilin awning red `#C94B2C` | Protanopia | Near-identical brown | Angular shape grammar is primary; position in near-layer |
| Player `#E8F542` vs Fengjia neon pink `#D44FA0` | Tritanopia | Safe | Silhouette always primary |
| Death flash white (2 frames) vs Level-end warm swell (2–3s) | All | Safe | Duration IS the signal |
| Collectible `#F2A227` vs score-pop gold `#FFD966` | Deuteranopia | Similar channel | Temporal separation (gameplay vs level-end only) |

**Net verdict**: Palette is colorblind-adequate. Shape + animation + position +
timing each independently carry the signals that color reinforces. No signal
is carried by color alone.

### F. Shade Discipline (pixel art production rule)

Each sprite uses max **4 shades per palette role**: base tone, +30% highlight,
−30% shadow, and one rim/specular pop (≤20% sprite area). Far-layer background
tiles use **2 shades only** (base + shadow) — contrast suppression is a
production rule, not optional.

Total unique swatches across entire game: ~18 (semantic + 3 env sets + UI
overlap). Indexable for <20MB HTML5 build.

## 8. Asset Standards

### A. Canvas Size Tiers

Native viewport: **320×180** (integer-scales cleanly to 1080p=6×, 1440p=8×,
720p=4×). Tile grid: **32×32** (locked from concept doc).

| Category | Canvas | Notes |
|---|---|---|
| Player | 24×40 | Vertical-slim per P3 Pole Rule; extra height for boba straw spike; all animation frames share canvas |
| Broom owner | 40×32 | Horizontal-wide T-silhouette |
| Stray dog | 40×24 | Horizontal-low (only entity in bottom third) |
| Tourist | 28×48 | Top-heavy; 48h makes silhouette unambiguous |
| Collectibles | 20×24 | Fits tall-with-spike family; tight canvas forces readable silhouettes |
| Static obstacles | 32×32 | Match tile grid — each occupies exactly 1 tile unit |
| Floor + wall tiles | 32×32 | Core tile grid |
| Parallax far | 384×128 | One screen-width at 384; 2 shades only |
| Parallax mid | 384×160 | Awning / vendor silhouettes; full 4-shade allowance |
| Parallax near | 384×64 | Floor band; highest contrast |
| UI receipt strip | 128×24 | Score + timer, corner-pinned |
| UI lunchbox panel | 80×64 | 4–6 slot layout with 20×20 slot icons |
| UI stamp button | 64×20 | Menu / restart / next |

### B. Animation Frame Discipline

**Rule**: minimum viable motion over maximum frames. Every frame cut = an hour saved.

| Animation | Frames | Loop | Notes |
|---|---|---|---|
| Player run | 4 | Yes | Minimum that reads as run |
| Player jump ascend / peak / descend | 1 each | No | 3 distinct poses, not frames |
| Player death burst | 4 | No | Particle expansion |
| Enemy patrol (all types) | 4 | Yes | Silhouette must not collapse across frames |
| Collectible bob | 2 | Yes | Locked in Section 3 |
| UI stamp button press | 2 | No | Depressed + release |

**Total unique frames** across characters + collectibles: ~55–65 (achievable solo, weekend scope).

### C. File Organization (snake_case per coding standard)

```
assets/art/
├── characters/
│   ├── player/          char_player_run_01.png … _04.png, char_player_jump_*, char_player_death_*
│   ├── enemy_broom/     char_broom_walk_01.png … _04.png
│   ├── enemy_dog/       char_dog_walk_01.png … _04.png
│   └── enemy_tourist/   char_tourist_walk_01.png … _04.png
├── collectibles/        col_bubble_tea_bob_01.png … (per item + frame)
├── obstacles/           obs_scooter_idle.png, obs_trash_bag_idle.png, obs_crate_idle.png
├── tiles/               env_floor_[market].png, env_wall_[market].png
├── parallax/            env_parallax_[layer]_[market].png  (9 total)
└── ui/                  ui_receipt_strip.png, ui_lunchbox_panel.png, ui_btn_stamp_*, ui_slot_icon_*
```

Flat paths within each subdirectory — no level-named subfolders. Market
differentiation is suffix-based (`_shilin` / `_fengjia` / `_liouho`) on
environment only. Characters and collectibles have no market suffix.

### D. Spritesheet vs Individual Frames

**Individual PNGs for characters and collectibles. Single-strip PNG for parallax backgrounds.**

Rationale: iteration speed > HTTP optimization. Godot HTML5 bundles all
assets into a single `.pck`; HTTP request count is not a meaningful target.
Artist edits one frame = one file reload.

### E. Texture Reuse Policy (protects <20MB ceiling)

| Asset | Reuse rule |
|---|---|
| Floor + wall tiles | One geometry, three palette variants per market |
| Enemies | Fully shared across markets (no recolor — they are hazards, color is already locked) |
| Collectibles | Market-specific, NO reuse (Taste of home pillar — cultural authenticity lives here) |
| Parallax backgrounds | Never reused across markets (9 unique PNGs total) |
| UI | One set, zero variants — receipt is a Taiwan receipt regardless of level |

### F. PNG Export Rules (every sprite must pass these)

| Rule | Value |
|---|---|
| Color depth | 8-bit indexed (fits ~18-swatch palette; forces discipline) |
| Alpha | 1-bit only (fully opaque or fully transparent — no partial alpha) |
| Dithering | Forbidden on characters/collectibles; 2-color Bayer 4×4 ordered dither permitted on far-layer parallax only |
| Anti-aliasing | Forbidden everywhere |
| Pixel alignment | Every sprite on exact pixel boundaries; sub-pixel offsets must round down |
| Canvas origin | Top-left (0,0); pivot for characters = foot-center (document in `assets/art/PIVOTS.md`) |
| Color profile | sRGB, no embedded ICC profiles |
| Metadata | Strip all EXIF and PNG chunks on export (Aseprite: disable author metadata) |

**The one-question export test**: "If I zoom this PNG to 400% in a browser with
nearest-neighbor scaling, does every pixel sit on a clean grid and does no edge
show gray fringe?" If yes, export approved.

### G. Godot 4.6 Import Preset (`pixel_art_standard`)

Commit as project-wide preset, applied to every texture in `assets/`.

| Import Flag | Required Value |
|---|---|
| `compress/mode` | Lossless (PNG) |
| `flags/filter` | off (Nearest) — MUST — bilinear blurs pixel art |
| `flags/mipmaps` | off |
| `flags/repeat` | off (on only for tileset atlases) |
| `flags/anisotropic` | off |
| `process/fix_alpha_border` | on (prevents dark halos) |
| `process/premult_alpha` | off (unless alpha fringing appears) |
| `detect_3d/compress_to` | disabled |

**Note**: Godot 4.4 changed shader texture parameter types from `Texture2D` to
`Texture` base. Any custom shader sampling these textures must use `Texture`
not `Texture2D` in the uniform declaration.

### H. project.godot — Pixel-Perfect Rendering Settings

| Setting | Value |
|---|---|
| `display/window/size/viewport_width` | `320` |
| `display/window/size/viewport_height` | `180` |
| `display/window/stretch/mode` | `viewport` |
| `display/window/stretch/aspect` | `keep` |
| `display/window/stretch/scale_mode` | `integer` *(verify property name in 4.6 Project Settings → Display → Window → Stretch — introduced 4.2)* |
| `rendering/renderer/rendering_method` | `gl_compatibility` |
| `rendering/renderer/rendering_method.web` | `gl_compatibility` *(must set separately)* |
| `rendering/textures/canvas_textures/default_texture_filter` | `0` (Nearest) |
| `rendering/2d/snap/snap_2d_transforms_to_pixel` | `true` |
| `rendering/2d/snap/snap_2d_vertices_to_pixel` | `true` |

### I. HTML5 Export & Build Budget

**WebGL requirement**: WebGL 2.0 (Godot 4.6 HTML5 minimum). Not a concern for 2026 web.

**Budget estimate (<20MB ceiling)**:

| Asset type | Format | Budget |
|---|---|---|
| Godot Web runtime | — | ~6–8MB (fixed overhead) |
| Music (3 tracks) | OGG Vorbis, 96kbps stereo | ~3–4MB |
| SFX (~30 sounds) | OGG Vorbis, 64kbps mono | ~1MB |
| Textures (full atlas set) | PNG lossless, indexed | ~2–4MB |
| Scripts | Tokenized .gd (default) | Negligible |
| **Total estimate** | — | **~12–14MB** (margin available) |

**Features that do NOT work in HTML5 Compatibility renderer**: Forward+ /
Vulkan effects (SSR, SDFGI, volumetric fog), compute shaders, `OS.execute()`,
threading (restricted — needs COOP/COEP headers, unreliable, design around
it). `FileAccess` works via IndexedDB (save data is async-constrained).

> **KNOWLEDGE GAP**: Godot 4.6 HTML5 threading behavior
> (SharedArrayBuffer/COOP headers) is not in the verified engine-reference
> docs. Do NOT architect systems that require `Thread` without testing on
> actual HTML5 export first.

### J. File Format Rules (mandated)

| Category | Format | Forbidden | Reason |
|---|---|---|---|
| Sprites, tiles, UI | PNG | WebP, BMP, JPEG | PNG lossless; WebP damages palette; JPEG no alpha |
| Music | OGG Vorbis (.ogg) | MP3, WAV, FLAC | Godot-native, HTML5-safe, no patent history |
| SFX | OGG Vorbis (.ogg), mono | WAV, MP3 | Same |
| UI font | BMFont (.fnt + PNG) | TTF with hinting | Bitmap = exact pixel; TTF sub-pixel rendering destroys pixel aesthetic |
| Scenes | .tscn (text) | .scn (binary) | Diffable in git |
| Scripts | .gd | — | GDScript is project language |

### K. Per-Frame Performance Budget

320×180 / Compatibility / HTML5 / 60fps / mid-range 2024 laptop (Intel Iris
Xe / AMD Radeon 680M) in Chrome = baseline.

| Item | Target | Hard Ceiling |
|---|---|---|
| Visible sprite nodes | 150 | 250 |
| Draw calls per frame | 30 | 60 |
| Visible tiles (TileMapLayer) | 200 | 400 |
| Unique textures bound per frame | 8 | 16 |
| Particle emitters active | 4 | 8 |
| Audio streams simultaneous | 8 | 12 |
| `_process()`-enabled nodes | 50 | 100 |

**Batching rule**: pack all tiles + sprites for a given visual layer into one
atlas. Texture switches break Canvas batching in Compatibility renderer.

### L. Known Engine Traps for Pixel Art

| Trap | Fix |
|---|---|
| Camera `position` stored as float | Round each frame: `camera.position = camera.position.round()` |
| `snap_2d_transforms_to_pixel` not set | Set in project.godot (Section H) |
| Control nodes mixed with Node2D in same layer | Keep HUD/UI in dedicated `CanvasLayer` above game layer |
| `anti_aliased = true` on Line2D / Polygon2D | Always `false` |
| `TextureButton` with filtered texture | Set import filter to Nearest AND set node's `texture_filter = TEXTURE_FILTER_NEAREST` (node property overrides import) |
| Multiple atlases per TileMapLayer | One atlas per layer, max |
| `TileMap` node (deprecated in 4.3) | Use `TileMapLayer` |

> **KNOWLEDGE GAP**: WorldEnvironment glow was reworked in 4.6 (processes
> before tonemapping). Compatibility renderer glow support is not documented
> in the verified engine-reference docs. **Assume glow via WorldEnvironment
> is unavailable in Compatibility/HTML5 and design around it.** Use
> sprite-based glow (a soft amber-tinted Sprite2D overlay) for collectible
> shimmer and lantern warmth instead.
