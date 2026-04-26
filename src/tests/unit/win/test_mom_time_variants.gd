## GUT unit tests for MomNPC time-tier success lines (v0.2).
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


func _make_mom() -> MomNPC:
	var mom: MomNPC = MomNPC.new()
	mom.cell = Vector2i(3, 11)
	add_child_autofree(mom)
	await get_tree().process_frame
	return mom


func test_mom_fast_time_uses_speed_praise() -> void:
	var mom: MomNPC = await _make_mom()
	var lines: Array[String] = mom._success_lines_for_time(60.0)
	assert_true(lines[0].contains("好快"),
		"<90s should use speed-praise line — got '%s'" % lines[0])


func test_mom_normal_time_uses_thanks() -> void:
	var mom: MomNPC = await _make_mom()
	var lines: Array[String] = mom._success_lines_for_time(150.0)
	assert_true(lines[0].contains("謝謝"),
		"90-240s should use thanks line — got '%s'" % lines[0])


func test_mom_slow_time_uses_teasing() -> void:
	var mom: MomNPC = await _make_mom()
	var lines: Array[String] = mom._success_lines_for_time(400.0)
	assert_true(lines[0].contains("這麼久"),
		">240s should use teasing line — got '%s'" % lines[0])


func test_mom_threshold_boundary_below_fast() -> void:
	var mom: MomNPC = await _make_mom()
	var fast: Array[String] = mom._success_lines_for_time(89.9)
	var normal: Array[String] = mom._success_lines_for_time(90.0)
	assert_ne(fast[0], normal[0],
		"Fast and normal tiers should produce different first lines")
