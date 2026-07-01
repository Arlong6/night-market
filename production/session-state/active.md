# Active Session State

> **Last Updated**: 2026-07-01 (Road Rage — first-person 3D branch, iterated to a good state)
> **Purpose**: Living checkpoint. Read this first after compaction or new session.

## Current build: 橫衝直撞 (Road Rage) — mindless vehicle-destruction game (Godot 4.6)

Standalone project `road-rage/`. Spec/plan in `docs/superpowers/`.

### Two branches exist in the same project
- **2D top-down** (`scenes/main.tscn` / `main.gd`): the original v1 vertical slice — city, combo, score, wanted/police, game-over, juice. Complete, 23 unit tests. NOT the boot scene now.
- **First-person / third-person 3D** (`scenes/fp_main.tscn` / `fp_main.gd`) — **the active build + boot scene**. This is where all recent work went.

### FP 3D — current state (what the user plays)
- **Third-person chase camera** (pulled back/high), big detailed muscle car (chassis/cabin/windshield/spoiler/stripe/headlights/wheels), engine drone (pitch tracks speed), FOV widens with speed, handbrake (SPACE).
- **Handling**: grip model (velocity steers toward the car's travel axis) so corners are planted; reverse inverts steering (natural); REVERSE_SPEED 20; MAX_SPEED 30.
- **World**: procedural city (CityGen, grid now 30, TILE3D 14 = wider roads/bigger world), designed buildings (tiers/windows/trim/roofs), pedestrians (FPPed, wander + crowds), traffic (drifting FPTargets), street trees, a cone ring near spawn as a cornering test-track, perimeter walls + fall-respawn (never "ends").
- **Destruction**: smashed props/cars/peds spawn a physics RigidBody3D **knocked away** (flung in travel dir + up, tumbles, lands, fades) + particle burst + score/combo. Endless (no death).
- **Grand environment**: procedural gradient sky + sun, SSAO, glow/bloom, SSR reflections on polished asphalt, ACES tonemap, atmospheric fog, real-time shadows.

### ⚠️ CRITICAL LEARNING — the crash saga (root cause found)
The FP build repeatedly "closed the whole window" on the user's machine. Headless checks were ALWAYS clean because **the crash is GPU-side**. Root cause (from the launch log): device is **Apple M3** and the project ran **GL Compatibility (OpenGL-over-Metal)** — chosen originally for web export — which is **unstable on Apple Silicon under load**. FIX: `rendering/renderer/rendering_method="forward_plus"` (native Metal, stable). Confirmed: launch banner now "Metal 4.0 - Forward+", clean exits, no crash.
- **Consequence**: Forward+ means **no HTML5/web export** for now. If web is wanted later, need a GL-compat-friendly variant (lighter scene, no SSR/SSAO/volumetrics).

### Tuning knobs
- Car feel: `fp_car.gd` (ACCEL, MAX_SPEED, REVERSE_SPEED, TURN_RATE, GRIP, BASE/MAX_FOV, BRAKE_DECEL).
- Knock-away force: `fp_target.gd` / `fp_ped.gd` `_spawn_flying_chunk` / `_spawn_flying_ped`.
- World size: `rr_tuning.gd` CITY_COLS/ROWS; `fp_main.gd` TILE3D.
- Look: `fp_main.gd` `_build_environment` (sky/SSAO/SSR/glow/fog).

### How to run
```
~/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot --path road-rage
```
WASD/arrows drive, SPACE handbrake, S/↓ reverse. Tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit` (23 green).

### Next beauty/feature candidates (offered, user to pick)
Sidewalk curbs · neon signs · real car-shaped traffic · dusk/night toggle with neon · more building styles · minimap · pickups/nitro · a real objective/score-chase framing.

## Other games (paused, intact)
- Night Market (夜市) — boot game in `src/`, ship-prep done (v0.59), 553 tests.
- word-suika (一字一句) — juiced + title.
- Lexicon Village — shelved (core-loop rebuild needed).

## Solo Mode
`production/review-mode.txt` = `solo`.
