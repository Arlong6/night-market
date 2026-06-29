## FPTarget — a smashable 3D box for the first-person spike. Breaks when the car
## hits it above a small speed threshold, bursting into debris particles.
class_name FPTarget
extends Area3D

signal smashed(value: int, heat: int, pos: Vector3)

@export var value: int = 10
@export var heat: int = 8
@export var box_color: Color = Color("#C8A24A")
@export var size: Vector3 = Vector3(1.8, 2.2, 1.8)
@export var min_speed: float = 6.0
## Non-zero for "traffic" — the box drifts and ping-pongs over this travel range.
@export var drift: Vector3 = Vector3.ZERO
@export var drift_range: float = 60.0

var _broke: bool = false
var _mesh: MeshInstance3D = null
var _origin: Vector3 = Vector3.ZERO
var _traveled: float = 0.0
var _dir: float = 1.0

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = box_color
	bm.material = mat
	_mesh.mesh = bm
	_mesh.position = Vector3(0.0, size.y * 0.5, 0.0)  # sit on the ground
	add_child(_mesh)
	_origin = global_position
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _broke or drift == Vector3.ZERO:
		return
	var step: float = drift.length() * delta
	global_position += drift.normalized() * step * _dir
	_traveled += step
	if _traveled >= drift_range:
		_traveled = 0.0
		_dir = -_dir  # ping-pong so traffic stays in play

func _on_body_entered(body: Node) -> void:
	if _broke or not body is FPCar:
		return
	var car: FPCar = body
	if car.speed() < min_speed:
		return
	_break(car)

func _break(car: FPCar) -> void:
	_broke = true
	_spawn_debris()
	car.bleed_speed(0.86)
	smashed.emit(value, heat, global_position)
	queue_free()

func _spawn_debris() -> void:
	var p := CPUParticles3D.new()
	p.global_position = global_position + Vector3(0.0, size.y * 0.5, 0.0)
	p.amount = 10
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 80.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0.0, -18.0, 0.0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.7
	var debris_mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = box_color.lightened(0.15)
	debris_mesh.material = mat
	p.mesh = debris_mesh
	p.emitting = true
	get_parent().add_child(p)
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())
