extends GutTest

const WantedSystem = preload("res://scripts/wanted_system.gd")

func test_starts_at_zero_stars() -> void:
	assert_eq(WantedSystem.new().stars(), 0)

func test_heat_raises_stars_at_thresholds() -> void:
	var w = WantedSystem.new()
	w.add_heat(60)   # threshold for 1 star
	assert_eq(w.stars(), 1)
	w.add_heat(120)  # total 180 -> 2 stars
	assert_eq(w.stars(), 2)

func test_decay_reduces_heat_but_not_below_zero() -> void:
	var w = WantedSystem.new()
	w.add_heat(60)
	w.decay(100.0)  # large decay
	assert_eq(w.stars(), 0)
	assert_almost_eq(w.heat(), 0.0, 0.001)

func test_caps_at_five_stars() -> void:
	var w = WantedSystem.new()
	w.add_heat(100000)
	assert_eq(w.stars(), 5)
