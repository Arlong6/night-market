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
	bg.color = Color(0.78, 0.7, 0.55, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	# Header
	var header := Label.new()
	header.text = "謝謝你來過"
	header.position = Vector2(110, 10)
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)
	# Dictionary panel
	_dict_label = Label.new()
	_dict_label.text = ""
	_dict_label.position = Vector2(20, 35)
	_dict_label.add_theme_font_size_override("font_size", 8)
	add_child(_dict_label)
	# Time
	_time_label = Label.new()
	_time_label.text = ""
	_time_label.position = Vector2(20, 140)
	_time_label.add_theme_font_size_override("font_size", 10)
	add_child(_time_label)
	# Return button
	_return_btn = Button.new()
	_return_btn.text = "再來一次"
	_return_btn.position = Vector2(120, 155)
	_return_btn.size = Vector2(80, 18)
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
