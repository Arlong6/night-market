## Title screen for Night Market Shopping (R-009).
##
## Centred vbox: title (16pt) + English subtitle (8pt) + quest hint (8pt) +
## START button (12pt). On START: resets Inventory + Game state and routes
## to Shilin Market. CJK SystemFont chain ensures Chinese renders correctly
## across macOS / Windows / Linux without bundling a TTF.
class_name TitleScreen
extends Control

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180

const COLOR_TITLE: Color = Color("#F5EDDA")
const COLOR_SUBTITLE: Color = Color("#888888")
const COLOR_QUEST: Color = Color("#F2A227")


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	Game.current_area = "title"
	Music.stop()  # silent title; market loop kicks in on START
	_build_ui()


func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	vbox.position = Vector2.ZERO
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var title: Label = _make_label("夜市採購大作戰", 16, COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle: Label = _make_label("Night Market Shopping", 8, COLOR_SUBTITLE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var quest: Label = _make_label("媽媽叫你去夜市買 5 樣食材", 10, COLOR_QUEST)
	quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(quest)

	# Spacer
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	var start_button: Button = Button.new()
	start_button.text = "  START  "
	start_button.add_theme_font_override("font", _make_cjk_font())
	start_button.add_theme_font_size_override("font_size", 12)
	start_button.add_theme_color_override("font_color", COLOR_TITLE)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)
	start_button.grab_focus.call_deferred()


func _on_start_pressed() -> void:
	Inventory.reset()
	Game.reset_run()
	Game.goto_level("shilin")


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _make_cjk_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return f
