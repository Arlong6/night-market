# Story R-007: HUD

> **Status**: Ready
> **Type**: UI
> **Estimated**: 1h
> **Depends on**: R-005
> **Unlocks**: —

## Goal

A minimal heads-up display showing current money (top-left) and ingredient
progress `N/5` (top-right). Subscribes to `Inventory` signals so it auto-updates
without polling. Always visible in the level scene; hidden during the title /
end screens (handled by scene composition — HUD is a child of the level only).

## References
- `design/gdd/game-concept-rpg.md` §8 AC ("HUD always displays...")
- v0.1-platformer `src/scripts/hud.gd` — CanvasLayer pattern with SystemFont +
  `FONT_ANTIALIASING_NONE` for pixel-crisp text

## Acceptance Criteria

- [ ] `src/scripts/hud_rpg.gd` — `class_name HudRpg extends CanvasLayer`:
  - [ ] `layer = 10` (above world, below dialogue at 15)
  - [ ] Two `Label` children:
    - [ ] Money label at top-left margin (4, 2), text format `"$XXX"`, font_size = 10
    - [ ] Progress label at top-right (right-aligned, x = 320 - 4 - text_width, y = 2), text format `"X/5"`, font_size = 10
  - [ ] Stamp-red `#C2241A` font colour (same accent as platformer HUD)
  - [ ] CJK SystemFont with explicit fallback chain (same as DialogueBox)
  - [ ] In `_ready`: connect to `Inventory.money_changed` → update money label, `Inventory.ingredient_added` → update progress label
  - [ ] On first frame, render initial values from `Inventory.money` and `Inventory.ingredient_count()`
- [ ] `src/scenes/hud_rpg.tscn` — minimal wrapper
- [ ] Level (`shilin_market.gd`) spawns the HUD as a child during `_spawn_hud()` step

## Implementation Notes

- Don't call `Inventory.money_changed.connect` if Inventory hasn't initialised
  yet — but as an autoload it's always ready by the time any scene loads, so
  this is safe.
- Use `await get_tree().process_frame` in tests if you need to assert label text
  after a signal fires.
- Right-align progress: simplest is `right_label.position.x = 320 - margin -
  right_label.size.x` after `right_label.update_minimum_size()`. Or use an
  HBoxContainer anchored top-right.

## Test Evidence (UI)

Manual walkthrough doc at `production/qa/evidence/R-007-hud-walkthrough.md`:

- [ ] Screenshot: title screen shows no HUD
- [ ] Screenshot: market loads, HUD shows "$200" and "0/5"
- [ ] Screenshot: after buying one ingredient, HUD shows "$170" and "1/5"
- [ ] Screenshot: after buying all 5, HUD shows the residual money and "5/5"

(GUT signal-update test optional; visual verification is the primary gate.)

## Out of Scope

- End-of-level money summary → R-008 (end screen)
- Time elapsed display (could add as a third label later if you want a speedrun
  metric — defer to v0.2 polish)
