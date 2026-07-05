## FPFootCop — an on-foot police officer that chases the player and shoots,
## dealing damage (via the FPMain game ref). Destroyable by gun or car ram.
class_name FPFootCop
extends CharacterBody3D

const SPEED: float = 6.5
const GRAVITY: float = 24.0
const SHOOT_RANGE: float = 30.0
const SHOOT_INTERVAL: float = 1.5
const SHOT_DMG: float = 7.0

var game = null            # FPMain — provides _player_pos() and _damage()
var hp: int = 2
var _wrecked: bool = false
var _shoot_t: float = 0.0
var _muzzle: MeshInstance3D = null
var _muzzle_t: float = 0.0

func _ready() -> void:
	up_direction = Vector3.UP
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)
	# Navy body + cap + head + gun.
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#1C2A50")
	cm.material = bmat
	body.mesh = cm
	body.position = Vector3(0.0, 0.9, 0.0)
	add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color("#E7B58A")
	sm.material = hmat
	head.mesh = sm
	head.position = Vector3(0.0, 1.95, 0.0)
	add_child(head)
	var cap_mesh := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(0.5, 0.18, 0.5)
	var cbmat := StandardMaterial3D.new()
	cbmat.albedo_color = Color("#14203A")
	cbm.material = cbmat
	cap_mesh.mesh = cbm
	cap_mesh.position = Vector3(0.0, 2.2, 0.0)
	add_child(cap_mesh)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.14, 0.14, 0.6)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("#15151A")
	gm.material = gmat
	gun.mesh = gm
	gun.position = Vector3(0.3, 1.1, -0.5)
	add_child(gun)
	_muzzle = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.16
	mm.height = 0.32
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color("#FFE070")
	mmat.emission_enabled = true
	mmat.emission = Color("#FFC030")
	mmat.emission_energy_multiplier = 5.0
	mm.material = mmat
	_muzzle.mesh = mm
	_muzzle.position = Vector3(0.3, 1.1, -0.95)
	_muzzle.visible = false
	add_child(_muzzle)

func _process(delta: float) -> void:
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		if _muzzle_t <= 0.0 and _muzzle:
			_muzzle.visible = false

func _physics_process(delta: float) -> void:
	if _wrecked:
		return
	if game == null:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var pp: Vector3 = game._player_pos()
	var flat := Vector3(pp.x, global_position.y, pp.z)
	var to: Vector3 = flat - global_position
	var d: float = to.length()
	if d > 0.6:
		look_at(flat, Vector3.UP)
	if d > SHOOT_RANGE:
		var dir: Vector3 = to.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_shoot_t -= delta
		if _shoot_t <= 0.0:
			_shoot_t = SHOOT_INTERVAL
			_shoot()
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

func _shoot() -> void:
	if _muzzle:
		_muzzle.visible = true
	_muzzle_t = 0.06
	RRAudio.gunshot(self)
	if game != null and game.has_method("_damage"):
		game._damage(SHOT_DMG)

func shoot_hit() -> void:
	hp -= 1
	if hp <= 0:
		_wreck()

func ram_wreck() -> void:
	_wreck()

func _wreck() -> void:
	if _wrecked:
		return
	_wrecked = true
	var host := get_parent()
	if host != null:
		var p := CPUParticles3D.new()
		p.amount = 12
		p.lifetime = 0.5
		p.one_shot = true
		p.explosiveness = 1.0
		p.spread = 120.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 8.0
		p.gravity = Vector3(0.0, -12.0, 0.0)
		p.scale_amount_min = 0.3
		p.scale_amount_max = 0.7
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#2A3A66")
		var bm := BoxMesh.new()
		bm.material = mat
		p.mesh = bm
		host.add_child(p)
		p.global_position = global_position + Vector3(0.0, 1.0, 0.0)
		p.emitting = true
		get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(p): p.queue_free())
	queue_free()

static func spawn(parent: Node, game_ref, around: Vector3, dist: float) -> FPFootCop:
	var c := FPFootCop.new()
	parent.add_child(c)
	c.game = game_ref
	var ang: float = randf() * TAU
	c.global_position = around + Vector3(cos(ang) * dist, 1.0, sin(ang) * dist)
	return c
