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
- GANG + TUNING (2026-08-05): FPGang (scripts/fp_gang.gd) — dark-hoodie + red-bandana
  hostile enemies, roam then hunt+shoot within AGGRO_RANGE 48 (game._damage -> dir arc),
  hp 3, group "gang"+"blastable", killable. _manage_gangs() keeps 5 (respawn at dist 70),
  seeded in _ready + on police timer. Minimap orange blips. Tuning: explode mission
  target mini(2+n/2,5)/42s + barrels 40->60; knockback UP halved (fp_ped/fp_target);
  weapon pickups 4->2. Feature check #14 gang[spawn hurt kill_scores]. 14 items.
- GANG REVIEW FIXES (2026-08-05, adversarial review workflow): 5 gangs -> 3, SHOOT_INTERVAL
  1.3->1.8, SHOT_DMG 6->5 (five always-hostile gangs out-DPS'd regen = ~4s softlock).
  FPGang now emits smashed(60,6,pos) on death (connected in _manage_gangs) so kills score +
  count for rampage. FPGang preloaded to match convention. (Review's 'missing preload crash'
  was a false positive — class_name = global; verified working.)
- ROADMAP (user wants 1->2->3->4 + 手機版本): #1 title+music DONE, #2 mobile (touch+web/GL)
  NEXT, #3 more content, #4 gang territory. Tasks #8-11 track these.
- TITLE + MUSIC (2026-08-06, step 1/4): _build_title() CanvasLayer(layer 10) title overlay
  over live city; _input() starts on first key/mouse/TOUCH (Web-audio gesture); _start_game
  hides title + plays music; missions + enemy spawns gated on _started. RRAudio.make_music_stream
  (4s loop bass+kick), AudioStreamPlayer -16dB, M toggles (_toggle_music). Feature check #15
  title[music]. 15 items. NOTE: music unauditioned headlessly — user judges sound.
- MOBILE GROUNDWORK (2026-08-06, step 2/4): renderer override project.godot
  renderer/rendering_method.web + .mobile = gl_compatibility (desktop stays forward_plus;
  web=WebGL2 != desktop ANGLE that crashed on M3). export_presets.cfg (Web, nothreads,
  excludes addons/gut+tests). Web export works (pck 3.6MB, wasm 37MB). FPTouch
  (scripts/fp_touch.gd): left joystick->move actions, right drag->touch_look, buttons
  射擊/上下車/氮氣/跳-煞/換槍; shown on _is_touch()/web/_force_touch. fp_main.touch_look/
  cycle_weapon. _lite (=touch/web) drops SSR/SSAO/glow + shadow dist + thins entities.
  Feature check #16 touch[built,look,cycle]. 16 items. build/ gitignored.
  PENDING: runtime browser test (Chrome remote-debug was blocked here) — user opens
  http://localhost:8777 (desktop) or http://192.168.68.54:8777 (phone, same WiFi);
  python3 -m http.server 8777 runs from road-rage/build/web. Confirms WebGL2 renders.
  >>> USER CONFIRMED 2026-08-08: web build RUNS in the browser. Mobile path is viable.
- RAMPS (2026-08-08, step 3 more-content): FPRamp (scripts/fp_ramp.gd) visual tilted slab
  (NO blocking collision — CharacterBody can't climb) + ground launch Area over footprint;
  fast car -> FPCar.launch(speed*0.7+8, cap 26), applied after on-floor zeroing. 4 ramps
  (_spawn_ramps). Air-time stunt bonus in _process (car): land after >0.6s -> int(air*260)
  + '空中特技!' callout. Feature check #17 ramps[count=4 launch=true]. 17 items.
  step 3 remaining options: weather, more vehicle types. step 4 = gang territory.
- WEATHER (2026-08-09, step 3 #2): V cycles clear/rain. _cycle_weather/_apply_weather/
  _start_rain/_stop_rain in fp_main. Rain = player-following CPUParticles3D downpour
  (800/300 lite) + sun 1.35->0.7 + fog 0.0016->0.007 grey. _process repositions rain
  above player. Feature check #18 weather[rain,clear]. 18 items. Roadmap step 3 DONE
  (ramps+weather; more vehicle types optional). NEXT = step 4 gang territory.
- GANG TERRITORY (2026-08-10, step 4): _spawn_turf() 2 turf zones (紅蛇幫/黑爪幫) = emissive
  ground disc + floating name; _update_turf() flags _in_turf + red HUD '危險：幫派地盤';
  _manage_gangs swells 3->6 + spawns closer (40u) in turf. Feature check #19 turf[swarm6].
  19 items. >>> ROADMAP 1-2-3-4 ALL COMPLETE.
- QA PASS (2026-08-10): full adversarial review workflow (5 lenses x verify, 16 raised /
  7 confirmed). Fixed: touch-stuck (FPTouch._on_press releases stale finger + _release_all
  on FOCUS_OUT), ramp retrigger (1.2s cooldown), board-airborne-car (_enter_car guard
  global_position.y<3.0 — is_on_floor was too strict, broke foot check), grant_weapon
  ownership guard, lite shadow dist 80->55. Skipped ACES-on-web (gl_compat supports it;
  confirmed running) + combo-callout tint (cosmetic). All 19 checks green. Web re-exported
  with all features + fixes (pck ~3.6MB). Server http://192.168.68.54:8777 (phone).
  Next options: deploy to shareable host, run summary/game-loop, more content.
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
