## Title — start gate (Web audio-unlock gesture) for 橫衝直撞.
extends Node2D

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "橫衝直撞"
	title.position = Vector2(0, 170)
	title.size = Vector2(960, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#F2C14E"))
	ui.add_child(title)
	var start := Label.new()
	start.text = "點擊開始　·　WASD / 方向鍵 駕駛"
	start.position = Vector2(0, 320)
	start.size = Vector2(960, 40)
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.add_theme_font_size_override("font_size", 24)
	start.add_theme_color_override("font_color", Color("#E8E2D0"))
	ui.add_child(start)
	# Best score to beat (if any).
	const ScoreSystem = preload("res://scripts/score_system.gd")
	var best: int = ScoreSystem.new().load_best()
	if best > 0:
		var b := Label.new()
		b.text = "最佳 %d" % best
		b.position = Vector2(0, 380)
		b.size = Vector2(960, 30)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color("#C8BC90"))
		ui.add_child(b)

func _input(event: InputEvent) -> void:
	var go: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if go:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
