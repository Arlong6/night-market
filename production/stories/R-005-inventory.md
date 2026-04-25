# Story R-005: Inventory Autoload

> **Status**: Ready
> **Type**: Logic
> **Estimated**: 1h
> **Depends on**: R-001
> **Unlocks**: R-006, R-007, R-008

## Goal

Global state tracker for player money and ingredients collected. Pure logic
class — no UI, no scene dependencies. The HUD (R-007) will subscribe to its
signals; the StallNPC (R-006) and MomNPC (R-008) will mutate / query it.

## References
- `design/gdd/game-concept-rpg.md` §3 (Inventory & money), §4 (Formulas)

## Acceptance Criteria

- [ ] `src/autoloads/inventory.gd` — `extends Node`, registered as `Inventory` autoload:
  - [ ] `const STARTING_MONEY: int = 200`
  - [ ] `const REQUIRED_INGREDIENTS: PackedStringArray = ["scallion", "egg", "cabbage", "chicken", "soy_sauce"]`
  - [ ] `const INGREDIENT_DISPLAY: Dictionary[String, String] = {"scallion": "蔥", "egg": "蛋", "cabbage": "高麗菜", "chicken": "雞肉", "soy_sauce": "醬油"}`
  - [ ] `var money: int = STARTING_MONEY`
  - [ ] `var ingredients: Dictionary[String, bool] = {}`
  - [ ] `signal money_changed(new_money: int)`
  - [ ] `signal ingredient_added(ingredient_id: String)`
- [ ] Methods:
  - [ ] `func has(ingredient_id: String) -> bool`
  - [ ] `func can_afford(price: int) -> bool` — returns `money >= price`
  - [ ] `func buy(ingredient_id: String, price: int) -> bool` — returns false if can't afford OR already have it; else deducts money + adds to dict + emits both signals
  - [ ] `func ingredient_count() -> int`
  - [ ] `func has_all_required() -> bool` — true iff every id in `REQUIRED_INGREDIENTS` is in `ingredients`
  - [ ] `func reset() -> void` — resets to starting state (used by R-009 restart)
  - [ ] `func display_name(ingredient_id: String) -> String` — returns CJK display label

## Implementation Notes

- `ingredients` is a `Dictionary[String, bool]` rather than a `PackedStringArray`
  for O(1) `has()` checks. Could also be `Dictionary[String, int]` if we ever
  want stack counts, but boolean is enough for this slice.
- `buy` returns bool so the StallNPC can branch on success (e.g., play sparkle
  FX vs. show "錢不夠" line).
- Total of 5 prices: 20 + 30 + 40 + 50 + 50 = 190. Less than STARTING_MONEY 200
  so a forgetful player still wins. Future tuning may tighten.

## Tests (BLOCKING — Logic story)

`src/tests/unit/inventory/test_inventory.gd` (GUT):

Setup: each test calls `Inventory.reset()` in `before_each`.

- [ ] `test_inventory_starts_with_starting_money` — `assert_eq(Inventory.money, 200)`
- [ ] `test_inventory_starts_empty` — `assert_eq(Inventory.ingredient_count(), 0)`
- [ ] `test_inventory_can_afford_when_money_sufficient` — money=200, `can_afford(50)` true
- [ ] `test_inventory_cannot_afford_when_money_insufficient` — set money=10, `can_afford(50)` false
- [ ] `test_inventory_buy_succeeds_when_affordable_and_new` — `buy("egg", 30)` returns true; money=170; `has("egg")` true
- [ ] `test_inventory_buy_emits_signals_on_success` — watch_signals(Inventory); buy succeeds; assert both `money_changed` and `ingredient_added` emitted exactly once each
- [ ] `test_inventory_buy_fails_when_unaffordable` — set money=10; `buy("chicken", 50)` returns false; money still 10; `has("chicken")` false
- [ ] `test_inventory_buy_fails_when_already_owned` — `buy("egg", 30)` then `buy("egg", 30)` again; second returns false; money decremented only once
- [ ] `test_inventory_has_all_required_false_when_partial` — buy 4 of 5; `has_all_required()` false
- [ ] `test_inventory_has_all_required_true_when_complete` — buy all 5; `has_all_required()` true
- [ ] `test_inventory_reset_returns_to_starting_state` — buy stuff, call reset, assert money=200, count=0
- [ ] `test_inventory_display_name_returns_cjk_label` — `display_name("egg")` returns "蛋"

## Out of Scope

- HUD display (R-007)
- Stall purchase flow (R-006)
- Win check (R-008)
