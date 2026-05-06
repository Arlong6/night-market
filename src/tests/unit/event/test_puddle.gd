## GUT unit tests for Puddle (v0.44 rain decoration).
##
## Puddle is a pure-visual node; tests cover construction, the test_mode
## freeze (so unit tests of the level scene aren't time-dependent on
## puddle ripple), and the heavy/light flag.
extends GutTest


func before_each() -> void:
	Game.test_mode = true


func after_each() -> void:
	Game.test_mode = false


func test_puddle_construct_and_frame_does_not_crash() -> void:
	# Arrange
	var p: Puddle = Puddle.new()
	p.cell = Vector2i(3, 4)
	add_child_autofree(p)

	# Act
	await get_tree().process_frame

	# Assert
	assert_eq(p.cell, Vector2i(3, 4),
		"cell should round-trip through the @export field")


func test_puddle_heavy_flag_defaults_false() -> void:
	# Arrange
	var p: Puddle = Puddle.new()
	add_child_autofree(p)

	# Assert
	assert_false(p.heavy,
		"heavy should default false so non-typhoon puddles use the light tier")


func test_puddle_freezes_in_test_mode() -> void:
	# Arrange — Game.test_mode is true via before_each.
	var p: Puddle = Puddle.new()
	add_child_autofree(p)
	await get_tree().process_frame
	var t_before: float = p._t

	# Act — simulate one second of process under test_mode.
	p._process(1.0)

	# Assert — _t should NOT have advanced.
	assert_almost_eq(p._t, t_before, 0.001,
		"test_mode should freeze the ripple accumulator")


func test_puddle_advances_ripple_when_test_mode_off() -> void:
	# Arrange
	Game.test_mode = false
	var p: Puddle = Puddle.new()
	add_child_autofree(p)
	await get_tree().process_frame
	var t_before: float = p._t

	# Act — drive _process directly with a known delta.
	p._process(0.5)

	# Assert
	assert_gt(p._t, t_before,
		"ripple accumulator should advance when test_mode is off")
