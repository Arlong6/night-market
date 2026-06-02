## LVGlyphFont — Pragmatic "pixel" glyph font for #5 Glyph Font Rendering.
##
## True 8×8 bitmap fonts (per cascade-shimmer.md design) require hand-authored
## pixel data per character. As an MVP-shippable approximation, we clone the
## project's default CJK font with antialiasing/hinting/subpixel-positioning
## disabled at a small font size. Result reads as "pixel-ish" without bespoke
## bitmap data, while preserving full character coverage (CJK + ASCII).
##
## Used by LVDialogueDisplay for unresolved LEXICON_SLOT tokens (the glyph
## form the player decodes). Resolved tokens render with the normal CJK font
## so 麵包 still looks like rich CJK type.
##
## See: design/gdd/cascade-shimmer.md Visual/Audio Requirements,
##      cascade-shimmer-overshoot at 16-bit pixel palette discussion.
class_name LVGlyphFont
extends RefCounted

const SOURCE_FONT_PATH: String = "res://assets/fonts/jf-openhuninn-2.1.ttf"

## Pixel-mode font size (small enough to read as "pixel art" at 1× scale).
const PIXEL_FONT_SIZE: int = 10

static var _cached_pixel_font: FontFile = null

## Return the pixel-mode font (cached). Returns null if source font missing.
static func get_pixel_font() -> FontFile:
	if _cached_pixel_font != null:
		return _cached_pixel_font
	var src: Resource = load(SOURCE_FONT_PATH)
	if src == null or not (src is FontFile):
		push_error("LVGlyphFont: failed to load source font at %s" % SOURCE_FONT_PATH)
		return null
	# Duplicate so we can tweak rendering without affecting the project default.
	var f: FontFile = (src as FontFile).duplicate() as FontFile
	if f == null:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.multichannel_signed_distance_field = false
	f.force_autohinter = false
	_cached_pixel_font = f
	return _cached_pixel_font

## Apply pixel-mode font + size to a Label. Idempotent / cheap to call.
static func apply_to_label(lbl: Label, size: int = PIXEL_FONT_SIZE) -> void:
	if lbl == null or not is_instance_valid(lbl):
		return
	var f: FontFile = get_pixel_font()
	if f == null:
		return
	lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", size)

## Remove the pixel-mode overrides (restore project default CJK rendering).
static func clear_label_overrides(lbl: Label) -> void:
	if lbl == null or not is_instance_valid(lbl):
		return
	lbl.remove_theme_font_override("font")
	lbl.remove_theme_font_size_override("font_size")

## Test hook — true if the cached pixel font has AA disabled.
static func is_pixel_font_anti_aliased() -> bool:
	var f: FontFile = get_pixel_font()
	if f == null:
		return false
	return f.antialiasing != TextServer.FONT_ANTIALIASING_NONE
