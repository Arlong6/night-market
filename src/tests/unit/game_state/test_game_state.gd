## GUT unit tests for the Game state singleton.
## Story 007: Game State Singleton
##
## Requires: GUT addon at res://addons/gut/
## Run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
extends GutTest

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	# Enable test mode so restart_level / goto_level skip scene tree ops.
	Game.test_mode = true
	# Reset all state so tests are fully isolated.
	Game.reset_run()
	Game.current_level = "shilin"


func after_each() -> void:
	Game.test_mode = false

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_game_add_score_increments_and_emits() -> void:
	watch_signals(Game)

	Game.add_score(100)

	assert_eq(Game.score, 100,
		"score should be 100 after add_score(100)")
	assert_signal_emit_count(Game, "score_changed", 1,
		"score_changed should emit once")
	var params: Array = get_signal_parameters(Game, "score_changed", 0)
	assert_not_null(params, "score_changed emit record should exist")
	if params != null:
		assert_eq(params[0], 100,
			"score_changed should carry new_score=100, got %s" % params[0])


func test_game_record_death_increments_and_emits() -> void:
	watch_signals(Game)

	Game.record_death()

	assert_eq(Game.deaths, 1,
		"deaths should be 1 after record_death()")
	assert_signal_emit_count(Game, "deaths_changed", 1,
		"deaths_changed should emit once")
	var params: Array = get_signal_parameters(Game, "deaths_changed", 0)
	assert_not_null(params, "deaths_changed emit record should exist")
	if params != null:
		assert_eq(params[0], 1,
			"deaths_changed should carry new_deaths=1, got %s" % params[0])


func test_game_restart_level_preserves_score_and_deaths() -> void:
	Game.add_score(500)
	Game.record_death()  # deaths=1, triggers restart_level (test_mode skips reload)
	Game.restart_level()

	assert_eq(Game.score, 500,
		"score should be preserved across restart_level (got %s)" % Game.score)
	assert_eq(Game.deaths, 1,
		"deaths should be preserved across restart_level (got %s)" % Game.deaths)


func test_game_reset_run_zeros_everything() -> void:
	Game.add_score(300)
	Game.record_death()
	Game._process(2.0)

	Game.reset_run()

	assert_eq(Game.score, 0,      "score should be 0 after reset_run()")
	assert_eq(Game.deaths, 0,     "deaths should be 0 after reset_run()")
	assert_almost_eq(Game.session_time, 0.0, 0.001,
		"session_time should be 0.0 after reset_run() (got %s)" % Game.session_time)


func test_game_goto_level_updates_current_level_and_emits() -> void:
	watch_signals(Game)

	Game.goto_level("fengjia")

	assert_eq(Game.current_level, "fengjia",
		"current_level should be 'fengjia' after goto_level")
	assert_signal_emit_count(Game, "level_changed", 1,
		"level_changed should emit once")
	var params: Array = get_signal_parameters(Game, "level_changed", 0)
	assert_not_null(params, "level_changed emit record should exist")
	if params != null:
		assert_eq(params[0], "fengjia",
			"level_changed should carry 'fengjia', got '%s'" % params[0])


func test_game_goto_level_invalid_slug_no_crash() -> void:
	var score_before: int = Game.score
	var level_before: String = Game.current_level
	watch_signals(Game)

	Game.goto_level("invalid_slug_xyz")

	assert_eq(Game.score, score_before,
		"score should be unchanged after invalid goto_level")
	assert_eq(Game.current_level, level_before,
		"current_level should be unchanged after invalid goto_level")
	assert_signal_not_emitted(Game, "level_changed",
		"level_changed should NOT emit for an unknown slug")


func test_game_session_time_accumulates() -> void:
	for _i: int in range(5):
		Game._process(0.1)

	assert_almost_eq(Game.session_time, 0.5, 0.01,
		"session_time should be ~0.5 after five 0.1s _process calls (got %s)" % Game.session_time)
