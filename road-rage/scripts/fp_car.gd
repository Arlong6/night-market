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
var _trauma: float = 0.0   ## impact/explosion camera-shake energy (decays each frame)
var active: bool = true   ## false when the player has stepped out (car parks)

## Feed camera-shake energy in (0..1 range per hit). Used for crashes/explosions.
func add_trauma(amt: float) -> void:
	_trauma = minf(1.2, _trauma + amt)
var _look_yaw: float = 0.0   ## camera look-around (, / .), recenters when released

const GUN_RATE: float = 0.11   ## drive-by mounted gun cooldown (hold fire while driving)
const GUN_RANGE: float = 55.0
var _gun_cd: float = 0.0
var _car_muzzle: MeshInstance3D = null
var _car_muzzle_t: float = 0.0
var _launch: float = 0.0   ## pending upward kick from a ramp (applied next physics frame)

## Kick the car into the air (used by ramps). Keeps the strongest pending launch.
func launch(v: float) -> void:
	_launch = maxf(_launch, v)

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
	# Drive-by mounted gun: a muzzle flash at the car's nose, shown when firing.
	_car_muzzle = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.36
	mm.height = 0.72
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color("#FFE070")
	mmat.emission_enabled = true
	mmat.emission = Color("#FFC030")
	mmat.emission_energy_multiplier = 7.0
	mm.material = mmat
	_car_muzzle.mesh = mm
	_car_muzzle.position = Vector3(0.0, 1.0, -3.6)   # at the front bumper
	_car_muzzle.visible = false
	add_child(_car_muzzle)
	# Engine drone — pitch tracks speed; starts on first input (Web-safe gesture).
	_engine = AudioStreamPlayer.new()
	_engine.stream = RRAudio.make_engine_stream()
	_engine.volume_db = -24.0   ## much quieter — engine drone was too loud
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

func focus_camera() -> void:
	if _cam:
		_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # driving uses the keyboard; free the cursor

## Fire the forward mounted gun: hitscan straight ahead from the car's nose.
func _car_fire() -> void:
	_gun_cd = GUN_RATE
	if _car_muzzle != null:
		_car_muzzle.visible = true
	_car_muzzle_t = 0.05
	RRAudio.gunshot(self, 1.05)
	var dir: Vector3 = -global_transform.basis.z
	var from: Vector3 = _car_muzzle.global_position if _car_muzzle != null else global_position + dir * 3.5 + Vector3(0.0, 0.95, 0.0)
	var to: Vector3 = from + dir * GUN_RANGE
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
		_car_spark(endp)
	_car_tracer(from + dir * 1.5, endp)
	var g: Node = get_parent()
	if g != null and g.has_method("alarm_peds"):
		g.alarm_peds(global_position, 20.0)

func _car_tracer(a: Vector3, b: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var dist: float = a.distance_to(b)
	if dist < 0.3:
		return
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, dist)
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

func _car_spark(pos: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 0.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
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

func speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func _physics_process(delta: float) -> void:
	var throttle: float = (Input.get_axis("brake", "accel") if active else 0.0)
	var steer: float = (Input.get_axis("left", "right") if active else 0.0)
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
	if _launch > 0.0:
		velocity.y = _launch   # ramp kick — overrides the floor-zeroing this frame
		_launch = 0.0
	move_and_slide()
	# ── Drive-by mounted gun (hold fire while driving) ──
	_gun_cd = maxf(0.0, _gun_cd - delta)
	if _car_muzzle_t > 0.0:
		_car_muzzle_t -= delta
		if _car_muzzle_t <= 0.0 and _car_muzzle != null:
			_car_muzzle.visible = false
	if active and _gun_cd <= 0.0 and Input.is_action_pressed("fire"):
		_car_fire()
	# Smash through buildings when ramming them fast enough.
	if speed() > 18.0:
		for i in get_slide_collision_count():
			var other := get_slide_collision(i).get_collider()
			if other != null:
				if other.has_method("collapse"):
					other.collapse()
				elif other.has_method("ram_wreck"):
					other.ram_wreck()
	# ── Speed feel ──
	var frac: float = clampf(speed() / MAX_SPEED, 0.0, 1.0)
	_trauma = maxf(0.0, _trauma - delta * 1.8)   # shake energy bleeds off fast
	if _cam != null:
		var t2: float = _trauma * _trauma        # quadratic: sharp on impact, calm tail
		var tgt_fov: float = lerpf(BASE_FOV, MAX_FOV, frac)
		if throttle > 0.0:
			tgt_fov += 3.0
		if boosting:
			tgt_fov += 9.0   # nitro rush
		_cam.fov = lerpf(_cam.fov, tgt_fov + t2 * 6.0, 0.10)   # impact punch-out
		var shake: float = maxf(0.0, frac - 0.6) * 0.08 + t2 * 0.5
		_cam.h_offset = randf_range(-shake, shake)
		_cam.v_offset = randf_range(-shake, shake)
		# Look around with , / . (recenters when released).
		var look_in: float = (Input.get_axis("cam_left", "cam_right") if active else 0.0)
		if absf(look_in) > 0.01:
			_look_yaw = clampf(_look_yaw + look_in * 2.0 * delta, -PI, PI)
		else:
			_look_yaw = lerpf(_look_yaw, 0.0, 0.12)
		var base := Vector2(0.0, 16.5).rotated(_look_yaw)
		_cam.position = Vector3(base.x, 8.0, base.y)
		_cam.look_at(global_position + Vector3(0.0, 1.5, 0.0), Vector3.UP)
		if _trauma > 0.001:
			_cam.rotation.z += randf_range(-1.0, 1.0) * (_trauma * _trauma) * 0.05  # roll jolt
	# Engine sound disabled per feedback (looping drone / pitch-zipper "click" was
	# annoying). Re-add with a cleaner one-shot rev sample later if wanted.
	# Safety: a run never "ends" — respawn if the car drops off the world.
	if global_position.y < -8.0:
		global_position = Vector3(144.0, 2.0, 144.0)
		velocity = Vector3.ZERO

func bleed_speed(factor: float) -> void:
	velocity.x *= factor
	velocity.z *= factor
