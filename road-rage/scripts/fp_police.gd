## FPPolice — a 3D police cruiser that chases the player (橫衝直撞 FP).
## The game is endless with NO death — police add pressure/chaos, they don't kill.
class_name FPPolice
extends CharacterBody3D

const SPEED: float = 27.0        ## a bit slower than the player so skill outruns them
const GRAVITY: float = 24.0
const SIREN_INTERVAL: float = 2.6

var target: FPCar = null
var hp: int = 3
var _wrecked: bool = false
var _siren_t: float = 0.0
var _blink: float = 0.0
var _red: MeshInstance3D = null
var _blue: MeshInstance3D = null

## Shot on foot — a few bullets wreck a cruiser.
func shoot_hit() -> void:
	hp -= 1
	if hp <= 0:
		_wreck()

## Rammed by the car at speed — instant wreck.
func ram_wreck() -> void:
	_wreck()

func _wreck() -> void:
	if _wrecked:
		return
	_wrecked = true
	RRAudio.explosion(self)
	var host := get_parent()
	if host != null:
		var p := CPUParticles3D.new()
		p.amount = 26
		p.lifetime = 0.8
		p.one_shot = true
		p.explosiveness = 0.95
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 90.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 13.0
		p.gravity = Vector3(0.0, -14.0, 0.0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#FF7A2A")
		mat.emission_enabled = true
		mat.emission = Color("#FF5010")
		mat.emission_energy_multiplier = 2.0
		var bm := BoxMesh.new()
		bm.material = mat
		p.mesh = bm
		host.add_child(p)
		p.global_position = global_position + Vector3(0.0, 1.0, 0.0)
		p.emitting = true
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(p): p.queue_free())
	queue_free()

func _ready() -> void:
	up_direction = Vector3.UP
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.6, 6.2)
	col.shape = box
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)
	_build_visual()

func _build_visual() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#16233E")
	body_mat.metallic = 0.4
	body_mat.roughness = 0.4
	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.6, 0.9, 6.2)
	cm.material = body_mat
	chassis.mesh = cm
	chassis.position = Vector3(0.0, 0.65, 0.0)
	add_child(chassis)
	# White door panels (police livery).
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(2.64, 0.55, 2.6)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color("#EAEEF4")
	dm.material = dmat
	door.mesh = dm
	door.position = Vector3(0.0, 0.6, 0.0)
	add_child(door)
	# Cabin
	var cabin := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(2.2, 0.95, 2.9)
	cab.material = body_mat
	cabin.mesh = cab
	cabin.position = Vector3(0.0, 1.55, 0.3)
	add_child(cabin)
	# Blinking roof light bar.
	_red = _make_light(Color("#FF3020"), -0.55)
	_blue = _make_light(Color("#2A58FF"), 0.55)
	# Wheels
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("#131317")
	wmat.roughness = 0.9
	for wx in [-1.35, 1.35]:
		for wz in [-2.05, 2.05]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.6
			wm.bottom_radius = 0.6
			wm.height = 0.45
			wm.material = wmat
			w.mesh = wm
			w.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			w.position = Vector3(wx, 0.6, wz)
			add_child(w)

func _make_light(color: Color, x: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.32, 0.55)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.2
	bm.material = m
	mi.mesh = bm
	mi.position = Vector3(x, 2.1, 0.3)
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	_blink += delta * 8.0
	var on: bool = sin(_blink) > 0.0
	if _red:
		_red.visible = on
	if _blue:
		_blue.visible = not on

func _physics_process(delta: float) -> void:
	_siren_t -= delta
	if target == null or not is_instance_valid(target):
		if is_on_floor():
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	# Siren disabled per feedback (too noisy with several cruisers).
	# if _siren_t <= 0.0:
	# 	_siren_t = SIREN_INTERVAL
	# 	RRAudio.siren(self)
	var flat: Vector3 = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	var to: Vector3 = flat - global_position
	if to.length() > 4.0:
		look_at(flat, Vector3.UP)   # -Z faces the target
		var dir: Vector3 = to.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	else:
		# Close enough — jostle (non-fatal ram), then back off slightly.
		velocity.x *= 0.5
		velocity.z *= 0.5
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

## Spawn one cruiser 'dist' units from 'around' at a random angle, chasing 'tgt'.
static func spawn(parent: Node, tgt: FPCar, around: Vector3, dist: float) -> FPPolice:
	var p := FPPolice.new()
	parent.add_child(p)
	var ang: float = randf() * TAU
	p.global_position = around + Vector3(cos(ang) * dist, 0.9, sin(ang) * dist)
	p.target = tgt
	return p
