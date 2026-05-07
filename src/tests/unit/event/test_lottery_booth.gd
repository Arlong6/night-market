## GUT tests for LotteryBooth (v0.52 抽獎攤).
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	HiScore.day = 1
	Inventory.reset()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


func _make_booth() -> LotteryBooth:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var b: LotteryBooth = LotteryBooth.new()
	b.cell = Vector2i(15, 5)
	parent.add_child(b)
	await get_tree().process_frame
	return b


func test_lottery_booth_constructs_without_crash() -> void:
	var b: LotteryBooth = await _make_booth()
	assert_eq(b._draws_used, 0,
		"_draws_used should default to 0 on a fresh booth")


func test_lottery_booth_bump_when_broke_does_not_charge() -> void:
	var b: LotteryBooth = await _make_booth()
	Inventory.money = LotteryBooth.LOTTERY_PRICE - 1
	var before: int = Inventory.money
	b.on_bumped()
	await get_tree().process_frame
	assert_eq(Inventory.money, before,
		"insufficient-funds bump must not deduct money")
	assert_eq(b._draws_used, 0,
		"insufficient-funds bump must not increment _draws_used")


func test_lottery_booth_at_max_draws_does_not_charge() -> void:
	var b: LotteryBooth = await _make_booth()
	b._draws_used = LotteryBooth.MAX_DRAWS
	var before: int = Inventory.money
	b.on_bumped()
	await get_tree().process_frame
	assert_eq(Inventory.money, before,
		"draws-exhausted bump must not deduct money")


func test_lottery_booth_constants_consistent() -> void:
	# Public API contract. Lock these so callers / banner copy can hard-code.
	assert_eq(LotteryBooth.LOTTERY_PRICE, 10,
		"LOTTERY_PRICE should be NT$10")
	assert_eq(LotteryBooth.MAX_DRAWS, 3,
		"MAX_DRAWS should be 3")


func test_lottery_booth_roll_thresholds_strictly_increasing() -> void:
	# Each cumulative threshold must be strictly greater than the prior;
	# otherwise the corresponding bucket has 0% probability.
	assert_true(LotteryBooth.ROLL_LOSE < LotteryBooth.ROLL_BREAK_EVEN,
		"LOSE < BREAK_EVEN")
	assert_true(LotteryBooth.ROLL_BREAK_EVEN < LotteryBooth.ROLL_THIRD,
		"BREAK_EVEN < THIRD")
	assert_true(LotteryBooth.ROLL_THIRD < LotteryBooth.ROLL_SECOND,
		"THIRD < SECOND")
	assert_true(LotteryBooth.ROLL_SECOND < LotteryBooth.ROLL_BONUS,
		"SECOND < BONUS")
	assert_true(LotteryBooth.ROLL_BONUS < 1.0,
		"BONUS < 1.0 so FIRST PRIZE bucket has > 0% probability")


func test_lottery_booth_pick_prize_returns_owned_filtered_id() -> void:
	# Arrange — own everything except "egg"
	var b: LotteryBooth = await _make_booth()
	for id in LotteryBooth.PRIZE_INGREDIENT_POOL:
		if id != "egg":
			Inventory.ingredients[id] = true

	# Act
	var picked: String = b._pick_prize_ingredient()

	# Assert
	assert_eq(picked, "egg",
		"prize picker should return the only un-owned ingredient")


func test_lottery_booth_pick_prize_returns_empty_when_all_owned() -> void:
	# Arrange — own every prize-pool ingredient
	var b: LotteryBooth = await _make_booth()
	for id in LotteryBooth.PRIZE_INGREDIENT_POOL:
		Inventory.ingredients[id] = true

	# Act
	var picked: String = b._pick_prize_ingredient()

	# Assert
	assert_true(picked.is_empty(),
		"prize picker should return '' when every ingredient is already owned")


func test_inventory_grant_ingredient_adds_when_unowned() -> void:
	# Arrange — guarantee not owned
	Inventory.ingredients.erase("egg")

	# Act
	var added: bool = Inventory.grant_ingredient("egg")

	# Assert
	assert_true(added,
		"grant_ingredient should report true when adding a fresh ingredient")
	assert_true(Inventory.has("egg"),
		"egg should now be in the player's inventory")


func test_inventory_grant_ingredient_no_op_when_already_owned() -> void:
	# Arrange — pretend egg is already owned
	Inventory.ingredients["egg"] = true

	# Act
	var added: bool = Inventory.grant_ingredient("egg")

	# Assert
	assert_false(added,
		"grant_ingredient should report false when already owned")
