## GUT integration tests for Dialogue autoload + DialogueBox (R-004).
extends GutTest


## Resets Dialogue + Game state before AND after each test (autoloads persist
## across files so we must clean up explicitly to avoid leaking state).
func _reset_dialogue() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false


func before_each() -> void:
	_reset_dialogue()


func after_each() -> void:
	_reset_dialogue()


func test_dialogue_show_locks_game_in_dialogue() -> void:
	var ok: bool = Dialogue.show(["你好！"])
	await get_tree().process_frame
	assert_true(ok, "First show should succeed")
	assert_true(Game.in_dialogue, "Game.in_dialogue should be true while active")
	assert_true(Dialogue.is_active(), "Dialogue.is_active() should be true")


func test_dialogue_show_when_active_returns_false() -> void:
	assert_true(Dialogue.show(["第一句"]))
	await get_tree().process_frame
	assert_false(Dialogue.show(["不該被收"]),
		"Re-entrant show() should return false while active")


func test_dialogue_typewriter_advances_visible_chars_over_time() -> void:
	var line := "你好今天買什麼"  # 7 chars
	assert_true(Dialogue.show([line]))
	await get_tree().process_frame
	# Wait long enough for typewriter to advance but not finish.
	# At 30 chars/sec, 0.10s reveals 3 chars.
	await get_tree().create_timer(0.10).timeout
	var n: int = Dialogue._box.current_visible_chars()
	assert_true(n > 0, "Should have revealed some chars — got %s" % n)
	assert_true(n < line.length(),
		"Should not have revealed all — got %s of %s" % [n, line.length()])


func test_dialogue_advances_to_next_line_and_finishes() -> void:
	var done_called: Array[bool] = [false]
	var on_done: Callable = func() -> void: done_called[0] = true
	assert_true(Dialogue.show(["A", "B"], on_done))
	await get_tree().process_frame

	# Wait for typewriter to fill line 1, then advance.
	await get_tree().create_timer(0.10).timeout
	Dialogue._box._advance()  # snap to full line 1
	Dialogue._box._advance()  # next line
	assert_eq(Dialogue._box.current_line_index(), 1,
		"Should be on second line — got %s" % Dialogue._box.current_line_index())

	await get_tree().create_timer(0.10).timeout
	Dialogue._box._advance()  # snap line 2
	Dialogue._box._advance()  # close
	await get_tree().process_frame

	assert_false(Dialogue.is_active(), "Dialogue should be closed")
	assert_false(Game.in_dialogue, "Game.in_dialogue should reset")
	assert_true(done_called[0], "on_done callable should have been invoked")


func test_dialogue_advance_skips_typewriter() -> void:
	var line := "AAAAAAAAAA"  # 10 chars
	assert_true(Dialogue.show([line]))
	await get_tree().process_frame

	# Immediately advance — typewriter at ~0 chars; advance should snap to full.
	Dialogue._box._advance()
	await get_tree().process_frame
	assert_eq(Dialogue._box.current_visible_chars(), line.length(),
		"Advance during typing should snap to full line — got %s" %
			Dialogue._box.current_visible_chars())
