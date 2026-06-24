## Unit tests for #3 Camera & viewport — verifies project.godot settings match GDD spec.
## Camera & viewport has no script; it's pure project configuration.
extends GutTest

# AC-1 — Viewport configured correctly at boot.
# Note: original design called for 'viewport' + 'integer' for pixel-art crispness.
# Switched to 'canvas_items' + 'keep' for sharp CJK rendering on Web export (the
# pixel-art aesthetic was incompatible with readable CJK at small font sizes).
func test_viewport_stretch_mode_is_canvas_items() -> void:
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode", "")
	assert_eq(mode, "canvas_items", "stretch_mode must be 'canvas_items' for sharp CJK on Web")

func test_viewport_scale_mode_is_keep() -> void:
	var scale_mode: String = ProjectSettings.get_setting("display/window/stretch/scale_mode", "")
	assert_eq(scale_mode, "keep", "scale_mode must be 'keep' to lock aspect under canvas_items")

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
