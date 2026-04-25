# Story R-006: Stall NPCs

> **Status**: Ready
> **Type**: Integration
> **Estimated**: 2h
> **Depends on**: R-004, R-005
> **Unlocks**: R-008

## Goal

The 5 vendor NPCs that actually sell ingredients. Each stall extends the base
`NPC` class. On bump, it shows an intro dialogue, then a yes/no choice
("買 [食材] NT$XX? 是 / 否"). Selecting `是` calls `Inventory.buy()` and shows
sparkle FX on success or a "錢不夠" line on failure. Once sold, the stall's
state flips to "sold-out" with a closing line.

## References
- `design/gdd/game-concept-rpg.md` §3 (NPC two types, talked-once flag)
- `src/scripts/fx/particle_burst.gd:1-95` — restored from v0.1-platformer; use
  for purchase-success sparkle

## Acceptance Criteria

- [ ] `src/scripts/stall_npc.gd` — `class_name StallNPC extends NPC`:
  - [ ] Exports: `ingredient_id: String`, `price: int`, `intro_lines: Array[String]`, `sold_out_lines: Array[String]`
  - [ ] State: `_sold: bool = false` (private)
  - [ ] Override `on_bumped()`: if `_sold` → show `sold_out_lines`; else → show `intro_lines` then trigger choice prompt
  - [ ] `_draw()`: 14×14 ColorRect in stall colour `#D94F2B` (carries vendor visual identity from platformer art-bible) with `#F2A227` 2px top stripe (food highlight)
- [ ] Dialogue choice prompt (extension to R-004 dialogue system):
  - [ ] `Dialogue.ask_choice(question: String, options: Array[String], on_choice: Callable) -> bool`
  - [ ] DialogueBox renders option list below the question; arrow keys move selection; `interact` confirms; `on_choice.call(selected_index)`
- [ ] Stall purchase flow:
  - [ ] If `selected_index == 0` (是) AND `Inventory.buy(ingredient_id, price)` succeeds:
    - [ ] Spawn `ParticleBurst` at stall position (gold particles, ~6 count)
    - [ ] Show "好喔，多謝！" closing line
    - [ ] Set `_sold = true`
  - [ ] If 是 but buy fails (unaffordable): show "錢不夠喔，下次再來"; `_sold` stays false
  - [ ] If 否 (selected_index == 1): show "好啦，看看就好"; `_sold` stays false
- [ ] Level (`shilin_market.gd`) spawns 5 StallNPC instances at the 5 reserved
  `STALL_CELLS` from R-003, each pre-configured with one ingredient + price:
  - 蔥 NT$20, 蛋 NT$30, 高麗菜 NT$40, 雞肉 NT$50, 醬油 NT$50

## Implementation Notes

- `Dialogue.ask_choice()` is a meaningful R-004 extension; if R-004 was already
  done, modify it now or fold the choice rendering into DialogueBox here.
- Choice navigation: track `_selected_choice: int`, render with `▶` marker
  on the active line. Up/Down arrow key moves it.
- The bumps-during-dialogue gate from R-004 is critical: don't allow re-bumping
  the stall while the choice prompt is open (player movement is locked anyway,
  but make sure the choice flow can't re-enter itself).
- `ParticleBurst` is restored from the v0.1-platformer tag — it works as-is.
  Use `parent.add_child(burst)` pattern from `level_shilin.gd:303-318`.

## Tests (Integration)

`src/tests/integration/npc/test_stall_npc.gd` (GUT):

- [ ] `test_stall_intro_then_choice_on_first_bump` — bump stall, await dialogue, assert intro lines shown then choice prompt opens
- [ ] `test_stall_yes_choice_with_money_buys_ingredient` — Inventory.money=200, bump stall (egg, 30), select 是, assert money=170 + has("egg") + sold flag
- [ ] `test_stall_yes_choice_without_money_shows_poor_line` — Inventory.money=10, bump stall (egg, 30), select 是, assert money=10 + not has("egg") + closing line is "錢不夠..."
- [ ] `test_stall_no_choice_does_not_buy` — bump, select 否, assert money unchanged + not has(id)
- [ ] `test_stall_repeat_bump_after_sold_shows_sold_out_lines` — buy, then bump again, assert sold_out_lines shown not intro_lines
- [ ] `test_stall_particle_burst_spawned_on_successful_buy` — buy succeeds, await one frame, assert level has at least one ParticleBurst child

## Out of Scope

- HUD reflection of money / ingredient changes (R-007)
- Win check on mum bump (R-008)
- Multiple ingredients per stall (single-item per stall is the design)
