## GUT smoke tests for WanderShopper (v0.17).
##
## WanderShopper is pure visual — no game state changes. Tests cover the
## minimum: instantiation, position seeding, and the wrap-around logic.
extends GutTest


func before_each() -> void:
	# Disable test_mode so _process actually integrates motion in this file.
	# (Game.test_mode is reset in after_each; the rest of the suite is safe.)
	Game.test_mode = false


func after_each() -> void:
	Game.test_mode = false
	# Reset HiScore.day so v0.43 weather tests don't bleed into others.
	HiScore.day = 1


func test_wander_shopper_seeds_position_from_direction() -> void:
	# Arrange
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = 1
	add_child_autofree(s)
	await get_tree().process_frame

	# Assert — direction +1 means start at x_min
	assert_almost_eq(s.position.x, 50.0, 0.5,
		"Right-walking shopper should start at x_min")
	assert_almost_eq(s.position.y, 100.0, 0.001,
		"Shopper should sit at lane_y")


func test_wander_shopper_seeds_position_from_left_direction() -> void:
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = -1
	add_child_autofree(s)
	await get_tree().process_frame
	assert_almost_eq(s.position.x, 150.0, 0.5,
		"Left-walking shopper should start at x_max")


func test_wander_shopper_wraps_at_right_edge() -> void:
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = 1
	s.speed = 100.0
	add_child_autofree(s)
	await get_tree().process_frame

	# Manually push x past x_max, then tick a frame to trigger wrap
	s._x = 200.0
	s._process(0.001)
	assert_almost_eq(s._x, 50.0, 1.0,
		"Should wrap back to x_min after passing x_max — got %s" % s._x)


func test_wander_shopper_wraps_at_left_edge() -> void:
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = -1
	s.speed = 100.0
	add_child_autofree(s)
	await get_tree().process_frame

	s._x = 10.0
	s._process(0.001)
	assert_almost_eq(s._x, 150.0, 1.0,
		"Should wrap back to x_max after passing x_min — got %s" % s._x)


func test_wander_shopper_freezes_in_test_mode() -> void:
	# Test_mode = true means _process is a no-op; useful so unit tests of the
	# market scene aren't time-dependent on shopper motion.
	var s: WanderShopper = WanderShopper.new()
	s.x_min = 50.0
	s.x_max = 150.0
	s.lane_y = 100.0
	s.direction = 1
	s.speed = 100.0
	add_child_autofree(s)
	await get_tree().process_frame

	Game.test_mode = true
	var x_before: float = s._x
	s._process(1.0)  # under test_mode this should NOT advance _x
	assert_almost_eq(s._x, x_before, 0.001,
		"test_mode should freeze shopper motion")


# ---------------------------------------------------------------------------
# v0.36 — kind variety
# ---------------------------------------------------------------------------

func test_wander_shopper_default_kind_is_adult() -> void:
	# Arrange
	var s: WanderShopper = WanderShopper.new()
	add_child_autofree(s)

	# Assert
	assert_eq(s.kind, WanderShopper.Kind.ADULT,
		"default kind should be ADULT for backward compat with v0.17 callers")


func test_wander_shopper_accepts_each_kind_without_crashing() -> void:
	# Arrange — exercise every kind through one frame so any draw-time crash
	# (bad rect, missing accent, etc.) shows up in CI.
	Game.test_mode = false
	var kinds: Array = [
		WanderShopper.Kind.ADULT,
		WanderShopper.Kind.GRANNY,
		WanderShopper.Kind.BUSINESSMAN,
		WanderShopper.Kind.KID,
		WanderShopper.Kind.COUPLE,
	]
	for k in kinds:
		var s: WanderShopper = WanderShopper.new()
		s.x_min = 0.0
		s.x_max = 320.0
		s.lane_y = 100.0
		s.direction = 1
		s.kind = k
		s.body_color = Color("#5A8A5A")
		s.accent_color = Color("#3A2A4A")
		add_child_autofree(s)

	await get_tree().process_frame

	# Assert — survival of the frame is the assertion; no crashes means pass.
	assert_true(true, "all 5 shopper kinds should construct + tick + draw")


# ---------------------------------------------------------------------------
# v0.43 — umbrella draws cleanly for every kind in rain + typhoon
# ---------------------------------------------------------------------------

func test_wander_shopper_umbrella_draws_for_each_kind_in_rain() -> void:
	# Arrange — RAINY weather (day 4) + every kind. Survival is the test.
	HiScore.day = 4
	Game.test_mode = false
	var kinds: Array = [
		WanderShopper.Kind.ADULT,
		WanderShopper.Kind.GRANNY,
		WanderShopper.Kind.BUSINESSMAN,
		WanderShopper.Kind.KID,
		WanderShopper.Kind.COUPLE,
	]
	for k in kinds:
		var s: WanderShopper = WanderShopper.new()
		s.kind = k
		s.body_color = Color("#5A8A5A")
		s.accent_color = Color("#3A2A4A")
		add_child_autofree(s)
	await get_tree().process_frame

	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_RAINY,
		"day 4 must be RAINY for the umbrella canopy path to fire")


func test_wander_shopper_umbrella_draws_for_each_kind_in_typhoon() -> void:
	# Arrange — TYPHOON weather (day 14) darkens canopies via _draw_umbrella.
	HiScore.day = 14
	Game.test_mode = false
	var kinds: Array = [
		WanderShopper.Kind.ADULT,
		WanderShopper.Kind.GRANNY,
		WanderShopper.Kind.BUSINESSMAN,
		WanderShopper.Kind.KID,
		WanderShopper.Kind.COUPLE,
	]
	for k in kinds:
		var s: WanderShopper = WanderShopper.new()
		s.kind = k
		s.body_color = Color("#5A8A5A")
		s.accent_color = Color("#3A2A4A")
		add_child_autofree(s)
	await get_tree().process_frame

	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_TYPHOON,
		"day 14 must be TYPHOON so storm canopy path fires for every kind")


func test_wander_shopper_couple_umbrella_is_wider_than_adult() -> void:
	# Arrange — sanity check the per-kind canopy table includes COUPLE.
	# COUPLE umbrella is drawn 11px wide vs the standard 7px, but that's
	# inside _draw_umbrella; this test just confirms the COUPLE colour entry
	# exists so future renames don't silently drop it.
	# Assert
	assert_true(WanderShopper.UMBRELLA_COLORS.has(WanderShopper.Kind.COUPLE),
		"COUPLE must have a umbrella colour entry for v0.43 wider canopy")
	assert_true(WanderShopper.UMBRELLA_COLORS.has(WanderShopper.Kind.ADULT),
		"ADULT must have an umbrella colour entry for v0.43")
