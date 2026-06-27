## Main — game director. Phase 2: player + camera + scattered destructibles on a
## gridded lot, with impact camera shake. Later phases add combo/score/HUD, city,
## wanted, police, juice.
extends Node2D

const Vehicle = preload("res://scripts/vehicle.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Destructible = preload("res://scripts/destructible.gd")

var _player: Vehicle = null
var _cam: CameraRig = null

func _ready() -> void:
	_player = Vehicle.new()
	_player.position = Vector2.ZERO
	add_child(_player)
	_cam = CameraRig.new()
	add_child(_cam)
	_cam.setup(_player)
	_scatter_props()
	queue_redraw()

func _scatter_props() -> void:
	var kinds := ["prop", "prop", "prop", "car", "ped", "ped"]
	for i in 80:
		var d := Destructible.new()
		d.kind = kinds[i % kinds.size()]
		# Avoid spawning on top of the player start.
		var p := Vector2(randf_range(-1100, 1100), randf_range(-800, 800))
		if p.length() < 120.0:
			p = p.normalized() * 160.0
		d.position = p
		d.destroyed.connect(_on_destroyed)
		add_child(d)

func _on_destroyed(kind: String, value: int, heat: int, pos: Vector2) -> void:
	_cam.shake(0.25 if kind != "car" else 0.6)
	if kind == "car":
		_cam.punch(0.06)

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
