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
	# v0.12: mom.on_bumped() now writes to HiScore via record_run; clear so
	# wins from one test don't leak counters into the next.
	HiScore.clear()


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


## v0.14.1: bumping mum opens a "煮嗎？" choice prompt before the cook flow.
## Test helper that walks past the prompt by selecting `option_index`.
## option_index 0 = 是 (commit), 1 = 否 (cancel).
func _confirm_mom_choice(option_index: int) -> void:
	# Snap the typewriter so the option list is visible
	Dialogue._box._advance()
	# Pick the requested option (default _option_index is 0 = 是)
	Dialogue._box._option_index = option_index
	# Confirm
	Dialogue._box._advance()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_mom_bump_with_all_ingredients_triggers_win() -> void:
	# v0.13: pin the required list so we can deterministically buy ALL of it.
	Inventory.money = 1000
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "soy_sauce"
	])
	for id_price in [["scallion", 20], ["egg", 30], ["cabbage", 40],
					 ["chicken", 50], ["soy_sauce", 50]]:
		assert_true(Inventory.buy(id_price[0], id_price[1]))
	assert_true(Inventory.has_all_required(),
		"Pre-condition: every required ingredient owned")

	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame
	# v0.14.1: confirm the "回家煮嗎？" prompt with 是.
	await _confirm_mom_choice(0)

	# Mom shows 2 success lines based on session_time bucket; advance 4 times
	# (snap1, next, snap2, close → on_done → goto_level).
	Dialogue._box._advance()  # snap line 1
	Dialogue._box._advance()  # next line
	Dialogue._box._advance()  # snap line 2
	Dialogue._box._advance()  # close + on_done
	await get_tree().process_frame

	# v0.8: win path now routes through the kitchen cutscene first.
	assert_eq(Game.current_area, "kitchen",
		"goto_level should route to 'kitchen' on win — got '%s'" % Game.current_area)


func test_mom_bump_without_all_ingredients_routes_to_kitchen_messy() -> void:
	# v0.14: incomplete runs no longer block — kid still cooks, but the run
	# is flagged incomplete and HiScore is NOT touched.
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "soy_sauce"
	])
	# Buy only 4 of 5
	Inventory.buy("scallion", 20)
	Inventory.buy("egg", 30)
	Inventory.buy("cabbage", 40)
	Inventory.buy("chicken", 50)
	assert_false(Inventory.has_all_required(),
		"Pre-condition: should NOT have all required")

	var wins_before: int = HiScore.total_wins
	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame
	# v0.14.1: confirm the "現在就回家嗎？" prompt with 是.
	await _confirm_mom_choice(0)
	# Walk through the 2 incomplete lines (snap1, next, snap2, close + on_done).
	Dialogue._box._advance()
	Dialogue._box._advance()
	Dialogue._box._advance()
	Dialogue._box._advance()
	await get_tree().process_frame

	assert_eq(Game.current_area, "kitchen",
		"v0.14: incomplete runs still cook — should route to 'kitchen', got '%s'" % Game.current_area)
	assert_true(Game.last_run_incomplete,
		"last_run_incomplete should be set so kitchen + end_screen pick the messy variant")
	assert_eq(HiScore.total_wins, wins_before,
		"Incomplete runs must NOT touch HiScore.total_wins")
	assert_false(Game.last_run_was_record,
		"Incomplete runs cannot set last_run_was_record")


func test_mom_bump_incomplete_shows_dialogue() -> void:
	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame
	assert_true(Dialogue.is_active(),
		"Bumping mum with no ingredients should show a dialogue")


func test_mom_bump_choice_no_keeps_player_in_market() -> void:
	# v0.14.1: selecting 否 at the "回家煮嗎？" prompt should NOT change the
	# scene and should NOT mutate any run flags. Player keeps shopping.
	Inventory.required_ingredients = PackedStringArray([
		"scallion", "egg", "cabbage", "chicken", "soy_sauce"
	])
	# Set up an arbitrary "in market" current_area so we can detect a change.
	Game.current_area = "shilin"

	var mom: MomNPC = await _make_mom()
	mom.on_bumped()
	await get_tree().process_frame
	# Confirm the "現在就回家嗎？" prompt with 否 (index 1).
	await _confirm_mom_choice(1)

	assert_eq(Game.current_area, "shilin",
		"Choosing 否 should NOT route away from the market — got '%s'" % Game.current_area)
	assert_false(Game.last_run_incomplete,
		"Choosing 否 should NOT flip last_run_incomplete")
	assert_false(Dialogue.is_active(),
		"Dialogue should be closed after the cancel choice")


func test_mom_bump_complete_clears_incomplete_flag() -> void:
	# Ensure the incomplete flag from a prior aborted run can't bleed into a
	# successful one — Game.reset_run() should clear it, and a complete bump
	# never sets it back.
	Game.last_run_incomplete = true
	Game.reset_run()
	Inventory.reset()
	assert_false(Game.last_run_incomplete,
		"reset_run() should clear last_run_incomplete")


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
