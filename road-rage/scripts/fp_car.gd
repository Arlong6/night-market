## FPCar — first-person arcade car (3D) for the 橫衝直撞 first-person spike.
## CharacterBody3D with manual arcade driving + a cockpit Camera3D facing forward.
class_name FPCar
extends CharacterBody3D

const ACCEL: float = 22.0
const MAX_SPEED: float = 42.0
const REVERSE_SPEED: float = 12.0
const TURN_RATE: float = 2.3
const FRICTION: float = 12.0
const GRAVITY: float = 24.0

var _cam: Camera3D = null

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
	_cam.position = Vector3(0.0, 1.5, -0.2)
	_cam.fov = 82.0
	_cam.current = true
	add_child(_cam)

func speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func _physics_process(delta: float) -> void:
	var throttle: float = Input.get_axis("brake", "accel")
	var steer: float = Input.get_axis("left", "right")
	var sp: float = speed()
	# Steer only while moving; scale with speed for an arcade feel.
	if sp > 0.5:
		rotate_y(-steer * TURN_RATE * delta * clampf(sp / MAX_SPEED, 0.25, 1.0))
	var forward: Vector3 = -global_transform.basis.z
	if throttle > 0.0:
		velocity += forward * ACCEL * delta
	elif throttle < 0.0:
		velocity -= forward * REVERSE_SPEED * delta
	# Horizontal friction.
	var h := Vector3(velocity.x, 0.0, velocity.z)
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

func bleed_speed(factor: float) -> void:
	velocity.x *= factor
	velocity.z *= factor
