## Diegetic receipt-style HUD for Night Market Runner.
## Displays SCORE / TIME / DEATHS on a cream receipt strip in the top-left.
## Listens to Game singleton signals; polls session_time each frame.
## Story 008 (Visual/Feel).
class_name Hud
extends CanvasLayer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const HUD_LAYER: int = 10
const STRIP_W: float = 128.0
const STRIP_H: float = 24.0
const STRIP_POS: Vector2 = Vector2(2.0, 2.0)
## 10px font for crisp readable digits. Prefixes ("SCORE"/"TIME") are dropped
## — position alone carries meaning (left=score, centre=time, right=deaths),
## matching arcade HUD convention. Post-MVP BMFont swap can re-add prefixes.
const FONT_SIZE: int = 10

## Art-bible §4D UI palette.
const COLOUR_CREAM: Color = Color("#F5EDDA")
const COLOUR_STAMP_RED: Color = Color("#C2241A")
const COLOUR_INK: Color = Color("#2A1A0A")

# ---------------------------------------------------------------------------
# Private node references (created in _ready)
# ---------------------------------------------------------------------------

var _root: Control
var _score_label: Label
var _time_label: Label
var _deaths_label: Label

## Cached crisp-pixel font — TTF with anti-aliasing disabled so labels
## render pixel-sharp, matching art-bible §8J pixel aesthetic.
var _pixel_font: SystemFont

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = HUD_LAYER
	_build_ui()
	_connect_game_signals()
	_refresh_score(Game.score)
	_refresh_deaths(Game.deaths)
	_refresh_time(Game.session_time)


func _process(_delta: float) -> void:
	_refresh_time(Game.session_time)

# ---------------------------------------------------------------------------
# Public API (Story 010 menus will call this)
# ---------------------------------------------------------------------------

## Show/hide the HUD — menus hide it during non-gameplay screens.
func set_visible_for_gameplay(is_visible: bool) -> void:
	visible = is_visible

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_pixel_font = _make_pixel_font()

	_root = Control.new()
	_root.name = "Receipt"
	_root.position = STRIP_POS
	_root.size = Vector2(STRIP_W, STRIP_H)
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	var bg: ColorRect = ColorRect.new()
	bg.color = COLOUR_CREAM
	bg.size = Vector2(STRIP_W, STRIP_H)
	bg.position = Vector2.ZERO
	_root.add_child(bg)

	var border: ColorRect = ColorRect.new()
	border.color = COLOUR_INK
	border.size = Vector2(STRIP_W, 1.0)
	border.position = Vector2(0.0, STRIP_H - 1.0)
	_root.add_child(border)

	# Layout: three sections inside the 128-wide strip.
	# Prefixes dropped — position carries meaning (left=score, centre=time,
	# right=deaths). At 10px monospace, digits ~6px wide:
	#   "0000" ~28px  |  "0:00" ~28px  |  "D 0" ~18px
	# Sections evenly divided with small internal gutters.
	_score_label  = _make_label("0000", Vector2(4.0, 0.0),   Vector2(40.0, 23.0), HORIZONTAL_ALIGNMENT_LEFT)
	_time_label   = _make_label("0:00", Vector2(44.0, 0.0),  Vector2(40.0, 23.0), HORIZONTAL_ALIGNMENT_CENTER)
	# Using "D" prefix for deaths (✗ glyph not guaranteed in default font — swap
	# to ✗ after Story 011 replaces placeholder font with BMFont).
	_deaths_label = _make_label("D 0",  Vector2(88.0, 0.0),  Vector2(36.0, 23.0), HORIZONTAL_ALIGNMENT_RIGHT)


## Creates a SystemFont with anti-aliasing disabled for crisp pixel rendering.
func _make_pixel_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "Courier", "Monaco", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.force_autohinter = false
	return f


func _make_label(
	text: String,
	pos: Vector2,
	p_size: Vector2,
	h_align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = p_size
	lbl.horizontal_alignment = h_align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(lbl)
	return lbl


func _connect_game_signals() -> void:
	Game.score_changed.connect(_refresh_score)
	Game.deaths_changed.connect(_refresh_deaths)


func _refresh_score(new_score: int) -> void:
	_score_label.text = "%04d" % new_score


func _refresh_deaths(new_deaths: int) -> void:
	_deaths_label.text = "D %d" % new_deaths


func _refresh_time(t: float) -> void:
	var total_seconds: int = int(t)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	_time_label.text = "%d:%02d" % [minutes, seconds]
