## GUT unit tests for Inventory autoload (R-005). BLOCKING — Logic story.
extends GutTest


## Inventory is an autoload that persists across tests; each test resets.
## v0.13: reset() now randomises required_ingredients; tests that need a
## specific list assign it manually after reset (see explicit overrides
## below).
## v0.19: pin HiScore.day = 1 (週一 / 家常日 / size 5) so randomization tests
## get the expected list size by default.
func before_each() -> void:
	HiScore.day = 1
	# v0.35 / v0.40: zero the queued bonuses so each test starts from a
	# clean slate; Inventory.reset() consumes both pending values.
	HiScore.pending_dream_bonus = 0
	HiScore.pending_special_bonus = 0
	Inventory.last_dream_bonus = 0
	Inventory.last_special_bonus = 0
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


# ---------------------------------------------------------------------------
# v0.15 — recipe / dish matching
# ---------------------------------------------------------------------------

func test_inventory_cooked_dishes_empty_when_nothing_owned() -> void:
	# Fresh inventory — no ingredients, no dishes
	assert_eq(Inventory.cooked_dishes().size(), 0,
		"cooked_dishes() should be empty when no ingredients are owned")


func test_inventory_cooked_dishes_matches_simple_pair() -> void:
	Inventory.money = 1000
	Inventory.buy("chicken", 50)
	Inventory.buy("soy_sauce", 50)
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	assert_true("醬油雞" in dishes,
		"chicken + soy_sauce should produce 醬油雞 — got %s" % str(dishes))


func test_inventory_cooked_dishes_orders_by_recipe_priority() -> void:
	# RECIPES is ordered with 三杯雞 (the showpiece) first. When the
	# ingredients support both 三杯雞 (chicken+soy+scallion) and 醬油雞
	# (chicken+soy), the showpiece should appear first.
	Inventory.money = 1000
	Inventory.buy("chicken", 50)
	Inventory.buy("soy_sauce", 50)
	Inventory.buy("scallion", 20)
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	assert_eq(dishes[0], "三杯雞",
		"Showpiece dish should appear first when its ingredients are owned")


func test_inventory_cooked_dishes_caps_at_max_displayed() -> void:
	# Owning every ingredient should match every recipe (7) — but the
	# returned list must respect MAX_DISHES_DISPLAYED so end-screen text
	# doesn't overflow.
	Inventory.money = 10000
	for id in Inventory.ALL_INGREDIENTS:
		Inventory.buy(id, 10)
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	assert_eq(dishes.size(), Inventory.MAX_DISHES_DISPLAYED,
		"Perfect run should be capped at MAX_DISHES_DISPLAYED dishes")


func test_inventory_cooked_dishes_skips_recipes_with_missing_ingredient() -> void:
	# 蔥蛋 needs scallion + egg. Owning only scallion should NOT match it.
	Inventory.money = 1000
	Inventory.buy("scallion", 20)
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	assert_false("蔥蛋" in dishes,
		"蔥蛋 should not match when egg is missing — got %s" % str(dishes))


func test_inventory_cooked_dishes_solo_ingredient_recipes_match() -> void:
	# 清炒高麗菜 needs only cabbage; owning just cabbage should match it.
	Inventory.money = 1000
	Inventory.buy("cabbage", 40)
	var dishes: PackedStringArray = Inventory.cooked_dishes()
	assert_true("清炒高麗菜" in dishes,
		"清炒高麗菜 should match with just cabbage — got %s" % str(dishes))


# ---------------------------------------------------------------------------
# v0.19 — daily themes / calendar rotation
# ---------------------------------------------------------------------------

func test_inventory_current_theme_day_1_is_monday() -> void:
	HiScore.day = 1
	var theme: Dictionary = Inventory.current_theme()
	assert_eq(theme["key"], "monday",
		"day 1 should map to 週一 / 家常日 — got %s" % theme["key"])


func test_inventory_current_theme_cycles_every_7_days() -> void:
	HiScore.day = 8
	var theme: Dictionary = Inventory.current_theme()
	assert_eq(theme["key"], "monday",
		"day 8 should cycle back to Monday — got %s" % theme["key"])
	HiScore.day = 14
	theme = Inventory.current_theme()
	assert_eq(theme["key"], "sunday",
		"day 14 should be Sunday — got %s" % theme["key"])


# ---------------------------------------------------------------------------
# v0.31 — weekend mode
# ---------------------------------------------------------------------------

func test_inventory_is_weekend_false_on_weekdays() -> void:
	# Mon..Fri = days 1..5 in the rotating week — none should be weekends.
	for d in [1, 2, 3, 4, 5]:
		HiScore.day = d
		assert_false(Inventory.is_weekend(),
			"day %d (%s) should NOT be weekend"
			% [d, Inventory.current_theme()["key"]])


func test_inventory_is_weekend_true_on_saturday_and_sunday() -> void:
	# Day 6 = Sat, Day 7 = Sun.
	HiScore.day = 6
	assert_true(Inventory.is_weekend(),
		"day 6 (Sat) should be weekend — theme key %s"
		% Inventory.current_theme()["key"])
	HiScore.day = 7
	assert_true(Inventory.is_weekend(),
		"day 7 (Sun) should be weekend — theme key %s"
		% Inventory.current_theme()["key"])


func test_inventory_is_weekend_cycles_every_week() -> void:
	# Weekend semantics must hold across week boundaries — day 13 (Sat
	# of week 2) must still be a weekend.
	HiScore.day = 13
	assert_true(Inventory.is_weekend(),
		"day 13 (Sat of week 2) should be weekend")
	HiScore.day = 15  # Mon of week 3
	assert_false(Inventory.is_weekend(),
		"day 15 (Mon of week 3) should NOT be weekend")


func test_inventory_soup_day_forces_tofu_and_cabbage() -> void:
	HiScore.day = 2  # 週二 湯品日 — forces tofu + cabbage
	# Run randomize many times; every result must contain both forced items.
	for _i in 20:
		Inventory.randomize_required()
		assert_true("tofu" in Inventory.required_ingredients,
			"湯品日 must always include tofu — got %s" %
				str(Inventory.required_ingredients))
		assert_true("cabbage" in Inventory.required_ingredients,
			"湯品日 must always include cabbage — got %s" %
				str(Inventory.required_ingredients))
		assert_eq(Inventory.required_ingredients.size(), 5,
			"湯品日 list size should be 5")


func test_inventory_friday_theme_has_smaller_list() -> void:
	HiScore.day = 5  # 週五 樸素日 — only 3 items
	Inventory.randomize_required()
	assert_eq(Inventory.required_ingredients.size(), 3,
		"樸素日 should generate a 3-item list — got %s" %
			str(Inventory.required_ingredients))


func test_inventory_sunday_theme_requires_all_seven() -> void:
	HiScore.day = 7  # 週日 滿漢日 — all 7
	Inventory.randomize_required()
	assert_eq(Inventory.required_ingredients.size(), 7,
		"滿漢日 should generate a 7-item list — got %s" %
			str(Inventory.required_ingredients))
	# Should equal ALL_INGREDIENTS as a set
	for id in Inventory.ALL_INGREDIENTS:
		assert_true(id in Inventory.required_ingredients,
			"滿漢日 must include every ingredient (%s missing)" % id)


func test_inventory_thursday_theme_forces_chicken_and_soy() -> void:
	HiScore.day = 4  # 週四 雞肉日
	for _i in 10:
		Inventory.randomize_required()
		assert_true("chicken" in Inventory.required_ingredients,
			"雞肉日 must include chicken")
		assert_true("soy_sauce" in Inventory.required_ingredients,
			"雞肉日 must include soy_sauce")


# ---------------------------------------------------------------------------
# v0.23 — festivals (special days inside the 30-day cycle)
# ---------------------------------------------------------------------------

func test_inventory_no_festival_on_normal_day() -> void:
	HiScore.day = 1
	assert_eq(Inventory.current_festival(), Inventory.FESTIVAL_NONE)
	assert_eq(Inventory.festival_bonus(), 0)


func test_inventory_mid_autumn_festival_fires_on_day_15() -> void:
	HiScore.day = 15
	assert_eq(Inventory.current_festival(), Inventory.FESTIVAL_MID_AUTUMN)
	assert_eq(Inventory.festival_bonus(), Inventory.FESTIVAL_BONUS_MID_AUTUMN)
	assert_false(Inventory.festival_label().is_empty(),
		"festival_label should be non-empty on a festival day")


func test_inventory_new_year_festival_fires_on_day_30() -> void:
	HiScore.day = 30
	assert_eq(Inventory.current_festival(), Inventory.FESTIVAL_NEW_YEAR)
	assert_eq(Inventory.festival_bonus(), Inventory.FESTIVAL_BONUS_NEW_YEAR)


func test_inventory_festivals_repeat_on_30_day_cycle() -> void:
	HiScore.day = 45  # day 15 of the 2nd month
	assert_eq(Inventory.current_festival(), Inventory.FESTIVAL_MID_AUTUMN,
		"中秋 should fire again on day 45")
	HiScore.day = 60  # day 30 of the 2nd month
	assert_eq(Inventory.current_festival(), Inventory.FESTIVAL_NEW_YEAR,
		"過年 should fire again on day 60")


func test_inventory_reset_applies_festival_bonus_to_money() -> void:
	HiScore.day = 30  # 過年 day
	Inventory.reset()
	assert_eq(Inventory.money,
		Inventory.STARTING_MONEY + Inventory.FESTIVAL_BONUS_NEW_YEAR,
		"reset on 過年 should add the red-envelope bonus to STARTING_MONEY")


# ---------------------------------------------------------------------------
# v0.35 — 夢境餘韻 dream bonus
# ---------------------------------------------------------------------------

func test_inventory_reset_applies_pending_dream_bonus_to_money() -> void:
	# Arrange — queue a 100 NT$ dream bonus on a normal weekday (no festival).
	HiScore.day = 1
	HiScore.pending_dream_bonus = HiScore.DREAM_BONUS_PER_CLEAR

	# Act
	Inventory.reset()

	# Assert
	assert_eq(Inventory.money,
		Inventory.STARTING_MONEY + HiScore.DREAM_BONUS_PER_CLEAR,
		"reset should stack the queued dream bonus on top of STARTING_MONEY")
	assert_eq(Inventory.last_dream_bonus, HiScore.DREAM_BONUS_PER_CLEAR,
		"reset should store the bonus amount on Inventory.last_dream_bonus")
	assert_eq(HiScore.pending_dream_bonus, 0,
		"reset should consume (zero) HiScore.pending_dream_bonus")


func test_inventory_reset_dream_bonus_stacks_with_festival_bonus() -> void:
	# Arrange — 過年 day AND a queued boss-clear bonus.
	HiScore.day = 30
	HiScore.pending_dream_bonus = HiScore.DREAM_BONUS_PER_CLEAR

	# Act
	Inventory.reset()

	# Assert
	assert_eq(Inventory.money,
		Inventory.STARTING_MONEY
			+ Inventory.FESTIVAL_BONUS_NEW_YEAR
			+ HiScore.DREAM_BONUS_PER_CLEAR,
		"festival + dream bonuses should both add to starting money")


func test_inventory_reset_with_no_pending_bonus_leaves_last_dream_bonus_zero() -> void:
	# Arrange — already done in before_each (pending=0).

	# Act
	Inventory.reset()

	# Assert
	assert_eq(Inventory.last_dream_bonus, 0,
		"with no queued bonus, reset should leave last_dream_bonus at 0")
	assert_eq(Inventory.money, Inventory.STARTING_MONEY,
		"weekday with no bonus should equal STARTING_MONEY exactly")


# ---------------------------------------------------------------------------
# v0.40 — 媽媽特別交代 (special requests)
# ---------------------------------------------------------------------------

func test_inventory_special_request_none_on_regular_weekday() -> void:
	# Arrange — day 1 is cycle 0 (none of the special-request days).
	HiScore.day = 1
	# Act / Assert
	assert_eq(Inventory.current_special_request(),
		Inventory.SPECIAL_REQUEST_NONE,
		"day 1 should have no special request")
	assert_eq(Inventory.special_request_bonus(), 0,
		"no request → 0 bonus")


func test_inventory_special_request_dad_birthday_on_day_3() -> void:
	# Arrange — (3-1) % 7 = 2 → DAD_BIRTHDAY
	HiScore.day = 3
	# Act / Assert
	assert_eq(Inventory.current_special_request(),
		Inventory.SPECIAL_REQUEST_DAD_BIRTHDAY,
		"day 3 should fire 爸爸生日")
	assert_eq(Inventory.special_request_bonus(),
		Inventory.SPECIAL_REQUEST_BONUS_DAD_BIRTHDAY,
		"day 3 bonus should be DAD_BIRTHDAY value")


func test_inventory_special_request_guest_dinner_on_day_6() -> void:
	HiScore.day = 6
	assert_eq(Inventory.current_special_request(),
		Inventory.SPECIAL_REQUEST_GUEST_DINNER,
		"day 6 should fire 客人晚餐")
	assert_eq(Inventory.special_request_bonus(),
		Inventory.SPECIAL_REQUEST_BONUS_GUEST_DINNER)


func test_inventory_special_request_repeats_on_7_day_cycle() -> void:
	# Day 10 = (10-1) % 7 = 2 → DAD_BIRTHDAY again
	HiScore.day = 10
	assert_eq(Inventory.current_special_request(),
		Inventory.SPECIAL_REQUEST_DAD_BIRTHDAY,
		"day 10 should fire DAD_BIRTHDAY again (7-day cycle)")
	# Day 13 = (13-1) % 7 = 5 → GUEST_DINNER again
	HiScore.day = 13
	assert_eq(Inventory.current_special_request(),
		Inventory.SPECIAL_REQUEST_GUEST_DINNER,
		"day 13 should fire GUEST_DINNER again")


func test_inventory_festival_overrides_special_request() -> void:
	# Day 30 is 過年 (festival cycle 29) AND would otherwise be cycle (30-1)%7=1
	# so no conflict by accident. Force the conflict by checking day 15 which
	# is mid-autumn AND (15-1)%7 = 0 (also no conflict). Try day 45 = mid-autumn,
	# (45-1)%7 = 2 → would have been DAD_BIRTHDAY without festival override.
	HiScore.day = 45
	assert_ne(Inventory.current_festival(), Inventory.FESTIVAL_NONE,
		"pre-condition: day 45 must be a festival day")
	assert_eq(Inventory.current_special_request(),
		Inventory.SPECIAL_REQUEST_NONE,
		"festival days must suppress special-request firing")


func test_inventory_randomize_required_uses_special_override() -> void:
	# Arrange — day 3, DAD_BIRTHDAY → required list should be the override.
	HiScore.day = 3
	# Act
	Inventory.randomize_required()
	# Assert
	var expected_arr: Array = Inventory.SPECIAL_REQUEST_REQUIRED[
		Inventory.SPECIAL_REQUEST_DAD_BIRTHDAY]
	var expected: PackedStringArray = PackedStringArray()
	for id in expected_arr:
		expected.append(String(id))
	assert_eq(Inventory.required_ingredients, expected,
		"DAD_BIRTHDAY day should override required list — got %s"
		% str(Inventory.required_ingredients))


func test_inventory_special_request_complete_requires_all_override_items() -> void:
	# Arrange — day 3 (DAD_BIRTHDAY), buy 3 of the 4 required.
	HiScore.day = 3
	Inventory.reset()
	Inventory.buy("chicken", 0)
	Inventory.buy("scallion", 0)
	Inventory.buy("soy_sauce", 0)
	# Act / Assert
	assert_false(Inventory.special_request_complete(),
		"missing one ingredient → request not complete")
	# Buy the last one
	Inventory.buy("egg", 0)
	assert_true(Inventory.special_request_complete(),
		"all 4 ingredients bought → request complete")


func test_inventory_reset_applies_special_bonus_to_money() -> void:
	# Arrange — queue a special-request bonus.
	HiScore.day = 1  # weekday, no festival, no special
	HiScore.pending_special_bonus = Inventory.SPECIAL_REQUEST_BONUS_DAD_BIRTHDAY
	# Act
	Inventory.reset()
	# Assert
	assert_eq(Inventory.money, Inventory.STARTING_MONEY
		+ Inventory.SPECIAL_REQUEST_BONUS_DAD_BIRTHDAY,
		"queued special bonus should add to STARTING_MONEY on reset")
	assert_eq(Inventory.last_special_bonus,
		Inventory.SPECIAL_REQUEST_BONUS_DAD_BIRTHDAY,
		"last_special_bonus should mirror the consumed amount")
	assert_eq(HiScore.pending_special_bonus, 0,
		"reset should zero the pending special bonus")
