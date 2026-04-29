## GUT smoke tests for WanderShopper (v0.17).
##
## WanderShopper is pure visual — no game state changes. Tests cover the
## minimum: instantiation, position seeding, and the wrap-around logic.
extends GutTest


func before_each() -> void:
	# Disable test_mode so _process actually integrates motion in this file.
	# (Game.test_mode is reset in after_each; the rest of the suite is safe.)
	Game.test_mode = false


func after_each() -> void:
	Game.test_mode = false


func test_wander_shopper_seeds_position_from_direction() -> void:
	# Arrange
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = 1
	add_child_autofree(s)
	await get_tree().process_frame

	# Assert — direction +1 means start at x_min
	assert_almost_eq(s.position.x, 50.0, 0.5,
		"Right-walking shopper should start at x_min")
	assert_almost_eq(s.position.y, 100.0, 0.001,
		"Shopper should sit at lane_y")


func test_wander_shopper_seeds_position_from_left_direction() -> void:
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = -1
	add_child_autofree(s)
	await get_tree().process_frame
	assert_almost_eq(s.position.x, 150.0, 0.5,
		"Left-walking shopper should start at x_max")


func test_wander_shopper_wraps_at_right_edge() -> void:
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = 1
	s.speed = 100.0
	add_child_autofree(s)
	await get_tree().process_frame

	# Manually push x past x_max, then tick a frame to trigger wrap
	s._x = 200.0
	s._process(0.001)
	assert_almost_eq(s._x, 50.0, 1.0,
		"Should wrap back to x_min after passing x_max — got %s" % s._x)


func test_wander_shopper_wraps_at_left_edge() -> void:
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = -1
	s.speed = 100.0
	add_child_autofree(s)
	await get_tree().process_frame

	s._x = 10.0
	s._process(0.001)
	assert_almost_eq(s._x, 150.0, 1.0,
		"Should wrap back to x_max after passing x_min — got %s" % s._x)


func test_wander_shopper_freezes_in_test_mode() -> void:
	# Test_mode = true means _process is a no-op; useful so unit tests of the
	# market scene aren't time-dependent on shopper motion.
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = 1
	s.speed = 100.0
	add_child_autofree(s)
	await get_tree().process_frame

	Game.test_mode = true
	var x_before: float = s._x
	s._process(1.0)  # under test_mode this should NOT advance _x
	assert_almost_eq(s._x, x_before, 0.001,
		"test_mode should freeze shopper motion")
