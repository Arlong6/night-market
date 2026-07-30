## FPRocket — the projectile fired by the 火箭筒. Flies straight from the muzzle,
## trailing smoke, and detonates a full blast on impact or at the end of its range.
## The blast is delegated to FPExplosive.explode() so it reuses the exact fireball,
## shockwave ring, debris, chain-detonation, area destruction and score/shake path.
class_name FPRocket
extends Node3D

const SPEED: float = 48.0
const MAX_DIST: float = 95.0

var game = null
var _dir: Vector3 = Vector3.FORWARD
var _shooter: RID
var _traveled: float = 0.0
var _dead: bool = false

## Aim + ownership. Call right after adding to the tree and setting position.
func setup(dir: Vector3, shooter: RID, g) -> void:
	_dir = dir.normalized()
	_shooter = shooter
	game = g
	if absf(_dir.dot(Vector3.UP)) < 0.98:
		look_at(global_position + _dir, Vector3.UP)

func _ready() -> void:
	# Stubby warhead: a dark body with a glowing tail so it reads in flight.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.7)   # long along local -Z (travel direction)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3E4A2E")
	mat.metallic = 0.3
	mat.roughness = 0.6
	bm.material = mat
	body.mesh = bm
	add_child(body)
	var tip := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.13
	tm.height = 0.26
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color("#C43A1A")
	tip.mesh = tm
	tip.position = Vector3(0.0, 0.0, -0.4)
	add_child(tip)
	# Glowing exhaust + smoke trail out the back (+Z local).
	var glow := OmniLight3D.new()
	glow.light_color = Color("#FFB060")
	glow.light_energy = 2.4
	glow.omni_range = 5.0
	glow.position = Vector3(0.0, 0.0, 0.45)
	add_child(glow)
	var trail := CPUParticles3D.new()
	trail.amount = 22
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.direction = Vector3(0.0, 0.0, 1.0)
	trail.spread = 8.0
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 3.0
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.3
	trail.scale_amount_max = 0.7
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("#FF8A3A")
	pmat.emission_enabled = true
	pmat.emission = Color("#FF5A10")
	pmat.emission_energy_multiplier = 2.0
	var pm := SphereMesh.new()
	pm.radius = 0.14
	pm.height = 0.28
	pm.material = pmat
	trail.mesh = pm
	trail.position = Vector3(0.0, 0.0, 0.45)
	add_child(trail)
	trail.emitting = true

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step: float = SPEED * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _dir * step
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [_shooter]
	var hit := space.intersect_ray(q)
	if hit.has("collider"):
		global_position = hit["position"]
		_detonate()
		return
	global_position = to
	_traveled += step
	if _traveled >= MAX_DIST:
		_detonate()

func _detonate() -> void:
	if _dead:
		return
	_dead = true
	var host: Node = get_parent()
	if host != null:
		var FPExplosive = load("res://scripts/fp_explosive.gd")
		var e = FPExplosive.new()
		host.add_child(e)
		e.global_position = global_position
		if game != null and game.has_method("_on_explosion"):
			e.exploded.connect(game._on_explosion)
		e.explode()
	queue_free()
