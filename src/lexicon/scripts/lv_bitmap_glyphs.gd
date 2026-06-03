## LVBitmapGlyphs — Hand-encoded 8×8 pixel font for unresolved lexicon glyphs.
##
## Each character is 8 rows × 8 bits, MSB = leftmost pixel. 1 = lit, 0 = transparent.
## Designed for lowercase ASCII used by SEED_GLYPHS + LVProcGen output:
##   vowels:     a e i o u
##   consonants: m n t k p v s r l d
##   misc:       . ? _ space + digits 0-9 (for collision suffixes)
##
## Use [method render_word_image] to get an Image of a complete word ready to
## convert into an ImageTexture and assign to a TextureRect (LVDialogueDisplay
## swaps between this and the CJK font Label based on resolved/unresolved state).
##
## Style: blocky, slightly archaic — reads as "engraved" rather than "typed".
## Bounding box: rows 1-7 (skip top row), columns 0-5 (right 2 cols padding).
class_name LVBitmapGlyphs
extends RefCounted

const GLYPH_W: int = 8
const GLYPH_H: int = 8
const KERN: int = 1  # pixel gap between characters

# 8 bytes per glyph, top row → bottom row. Bit 7 = leftmost pixel.
const GLYPH_DATA: Dictionary = {
	# ─── Vowels ───────────────────────────────────────────────────────────────
	"a": [0x00, 0x00, 0x00, 0x38, 0x04, 0x3C, 0x44, 0x3C],
	"e": [0x00, 0x00, 0x00, 0x38, 0x44, 0x7C, 0x40, 0x38],
	"i": [0x00, 0x10, 0x00, 0x30, 0x10, 0x10, 0x10, 0x38],
	"o": [0x00, 0x00, 0x00, 0x38, 0x44, 0x44, 0x44, 0x38],
	"u": [0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x44, 0x3C],

	# ─── Consonants ───────────────────────────────────────────────────────────
	"m": [0x00, 0x00, 0x00, 0x6C, 0x92, 0x92, 0x92, 0x92],
	"n": [0x00, 0x00, 0x00, 0x78, 0x44, 0x44, 0x44, 0x44],
	"t": [0x00, 0x20, 0x20, 0x70, 0x20, 0x20, 0x24, 0x18],
	"k": [0x00, 0x40, 0x40, 0x48, 0x50, 0x60, 0x50, 0x48],
	"p": [0x00, 0x00, 0x00, 0x78, 0x44, 0x44, 0x78, 0x40],
	"v": [0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x28, 0x10],
	"s": [0x00, 0x00, 0x00, 0x3C, 0x40, 0x38, 0x04, 0x78],
	"r": [0x00, 0x00, 0x00, 0x58, 0x64, 0x40, 0x40, 0x40],
	"l": [0x00, 0x60, 0x20, 0x20, 0x20, 0x20, 0x20, 0x70],
	"d": [0x00, 0x04, 0x04, 0x3C, 0x44, 0x44, 0x44, 0x3C],

	# ─── Punctuation + space + suffix chars ───────────────────────────────────
	".": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x30],
	"?": [0x00, 0x38, 0x44, 0x04, 0x08, 0x10, 0x00, 0x10],
	"_": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC],
	" ": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],

	# ─── Digits (for procgen collision suffixes like `mura_2`) ────────────────
	"0": [0x00, 0x38, 0x44, 0x4C, 0x54, 0x64, 0x44, 0x38],
	"1": [0x00, 0x10, 0x30, 0x10, 0x10, 0x10, 0x10, 0x38],
	"2": [0x00, 0x38, 0x44, 0x04, 0x08, 0x10, 0x20, 0x7C],
	"3": [0x00, 0x38, 0x44, 0x04, 0x18, 0x04, 0x44, 0x38],
	"4": [0x00, 0x08, 0x18, 0x28, 0x48, 0x7C, 0x08, 0x08],
	"5": [0x00, 0x7C, 0x40, 0x78, 0x04, 0x04, 0x44, 0x38],
	"6": [0x00, 0x38, 0x40, 0x40, 0x78, 0x44, 0x44, 0x38],
	"7": [0x00, 0x7C, 0x04, 0x08, 0x10, 0x20, 0x20, 0x20],
	"8": [0x00, 0x38, 0x44, 0x44, 0x38, 0x44, 0x44, 0x38],
	"9": [0x00, 0x38, 0x44, 0x44, 0x3C, 0x04, 0x04, 0x38],
}

## Render a single glyph as an 8×8 Image. Lit pixels use `color`; transparent
## pixels are RGBA(0,0,0,0). Unknown chars return a tofu box (frame only).
static func glyph_image(c: String, color: Color = Color.WHITE) -> Image:
	var img := Image.create(GLYPH_W, GLYPH_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rows: Variant = GLYPH_DATA.get(c, null)
	if rows == null:
		# Tofu box: draw 8x8 frame
		for x in GLYPH_W:
			img.set_pixel(x, 0, color)
			img.set_pixel(x, GLYPH_H - 1, color)
		for y in GLYPH_H:
			img.set_pixel(0, y, color)
			img.set_pixel(GLYPH_W - 1, y, color)
		return img
	for y in GLYPH_H:
		var row: int = rows[y]
		for x in GLYPH_W:
			if (row >> (7 - x)) & 1 == 1:
				img.set_pixel(x, y, color)
	return img

## Render a whole word as a single Image (concatenated 8×8 glyphs + KERN gap).
## Width = N glyphs × (GLYPH_W + KERN) − KERN. Height = GLYPH_H.
static func render_word_image(word: String, color: Color = Color.WHITE) -> Image:
	if word.is_empty():
		return Image.create(1, GLYPH_H, false, Image.FORMAT_RGBA8)
	var n: int = word.length()
	var w: int = n * (GLYPH_W + KERN) - KERN
	var img := Image.create(w, GLYPH_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in n:
		var ch: String = word.substr(i, 1)
		var g: Image = glyph_image(ch, color)
		var x_off: int = i * (GLYPH_W + KERN)
		img.blit_rect(g, Rect2i(0, 0, GLYPH_W, GLYPH_H), Vector2i(x_off, 0))
	return img

## Convenience — directly produce an ImageTexture for a word.
static func render_word_texture(word: String, color: Color = Color.WHITE) -> ImageTexture:
	return ImageTexture.create_from_image(render_word_image(word, color))

## True if the given character has hand-encoded pixel data.
static func has_glyph(c: String) -> bool:
	return GLYPH_DATA.has(c)

## How many characters are supported by this font.
static func supported_char_count() -> int:
	return GLYPH_DATA.size()
