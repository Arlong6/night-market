## Main — game director. Phase 4: procedural city (road grid + buildings as walls
## + smashable props) + combo/score + HUD + impact shake. Later: wanted, police, juice.
extends Node2D

const Vehicle = preload("res://scripts/vehicle.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Destructible = preload("res://scripts/destructible.gd")
const ComboSystem = preload("res://scripts/combo_system.gd")
const ScoreSystem = preload("res://scripts/score_system.gd")
const CityGen = preload("res://scripts/city_gen.gd")

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
	_build_city()
	# Player starts on a central road intersection (cell 12,12 — both % 4 == 0).
	_player = Vehicle.new()
	_player.position = Vector2(12, 12) * RRTuning.TILE + Vector2.ONE * (RRTuning.TILE * 0.5)
	add_child(_player)
	_cam = CameraRig.new()
	add_child(_cam)
	_cam.setup(_player)
	_build_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_combo.tick(delta)
	if _ui_combo:
		_ui_combo.visible = _combo.is_active() and _combo.multiplier() > 1
		_ui_combo.text = "×%d 連擊!" % _combo.multiplier()

func _build_city() -> void:
	var w: int = RRTuning.CITY_COLS * RRTuning.TILE
	var h: int = RRTuning.CITY_ROWS * RRTuning.TILE
	var bg := ColorRect.new()
	bg.color = Color("#2A2A30")  # tarmac (roads are the gaps between buildings)
	bg.size = Vector2(w, h)
	bg.z_index = -100
	add_child(bg)
	var layout: Dictionary = CityGen.new().generate(randi())
	for cell in layout["buildings"]:
		_add_building(cell)
	for p in layout["props"]:
		_add_prop(p["cell"], p["kind"])

func _add_building(cell: Vector2i) -> void:
	var sb := StaticBody2D.new()
	sb.position = Vector2(cell) * RRTuning.TILE + Vector2.ONE * (RRTuning.TILE * 0.5)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * (RRTuning.TILE * 0.9)
	col.shape = shape
	sb.add_child(col)
	var hs: float = RRTuning.TILE * 0.45
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(hs, hs), Vector2(-hs, hs)])
	poly.color = Color("#5A5560")
	sb.add_child(poly)
	add_child(sb)

func _add_prop(cell: Vector2i, kind: String) -> void:
	var d := Destructible.new()
	d.kind = kind
	d.position = Vector2(cell) * RRTuning.TILE + Vector2.ONE * (RRTuning.TILE * 0.5)
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
	# Faint lane lines along the road cells so streets read at speed.
	var line_col := Color(1.0, 0.95, 0.7, 0.05)
	var w: int = RRTuning.CITY_COLS * RRTuning.TILE
	var h: int = RRTuning.CITY_ROWS * RRTuning.TILE
	for cx in range(0, RRTuning.CITY_COLS + 1, 4):
		var x: float = cx * RRTuning.TILE
		draw_line(Vector2(x, 0), Vector2(x, h), line_col, 2.0)
	for cy in range(0, RRTuning.CITY_ROWS + 1, 4):
		var y: float = cy * RRTuning.TILE
		draw_line(Vector2(0, y), Vector2(w, y), line_col, 2.0)
