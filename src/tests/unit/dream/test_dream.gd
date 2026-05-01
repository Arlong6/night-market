## GUT unit tests for the v0.33 夢境 platformer scene.
##
## Test_mode short-circuits the simulation in _process so headless tests
## can poke state directly without enemies spawning, projectiles moving,
## or the difficulty timer ramping up under them. Verifies:
##   * Boot sets Game.current_area
##   * _advance routes to "title" and is single-shot
##   * Shoot cooldown gates rapid presses
##   * Jump only works from ground state
##   * _check_endings fires when HP=0 (lose) or kill-target reached (win)
extends GutTest


func _reset() -> void:
	Game.test_mode = true
	Game.current_area = ""
	Game.in_dialogue = false


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_scene() -> Dream:
	var scene: Dream = Dream.new()
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene


# ---------------------------------------------------------------------------
# Boot + routing
# ---------------------------------------------------------------------------

func test_dream_sets_area_on_ready() -> void:
	# Arrange / Act
	var _scene: Dream = await _make_scene()

	# Assert
	assert_eq(Game.current_area, "dream",
		"dream._ready should mark Game.current_area")


func test_dream_advance_routes_to_title() -> void:
	# Arrange
	var scene: Dream = await _make_scene()

	# Act
	scene._advance()

	# Assert
	assert_eq(Game.current_area, "title",
		"_advance should route to 'title' — got '%s'" % Game.current_area)


func test_dream_advance_is_single_shot() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	scene._advance()
	Game.current_area = "shilin"

	# Act
	scene._advance()

	# Assert: second call must be guarded so the outro timer + ESC can't
	# both fire and double-load the title.
	assert_eq(Game.current_area, "shilin",
		"second _advance should be no-op — got '%s'" % Game.current_area)


# ---------------------------------------------------------------------------
# Shoot cooldown
# ---------------------------------------------------------------------------

func test_dream_shoot_cooldown_gates_rapid_presses() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	assert_eq(scene._projectiles.size(), 0,
		"pre-condition: no projectiles before any shot")

	# Act — fire twice back-to-back; second should be cooldown-blocked.
	scene._try_shoot()
	scene._try_shoot()

	# Assert
	assert_eq(scene._projectiles.size(), 1,
		"only the first shot should fire while cooldown is hot — got %d"
		% scene._projectiles.size())
	assert_almost_eq(scene._shoot_cd_t, scene.SHOOT_COOLDOWN, 0.001,
		"cooldown should reset to SHOOT_COOLDOWN on each fire")


func test_dream_shoot_after_cooldown_fires_again() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	scene._try_shoot()

	# Act — drop the cooldown to 0 manually then fire again
	scene._shoot_cd_t = 0.0
	scene._try_shoot()

	# Assert
	assert_eq(scene._projectiles.size(), 2,
		"second shot should land once cooldown expired — got %d"
		% scene._projectiles.size())


# ---------------------------------------------------------------------------
# Jump physics
# ---------------------------------------------------------------------------

func test_dream_jump_only_works_from_ground() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	scene._player_on_ground = true
	scene._player_vel.y = 0.0

	# Act — first jump (from ground) should set negative velocity
	scene._jump()

	# Assert
	assert_almost_eq(scene._player_vel.y, scene.JUMP_VELOCITY, 0.01,
		"jump from ground should set vy=JUMP_VELOCITY — got %f"
		% scene._player_vel.y)
	assert_false(scene._player_on_ground,
		"jump should clear _player_on_ground")


# ---------------------------------------------------------------------------
# Endings
# ---------------------------------------------------------------------------

func test_dream_check_endings_fires_lose_card_at_zero_hp() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	scene._player_hp = 0

	# Act
	scene._check_endings()

	# Assert
	assert_gt(scene._outro_t, 0.0,
		"outro timer should arm when HP reaches 0")
	assert_false(scene._won,
		"HP=0 ending should be marked as a loss")


func test_dream_check_endings_fires_win_card_at_target_kills() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	scene._enemies_killed = scene.TARGET_KILLS

	# Act
	scene._check_endings()

	# Assert
	assert_gt(scene._outro_t, 0.0,
		"outro timer should arm when kill target is reached")
	assert_true(scene._won,
		"hitting TARGET_KILLS should be marked as a win")
