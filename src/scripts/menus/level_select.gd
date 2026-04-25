## Level Select screen for Night Market Runner.
## Shows three level cards: Shilin (selectable), Fengjia + Liouho (locked).
## Card press loads the chosen level via Game.goto_level(slug).
## Back button returns to title screen.
## Story 010.
class_name LevelSelectScreen
extends Control

const COLOUR_BG: Color = Color("#1A0A00")
const COLOUR_STAMP_RED: Color = Color("#C2241A")
const COLOUR_CREAM: Color = Color("#F5EDDA")
const COLOUR_INK: Color = Color("#2A1A0A")

const LEVEL_CARDS: Array = [
	{"slug": "shilin",  "name": "士林",  "colour": Color("#8B1A1A"), "locked": false},
	{"slug": "fengjia", "name": "逢甲",  "colour": Color("#C2607A"), "locked": true},
	{"slug": "liouho",  "name": "六合",  "colour": Color("#1A3060"), "locked": true},
]

const CARD_W: float = 72.0
const CARD_H: float = 60.0
const CARD_GAP: float = 12.0

var _back_button: Button


func _ready() -> void:
	_build_ui()
	var first_card: Button = _find_first_unlocked_card()
	if first_card:
		first_card.grab_focus()
	else:
		_back_button.grab_focus()


func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg: ColorRect = ColorRect.new()
	bg.color = COLOUR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var header: Label = Label.new()
	header.text = "SELECT LEVEL"
	header.add_theme_font_override("font", _make_cjk_font())
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	header.add_theme_constant_override("outline_size", 0)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0.0, 20.0)
	header.size = Vector2(320.0, 14.0)
	add_child(header)

	var total_w: float = LEVEL_CARDS.size() * CARD_W + (LEVEL_CARDS.size() - 1) * CARD_GAP
	var start_x: float = (320.0 - total_w) / 2.0
	var card_y: float = 55.0

	for i: int in range(LEVEL_CARDS.size()):
		var card_def: Dictionary = LEVEL_CARDS[i]
		var card_x: float = start_x + i * (CARD_W + CARD_GAP)
		_build_card(card_def, Vector2(card_x, card_y))

	_back_button = _make_stamp_button("BACK", Vector2(128.0, 148.0), Vector2(64.0, 18.0))
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)


func _build_card(card_def: Dictionary, pos: Vector2) -> Button:
	var is_locked: bool = card_def["locked"]
	var slug: String = card_def["slug"]
	var display_name: String = card_def["name"]
	var accent: Color = card_def["colour"]

	var btn: Button = Button.new()
	btn.position = pos
	btn.size = Vector2(CARD_W, CARD_H)
	btn.focus_mode = Control.FOCUS_ALL
	btn.disabled = is_locked

	var fill_colour: Color = accent if not is_locked else accent.darkened(0.5)
	fill_colour.a = 1.0 if not is_locked else 0.5

	btn.add_theme_stylebox_override("normal",   _make_card_stylebox(fill_colour, COLOUR_INK, false))
	btn.add_theme_stylebox_override("hover",    _make_card_stylebox(fill_colour, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("focus",    _make_card_stylebox(fill_colour, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("pressed",  _make_card_stylebox(fill_colour.darkened(0.1), COLOUR_INK, true))
	btn.add_theme_stylebox_override("disabled", _make_card_stylebox(fill_colour, Color(0.4, 0.4, 0.4), false))

	var name_lbl: Label = Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_override("font", _make_cjk_font())
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", COLOUR_CREAM)
	name_lbl.add_theme_constant_override("outline_size", 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if is_locked:
		var lock_lbl: Label = Label.new()
		lock_lbl.text = "SOON"
		lock_lbl.add_theme_font_override("font", _make_cjk_font())
		lock_lbl.add_theme_font_size_override("font_size", 8)
		lock_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
		lock_lbl.add_theme_constant_override("outline_size", 0)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.position = Vector2(0.0, CARD_H - 16.0)
		lock_lbl.size = Vector2(CARD_W, 12.0)
		btn.add_child(lock_lbl)

	btn.add_child(name_lbl)

	if not is_locked:
		btn.pressed.connect(_on_card_pressed.bind(slug))

	add_child(btn)
	return btn


func _find_first_unlocked_card() -> Button:
	for child: Node in get_children():
		if child is Button and not (child as Button).disabled:
			if child != _back_button:
				return child as Button
	return null


func _make_stamp_button(label_text: String, pos: Vector2, p_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.position = pos
	btn.size = p_size
	btn.focus_mode = Control.FOCUS_ALL

	btn.add_theme_stylebox_override("normal",  _make_card_stylebox(COLOUR_CREAM, COLOUR_INK, false))
	btn.add_theme_stylebox_override("hover",   _make_card_stylebox(COLOUR_CREAM, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("focus",   _make_card_stylebox(COLOUR_CREAM, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("pressed", _make_card_stylebox(Color(0.9, 0.87, 0.8), COLOUR_INK, true))

	btn.add_theme_font_override("font", _make_cjk_font())
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	btn.add_theme_color_override("font_color_hover", COLOUR_INK)
	btn.add_theme_color_override("font_color_pressed", COLOUR_INK)
	btn.add_theme_color_override("font_color_focus", COLOUR_INK)
	return btn


func _make_card_stylebox(fill: Color, border_colour: Color, thick_border: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border_colour
	var border_w: int = 2 if thick_border else 1
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)
	return sb


func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_LIGHT
	return f


func _on_card_pressed(slug: String) -> void:
	Game.goto_level(slug)


func _on_back_pressed() -> void:
	Game.goto_level("title")
