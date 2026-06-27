extends GutTest

const RRPhysics = preload("res://scripts/rr_physics.gd")

func test_impact_force_scales_with_speed_and_mass() -> void:
	assert_eq(RRPhysics.impact_force(100.0, 3.0), 300.0)

func test_impact_force_zero_speed_is_zero() -> void:
	assert_eq(RRPhysics.impact_force(0.0, 3.0), 0.0)

func test_breaks_at_true_when_force_meets_threshold() -> void:
	assert_true(RRPhysics.breaks_at(220.0, 220.0))

func test_breaks_at_false_below_threshold() -> void:
	assert_false(RRPhysics.breaks_at(219.9, 220.0))
