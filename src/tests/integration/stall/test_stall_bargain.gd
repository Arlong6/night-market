## GUT integration tests for the bargain mini-game + discount system (v0.2).
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	# v0.22: bargain now spawns an interactive meter — under test_mode the
	# stall falls back to the legacy randf path so existing assertions still
	# work without simulating cursor timing.
	Game.test_mode = true
	Inventory.reset()
	HiScore.clear()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_stall(price: int = 50) -> StallNPC:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var stall: StallNPC = StallNPC.new()
	stall.cell = Vector2i(5, 5)
	stall.ingredient_id = "egg"
	stall.price = price
	var intro: Array[String] = ["test"]
	stall.intro_lines = intro
	parent.add_child(stall)
	await get_tree().process_frame
	return stall


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_stall_effective_price_full_at_default_discount() -> void:
	var stall: StallNPC = await _make_stall(50)
	assert_eq(stall.effective_price(), 50,
		"discount=1.0 should mean effective_price == price")


func test_stall_effective_price_applies_discount() -> void:
	var stall: StallNPC = await _make_stall(50)
	stall.discount = 0.8
	assert_eq(stall.effective_price(), 40,
		"discount=0.8 on price=50 should give 40")


func test_stall_effective_price_rounds_to_int() -> void:
	var stall: StallNPC = await _make_stall(33)
	stall.discount = 0.5
	assert_eq(stall.effective_price(), 17,
		"33 * 0.5 = 16.5 → rounds to 17")


func test_stall_bargain_flips_bargained_flag() -> void:
	var stall: StallNPC = await _make_stall(50)
	assert_false(stall._bargained, "Pre-condition: not bargained")
	stall._start_bargain()
	await get_tree().process_frame
	assert_true(stall._bargained,
		"_bargained should be true after _start_bargain()")


func test_stall_bargain_changes_discount() -> void:
	var stall: StallNPC = await _make_stall(50)
	var before: float = stall.discount
	stall._start_bargain()
	await get_tree().process_frame
	# Either success (-20%) or failure (+10%) — discount changes either way.
	assert_ne(stall.discount, before,
		"discount should change after a bargain — was %s, now %s" %
			[before, stall.discount])


func test_stall_buy_uses_effective_price_not_base_price() -> void:
	var stall: StallNPC = await _make_stall(50)
	stall.discount = 0.8  # 50 → 40
	stall._attempt_buy()
	await get_tree().process_frame
	# Snap + close the success "好喔，多謝！" line.
	if Dialogue.is_active():
		Dialogue._box._advance()
		Dialogue._box._advance()
	await get_tree().process_frame
	assert_eq(Inventory.money, Inventory.STARTING_MONEY - 40,
		"Buy should deduct effective_price (40) not base price (50)")
	assert_true(Inventory.has("egg"))
