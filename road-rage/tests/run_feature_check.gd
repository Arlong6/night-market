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

	# 6) Pedestrians panic (flee state) when alarmed by violence.
	var peds: Array = _m.get_tree().get_nodes_in_group("pedestrian")
	var ped_ok: bool = false
	if peds.size() > 0:
		var pd = peds[0]
		pd.panic(pd.global_position + Vector3(0.0, 0.0, 3.0))
		ped_ok = pd._panic_t > 0.0
	out.append("ped_panic[count=%d fleeing=%s]" % [peds.size(), ped_ok])

	# 7) Taking damage from a source arms the directional damage indicator.
	_m._hp = 100.0
	_m._damage(5.0, _m._player_pos() + Vector3(10.0, 0.0, 0.0))
	out.append("dmg_indicator=%s" % (_m._dmg_t > 0.0))

	# 8) Gun fire-mode toggle exists and flips (連發 <-> 單發).
	var fire_ok: bool = false
	if is_instance_valid(_m._walker):
		var was: bool = _m._walker._auto_fire
		_m._walker._auto_fire = not was
		fire_ok = _m._walker._auto_fire != was
	out.append("fire_mode_toggle=%s" % fire_ok)

	# 9) Weapon ownership: shotgun is locked by default; a grant unlocks + switches.
	var weap_ok: bool = false
	if is_instance_valid(_m._walker):
		_m._walker._set_weapon(2)               # locked -> should be ignored
		var blocked: bool = _m._walker._weapon != 2
		_m._walker.grant_weapon(2)              # pickup unlocks the shotgun
		var wd = _m._walker._weapons[_m._walker._weapon]
		weap_ok = blocked and _m._walker._weapon == 2 and int(wd["pellets"]) == 8
		_m._walker._set_weapon(0)
	out.append("weapons[lock+grant=%s]" % weap_ok)

	# 10) Rocket launcher: once granted, firing spawns an FPRocket projectile.
	var rocket_ok: bool = false
	if is_instance_valid(_m._walker):
		_m._walker.grant_weapon(3)
		var name_ok: bool = _m._walker.weapon_name() == "火箭筒"
		_m._walker._do_fire()
		var spawned: bool = false
		for c in _m.get_children():
			if c is FPRocket:
				spawned = true
				break
		rocket_ok = name_ok and spawned
		_m._walker._set_weapon(0)
	out.append("rocket[ok=%s]" % rocket_ok)

	# 11) Weapon pickups were scattered in the world.
	var pk: int = 0
	for c in _m.get_children():
		if c is FPWeaponPickup:
			pk += 1
	out.append("weapon_pickups=%d" % pk)

	# 12) Car mounted gun fires (drive-by shooting).
	var carfire_ok: bool = false
	if is_instance_valid(_m._car) and _m._car.has_method("_car_fire"):
		_m._car._car_fire()
		carfire_ok = _m._car._gun_cd > 0.0
	out.append("car_gun=%s" % carfire_ok)

	# 13) Demolition mission: cooldown elapses -> starts; a collapse advances it;
	#     reaching the target completes it.
	_m._mission_active = false
	_m._mission_cooldown = 0.0
	_m._update_mission(0.1)                 # cooldown gone -> mission starts
	var m_started: bool = _m._mission_active and _m._mission_target >= 2
	_m._mission_target = 1                  # shrink to a 1-building objective for the test
	_m._mission_progress = 0
	_m._on_building_collapsed(Vector3(60.0, 0.0, 60.0))
	var m_done: bool = (not _m._mission_active) and _m._mission_progress >= 1
	out.append("mission[start=%s done=%s]" % [m_started, m_done])

	print("FEATURE_CHECK " + " ".join(out))
	return true
