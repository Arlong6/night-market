## FPMain — first-person 3D destruction-driving spike for 橫衝直撞.
## Reuses the engine-agnostic logic units (CityGen, ComboSystem, ScoreSystem) in
## a 3D world built from primitive meshes (no art assets). Endless rampage — no
## death — so a run lasts as long as you want (addresses "crash ends the game").
extends Node3D

const FPCar = preload("res://scripts/fp_car.gd")
const FPTarget = preload("res://scripts/fp_target.gd")
const CityGen = preload("res://scripts/city_gen.gd")
const ComboSystem = preload("res://scripts/combo_system.gd")
const ScoreSystem = preload("res://scripts/score_system.gd")

const TILE3D: float = 12.0

var _car: FPCar = null
var _combo := ComboSystem.new()
var _score := ScoreSystem.new()
var _best: int = 0
var _smashed: int = 0
var _rng := RandomNumberGenerator.new()

var _ui_score: Label = null
var _ui_combo: Label = null
var _ui_best: Label = null
var _ui_speed: Label = null

func _ready() -> void:
	_rng.randomize()
	_best = _score.load_best()
	_build_environment()
	_build_ground()
	_build_city()
	_spawn_car()
	_build_hud()

func _process(delta: float) -> void:
	_combo.tick(delta)
	if _ui_combo:
		_ui_combo.visible = _combo.is_active() and _combo.multiplier() > 1
		_ui_combo.text = "×%d 連擊!" % _combo.multiplier()
	if _ui_speed and is_instance_valid(_car):
		_ui_speed.text = "%d km/h" % int(_car.speed() * 3.6)

# ── World ─────────────────────────────────────────────────────────────────────

func _world_pos(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE3D, 0.0, cell.y * TILE3D)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#171720")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9AA0B4")
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color("#171720")
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.15
	add_child(sun)

func _build_ground() -> void:
	var span: float = RRTuning.CITY_COLS * TILE3D
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(span + 60.0, 2.0, span + 60.0)
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#26262C")
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	body.position = Vector3(span * 0.5, -1.0, span * 0.5)  # top at y=0
	add_child(body)

func _build_city() -> void:
	var layout: Dictionary = CityGen.new().generate(_rng.randi())
	for cell in layout["buildings"]:
		_add_building(cell)
	for p in layout["props"]:
		_add_target(p["cell"], p["kind"], Vector3.ZERO)
	_spawn_traffic(14)

func _add_building(cell: Vector2i) -> void:
	var height: float = _rng.randf_range(8.0, 28.0)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE3D * 0.82, height, TILE3D * 0.82)
	col.shape = shape
	sb.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	var mat := StandardMaterial3D.new()
	var shade: float = _rng.randf_range(0.30, 0.46)
	mat.albedo_color = Color(shade, shade, shade + 0.05)
	bm.material = mat
	mi.mesh = bm
	sb.add_child(mi)
	sb.position = _world_pos(cell) + Vector3(0.0, height * 0.5, 0.0)
	add_child(sb)

func _add_target(cell: Vector2i, kind: String, drift: Vector3) -> void:
	var t := FPTarget.new()
	match kind:
		"car":
			t.value = RRTuning.SCORE_CAR; t.heat = RRTuning.HEAT_CAR
			t.box_color = Color("#4A7AC8"); t.size = Vector3(2.4, 1.6, 4.2); t.min_speed = 4.0
		"ped":
			t.value = RRTuning.SCORE_PED; t.heat = RRTuning.HEAT_PED
			t.box_color = Color("#E0B0A0"); t.size = Vector3(1.0, 2.0, 1.0); t.min_speed = 2.0
		_:
			t.value = RRTuning.SCORE_PROP; t.heat = RRTuning.HEAT_PROP
			t.box_color = Color("#C8A24A"); t.size = Vector3(1.8, 2.0, 1.8); t.min_speed = 5.0
	t.drift = drift
	t.smashed.connect(_on_smashed)
	add_child(t)
	t.global_position = _world_pos(cell)

func _spawn_traffic(count: int) -> void:
	# Cars that cruise along road lanes (cells where x or y % 4 == 0), ping-ponging.
	for i in count:
		var on_x: bool = (i % 2 == 0)
		var lane: int = (_rng.randi_range(0, RRTuning.CITY_COLS / 4)) * 4
		var along: int = _rng.randi_range(1, RRTuning.CITY_ROWS - 2)
		var cell := Vector2i(lane, along) if on_x else Vector2i(along, lane)
		var dir := Vector3(0, 0, _rng.randf_range(8.0, 16.0)) if on_x else Vector3(_rng.randf_range(8.0, 16.0), 0, 0)
		_add_target(cell, "car", dir)

func _spawn_car() -> void:
	_car = FPCar.new()
	# Central road intersection (cell 12,12 — both % 4 == 0).
	_car.position = _world_pos(Vector2i(12, 12)) + Vector3(0.0, 1.2, 0.0)
	add_child(_car)

# ── Events ────────────────────────────────────────────────────────────────────

func _on_smashed(value: int, _heat: int, pos: Vector3) -> void:
	var pts: int = _combo.register(value)
	_score.add(pts, 1)
	_smashed += 1
	_maybe_new_best()
	_popup(pos, "+%d" % pts)
	_refresh()

func _maybe_new_best() -> void:
	# Live best tracking (endless run — no game over to submit at).
	if _score.score > _best:
		_best = _score.score
		_score.submit()

func _popup(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos + Vector3(0.0, 2.5, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.modulate = Color("#FFE08A")
	l.outline_size = 12
	add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 4.0, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(l): l.queue_free())

# ── HUD ───────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _ui_score:
		_ui_score.text = "分數 %d　·　摧毀 %d" % [_score.score, _smashed]
	if _ui_best:
		_ui_best.text = ("最佳 %d" % _best) if _best > 0 else ""

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_ui_score = _mk_label(ui, Vector2(20, 16), 26, Color("#F2E4B0"))
	_ui_best = _mk_label(ui, Vector2(740, 18), 18, Color("#C8BC90"))
	_ui_combo = _mk_label(ui, Vector2(20, 50), 24, Color("#FFB020"))
	_ui_combo.visible = false
	_ui_speed = _mk_label(ui, Vector2(740, 500), 22, Color("#A0D0FF"))
	_refresh()

func _mk_label(ui: CanvasLayer, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(400, 36)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	ui.add_child(l)
	return l
