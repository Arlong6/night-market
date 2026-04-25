## GUT unit tests for the Collectible pickup system.
## Story 003: Collectible System
##
## Requires: GUT addon at res://addons/gut/
## Run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds a Collectible, adds it to the scene tree, and runs _ready() by
## awaiting one frame. Returns the ready collectible.
func _make_collectible(spawn_y: float = 100.0) -> Collectible:
	var c: Collectible = Collectible.new()
	c.position = Vector2(0.0, spawn_y)
	add_child_autofree(c)
	await get_tree().process_frame
	return c

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_collectible_picked_up_signal_emits_once_when_player_enters() -> void:
	# Arrange
	var c: Collectible = await _make_collectible()
	watch_signals(c)
	var player: Player = Player.new()
	add_child_autofree(player)

	# Act
	c._on_body_entered(player)

	# Assert
	assert_signal_emit_count(c, "picked_up", 1,
		"picked_up should emit exactly once when a Player enters")


func test_collectible_signal_carries_default_points_value() -> void:
	# Arrange — default 100
	var c: Collectible = await _make_collectible()
	watch_signals(c)
	var player: Player = Player.new()
	add_child_autofree(player)

	# Act
	c._on_body_entered(player)

	# Assert
	var params: Array = get_signal_parameters(c, "picked_up", 0)
	assert_not_null(params, "Signal emit record should exist")
	if params != null:
		assert_eq(params[0], 100,
			"Default points value should be 100 — got %s" % params[0])


func test_collectible_signal_carries_custom_points_value() -> void:
	# Arrange — custom value 250
	var c: Collectible = Collectible.new()
	c.points = 250
	add_child_autofree(c)
	await get_tree().process_frame
	watch_signals(c)
	var player: Player = Player.new()
	add_child_autofree(player)

	# Act
	c._on_body_entered(player)

	# Assert
	var params: Array = get_signal_parameters(c, "picked_up", 0)
	assert_not_null(params, "Signal emit record should exist")
	if params != null:
		assert_eq(params[0], 250,
			"Custom points value should be 250 — got %s" % params[0])


func test_collectible_queue_free_called_after_pickup() -> void:
	# Arrange
	var c: Collectible = await _make_collectible()
	var player: Player = Player.new()
	add_child_autofree(player)

	# Act
	c._on_body_entered(player)
	await get_tree().process_frame  # queue_free is deferred

	# Assert
	assert_false(is_instance_valid(c),
		"Collectible should be freed after pickup")


func test_collectible_enemy_body_does_not_trigger_pickup() -> void:
	# Arrange
	var c: Collectible = await _make_collectible()
	watch_signals(c)
	var non_player: Node2D = Node2D.new()
	add_child_autofree(non_player)

	# Act
	c._on_body_entered(non_player)

	# Assert
	assert_signal_not_emitted(c, "picked_up",
		"picked_up should NOT emit when a non-Player body enters")
	assert_true(is_instance_valid(c),
		"Collectible should still exist after a non-Player enters")


func test_collectible_bob_oscillation_alternates_y() -> void:
	# Arrange
	var c: Collectible = await _make_collectible(100.0)

	# Act: first phase (0..0.25s) — phase index 0 → y = base_y - 2
	c._process(0.10)
	var y_phase_0: float = c.position.y

	# Advance past the phase boundary into phase 1 (0.25s+)
	c._process(0.20)
	var y_phase_1: float = c.position.y

	# Assert
	assert_almost_eq(y_phase_0, c._base_y - 2.0, 0.01,
		"Phase 0: position.y should be base_y - 2 (got %s)" % y_phase_0)
	assert_almost_eq(y_phase_1, c._base_y, 0.01,
		"Phase 1: position.y should be base_y (got %s)" % y_phase_1)


func test_collectible_base_y_captured_from_spawn_position() -> void:
	# Arrange — set a non-zero spawn y before adding to tree
	var c: Collectible = Collectible.new()
	c.position = Vector2(0.0, 75.0)
	add_child_autofree(c)
	await get_tree().process_frame  # _ready runs here

	# Assert
	assert_almost_eq(c._base_y, 75.0, 0.01,
		"_base_y should be captured from spawn position (expected 75, got %s)" % c._base_y)
