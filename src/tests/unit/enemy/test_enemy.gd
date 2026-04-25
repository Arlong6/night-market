## GUT unit tests for the Enemy patrol system.
## Story 005: Enemy Patrol
##
## Run: godot --headless -s addons/gut/gut_cmdln.gd \
##        -gdir=res://tests/unit -ginclude_subdirs -gexit
extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds an Enemy, adds it to the scene tree, and runs _ready() by
## awaiting one frame. Returns the ready enemy.
func _make_enemy(spawn_x: float = 0.0) -> Enemy:
	var e: Enemy = Enemy.new()
	e.position = Vector2(spawn_x, 0.0)
	add_child_autofree(e)
	await get_tree().process_frame
	return e

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_enemy_moves_horizontally_at_patrol_speed() -> void:
	# Arrange
	var e: Enemy = await _make_enemy(0.0)
	e._direction = 1

	# Act — 1.0 s of simulation: 45 px/s * 1.0 s * dir 1 = 45 px
	e._process(1.0)

	# Assert — within patrol_range=60 so no flip; x = 45
	assert_eq(e.position.x, 45.0,
		"After 1s at speed 45 moving right from origin, x should be 45 — got %s" % e.position.x)


func test_enemy_direction_flips_at_positive_boundary() -> void:
	# Arrange
	var e: Enemy = await _make_enemy(0.0)
	e._direction = 1

	# Act — 2.0 s would travel 90 px, exceeding patrol_range of 60
	e._process(2.0)

	# Assert — x clamped to +60, direction flipped to -1
	assert_eq(e.position.x, 60.0,
		"x should be clamped to +patrol_range (60) — got %s" % e.position.x)
	assert_eq(e._direction, -1,
		"Direction should flip to -1 after hitting positive boundary")


func test_enemy_direction_flips_at_negative_boundary() -> void:
	# Arrange
	var e: Enemy = await _make_enemy(0.0)
	e._direction = -1

	# Act — 2.0 s would travel -90 px, below -patrol_range of -60
	e._process(2.0)

	# Assert — x clamped to -60, direction flipped to +1
	assert_eq(e.position.x, -60.0,
		"x should be clamped to -patrol_range (-60) — got %s" % e.position.x)
	assert_eq(e._direction, 1,
		"Direction should flip to +1 after hitting negative boundary")


func test_enemy_player_hit_emits_when_player_enters() -> void:
	# Arrange
	var e: Enemy = await _make_enemy()
	watch_signals(e)
	var player: Player = Player.new()
	add_child_autofree(player)

	# Act — direct invocation of the handler (no physics engine needed)
	e._on_body_entered(player)

	# Assert
	assert_signal_emit_count(e, "player_hit", 1,
		"player_hit should emit exactly once when a Player enters")


func test_enemy_player_hit_does_not_emit_for_non_player() -> void:
	# Arrange
	var e: Enemy = await _make_enemy()
	watch_signals(e)
	var other: Node2D = Node2D.new()
	add_child_autofree(other)

	# Act
	e._on_body_entered(other)

	# Assert
	assert_signal_not_emitted(e, "player_hit",
		"player_hit should NOT emit when a non-Player body enters")


func test_enemy_position_clamped_to_boundary_after_flip() -> void:
	# Arrange
	var e: Enemy = await _make_enemy(0.0)
	e._direction = 1

	# Act — multiple frames that would cause overshoot if clamp were missing
	e._process(1.5)
	e._process(0.1)
	e._process(0.1)

	# Assert — x must remain within ±patrol_range at every point
	assert_true(
		e.position.x >= -e.patrol_range and e.position.x <= e.patrol_range,
		"x must stay within patrol_range bounds after multiple frames — got %s" % e.position.x
	)
