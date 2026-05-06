## GUT unit tests for WindOverlay (v0.45 typhoon leaves).
##
## WindOverlay is pure visual. Tests cover: construction, leaf seeding,
## test_mode freeze, and direction defaulting.
extends GutTest


func before_each() -> void:
	Game.test_mode = false


func after_each() -> void:
	Game.test_mode = false


func test_wind_overlay_seeds_leaves() -> void:
	# Arrange / Act
	var w: WindOverlay = WindOverlay.new()
	add_child_autofree(w)
	await get_tree().process_frame

	# Assert
	assert_eq(w._leaves.size(), WindOverlay.LEAF_COUNT,
		"should spawn LEAF_COUNT leaves on _ready")


func test_wind_overlay_default_direction_is_right() -> void:
	# Arrange
	var w: WindOverlay = WindOverlay.new()

	# Assert — default field value is +1 (right)
	assert_eq(w.direction, 1,
		"default wind direction should be +1 (right) for backward compat")


func test_wind_overlay_freezes_in_test_mode() -> void:
	# Arrange
	var w: WindOverlay = WindOverlay.new()
	add_child_autofree(w)
	await get_tree().process_frame
	Game.test_mode = true
	var t_before: float = w._t

	# Act
	w._process(1.0)

	# Assert
	assert_almost_eq(w._t, t_before, 0.001,
		"test_mode should freeze leaf integration")


func test_wind_overlay_advances_when_test_mode_off() -> void:
	# Arrange
	var w: WindOverlay = WindOverlay.new()
	add_child_autofree(w)
	await get_tree().process_frame
	var t_before: float = w._t

	# Act
	w._process(0.5)

	# Assert
	assert_gt(w._t, t_before,
		"_t should advance when test_mode is off")
