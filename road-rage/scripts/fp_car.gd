## FPCar — arcade car (3D) with a THIRD-PERSON chase camera for 橫衝直撞.
## Pulled-back chase view; the car body is fully modelled (visible now).
class_name FPCar
extends CharacterBody3D

const ACCEL: float = 18.0
const MAX_SPEED: float = 33.0      ## base top speed (nitro boosts above this)
const REVERSE_SPEED: float = 20.0   ## faster reverse per feedback
const TURN_RATE: float = 2.3
const FRICTION: float = 12.0
const GRIP: float = 5.0             ## how hard velocity steers toward facing in turns
const BRAKE_DECEL: float = 55.0    ## handbrake (SPACE)
const GRAVITY: float = 24.0
const BASE_FOV: float = 72.0
const MAX_FOV: float = 86.0        ## widens with speed for an acceleration rush

var _cam: Camera3D = null
var _engine: AudioStreamPlayer = null
var _engine_started: bool = false

func _ready() -> void:
	up_direction = Vector3.UP
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.7, 6.6)
	col.shape = box
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)
	_build_car_visual()
	# Third-person chase camera: behind (+Z, since the car faces -Z) and above,
	# pulled back, with a slight downward tilt. Rigidly parented so it follows turns.
	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 8.0, 16.5)   # pulled further back + higher
	_cam.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	_cam.fov = BASE_FOV
	_cam.current = true
	add_child(_cam)
	# Engine drone — pitch tracks speed; starts on first input (Web-safe gesture).
	_engine = AudioStreamPlayer.new()
	_engine.stream = RRAudio.make_engine_stream()
	_engine.volume_db = -13.0
	add_child(_engine)

func _build_car_visual() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#D8482A")
	body_mat.metallic = 0.35
	body_mat.roughness = 0.45
	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(3.2, 1.0, 6.6)
	cm.material = body_mat
	chassis.mesh = cm
	chassis.position = Vector3(0.0, 0.68, 0.0)
	add_child(chassis)
	# Cabin
	var cabin := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(2.7, 1.0, 3.0)
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color("#BE3C20")
	cab_mat.metallic = 0.35
	cab_mat.roughness = 0.45
	cab.material = cab_mat
	cabin.mesh = cab
	cabin.position = Vector3(0.0, 1.7, 0.45)
	add_child(cabin)
	# Windshield (front = -Z)
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(2.5, 0.85, 0.2)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("#243040")
	gmat.metallic = 0.7
	gmat.roughness = 0.1
	gm.material = gmat
	glass.mesh = gm
	glass.position = Vector3(0.0, 1.7, -1.1)
	add_child(glass)
	# Headlights (front), emissive
	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color("#FFF6C0")
	hl_mat.emission_enabled = true
	hl_mat.emission = Color("#FFE890")
	hl_mat.emission_energy_multiplier = 2.0
	for sx in [-1.05, 1.05]:
		var hl := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.6, 0.35, 0.2)
		hm.material = hl_mat
		hl.mesh = hm
		hl.position = Vector3(sx, 0.7, -3.35)
		add_child(hl)
	# Wheels (cylinders laid on their side — axis along X)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color("#18181C")
	wheel_mat.roughness = 0.9
	for wx in [-1.7, 1.7]:
		for wz in [-2.2, 2.2]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.72
			wm.bottom_radius = 0.72
			wm.height = 0.5
			wm.material = wheel_mat
			w.mesh = wm
			w.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			w.position = Vector3(wx, 0.6, wz)
			add_child(w)

func speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func _physics_process(delta: float) -> void:
	var throttle: float = Input.get_axis("brake", "accel")
	var steer: float = Input.get_axis("left", "right")
	var sp: float = speed()
	# Invert steering while reversing so it feels natural (like backing up looking over your shoulder).
	var steer_input: float = (-steer if throttle < 0.0 else steer)
	if sp > 0.5:
		rotate_y(-steer_input * TURN_RATE * delta * clampf(sp / MAX_SPEED, 0.25, 1.0))
	var forward: Vector3 = -global_transform.basis.z
	var h := Vector3(velocity.x, 0.0, velocity.z)
	var boosting: bool = Input.is_action_pressed("nitro") and throttle > 0.0
	if Input.is_action_pressed("handbrake"):
		h = h.move_toward(Vector3.ZERO, BRAKE_DECEL * delta)
	elif throttle > 0.0:
		h += forward * ACCEL * (2.0 if boosting else 1.0) * delta
	elif throttle < 0.0:
		h += -forward * REVERSE_SPEED * delta
	else:
		var fr: float = FRICTION * delta
		if h.length() <= fr:
			h = Vector3.ZERO
		else:
			h -= h.normalized() * fr
	# Grip: steer the velocity toward the car's facing so corners feel planted
	# instead of sliding (the "handling feels off / drifty" feedback).
	if h.length() > 1.0 and not Input.is_action_pressed("handbrake"):
		# Grip toward the car's travel axis — forward OR backward, whichever it's
		# actually moving — so it stays planted without fighting reverse.
		var travel_sign: float = (1.0 if h.dot(forward) >= 0.0 else -1.0)
		h = h.lerp(forward * travel_sign * h.length(), clampf(GRIP * delta, 0.0, 1.0))
	h = h.limit_length(MAX_SPEED * (1.55 if boosting else 1.0))
	velocity.x = h.x
	velocity.z = h.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# ── Speed feel ──
	var frac: float = clampf(speed() / MAX_SPEED, 0.0, 1.0)
	if _cam != null:
		var tgt_fov: float = lerpf(BASE_FOV, MAX_FOV, frac)
		if throttle > 0.0:
			tgt_fov += 3.0
		if boosting:
			tgt_fov += 9.0   # nitro rush
		_cam.fov = lerpf(_cam.fov, tgt_fov, 0.10)
		var shake: float = maxf(0.0, frac - 0.6) * 0.08
		_cam.h_offset = randf_range(-shake, shake)
		_cam.v_offset = randf_range(-shake, shake)
	if _engine != null:
		if not _engine_started and (throttle != 0.0 or steer != 0.0):
			_engine_started = true
			_engine.play()
		_engine.pitch_scale = 0.7 + 1.4 * frac + (0.4 if boosting else 0.0)
	# Safety: a run never "ends" — respawn if the car drops off the world.
	if global_position.y < -8.0:
		global_position = Vector3(144.0, 2.0, 144.0)
		velocity = Vector3.ZERO

func bleed_speed(factor: float) -> void:
	velocity.x *= factor
	velocity.z *= factor
