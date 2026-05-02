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
	# v0.34: dream now writes to HiScore on _advance — wipe so any persisted
	# state from a previous run can't leak into assertions.
	HiScore.clear()


func after_each() -> void:
	_reset()
	Game.test_mode = false
	HiScore.clear()


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


func test_dream_check_endings_fires_win_card_on_boss_defeat() -> void:
	# Arrange — v0.34 makes the boss the canonical big-win path. Killing N
	# small fries no longer ends the run; defeating 夜市大魔王 does.
	var scene: Dream = await _make_scene()
	scene._boss_defeated = true

	# Act
	scene._check_endings()

	# Assert
	assert_gt(scene._outro_t, 0.0,
		"outro timer should arm when boss is defeated")
	assert_true(scene._won,
		"boss defeat should be a win")


# ---------------------------------------------------------------------------
# Floating platforms (v0.34)
# ---------------------------------------------------------------------------

func test_dream_platform_lands_player_on_cross_from_above() -> void:
	# Arrange — position the player just above the first platform with a
	# downward velocity so this frame's integration crosses the top edge.
	# PLATFORMS[0] is at x=56,y=110,w=40 → centred at x=76.
	var scene: Dream = await _make_scene()
	scene._player_pos = Vector2(76.0, 109.5)
	scene._player_vel = Vector2(0.0, 60.0)
	scene._player_on_ground = false

	# Act — one tick of physics
	scene._step_player(0.1)

	# Assert
	assert_almost_eq(scene._player_pos.y, 110.0, 0.01,
		"player should snap to platform top y=110 — got %f"
		% scene._player_pos.y)
	assert_almost_eq(scene._player_vel.y, 0.0, 0.01,
		"vy should zero on landing — got %f" % scene._player_vel.y)
	assert_true(scene._player_on_ground,
		"_player_on_ground should be true after platform landing")


func test_dream_platform_passes_through_when_jumping_up() -> void:
	# Arrange — player rising through the platform from below; vy is
	# negative so the one-way platform check must skip and leave the player
	# in the air.
	var scene: Dream = await _make_scene()
	scene._player_pos = Vector2(76.0, 112.0)
	scene._player_vel = Vector2(0.0, -200.0)
	scene._player_on_ground = false

	# Act
	scene._step_player(0.1)

	# Assert: player has moved upward through the platform plane (y < 110)
	# without snapping.
	assert_lt(scene._player_pos.y, 110.0,
		"jumping up should pass through platform — got y=%f"
		% scene._player_pos.y)
	assert_false(scene._player_on_ground,
		"player should still be airborne after passing through platform")


# ---------------------------------------------------------------------------
# 章魚燒 hopper enemy (v0.34)
# ---------------------------------------------------------------------------

func test_dream_tako_takes_two_hits_to_kill() -> void:
	# Arrange — manual tako entry sitting in front of a manual projectile.
	var scene: Dream = await _make_scene()
	scene._enemies = [{
		"pos": Vector2(160.0, 137.5),
		"hp": scene.TAKO_HP,
		"kind": "tako",
		"vel": Vector2.ZERO,
		"hop_cd_t": 0.0,
		"grounded": true,
	}]
	scene._projectiles = [{
		"pos": Vector2(160.0, 137.5),
		"vel": Vector2(scene.PROJECTILE_SPEED, 0.0),
		"age": 0.0,
	}]

	# Act — first hit knocks 1 hp; tako should still be alive.
	scene._step_projectiles(0.0)

	# Assert
	assert_eq(scene._enemies[0]["hp"], scene.TAKO_HP - 1,
		"first projectile should reduce tako hp by 1 — got %d"
		% scene._enemies[0]["hp"])
	assert_eq(scene._enemies_killed, 0,
		"kill counter should not advance until hp reaches 0")


func test_dream_tako_launches_hop_on_cooldown_expiry() -> void:
	# Arrange — grounded tako with hop_cd_t already at 0 should launch on
	# its next physics step.
	var scene: Dream = await _make_scene()
	scene._player_pos = Vector2(220.0, 142.0)  ## player to the right
	var tako: Dictionary = {
		"pos": Vector2(80.0, 137.5),
		"hp": scene.TAKO_HP,
		"kind": "tako",
		"vel": Vector2.ZERO,
		"hop_cd_t": 0.0,
		"grounded": true,
	}
	scene._enemies = [tako]

	# Act
	scene._step_enemies(0.016)

	# Assert
	var t: Dictionary = scene._enemies[0]
	assert_false(bool(t["grounded"]),
		"tako should leave the ground when cooldown expires")
	assert_lt(float(t["vel"].y), 0.0,
		"hop velocity y should be negative (upward) — got %f"
		% float(t["vel"].y))
	assert_gt(float(t["vel"].x), 0.0,
		"tako should move toward the player on the right — got vx=%f"
		% float(t["vel"].x))


func test_dream_tako_lands_back_on_floor_and_resets_cooldown() -> void:
	# Arrange — tako mid-air with downward velocity, just above floor.
	var scene: Dream = await _make_scene()
	var floor_y_top: float = float(scene.FLOOR_Y) - scene.ENEMY_H * 0.5
	var tako: Dictionary = {
		"pos": Vector2(160.0, floor_y_top - 0.5),
		"hp": scene.TAKO_HP,
		"kind": "tako",
		"vel": Vector2(20.0, 200.0),
		"hop_cd_t": 0.0,
		"grounded": false,
	}
	scene._enemies = [tako]

	# Act — one physics tick should drive it onto the floor.
	scene._step_enemies(0.1)

	# Assert
	var t: Dictionary = scene._enemies[0]
	assert_true(bool(t["grounded"]),
		"tako should snap to grounded after touching floor")
	assert_almost_eq(float(t["pos"].y), floor_y_top, 0.01,
		"tako y should clamp to floor top — got %f" % float(t["pos"].y))
	assert_gt(float(t["hop_cd_t"]), 0.0,
		"hop cooldown should reset on landing — got %f"
		% float(t["hop_cd_t"]))


# ---------------------------------------------------------------------------
# 夜市大魔王 boss (v0.34)
# ---------------------------------------------------------------------------

func test_dream_boss_spawns_at_kill_threshold() -> void:
	# Arrange — set kills to threshold but no boss yet.
	var scene: Dream = await _make_scene()
	scene._enemies_killed = scene.BOSS_TRIGGER_KILLS

	# Act
	scene._maybe_spawn_boss()

	# Assert
	assert_true(scene._boss_alive,
		"boss should be alive after _maybe_spawn_boss when kill target met")
	assert_eq(int(scene._boss["hp"]), scene.BOSS_HP_MAX,
		"boss should spawn at full HP — got %d" % int(scene._boss["hp"]))


func test_dream_boss_does_not_spawn_below_threshold() -> void:
	# Arrange
	var scene: Dream = await _make_scene()
	scene._enemies_killed = scene.BOSS_TRIGGER_KILLS - 1

	# Act
	scene._maybe_spawn_boss()

	# Assert
	assert_false(scene._boss_alive,
		"boss must not spawn before threshold is reached")


func test_dream_boss_takes_damage_from_player_projectile() -> void:
	# Arrange — manual boss + projectile aligned in the boss bounding box.
	var scene: Dream = await _make_scene()
	scene._boss = {
		"pos": Vector2(160.0, scene.BOSS_HOVER_Y),
		"hp": scene.BOSS_HP_MAX,
	}
	scene._boss_alive = true
	scene._projectiles = [{
		"pos": Vector2(160.0, scene.BOSS_HOVER_Y),
		"vel": Vector2(scene.PROJECTILE_SPEED, 0.0),
		"age": 0.0,
	}]

	# Act
	scene._step_projectiles(0.0)

	# Assert
	assert_eq(int(scene._boss["hp"]), scene.BOSS_HP_MAX - 1,
		"boss HP should decrement by 1 — got %d" % int(scene._boss["hp"]))
	assert_gt(scene._boss_invincible_t, 0.0,
		"i-frames should arm so two projectiles in the same frame don't double-hit")


func test_dream_boss_defeat_marks_defeated_and_clears_alive() -> void:
	# Arrange — boss at 1 HP, single projectile to land the kill shot.
	var scene: Dream = await _make_scene()
	scene._boss = {
		"pos": Vector2(160.0, scene.BOSS_HOVER_Y),
		"hp": 1,
	}
	scene._boss_alive = true
	scene._projectiles = [{
		"pos": Vector2(160.0, scene.BOSS_HOVER_Y),
		"vel": Vector2(scene.PROJECTILE_SPEED, 0.0),
		"age": 0.0,
	}]

	# Act
	scene._step_projectiles(0.0)

	# Assert
	assert_false(scene._boss_alive, "boss_alive should clear on kill shot")
	assert_true(scene._boss_defeated, "boss_defeated flag should latch")


func test_dream_advance_records_kills_to_hiscore() -> void:
	# Arrange — fresh HiScore (cleared in before_each); pretend the player
	# ended their dream with 4 small-fry kills and no boss clear.
	var scene: Dream = await _make_scene()
	scene._enemies_killed = 4

	# Act
	scene._advance()

	# Assert
	assert_eq(HiScore.dream_best_kills, 4,
		"dream_best_kills should track this dream's kill count — got %d"
		% HiScore.dream_best_kills)
	assert_eq(HiScore.dream_boss_clears, 0,
		"no boss clear should leave dream_boss_clears at 0")


func test_dream_advance_records_boss_clear_to_hiscore() -> void:
	# Arrange — boss-clear win: kills capped at trigger threshold + boss flag.
	var scene: Dream = await _make_scene()
	scene._enemies_killed = scene.BOSS_TRIGGER_KILLS
	scene._boss_defeated = true

	# Act
	scene._advance()

	# Assert
	assert_eq(HiScore.dream_boss_clears, 1,
		"first boss clear should bump dream_boss_clears to 1 — got %d"
		% HiScore.dream_boss_clears)
	assert_eq(HiScore.dream_best_kills, scene.BOSS_TRIGGER_KILLS,
		"kills before boss should still be recorded — got %d"
		% HiScore.dream_best_kills)


func test_dream_boss_projectile_damages_player_on_overlap() -> void:
	# Arrange — boss projectile centred on player.
	var scene: Dream = await _make_scene()
	scene._player_pos = Vector2(160.0, 142.0)
	scene._player_invincible_t = 0.0
	var initial_hp: int = scene._player_hp
	scene._boss_projectiles = [{
		"pos": Vector2(160.0, 142.0 - scene.PLAYER_H * 0.5),
		"vel": Vector2(0.0, scene.BOSS_PROJECTILE_VY),
		"age": 0.0,
	}]

	# Act — zero-delta tick still runs the overlap check before motion
	scene._step_boss_projectiles(0.0)

	# Assert
	assert_eq(scene._player_hp, initial_hp - 1,
		"player should take 1 damage from boss projectile — hp went %d→%d"
		% [initial_hp, scene._player_hp])
	assert_eq(scene._boss_projectiles.size(), 0,
		"projectile should be consumed on hit")


func test_dream_platform_ignored_when_horizontally_off() -> void:
	# Arrange — player to the right of all platforms (x=180 is in the gap
	# between platform[0] right=96 and platform[1] left=224). Falls past
	# the platform y plane and should keep falling (or hit floor) rather
	# than snap to a platform.
	var scene: Dream = await _make_scene()
	scene._player_pos = Vector2(180.0, 109.5)
	scene._player_vel = Vector2(0.0, 60.0)
	scene._player_on_ground = false

	# Act
	scene._step_player(0.1)

	# Assert: not snapped to y=110.
	assert_gt(scene._player_pos.y, 110.5,
		"off-platform fall should not snap to platform top — got y=%f"
		% scene._player_pos.y)
	assert_false(scene._player_on_ground,
		"_player_on_ground should remain false in the platform gap")
