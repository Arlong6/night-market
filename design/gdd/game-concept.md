# Night Market Runner — Game Concept

> **Status**: Concept
> **Scope**: Weekend project (MVP in 1–2 weekends)
> **Last Updated**: 2026-04-22
> **Working Title**: Night Market Runner (placeholder — rename when locked)

## One-Line Pitch
A 2D pixel-art platformer where a young Taiwanese kid dashes through Taiwan's
most iconic night markets, grabbing street food faves while dodging obstacles
and market hazards.

## Genre & Platform
- **Genre**: 2D side-scrolling platformer / collect-em-up
- **Perspective**: Side-scrolling, 16-bit pixel art
- **Platform**: Web (HTML5 via Godot 4.6)
- **Session length**: 2–5 minutes per level

## Setting
Three real Taiwanese night markets, each as its own level:
1. **Shilin (士林)** — Taipei classic, crowded, bright neon
2. **Fengjia (逢甲)** — Taichung, foodie heaven, tighter alleys
3. **Liouho (六合)** — Kaohsiung, coastal feel, seafood stalls

Each level's visual palette and food items reflect that market's real specialties.

## Player Fantasy
The rush of weaving through a packed night market on a perfect weekend night —
the smells, the neon, the spotting-your-favorite-stall-from-across-the-street
excitement. You're the hungry kid who knows exactly what they want and is going
for it.

## Core Loop
1. Run right along the market street (**player-paced — camera follows**; no forced forward motion)
2. **Jump over** ground obstacles (puddles, trash bags, scooters) and **duck under** hanging signs
3. Grab food items scattered through the level for points
4. Avoid enemies (annoyed stall owner with a broom, stray dog, careless tourist)
5. Reach the level end → score screen → next level

## Pillars (guide every design decision)
1. **Taste of home** — every visual/audio choice should feel authentically
   Taiwanese to a local, not a tourist's postcard version.
2. **Snackable joy** — 2–5 minute levels, zero friction to replay, instant
   "one more try" feel.
3. **Juicy feedback** — grabbing food should feel GOOD. Pixel particles, sound,
   score pop. Platformer feel > platformer depth.

## MVP Scope (locked)

**In:**
- 3 levels (one per market)
- Player character: run + jump (single jump, no double-jump for MVP) + **duck** (hold ↓/S; slide-under at 60% speed; auto-stand when clear)
- Collectibles: 4–6 food items per level, each worth points
- Obstacles: 2–3 types per level split across two categories:
  - **Jump-over**: static ground hazards (scooter, trash bag, crate)
  - **Duck-under**: hanging hazards (low-hanging sign, banner, awning rope)
- Enemies: 1–2 types per level, simple patrol AI (walk back and forth)
- Score system: points per item, time bonus, end-of-level total
- Level-end screen + level select
- Title screen + one background music track per level

**Out of scope (explicit cuts):**
- Multiple playable characters
- Dialogue, story cutscenes, NPCs
- Power-ups or abilities beyond jump
- Save system (high scores can be memory-only for MVP)
- Mobile/touch controls (keyboard only for MVP; add later if fun)
- Online leaderboard
- More than 3 levels

## Win / Lose Conditions
- **Win a level**: reach the right edge of the level.
- **Lose a level**: hit any enemy → instant restart of that level (no lives system
  for MVP — keep it frictionless).
- **Finish the game**: complete all 3 levels. Show total score.

## Controls (keyboard, web)
- **← / →** or **A / D** — move
- **Space** or **↑ / W** — jump (hold for higher jump, release early for short hop)
- **↓** or **S** — duck / slide-under (hold while running to pass under hanging hazards; auto-stand when clear)
- **R** — restart level
- **Esc** — return to level select

## Visual & Audio Direction
- 16-bit pixel art, ~32×32 tile grid, limited palette per market
  (full palette rules → `/art-bible`)
- Chip-tune / lo-fi retro music with subtle Taiwanese instrumentation if feasible
  (nanguan / erhu sample hits) — one track per level
- SFX: pickup blip, jump whoosh, enemy hit, stage clear fanfare

## Success Criteria (how we know MVP is done)
- All 3 levels playable start to finish in a browser
- Core loop (run → jump → grab → avoid → finish) feels responsive
- Score persists within a single play session
- Total download under 20MB for fast web load
- Runs at 60fps in Chrome on a mid-range laptop

## Open Questions (park for later)
- ~~Auto-scroll vs. player-paced scroll?~~ **RESOLVED 2026-04-22** — player-paced locked via prototype playtest. Camera follows player; no forced forward motion. Rationale: serves Snackable Joy (miss a collectible → turn around) and Taste of Home (unhurried exploration of each stall) better than auto-scroll's time pressure. See `prototypes/night-market-runner/REPORT.md`.
- Should collecting ALL items in a level unlock something? (post-MVP)
- How many unique food items total? (per market → `/art-bible`)
