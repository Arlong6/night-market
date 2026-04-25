## Level End screen for Night Market Runner.
## Displayed after the player reaches the goal. Reads final stats from Game
## autoload and animates the score with a coin-drop bounce Tween.
## Story 010.
class_name LevelEndScreen
extends Control

const COLOUR_BG: Color = Color("#1A0A00")
const COLOUR_STAMP_RED: Color = Color("#C2241A")
const COLOUR_CREAM: Color = Color("#F5EDDA")
const COLOUR_INK: Color = Color("#2A1A0A")

const SCORE_TWEEN_DURATION: float = 1.0

const LEVEL_ORDER: Array[String] = ["shilin", "fengjia", "liouho"]

const LEVEL_NAMES: Dictionary = {
	"shilin":  "士林夜市",
	"fengjia": "逢甲夜市",
	"liouho":  "六合夜市",
}

var _final_score: int = 0
var _score_label: Label
var _next_slug: String = ""


func _ready() -> void:
	_final_score = Game.score
	_next_slug = _resolve_next_slug(Game.current_level)
	_build_ui()
	_animate_score()


func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg: ColorRect = ColorRect.new()
	bg.color = COLOUR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var card: ColorRect = ColorRect.new()
	card.color = COLOUR_CREAM
	card.position = Vector2(80.0, 28.0)
	card.size = Vector2(160.0, 106.0)
	add_child(card)

	var level_name: String = LEVEL_NAMES.get(Game.current_level, Game.current_level)
	var name_lbl: Label = _make_card_label(level_name, Vector2(80.0, 32.0), Vector2(160.0, 18.0), 12, true)
	add_child(name_lbl)

	var divider: ColorRect = ColorRect.new()
	divider.color = COLOUR_INK
	divider.position = Vector2(84.0, 52.0)
	divider.size = Vector2(152.0, 1.0)
	add_child(divider)

	var score_row_lbl: Label = _make_card_label("SCORE", Vector2(84.0, 56.0), Vector2(60.0, 12.0), 8, false)
	add_child(score_row_lbl)
	_score_label = _make_numeric_label("0", Vector2(144.0, 56.0), Vector2(90.0, 12.0))
	add_child(_score_label)

	var time_row_lbl: Label = _make_card_label("TIME", Vector2(84.0, 72.0), Vector2(60.0, 12.0), 8, false)
	add_child(time_row_lbl)
	var time_val_lbl: Label = _make_numeric_label(_format_time(Game.session_time), Vector2(144.0, 72.0), Vector2(90.0, 12.0))
	add_child(time_val_lbl)

	var deaths_row_lbl: Label = _make_card_label("DEATHS", Vector2(84.0, 88.0), Vector2(60.0, 12.0), 8, false)
	add_child(deaths_row_lbl)
	var deaths_val_lbl: Label = _make_numeric_label(str(Game.deaths), Vector2(144.0, 88.0), Vector2(90.0, 12.0))
	add_child(deaths_val_lbl)

	var bottom_div: ColorRect = ColorRect.new()
	bottom_div.color = COLOUR_STAMP_RED
	bottom_div.position = Vector2(84.0, 118.0)
	bottom_div.size = Vector2(152.0, 2.0)
	add_child(bottom_div)

	var again_btn: Button = _make_stamp_button("AGAIN", Vector2(72.0, 148.0), Vector2(60.0, 18.0))
	again_btn.pressed.connect(_on_again_pressed)
	add_child(again_btn)

	var next_label_text: String = "NEXT" if not _next_slug.is_empty() else "MENU"
	var next_btn: Button = _make_stamp_button(next_label_text, Vector2(192.0, 148.0), Vector2(60.0, 18.0))
	next_btn.pressed.connect(_on_next_pressed)
	add_child(next_btn)

	again_btn.grab_focus()


func _make_card_label(text: String, pos: Vector2, p_size: Vector2, font_size: int, is_header: bool) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = p_size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_header else HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _make_cjk_font())
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COLOUR_STAMP_RED)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.clip_text = true
	return lbl


func _make_numeric_label(text: String, pos: Vector2, p_size: Vector2) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = p_size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _make_numeric_font())
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", COLOUR_INK)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.clip_text = true
	return lbl


func _make_stamp_button(label_text: String, pos: Vector2, p_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.position = pos
	btn.size = p_size
	btn.focus_mode = Control.FOCUS_ALL

	btn.add_theme_stylebox_override("normal",  _make_stamp_stylebox(COLOUR_CREAM, COLOUR_INK, false))
	btn.add_theme_stylebox_override("hover",   _make_stamp_stylebox(COLOUR_CREAM, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("focus",   _make_stamp_stylebox(COLOUR_CREAM, COLOUR_STAMP_RED, true))
	btn.add_theme_stylebox_override("pressed", _make_stamp_stylebox(Color(0.9, 0.87, 0.8), COLOUR_INK, true))

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
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_LIGHT
	return f


func _make_numeric_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "Courier", "Monaco", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	f.force_autohinter = false
	return f


func _resolve_next_slug(current: String) -> String:
	var idx: int = LEVEL_ORDER.find(current)
	if idx == -1 or idx >= LEVEL_ORDER.size() - 1:
		return ""
	var candidate: String = LEVEL_ORDER[idx + 1]
	if Game.LEVEL_PATHS.has(candidate):
		return candidate
	return ""


func _format_time(t: float) -> String:
	var total_seconds: int = int(t)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%d:%02d" % [minutes, seconds]


func _animate_score() -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_method(
		func(v: float) -> void:
			_score_label.text = str(int(v)),
		0.0,
		float(_final_score),
		SCORE_TWEEN_DURATION
	)


func _on_again_pressed() -> void:
	Game.restart_level()


func _on_next_pressed() -> void:
	if not _next_slug.is_empty():
		Game.goto_level(_next_slug)
	else:
		Game.goto_level("title")
