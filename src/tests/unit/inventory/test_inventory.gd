## GUT unit tests for Inventory autoload (R-005). BLOCKING — Logic story.
extends GutTest


## Inventory is an autoload that persists across tests; each test resets.
func before_each() -> void:
	Inventory.reset()


func test_inventory_starts_with_starting_money() -> void:
	assert_eq(Inventory.money, Inventory.STARTING_MONEY,
		"Money should start at STARTING_MONEY")
	assert_eq(Inventory.STARTING_MONEY, 180,
		"v0.7 difficulty target — must bargain or skip dearer items to make budget")


func test_inventory_starts_empty() -> void:
	assert_eq(Inventory.ingredient_count(), 0,
		"No ingredients should be collected at start")


func test_inventory_can_afford_when_money_sufficient() -> void:
	assert_true(Inventory.can_afford(50), "180 >= 50 should be affordable")
	assert_true(Inventory.can_afford(180), "180 >= 180 should be affordable (boundary)")


func test_inventory_cannot_afford_when_money_insufficient() -> void:
	Inventory.money = 10
	assert_false(Inventory.can_afford(50), "10 < 50 should not be affordable")
	assert_false(Inventory.can_afford(11), "10 < 11 should not be affordable (boundary)")


func test_inventory_buy_succeeds_when_affordable_and_new() -> void:
	var ok: bool = Inventory.buy("egg", 30)
	assert_true(ok, "buy should succeed when affordable + new")
	assert_eq(Inventory.money, 150, "Money should decrement by price (180 - 30)")
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
	assert_eq(Inventory.money, 150,
		"Money should only decrement once even after duplicate attempt")


func test_inventory_has_enough_false_when_partial() -> void:
	# Buy only 4 ingredients — below REQUIRED_COUNT (5)
	assert_true(Inventory.buy("scallion", 20))
	assert_true(Inventory.buy("egg", 30))
	assert_true(Inventory.buy("cabbage", 40))
	assert_true(Inventory.buy("chicken", 50))
	assert_false(Inventory.has_enough(),
		"4/5 collected should not satisfy has_enough()")


func test_inventory_has_enough_true_when_threshold_reached() -> void:
	# v0.7: any 5 out of 7 satisfies the win condition. Top up money so the
	# test isn't gated by the new $180 budget — buying 5-of-7 is the focus.
	Inventory.money = 1000
	for id_price in [["scallion", 20], ["egg", 30], ["cabbage", 40],
					 ["chicken", 50], ["tofu", 60]]:
		assert_true(Inventory.buy(id_price[0], id_price[1]),
			"Buy %s should succeed" % id_price[0])
	assert_true(Inventory.has_enough(),
		"5 collected (any of the 7) should satisfy has_enough()")
	assert_true(Inventory.has_all_required(),
		"Legacy alias has_all_required() should match has_enough()")


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


func test_inventory_difficulty_forces_engagement_with_bargain() -> void:
	# v0.7 design: the 5 cheapest ingredients sum to MORE than STARTING_MONEY
	# so a player who never bargains can't just buy all the cheap stuff.
	# (Cheapest 5 of [20,30,40,50,50,60,70] = 190; STARTING_MONEY = 180)
	var prices: Array[int] = [20, 30, 40, 50, 50, 60, 70]
	prices.sort()
	var cheapest_5_total: int = 0
	for i in Inventory.REQUIRED_COUNT:
		cheapest_5_total += prices[i]
	assert_gt(cheapest_5_total, Inventory.STARTING_MONEY,
		"Cheapest %d ingredients (%d) must exceed STARTING_MONEY (%d) so the player must bargain" %
			[Inventory.REQUIRED_COUNT, cheapest_5_total, Inventory.STARTING_MONEY])
	# But not by so much that bargain success can't close the gap.
	# Best bargain: 0.8x on the most expensive of the 5 = roughly 50 → 40 = saves 10.
	assert_lt(cheapest_5_total - Inventory.STARTING_MONEY, 30,
		"Gap between budget and cheap 5 must be closeable with one or two bargains")
