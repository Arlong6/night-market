## Main — game director. Phase 5: city + combo/score + HUD + wanted/heat +
## police that chase & ram + game-over/restart. Phase 6 adds the juice pass.
extends Node2D

const Vehicle = preload("res://scripts/vehicle.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Destructible = preload("res://scripts/destructible.gd")
const ComboSystem = preload("res://scripts/combo_system.gd")
const ScoreSystem = preload("res://scripts/score_system.gd")
const CityGen = preload("res://scripts/city_gen.gd")
const WantedSystem = preload("res://scripts/wanted_system.gd")
const Police = preload("res://scripts/police.gd")

var _player: Vehicle = null
var _cam: CameraRig = null
var _combo := ComboSystem.new()
var _score := ScoreSystem.new()
var _wanted := WantedSystem.new()
var _best: int = 0
var _police: Array[Police] = []
var _spawn_timer: float = 0.0
var _over: bool = false

var _ui_score: Label = null
var _ui_combo: Label = null
var _ui_best: Label = null
var _ui_stars: Label = null

func _ready() -> void:
	_best = _score.load_best()
	_build_city()
	_player = Vehicle.new()
	_player.position = Vector2(12, 12) * RRTuning.TILE + Vector2.ONE * (RRTuning.TILE * 0.5)
	_player.died.connect(_on_player_died)
	add_child(_player)
	_cam = CameraRig.new()
	add_child(_cam)
	_cam.setup(_player)
	_build_hud()
	queue_redraw()

func _process(delta: float) -> void:
	if _over:
		return
	_combo.tick(delta)
	_wanted.decay(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = RRTuning.POLICE_SPAWN_INTERVAL
		_manage_police()
	if _ui_combo:
		_ui_combo.visible = _combo.is_active() and _combo.multiplier() > 1
		_ui_combo.text = "×%d 連擊!" % _combo.multiplier()
	if _ui_stars:
		var s: int = _wanted.stars()
		_ui_stars.text = "通緝 " + "★".repeat(s) + "☆".repeat(5 - s)

# ── World ─────────────────────────────────────────────────────────────────────

func _build_city() -> void:
	var w: int = RRTuning.CITY_COLS * RRTuning.TILE
	var h: int = RRTuning.CITY_ROWS * RRTuning.TILE
	var bg := ColorRect.new()
	bg.color = Color("#2A2A30")
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

# ── Events ────────────────────────────────────────────────────────────────────

func _on_destroyed(kind: String, value: int, heat: int, _pos: Vector2) -> void:
	var pts: int = _combo.register(value)
	_score.add(pts, 1)
	_wanted.add_heat(heat)
	_cam.shake(0.25 if kind != "car" else 0.6)
	if kind == "car":
		_cam.punch(0.06)
	_refresh()

func _manage_police() -> void:
	_police = _police.filter(func(p): return is_instance_valid(p))
	var want: int = _wanted.stars() * RRTuning.POLICE_PER_STAR
	while _police.size() < want:
		var p := Police.new()
		p.target = _player
		var ang: float = randf_range(0.0, TAU)
		p.global_position = _player.global_position + Vector2.RIGHT.rotated(ang) * 600.0
		add_child(p)
		_police.append(p)

func _on_player_died() -> void:
	if _over:
		return
	_over = true
	var is_best: bool = _score.submit()
	if is_best:
		_best = _score.score
	var ui := CanvasLayer.new()
	add_child(ui)
	var l := Label.new()
	l.text = "被擊毀!\n分數 %d\n%s\n點擊重來" % [_score.score, ("★ 新紀錄! ★" if is_best else "最佳 %d" % _best)]
	l.size = Vector2(960, 320)
	l.position = Vector2(0, 120)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color("#FFD23F"))
	ui.add_child(l)

func _unhandled_input(event: InputEvent) -> void:
	if _over and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)):
		get_tree().reload_current_scene()

# ── HUD ───────────────────────────────────────────────────────────────────────

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
	_ui_stars = _mk_label(ui, Vector2(360, 16), 24, Color("#FF6060"))
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
	var line_col := Color(1.0, 0.95, 0.7, 0.05)
	var w: int = RRTuning.CITY_COLS * RRTuning.TILE
	var h: int = RRTuning.CITY_ROWS * RRTuning.TILE
	for cx in range(0, RRTuning.CITY_COLS + 1, 4):
		var x: float = cx * RRTuning.TILE
		draw_line(Vector2(x, 0), Vector2(x, h), line_col, 2.0)
	for cy in range(0, RRTuning.CITY_ROWS + 1, 4):
		var y: float = cy * RRTuning.TILE
		draw_line(Vector2(0, y), Vector2(w, y), line_col, 2.0)
