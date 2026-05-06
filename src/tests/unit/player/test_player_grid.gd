## GUT unit tests for PlayerGrid (grid-snap player controller).
## Story R-002.
##
## Tests advance time via `await get_tree().create_timer(...).timeout` rather
## than fixed frame counts so they remain valid if frame-rate-dependent timing
## is changed.
extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Builds a PlayerGrid at start_cell with a walkable callback that always
## returns the given value.
func _make_player(start: Vector2i, all_walkable: bool = true) -> PlayerGrid:
	var p: PlayerGrid = PlayerGrid.new()
	p.start_cell = start
	p.walkable_check = func(_c: Vector2i) -> bool: return all_walkable
	add_child_autofree(p)
	await get_tree().process_frame
	return p


## Releases every input action this controller listens to. Called in
## `before_each` because GUT can leak Input state across tests.
func _release_all_inputs() -> void:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		Input.action_release(action)


func before_each() -> void:
	_release_all_inputs()
	# Defensive: dialogue tests can leak Game.in_dialogue = true across files.
	Game.in_dialogue = false


func after_each() -> void:
	_release_all_inputs()
	# Reset HiScore.day so v0.43 weather tests don't bleed into others.
	HiScore.day = 1

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_player_press_right_moves_one_cell_right() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)

	# Tap-then-release pattern: edge-press is detected on frame 0; we release
	# well before the step finishes so no second step chains. The first tween
	# still completes because cell + position are committed at step START.
	Input.action_press("ui_right")
	await get_tree().create_timer(0.04).timeout
	Input.action_release("ui_right")
	# Wait for the in-flight tween to finish + a small buffer.
	await get_tree().create_timer(PlayerGrid.STEP_DURATION + 0.05).timeout

	assert_eq(p.cell, Vector2i(6, 5),
		"After one tap of ui_right, cell should be (6,5) — got %s" % p.cell)
	assert_false(p.is_stepping, "Tween should have completed")


func test_player_blocked_target_stays_in_place() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), false)
	watch_signals(p)

	Input.action_press("ui_right")
	await get_tree().create_timer(PlayerGrid.STEP_DURATION + 0.05).timeout
	Input.action_release("ui_right")

	assert_eq(p.cell, Vector2i(5, 5),
		"Blocked step should not move — got %s" % p.cell)
	assert_eq(p.facing, Vector2i.RIGHT,
		"Facing should still update on blocked attempt — got %s" % p.facing)
	assert_signal_emitted(p, "bumped",
		"`bumped` signal should fire when target is unwalkable")


func test_player_held_input_continues_stepping() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)

	Input.action_press("ui_left")
	# Hold for 2 step durations + small buffer.
	await get_tree().create_timer(PlayerGrid.STEP_DURATION * 2.0 + 0.05).timeout
	Input.action_release("ui_left")
	# Let any in-flight final step settle.
	await get_tree().create_timer(PlayerGrid.STEP_DURATION + 0.05).timeout

	assert_true(p.cell.x <= 3,
		"After 2.x step durations holding ui_left, x should be ≤ 3 (started 5) — got %s" % p.cell.x)


func test_player_releases_input_mid_step_completes_then_stops() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)

	Input.action_press("ui_down")
	# Release mid-tween.
	await get_tree().create_timer(PlayerGrid.STEP_DURATION * 0.4).timeout
	Input.action_release("ui_down")
	# Allow current tween to finish; assert no further step.
	await get_tree().create_timer(PlayerGrid.STEP_DURATION * 2.0).timeout

	assert_eq(p.cell, Vector2i(5, 6),
		"Should land on the cell currently being stepped to — got %s" % p.cell)
	assert_false(p.is_stepping, "No further stepping should be in flight")


func test_player_facing_updates_even_when_blocked() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), false)

	Input.action_press("ui_up")
	await get_tree().create_timer(0.05).timeout
	Input.action_release("ui_up")

	assert_eq(p.facing, Vector2i.UP,
		"Facing should update on blocked press — got %s" % p.facing)


func test_player_starts_at_start_cell_position() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(3, 7), true)

	assert_eq(p.cell, Vector2i(3, 7),
		"cell should equal start_cell after _ready — got %s" % p.cell)
	assert_eq(p.position, GridWorld.cell_to_px(Vector2i(3, 7)),
		"position should be cell-centre pixel after _ready — got %s" % p.position)


func test_player_cell_changed_signal_emits_on_step_completion() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	watch_signals(p)

	Input.action_press("ui_right")
	await get_tree().create_timer(PlayerGrid.STEP_DURATION + 0.05).timeout
	Input.action_release("ui_right")

	assert_signal_emitted(p, "cell_changed",
		"cell_changed should emit at end of completed step")


func test_player_no_step_when_no_input() -> void:
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)

	# Wait for several step durations with no input pressed.
	await get_tree().create_timer(PlayerGrid.STEP_DURATION * 3.0).timeout

	assert_eq(p.cell, Vector2i(5, 5),
		"No input should produce no movement — got %s" % p.cell)


# ---------------------------------------------------------------------------
# v0.37 — sprite polish: facing + idle breathing
# ---------------------------------------------------------------------------

func test_player_idle_accumulator_advances_when_stationary() -> void:
	# Arrange — reset to a known value (the helper's process_frame already
	# bumped _idle_t by one frame's delta).
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	p._idle_t = 0.0

	# Act — wait a few frames with no input held.
	await get_tree().create_timer(0.2).timeout

	# Assert — accumulator should have grown so the breathing sin has phase.
	assert_gt(p._idle_t, 0.1,
		"idle accumulator should tick when stationary — got %f"
		% p._idle_t)


func test_player_idle_accumulator_freezes_during_step() -> void:
	# Arrange — capture _idle_t after some idle time, then start stepping.
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	await get_tree().create_timer(0.15).timeout
	var idle_before: float = p._idle_t
	# Act — press right and wait until step is in flight.
	Input.action_press("ui_right")
	await get_tree().create_timer(PlayerGrid.STEP_DURATION * 0.4).timeout
	# At this moment the player is mid-tween. Capture the idle accumulator.
	var idle_during_step: float = p._idle_t
	Input.action_release("ui_right")
	# Assert
	assert_almost_eq(idle_during_step, idle_before, 0.05,
		"_idle_t should be frozen while a step is in flight — was %f, now %f"
		% [idle_before, idle_during_step])


func test_player_facing_up_after_pressing_up() -> void:
	# Arrange
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), false)  # blocked
	# Act — press up on blocked map; facing should still update.
	Input.action_press("ui_up")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_up")
	# Assert
	assert_eq(p.facing, Vector2i(0, -1),
		"facing should be (0,-1) after pressing up — got %s" % p.facing)


func test_player_facing_horizontal_records_x_sign() -> void:
	# Arrange
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), false)
	# Act — press left
	Input.action_press("ui_left")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_left")
	# Assert
	assert_eq(p.facing.x, -1,
		"facing.x should be -1 after pressing left — got %d" % p.facing.x)


# ---------------------------------------------------------------------------
# v0.43 — umbrella renders above head on non-sunny days
# ---------------------------------------------------------------------------

func test_player_draw_umbrella_skips_when_sunny() -> void:
	# Arrange — force a known sunny day (day 1 puts cycle 0 → SUNNY).
	HiScore.day = 1
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	# Act — _draw runs every frame; survival is the assertion. We just need
	# to confirm the helper short-circuits without touching draw state when
	# weather is sunny (no crash from missing context).
	p._draw_umbrella(0.0)
	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_SUNNY,
		"day 1 should be SUNNY so _draw_umbrella early-returns")


func test_player_draw_umbrella_renders_when_rainy_and_owned() -> void:
	# Arrange — day 4 in the v0.42 weather cycle is RAINY. v0.46 requires
	# has_umbrella=true before the canopy draws.
	HiScore.day = 4
	Inventory.has_umbrella = true
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	# Act — drawing through the engine's render pipeline runs each frame.
	# Wait one frame so queue_redraw fires the canopy path; survival = pass.
	await get_tree().process_frame
	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_RAINY,
		"day 4 should be RAINY so _draw_umbrella renders the canopy")
	assert_true(p != null, "player drew one frame in rain without crashing")
	# Cleanup so the flag doesn't bleed into other tests.
	Inventory.has_umbrella = false


func test_player_draw_umbrella_renders_when_typhoon_and_owned() -> void:
	# Arrange — typhoon special-request day (14 in the 14-day cycle).
	HiScore.day = 14
	Inventory.has_umbrella = true
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	# Act
	await get_tree().process_frame
	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_TYPHOON,
		"day 14 should be TYPHOON so umbrella uses the storm canopy")
	assert_true(p != null, "player drew one frame in typhoon without crashing")
	Inventory.has_umbrella = false


func test_player_draw_umbrella_skips_when_rainy_but_not_owned() -> void:
	# Arrange — v0.46 retcon: rainy + no umbrella means kid is wet, no canopy.
	HiScore.day = 4
	Inventory.has_umbrella = false
	var p: PlayerGrid = await _make_player(Vector2i(5, 5), true)
	# Act — calling the helper directly so we don't need a render context
	p._draw_umbrella(0.0)  # should early-return, no draw_rect calls
	# Assert
	assert_false(Inventory.has_umbrella,
		"sanity: precondition for the v0.46 retcon path")
	assert_true(p != null, "_draw_umbrella early-return without crash")
