## Headless proof that the 3 requested features actually work (logic-level).
## Run: godot --headless -s res://tests/run_feature_check.gd
extends SceneTree

var _m
var _done: bool = false

func _initialize() -> void:
	_m = load("res://scenes/fp_main.tscn").instantiate()
	root.add_child(_m)

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var out: Array = []

	# 1) Carjack a traffic vehicle: stand next to it (own car far), enter -> should
	#    board, the traffic car is removed, and our car moves onto its spot.
	_m._exit_car()
	var vehicles: Array = _m.get_tree().get_nodes_in_group("vehicle")
	var cj_mode: String = "none"
	var cj_dist: float = -1.0
	var cj_freed: bool = false
	var cj_count: int = vehicles.size()
	if vehicles.size() > 0 and is_instance_valid(_m._walker):
		var v = vehicles[0]
		var vpos: Vector3 = v.global_position
		_m._walker.global_position = vpos + Vector3(2.0, 0.0, 0.0)
		_m._car.global_position = vpos + Vector3(500.0, 0.0, 0.0)  # own car far away
		_m._enter_car()
		cj_mode = _m._mode
		cj_dist = _m._car.global_position.distance_to(vpos)
		cj_freed = v.is_queued_for_deletion() or (not is_instance_valid(v))
	out.append("carjack[vehicles=%d mode=%s cardist=%.1f freed=%s]" % [cj_count, cj_mode, cj_dist, cj_freed])

	# 2) Death -> respawn must bring the car to spawn (never lost).
	_m._car.global_position = Vector3(999.0, 1.0, 999.0)
	_m._hp = 5.0
	_m._damage(999.0)
	var spawn: Vector3 = _m._world_pos(Vector2i(12, 12))
	var respawn_ok: bool = (_m._hp >= _m._max_hp - 0.1) and (_m._car.global_position.distance_to(spawn) < 6.0)
	out.append("respawn_keeps_car=%s" % respawn_ok)

	# 3) Camera rotation logic runs without error and moves the walker cam.
	if _m._mode == "car":
		_m._exit_car()
	# First-person camera: rotates in place from yaw + pitch (pitch = vertical aim).
	var cam_ok: bool = false
	if is_instance_valid(_m._walker):
		_m._walker._cam_yaw = 1.2
		_m._walker._cam_pitch = 0.5
		_m._walker._update_camera()
		var wc = _m._walker._cam
		cam_ok = wc != null and absf(wc.rotation.y - 1.2) < 0.01 and absf(wc.rotation.x - 0.5) < 0.01
	out.append("camera_rotate=%s" % cam_ok)

	# 4) Barrel explosion fires + emits its signal (drives the flash/damage/score).
	var FPExplosive = load("res://scripts/fp_explosive.gd")
	var b = FPExplosive.new()
	_m.add_child(b)
	b.global_position = Vector3(300.0, 0.0, 300.0)
	var got: Array = [false]
	b.exploded.connect(func(_p): got[0] = true)
	b.explode()
	out.append("explosion_fires=%s" % (got[0] and b._broke))

	# 5) Helicopter deploys at high wanted.
	_m._wanted_heat = 5000.0
	_m._manage_police()
	out.append("heli_high_wanted=%s" % is_instance_valid(_m._heli))

	print("FEATURE_CHECK " + " ".join(out))
	return true
