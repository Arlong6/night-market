# Story R-008: Mom NPC + Win Condition

> **Status**: Ready
> **Type**: Logic
> **Estimated**: 1h
> **Depends on**: R-005, R-006
> **Unlocks**: R-009

## Goal

The mum NPC at the home tile. On bump, she checks `Inventory.has_all_required()`.
If true → trigger transition to the end scene (win). If false → show "還沒買齊"
encouragement line and resume play (no scene change). The end scene shows a
summary: thank-you line, money remaining, ingredients delivered, and an "any
key returns to title" prompt.

## References
- `design/gdd/game-concept-rpg.md` §3 (Win/lose), §8 AC (Win conditions)
- v0.1-platformer `src/scripts/menus/level_end.gd` — coin-drop tween pattern
  (steal the bounce ease for the money summary number)

## Acceptance Criteria

- [ ] `src/scripts/mom_npc.gd` — `class_name MomNPC extends NPC`:
  - [ ] Exports: `incomplete_lines: Array[String]` (default `["回來啦？讓我看看…", "還差 N 樣，再去看看吧。"]`)
  - [ ] Override `on_bumped()`:
    - [ ] If `Inventory.has_all_required()` → show "謝謝你！加菜囉～" then call `Game.goto_level("end_win")`
    - [ ] Else → show `incomplete_lines` (with the count substituted), no level change
  - [ ] `_draw()` placeholder: 14×14 ColorRect in `#9A4A8A` (purple — distinct from vendor brown / kid yellow)
- [ ] `src/scripts/menus/end_screen.gd` — `class_name EndScreen extends Control`:
  - [ ] Reads `Inventory.money`, `Inventory.ingredient_count()`, `Game.session_time`
  - [ ] Centred vbox with: "謝謝，今晚加菜！" header, money-remaining row (with bounce tween), ingredient list (5 rows, all checked), elapsed time, "按任何鍵回到首頁" prompt
  - [ ] CJK SystemFont fallback chain
  - [ ] On any input → `Game.goto_level("title")`
- [ ] `Game` autoload extended:
  - [ ] `var session_time: float = 0.0` updated each `_process` while in market
  - [ ] `LEVEL_PATHS = {"title": "res://scenes/menus/title.tscn", "shilin": "res://scenes/levels/shilin_market.tscn", "end_win": "res://scenes/menus/end_screen.tscn"}`
  - [ ] `func goto_level(key: String) -> void` — uses `get_tree().change_scene_to_file()` unless `test_mode == true`
- [ ] Level spawns one MomNPC at `home_cell + Vector2i(1, 0)` (one cell to the right of player spawn) so the player can immediately bump her on first arrival to test the no-ingredients path

## Implementation Notes

- `Game.session_time` resets in `Game.reset_run()` which the title screen calls
  on START. Don't reset on goto_level — the timer should run continuously
  through the whole shopping run.
- Use `Game.test_mode` flag to skip the actual scene change in unit tests
  (same pattern as platformer `Game` autoload).
- Bounce tween on the money number: `tween.set_ease(Tween.EASE_OUT);
  tween.set_trans(Tween.TRANS_BOUNCE)` — copy from platformer's `level_end.gd`.

## Tests (BLOCKING — Logic story)

`src/tests/unit/win/test_win_condition.gd` (GUT):

Setup: each test calls `Game.test_mode = true; Game.reset_run(); Inventory.reset()`.

- [ ] `test_mom_bump_with_all_ingredients_triggers_win` — call `Inventory.buy()` 5 times, bump mum, assert `Game.goto_level` was called with `"end_win"` (verify via spy or by checking `Game.current_area == "end_win"` if test_mode persists state)
- [ ] `test_mom_bump_without_all_ingredients_no_level_change` — buy only 4, bump mum, assert `Game.current_area` unchanged
- [ ] `test_mom_bump_incomplete_shows_dialogue` — bump with 0 ingredients, assert `Dialogue.show` was called with the incomplete lines
- [ ] `test_session_time_accumulates_during_market` — call `Game._process(0.5)` 4 times, assert `Game.session_time == 2.0`
- [ ] `test_reset_run_zeroes_session_time` — set time to 30.0, call reset, assert 0.0

## Out of Scope

- Save/load of best-time (no save system this slice)
- Lose state (player can never lose this slice, only delay)
