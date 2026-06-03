## Unit tests for LVBitmapGlyphs (#5 real 8×8 hand-encoded pixel font).
extends GutTest

const LVBitmapGlyphs = preload("res://lexicon/scripts/lv_bitmap_glyphs.gd")
const LVProcGen = preload("res://lexicon/scripts/lv_proc_gen.gd")

# All required lowercase characters from procgen alphabet supported
func test_all_procgen_consonants_supported() -> void:
	for c in LVProcGen.CONSONANTS:
		assert_true(LVBitmapGlyphs.has_glyph(c), "Missing bitmap for consonant '%s'" % c)

func test_all_procgen_vowels_supported() -> void:
	for v in LVProcGen.VOWELS:
		assert_true(LVBitmapGlyphs.has_glyph(v), "Missing bitmap for vowel '%s'" % v)

# Punctuation supported
func test_punctuation_supported() -> void:
	for p in [".", "?", "_", " "]:
		assert_true(LVBitmapGlyphs.has_glyph(p), "Missing bitmap for '%s'" % p)

# Digits 0-9 supported (for collision suffixes)
func test_digits_supported() -> void:
	for d in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		assert_true(LVBitmapGlyphs.has_glyph(d), "Missing bitmap for digit '%s'" % d)

# At least 25 chars supported
func test_supported_char_count_meets_minimum() -> void:
	assert_gte(LVBitmapGlyphs.supported_char_count(), 25)

# glyph_image returns an 8×8 image
func test_glyph_image_is_8x8() -> void:
	var img: Image = LVBitmapGlyphs.glyph_image("a", Color.WHITE)
	assert_eq(img.get_width(), LVBitmapGlyphs.GLYPH_W)
	assert_eq(img.get_height(), LVBitmapGlyphs.GLYPH_H)

# glyph_image has at least one lit pixel (not all transparent)
func test_glyph_image_has_lit_pixels() -> void:
	var img: Image = LVBitmapGlyphs.glyph_image("a", Color.WHITE)
	var lit: int = 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				lit += 1
	assert_gt(lit, 0, "Glyph 'a' should have at least 1 lit pixel")

# Unknown char returns a tofu box (frame-only image)
func test_unknown_char_returns_tofu() -> void:
	var img: Image = LVBitmapGlyphs.glyph_image("≈", Color.WHITE)
	# Corner should be lit (frame)
	assert_true(img.get_pixel(0, 0).a > 0.5)
	assert_true(img.get_pixel(7, 7).a > 0.5)
	# Center should be transparent (frame-only, no fill)
	assert_true(img.get_pixel(3, 3).a < 0.5)

# render_word_image produces image with width = N × (8+1) − 1
func test_render_word_image_dimensions() -> void:
	var img: Image = LVBitmapGlyphs.render_word_image("mura", Color.WHITE)
	# 4 chars × 9 (8+1) − 1 kern = 35 wide
	var expected_w: int = 4 * (LVBitmapGlyphs.GLYPH_W + LVBitmapGlyphs.KERN) - LVBitmapGlyphs.KERN
	assert_eq(img.get_width(), expected_w)
	assert_eq(img.get_height(), LVBitmapGlyphs.GLYPH_H)

# Empty word returns a 1×8 placeholder (no crash)
func test_empty_word_returns_placeholder() -> void:
	var img: Image = LVBitmapGlyphs.render_word_image("", Color.WHITE)
	assert_eq(img.get_width(), 1)
	assert_eq(img.get_height(), LVBitmapGlyphs.GLYPH_H)

# render_word_texture produces a valid ImageTexture
func test_render_word_texture_is_valid() -> void:
	var tex: ImageTexture = LVBitmapGlyphs.render_word_texture("mura", Color.WHITE)
	assert_not_null(tex)
	assert_true(tex.get_width() > 0)
	assert_eq(tex.get_height(), LVBitmapGlyphs.GLYPH_H)

# Color is applied (lit pixels use the given color, not white default)
func test_glyph_image_respects_color() -> void:
	var red := Color(1.0, 0.0, 0.0, 1.0)
	var img: Image = LVBitmapGlyphs.glyph_image("a", red)
	# Find a lit pixel and confirm its color
	var found: bool = false
	for y in img.get_height():
		for x in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a > 0.5:
				assert_almost_eq(p.r, 1.0, 0.01)
				assert_almost_eq(p.g, 0.0, 0.01)
				assert_almost_eq(p.b, 0.0, 0.01)
				found = true
				break
		if found:
			break
	assert_true(found, "Should find at least one lit pixel in 'a'")

# All 4 baker glyphs render without crash
func test_baker_glyphs_render() -> void:
	for word in ["mura", "tola", "ven", "ka"]:
		var img: Image = LVBitmapGlyphs.render_word_image(word, Color.WHITE)
		assert_gt(img.get_width(), 0, "Failed to render '%s'" % word)
