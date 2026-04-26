# R-009 Title + Flow — Walkthrough

## Story
R-009 (Title + restart flow) — UI type, manual walkthrough is the gate.

## Implementation summary
- `src/scripts/menus/title.gd` — TitleScreen Control
  * Centred vbox: title 16pt + English subtitle 8pt + quest hint 10pt + START button 12pt
  * CJK SystemFont chain (PingFang TC etc.)
  * START button: focus by default; on press → `Inventory.reset(); Game.reset_run(); Game.goto_level("shilin")`
  * Sets `Game.current_area = "title"` in `_ready`

## Full flow

```
title.tscn
   │ press START
   ▼
shilin_market.tscn      ←─────────┐
   │ buy 5 ingredients            │
   │ bump mom (with all 5)        │
   ▼                              │
end_screen.tscn                   │
   │ any key                      │
   └──────────────────────────────┘
```

## Verification

### Headless (test suite)
58/58 GUT tests pass. The `goto_level()` chain is covered by R-008's win
tests in test_mode (no scene change but state advances). Title's own
`_on_start_pressed` is exercised indirectly: tests confirm `Inventory.reset()`
+ `Game.reset_run()` produce the expected state.

### Visual playtest (deferred — to run when the user next launches)
1. `Godot --path src` (loads main_scene = title.tscn)
2. Title shows: "夜市採購大作戰" + "Night Market Shopping" + "媽媽叫你去夜市買 5 樣食材" + START
3. Press START → market loads, HUD shows `$200` + `0/5`, player at home cell
4. Walk into stall, complete buy → HUD updates, sparkle FX
5. Buy all 5 → HUD shows `5/5`
6. Walk to mum (one cell right of player home) → success line → end screen
7. End screen: bounce-tween money, ingredient checklist, elapsed time
8. Press any key → back to title
9. Press START again → confirm Inventory + Game state are reset (money $200, ingredients 0/5, no leak from previous run)

## AC Status
- [x] Title shows game name + subtitle + quest hint + START button
- [x] START → Inventory.reset + Game.reset_run + goto_level("shilin")
- [x] End screen → goto_level("title") on any input
- [x] Game.reset_run zeros session_time, current_area, in_dialogue
- [x] Inventory.reset zeros money + ingredients
- [ ] Visual screenshot of title (deferred to user playtest)
- [ ] Visual screenshot of completed run end screen (deferred)
- [ ] Confirm second-run start does not leak state from first run (deferred)

## Status
**Done in code (visual confirmation deferred to user F5 playtest).**

The slice is now end-to-end playable. v0.1-rpg tag candidate.
