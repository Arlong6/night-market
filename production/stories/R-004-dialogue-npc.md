# Story R-004: Dialogue Box + NPC

> **Status**: Ready
> **Type**: Integration
> **Estimated**: 2h
> **Depends on**: R-003
> **Unlocks**: R-006

## Goal

A typewriter dialogue box that pops up when the player bumps an NPC. Player
input is locked while dialogue is open. Pressing the `interact` key advances
the line (or skips the typewriter to the end of the current line if still
animating). The dialogue system is global (autoload) so any future NPC type
can call it without coupling.

## References
- `design/gdd/game-concept-rpg.md` §3 (NPCs), §5 (re-entrancy edge case)
- v0.1-platformer `src/scripts/menus/title.gd` — `_make_cjk_font()` pattern
  (PingFang TC chain — required for Chinese text rendering)

## Acceptance Criteria

- [ ] `src/autoloads/dialogue.gd` — `extends Node`, registered as `Dialogue` autoload:
  - [ ] `signal dialogue_started`
  - [ ] `signal dialogue_finished`
  - [ ] `func show(lines: Array[String], on_done: Callable = Callable()) -> bool` — returns false if already in dialogue (re-entrancy guard)
  - [ ] Owns / spawns the `DialogueBox` instance lazily on first call
  - [ ] Sets `Game.in_dialogue = true` on start, `false` on finish; calls `on_done` when finished
- [ ] `src/scripts/dialogue_box.gd` — `class_name DialogueBox extends CanvasLayer`:
  - [ ] `layer = 15`
  - [ ] CJK SystemFont with explicit fallback chain (`PingFang TC`, `Heiti TC`, `Microsoft JhengHei`, `Noto Sans CJK TC`, `Noto Sans TC`, `sans-serif`)
  - [ ] Visual: ColorRect background at bottom of viewport (cream `#F5EDDA`, 4px margin from edges, height = ~50px), 1px ink border
  - [ ] `var current_line: String`, `var visible_chars: int`, `var lines: Array[String]`, `var on_done: Callable`
  - [ ] `_process` advances `visible_chars` at `CHARS_PER_SECOND = 30.0`
  - [ ] On `interact` press: if mid-typewriter → reveal full line; if line fully shown → next line; if last line → close + emit finished
- [ ] `src/scripts/npc.gd` — `class_name NPC extends Node2D`:
  - [ ] Exports: `cell: Vector2i`, `lines: Array[String]`
  - [ ] On `_ready`: `position = GridWorld.cell_to_px(cell)`
  - [ ] `func on_bumped() -> void` — calls `Dialogue.show(lines)`. Stalls override this in R-006.
  - [ ] `_draw()` placeholder: 14×14 ColorRect in `#7A3A2A` (vendor brown) centred on cell
- [ ] `Game.in_dialogue` flag added to `Game` autoload (default `false`)
- [ ] Player movement gated on `not Game.in_dialogue` (wire R-002's gate to the actual flag)
- [ ] Level wires bumps: when PlayerGrid attempts an unwalkable step, the level checks if the target cell hosts an NPC and calls `npc.on_bumped()`

## Implementation Notes

- Re-entrancy: `Dialogue.show()` must return `false` and no-op if a dialogue is
  already active. Tested.
- Bump detection: simplest place is in `ShilinMarket` — when PlayerGrid emits
  `cell_changed` is too late (already moved). Better: PlayerGrid emits a
  separate `signal bumped(target_cell)` when the walkable check fails, level
  listens and looks up NPC by cell. Add this signal to PlayerGrid.
- Maintain a `Dictionary[Vector2i, NPC]` in the level keyed on each NPC's cell
  for O(1) bump lookup.
- DialogueBox must not consume input via `_input` if the player is mid-dialogue
  but dialogue hasn't fully started (race condition). Use a small `_active: bool`
  flag set on first `_process` after `show()`.

## Tests (Integration)

`src/tests/integration/dialogue/test_dialogue.gd` (GUT):

- [ ] `test_dialogue_show_locks_game_in_dialogue` — call `Dialogue.show(["hi"])`, await frame, assert `Game.in_dialogue == true`
- [ ] `test_dialogue_show_when_active_returns_false` — call show twice, second returns false
- [ ] `test_dialogue_typewriter_advances_visible_chars_over_time` — show a line, advance 0.5s, assert `visible_chars > 0` and `< len(line)`
- [ ] `test_dialogue_interact_skips_typewriter` — show a long line, simulate `interact` press mid-typewriter, assert `visible_chars == len(line)`
- [ ] `test_dialogue_advances_to_next_line` — show 2 lines, fast-forward + interact, fast-forward + interact, assert `dialogue_finished` emitted
- [ ] `test_dialogue_on_done_callable_invoked` — pass a Callable, complete dialogue, assert callable was called

`src/tests/integration/npc/test_npc_bump.gd` (GUT):

- [ ] `test_npc_bump_triggers_dialogue` — spawn NPC at cell (5,5), simulate player bump on (5,5), assert `Dialogue.show` called with NPC.lines

## Out of Scope

- Choice prompts (yes/no) → R-006 (StallNPC)
- HUD updates → R-007
