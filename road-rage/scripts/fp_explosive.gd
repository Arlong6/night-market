## FPExplosive — a fuel barrel that detonates when rammed, shot, or caught in
## another blast (chain reactions). Big blast + flash + destroys nearby things.
class_name FPExplosive
extends Area3D

signal exploded(pos: Vector3)

const RADIUS: float = 13.0
var _broke: bool = false

func _ready() -> void:
	add_to_group("explosive")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 1.8
	col.shape = shape
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)
	# Red barrel with a yellow hazard band.
	var barrel := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 1.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#C42A1A")
	mat.metallic = 0.3
	mat.roughness = 0.5
	cm.material = mat
	barrel.mesh = cm
	barrel.position = Vector3(0.0, 0.9, 0.0)
	add_child(barrel)
	var band := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 0.73
	bcm.bottom_radius = 0.73
	bcm.height = 0.35
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#F2C12E")
	bmat.emission_enabled = true
	bmat.emission = Color("#F2C12E")
	bmat.emission_energy_multiplier = 0.4
	bcm.material = bmat
	band.mesh = bcm
	band.position = Vector3(0.0, 1.1, 0.0)
	add_child(band)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is FPCar or body is FPWalker:
		explode()

## Shot on foot, or rammed (car ram loop calls this too).
func shoot_hit() -> void:
	explode()

func ram_wreck() -> void:
	explode()

func explode() -> void:
	if _broke:
		return
	_broke = true
	var here: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	var host: Node = get_parent()
	if host != null:
		_blast_fx(host, here)
	# Chain-detonate nearby barrels.
	for n in get_tree().get_nodes_in_group("explosive"):
		if n != self and is_instance_valid(n) and n.global_position.distance_to(global_position) < RADIUS:
			n.call_deferred("explode")
	# Destroy nearby smashables (props, cars, peds, police, foot cops).
	for n in get_tree().get_nodes_in_group("blastable"):
		if is_instance_valid(n) and n.global_position.distance_to(global_position) < RADIUS and n.has_method("shoot_hit"):
			n.call_deferred("shoot_hit")
	exploded.emit(global_position)
	queue_free()

func _blast_fx(host: Node, at: Vector3) -> void:
	# Fireball particles.
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 120.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.6
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("#FF7A28")
	pmat.emission_enabled = true
	pmat.emission = Color("#FF5410")
	pmat.emission_energy_multiplier = 3.0
	var bm := BoxMesh.new()
	bm.material = pmat
	p.mesh = bm
	host.add_child(p)
	p.global_position = at
	p.emitting = true
	# A brief flash light.
	var light := OmniLight3D.new()
	light.light_color = Color("#FFB060")
	light.light_energy = 8.0
	light.omni_range = RADIUS * 1.5
	host.add_child(light)
	light.global_position = at
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.35)
	lt.tween_callback(func() -> void:
		if is_instance_valid(light): light.queue_free())
	# Expanding shockwave ring on the ground — reads as a physical blast wave.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.35
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("#FFD070")
	rmat.emission_enabled = true
	rmat.emission = Color("#FFB24A")
	rmat.emission_energy_multiplier = 2.4
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = rmat
	ring.mesh = torus
	# TorusMesh already lies flat in the XZ plane (donut on a table) — no rotation,
	# so the shockwave spreads outward along the ground.
	host.add_child(ring)
	ring.global_position = at + Vector3(0.0, -0.7, 0.0)   # just above the road
	var rt := ring.create_tween()
	rt.set_parallel(true)
	rt.tween_property(ring, "scale", Vector3.ONE * (RADIUS * 0.85), 0.45)
	rt.tween_property(rmat, "albedo_color:a", 0.0, 0.45)
	rt.chain().tween_callback(func() -> void:
		if is_instance_valid(ring): ring.queue_free())
	# Dark debris chunks flung outward and tumbling.
	var d := CPUParticles3D.new()
	d.amount = 26
	d.lifetime = 1.1
	d.one_shot = true
	d.explosiveness = 1.0
	d.direction = Vector3(0.0, 0.6, 0.0)
	d.spread = 80.0
	d.initial_velocity_min = 8.0
	d.initial_velocity_max = 22.0
	d.gravity = Vector3(0.0, -18.0, 0.0)
	d.angular_velocity_min = -400.0
	d.angular_velocity_max = 400.0
	d.scale_amount_min = 0.25
	d.scale_amount_max = 0.6
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color("#2B2B30")
	var dbm := BoxMesh.new()
	dbm.material = dmat
	d.mesh = dbm
	host.add_child(d)
	d.global_position = at
	d.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(d): d.queue_free())
	RRAudio.explosion(host)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())

## Scatter helper: place `count` barrels around the world (on the ground).
static func scatter(parent: Node, count: int, span: float, rng: RandomNumberGenerator) -> Array:
	var arr: Array = []
	for i in count:
		var e := FPExplosive.new()
		parent.add_child(e)
		e.global_position = Vector3(rng.randf_range(10.0, span - 10.0), 0.0, rng.randf_range(10.0, span - 10.0))
		arr.append(e)
	return arr
