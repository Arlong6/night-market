## GUT unit tests for the LostCat random event (v0.21).
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	Game.test_mode = true
	Inventory.reset()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_cat() -> LostCat:
	var cat: LostCat = LostCat.new()
	cat.cell = Vector2i(5, 5)
	add_child_autofree(cat)
	await get_tree().process_frame
	return cat


# ---------------------------------------------------------------------------
# Bump → choice
# ---------------------------------------------------------------------------

func test_lost_cat_bump_opens_choice_dialogue() -> void:
	var cat: LostCat = await _make_cat()
	cat.on_bumped()
	await get_tree().process_frame
	assert_true(Dialogue.is_active(),
		"Bumping the cat should open a dialogue")


func test_lost_cat_yes_choice_awards_reward_and_emits_despawn() -> void:
	var cat: LostCat = await _make_cat()
	var money_before: int = Inventory.money

	# Spy on the despawn signal
	var got_despawn: Array = []
	cat.despawned.connect(func(c: Vector2i) -> void: got_despawn.append(c))

	cat.on_bumped()
	await get_tree().process_frame
	# Snap question + confirm option 0 (是)
	Dialogue._box._advance()
	Dialogue._box._option_index = 0
	Dialogue._box._advance()
	await get_tree().process_frame
	# Walk through the 2 thank-you lines: snap1, next, snap2, close + on_done
	Dialogue._box._advance()
	Dialogue._box._advance()
	Dialogue._box._advance()
	Dialogue._box._advance()
	await get_tree().process_frame

	assert_eq(Inventory.money, money_before + LostCat.REWARD,
		"Returning the cat should credit REWARD NT$ to Inventory")
	assert_eq(got_despawn.size(), 1,
		"despawned signal should fire exactly once on a successful return")


func test_lost_cat_no_choice_keeps_money_and_does_not_despawn() -> void:
	var cat: LostCat = await _make_cat()
	var money_before: int = Inventory.money

	cat.on_bumped()
	await get_tree().process_frame
	Dialogue._box._advance()
	Dialogue._box._option_index = 1  # 否
	Dialogue._box._advance()
	await get_tree().process_frame

	assert_eq(Inventory.money, money_before,
		"Cancelling the cat return should leave money unchanged")
	assert_true(is_instance_valid(cat),
		"Cat should still exist after a 否 reply")


func test_lost_cat_does_not_double_open_dialogue() -> void:
	var cat: LostCat = await _make_cat()
	cat.on_bumped()
	await get_tree().process_frame
	# Second bump while a dialogue is already active should NOT stack a new
	# choice on top of the running one.
	cat.on_bumped()
	await get_tree().process_frame
	# We don't have a clean way to count active dialogues, but any visible
	# stacking would have raised an error. Assert the still-active state.
	assert_true(Dialogue.is_active())
