## FPWalker — on-foot character for 橫衝直撞. FIRST-PERSON: mouse looks around
## (yaw + pitch), WASD moves relative to look, hitscan gun fires exactly where the
## crosshair points (so you can aim UP at the helicopter). Get in/out via FPMain.
class_name FPWalker
extends CharacterBody3D

const SPEED: float = 8.0
const SPRINT_MULT: float = 1.7   ## hold Shift to sprint
const JUMP_VEL: float = 9.5      ## Space to jump
const GRAVITY: float = 24.0
const SPREAD_DECAY: float = 0.22    ## bloom recovered per second when not firing
const BASE_FOV: float = 74.0

## Data-driven weapon table. Switch with 1/2/3. Per-weapon: rays per trigger pull,
## fire cooldown, inherent cone + recoil bloom, range, sound pitch, and viewmodel
## size/colour so each gun looks and feels distinct.
var _weapons: Array[Dictionary] = [
	{"name": "手槍", "pellets": 1, "rate": 0.20, "spread": 0.004, "bloom": 0.006, "bloom_max": 0.03, "range": 60.0, "pitch": 1.0, "len": 0.58, "thick": 0.12, "col": Color("#3B3D47")},
	{"name": "衝鋒槍", "pellets": 1, "rate": 0.075, "spread": 0.012, "bloom": 0.020, "bloom_max": 0.11, "range": 55.0, "pitch": 1.18, "len": 0.82, "thick": 0.11, "col": Color("#2E2F37")},
	{"name": "散彈槍", "pellets": 8, "rate": 0.72, "spread": 0.060, "bloom": 0.0, "bloom_max": 0.02, "range": 34.0, "pitch": 0.7, "len": 0.92, "thick": 0.17, "col": Color("#4A3A2A")},
	{"name": "火箭筒", "pellets": 0, "rate": 1.1, "spread": 0.0, "bloom": 0.0, "bloom_max": 0.0, "range": 0.0, "pitch": 0.55, "len": 1.0, "thick": 0.22, "col": Color("#3E4A2E"), "rocket": true},
]
var _weapon: int = 0
var _owned: Array = [true, true, true, true]   ## which weapons are unlocked (set by FPMain)
var _gun: MeshInstance3D = null   ## viewmodel body (reshaped per weapon)
const EYE_HEIGHT: float = 1.6    ## first-person camera height
const MOUSE_SENS: float = 0.0026 ## radians of look per pixel of mouse motion
const MAX_PITCH: float = 1.35    ## clamp look up/down (~77 degrees)

var _fire_cd: float = 0.0
var _auto_fire: bool = true   ## true = 連發 (hold to spray), false = 單發 (tap per shot)
var _spread: float = 0.0      ## current bloom; grows while spraying, decays at rest

var _cam: Camera3D = null
var _visual: Node3D = null
var _muzzle: MeshInstance3D = null
var _face: Vector3 = Vector3.FORWARD
var _muzzle_t: float = 0.0
var _fire_queued: bool = false
var _cam_yaw: float = 0.0    ## look yaw (mouse X, or , / . keys)
var _cam_pitch: float = 0.0  ## look pitch (mouse Y) — enables vertical aim
var _trauma: float = 0.0   ## impact/explosion camera-shake energy (decays each frame)

## Feed camera-shake energy in (0..1 per hit) — crashes/explosions near the walker.
func add_trauma(amt: float) -> void:
	_trauma = minf(1.2, _trauma + amt)

func _ready() -> void:
	up_direction = Vector3.UP
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	_visual.visible = false   # first-person: our own body isn't drawn into the view
	# First-person camera at eye height; rotates in place from look yaw + pitch.
	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	_cam.fov = BASE_FOV
	add_child(_cam)
	_build_viewmodel()

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#3A6EA5")
	cm.material = bmat
	body.mesh = cm
	body.position = Vector3(0.0, 0.9, 0.0)
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color("#E7B58A")
	sm.material = hmat
	head.mesh = sm
	head.position = Vector3(0.0, 1.95, 0.0)
	_visual.add_child(head)
	# Gun held forward (visual -Z).
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.16, 0.16, 0.7)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("#1A1A1E")
	gm.material = gmat
	gun.mesh = gm
	gun.position = Vector3(0.32, 1.1, -0.55)
	_visual.add_child(gun)
	# Muzzle flash (shown briefly when firing).
	_muzzle = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.18
	mm.height = 0.36
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color("#FFE070")
	mmat.emission_enabled = true
	mmat.emission = Color("#FFC030")
	mmat.emission_energy_multiplier = 5.0
	mm.material = mmat
	_muzzle.mesh = mm
	_muzzle.position = Vector3(0.32, 1.1, -1.0)
	_muzzle.visible = false
	_visual.add_child(_muzzle)

## First-person weapon viewmodel — a gun barrel fixed to the camera (bottom-right)
## plus its muzzle flash. Replaces the world-body muzzle for the FP view.
func _build_viewmodel() -> void:
	_gun = MeshInstance3D.new()
	var gm := BoxMesh.new()
	var gmat := StandardMaterial3D.new()
	gmat.metallic = 0.6
	gmat.roughness = 0.45
	gm.material = gmat
	_gun.mesh = gm
	_gun.position = Vector3(0.22, -0.19, -0.5)
	_cam.add_child(_gun)
	_muzzle = MeshInstance3D.new()   # reassign: FP muzzle lives on the viewmodel now
	var mm := SphereMesh.new()
	mm.radius = 0.11
	mm.height = 0.22
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color("#FFE070")
	mmat.emission_enabled = true
	mmat.emission = Color("#FFC030")
	mmat.emission_energy_multiplier = 6.0
	mm.material = mmat
	_muzzle.mesh = mm
	_muzzle.visible = false
	_cam.add_child(_muzzle)
	_apply_weapon_visual()   # size the gun + place the muzzle for weapon 0

## Reshape the viewmodel + reposition the muzzle to match the current weapon.
func _apply_weapon_visual() -> void:
	var w: Dictionary = _weapons[_weapon]
	var wlen: float = w["len"]
	var thick: float = w["thick"]
	if _gun != null and _gun.mesh is BoxMesh:
		_gun.mesh.size = Vector3(thick, thick * 1.15, wlen)
		var m := _gun.get_active_material(0)
		if m is StandardMaterial3D:
			m.albedo_color = w["col"]
	if _muzzle != null:
		# Sit the flash at the barrel tip (gun is centred at z=-0.5).
		_muzzle.position = Vector3(0.22, -0.19, -0.5 - wlen * 0.5 - 0.04)

func make_current() -> void:
	if _cam:
		_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # FP mouse-look on foot

func _process(delta: float) -> void:
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		if _muzzle_t <= 0.0 and _muzzle:
			_muzzle.visible = false
	# Toggle 連發/單發 fire mode with F.
	if Input.is_action_just_pressed("fire_mode"):
		_auto_fire = not _auto_fire
	# Switch weapons with 1 / 2 / 3.
	if Input.is_action_just_pressed("weap_1"):
		_set_weapon(0)
	elif Input.is_action_just_pressed("weap_2"):
		_set_weapon(1)
	elif Input.is_action_just_pressed("weap_3"):
		_set_weapon(2)
	elif Input.is_action_just_pressed("weap_4"):
		_set_weapon(3)
	# 連發: fire while held. 單發: one shot per press.
	_fire_cd = maxf(0.0, _fire_cd - delta)
	var wants_fire: bool = Input.is_action_pressed("fire") if _auto_fire else Input.is_action_just_pressed("fire")
	if _fire_cd <= 0.0 and wants_fire:
		fire()
	# Ease the recoil FOV kick back to normal.
	if _cam:
		_cam.fov = lerpf(_cam.fov, BASE_FOV, 0.25)
	_trauma = maxf(0.0, _trauma - delta * 1.8)   # shake energy bleeds off
	_spread = maxf(0.0, _spread - SPREAD_DECAY * delta)   # accuracy recovers at rest
	# Esc frees / re-locks the mouse cursor (so you can click away and come back).
	if _cam and _cam.current and Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	# Keyboard yaw fallback (, / .) still works alongside the mouse.
	_cam_yaw += Input.get_axis("cam_left", "cam_right") * 2.6 * delta
	_update_camera()

## Mouse-look: yaw from horizontal motion, pitch (vertical aim) from vertical.
func _unhandled_input(event: InputEvent) -> void:
	if _cam == null or not _cam.current:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_cam_yaw -= event.relative.x * MOUSE_SENS
		_cam_pitch = clampf(_cam_pitch - event.relative.y * MOUSE_SENS, -MAX_PITCH, MAX_PITCH)

func _update_camera() -> void:
	if _cam == null:
		return
	# First-person: camera sits at the eye and rotates in place (yaw + pitch).
	_cam.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	_cam.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	var t2: float = _trauma * _trauma
	_cam.h_offset = randf_range(-1.0, 1.0) * t2 * 0.4
	_cam.v_offset = randf_range(-1.0, 1.0) * t2 * 0.4
	if _trauma > 0.001:
		_cam.rotation.z = randf_range(-1.0, 1.0) * t2 * 0.05  # roll jolt on impact

func _physics_process(delta: float) -> void:
	var spd: float = SPEED * (SPRINT_MULT if Input.is_action_pressed("nitro") else 1.0)
	# Movement + aim are relative to the camera yaw (proper 3rd-person shooter feel).
	var fwd := Vector3(-sin(_cam_yaw), 0.0, -cos(_cam_yaw))
	var right := fwd.cross(Vector3.UP)
	_face = fwd
	_visual.look_at(global_position + fwd, Vector3.UP)
	var move := fwd * Input.get_axis("brake", "accel") + right * Input.get_axis("left", "right")
	if move.length() > 0.1:
		move = move.normalized()
		velocity.x = move.x * spd
		velocity.z = move.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_on_floor():
		if Input.is_action_just_pressed("handbrake"):
			velocity.y = JUMP_VEL   # jump (Space)
		elif velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if _fire_queued:
		_fire_queued = false
		_do_fire()

## Fire the gun: immediate muzzle flash + shot; the hitscan runs on the physics
## frame (space-state queries are only safe there).
func fire() -> void:
	if _fire_cd > 0.0:
		return
	var w: Dictionary = _weapons[_weapon]
	_fire_cd = w["rate"]
	if _muzzle:
		_muzzle.visible = true
	_muzzle_t = 0.05
	RRAudio.gunshot(self, w["pitch"])
	if _cam:
		_cam.fov = BASE_FOV + (6.0 if int(w["pellets"]) > 1 else 3.0)  # shotgun kicks harder
	_fire_queued = true

## Switch to weapon `i` (1/2/3/4). Ignored if the weapon isn't unlocked yet.
func _set_weapon(i: int) -> void:
	if i < 0 or i >= _weapons.size() or i == _weapon:
		return
	if i < _owned.size() and not _owned[i]:
		return   # not picked up yet
	_weapon = i
	_spread = 0.0
	_fire_cd = maxf(_fire_cd, 0.12)   # tiny raise delay on swap
	_apply_weapon_visual()

## Point ownership at FPMain's persistent array and start on `start_weapon` if owned.
## Called when the walker is (re)created so owned weapons survive car trips + respawns.
func set_owned(arr: Array, start_weapon: int = 0) -> void:
	_owned = arr
	if start_weapon >= 0 and start_weapon < _weapons.size() and start_weapon < _owned.size() and _owned[start_weapon]:
		_weapon = start_weapon
	else:
		_weapon = 0
	_apply_weapon_visual()

## Unlock weapon `i` (from a pickup) and switch to it.
func grant_weapon(i: int) -> void:
	if i < 0 or i >= _weapons.size() or i >= _owned.size():
		return   # only equip a weapon we can actually mark as owned (keep them in sync)
	_owned[i] = true
	_weapon = i
	_spread = 0.0
	_apply_weapon_visual()

func weapon_name() -> String:
	return String(_weapons[_weapon]["name"])

## Current total aim cone (inherent weapon spread + accumulated recoil bloom).
## Drives how wide the HUD crosshair opens.
func current_spread() -> float:
	return float(_weapons[_weapon].get("spread", 0.0)) + _spread

func _do_fire() -> void:
	var w: Dictionary = _weapons[_weapon]
	var base_dir: Vector3 = (-_cam.global_transform.basis.z) if _cam != null else _face
	if w.get("rocket", false):
		_fire_rocket(base_dir)
	else:
		var from: Vector3 = _cam.global_position if _cam != null else global_position + Vector3(0.0, 1.4, 0.0)
		var rng: float = float(w["range"])
		var cone: float = float(w["spread"]) + _spread   # inherent cone + accumulated recoil bloom
		var pellets: int = int(w["pellets"])
		var rt: Vector3 = _cam.global_transform.basis.x if _cam != null else Vector3.RIGHT
		var up: Vector3 = _cam.global_transform.basis.y if _cam != null else Vector3.UP
		for i in pellets:
			var dir := base_dir
			if cone > 0.0001:
				dir = (base_dir + rt * randf_range(-cone, cone) + up * randf_range(-cone, cone)).normalized()
			_fire_ray(from, dir, rng)
		_spread = minf(float(w["bloom_max"]), _spread + float(w["bloom"]))
		_eject_shell()
	# The shot scatters nearby civilians.
	var g: Node = get_parent()
	if g != null and g.has_method("alarm_peds"):
		g.alarm_peds(global_position, 24.0)

## Launch a rocket projectile from the muzzle along `dir` (used by the 火箭筒).
func _fire_rocket(dir: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var FPRocket = load("res://scripts/fp_rocket.gd")
	var r = FPRocket.new()
	host.add_child(r)
	var origin: Vector3 = (_cam.global_position + dir * 1.0) if _cam != null else (global_position + Vector3(0.0, 1.4, 0.0) + dir)
	r.global_position = origin
	r.setup(dir, get_rid(), host)

## One hitscan pellet: raycast, damage what it hits, draw a tracer.
func _fire_ray(from: Vector3, dir: Vector3, rng: float) -> void:
	var to: Vector3 = from + dir * rng
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var endp: Vector3 = to
	if hit.has("collider"):
		endp = hit["position"]
		var c = hit["collider"]
		if c != null and c.has_method("shoot_hit"):
			c.shoot_hit()
		_hit_spark(endp)
	_tracer(from + dir * 1.2, endp)

## Toss a brass shell casing out of the ejection port with a short tumble + drop.
func _eject_shell() -> void:
	if _cam == null:
		return
	var host: Node = get_parent()
	if host == null:
		return
	var shell := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#E7B84A")   # bright brass
	mat.metallic = 0.7
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color("#6A4E12")       # faint sheen so it reads against dark ground
	mat.emission_energy_multiplier = 0.5
	bm.material = mat
	shell.mesh = bm
	host.add_child(shell)
	var xf: Transform3D = _cam.global_transform
	var start: Vector3 = xf * Vector3(0.2, -0.15, -0.5)   # ejection port, just right of the gun
	shell.global_position = start
	var rt: Vector3 = xf.basis.x
	var up: Vector3 = xf.basis.y
	var apex: Vector3 = start + rt * 0.28 + up * 0.24
	var landing: Vector3 = start + rt * 0.5 - up * 1.4
	var mv := shell.create_tween()
	mv.tween_property(shell, "global_position", apex, 0.11)
	mv.tween_property(shell, "global_position", landing, 0.34)
	var sp := shell.create_tween()
	sp.tween_property(shell, "rotation", Vector3(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)), 0.55)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(shell): shell.queue_free())

func _tracer(a: Vector3, b: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var dist: float = a.distance_to(b)
	if dist < 0.2:
		return
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, dist)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#FFF0A0")
	mat.emission_enabled = true
	mat.emission = Color("#FFD84A")
	mat.emission_energy_multiplier = 5.0
	bm.material = mat
	beam.mesh = bm
	host.add_child(beam)
	beam.global_position = (a + b) * 0.5
	if absf((b - a).normalized().dot(Vector3.UP)) < 0.98:
		beam.look_at(b, Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(beam): beam.queue_free())

func _hit_spark(pos: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#FFE080")
	mat.emission_enabled = true
	mat.emission = Color("#FFC040")
	mat.emission_energy_multiplier = 3.0
	var bm := BoxMesh.new()
	bm.material = mat
	p.mesh = bm
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())
