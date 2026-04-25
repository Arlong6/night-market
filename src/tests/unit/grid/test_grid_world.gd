## GUT unit tests for the GridWorld coordinate utility.
## Story R-002.
extends GutTest


func test_grid_world_cell_to_px_returns_centred_pixel() -> void:
	# Cell (2, 3) starts at pixel (32, 48); centre is +8 → (40, 56).
	var px: Vector2 = GridWorld.cell_to_px(Vector2i(2, 3))
	assert_eq(px, Vector2(40.0, 56.0),
		"cell_to_px((2,3)) should return cell-centre (40,56) — got %s" % px)


func test_grid_world_cell_to_px_origin_cell() -> void:
	var px: Vector2 = GridWorld.cell_to_px(Vector2i(0, 0))
	assert_eq(px, Vector2(8.0, 8.0),
		"Cell (0,0) centre should be (8,8) — got %s" % px)


func test_grid_world_px_to_cell_inverse_of_cell_to_px() -> void:
	for cx in [0, 1, 5, 19]:
		for cy in [0, 3, 10]:
			var input := Vector2i(cx, cy)
			var px: Vector2 = GridWorld.cell_to_px(input)
			var roundtrip: Vector2i = GridWorld.px_to_cell(px)
			assert_eq(roundtrip, input,
				"Round-trip (%s) should equal input (%s) — got %s" % [px, input, roundtrip])


func test_grid_world_in_bounds_inside_returns_true() -> void:
	# Standard market grid is 20x11.
	assert_true(GridWorld.in_bounds(Vector2i(0, 0), 20, 11), "(0,0) should be in 20x11")
	assert_true(GridWorld.in_bounds(Vector2i(19, 10), 20, 11), "(19,10) should be in 20x11")
	assert_true(GridWorld.in_bounds(Vector2i(10, 5), 20, 11), "(10,5) should be in 20x11")


func test_grid_world_in_bounds_outside_returns_false() -> void:
	assert_false(GridWorld.in_bounds(Vector2i(-1, 0), 20, 11), "(-1,0) should be out")
	assert_false(GridWorld.in_bounds(Vector2i(0, -1), 20, 11), "(0,-1) should be out")
	assert_false(GridWorld.in_bounds(Vector2i(20, 0), 20, 11), "(20,0) should be out (off right)")
	assert_false(GridWorld.in_bounds(Vector2i(0, 11), 20, 11), "(0,11) should be out (off bottom)")
