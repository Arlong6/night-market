## GUT unit tests for Inventory autoload (R-005). BLOCKING — Logic story.
extends GutTest


## Inventory is an autoload that persists across tests; each test resets.
func before_each() -> void:
	Inventory.reset()


func test_inventory_starts_with_starting_money() -> void:
	assert_eq(Inventory.money, Inventory.STARTING_MONEY,
		"Money should start at STARTING_MONEY (200)")


func test_inventory_starts_empty() -> void:
	assert_eq(Inventory.ingredient_count(), 0,
		"No ingredients should be collected at start")


func test_inventory_can_afford_when_money_sufficient() -> void:
	assert_true(Inventory.can_afford(50), "200 >= 50 should be affordable")
	assert_true(Inventory.can_afford(200), "200 >= 200 should be affordable (boundary)")


func test_inventory_cannot_afford_when_money_insufficient() -> void:
	Inventory.money = 10
	assert_false(Inventory.can_afford(50), "10 < 50 should not be affordable")
	assert_false(Inventory.can_afford(11), "10 < 11 should not be affordable (boundary)")


func test_inventory_buy_succeeds_when_affordable_and_new() -> void:
	var ok: bool = Inventory.buy("egg", 30)
	assert_true(ok, "buy should succeed when affordable + new")
	assert_eq(Inventory.money, 170, "Money should decrement by price")
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
	assert_eq(Inventory.money, 170,
		"Money should only decrement once even after duplicate attempt")


func test_inventory_has_all_required_false_when_partial() -> void:
	# Buy 4 of 5 required
	assert_true(Inventory.buy("scallion", 20))
	assert_true(Inventory.buy("egg", 30))
	assert_true(Inventory.buy("cabbage", 40))
	assert_true(Inventory.buy("chicken", 50))
	assert_false(Inventory.has_all_required(),
		"4/5 collected should not satisfy has_all_required")


func test_inventory_has_all_required_true_when_complete() -> void:
	for id_price in [["scallion", 20], ["egg", 30], ["cabbage", 40],
					 ["chicken", 50], ["soy_sauce", 50]]:
		assert_true(Inventory.buy(id_price[0], id_price[1]),
			"Buy %s should succeed" % id_price[0])
	assert_true(Inventory.has_all_required(),
		"All 5 collected should satisfy has_all_required")


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


func test_inventory_total_required_prices_within_starting_money() -> void:
	# Sanity: the 5 required ingredients sum should be ≤ STARTING_MONEY
	# so a player who never wastes money can win.
	var prices: Dictionary = {
		"scallion": 20, "egg": 30, "cabbage": 40,
		"chicken": 50, "soy_sauce": 50,
	}
	var total: int = 0
	for id in Inventory.REQUIRED_INGREDIENTS:
		total += prices.get(id, 0)
	assert_true(total <= Inventory.STARTING_MONEY,
		"Total required ingredient prices (%s) must be ≤ STARTING_MONEY (%s)" %
			[total, Inventory.STARTING_MONEY])
