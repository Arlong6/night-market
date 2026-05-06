## GUT smoke tests for UmbrellaVendor (v0.46).
##
## UmbrellaVendor is bump-driven: tests cover (a) construct + draw doesn't
## crash, (b) the spawn-eligibility check on the level (rainy / not owned).
## The buy / dialogue paths are covered indirectly by Inventory tests.
extends GutTest


func before_each() -> void:
	HiScore.day = 1
	HiScore.pending_dream_bonus = 0
	HiScore.pending_special_bonus = 0
	Inventory.last_dream_bonus = 0
	Inventory.last_special_bonus = 0
	Inventory.reset()


func test_umbrella_vendor_constructs_and_draws_without_crash() -> void:
	# Arrange / Act
	var v: UmbrellaVendor = UmbrellaVendor.new()
	v.cell = Vector2i(5, 9)
	add_child_autofree(v)
	await get_tree().process_frame

	# Assert
	assert_eq(v.cell, Vector2i(5, 9),
		"cell should round-trip through the @export field")


func test_umbrella_vendor_should_not_spawn_on_sunny_day() -> void:
	# Arrange — day 1 = sunny; vendor exists but level is expected to gate
	# the spawn upstream. This test just locks in the predicate the level uses.
	HiScore.day = 1
	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_SUNNY,
		"sunny weather should suppress the vendor spawn at the level layer")
	assert_false(Inventory.needs_umbrella(),
		"needs_umbrella() must be false on sunny days")


func test_umbrella_vendor_should_spawn_on_rainy_day() -> void:
	# Arrange — day 4 in the cycle is RAINY.
	HiScore.day = 4
	# Assert
	assert_eq(Inventory.current_weather(), Inventory.WEATHER_RAINY,
		"day 4 should put weather into RAINY mode")
	assert_true(Inventory.needs_umbrella(),
		"rainy + no umbrella → vendor spawn should be triggered")
