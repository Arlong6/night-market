## GUT smoke tests for NightMarketCat (v0.36).
##
## NightMarketCat is pure visual (like WanderShopper) but with a 2-state
## walking↔sitting machine. Tests cover instantiation, position seeding,
## state-toggle when its duration elapses, edge wrap-around, and
## test_mode freeze.
extends GutTest


func before_each() -> void:
	Game.test_mode = false


func after_each() -> void:
	Game.test_mode = false


func test_cat_seeds_position_from_right_direction() -> void:
	# Arrange
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 50.0
	c.x_max = 150.0
	c.lane_y = 124.0
	c.direction = 1
	add_child_autofree(c)
	await get_tree().process_frame

	# Assert
	assert_almost_eq(c.position.x, 50.0, 1.5,
		"right-walking cat should start near x_min — got %s" % c.position.x)
	assert_almost_eq(c.position.y, 124.0, 0.001,
		"cat should sit at lane_y")


func test_cat_seeds_position_from_left_direction() -> void:
	# Arrange
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 50.0
	c.x_max = 150.0
	c.lane_y = 124.0
	c.direction = -1
	add_child_autofree(c)
	await get_tree().process_frame

	# Assert
	assert_almost_eq(c.position.x, 150.0, 1.5,
		"left-walking cat should start near x_max — got %s" % c.position.x)


func test_cat_walks_horizontally_when_in_walking_state() -> void:
	# Arrange — cat in WALKING state by construction.
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 0.0
	c.x_max = 200.0
	c.lane_y = 124.0
	c.direction = 1
	add_child_autofree(c)
	await get_tree().process_frame
	c._state = NightMarketCat.State.WALKING
	c._x = 100.0
	c._state_t = 0.0
	c._state_duration = 999.0  # don't auto-toggle this tick
	# Act
	c._process(0.5)
	# Assert
	assert_gt(c._x, 100.0,
		"WALKING cat should advance _x — went %s" % c._x)


func test_cat_does_not_walk_when_sitting() -> void:
	# Arrange
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 0.0
	c.x_max = 200.0
	c.lane_y = 124.0
	c.direction = 1
	add_child_autofree(c)
	await get_tree().process_frame
	c._state = NightMarketCat.State.SITTING
	c._x = 100.0
	c._state_t = 0.0
	c._state_duration = 999.0  # don't auto-toggle this tick
	# Act
	c._process(0.5)
	# Assert
	assert_almost_eq(c._x, 100.0, 0.001,
		"SITTING cat must not advance _x — got %s" % c._x)


func test_cat_toggles_state_after_state_duration_elapses() -> void:
	# Arrange
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 0.0
	c.x_max = 200.0
	c.lane_y = 124.0
	c.direction = 1
	add_child_autofree(c)
	await get_tree().process_frame
	c._state = NightMarketCat.State.WALKING
	c._state_t = 0.0
	c._state_duration = 0.1  # short
	# Act — push past the duration in one tick
	c._process(0.5)
	# Assert
	assert_eq(c._state, NightMarketCat.State.SITTING,
		"cat should switch to SITTING after walking duration elapses")


func test_cat_wraps_at_right_edge() -> void:
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 50.0
	c.x_max = 150.0
	c.lane_y = 124.0
	c.direction = 1
	add_child_autofree(c)
	await get_tree().process_frame
	c._state = NightMarketCat.State.WALKING
	c._state_t = 0.0
	c._state_duration = 999.0
	# Manually push x past x_max, then tick a frame to trigger wrap
	c._x = 200.0
	c._process(0.001)
	assert_almost_eq(c._x, 50.0, 1.0,
		"cat should wrap to x_min after passing x_max — got %s" % c._x)


func test_cat_freezes_in_test_mode() -> void:
	var c: NightMarketCat = NightMarketCat.new()
	c.x_min = 50.0
	c.x_max = 150.0
	c.lane_y = 124.0
	c.direction = 1
	add_child_autofree(c)
	await get_tree().process_frame

	Game.test_mode = true
	c._state = NightMarketCat.State.WALKING
	var x_before: float = c._x
	c._process(2.0)
	assert_almost_eq(c._x, x_before, 0.001,
		"test_mode should freeze cat motion")
