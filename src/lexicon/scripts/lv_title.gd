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
	# Background (warm parchment)
	var bg := ColorRect.new()
	bg.color = Color(0.83, 0.74, 0.55, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	# Decorative borders (sun-bleached pages feel)
	var top_band := ColorRect.new()
	top_band.color = Color(0.7, 0.55, 0.35, 1.0)
	top_band.size = Vector2(320, 4)
	top_band.position = Vector2(0, 0)
	add_child(top_band)
	var bot_band := ColorRect.new()
	bot_band.color = Color(0.7, 0.55, 0.35, 1.0)
	bot_band.size = Vector2(320, 4)
	bot_band.position = Vector2(0, 176)
	add_child(bot_band)
	# Title text centered
	var title := Label.new()
	title.text = "字典村莊"
	title.size = Vector2(320, 40)
	title.position = Vector2(0, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08, 1.0))
	add_child(title)
	# Subtitle centered
	var subtitle := Label.new()
	subtitle.text = "Lexicon Village"
	subtitle.size = Vector2(320, 18)
	subtitle.position = Vector2(0, 84)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.3, 0.18, 1.0))
	add_child(subtitle)
	# Tagline
	var tagline := Label.new()
	tagline.text = "一個下午學會一門陌生語言"
	tagline.size = Vector2(320, 14)
	tagline.position = Vector2(0, 108)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 10)
	tagline.add_theme_color_override("font_color", Color(0.4, 0.28, 0.16, 0.85))
	add_child(tagline)
	# Start button
	_start_btn = Button.new()
	_start_btn.text = "  開始  "
	_start_btn.size = Vector2(70, 24)
	_start_btn.position = Vector2(125, 134)
	_start_btn.add_theme_font_size_override("font_size", 12)
	_start_btn.pressed.connect(_on_start_pressed)
	add_child(_start_btn)
	# Footer hint
	var footer := Label.new()
	footer.text = "Enter 開始 · N 開筆記本 · Esc 關閉"
	footer.size = Vector2(320, 12)
	footer.position = Vector2(0, 162)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 8)
	footer.add_theme_color_override("font_color", Color(0.4, 0.28, 0.16, 0.7))
	add_child(footer)
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
