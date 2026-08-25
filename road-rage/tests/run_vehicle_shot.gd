## Lines every vehicle kind up side-on in front of the chase camera and shoots it,
## so the silhouettes can actually be looked at instead of trusted. Needs a GPU:
##   godot --path road-rage -s res://tests/run_vehicle_shot.gd -- <out.png>
extends SceneTree

var _m
var _f: int = 0
var _shot: String = "/tmp/roadrage_vehicles.png"
var _placed: bool = false

func _initialize() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.size() > 0:
		_shot = argv[0]
	_m = load("res://scenes/fp_main.tscn").instantiate()
	root.add_child(_m)

func _process(_delta: float) -> bool:
	_f += 1
	if _f == 20:
		_m._start_game()
		if _m._ui_title != null:
			_m._ui_title.visible = false
	if _f == 30 and not _placed:
		_placed = true
		_line_up()
	if _f < 110:
		return false
	var img := root.get_texture().get_image()
	if img != null:
		print("SHOT saved=%s err=%d size=%dx%d" % [_shot, img.save_png(_shot), img.get_width(), img.get_height()])
	return true

## Park the player somewhere empty and lay the catalogue out in front, broadside on.
func _line_up() -> void:
	var base := Vector3(200.0, 1.0, 200.0)
	_m._car.global_position = base
	_m._car.velocity = Vector3.ZERO
	# Clear the backdrop: traffic, crowds, and any building standing in the shot.
	for grp in ["vehicle", "pedestrian", "gang"]:
		for n in _m.get_tree().get_nodes_in_group(grp):
			if is_instance_valid(n):
				n.queue_free()
	var look: Vector3 = base + Vector3(0.0, 0.0, -30.0)
	for n in _m.get_children():
		if n == _m._car or not (n is Node3D):
			continue
		var d: float = (n as Node3D).global_position.distance_to(look)
		if d < 62.0:
			n.queue_free()
	var kinds: Array = FPVehicleKinds.catalogue()
	var x: float = -19.0
	for k in kinds:
		var t := FPTarget.new()
		var cols: Array = k["colors"]
		t.size = k["chassis"]
		t.box_color = Color(String(cols[0]))
		t.draw_box = false
		t.kind = k
		_m.add_child(t)
		t.global_position = base + Vector3(x, 0.0, -30.0)
		t.rotation_degrees = Vector3(0.0, 90.0, 0.0)   # broadside so the shape reads
		FPVehicleKinds.build(t, k, t.box_color)
		x += 8.6
