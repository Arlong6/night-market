# Active Session State

> Last Updated: 2026-07-09 (Road Rage FP 3D — GTA-like, heavily expanded)
> Purpose: Living checkpoint. Read this first after compaction or new session.

## Active build: 橫衝直撞 (Road Rage) — standalone `road-rage/`, Godot 4.6

Boot scene = `scenes/fp_main.tscn` (`fp_main.gd`). A third-person 3D GTA-like sandbox
built entirely from primitive meshes (no art assets). The 2D top-down build
(`scenes/main.tscn`) still exists but is not the boot scene.

Spec/plan: `docs/superpowers/specs/2026-06-27-road-rage-design.md`, `docs/superpowers/plans/2026-06-27-road-rage.md`.

### CRITICAL: renderer
`rendering_method = forward_plus` (NOT gl_compatibility). The window-closing crash
the user hit was GL-compat on Apple M3 (OpenGL-over-Metal) choking on load — headless
never caught it because it is GPU-side. Forward+ = native Metal = stable. Consequence:
no HTML5/web export in this mode; a GL-compat-lite variant would be needed for web.

### Features implemented (all verified: scan/boot/23 unit tests + headless checks)
- Driving: third-person chase cam, big detailed car, nitro (Shift), handbrake (Space),
  reverse with inverted steering, grip handling, FOV-with-speed, MAX_SPEED 33.
- On foot: FPWalker — E to enter/exit car, WASD move + aim relative to a rotatable
  camera (, / .), J or left-click auto-fire hitscan (tracers + sparks + recoil),
  Space jump, Shift sprint. Carjack ANY nearby car (own or traffic) with E.
- Destruction: props/cars/peds knocked away as physics bodies; buildings collapse when
  rammed fast; explosive barrels (40) with chain reactions; hit-stop on big smashes.
- Cops: cruisers (ram damage) + foot cops (chase + shoot) scale with a wanted-heat
  star system; police destroyable by gun/ram; helicopter at 5 stars (searchlight,
  shoots, leaves when heat drops).
- Player health: 體力 bar, damage from cops/heli/explosions, regen when safe, respawn
  at spawn (brings the car — never lost). Health packs (16) heal.
- World: procedural city (grid 30, TILE3D 14), designed buildings w/ windows/roofs,
  pedestrians + drifting traffic (car-shaped), street trees, neon signs, curbs,
  crosswalks, 5 tall landmark towers, day/dusk/night toggle (T), cone test-track.
- Look/feel: procedural sky + SSAO + SSR + bloom + fog + shadows; screen flash on
  explosions; combo callouts (失控!/瘋狂!/大屠殺!); minimap (player/police/heli/pickups).
- JUICE (2026-07-24): trauma camera shake (car + walker, quadratic decay, offset+fov
  punch+roll) routed through fp_main._add_shake() for every impact; bigger hit-stop on
  building/blast; explosions add a ground-plane shockwave ring (TorusMesh, NO rotation —
  it's already flat) + tumbling debris chunks on top of the fireball.
- CROWD + FEEDBACK (2026-07-25): FPPed flee state (panic) — bolt from a fast car nearby
  (passive) or from gunfire/blast/kill via fp_main.alarm_peds() broadcast (group
  "pedestrian"). Directional damage indicator: _damage(amt, source_pos) — all 4 call
  sites pass source; FPDamageIndicator (scripts/fp_damage_indicator.gd) draws a red arc
  at screen centre pointing at the hit, angle from the ACTIVE camera forward (works in
  car + foot). Feature check now asserts ped_panic + dmg_indicator.
- PANIC POLISH + FIRE MODE (2026-07-26): panicked peds throw arms overhead + flail
  (sin wave) and zig-zag flee (re-roll heading every ~0.25-0.5s, +/-57deg jitter).
  Gun fire mode: FPWalker._auto_fire toggled with F — 連發 hold-to-spray / 單發 tap.
  "fire" input action now includes MOUSE_BUTTON_LEFT (walker fire loop covers mouse+J;
  fp_main's old left-click handler removed to avoid double-fire). HUD shows 連發/單發 [F]
  on foot. Feature check asserts fire_mode_toggle.
- GUN + SCREAM JUICE (2026-07-28): FPWalker recoil spread (_spread bloom grows while
  spraying up to ~3.4deg, decays at rest) + brass shell ejection per shot (tumbling
  arc, freed 0.7s). RRAudio.scream() procedural yelp with per-ped pitch; FPPed cries
  out ~30% only on the calm->panic transition (no spam).
- MULTI-WEAPON (2026-07-28): data-driven _weapons table in FPWalker — 手槍/衝鋒槍/散彈槍,
  switch with keys 1/2/3. Per-weapon pellets/rate/spread/bloom_max/range/pitch + viewmodel
  len/thick/col (reshaped in _apply_weapon_visual). Firing loops pellets via _fire_ray()
  (shotgun = 8-pellet cone). RRAudio.gunshot(pitch). HUD firemode label now shows weapon
  name. Feature check asserts weapons[switch]. Damage still via shoot_hit() (1 hit/pellet)
  — no per-damage refactor; differentiation comes from pellets * fire rate.
- ROCKET LAUNCHER (2026-07-30): 4th weapon 火箭筒 (key 4). Weapon entry has "rocket": true;
  _do_fire branches to _fire_rocket() which spawns FPRocket (scripts/fp_rocket.gd) — a
  Node3D flying 48u/s with smoke trail, raycasting ahead; on impact/95u it spawns an
  FPExplosive + connects exploded->game._on_explosion + explode(), reusing the whole
  blast path. Feature check asserts rocket[ok].
- CROSSHAIR + PICKUPS + DRIVE-BY (2026-08-04):
  * Dynamic crosshair: 4 arms in _ch_arms, gap = 4 + FPWalker.current_spread()*520 each
    frame (tight pistol, wide shotgun, blooms with SMG spray, 0 for rocket).
  * Weapon pickups: ownership on FPMain._weapons_owned [pistol,SMG owned; shotgun,rocket
    locked]; set_owned(arr,start) on _exit_car, _cur_weapon saved in _board_car.
    FPWeaponPickup (scripts/fp_weapon_pickup.gd) crates unlock+equip on walk-over.
    _spawn_weapon_pickups() = 2 shotgun + 2 rocket near spawn. grant_weapon() unlocks.
  * Drive-by: fp_car mounted gun — _car_fire() hitscan from the nose while active+fire
    held (GUN_RATE 0.11), tracer/spark/muzzle + alarm_peds. Feature check car_gun.
  Feature check now 12 items: ...weapons[lock+grant], rocket[ok], weapon_pickups=4, car_gun.
- MISSIONS + VARIETY (2026-08-04): timed objectives, random type each round, escalating.
  4 types (const MTYPE_*): DEMOLISH/RAMPAGE/EXPLODE/COMBO. _mission_event(type) routed
  from _on_building_collapsed/_on_smashed/_on_explosion; COMBO tracks _combo.multiplier()
  live in _update_mission. Top-centre banner (_ui_mission); big _ui_callout on start
  (blue) / success (green +bonus) / fail (red) — _maybe_callout resets modulate to white.
  Reward: score target*150+num*50, heal 30, flash, RRAudio.fanfare(); fail RRAudio.buzz().
  Cooldown banner shows '已完成 N'. Feature check #13 mission[start,done,rampage]. 13 items.
- Audio: procedural impact/explosion/gunshot. Engine drone DISABLED (user found the
  looping pitch sound annoying).

### Controls
Car (3rd-person): WASD drive, Shift nitro, Space handbrake, E exit, , / . look. T day/night.
Foot (FIRST-PERSON, 2026-07-24): WASD move, MOUSE look (yaw+pitch, vertical aim),
J/left-click shoot, Shift sprint, Space jump, E enter/carjack, Esc free/lock cursor.
Mouse captured on foot, released in car. Centre crosshair (HUD, on-foot only).
Fire travels along camera forward → can aim up and shoot the helicopter.

### FIXED 2026-07-23: orphaned WorldEnvironment (major visual bug)
`_build_environment()` created the WorldEnvironment (`we`) but never `add_child(we)`,
so the entire sky/ambient/fog/SSAO/SSR/bloom/ACES pipeline was inert — the game
rendered as a murky dark street lit only by sun + streetlight omnis. This is almost
certainly what the user meant by "沒看到更新" (they saw a dim, flat scene). One-line
fix `add_child(we)` restored the bright daytime look. Then tuned sky (vivid blue,
energy_multiplier 1.15) + lighter fog (0.0016). Proven by before/after screenshots.

### SCREENSHOT WORKFLOW (how to actually SEE the game headlessly-ish)
`tests/run_screenshot.gd` instantiates fp_main NON-headless, renders ~90 frames,
saves a PNG we can Read. Scratchpad dir must exist first (mkdir -p). Run:
`"$GODOT" --path road-rage -s res://tests/run_screenshot.gd` (NO --headless — needs GPU).
Then Read the PNG. This is the ground-truth check for any visual change.

### Verification (per delivery contract — always attach evidence)
- `GODOT=~/Downloads/godot-4.6.2/Godot.app/Contents/MacOS/Godot`
- Scan+cache: `"$GODOT" --headless --editor --quit`
- Unit tests (23): `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
- Feature check: `"$GODOT" --headless -s res://tests/run_feature_check.gd` → prints
  FEATURE_CHECK carjack/respawn/camera/explosion/heli — all must be true.
- Run for the user: `"$GODOT" --path road-rage` (GUI; feel/visuals need a real run).
  Launch WITHOUT piping to head so the output file captures the Metal/Forward+ banner + any crash.

### Next candidates (offered)
Weapon pickups, mission/objective framing, ramps/jumps, more vehicle types, weather,
shoot-down the heli (needs vertical aim), more environment variety.

## Other games (paused, intact)
- Night Market (夜市) — boot game in `src/`, v0.59, 553 tests. word-suika (一字一句) — juiced + title. Lexicon Village — shelved.

## Solo Mode
`production/review-mode.txt` = `solo`.
