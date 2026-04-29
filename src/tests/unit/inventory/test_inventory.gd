## GUT unit tests for Inventory autoload (R-005). BLOCKING — Logic story.
extends GutTest


## Inventory is an autoload that persists across tests; each test resets.
## v0.13: reset() now randomises required_ingredients; tests that need a
## specific list assign it manually after reset (see explicit overrides
## below).
func before_each() -> void:
	Inventory.reset()


func test_inventory_starts_with_starting_money() -> void:
	assert_eq(Inventory.money, Inventory.STARTING_MONEY,
		"Money should start at STARTING_MONEY")
	assert_eq(Inventory.STARTING_MONEY, 220,
		"v0.13 budget — random required-list can sum up to 270, $220 keeps bargain useful but feasible")


func test_inventory_starts_empty() -> void:
	assert_eq(Inventory.ingredient_count(), 0,
		"No ingredients should be collected at start")


func test_inventory_can_afford_when_money_sufficient() -> void:
	assert_true(Inventory.can_afford(50), "220 >= 50 should be affordable")
	assert_true(Inventory.can_afford(220), "220 >= 220 should be affordable (boundary)")


func test_inventory_cannot_afford_when_money_insufficient() -> void:
	Inventory.money = 10
	assert_false(Inventory.can_afford(50), "10 < 50 should not be affordable")
	assert_false(Inventory.can_afford(11), "10 < 11 should not be affordable (boundary)")


func test_inventory_buy_succeeds_when_affordable_and_new() -> void:
	var ok: bool = Inventory.buy("egg", 30)
	assert_true(ok, "buy should succeed when affordable + new")
	assert_eq(Inventory.money, 190, "Money should decrement by price (220 - 30)")
	assert_true(Inventory.has("egg"), "ingredient should be owned after buy")


func test_inventory_buy_emits_signals_on_success() -> void:
	watch_signals(Inventory)
	Inventory.buy("egg", 30)
	assert_signal_emitted(Inventory, "money_changed",
		"money_changed should emit on successful buy")
	assert_signal_emitted(Inventory, "ingredient_added",
		"ingredient_added should emit on successful buy")


func test_inventory_buy_fails_when_unaffordable() -> void:
	Inventory.money = 10
	var ok: bool = Inventory.buy("chicken", 50)
	assert_false(ok, "buy should fail when too poor")
	assert_eq(Inventory.money, 10, "Money unchanged on failed buy")
	assert_false(Inventory.has("chicken"), "ingredient not added on failed buy")


func test_inventory_buy_fails_when_already_owned() -> void:
	assert_true(Inventory.buy("egg", 30), "first buy succeeds")
	var second: bool = Inventory.buy("egg", 30)
	assert_false(second, "second buy of same item should fail")
	assert_eq(Inventory.money, 190,
		"Money should only decrement once even after duplicate attempt")


func test_inventory_has_enough_false_when_partial() -> void:
	# v0.13: pin the required list so we can reliably "buy 4 of 5"
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "soy_sauce"
	])
	# Buy only 4 of the required 5
	assert_true(Inventory.buy("scallion", 20))
	assert_true(Inventory.buy("egg", 30))
	assert_true(Inventory.buy("cabbage", 40))
	assert_true(Inventory.buy("chicken", 50))
	assert_false(Inventory.has_enough(),
		"4/5 of required collected should not satisfy has_enough()")


func test_inventory_has_enough_true_when_required_list_complete() -> void:
	# v0.13: must own EVERY id in the random required-list (not just 5 of 7).
	# Pin the list so the test is deterministic.
	Inventory.money = 1000
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "tofu"
	])
	for id_price in [["scallion", 20], ["egg", 30], ["cabbage", 40],
					 ["chicken", 50], ["tofu", 60]]:
		assert_true(Inventory.buy(id_price[0], id_price[1]),
			"Buy %s should succeed" % id_price[0])
	assert_true(Inventory.has_enough(),
		"All 5 required collected should satisfy has_enough()")
	assert_true(Inventory.has_all_required(),
		"Legacy alias has_all_required() should match has_enough()")


func test_inventory_has_enough_false_when_5_bought_but_wrong_set() -> void:
	# v0.13: buying 5 ingredients but missing even one required = no win.
	# This is the core semantic shift from v0.7's "any 5".
	Inventory.money = 1000
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "soy_sauce"
	])
	# Buy 4 of the required + 1 NOT required
	assert_true(Inventory.buy("scallion", 20))
	assert_true(Inventory.buy("egg", 30))
	assert_true(Inventory.buy("cabbage", 40))
	assert_true(Inventory.buy("chicken", 50))
	assert_true(Inventory.buy("tofu", 60))  # tofu not in required list
	assert_eq(Inventory.ingredient_count(), 5,
		"Pre-condition: 5 ingredients owned")
	assert_false(Inventory.has_enough(),
		"5 owned but missing 'soy_sauce' from required → not enough")


func test_inventory_reset_returns_to_starting_state() -> void:
	Inventory.buy("egg", 30)
	Inventory.buy("scallion", 20)
	Inventory.reset()
	assert_eq(Inventory.money, Inventory.STARTING_MONEY,
		"Reset should restore STARTING_MONEY")
	assert_eq(Inventory.ingredient_count(), 0,
		"Reset should clear ingredients")


func test_inventory_display_name_returns_cjk_label() -> void:
	assert_eq(Inventory.display_name("egg"), "蛋")
	assert_eq(Inventory.display_name("scallion"), "蔥")
	assert_eq(Inventory.display_name("chicken"), "雞肉")


func test_inventory_difficulty_keeps_bargain_relevant() -> void:
	# v0.13: required list is now random — but the WORST-case selection (the
	# 5 most expensive of the 7) must still exceed STARTING_MONEY so that some
	# runs really do force the bargain mini-game.
	var prices: Array[int] = [20, 30, 40, 50, 50, 60, 70]
	prices.sort()
	var most_expensive_5_total: int = 0
	for i in range(prices.size() - Inventory.REQUIRED_COUNT, prices.size()):
		most_expensive_5_total += prices[i]
	assert_gt(most_expensive_5_total, Inventory.STARTING_MONEY,
		"Worst-case required-list sum (%d) must exceed STARTING_MONEY (%d) so bargain stays relevant" %
			[most_expensive_5_total, Inventory.STARTING_MONEY])

	# At the same time, the EASIEST run (cheapest 5) should comfortably fit
	# the budget so a lucky randomisation doesn't soft-block the player on
	# difficulty.
	var cheapest_5_total: int = 0
	for i in Inventory.REQUIRED_COUNT:
		cheapest_5_total += prices[i]
	assert_lte(cheapest_5_total, Inventory.STARTING_MONEY,
		"Best-case required-list sum (%d) should fit STARTING_MONEY (%d) so easy runs feel breezy" %
			[cheapest_5_total, Inventory.STARTING_MONEY])


# ---------------------------------------------------------------------------
# v0.13 — random required-ingredient list
# ---------------------------------------------------------------------------

func test_inventory_randomize_required_picks_required_count_unique_ids() -> void:
	Inventory.randomize_required()
	assert_eq(Inventory.required_ingredients.size(), Inventory.REQUIRED_COUNT,
		"required_ingredients should have exactly REQUIRED_COUNT entries")
	# Uniqueness — convert to dictionary keys, count must match length
	var seen: Dictionary = {}
	for id in Inventory.required_ingredients:
		seen[id] = true
		assert_true(id in Inventory.ALL_INGREDIENTS,
			"required id '%s' must be from ALL_INGREDIENTS" % id)
	assert_eq(seen.size(), Inventory.REQUIRED_COUNT,
		"All required entries should be unique")


func test_inventory_reset_re_rolls_required_list() -> void:
	# Force a known list, then reset; new list should be regenerated
	# (probabilistically the new list will differ from the pinned one — but
	# even when it doesn't, randomize was still called, which is what we care
	# about. Assert at minimum that the size invariant holds.)
	Inventory.required_ingredients = PackedStringArray(["scallion", "egg", "cabbage"])
	Inventory.reset()
	assert_eq(Inventory.required_ingredients.size(), Inventory.REQUIRED_COUNT,
		"reset() should re-roll required_ingredients to REQUIRED_COUNT entries")


func test_inventory_is_required_matches_active_list() -> void:
	Inventory.required_ingredients = PackedStringArray(["scallion", "egg"])
	assert_true(Inventory.is_required("scallion"))
	assert_true(Inventory.is_required("egg"))
	assert_false(Inventory.is_required("chicken"))
	assert_false(Inventory.is_required("nonexistent"))


func test_inventory_required_owned_count_only_counts_required() -> void:
	Inventory.money = 1000
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "soy_sauce"
	])
	# Buy 2 required
	Inventory.buy("scallion", 20)
	Inventory.buy("egg", 30)
	# Buy 1 NOT required — should not count
	Inventory.buy("tofu", 60)
	assert_eq(Inventory.required_owned_count(), 2,
		"Only required ingredients should count toward progress")
	assert_eq(Inventory.ingredient_count(), 3,
		"ingredient_count() still counts every owned ingredient regardless")


func test_inventory_display_abbrev_returns_one_char() -> void:
	assert_eq(Inventory.display_abbrev("chicken"), "雞")
	assert_eq(Inventory.display_abbrev("cabbage"), "菜")
	assert_eq(Inventory.display_abbrev("soy_sauce"), "醬")
