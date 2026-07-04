## FPWalker — on-foot character for 橫衝直撞. Third-person, WASD move (camera-fixed),
## faces movement, shoots a hitscan gun forward. Get in/out of the car via FPMain.
class_name FPWalker
extends CharacterBody3D

const SPEED: float = 8.0
const GRAVITY: float = 24.0
const FIRE_RANGE: float = 60.0

var _cam: Camera3D = null
var _visual: Node3D = null
var _muzzle: MeshInstance3D = null
var _face: Vector3 = Vector3.FORWARD
var _muzzle_t: float = 0.0
var _fire_queued: bool = false

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
	# Fixed third-person camera (behind in world +Z; body never rotates).
	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 3.6, 7.0)
	_cam.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	_cam.fov = 70.0
	add_child(_cam)

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

func make_current() -> void:
	if _cam:
		_cam.current = true

func _process(delta: float) -> void:
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		if _muzzle_t <= 0.0 and _muzzle:
			_muzzle.visible = false

func _physics_process(delta: float) -> void:
	var move := Vector3(Input.get_axis("left", "right"), 0.0, -Input.get_axis("brake", "accel"))
	if move.length() > 0.1:
		move = move.normalized()
		_face = move
		_visual.look_at(global_position + move, Vector3.UP)
		velocity.x = move.x * SPEED
		velocity.z = move.z * SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_on_floor():
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
	if _muzzle:
		_muzzle.visible = true
	_muzzle_t = 0.06
	RRAudio.gunshot(self)
	_fire_queued = true

func _do_fire() -> void:
	var from: Vector3 = global_position + Vector3(0.0, 1.1, 0.0)
	var to: Vector3 = from + _face * FIRE_RANGE
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.has("collider"):
		var c = hit["collider"]
		if c != null and c.has_method("shoot_hit"):
			c.shoot_hit()
