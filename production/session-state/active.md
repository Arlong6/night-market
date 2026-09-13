# Active Session State

> Last Updated: 2026-09-13 (大夜班 netcode GDD **r4 修訂完成，散文評審結束，下一步＝W1 原型**；Road Rage 段落為歷史紀錄)
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
- CITY UPGRADE (2026-08-11): varied skyline — fp_buildings.make storeys now 8% skyscraper
  (16-28), 20% mid (8-15), rest low (1-6); tall ones taper 80%. Palette 6->10 tones. Grid
  30->34, BUILDING_CHANCE 0.28->0.36. _lite skips ~28% buildings. All 19 checks green.
- DEPLOY: web re-exported with new city (pck 3.6MB). Package ready: build/web/ folder +
  build/road-rage-web.zip (13MB, nothreads = any static host, no COOP/COEP). Publish needs
  USER's account: recommend itch.io (upload zip, tick 'play in browser') or Netlify Drop
  (drag build/web). Server still at http://192.168.68.54:8777 for LAN phone testing.
- WEAPONS UNLOCKED + FIXES (2026-08-11/12): all 4 weapons owned from start (_weapons_owned
  all true) — 3/4 were gated behind crates + gave no feedback (user confused). Blast-death
  'crash/跳掉' = web gl_compat light budget: on _lite, explosions skip OmniLight + fewer
  particles, streetlights skip OmniLight (emissive still glows), rocket glow skipped —
  desktop was fine (repro respawns clean). Music: percussive loop -> calm ambient sine pad,
  vol -16->-22, M toggles. All 19 checks green. Web re-exported. UNVERIFIED: on-device web
  blast-death (can't run web here) — user must re-confirm on phone; music can't be auditioned.
- VEHICLE KINDS + COMMIT/DEPLOY (2026-08-25): FPVehicleKinds (scripts/fp_vehicle_kinds.gd)
  data-driven catalogue (6 kinds: 肌肉車[player, weight 0]/轎車/跑車/廂型車/卡車/公車;
  5 spawn as traffic). Traffic spawns a
  weighted mix; carjack hands the player that kind's drive profile (bus top 33.7->25.1,
  clumsier turn). Touch overlay: feature check asserts CJK glyphs in button font (Web
  fallback font renders tofu — bundled TTF) + overlay hidden on desktop. New tests:
  web_blast_check(.gd/.tscn), run_vehicle_shot, run_screenshot, dump_music; tools/
  web_blast_check.sh. Feature check #20 vehicles[...]. 20 items green, 23/23 unit tests.
  Committed (2 commits: road-rage work + meta notify-hook/docs). Web re-exported
  (pck 4.1MB) + road-rage-web.zip rebuilt (13.2MB). LAN server up: build/web on :8777,
  Mac IP NOW 192.168.0.144 (was 192.168.68.54 — DHCP changed) -> phone URL
  http://192.168.0.144:8777. STILL UNVERIFIED on device: web blast-death + CJK touch
  labels + music feel — user must confirm on phone/browser.
- ITCH.IO PUBLISH (2026-08-28..09-01): user confirmed on-device web test PASSED
  (blast-death + CJK labels + music OK). Published via butler v15.30.0 (~/.local/bin/butler,
  creds saved) to arlong666/rad-rage:html5 — NOTE slug is 'rad-rage' (user typo'd on page
  creation), title on itch = RUNRUNRUN. Build ✓ #1934691 v1 LIVE on channel html5.
  Push saga: (a) email had to be verified first; (b) uploads to GCS
  (commondatastorage.googleapis.com) die with 'use of closed network connection' on this
  network — curl works, butler's Go HTTP/2 long uploads get cut. FIX: GODEBUG=http2client=0
  (HTTP/1.1) + butler retries + run detached via nohup (session-killed background tasks
  killed 3 earlier attempts). PENDING USER STEPS: itch edit page → tick 'This file will
  be played in the browser' on the html5 upload, embed 960x540 (project viewport),
  mobile-friendly + fullscreen button on, then Draft -> Public.
  >>> 2026-09-01 DONE: user set embed + flipped Public. Verified live: HTTP 200 +
  Run-game embed at https://arlong666.itch.io/rad-rage. GAME IS PUBLISHED.
  Future updates = re-export web + one command:
  GODEBUG=http2client=0 ~/.local/bin/butler push road-rage/build/web arlong666/rad-rage:html5
  (run via nohup detached if from Claude Code; butler retries survive this network).
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

## NEW GAME IN PRE-PRODUCTION: 大夜班 (Night Shift) — 2026-09-03
/brainstorm COMPLETE (solo mode, all gates skipped). Concept doc:
`design/gdd/game-concept-night-shift.md`. Co-op FP party game: Taiwan convenience
store night shift, 2-4p online, browser, Overcooked-like with star rating.
KEY USER DECISIONS: fellowship-first (co-op requested); FP required; timeline
relaxed ("慢慢做但要做好"); scenario chosen over 躲鬼(horror uncertain) and 亂流(空服);
**ENGINE = UNITY (user's explicit choice over recommended Godot)** — CLAUDE.md still
pins Godot, /setup-engine must run. Networking plan: Unity NGO + Relay/Lobby
(WebGL = WebSocket). FIRST PROTOTYPE = netcode chain validation (biggest risk:
new engine + WebGL multiplayer).
/setup-engine DONE (2026-09-03): Unity 6.3 LTS pinned (6000.3, LTS until 2027-12).
CLAUDE.md + technical-preferences.md switched to Unity/C# (Godot snapshot kept at
technical-preferences-godot.md; legacy games note added to CLAUDE.md). Engine reference
docs researched via 2 web-research subagents and written: docs/engine-reference/unity/
{VERSION, breaking-changes, deprecated-apis, current-best-practices, modules/{web,
multiplayer}}.md. HIGH RISK version (6.1-6.3 post-cutoff).
/art-bible DONE (2026-09-03): design/art/art-bible-night-shift.md sections 1-4+8
(5/6/7/9 deferred until prototype). All drafted by art-director/technical-artist
subagents, user approved each. KEY RULES: 慘白預設/彩色是特權 (interact yellow #FFD23F
+ alert red #E0392B are the ONLY 2 privileged hues, quota rule: density scales, hue
count never); 店內恆白不准變暗, all mood via window sky (窗外=隱形時鐘: darkest sky
01-04h = peak intensity; dawn = release); shape=identity (customer archetypes = 主導
幾何+掛載物 silhouette formulas); oden pot = hero (only cylinder + highest saturation
+ steam). Brand: 好鄰居超商 #2B2B54+#E8873B. HARD LIMITS: Simple Lit only (3-shader
rule, URP Lit forbidden), chars ≤800 tris, scene ≤120K, ≤150 draw calls target, baked
interior + 1 realtime directional for window sky, no skeletal anim (all tween), BGM
must stream. Conflicts resolved+logged in §8.9.
/map-systems DONE (2026-09-04): design/gdd/systems-index.md (Night Shift版; 舊夜市索引
git mv → systems-index-night-market.md). 19 systems, MVP=14項, design order: ①網路同步
層+Session ②商品資料庫 ③FP控制器 ④機台互動組 ⑤客人系統 ⑥評分邏輯 ⑦波次導演+時鐘
⑧攜帶交付 ⑨HUD ⑩結算… High-risk: 網路同步層(GDD後直衝原型). Next: /design-system
網路同步層+Session.

/design-system netcode-session DONE (2026-09-04): design/gdd/netcode-session.md 279行
全 11 章完成 (user approved every section). KEY DECISIONS: host-authoritative + owner
移動 + request→validate→broadcast; 搶奪=Host先到先得+撲空動畫(不回滾); NPC=里程碑事件
同步不逐幀+本地插值; 移動10Hz; reconnect 30s (NP的20-30勝過SD的90); late-join 3-5s過場;
房間碼=Sessions API原生(SD自訂碼公式作廢); Host關分頁=局終(no migration, UI明示);
Host分頁節流=最大風險(>500ms→時鐘2s追趕); 進房≤35s(硬標60); 連線狀態全用店語(去後場
拿貨/店長把鐵門拉下來了). 18條AC(qa-lead驗證+6條補強)+測試基建註記. Registry +5常數
(reconnect_window_sec=30, max_players=4, join_time_budget_sec=60, interact_rtt_p95_ms
=300, player_count_sampling=wave_boundary). Systems index #1#2→Designed.
/design-review netcode-session DONE (2026-09-05): 5 adversarial specialists + CD synthesis
→ NEEDS REVISION (14 blocking). ALL 14 FIXED same session. 關鍵修訂: (1) Provisional
Assumptions 表 P-1~P-6 含 fallback 欄 (未驗證引擎行為不再與定案規則混寫); (2) 留守者
保護 Core Rules #14-16 — 離線立即降載+15s寬限期(不生新客/耐心×1.5/「老闆出來擋一下」),
補上支柱5對留守者的保護; (3) 背景節流改 visibilitychange, ≤5s catch-up / >5s 視同斷線
(frame delta 在分頁全停時量不到); (4) MVP 分層 (CD裁決): 斷線基本保障=MVP、30s原位恢復
=Post-MVP, 已同步回寫 game-concept; (5) 更衣室過場定案(不推給UX); (6) 清除 HP 模板殘留;
(7) 新增 ServiceError 狀態(UGS失敗); (8) AC 18→26條+層級欄+測試基準環境數值; (9) 單一
場景不啟用 NetworkSceneManager. Registry 12 常數(+grace_window/claim_lock/late_join
_cutoff/background_disconnect). Review log: design/gdd/reviews/netcode-session-review-log.md
/design-review netcode-session 複審 DONE (2026-09-05, 新 session): 6 specialists (gd/sd/np/
unity/qa/ux) + CD → NEEDS REVISION (7 blocking, 皆局部補洞; systems-designer 獨判 MAJOR,
CD 裁 NEEDS). ALL 7 FIXED same session (r2), user 決策: 心跳 2s/8s app-level; MVP 離線名額
立即釋放; 全部 Host 動態 spawn 禁 scene-placed. 修訂內容: Core Rule #20 心跳; #18 改 client
端偵測 Host 消失; 公式③ rate=1+drift/2 (上界 3.5x); 狀態真相 NetworkVariable; 公式⑤ 冷啟動
讀取條標「未解」→ OQ#8 (web-platform ADR + /ux-design); AC8 MVP=2人/VS=4人; States
Disconnected 拆 MVP/Post; Onboarding 斷線; 寬限期不疊加; P-5 改測跨 channel; 新增 P-7 (.jslib)
P-8 (Relay 傳播) P-9 (內建逾時≥8s); AC 26→33. Registry +2 (heartbeat_interval_sec=2,
heartbeat_timeout_sec=8). Index #1#2 → In Review (r2). CD 列「順手可做不擋審」未動:
Rule #3 空窗搬回/Rule #9 寫 ≤30s/Host 於 Settlement 關分頁/AC23 跨文件引用/AC20 容忍窗.
/design-review netcode-session 第三輪 DONE (2026-09-06, 新 session): 6 specialists (gd/sd/np/
unity/qa/ux) + CD → NEEDS REVISION (24 blocking 含 3 結構前置, 21 recommended; sd+ux 判 MAJOR,
CD 裁 NEEDS). r2 7/7 確認已修、公式③數學全員複核 OK; 本輪全為新發現. 支柱級三洞: (1) #17/#18/
#20 未限 InShift → Host 在 Lobby 切分頁貼連結會殺自己的房; (2) client 分不清 Host 消失 vs 自己
斷線; (3) 退出→立刻重連可無限刷寬限期. CD 診斷: 三輪 blocking 只有四類 (範圍未限/常數未定/
層級未掃/未驗證前提), 清單式修訂只修被點名實例 → 改掃描式, 先建三張結構表.
ALL 24 FIXED same session (r3). user 決策 4 項: 鐵律改分域＋客製 Web Template 列 MVP; Host 獨留
續戰＋提前收班; Lobby 延後建連 (a) 為預設; settlement_timeout 20s. 修訂內容: 適用性矩陣 23×9/
常數三欄表/旋鈕約束 7 條; #17/#18/#20 限 InShift; 新 #21 Host 獨留, #22 結算逾時, #23 Lobby
延後建連 [P-10]＋複製連結鈕; #18 三訊號排歧表＋誠實預設文案; client 主動 teardown; 心跳
Unreliable [P-11]; 班次時鐘=wall-clock 真相、模擬不快轉、catch-up 暫緩 resync; #15 寬限期 rejoin
即結束; #6 交接完成=Host 提交; ClaimGeneration 入 NetworkVariable struct; UI 翻譯表加層級欄
＋MVP 文案改真; #10 更衣室 runtime 準時進場; 預算 25/10/10=45s＋AC7a; AC6a/6b [P-13/14];
P-7 加 [Preserve]; #8 輸碼大小寫不敏感; #12 beforeunload; AC 33→45 (新 34-43); P 9→14;
OQ#9-11. Registry +patience_mult/+settlement_timeout_sec, bg_threshold/max_players/
join_budget 註記更新. Index #1#2 → In Review (r3). Review log r3 條目已附.
未動 recommended (待批): AC9 拆重試/放棄; 碼失效 AC; #16/#17 AC; 寬限結束退場訊息;
測試專用 UGS 專案; 寬限期音效.
/design-review netcode-session 第四輪 DONE (2026-09-13, 新 session): 5 專家 (gd/np/sd/qa/ux)
+ 4 位獨立對抗驗證者 + CD → NEEDS REVISION (17 組). unity-specialist 三度因 API 用量上限中斷,
主審依 docs/engine-reference/unity/ 自行補交叉檢查 (scratchpad/r4-unity-crosscheck.md).
**另跑 2 張機械檢查**, 抓到的比六位專家加起來還多: AC 時間算術 37 條含時限 AC 中 **16 條不閉合**
(專家只找到 4 條) + 5 條無法驗算; 常數雙向對照 16 個常數中 **7 個假引用**、19 項應登錄未登錄、
**約束區塊 7 條全部與 Tuning Knobs 安全範圍矛盾**.
最嚴重 B4: #18 排歧表訊號三被誤述為「雲端側對 Host member 的觀察」(引擎文件只說「連線狀態」),
且其 fallback「退化為兩訊號」會讓「Host 消失」分支**永遠不可達**, 殺掉 AC6b (自標必達) 與 AC28
——全輪唯一 **fallback 自己不成立** 的假設.
**CD 流程裁定 (比 verdict 更重要): r4 是最後一輪散文式評審, 不再開 r5.** 理由: 四輪的 blocking
都長在上一輪修補的縫隙裡, 且約四成確認項是對一個沒人跑過的系統的斷言.

ALL FIXED same session (r4). 698 行 → **1224 行**; registry 常數 13 → **34**.
user 決策 3 項: (1) Settlement 期間加入者的支柱 5 出口＝**開放單人練習沙盒**;
(2) 留守者保護防濫用＝**同一玩家同班次第 2 次起仍降載但不給寬限期** (#15a);
(3) 現在就修.
修訂內容: 新增 8 條 Core Rule (#15a/#17a/#23a/#23b/#24 斷線處置原子序列/#24a MPS 成員唯一寫入者/
#25 Lobby Host 離開偵測/#26 開始上班轉場/#27 冷啟動 stall); #18 排歧表改雙路徑 (MPS 事件推播 +
roster 輪詢) 使「Host 消失」分支在 fallback 下仍可達; #20 刪除 Unreliable/HOL 錯誤立論 (HOL 在
TCP 層、在 pipeline 之下), 心跳範圍改「NGO 連線存在期間」, payload 一包三用並刪 60s resync;
#9 截止閘門移至 ConnectionApprovalCallback + 版本閘; 班次時鐘真相改 **Host 權威 shift_end_ts**
+ offset 掛心跳 + shift_length_sec 登錄; #23 降級為高風險架構假設 + 補完整替代設計;
States 新增 Booting/LoadFailed/Lobby*(前一班進行中), 刪孤兒名詞「Lobby 倒數」;
矩陣擴為 30 列 x 11 欄; **Tuning Knobs 安全範圍改為公式而非固定區間**; 約束 7 → **11 條**;
AC 46 → **57 條** (16 條不閉合全修 + 5 條拆分 + 新增 AC44-54) + 5 條 AC 撰寫規則;
[P] 14 → **20 條全部補「影響」欄** (META-I1) + 新增 P-15~P-20; OQ 新增 #12-#16.
約束驗算實跑: 11 條中 9 PASS / 2 待原型 / 1 條 (⑧ tick×RTT) 在 P-3 為全域 tick 時 FAIL
——**設計意圖如此**, 讓問題在回填當下自己跳出來.

**原型 W1 優先序 (r4 重排)**: **P-10 (升第一, 一次回答四項 blocking)** → P-4/P-6/P-19 (同一次
itch.io 部署) → P-7 → **P-3 + OQ#1 (必須與 AC22 聯測)** → P-13/P-14/P-15 → P-9/P-16 →
P-17/P-18/P-20. **P-11 移出 W1** (它問的是基於錯誤前提的問題).
P-4 讓位理由: 它的 fallback 是全表最健康的一條 (不轉發 → 輸碼成為唯一入口, AC2 已保底).
**W1 成功判準**: 原型報告必須回填 [P] 表的「影響」欄, 每條被推翻的假設要明講殺掉哪幾條 AC.

三張機械檢查 DONE (2026-09-13): 抓到的比六位專家加起來還多, 也抓到修訂本身的殘留與新洞.
AC 時間算術 50 條含時限: 閉合 32/不閉合 10/無法驗算 8, 其中 **6 條同源於單點缺陷**
(`t_disconnect` 在公式①是「Host 判定時刻」、在測試基建是「socket.close() 時刻」, 差 2s).
常數雙向: 三欄表 16 項「待補登」全為誤標 + 1 項假 Y + 4 處正文殘留.
[P]→影響 (首次執行): **20 條中 17 條影響欄不完整**; 7 條 fallback 會殺 MVP AC (5 條未標).
**最關鍵: B4 未修好只推遲一層** —— 排歧表兩條路徑共用 MPS session 層載體, 同層不可用時
序 1/3/4/5 一起死. 修法＝補「roster 查詢是 Lobby 設計既有前提」的載體論證.
**判準主詞未定義** —— 已新增 **MVP-必達** 層級 (AC6b/AC53/AC54/AC7).
ALL FIXED (r4 二次修訂): 1224 → **1291 行**; registry 34 → **40 常數**; 約束 11 → **14 條**
(⑧改條件式, 新增⑫⑬⑭); AC 修 11 條 + 新增 AC45a/AC55; P-2/P-20 拆半; P-6/7/9/17/18 標
fallback 不可行; 優先序新增**第 0 批 (零成本文件查詢)**, **P-17 從最後移到第 1 批**.
修訂協定新增兩條: (A) 影響欄須**反向掃描機械產生**不得手填; (B) fallback 寫「可行」前**須代入數字驗算**.
約束驗算實跑: 14 條 **PASS 10 / FAIL 0 / 待原型或非數值 4**.

NEXT: **直接開 W1 原型** (不開 r5), 依新分批: 第0批文件查詢(P-9前半/P-20/P-3前半) →
第1批 Sessions API 建連(P-10全部+P-17+P-14+P-2b) → 第2批 itch.io 部署(P-4+P-6+P-19) →
第3批 Release build(P-7+P-18) → 第4批 P-3後半+OQ#1+AC22聯測 → 第5批 P-13+P-15 → 之後 /design-system 商品資料庫 (順位2).
未 commit: 這幾天全部 pre-production 產出 (engine ref/art bible/index/GDD/registry/review log).
未 commit: 這幾天全部 pre-production 產出 (engine ref/art bible/index/GDD/registry).

<!-- STATUS -->
Epic: 大夜班 Pre-production
Feature: Systems Design
Task: netcode GDD r4 修訂完成 (散文評審結束) → 機械檢查複驗 → W1 技術原型
<!-- /STATUS --> KEY FACTS: C# 9.0 only;
[SerializeField] fields-only; URP render-graph only; NGO 2.13.2 + Multiplayer Services
2.3.1 (Sessions API: CreateSessionAsync + session.Code = room codes built-in); Web needs
UseWebSockets + "wss" Relay; Relay free tier 50 avg CCU no card needed. 5 unity-* agent
files got Version Awareness sections. Next: /art-bible → /map-systems.

## Other games (paused, intact)
- Night Market (夜市) — boot game in `src/`, v0.59, 553 tests. word-suika (一字一句) — juiced + title. Lexicon Village — shelved.

## Solo Mode
`production/review-mode.txt` = `solo`.
