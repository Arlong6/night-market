## FPPickup — a floating health pack the player drives/walks over to restore HP.
class_name FPPickup
extends Area3D

signal collected(amount: float, pos: Vector3)

@export var amount: float = 35.0
var _t: float = 0.0
var _visual: Node3D = null

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	col.shape = shape
	col.position = Vector3(0.0, 1.0, 0.0)
	add_child(col)
	_visual = Node3D.new()
	_visual.position = Vector3(0.0, 1.2, 0.0)
	add_child(_visual)
	# A glowing green medkit: white box + green cross.
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#F2F4F0")
	bm.material = bmat
	box.mesh = bm
	_visual.add_child(box)
	for part in [Vector3(0.62, 0.22, 0.0), Vector3(0.62, 0.0, 0.22)]:
		var cross := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		if part.y > 0.0:
			cbm.size = Vector3(0.2, 0.7, 0.2)
		else:
			cbm.size = Vector3(0.2, 0.2, 0.7)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color("#3ADE5A")
		cmat.emission_enabled = true
		cmat.emission = Color("#2ECB4A")
		cmat.emission_energy_multiplier = 1.6
		cbm.material = cmat
		cross.mesh = cbm
		cross.position = Vector3(0.51, 0.0, 0.0)
		_visual.add_child(cross)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	if _visual:
		_visual.rotation.y = _t * 1.6
		_visual.position.y = 1.2 + sin(_t * 2.5) * 0.18

func _on_body_entered(body: Node) -> void:
	if body is FPCar or body is FPWalker:
		collected.emit(amount, global_position)
		queue_free()

static func scatter(parent: Node, count: int, span: float, rng: RandomNumberGenerator) -> Array:
	var arr: Array = []
	for i in count:
		var p := FPPickup.new()
		parent.add_child(p)
		p.global_position = Vector3(rng.randf_range(10.0, span - 10.0), 0.0, rng.randf_range(10.0, span - 10.0))
		arr.append(p)
	return arr
