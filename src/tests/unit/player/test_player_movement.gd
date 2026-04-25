## GUT unit tests for Player movement logic.
## Story 002: Player Controller (run + jump + duck)
##
## Requires: GUT addon at res://addons/gut/
## Run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
extends GutTest

# ---------------------------------------------------------------------------
# Constants for test world
# ---------------------------------------------------------------------------

const PLAYER_X: float = 200.0
## Floor top sits at this y; player feet land here after warmup.
const FLOOR_TOP_Y: float = 120.0
const FLOOR_CENTRE_Y: float = 140.0  # top_y + half_height
const FLOOR_HALF_H: float = 20.0

# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

## Creates a StaticBody2D floor with top at FLOOR_TOP_Y and x-span 0..400.
func _spawn_floor() -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(400.0, FLOOR_HALF_H * 2.0)
	cs.shape = rect
	body.add_child(cs)
	body.position = Vector2(PLAYER_X, FLOOR_CENTRE_Y)
	add_child_autofree(body)
	return body


## Creates a ceiling low enough to block standing after a duck.
## Standing top = FLOOR_TOP_Y - STAND_H = 80. Ceiling bottom at y=82 blocks it.
func _spawn_ceiling_above_standing() -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(60.0, 4.0)
	cs.shape = rect
	body.add_child(cs)
	# Centre y=84, half-h=2 → bottom y=82, top y=86
	body.position = Vector2(PLAYER_X, 84.0)
	add_child_autofree(body)
	return body


## Creates a grounded player: real floor + player on it + physics warmup
## so is_on_floor() returns true and coyote_timer is refreshed.
func _make_grounded_player() -> Player:
	_spawn_floor()
	var p: Player = Player.new()
	add_child_autofree(p)
	# Spawn embedded 1px into the floor — move_and_slide pushes back up to
	# the floor top within one frame and is_on_floor() latches true.
	p.position = Vector2(PLAYER_X, FLOOR_TOP_Y + 1.0)
	# Warmup frames for physics state to stabilize
	for i in range(6):
		await get_tree().physics_frame
	return p


## Creates an airborne player: NO floor, player simply exists in empty space.
## Coyote timer can be set manually by the test after creation.
func _make_airborne_player() -> Player:
	var p: Player = Player.new()
	add_child_autofree(p)
	p.position = Vector2(PLAYER_X, 50.0)
	await get_tree().physics_frame
	p.velocity = Vector2.ZERO
	return p


## Gets the Player's CollisionShape2D.
func _get_shape(p: Player) -> CollisionShape2D:
	for child in p.get_children():
		if child is CollisionShape2D:
			return child
	return null

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_horizontal_movement_symmetric() -> void:
	var player: Player = await _make_grounded_player()

	Input.action_press("move_right")
	await get_tree().physics_frame
	var vx_right: float = player.velocity.x
	Input.action_release("move_right")
	await get_tree().physics_frame

	Input.action_press("move_left")
	await get_tree().physics_frame
	var vx_left: float = player.velocity.x
	Input.action_release("move_left")

	assert_almost_eq(vx_right, Player.MOVE_SPEED, 1.0,
		"move_right velocity should equal MOVE_SPEED")
	assert_almost_eq(vx_left, -Player.MOVE_SPEED, 1.0,
		"move_left velocity should equal -MOVE_SPEED")
	assert_almost_eq(absf(vx_right), absf(vx_left), 1.0,
		"Left and right velocities should have equal magnitude")


func test_jump_on_ground_applies_jump_velocity() -> void:
	var player: Player = await _make_grounded_player()

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")

	assert_almost_eq(player.velocity.y, Player.JUMP_VELOCITY, 2.0,
		"Jump while grounded should apply JUMP_VELOCITY — got vy=%s" % player.velocity.y)


func test_jump_cut_halves_upward_velocity_on_release() -> void:
	var player: Player = await _make_grounded_player()

	Input.action_press("jump")
	await get_tree().physics_frame  # jump fires, vy = JUMP_VELOCITY
	Input.action_release("jump")
	await get_tree().physics_frame  # cut fires on this frame; gravity adds ~13

	# Expected: vy ≈ (JUMP_VELOCITY * 0.5) + gravity_delta ≈ -112
	assert_true(player.velocity.y < 0.0,
		"Velocity.y should still be upward (negative) after jump-cut — got vy=%s" % player.velocity.y)
	assert_true(player.velocity.y > Player.JUMP_VELOCITY * 0.75,
		"Jump-cut should noticeably reduce upward velocity (got vy=%s, full jump is %s)" % [player.velocity.y, Player.JUMP_VELOCITY])
	assert_true(player.velocity.y < Player.JUMP_VELOCITY * 0.2,
		"Jump-cut should not leave vy near zero — got vy=%s" % player.velocity.y)


func test_coyote_time_allows_jump_after_leaving_ground() -> void:
	var player: Player = await _make_airborne_player()
	player._coyote_timer = 0.08  # within window

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")

	assert_almost_eq(player.velocity.y, Player.JUMP_VELOCITY, 20.0,
		"Jump within coyote window should fire — got vy=%s" % player.velocity.y)


func test_coyote_time_expires_after_100ms() -> void:
	var player: Player = await _make_airborne_player()
	player._coyote_timer = 0.0

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")

	assert_true(player.velocity.y > Player.JUMP_VELOCITY + 100.0,
		"Jump after coyote expiry should NOT produce full jump — got vy=%s" % player.velocity.y)
	assert_true(player.velocity.y >= 0.0,
		"Velocity should be 0 or falling, not upward — got vy=%s" % player.velocity.y)


func test_jump_buffer_queues_jump_before_landing() -> void:
	var player: Player = await _make_airborne_player()
	player._coyote_timer = 0.0

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")

	assert_true(player._jump_buffer_timer > 0.0,
		"Jump buffer should be active — got %s" % player._jump_buffer_timer)
	assert_true(player.velocity.y >= 0.0,
		"Jump should not fire with coyote=0 — got vy=%s" % player.velocity.y)

	# Simulate landing
	player._coyote_timer = Player.COYOTE_TIME
	await get_tree().physics_frame

	assert_almost_eq(player.velocity.y, Player.JUMP_VELOCITY, 20.0,
		"Buffered jump should fire on landing — got vy=%s" % player.velocity.y)


func test_duck_halves_height_preserves_feet() -> void:
	var player: Player = await _make_grounded_player()
	var feet_y_before: float = player.position.y

	Input.action_press("duck")
	await get_tree().physics_frame

	var shape: CollisionShape2D = _get_shape(player)
	var rect: RectangleShape2D = shape.shape as RectangleShape2D

	assert_true(player.is_ducking(), "Player should be ducking after press")
	assert_almost_eq(rect.size.y, Player.DUCK_H, 0.01,
		"Collision height should be DUCK_H — got %s" % rect.size.y)
	assert_almost_eq(player.position.y, feet_y_before, 1.0,
		"Feet world-y preserved (before=%s, after=%s)" % [feet_y_before, player.position.y])

	Input.action_release("duck")


func test_duck_auto_stand_when_clear() -> void:
	var player: Player = await _make_grounded_player()

	Input.action_press("duck")
	await get_tree().physics_frame
	assert_true(player.is_ducking(), "Pre-condition: player ducking")

	Input.action_release("duck")
	await get_tree().physics_frame

	assert_false(player.is_ducking(), "Player should auto-stand when clear")

	var shape: CollisionShape2D = _get_shape(player)
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	assert_almost_eq(rect.size.y, Player.STAND_H, 0.01,
		"Collision height should return to STAND_H — got %s" % rect.size.y)


func test_duck_auto_stand_blocked_when_ceiling() -> void:
	var player: Player = await _make_grounded_player()
	_spawn_ceiling_above_standing()
	await get_tree().physics_frame  # let ceiling register in physics

	Input.action_press("duck")
	await get_tree().physics_frame
	assert_true(player.is_ducking(), "Pre-condition: player ducking")

	Input.action_release("duck")
	await get_tree().physics_frame

	assert_true(player.is_ducking(),
		"Player should remain ducked when ceiling blocks auto-stand")

	var shape: CollisionShape2D = _get_shape(player)
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	assert_almost_eq(rect.size.y, Player.DUCK_H, 0.01,
		"Collision height should remain DUCK_H — got %s" % rect.size.y)


func test_cannot_jump_while_ducking() -> void:
	var player: Player = await _make_grounded_player()

	Input.action_press("duck")
	await get_tree().physics_frame
	assert_true(player.is_ducking(), "Pre-condition: player ducking")

	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("duck")

	assert_true(player.velocity.y > Player.JUMP_VELOCITY + 100.0,
		"Jump while ducking should not produce upward velocity — got vy=%s" % player.velocity.y)


func test_duck_reduces_horizontal_speed() -> void:
	var player: Player = await _make_grounded_player()

	Input.action_press("duck")
	Input.action_press("move_right")
	await get_tree().physics_frame
	var ducked_vx: float = player.velocity.x
	Input.action_release("duck")
	Input.action_release("move_right")

	var expected: float = Player.MOVE_SPEED * Player.DUCK_MOVE_MULT
	assert_almost_eq(ducked_vx, expected, 1.0,
		"Ducked speed should be MOVE_SPEED * DUCK_MOVE_MULT (%s) — got %s" % [expected, ducked_vx])


func test_died_signal_emits_when_fallen_off_world() -> void:
	var player: Player = await _make_airborne_player()
	watch_signals(player)

	player.position = Vector2(160.0, 250.0)
	await get_tree().physics_frame

	assert_signal_emitted(player, "died",
		"'died' signal should emit when position.y > 240")
