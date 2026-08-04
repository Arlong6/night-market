## FPPed — a smashable cartoon pedestrian (多人物) for the first-person spike.
## Built entirely from primitive meshes (no art assets): capsule torso, box legs,
## sphere head, color-varied "shirt". Idle-bobs and wanders the streets, then
## bursts into a comedic (non-gory) confetti poof when an FPCar plows through it.
## Emits the SAME signal as FPTarget so FPMain handles it identically.
class_name FPPed
extends Area3D

## Awarded when smashed — matches FPTarget's contract: (value, heat, position).
signal smashed(value: int, heat: int, pos: Vector3)

@export var value: int = 25
@export var heat: int = 20
## Minimum car ground speed required to actually flatten the ped.
@export var min_speed: float = 2.0
## How fast the ped wanders along the ground (world units / second).
@export var drift_speed: float = 1.4
## How far the ped strays from its origin before turning back (ping-pong range).
@export var wander_range: float = 3.0
## Overall body height in world units (collision + visual scale to this).
@export var body_height: float = 1.8

const _SHIRT_COLORS: Array[Color] = [
	Color("#E94F4F"),  # red
	Color("#4F9DE9"),  # blue
	Color("#54C26B"),  # green
	Color("#E9C94F"),  # yellow
	Color("#B863E9"),  # purple
	Color("#E98A3F"),  # orange
	Color("#46C9C2"),  # teal
	Color("#E96FB0"),  # pink
]

const PANIC_TIME: float = 2.6      ## seconds a ped keeps fleeing after a scare
const PANIC_SPEED: float = 5.4     ## flee speed (much faster than the idle drift)
const FEAR_RADIUS: float = 9.0     ## bolt if a fast car comes this close

var _broke: bool = false
var _root: Node3D = null          # visual pivot we bob/sway, leaving collision steady
var _origin: Vector3 = Vector3.ZERO
var _wander_dir: Vector3 = Vector3.FORWARD
var _traveled: float = 0.0
var _bob_phase: float = 0.0
var _shirt_color: Color = Color("#4F9DE9")
var _game: Node = null            # FPMain — for player position / threat awareness
var _panic_t: float = 0.0         # >0 while fleeing
var _arms: Array[MeshInstance3D] = []   # so we can throw them up in a panic
var _threat_pos: Vector3 = Vector3.ZERO # what we're fleeing from
var _reroll_t: float = 0.0        # timer to re-pick an erratic flee heading

func _ready() -> void:
	_shirt_color = _SHIRT_COLORS[randi() % _SHIRT_COLORS.size()]
	_bob_phase = randf() * TAU
	# Wander in a random horizontal direction on the x/z ground plane.
	var ang: float = randf() * TAU
	_wander_dir = Vector3(cos(ang), 0.0, sin(ang)).normalized()

	# Collision: a simple upright box around the figure.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, body_height, 0.8)
	col.shape = shape
	col.position = Vector3(0.0, body_height * 0.5, 0.0)
	add_child(col)

	# Visual pivot at the feet; everything humanoid hangs off this so we can
	# bob/sway the figure without nudging the collision shape.
	_root = Node3D.new()
	add_child(_root)
	_build_figure()

	_origin = global_position
	add_to_group("blastable")
	add_to_group("pedestrian")   # so FPMain can scare the crowd on gunfire/blasts
	_game = get_parent()         # peds are spawned as children of FPMain
	body_entered.connect(_on_body_entered)

## Assemble the little person from primitives. Heights are fractions of body_height.
func _build_figure() -> void:
	var h: float = body_height
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#E7B58A")
	skin.roughness = 0.9
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = _shirt_color
	shirt.roughness = 0.8
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color("#3A3F52")
	pants.roughness = 0.85

	# Legs — two slim boxes side by side from the feet up to mid-body.
	var leg_h: float = h * 0.42
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.18, leg_h, 0.22)
		lm.material = pants
		leg.mesh = lm
		leg.position = Vector3(side * 0.14, leg_h * 0.5, 0.0)
		_root.add_child(leg)

	# Torso — a capsule "shirt" sitting on top of the legs.
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.26
	cm.height = h * 0.5
	cm.material = shirt
	torso.mesh = cm
	torso.position = Vector3(0.0, leg_h + h * 0.25, 0.0)
	_root.add_child(torso)

	# Arms — thin capsules dangling at the sides, shirt-colored.
	var arm_h: float = h * 0.36
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.07
		am.height = arm_h
		am.material = shirt
		arm.mesh = am
		arm.position = Vector3(side * 0.34, leg_h + h * 0.22, 0.0)
		_root.add_child(arm)
		_arms.append(arm)

	# Head — a skin-toned sphere on top.
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.material = skin
	head.mesh = sm
	head.position = Vector3(0.0, leg_h + h * 0.5 + 0.22, 0.0)
	_root.add_child(head)

func _process(delta: float) -> void:
	if _broke:
		return
	# Passive fear: bolt if the player's car is bearing down close and fast.
	if _panic_t <= 0.0 and is_instance_valid(_game) and _game.has_method("_player_pos"):
		var pp: Vector3 = _game._player_pos()
		if global_position.distance_to(pp) < FEAR_RADIUS and _game._mode == "car" \
				and is_instance_valid(_game._car) and _game._car.speed() > 6.0:
			panic(pp)
	if _panic_t > 0.0:
		_panic_t -= delta
		_update_panic(delta)
	else:
		_update_idle(delta)

## Idle bob + slow ping-pong wander so the crowd feels alive.
func _update_idle(delta: float) -> void:
	_bob_phase += delta * 3.0
	if _root != null:
		_root.position.y = absf(sin(_bob_phase)) * 0.06
		_root.rotation.z = sin(_bob_phase * 0.5) * 0.05
	# Arms ease back down to a resting hang.
	for a in _arms:
		if is_instance_valid(a):
			a.rotation.x = lerpf(a.rotation.x, 0.0, 0.2)
	var step: float = drift_speed * delta
	global_position += _wander_dir * step
	_traveled += step
	if _traveled >= wander_range:
		_traveled = 0.0
		_wander_dir = -_wander_dir  # turn around, stay near the street
		if _root != null:
			_root.rotation.y = atan2(_wander_dir.x, _wander_dir.z)

## Flee: arms thrown overhead and flailing, running in a frantic zig-zag away.
func _update_panic(delta: float) -> void:
	_bob_phase += delta * 11.0
	if _root != null:
		_root.position.y = absf(sin(_bob_phase)) * 0.17   # big panicked hops
		_root.rotation.z = sin(_bob_phase * 0.5) * 0.07
	# Hands up, waving in terror.
	var wave: float = sin(_bob_phase * 1.6) * 0.35
	for a in _arms:
		if is_instance_valid(a):
			a.rotation.x = -2.3 + wave   # ~ -130deg: arms flung overhead, flailing
	# Re-pick an erratic heading now and then (generally away from the threat).
	_reroll_t -= delta
	if _reroll_t <= 0.0:
		_reroll_t = randf_range(0.25, 0.5)
		_pick_flee_dir()
	global_position += _wander_dir * PANIC_SPEED * delta

## Choose a flee heading: away from the threat, jittered for a panicked scramble.
func _pick_flee_dir() -> void:
	var away: Vector3 = global_position - _threat_pos
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	away = away.normalized().rotated(Vector3.UP, randf_range(-1.0, 1.0))  # +/- ~57deg jitter
	_wander_dir = away.normalized()
	if _root != null:
		_root.rotation.y = atan2(_wander_dir.x, _wander_dir.z)

## Scare this pedestrian: bolt away from `threat_pos` for a couple of seconds.
## Called by FPMain on gunfire, explosions, or a nearby kill.
func panic(threat_pos: Vector3) -> void:
	if _broke:
		return
	var was_calm: bool = _panic_t <= 0.0
	_panic_t = PANIC_TIME
	_threat_pos = threat_pos
	_reroll_t = 0.0        # pick a heading immediately
	_pick_flee_dir()
	# Only some peds cry out, and only at the moment of the scare (not on re-alarms),
	# so a scared crowd sounds like a scatter of yelps rather than a wall of noise.
	if was_calm and randf() < 0.3:
		RRAudio.scream(self, randf_range(0.85, 1.4))

func _on_body_entered(body: Node) -> void:
	if _broke or not body is FPCar:
		return
	var car: FPCar = body
	if car.speed() < min_speed:
		return
	_break(car)

func _break(car: FPCar) -> void:
	_broke = true
	_spawn_poof()
	_spawn_flying_ped(car)
	car.bleed_speed(0.92)  # pedestrians barely slow the car
	smashed.emit(value, heat, global_position)
	queue_free()

## Comically launch the pedestrian as a physics body — flung, tumbling, lands.
func _spawn_flying_ped(car: FPCar) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var r := RigidBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = body_height
	col.shape = shape
	r.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = body_height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _shirt_color
	cm.material = mat
	mi.mesh = cm
	r.add_child(mi)
	host.add_child(r)
	r.global_position = global_position + Vector3(0.0, body_height * 0.5, 0.0)
	var dir: Vector3 = global_position - car.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -car.global_transform.basis.z
	dir = dir.normalized()
	var force: float = maxf(car.speed(), 8.0)
	# Mostly knocked away, only a modest pop upward (was launching people skyward).
	r.linear_velocity = dir * force * 0.85 + Vector3.UP * (1.4 + force * 0.06)
	r.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	var t := r.create_tween()
	t.tween_interval(2.2)
	t.tween_property(r, "scale", Vector3.ZERO, 0.5)
	t.tween_callback(func() -> void:
		if is_instance_valid(r): r.queue_free())

## Comedic confetti poof — bright shirt-colored bits, no gore.
## Destroyed by a gunshot (on foot).
func shoot_hit() -> void:
	if _broke:
		return
	_broke = true
	_spawn_poof()
	smashed.emit(value, heat, global_position)
	queue_free()

func _spawn_poof() -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 75.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0.0, -14.0, 0.0)
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.4
	var bits := SphereMesh.new()
	bits.radius = 0.12
	bits.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _shirt_color.lightened(0.2)
	bits.material = mat
	p.mesh = bits
	# Parent to our parent (we're about to queue_free) so the burst outlives us.
	var host: Node = get_parent()
	if host == null:
		return
	host.add_child(p)
	p.global_position = global_position + Vector3(0.0, body_height * 0.5, 0.0)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(p): p.queue_free())

## Spawn `count` pedestrians clustered around `center` on the ground (y=0) as
## children of `parent`. Returns the array of FPPed instances so the caller can
## connect each one's `smashed` signal. Offsets are seeded RNG for determinism.
static func crowd(parent: Node, center: Vector3, count: int, rng: RandomNumberGenerator) -> Array:
	var peds: Array = []
	for i in count:
		var ped := FPPed.new()
		parent.add_child(ped)
		var ox: float = rng.randf_range(-4.0, 4.0)
		var oz: float = rng.randf_range(-4.0, 4.0)
		ped.global_position = Vector3(center.x + ox, 0.0, center.z + oz)
		ped.drift_speed = rng.randf_range(0.8, 1.8)
		peds.append(ped)
	return peds
