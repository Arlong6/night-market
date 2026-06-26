# 橫衝直撞 (Road Rage) — Design Spec

> **Status**: Approved (concept) 2026-06-27 — pending spec review
> **Type**: Top-down 2D vehicle destruction sandbox (Godot 4.6, Web/HTML5)
> **Working title**: 橫衝直撞 (subject to change)

## 1. Overview

A top-down arcade game about one thing: get in a car, floor it, and turn a city
into a smoking crater. No story, no objectives beyond "destroy more." The player
rams everything — market stalls, parked cars, hydrants, trees, fleeing pedestrians
— building destruction combos while the wanted level escalates and police pile on,
until the vehicle is finally wrecked. Then: a score, a personal best, and "one
more run." Mindless, juicy, instantly legible.

## 2. Player Fantasy

"I am a wrecking ball with wheels." Pure cathartic chaos: weight, speed, crunch,
explosions, sirens, and a screen full of carnage that I caused. The dopamine is
the *impact* — every smash pops, every chain reaction escalates, and the city
visibly falls apart behind me.

## 3. Core Loop (10-second)

Drive → ram destructibles (they break: debris + particles + score) → destruction
meter & combo climb → wanted level (★) rises → more/tougher police respond →
escalate (pickups keep the rampage going) → vehicle wrecked → score screen → restart.

## 4. Design Pillars

1. **Weighty driving** — momentum, drift, and a satisfying crunch/jolt on impact.
   The car must feel *heavy*, not floaty.
2. **Everything breaks** — fully programmatic destruction; any prop above an
   impact-force threshold shatters into debris + particles. Cartoony, non-gory
   (pedestrians comically scatter/tumble — playful, web/itch-safe).
3. **Escalation** — destruction raises *heat*; heat raises the wanted star level;
   stars spawn escalating responders (police car → roadblock → … later: helicopter,
   tank). Chain reactions (cars/gas → secondary explosions).
4. **Juice maximalism** — screenshake, impact freeze-frames, milestone slow-mo,
   particle storms, procedural engine/impact/explosion/siren audio, combo callouts,
   camera zoom-punch. This is where we "push the limits."

## 5. Session Structure

**Score-attack arcade.** Each run is a rampage until the player's vehicle health
hits zero (from heavy crashes + police ramming/fire). Persistent best score +
"most destroyed" stat drive the "one more run" chase. (Chosen over a
"flatten X% of the city" objective for maximum replay + minimum friction.)

## 6. Scope

### v1 — Vertical Slice (prove the 30 seconds is fun)
- ONE drivable vehicle (arcade physics, health).
- ONE procedurally-populated city district (road grid + blocks + scattered props).
- Destructibles: market stalls, parked cars, hydrants (water spray), trees,
  street props, pedestrians (scatter/tumble).
- Combo system + destruction scoring.
- Wanted/heat system with star levels.
- ONE police type (chase + ram).
- Full juice pass (shake, particles, freeze, audio, combo callouts).
- Title/start screen (= Web audio-unlock gesture) + high-score persistence.
- HUD: score, combo, wanted stars, destruction %.

### Later (NOT in v1)
- Vehicle upgrades / multiple vehicles, nitro pickups.
- Army tier (helicopter, tank), roadblocks, spike strips.
- On-foot play, multiple districts, missions, story.
- Chain-reaction gas stations (maybe a stretch goal in v1 if cheap).

### Out of scope (this game)
- 3D, online/multiplayer, real-world city/IP, gore.

## 7. System Architecture (isolated units)

Each unit has one purpose, a clear interface, and explicit dependencies. Pure-logic
units (marked ⚙) are unit-tested.

| Unit | Purpose | Interface (key) | Depends on |
|---|---|---|---|
| **Vehicle** | Player car arcade physics + health | `apply_input(accel, steer)`, `velocity`, `mass`, `take_damage()` | physics |
| **Destructible** | A breakable world object | `take_impact(force: float, point) -> bool broke`, emits `destroyed(value)` | DebrisPool, FX, RRAudio, Score |
| **DebrisPool / FX** | Pooled debris chunks + particle bursts | `spawn(pos, kind, color)` | — (leaf) |
| **CityGen** ⚙ | Procedurally lay out a district from a seed | `generate(seed) -> layout` | tile/prop data |
| **TrafficAI / PedAI** | Wandering cars + pedestrians that flee the player | steering `update()` | (reuse WanderShopper pattern) |
| **PoliceAI** | Chase + ram the player, scaled by wanted | `spawn()`, chase steering | Vehicle (target), Wanted |
| **WantedSystem** ⚙ | Accumulate heat → star level → responder budget | `add_heat(n)`, `stars()`, `decay(dt)` | — (pure state) |
| **ComboSystem** ⚙ | Chain destructions in a time window → multiplier | `register(value) -> points`, `multiplier()`, `tick(dt)` | — (pure state) |
| **ScoreSystem** ⚙ | Run score + persistent best/stats | `add(points)`, `submit() -> new_best` | ConfigFile |
| **CameraRig** | Follow + shake + zoom-punch | `shake(strength)`, `punch(z)` | player transform |
| **RRAudio** ⚙ | Procedural engine loop, impacts, explosions, sirens | `engine(rpm)`, `impact(force)`, `explosion()`, `siren()` | AudioStreamWAV |
| **GameDirector / Main** | Wire everything; run lifecycle + HUD | start/run/busted/restart | all of the above |
| **Title** | Start gate (audio unlock) + best score | input → load game | ScoreSystem |

## 8. Key Mechanics Detail

- **Impact model**: on collision, impact force ≈ relative speed × vehicle mass.
  If force ≥ a destructible's `break_threshold`, it breaks (debris + score +
  audio + a velocity bleed so the car slows realistically on big hits). Below
  threshold: a clink/bump, no break.
- **Heat → wanted**: each destruction adds heat (bigger objects = more). Star
  thresholds are data-driven (e.g. ★1 at 50 heat, ★2 at 150, …). Heat decays
  slowly when not destroying. Stars set a "responder budget" → how many/what
  police spawn.
- **Combo**: each destruction within `COMBO_WINDOW` (~1.6s) of the last bumps a
  multiplier (cap ~×10); the window refreshes on each hit. Combo drives both
  score and juice intensity.
- **Scoring**: per-object base value × combo multiplier; persistent best score +
  best destruction count.
- **City**: deterministic per seed (for replay variety + future share-codes). Grid
  of road tiles + buildings (impassable) + walkable blocks scattered with props.

## 9. Juice Catalog (the differentiator)

Screenshake scaled to impact force · zoom-punch on big smashes · 1–3 frame freeze
on heavy hits · slow-mo on milestone combos (e.g. ×10) · debris chunks with
physics · particle bursts (dust, sparks, smoke, water from hydrants) · floating
score popups · combo callouts ("×7 連擊! 失控!") · siren audio rising with stars ·
procedural engine note tracking speed · escalating music intensity by wanted level.

## 10. Tech Stack & Location

- Godot 4.6, GDScript, 2D top-down, GL Compatibility renderer (Web), programmatic
  art (zero art assets → small download, no asset pipeline).
- **New standalone project `road-rage/`** at repo root (clean isolation, like
  `word-suika/`). GUT installed from the start for unit tests.
- Object pooling for destructibles/debris (Web perf budget).
- CJK font bundled for HUD (per known Web-CJK constraint).
- Reuse proven patterns from this repo: WanderShopper steering AI (Night Market),
  procedural AudioStreamWAV synthesis (WSAudio / lv_sfx), high-score ConfigFile
  persistence (WSHiScore), camera shake (word-suika main).

## 11. Testing Strategy

Pure-logic units get GUT unit tests (run headless on Godot 4.6.2, the 553-green
standard): WantedSystem (heat→stars thresholds, decay), ComboSystem (window,
multiplier cap, reset), ScoreSystem (round-trip + new-best), impact→break
threshold logic, CityGen determinism (same seed → same layout), RRAudio (valid
non-empty streams per sound). Visual/feel (juice, driving) verified by the user
in an interactive run; headless boot confirms no runtime errors.

## 12. Tuning Knobs

Vehicle: accel, max speed, turn rate, mass, drift, health. Impact: break-force
threshold per object type, velocity bleed on break. Heat: heat-per-object, star
thresholds, decay rate. Police: spawn cadence per star, chase speed, ram damage.
Combo: window seconds, multiplier cap. Score: per-object base values. City: grid
size, building density, prop density. (All data-driven where practical.)

## 13. Acceptance Criteria (testable)

- **AC1** Run starts from the title on click/key; player drives a car with momentum/drift.
- **AC2** Ramming a destructible at/above its break threshold breaks it (debris +
  score event); below threshold it does not. (unit-tested threshold logic)
- **AC3** Destroying objects adds heat; crossing star thresholds raises the wanted
  level. (unit-tested)
- **AC4** Chained destructions within the combo window stack a multiplier up to the
  cap; the window resets correctly. (unit-tested)
- **AC5** Police spawn and chase as wanted rises; accumulated damage wrecks the
  player → game over → restart.
- **AC6** Run score + best persist across sessions; best is shown. (unit-tested round-trip)
- **AC7** City layout is deterministic per seed. (unit-tested)
- **AC8** Project boots clean headless; all unit tests green on Godot 4.6.2.

## 14. Build Order (vertical slice → escalation)

1. Project scaffold + GUT + title + a drivable car on an empty lot (feel the driving).
2. Destructibles + impact/break + debris/particles + impact audio (feel the smashing).
3. Combo + score + high score + HUD.
4. CityGen (district populated with props + traffic + pedestrians).
5. Wanted/heat + police AI + game-over.
6. Full juice pass (shake/freeze/slow-mo/zoom/music) — push the limits.

Each step verified (tests + headless boot) before the next; user playtests feel
at steps 1, 2, and 6.
