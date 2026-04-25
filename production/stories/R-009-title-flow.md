# Story R-009: Title + Restart Flow

> **Status**: Ready
> **Type**: UI
> **Estimated**: 1h
> **Depends on**: R-008
> **Unlocks**: —

## Goal

The title screen and the full game-flow loop: title → market → end → title.
The title scene was placeholder-built in R-001 with just a label; this story
adds the START button, wires it to the level transition, and confirms the
end-screen → title return path works.

## References
- `design/gdd/game-concept-rpg.md` §8 AC ("Pressing any key on the win scene returns to the title screen")
- v0.1-platformer `src/scripts/menus/title.gd` — title pattern, CJK font helper

## Acceptance Criteria

- [ ] `src/scripts/menus/title.gd` — `class_name TitleScreen extends Control`:
  - [ ] Centred vbox: title label "夜市採購大作戰" (font_size = 16), subtitle "Night Market Shopping" (font_size = 8), subtitle quest "媽媽叫你去夜市買 5 樣食材" (font_size = 8), START button (font_size = 12)
  - [ ] CJK SystemFont fallback chain
  - [ ] START button: focus by default; on press → `Inventory.reset(); Game.reset_run(); Game.goto_level("shilin")`
  - [ ] Background colour `#1A0A00` (project default_clear_color, no override needed)
- [ ] `Game.reset_run()` resets all per-run state: `session_time = 0.0`, `current_area = ""`. Inventory reset is called separately to keep the contract clean (each autoload manages its own state).
- [ ] Full flow verified end-to-end:
  - Title → press START → market loads with player at home cell, HUD shows $200 0/5
  - Walk around, buy 5 ingredients
  - Walk to mum → end screen → press any key → title (with reset Inventory, money=$200, count=0)

## Implementation Notes

- The platformer's `title.gd` already used the explicit CJK font chain — copy
  that pattern verbatim (`_make_cjk_font()` helper).
- For the "press any key returns to title" on the end screen, override
  `_unhandled_input(event)` in `end_screen.gd` and check `event is InputEvent
  and event.is_pressed()` (excludes mouse motion / focus events).
- Confirm via headless playtest that loading the market a second time after
  returning to title doesn't carry stale state from the first run (Inventory,
  Dialogue, Game.session_time all should re-init).

## Test Evidence (UI)

Manual walkthrough doc at `production/qa/evidence/R-009-flow-walkthrough.md`:

- [ ] Screenshot: title with "夜市採購大作戰" + START
- [ ] Screenshot: market loaded post-START, HUD $200 0/5
- [ ] Screenshot: end screen after delivery
- [ ] Notes: confirm second-run START re-initialises money + ingredients (no leak)
- [ ] Notes: GUT suite still passes (`/Users/arlong/Downloads/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`)

## Out of Scope

- Settings menu, pause menu, options
- Difficulty selection (game has no difficulty levels)
- Credits screen — defer to v0.2 if you want one
