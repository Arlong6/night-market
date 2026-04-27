## GUT unit tests for win condition flow (R-008). BLOCKING — Logic story.
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	Game.test_mode = true
	Game.reset_run()
	Inventory.reset()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_mom() -> MomNPC:
	var mom: MomNPC = MomNPC.new()
	mom.cell = Vector2i(3, 11)
	add_child_autofree(mom)
	await get_tree().process_frame
	return mom


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_mom_bump_with_all_ingredients_triggers_win() -> void:
	# v0.7: STARTING_MONEY=180 is below the 5-cheapest sum, so for this
	# test we top money up to skip the bargain dance and just verify the win flow.
	Inventory.money = 1000
	for id_price in [["scallion", 20], ["egg", 30], ["cabbage", 40],
					 ["chicken", 50], ["soy_sauce", 50]]:
		assert_true(Inventory.buy(id_price[0], id_price[1]))
	assert_true(Inventory.has_all_required(),
		"Pre-condition: 5 collected should satisfy has_all_required")

	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame

	# Mom shows 2 success lines based on session_time bucket; advance 4 times
	# (snap1, next, snap2, close → on_done → goto_level).
	Dialogue._box._advance()  # snap line 1
	Dialogue._box._advance()  # next line
	Dialogue._box._advance()  # snap line 2
	Dialogue._box._advance()  # close + on_done
	await get_tree().process_frame

	assert_eq(Game.current_area, "end_win",
		"goto_level should have been called with 'end_win' — got '%s'" % Game.current_area)


func test_mom_bump_without_all_ingredients_no_level_change() -> void:
	# Buy only 4 of 5
	Inventory.buy("scallion", 20)
	Inventory.buy("egg", 30)
	Inventory.buy("cabbage", 40)
	Inventory.buy("chicken", 50)
	# Soy sauce is missing.
	assert_false(Inventory.has_all_required(),
		"Pre-condition: should NOT have all required")

	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame
	# Walk through both incomplete lines.
	Dialogue._box._advance()  # snap line 1
	Dialogue._box._advance()  # next line
	Dialogue._box._advance()  # snap line 2
	Dialogue._box._advance()  # close (no on_done in incomplete path)
	await get_tree().process_frame

	assert_ne(Game.current_area, "end_win",
		"current_area should NOT be end_win when ingredients incomplete")


func test_mom_bump_incomplete_shows_dialogue() -> void:
	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame
	assert_true(Dialogue.is_active(),
		"Bumping mum with no ingredients should show a dialogue")


func test_session_time_accumulates_during_market() -> void:
	Game.current_area = "shilin"
	Game.session_time = 0.0
	# 4 process steps of 0.5s each = 2.0s
	for i in range(4):
		Game._process(0.5)
	assert_almost_eq(Game.session_time, 2.0, 0.01,
		"session_time should accumulate while in shilin — got %s" % Game.session_time)


func test_session_time_does_not_accumulate_outside_market() -> void:
	Game.current_area = "title"
	Game.session_time = 0.0
	for i in range(4):
		Game._process(0.5)
	assert_almost_eq(Game.session_time, 0.0, 0.01,
		"session_time should not advance outside the market — got %s" % Game.session_time)


func test_reset_run_zeroes_session_time() -> void:
	Game.session_time = 30.0
	Game.current_area = "shilin"
	Game.in_dialogue = true
	Game.reset_run()
	assert_eq(Game.session_time, 0.0)
	assert_eq(Game.current_area, "")
	assert_false(Game.in_dialogue)


func test_goto_level_unknown_key_is_safe() -> void:
	# Should not crash; should not change current_area.
	Game.current_area = "title"
	Game.goto_level("nonexistent")
	assert_eq(Game.current_area, "title",
		"current_area should not change for unknown key")
