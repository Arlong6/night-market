## Title screen for Night Market Runner.
## First scene the player sees. Displays game title and a single START button.
## Calls Game.reset_run() to clear any prior session before entering play.
##
## Font note: Chinese title text uses AA-ON SystemFont for CJK glyph readability.
## Post-MVP: replace with a CJK-supporting pixel BMFont to unify the look.
## Story 010.
class_name TitleScreen
extends Control

const COLOUR_BG: Color = Color("#1A0A00")
const COLOUR_STAMP_RED: Color = Color("#C2241A")
const COLOUR_CREAM: Color = Color("#F5EDDA")
const COLOUR_INK: Color = Color("#2A1A0A")

var _start_button: Button


func _ready() -> void:
	_build_ui()
	_start_button.grab_focus()


func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg: ColorRect = ColorRect.new()
	bg.color = COLOUR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title_label: Label = Label.new()
	title_label.text = "夜市大冒險"
	title_label.add_theme_font_override("font", _make_cjk_font())
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	title_label.add_theme_constant_override("outline_size", 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0.0, 48.0)
	title_label.size = Vector2(320.0, 24.0)
	add_child(title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "NIGHT MARKET RUNNER"
	sub_label.add_theme_font_override("font", _make_cjk_font())
	sub_label.add_theme_font_size_override("font_size", 10)
	sub_label.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	sub_label.add_theme_constant_override("outline_size", 0)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.position = Vector2(0.0, 74.0)
	sub_label.size = Vector2(320.0, 14.0)
	add_child(sub_label)

	_start_button = _make_stamp_button("START", Vector2(128.0, 120.0), Vector2(64.0, 20.0))
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)


func _make_stamp_button(label_text: String, pos: Vector2, p_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.position = pos
	btn.size = p_size
	btn.focus_mode = Control.FOCUS_ALL

	btn.add_theme_stylebox_override("normal",   _make_stamp_stylebox(COLOUR_CREAM, COLOUR_INK, false))
	btn.add_theme_stylebox_override("hover",    _make_stamp_stylebox(COLOUR_CREAM, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("focus",    _make_stamp_stylebox(COLOUR_CREAM, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("pressed",  _make_stamp_stylebox(Color(0.9, 0.87, 0.8), COLOUR_INK, true))
	btn.add_theme_stylebox_override("disabled", _make_stamp_stylebox(Color(0.6, 0.6, 0.6), COLOUR_INK, false))

	btn.add_theme_font_override("font", _make_cjk_font())
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	btn.add_theme_color_override("font_color_hover", COLOUR_INK)
	btn.add_theme_color_override("font_color_pressed", COLOUR_INK)
	btn.add_theme_color_override("font_color_focus", COLOUR_INK)
	return btn


func _make_stamp_stylebox(fill: Color, border_colour: Color, thick_border: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border_colour
	var border_w: int = 2 if thick_border else 1
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)
	return sb


func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	# Explicit CJK-capable fallback chain — macOS PingFang, Windows 微軟正黑,
	# Linux Noto Sans CJK. Without explicit names, SystemFont may pick a
	# non-CJK font and render Chinese as boxes or wrong glyphs.
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_LIGHT
	return f


func _on_start_pressed() -> void:
	Game.reset_run()
	Game.goto_level("shilin")
