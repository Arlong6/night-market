## GUT unit tests for Kitchen mum's CLOSING-stage dialogue (v0.25).
##
## Covers the priority order of `_closing_line_for_time`:
##   1. Incomplete run → "勉強OK啦"
##   2. New-dish unlock → "哇！第一次吃到 X"
##   3. Perfect run → "滿漢全席"
##   4. Single-dish + known-praise → DISH_PRAISE entry
##   5. Time tier fallback (fast / normal / slow)
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	Game.test_mode = true
	Game.last_run_perfect = false
	Game.last_run_incomplete = false
	Game.last_run_new_dishes = PackedStringArray()
	HiScore.clear()
	Inventory.reset()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_kitchen() -> Kitchen:
	var k: Kitchen = Kitchen.new()
	# Don't run the sequence — we only need _closing_line_for_time accessible.
	# Skip _ready by NOT adding to the tree until after we've stubbed.
	k.is_intro = false
	return k


# ---------------------------------------------------------------------------
# Priority order
# ---------------------------------------------------------------------------

func test_closing_incomplete_run_returns_made_do_line() -> void:
	# Arrange
	var k: Kitchen = _make_kitchen()
	Game.last_run_incomplete = true

	# Act
	var line: String = k._closing_line_for_time(60.0)

	# Assert
	assert_true(line.contains("勉強"),
		"incomplete run should yield 勉強 line — got '%s'" % line)
	k.free()


func test_closing_new_dish_unlock_overrides_perfect() -> void:
	# Arrange
	var k: Kitchen = _make_kitchen()
	Game.last_run_perfect = true
	Game.last_run_new_dishes = PackedStringArray(["三杯雞"])

	# Act
	var line: String = k._closing_line_for_time(60.0)

	# Assert
	assert_true(line.contains("第一次"),
		"new dish should override perfect — got '%s'" % line)
	assert_true(line.contains("三杯雞"),
		"line should name the new dish — got '%s'" % line)
	k.free()


func test_closing_multiple_new_dishes_uses_plural_line() -> void:
	# Arrange
	var k: Kitchen = _make_kitchen()
	Game.last_run_new_dishes = PackedStringArray(["三杯雞", "蔥蛋"])

	# Act
	var line: String = k._closing_line_for_time(120.0)

	# Assert
	assert_true(line.contains("三杯雞") and line.contains("蔥蛋"),
		"plural line should mention all new dishes — got '%s'" % line)
	k.free()


func test_closing_perfect_run_returns_full_banquet_line() -> void:
	# Arrange
	var k: Kitchen = _make_kitchen()
	Game.last_run_perfect = true

	# Act
	var line: String = k._closing_line_for_time(120.0)

	# Assert
	assert_true(line.contains("滿漢全席"),
		"perfect run should yield 滿漢全席 — got '%s'" % line)
	k.free()


func test_closing_falls_through_to_time_tier_when_nothing_special() -> void:
	# Arrange: no incomplete, no new dish, no perfect, multi-dish run so
	# dish-specific praise doesn't fire either.
	var k: Kitchen = _make_kitchen()
	# session_time = 60s → fast tier
	# (Inventory.cooked_dishes is empty because Inventory was reset)

	# Act
	var line: String = k._closing_line_for_time(60.0)

	# Assert
	assert_true(line.contains("好快"),
		"fast time tier should yield 好快 — got '%s'" % line)
	k.free()
