## FPCar — first-person arcade car (3D) for the 橫衝直撞 first-person spike.
## CharacterBody3D with manual arcade driving + a cockpit Camera3D facing forward.
class_name FPCar
extends CharacterBody3D

const FPCockpit = preload("res://scripts/fp_cockpit.gd")

const ACCEL: float = 22.0
const MAX_SPEED: float = 42.0
const REVERSE_SPEED: float = 16.0
const TURN_RATE: float = 2.3
const FRICTION: float = 12.0
const GRAVITY: float = 24.0
const BASE_FOV: float = 76.0
const MAX_FOV: float = 96.0    ## widens with speed for an acceleration rush

var _cam: Camera3D = null
var _cockpit: FPCockpit = null
var _engine: AudioStreamPlayer = null
var _engine_started: bool = false

func _ready() -> void:
	up_direction = Vector3.UP
	# Collision body (roughly car-sized).
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 4.0)
	col.shape = box
	add_child(col)
	# Visible body so you can see it in reflections / mirror later (mostly hidden in FP).
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 1.0, 4.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#D24B2A")
	bm.material = mat
	mi.mesh = bm
	add_child(mi)
	# Hood marker (front = -Z) so the player sees the car nose ahead.
	var hood := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(1.6, 0.4, 1.2)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color("#B23A1E")
	hm.material = hmat
	hood.mesh = hm
	hood.position = Vector3(0.0, 0.4, -1.6)
	add_child(hood)
	# First-person camera at the driver's eye, looking forward (-Z).
	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 1.7, 0.1)   # a touch higher to see over the dash
	_cam.fov = BASE_FOV
	_cam.current = true
	add_child(_cam)
	# First-person car interior (dashboard, wheel, pillars, mirror).
	_cockpit = FPCockpit.new()
	add_child(_cockpit)
	# Engine drone — pitch tracks speed; starts on first input (Web-safe gesture).
	_engine = AudioStreamPlayer.new()
	_engine.stream = RRAudio.make_engine_stream()
	_engine.volume_db = -13.0
	add_child(_engine)

func speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func _physics_process(delta: float) -> void:
	var throttle: float = Input.get_axis("brake", "accel")
	var steer: float = Input.get_axis("left", "right")
	if _cockpit != null:
		_cockpit.set_steer(steer)
	var sp: float = speed()
	# Steer only while moving; scale with speed for an arcade feel.
	if sp > 0.5:
		rotate_y(-steer * TURN_RATE * delta * clampf(sp / MAX_SPEED, 0.25, 1.0))
	var forward: Vector3 = -global_transform.basis.z
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if throttle > 0.0:
		h += forward * ACCEL * delta
	elif throttle < 0.0:
		# Reverse / brake. Friction is skipped while throttling so the car
		# actually builds reverse speed (friction used to cancel it out).
		h += -forward * REVERSE_SPEED * delta
	else:
		# Coasting: passive friction only when not accelerating.
		var fr: float = FRICTION * delta
		if h.length() <= fr:
			h = Vector3.ZERO
		else:
			h -= h.normalized() * fr
	h = h.limit_length(MAX_SPEED)
	velocity.x = h.x
	velocity.z = h.z
	# Gravity keeps the car on the ground.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# ── Speed feel ──────────────────────────────────────────────────────────
	var frac: float = clampf(speed() / MAX_SPEED, 0.0, 1.0)
	if _cam != null:
		var tgt_fov: float = lerpf(BASE_FOV, MAX_FOV, frac)
		if throttle > 0.0:
			tgt_fov += 4.0   # extra punch while flooring it
		_cam.fov = lerpf(_cam.fov, tgt_fov, 0.12)
		var shake: float = maxf(0.0, frac - 0.55) * 0.10   # vibration only at high speed
		_cam.h_offset = randf_range(-shake, shake)
		_cam.v_offset = randf_range(-shake, shake)
	if _engine != null:
		if not _engine_started and (throttle != 0.0 or steer != 0.0):
			_engine_started = true
			_engine.play()
		_engine.pitch_scale = 0.7 + 1.4 * frac
	# Safety: a run never "ends" — if the car ever drops off the world, respawn.
	if global_position.y < -8.0:
		global_position = Vector3(144.0, 2.0, 144.0)
		velocity = Vector3.ZERO

func bleed_speed(factor: float) -> void:
	velocity.x *= factor
	velocity.z *= factor
