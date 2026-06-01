## LVEnding — Lexicon Village #18 Ending scene
##
## Programmatic Control scaffold. Shows dictionary + elapsed time + return button.
##
## See: design/gdd/game-concept-lexicon-village.md (ending described inline; #18 has no separate GDD yet)
class_name LVEnding
extends Control

const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

var _dict_label: Label = null
var _time_label: Label = null
var _return_btn: Button = null

func _ready() -> void:
	_build_layout()
	_populate_data()

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.83, 0.74, 0.55, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	# Header centered
	var header := Label.new()
	header.text = "謝謝你來過"
	header.size = Vector2(320, 24)
	header.position = Vector2(0, 12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1.0))
	add_child(header)
	# Dictionary panel (centered)
	_dict_label = Label.new()
	_dict_label.text = ""
	_dict_label.size = Vector2(280, 100)
	_dict_label.position = Vector2(20, 42)
	_dict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dict_label.add_theme_font_size_override("font_size", 10)
	_dict_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1, 1.0))
	add_child(_dict_label)
	# Time
	_time_label = Label.new()
	_time_label.text = ""
	_time_label.size = Vector2(320, 14)
	_time_label.position = Vector2(0, 144)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 10)
	_time_label.add_theme_color_override("font_color", Color(0.4, 0.28, 0.16, 0.9))
	add_child(_time_label)
	# Return button
	_return_btn = Button.new()
	_return_btn.text = "再來一次"
	_return_btn.size = Vector2(80, 22)
	_return_btn.position = Vector2(120, 158)
	_return_btn.add_theme_font_size_override("font_size", 11)
	_return_btn.pressed.connect(_on_return_pressed)
	add_child(_return_btn)
	_return_btn.grab_focus()

func _populate_data() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss == null:
		return
	var confirmed: Array = ss.get_confirmed_slots()
	var dict_lines := PackedStringArray()
	for slot_id in confirmed:
		var glyph: String = LVVignetteContent.SEED_GLYPHS.get(slot_id, "?")
		var resolved: String = LVVignetteContent.RESOLVED_STRINGS.get(slot_id, "?")
		dict_lines.append("%s = %s" % [glyph, resolved])
	if _dict_label:
		_dict_label.text = "你學會的詞：\n" + "\n".join(dict_lines) if not dict_lines.is_empty() else "你學會的詞：\n(無)"
	if _time_label:
		var ms: int = ss.session_elapsed_ms()
		var minutes: int = ms / 60000
		var seconds: int = (ms / 1000) % 60
		if minutes > 0:
			_time_label.text = "用時：%d 分 %d 秒" % [minutes, seconds]
		else:
			_time_label.text = "用時：%d 秒" % seconds

func _on_return_pressed() -> void:
	var boot = get_node_or_null("/root/LVBoot")
	if boot:
		boot.return_to_title()
