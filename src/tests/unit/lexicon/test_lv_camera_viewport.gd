## Unit tests for #3 Camera & viewport — verifies project.godot settings match GDD spec.
## Camera & viewport has no script; it's pure project configuration.
extends GutTest

# AC-1 — Viewport configured correctly at boot
func test_viewport_stretch_mode_is_viewport() -> void:
	# Assert
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode", "")
	assert_eq(mode, "viewport", "stretch_mode must be 'viewport' per AC-1")

func test_viewport_scale_mode_is_integer() -> void:
	# Assert
	var scale_mode: String = ProjectSettings.get_setting("display/window/stretch/scale_mode", "")
	assert_eq(scale_mode, "integer", "scale_mode must be 'integer' per AC-8 (preserves 8x8 font crispness)")

# AC-2 — Base resolution is 320x180
func test_viewport_width_is_320() -> void:
	# Assert
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	assert_eq(w, 320, "viewport_width must be 320 per BASE_RESOLUTION")

func test_viewport_height_is_180() -> void:
	# Assert
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	assert_eq(h, 180, "viewport_height must be 180 per BASE_RESOLUTION")

# Constant for cross-system reference (per registry)
func test_base_resolution_is_16_9_ratio() -> void:
	# Assert: 320:180 = 16:9
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	assert_eq(w * 9, h * 16, "BASE_RESOLUTION must be 16:9 aspect ratio")
