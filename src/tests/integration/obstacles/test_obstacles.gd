## GUT integration tests for Story 004: Static Obstacles.
## Tests verify real physics interactions between Player and ObstacleGround /
## ObstacleHanging. Uses the grounded-player-with-warmup pattern from Story 002.
##
## Run with:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##     -gdir=res://tests/integration -ginclude_subdirs -gexit
extends GutTest

# ---------------------------------------------------------------------------
# World constants — must match test_player_movement.gd to share floor layout
# ---------------------------------------------------------------------------

const FLOOR_TOP_Y: float = 120.0
const FLOOR_CENTRE_Y: float = 140.0
const FLOOR_HALF_H: float = 20.0
const FLOOR_WIDTH: float = 600.0

const PLAYER_START_X: float = 100.0
const OBSTACLE_X: float = 200.0

# ---------------------------------------------------------------------------
# Setup helpers
# ---------------------------------------------------------------------------

func _spawn_floor() -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(FLOOR_WIDTH, FLOOR_HALF_H * 2.0)
	cs.shape = rect
	body.add_child(cs)
	body.position = Vector2(FLOOR_WIDTH / 2.0, FLOOR_CENTRE_Y)
	add_child_autofree(body)
	return body


func _make_grounded_player_at(x: float) -> Player:
	_spawn_floor()
	var p: Player = Player.new()
	add_child_autofree(p)
	p.position = Vector2(x, FLOOR_TOP_Y + 1.0)
	for _i in range(6):
		await get_tree().physics_frame
	return p


func _spawn_ground_obstacle(w: float = 24.0, h: float = 24.0) -> ObstacleGround:
	var obs: ObstacleGround = ObstacleGround.new()
	obs.width = w
	obs.height = h
	obs.position = Vector2(OBSTACLE_X, FLOOR_TOP_Y)
	add_child_autofree(obs)
	await get_tree().physics_frame
	return obs


func _spawn_hanging_obstacle() -> ObstacleHanging:
	var obs: ObstacleHanging = ObstacleHanging.new()
	obs.sign_width = 40.0
	obs.sign_height = 20.0
	obs.top_y = 78.0
	obs.position.x = OBSTACLE_X
	add_child_autofree(obs)
	await get_tree().physics_frame
	return obs

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_ground_obstacle_blocks_player_horizontally() -> void:
	var obs: ObstacleGround = await _spawn_ground_obstacle()
	var player: Player = await _make_grounded_player_at(PLAYER_START_X)

	Input.action_press("move_right")
	for _i in range(15):
		await get_tree().physics_frame
	Input.action_release("move_right")
	await get_tree().physics_frame

	var player_right: float = player.position.x + Player.PLAYER_W / 2.0
	var obs_left: float = obs.position.x - obs.width / 2.0
	assert_true(
		player_right <= obs_left + 2.0,
		"Player right edge (%s) should not pass obstacle left edge (%s)" % [player_right, obs_left]
	)
	assert_almost_eq(player.velocity.x, 0.0, 5.0,
		"Horizontal velocity should be near 0 — got %s" % player.velocity.x)


func test_player_jump_clears_24_tall_ground_obstacle() -> void:
	var obs: ObstacleGround = await _spawn_ground_obstacle(24.0, 24.0)
	var start_x: float = obs.position.x - 30.0
	var player: Player = await _make_grounded_player_at(start_x)

	# Hold jump throughout the traversal so jump-cut doesn't halve the arc
	# (jump-cut fires on release while rising — see Story 002 fix).
	Input.action_press("jump")
	Input.action_press("move_right")
	for _i in range(60):
		await get_tree().physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")

	var obs_right: float = obs.position.x + obs.width / 2.0
	assert_true(
		player.position.x > obs_right,
		"Player (x=%s) should pass obstacle right edge (x=%s) after jump" % [player.position.x, obs_right]
	)


func test_standing_player_blocked_by_hanging_obstacle() -> void:
	var obs: ObstacleHanging = await _spawn_hanging_obstacle()
	var player: Player = await _make_grounded_player_at(PLAYER_START_X)

	Input.action_press("move_right")
	for _i in range(20):
		await get_tree().physics_frame
	Input.action_release("move_right")
	await get_tree().physics_frame

	var player_right: float = player.position.x + Player.PLAYER_W / 2.0
	var obs_left: float = obs.position.x - obs.sign_width / 2.0
	assert_true(
		player_right <= obs_left + 2.0,
		"Standing player right edge (%s) should not pass hanging obstacle left edge (%s)" % [player_right, obs_left]
	)
	assert_almost_eq(player.velocity.x, 0.0, 5.0,
		"Horizontal velocity should be near 0 — got %s" % player.velocity.x)


func test_ducking_player_passes_under_hanging_obstacle() -> void:
	var obs: ObstacleHanging = await _spawn_hanging_obstacle()
	var player: Player = await _make_grounded_player_at(PLAYER_START_X)

	# Need ~130 frames: ducking speed 110*0.6 = 66 px/s; travel ~140px
	# from PLAYER_START_X=100 past OBSTACLE_X+20=220.
	Input.action_press("duck")
	await get_tree().physics_frame
	Input.action_press("move_right")
	for _i in range(140):
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("duck")

	var obs_right: float = obs.position.x + obs.sign_width / 2.0
	assert_true(
		player.position.x > obs_right,
		"Ducking player (x=%s) should pass past hanging obstacle right (x=%s)" % [player.position.x, obs_right]
	)


func test_ducking_player_forced_to_stay_ducked_under_hanging() -> void:
	var obs: ObstacleHanging = await _spawn_hanging_obstacle()
	var player: Player = await _make_grounded_player_at(obs.position.x)

	Input.action_press("duck")
	for _i in range(3):
		await get_tree().physics_frame
	assert_true(player.is_ducking(), "Pre-condition: player must be ducking")

	Input.action_release("duck")
	for _i in range(3):
		await get_tree().physics_frame

	assert_true(
		player.is_ducking(),
		"Player should remain ducked when hanging obstacle blocks auto-stand"
	)
	Input.action_release("duck")
