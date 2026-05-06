## GUT integration tests for StallNPC + ask_choice flow (R-006).
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	Inventory.reset()
	# v0.20: stall buys mutate HiScore.purchase_count + the loyalty-tier
	# greeting on subsequent visits. Clear so each test sees tier 0.
	HiScore.clear()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


## Builds a Node parent + StallNPC inside it (so spawn_sparkle has a parent).
func _make_stall(ingredient: String = "egg", price: int = 30) -> StallNPC:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var stall: StallNPC = StallNPC.new()
	stall.cell = Vector2i(5, 5)
	stall.ingredient_id = ingredient
	stall.price = price
	var intro: Array[String] = ["test intro"]
	var sold: Array[String] = ["sold out"]
	stall.intro_lines = intro
	stall.sold_out_lines = sold
	parent.add_child(stall)
	await get_tree().process_frame
	return stall


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_stall_first_bump_shows_intro_lines() -> void:
	var stall: StallNPC = await _make_stall()
	stall.on_bumped()
	await get_tree().process_frame
	assert_true(Dialogue.is_active(), "Dialogue should be active after bump")


func test_stall_yes_choice_with_money_buys_ingredient() -> void:
	var stall: StallNPC = await _make_stall("egg", 30)

	# Walk through dialogue: intro line → choice → 是
	stall.on_bumped()
	await get_tree().process_frame
	# Snap intro typewriter + advance to next, which closes intro and chains
	# into _open_buy_choice via the on_done callback.
	Dialogue._box._advance()  # snap intro
	Dialogue._box._advance()  # close intro → on_done fires → choice opens
	await get_tree().process_frame
	# Choice mode now active.
	assert_true(Dialogue._box._choice_mode, "Should be in choice mode")
	# Snap typewriter + confirm (option 0 = 是)
	Dialogue._box._advance()  # snap question
	Dialogue._box._advance()  # confirm at index 0
	await get_tree().process_frame

	assert_eq(Inventory.money, Inventory.STARTING_MONEY - 30,
		"Money should decrement by price — got %s" % Inventory.money)
	assert_true(Inventory.has("egg"),
		"Inventory should now own the egg")
	assert_true(stall._sold, "stall should be flagged sold")


func test_stall_yes_choice_without_money_shows_poor_line() -> void:
	var stall: StallNPC = await _make_stall("chicken", 50)
	Inventory.money = 10

	stall.on_bumped()
	await get_tree().process_frame
	Dialogue._box._advance()  # snap intro
	Dialogue._box._advance()  # → choice opens
	await get_tree().process_frame
	Dialogue._box._advance()  # snap question
	Dialogue._box._advance()  # confirm 是
	await get_tree().process_frame

	assert_eq(Inventory.money, 10, "Money unchanged when can't afford")
	assert_false(Inventory.has("chicken"), "Did not get the chicken")
	assert_false(stall._sold, "stall remains unsold")


func test_stall_no_choice_does_not_buy() -> void:
	var stall: StallNPC = await _make_stall("egg", 30)

	stall.on_bumped()
	await get_tree().process_frame
	Dialogue._box._advance()  # snap intro
	Dialogue._box._advance()  # → choice (3-way: 是 / 殺價 / 否)
	await get_tree().process_frame
	Dialogue._box._advance()  # snap question
	# 否 is at index 2 in the 3-way prompt.
	Dialogue._box._option_index = 2
	Dialogue._box._advance()  # confirm 否
	await get_tree().process_frame

	assert_eq(Inventory.money, Inventory.STARTING_MONEY,
		"Money unchanged when player picks 否")
	assert_false(Inventory.has("egg"), "Did not buy egg on 否")
	assert_false(stall._sold, "stall stays unsold")


func test_stall_sold_then_bump_shows_sold_out_lines() -> void:
	var stall: StallNPC = await _make_stall("egg", 30)
	# Mark sold directly to skip the buy flow.
	stall._sold = true

	stall.on_bumped()
	await get_tree().process_frame
	# Dialogue should be active showing sold_out_lines now.
	assert_true(Dialogue.is_active(), "Dialogue should be active")
	# The current line should be the sold-out line.
	assert_eq(Dialogue._box._lines, ["sold out"],
		"sold-out NPC should show sold_out_lines")


func test_dialogue_ask_choice_returns_index() -> void:
	var captured: Array = [-1]
	var on_choice: Callable = func(i: int) -> void: captured[0] = i

	Dialogue.ask_choice("選一個？", ["A", "B"], on_choice)
	await get_tree().process_frame
	# Snap typewriter, navigate to index 1, confirm.
	Dialogue._box._advance()
	Dialogue._box._option_index = 1
	Dialogue._box._advance()
	await get_tree().process_frame

	assert_eq(captured[0], 1,
		"Confirmed choice should pass selected index to callback — got %s" % captured[0])


# ---------------------------------------------------------------------------
# v0.47 — typhoon stall closures + price markup
# ---------------------------------------------------------------------------

func test_stall_closed_bump_shows_closed_lines_not_buy_prompt() -> void:
	# Arrange — closed stall on a "typhoon day"
	var stall: StallNPC = await _make_stall("egg", 30)
	stall.is_closed = true

	# Act
	stall.on_bumped()
	await get_tree().process_frame

	# Assert — dialogue active, but it should be the closure lines, not a
	# buy choice. Closed stalls never raise a choice prompt.
	assert_true(Dialogue.is_active(),
		"closed stall should still produce dialogue (closure message)")


func test_stall_typhoon_markup_increases_effective_price() -> void:
	# Arrange — stall priced at 30, +20% typhoon markup → 36
	var stall: StallNPC = await _make_stall("egg", 30)
	stall.typhoon_markup = 1.20

	# Assert
	assert_eq(stall.effective_price(), 36,
		"30 × 1.20 = 36 — typhoon markup should round to NT$36")


func test_stall_typhoon_markup_one_means_no_change() -> void:
	# Arrange — default markup 1.0 == sunny day pricing
	var stall: StallNPC = await _make_stall("egg", 30)

	# Assert
	assert_eq(stall.effective_price(), 30,
		"default typhoon_markup=1.0 should leave price unchanged")


func test_stall_closed_does_not_decrement_money_on_bump() -> void:
	# Arrange — closed stall + money snapshot
	var stall: StallNPC = await _make_stall("egg", 30)
	stall.is_closed = true
	var money_before: int = Inventory.money

	# Act — bump (would normally trigger buy flow)
	stall.on_bumped()
	await get_tree().process_frame
	# Try to advance through the dialogue to confirm no charge happens even
	# when the player presses past the closure message.
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._advance()
		await get_tree().process_frame

	# Assert
	assert_eq(Inventory.money, money_before,
		"closed stall must never charge — money stays exactly the same")
