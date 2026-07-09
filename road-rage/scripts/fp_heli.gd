## FPHeli — a police helicopter that appears at high wanted, hovers over the
## player with a searchlight and fires down (damage). It flies off when the
## wanted level drops (managed by FPMain). Flies (no physics body).
class_name FPHeli
extends Node3D

const HEIGHT: float = 30.0
const FOLLOW: float = 17.0
const SHOOT_INTERVAL: float = 1.5
const SHOT_DMG: float = 6.0
const SHOOT_RANGE: float = 42.0

var game = null              # FPMain — provides _player_pos() and _damage()
var _shoot_t: float = 0.0
var _rotor: Node3D = null
var _muzzle: MeshInstance3D = null
var _muzzle_t: float = 0.0

func _ready() -> void:
	# Fuselage.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 2.0, 5.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#1A2438")
	bmat.metallic = 0.4
	bmat.roughness = 0.4
	bm.material = bmat
	body.mesh = bm
	add_child(body)
	# Tail boom.
	var tail := MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = Vector3(0.5, 0.5, 4.0)
	tbm.material = bmat
	tail.mesh = tbm
	tail.position = Vector3(0.0, 0.4, 4.0)
	add_child(tail)
	# Spinning main rotor.
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 1.3, 0.0)
	add_child(_rotor)
	var blade := MeshInstance3D.new()
	var blm := BoxMesh.new()
	blm.size = Vector3(9.0, 0.1, 0.4)
	var blmat := StandardMaterial3D.new()
	blmat.albedo_color = Color("#0E0E14")
	blm.material = blmat
	blade.mesh = blm
	_rotor.add_child(blade)
	# Searchlight (down).
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, -0.5, -1.0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = Color("#FFF4D0")
	spot.light_energy = 6.0
	spot.spot_range = HEIGHT + 12.0
	spot.spot_angle = 26.0
	add_child(spot)
	# Muzzle flash (hidden).
	_muzzle = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.3
	mm.height = 0.6
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color("#FFE070")
	mmat.emission_enabled = true
	mmat.emission = Color("#FFC030")
	mmat.emission_energy_multiplier = 5.0
	mm.material = mmat
	_muzzle.mesh = mm
	_muzzle.position = Vector3(0.0, -0.6, -2.4)
	_muzzle.visible = false
	add_child(_muzzle)

func _process(delta: float) -> void:
	if _rotor:
		_rotor.rotation.y += delta * 34.0
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
		if _muzzle_t <= 0.0 and _muzzle:
			_muzzle.visible = false
	if game == null:
		return
	var pp: Vector3 = game._player_pos()
	var target := Vector3(pp.x, HEIGHT, pp.z)
	global_position = global_position.move_toward(target, FOLLOW * delta)
	var flat := Vector3(pp.x, global_position.y, pp.z)
	if global_position.distance_to(flat) > 0.5:
		look_at(flat, Vector3.UP)
	_shoot_t -= delta
	var horiz: float = Vector2(global_position.x - pp.x, global_position.z - pp.z).length()
	if _shoot_t <= 0.0 and horiz < SHOOT_RANGE:
		_shoot()

func _shoot() -> void:
	_shoot_t = SHOOT_INTERVAL
	if _muzzle:
		_muzzle.visible = true
	_muzzle_t = 0.06
	RRAudio.gunshot(self)
	if game != null and game.has_method("_damage"):
		game._damage(SHOT_DMG)
