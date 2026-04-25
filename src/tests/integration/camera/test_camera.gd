## GUT integration tests for Story 006: Camera System.
## Tests verify camera follow logic, boundary clamping, pixel snapping,
## and vertical lock using a plain Node2D target (no Player physics needed).
##
## Run with:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##     -gdir=res://tests/integration -ginclude_subdirs -gexit
extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Instantiate a GameCamera with a fresh Node2D target. Returns [camera, target].
func _make_camera(p_level_width: int = 960) -> Array:
	var cam: GameCamera = GameCamera.new()
	cam.level_width = p_level_width
	add_child_autofree(cam)

	var tgt: Node2D = Node2D.new()
	add_child_autofree(tgt)
	cam.target = tgt

	return [cam, tgt]

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_camera_follows_player_x_in_middle_of_level() -> void:
	var result: Array = _make_camera(960)
	var cam: GameCamera = result[0]
	var tgt: Node2D = result[1]

	tgt.position = Vector2(500.0, 0.0)
	cam._process(0.016)

	assert_eq(cam.position.x, 500.0,
		"Camera x should track target x=500 (mid-level, no clamp)")


func test_camera_clamps_to_left_edge() -> void:
	var result: Array = _make_camera(960)
	var cam: GameCamera = result[0]
	var tgt: Node2D = result[1]

	tgt.position = Vector2(50.0, 0.0)
	cam._process(0.016)

	assert_eq(cam.position.x, 160.0,
		"Camera x should clamp to left boundary (VIEWPORT_W/2 = 160)")


func test_camera_clamps_to_right_edge() -> void:
	var result: Array = _make_camera(960)
	var cam: GameCamera = result[0]
	var tgt: Node2D = result[1]

	tgt.position = Vector2(910.0, 0.0)
	cam._process(0.016)

	assert_eq(cam.position.x, 800.0,
		"Camera x should clamp to right boundary (level_width - VIEWPORT_W/2 = 800)")


func test_camera_position_is_integer() -> void:
	var result: Array = _make_camera(960)
	var cam: GameCamera = result[0]
	var tgt: Node2D = result[1]

	tgt.position = Vector2(245.7, 0.0)
	cam._process(0.016)

	assert_eq(cam.position.x, roundf(245.7),
		"Camera x must be pixel-snapped (integer); got %s" % cam.position.x)
	assert_eq(cam.position.x, floorf(cam.position.x),
		"Pixel-snap check: camera.x must equal its own floor")


func test_camera_vertical_is_locked() -> void:
	var result: Array = _make_camera(960)
	var cam: GameCamera = result[0]
	var tgt: Node2D = result[1]
	var initial_y: float = cam.position.y

	for y_val in [50.0, -30.0, 200.0, 0.0]:
		tgt.position = Vector2(500.0, y_val)
		cam._process(0.016)

	assert_eq(cam.position.y, initial_y,
		"Camera y must remain locked regardless of target y (no vertical follow)")
