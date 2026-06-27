## Main — game director. Phase 1: player + camera on a gridded lot so driving
## feel can be validated. Later phases add destructibles, city, wanted, police, HUD.
extends Node2D

const Vehicle = preload("res://scripts/vehicle.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")

var _player: Vehicle = null
var _cam: CameraRig = null

func _ready() -> void:
	_player = Vehicle.new()
	_player.position = Vector2.ZERO
	add_child(_player)
	_cam = CameraRig.new()
	add_child(_cam)
	_cam.setup(_player)
	queue_redraw()

func _draw() -> void:
	# Faint asphalt grid so speed and drift read clearly on the empty lot.
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
