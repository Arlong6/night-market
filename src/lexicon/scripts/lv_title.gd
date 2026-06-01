## LVTitle — Lexicon Village #17 Title screen
##
## Programmatic Control scaffold. Hand-lettered title + Start button.
##
## See: design/gdd/title-screen.md
class_name LVTitle
extends Control

const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

var _start_btn: Button = null

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	# Background (parchment)
	var bg := ColorRect.new()
	bg.color = Color(0.85, 0.78, 0.65, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	# Title text
	var title := Label.new()
	title.text = "字典村莊"
	title.position = Vector2(110, 40)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Lexicon Village"
	subtitle.position = Vector2(120, 75)
	subtitle.add_theme_font_size_override("font_size", 10)
	add_child(subtitle)
	# Start button
	_start_btn = Button.new()
	_start_btn.text = "開始"
	_start_btn.position = Vector2(140, 110)
	_start_btn.size = Vector2(40, 20)
	_start_btn.pressed.connect(_on_start_pressed)
	add_child(_start_btn)
	# Default focus
	_start_btn.grab_focus()

func _on_start_pressed() -> void:
	# Tell Boot to start the game with baker content
	var boot = get_node_or_null("/root/LVBoot")
	if boot:
		boot.start_game(
			LVVignetteContent.CORRECT_TABLE,
			LVVignetteContent.SLOTS_IN_VIGNETTE
		)
