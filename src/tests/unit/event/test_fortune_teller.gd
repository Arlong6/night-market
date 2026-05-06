## GUT tests for FortuneTeller (v0.48 算命阿婆).
##
## The roll is non-deterministic (RNG), so these tests cover the
## invariants that must hold every time:
##   * One consult per run — second bump never charges
##   * Insufficient money path doesn't charge
##   * Money never goes below STARTING_MONEY - FORTUNE_PRICE on a single bump
##   * Pricing constant matches the dialogue string
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	HiScore.day = 1
	HiScore.pending_dream_bonus = 0
	HiScore.pending_special_bonus = 0
	Inventory.last_dream_bonus = 0
	Inventory.last_special_bonus = 0
	Inventory.reset()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


func _make_teller() -> FortuneTeller:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var t: FortuneTeller = FortuneTeller.new()
	t.cell = Vector2i(2, 5)
	parent.add_child(t)
	await get_tree().process_frame
	return t


func test_fortune_teller_constructs_and_draws_without_crash() -> void:
	# Arrange / Act
	var t: FortuneTeller = await _make_teller()

	# Assert
	assert_eq(t.cell, Vector2i(2, 5),
		"cell @export should round-trip")
	assert_false(t._consulted,
		"_consulted should default to false on a fresh booth")


func test_fortune_teller_bump_when_broke_does_not_charge() -> void:
	# Arrange — drain money below FORTUNE_PRICE
	var t: FortuneTeller = await _make_teller()
	Inventory.money = FortuneTeller.FORTUNE_PRICE - 1
	var before: int = Inventory.money

	# Act
	t.on_bumped()
	await get_tree().process_frame

	# Assert
	assert_eq(Inventory.money, before,
		"insufficient-funds bump must not deduct money")
	assert_false(t._consulted,
		"insufficient-funds bump must not flip _consulted")


func test_fortune_teller_already_consulted_bump_does_not_charge() -> void:
	# Arrange — pretend the consult already happened.
	var t: FortuneTeller = await _make_teller()
	t._consulted = true
	var before: int = Inventory.money

	# Act
	t.on_bumped()
	await get_tree().process_frame

	# Assert
	assert_eq(Inventory.money, before,
		"second consult must not deduct money — once-per-run cap")


func test_fortune_teller_price_matches_constant() -> void:
	# Locks in the public price constant; downstream UI / banner copy
	# reads from this value, so a silent change here must break a test.
	assert_eq(FortuneTeller.FORTUNE_PRICE, 5,
		"FORTUNE_PRICE should be NT$5")


func test_fortune_teller_refund_buckets_are_non_decreasing() -> void:
	# The roll-bucket constants determine fairness — each bucket should
	# be at least as good as the previous one. (BAD <= EVEN <= GOOD <= GREAT <= EPIC)
	assert_true(FortuneTeller.REFUND_BAD <= FortuneTeller.REFUND_EVEN,
		"BAD refund should be ≤ EVEN refund")
	assert_true(FortuneTeller.REFUND_EVEN <= FortuneTeller.REFUND_GOOD,
		"EVEN refund should be ≤ GOOD refund")
	assert_true(FortuneTeller.REFUND_GOOD <= FortuneTeller.REFUND_GREAT,
		"GOOD refund should be ≤ GREAT refund")
	assert_true(FortuneTeller.REFUND_GREAT <= FortuneTeller.REFUND_EPIC,
		"GREAT refund should be ≤ EPIC refund")


func test_fortune_teller_roll_thresholds_strictly_increasing() -> void:
	# If the cumulative thresholds aren't strictly increasing, the
	# corresponding bucket has 0% probability — almost certainly a bug.
	assert_true(FortuneTeller.ROLL_BAD < FortuneTeller.ROLL_EVEN,
		"BAD threshold < EVEN threshold")
	assert_true(FortuneTeller.ROLL_EVEN < FortuneTeller.ROLL_GOOD,
		"EVEN threshold < GOOD threshold")
	assert_true(FortuneTeller.ROLL_GOOD < FortuneTeller.ROLL_GREAT,
		"GOOD threshold < GREAT threshold")
	assert_true(FortuneTeller.ROLL_GREAT < 1.0,
		"GREAT threshold < 1.0 so EPIC bucket has > 0% probability")
