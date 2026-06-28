extends GutTest

const ComboSystem = preload("res://scripts/combo_system.gd")

func test_first_hit_multiplier_is_one() -> void:
	var c = ComboSystem.new()
	assert_eq(c.register(10), 10)
	assert_eq(c.multiplier(), 1)

func test_chained_hits_increase_multiplier() -> void:
	var c = ComboSystem.new()
	c.register(10)  # x1
	var pts = c.register(10)  # x2
	assert_eq(c.multiplier(), 2)
	assert_eq(pts, 20)

func test_multiplier_caps() -> void:
	var c = ComboSystem.new()
	for i in 50:
		c.register(1)
	assert_eq(c.multiplier(), RRTuning.COMBO_MAX_MULT)

func test_window_timeout_resets_combo() -> void:
	var c = ComboSystem.new()
	c.register(10)
	c.register(10)
	c.tick(RRTuning.COMBO_WINDOW + 0.1)
	assert_eq(c.count(), 0)
	assert_false(c.is_active())
	assert_eq(c.register(10), 10)  # back to x1
