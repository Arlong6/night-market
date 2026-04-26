## GUT integration tests for ShilinMarket level (R-003).
##
## Verifies the programmatic build produces a navigable map: walkability
## perimeter is blocked, interior is open, stall + mum cells are reserved,
## player spawns on the home cell, camera follows with clamping.
extends GutTest


## Builds a fresh ShilinMarket instance in the scene tree so its _ready
## runs (which spawns player + camera). Returns the level after one frame.
func _make_market() -> ShilinMarket:
	var m: ShilinMarket = ShilinMarket.new()
	add_child_autofree(m)
	await get_tree().process_frame
	return m


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_market_loads_and_has_player() -> void:
	var m: ShilinMarket = await _make_market()
	var player: Node = m.find_child("Player", false, false)
	assert_not_null(player, "Level should spawn a Player node")
	assert_true(player is PlayerGrid, "Player should be a PlayerGrid instance")


func test_market_loads_and_has_camera() -> void:
	var m: ShilinMarket = await _make_market()
	var cam: Node = m.find_child("GameCamera", false, false)
	assert_not_null(cam, "Level should spawn a GameCamera")
	assert_true(cam is Camera2D, "GameCamera should be a Camera2D")


func test_market_walkable_perimeter_is_blocked() -> void:
	var m: ShilinMarket = await _make_market()
	# Sample corners + each edge midpoint.
	assert_false(m.is_walkable(Vector2i(0, 0)), "Top-left corner blocked")
	assert_false(m.is_walkable(Vector2i(ShilinMarket.GRID_W - 1, 0)), "Top-right corner blocked")
	assert_false(m.is_walkable(Vector2i(0, ShilinMarket.GRID_H - 1)), "Bottom-left corner blocked")
	assert_false(m.is_walkable(
		Vector2i(ShilinMarket.GRID_W - 1, ShilinMarket.GRID_H - 1)
	), "Bottom-right corner blocked")
	# Edge midpoints
	assert_false(m.is_walkable(Vector2i(ShilinMarket.GRID_W / 2, 0)), "Top edge blocked")
	assert_false(m.is_walkable(Vector2i(0, ShilinMarket.GRID_H / 2)), "Left edge blocked")


func test_market_walkable_centre_is_walkable() -> void:
	var m: ShilinMarket = await _make_market()
	# Pick a centre cell that's not a stall and not mum.
	assert_true(m.is_walkable(Vector2i(10, 6)),
		"Interior cell (10,6) should be walkable")


func test_market_walkable_stall_cells_blocked() -> void:
	var m: ShilinMarket = await _make_market()
	for sc in ShilinMarket.STALL_CELLS:
		assert_false(m.is_walkable(sc),
			"Stall cell %s should be unwalkable" % sc)


func test_market_mom_cell_blocked() -> void:
	var m: ShilinMarket = await _make_market()
	assert_false(m.is_walkable(ShilinMarket.MOM_CELL),
		"Mum cell should be unwalkable so the player bumps to talk")


func test_market_player_spawned_on_home_cell() -> void:
	var m: ShilinMarket = await _make_market()
	var player: PlayerGrid = m.find_child("Player", false, false) as PlayerGrid
	assert_not_null(player)
	if player != null:
		assert_eq(player.cell, ShilinMarket.HOME_CELL,
			"Player should start at HOME_CELL — got %s" % player.cell)


func test_market_out_of_bounds_returns_false() -> void:
	var m: ShilinMarket = await _make_market()
	assert_false(m.is_walkable(Vector2i(-1, 5)), "Negative x out of bounds")
	assert_false(m.is_walkable(Vector2i(5, -1)), "Negative y out of bounds")
	assert_false(m.is_walkable(Vector2i(ShilinMarket.GRID_W, 5)), "x >= GRID_W out")
	assert_false(m.is_walkable(Vector2i(5, ShilinMarket.GRID_H)), "y >= GRID_H out")


func test_market_camera_clamps_to_world_left_edge() -> void:
	var m: ShilinMarket = await _make_market()
	var player: PlayerGrid = m.find_child("Player", false, false) as PlayerGrid
	var cam: Camera2D = m.find_child("GameCamera", false, false) as Camera2D
	assert_not_null(player)
	assert_not_null(cam)
	if player == null or cam == null:
		return
	# Player is at HOME_CELL (2, 11), well inside the left edge.
	# Camera should clamp to viewport_w/2 = 160 (can't show negative x).
	await get_tree().process_frame
	assert_eq(cam.position.x, 160.0,
		"Camera at left edge should clamp x = VIEWPORT_W/2 = 160 — got %s" % cam.position.x)


func test_market_walkable_array_has_correct_dimensions() -> void:
	var m: ShilinMarket = await _make_market()
	assert_eq(m.walkable.size(), ShilinMarket.GRID_H,
		"walkable should have GRID_H rows")
	assert_eq(m.walkable[0].size(), ShilinMarket.GRID_W,
		"each row should have GRID_W cells")
