## Title / start screen for 一字一句 (Word Suika).
##
## A deliberate one-tap start: it teaches the goal (the merge ladder 雨→…→詩),
## shows the best score to beat, and — crucially on Web — the start click is the
## user gesture the browser requires before any audio can play, so the game's
## first sound lands cleanly on the first drop.
extends Node2D

const TierData = preload("res://scripts/tier_data.gd")
const WSHiScore = preload("res://scripts/hiscore.gd")

const VIEWPORT_W: float = 540.0
const VIEWPORT_H: float = 960.0

var _start_label: Label = null
var _pulse_t: float = 0.0

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	# Background wash — same warm parchment-dark as the play field.
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.14, 1.0)
	bg.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	ui.add_child(bg)

	# Title
	var title := Label.new()
	title.text = "一字一句"
	title.position = Vector2(0, 210)
	title.size = Vector2(VIEWPORT_W, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.52, 1.0))
	ui.add_child(title)

	# Tagline
	var tag := Label.new()
	tag.text = "同字相疊，疊成一首詩"
	tag.position = Vector2(0, 308)
	tag.size = Vector2(VIEWPORT_W, 32)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.72, 0.66, 0.55, 0.9))
	ui.add_child(tag)

	# Merge-ladder preview — the goal, shown as coloured glyphs with arrows.
	_build_ladder_preview(ui)

	# Best score (only if one exists)
	var best: int = WSHiScore.load_best()
	if best > 0:
		var best_lbl := Label.new()
		best_lbl.text = "最佳 %d" % best
		best_lbl.position = Vector2(0, 560)
		best_lbl.size = Vector2(VIEWPORT_W, 30)
		best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best_lbl.add_theme_font_size_override("font_size", 24)
		best_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 0.9))
		ui.add_child(best_lbl)

	# Pulsing start prompt
	_start_label = Label.new()
	_start_label.text = "點擊開始"
	_start_label.position = Vector2(0, 680)
	_start_label.size = Vector2(VIEWPORT_W, 40)
	_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_label.add_theme_font_size_override("font_size", 30)
	_start_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.62, 1.0))
	ui.add_child(_start_label)

func _build_ladder_preview(ui: CanvasLayer) -> void:
	var count: int = TierData.TIER_COUNT
	var margin: float = 30.0
	var step: float = (VIEWPORT_W - margin * 2.0) / float(count)
	var y: float = 430.0
	for i in count:
		var lbl := Label.new()
		lbl.text = TierData.get_char(i)
		lbl.position = Vector2(margin + step * float(i), y)
		lbl.size = Vector2(step, 44)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Bigger toward 詩 so the climb reads visually.
		lbl.add_theme_font_size_override("font_size", int(lerpf(22.0, 34.0, float(i) / float(count - 1))))
		lbl.add_theme_color_override("font_color", TierData.get_color(i))
		ui.add_child(lbl)

func _process(delta: float) -> void:
	_pulse_t += delta
	if _start_label:
		_start_label.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_pulse_t * 3.0))

func _input(event: InputEvent) -> void:
	var go: bool = false
	if event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			go = true
	if go:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
