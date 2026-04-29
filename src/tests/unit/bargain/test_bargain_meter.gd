## GUT unit tests for BargainMeter (v0.22).
##
## tier_for_x is a pure function so we can verify the zone math without
## driving the actual cursor / input.
extends GutTest


func test_bargain_meter_tier_left_red_zone_is_fail() -> void:
	# 0% of bar — far left, in the left red zone
	assert_eq(BargainMeter.tier_for_x(0.0), 0,
		"Left edge should be tier 0 (fail)")
	# Just before the red→yellow boundary at 30%
	var x_before_yellow: float = float(BargainMeter.BAR_W) * 0.29
	assert_eq(BargainMeter.tier_for_x(x_before_yellow), 0,
		"x just below RED_END_LEFT should still be tier 0")


func test_bargain_meter_tier_left_yellow_zone_is_partial() -> void:
	# 35% of bar — between RED_END_LEFT (0.30) and YELLOW_END_LEFT (0.42)
	var x: float = float(BargainMeter.BAR_W) * 0.35
	assert_eq(BargainMeter.tier_for_x(x), 1,
		"Left yellow zone should be tier 1 (partial)")


func test_bargain_meter_tier_green_zone_is_jackpot() -> void:
	# 50% of bar — dead centre, well inside the green band
	var x: float = float(BargainMeter.BAR_W) * 0.50
	assert_eq(BargainMeter.tier_for_x(x), 2,
		"Centre should be tier 2 (jackpot)")


func test_bargain_meter_tier_right_yellow_zone_is_partial() -> void:
	# 65% of bar — between GREEN_END (0.58) and YELLOW_END_RIGHT (0.70)
	var x: float = float(BargainMeter.BAR_W) * 0.65
	assert_eq(BargainMeter.tier_for_x(x), 1,
		"Right yellow zone should be tier 1 (partial)")


func test_bargain_meter_tier_right_red_zone_is_fail() -> void:
	# 95% of bar — far right red zone
	var x: float = float(BargainMeter.BAR_W) * 0.95
	assert_eq(BargainMeter.tier_for_x(x), 0,
		"Far right should be tier 0 (fail)")


func test_bargain_meter_tier_clamps_x_out_of_range() -> void:
	# Negative x is treated as 0 (left edge).
	assert_eq(BargainMeter.tier_for_x(-50.0), 0,
		"Negative x should clamp to left edge (red, tier 0)")
	# x larger than BAR_W treated as 1.0 (right edge).
	assert_eq(BargainMeter.tier_for_x(float(BargainMeter.BAR_W) + 50.0), 0,
		"x past right edge should clamp to right red (tier 0)")
