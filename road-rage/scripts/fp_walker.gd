## FPWalker — on-foot character for 橫衝直撞. FIRST-PERSON: mouse looks around
## (yaw + pitch), WASD moves relative to look, hitscan gun fires exactly where the
## crosshair points (so you can aim UP at the helicopter). Get in/out via FPMain.
class_name FPWalker
extends CharacterBody3D

const SPEED: float = 8.0
const SPRINT_MULT: float = 1.7   ## hold Shift to sprint
const JUMP_VEL: float = 9.5      ## Space to jump
const GRAVITY: float = 24.0
const FIRE_RANGE: float = 60.0
const FIRE_RATE: float = 0.13   ## seconds between shots when the fire key is held
const BASE_FOV: float = 74.0
const EYE_HEIGHT: float = 1.6    ## first-person camera height
const MOUSE_SENS: float = 0.0026 ## radians of look per pixel of mouse motion
const MAX_PITCH: float = 1.35    ## clamp look up/down (~77 degrees)

var _fire_cd: float = 0.0

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
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.12, 0.14, 0.62)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("#3B3D47")   # gunmetal — light enough to read on screen
	gmat.metallic = 0.6
	gmat.roughness = 0.45
	gm.material = gmat
	gun.mesh = gm
	gun.position = Vector3(0.22, -0.19, -0.5)
	_cam.add_child(gun)
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
	_muzzle.position = Vector3(0.24, -0.22, -0.86)
	_muzzle.visible = false
	_cam.add_child(_muzzle)

func make_current() -> void:
	if _cam:
		_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # FP mouse-look on foot

func _process(delta: float) -> void:
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		if _muzzle_t <= 0.0 and _muzzle:
			_muzzle.visible = false
	# Auto-fire while the fire key (J) is held.
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if _fire_cd <= 0.0 and Input.is_action_pressed("fire"):
		fire()
	# Ease the recoil FOV kick back to normal.
	if _cam:
		_cam.fov = lerpf(_cam.fov, BASE_FOV, 0.25)
	_trauma = maxf(0.0, _trauma - delta * 1.8)   # shake energy bleeds off
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
	_fire_cd = FIRE_RATE
	if _muzzle:
		_muzzle.visible = true
	_muzzle_t = 0.05
	RRAudio.gunshot(self)
	if _cam:
		_cam.fov = BASE_FOV + 3.0   # recoil kick, eased back in _process
	_fire_queued = true

func _do_fire() -> void:
	# Fire exactly where the camera looks (screen centre) — includes vertical aim.
	var dir: Vector3 = (-_cam.global_transform.basis.z) if _cam != null else _face
	var from: Vector3 = _cam.global_position if _cam != null else global_position + Vector3(0.0, 1.4, 0.0)
	var to: Vector3 = from + dir * FIRE_RANGE
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
