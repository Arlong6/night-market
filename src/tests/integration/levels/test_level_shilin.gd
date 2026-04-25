## GUT integration tests for Story 009: Level 1 — Shilin.
## Tests verify structural integrity, entity counts, signal wiring,
## and basic physics settle — NOT a full playthrough simulation.
##
## Run with:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##     -gdir=res://tests/integration -ginclude_subdirs -gexit
extends GutTest

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const LEVEL_SCENE_PATH: String = "res://scenes/levels/level_shilin.tscn"
const FLOOR_TOP_Y: float = 120.0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _load_level() -> LevelShilin:
	var packed: PackedScene = load(LEVEL_SCENE_PATH)
	assert_not_null(packed, "PackedScene should load without error")
	var level: LevelShilin = packed.instantiate() as LevelShilin
	assert_not_null(level, "Instantiated level should not be null")
	add_child_autofree(level)
	return level

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	Game.test_mode = true
	Game.reset_run()


func after_each() -> void:
	Game.test_mode = false

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_level_shilin_instantiates_without_errors() -> void:
	var level: LevelShilin = _load_level()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_not_null(level, "Level should still be valid after two frames")


func test_level_shilin_has_required_children() -> void:
	var level: LevelShilin = _load_level()
	await get_tree().process_frame

	assert_not_null(level.find_child("Player", false, false),
		"Level must contain a Player node")
	assert_not_null(level.find_child("GameCamera", false, false),
		"Level must contain a GameCamera node")
	assert_not_null(level.find_child("Hud", false, false),
		"Level must contain a Hud node")
	assert_not_null(level.find_child("Goal", false, false),
		"Level must contain a Goal Area2D node")
	assert_not_null(level.find_child("Collectibles", false, false),
		"Level must contain a Collectibles container node")
	assert_not_null(level.find_child("Enemies", false, false),
		"Level must contain an Enemies container node")


func test_level_shilin_has_expected_entity_counts() -> void:
	var level: LevelShilin = _load_level()
	await get_tree().process_frame

	var collectibles_node: Node = level.find_child("Collectibles", false, false)
	var enemies_node: Node = level.find_child("Enemies", false, false)

	assert_not_null(collectibles_node, "Collectibles container must exist")
	assert_not_null(enemies_node, "Enemies container must exist")

	var collectible_count: int = collectibles_node.get_child_count()
	var enemy_count: int = enemies_node.get_child_count()

	assert_eq(collectible_count, 6,
		"Level must have exactly 6 collectibles — got %d" % collectible_count)

	assert_true(
		enemy_count >= 1 and enemy_count <= 2,
		"Level must have 1–2 enemies — got %d" % enemy_count
	)


func test_level_shilin_collectible_signals_wired_to_game_score() -> void:
	var level: LevelShilin = _load_level()
	await get_tree().process_frame

	var collectibles_node: Node = level.find_child("Collectibles", false, false)
	assert_not_null(collectibles_node, "Pre-condition: Collectibles container must exist")

	var first_collectible: Collectible = null
	for child: Node in collectibles_node.get_children():
		if child is Collectible:
			first_collectible = child as Collectible
			break

	assert_not_null(first_collectible, "Pre-condition: at least one Collectible must exist")

	var score_before: int = Game.score

	first_collectible.picked_up.emit(first_collectible.points)

	assert_eq(
		Game.score,
		score_before + first_collectible.points,
		"Game.score should increment by collectible.points — got %d" % Game.score
	)


func test_level_shilin_enemy_hit_triggers_death_record() -> void:
	var level: LevelShilin = _load_level()
	await get_tree().process_frame

	var enemies_node: Node = level.find_child("Enemies", false, false)
	assert_not_null(enemies_node, "Pre-condition: Enemies container must exist")

	var first_enemy: Enemy = null
	for child: Node in enemies_node.get_children():
		if child is Enemy:
			first_enemy = child as Enemy
			break

	assert_not_null(first_enemy, "Pre-condition: at least one Enemy must exist")

	var deaths_before: int = Game.deaths

	first_enemy._on_body_entered(level.find_child("Player", false, false))

	assert_eq(
		Game.deaths,
		deaths_before + 1,
		"Game.deaths should increment by 1 after enemy._on_body_entered(Player) — got %d" % Game.deaths
	)


func test_level_shilin_player_lands_on_floor() -> void:
	var level: LevelShilin = _load_level()

	for _i: int in range(6):
		await get_tree().physics_frame

	var player_node: Player = level.find_child("Player", false, false) as Player
	assert_not_null(player_node, "Player node must exist")

	assert_true(
		player_node.is_on_floor(),
		"Player should be on floor after 6 physics warmup frames"
	)
