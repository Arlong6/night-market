## Unit tests for LVGlyphFont (#5 Glyph Font Rendering — MVP shim).
## Tests the pixel-mode font wrapper + Label override application.
extends GutTest

const LVGlyphFont = preload("res://lexicon/scripts/lv_glyph_font.gd")

# get_pixel_font returns a usable FontFile
func test_get_pixel_font_returns_font() -> void:
	# Act
	var f: FontFile = LVGlyphFont.get_pixel_font()
	# Assert
	assert_not_null(f, "Pixel font should load from source TTF")
	assert_true(f is FontFile)

# Pixel font has antialiasing disabled (the whole point of the override)
func test_pixel_font_has_no_antialiasing() -> void:
	# Act
	var f: FontFile = LVGlyphFont.get_pixel_font()
	# Assert
	assert_eq(f.antialiasing, TextServer.FONT_ANTIALIASING_NONE)

# Pixel font has hinting disabled
func test_pixel_font_has_no_hinting() -> void:
	# Act
	var f: FontFile = LVGlyphFont.get_pixel_font()
	# Assert
	assert_eq(f.hinting, TextServer.HINTING_NONE)

# Pixel font has subpixel positioning disabled
func test_pixel_font_has_no_subpixel() -> void:
	# Act
	var f: FontFile = LVGlyphFont.get_pixel_font()
	# Assert
	assert_eq(f.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)

# Caching works — second call returns same instance
func test_get_pixel_font_caches() -> void:
	# Act
	var a: FontFile = LVGlyphFont.get_pixel_font()
	var b: FontFile = LVGlyphFont.get_pixel_font()
	# Assert
	assert_eq(a.get_instance_id(), b.get_instance_id())

# apply_to_label sets both font override and size override
func test_apply_to_label_sets_overrides() -> void:
	# Arrange
	var lbl := Label.new()
	add_child_autofree(lbl)
	# Act
	LVGlyphFont.apply_to_label(lbl)
	# Assert
	assert_true(lbl.has_theme_font_override("font"))
	assert_true(lbl.has_theme_font_size_override("font_size"))
	assert_eq(lbl.get_theme_font_size("font_size"), LVGlyphFont.PIXEL_FONT_SIZE)

# clear_label_overrides removes them
func test_clear_label_overrides_removes() -> void:
	# Arrange
	var lbl := Label.new()
	add_child_autofree(lbl)
	LVGlyphFont.apply_to_label(lbl)
	# Act
	LVGlyphFont.clear_label_overrides(lbl)
	# Assert
	assert_false(lbl.has_theme_font_override("font"))
	assert_false(lbl.has_theme_font_size_override("font_size"))

# Safe to apply to null label (defensive)
func test_apply_to_null_label_is_safe() -> void:
	# Act + Assert: should not crash
	LVGlyphFont.apply_to_label(null)
	# Tautology assert to keep the test non-empty
	assert_true(true)

# Pixel font size constant is small (8-12 range for pixel feel)
func test_pixel_font_size_is_small() -> void:
	# Assert
	assert_true(LVGlyphFont.PIXEL_FONT_SIZE >= 8 and LVGlyphFont.PIXEL_FONT_SIZE <= 12)
