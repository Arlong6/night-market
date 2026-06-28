## Main — game director. Phase 3: player + camera + scattered destructibles +
## combo/score systems + HUD + impact shake. Later phases add city, wanted,
## police, juice.
extends Node2D

const Vehicle = preload("res://scripts/vehicle.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Destructible = preload("res://scripts/destructible.gd")
const ComboSystem = preload("res://scripts/combo_system.gd")
const ScoreSystem = preload("res://scripts/score_system.gd")

var _player: Vehicle = null
var _cam: CameraRig = null
var _combo := ComboSystem.new()
var _score := ScoreSystem.new()
var _best: int = 0

var _ui_score: Label = null
var _ui_combo: Label = null
var _ui_best: Label = null

func _ready() -> void:
	_best = _score.load_best()
	_player = Vehicle.new()
	_player.position = Vector2.ZERO
	add_child(_player)
	_cam = CameraRig.new()
	add_child(_cam)
	_cam.setup(_player)
	_scatter_props()
	_build_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_combo.tick(delta)
	if _ui_combo:
		_ui_combo.visible = _combo.is_active() and _combo.multiplier() > 1
		_ui_combo.text = "×%d 連擊!" % _combo.multiplier()

func _scatter_props() -> void:
	var kinds := ["prop", "prop", "prop", "car", "ped", "ped"]
	for i in 80:
		var d := Destructible.new()
		d.kind = kinds[i % kinds.size()]
		var p := Vector2(randf_range(-1100, 1100), randf_range(-800, 800))
		if p.length() < 120.0:
			p = p.normalized() * 160.0
		d.position = p
		d.destroyed.connect(_on_destroyed)
		add_child(d)

func _on_destroyed(kind: String, value: int, _heat: int, _pos: Vector2) -> void:
	var pts: int = _combo.register(value)
	_score.add(pts, 1)
	_cam.shake(0.25 if kind != "car" else 0.6)
	if kind == "car":
		_cam.punch(0.06)
	_refresh()

func _refresh() -> void:
	if _ui_score:
		_ui_score.text = "分數 %d" % _score.score
	if _ui_best:
		_ui_best.text = ("最佳 %d" % _best) if _best > 0 else ""

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_ui_score = _mk_label(ui, Vector2(20, 16), 28, Color("#F2E4B0"))
	_ui_best = _mk_label(ui, Vector2(740, 18), 18, Color("#C8BC90"))
	_ui_combo = _mk_label(ui, Vector2(20, 52), 24, Color("#FFB020"))
	_ui_combo.visible = false
	_refresh()

func _mk_label(ui: CanvasLayer, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(360, 36)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	ui.add_child(l)
	return l

func _draw() -> void:
	# Faint asphalt grid so speed and drift read clearly.
	var ext: float = 1600.0
	var step: float = 64.0
	var line_col := Color(1.0, 1.0, 1.0, 0.06)
	var x: float = -ext
	while x <= ext:
		draw_line(Vector2(x, -ext), Vector2(x, ext), line_col, 1.0)
		x += step
	var y: float = -ext
	while y <= ext:
		draw_line(Vector2(-ext, y), Vector2(ext, y), line_col, 1.0)
		y += step
