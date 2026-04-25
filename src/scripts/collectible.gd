## Food-item collectible for Night Market Runner.
## Area2D pickup that bobs vertically and emits picked_up when a Player enters.
## Visual: #F2A227 body (20×24) + #2A1A0A spike (2×4) on top — art-bible §3B.
class_name Collectible
extends Area2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted once when a Player body enters the area. Carries the point value.
signal picked_up(points: int)

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Point value awarded on pickup.
@export var points: int = 100

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const BODY_W: float = 20.0
const BODY_H: float = 24.0
const SPIKE_W: float = 2.0
const SPIKE_H: float = 4.0
const BOB_AMPLITUDE: float = 2.0   ## px offset at peak of bob
const BOB_PHASE_DURATION: float = 0.25  ## seconds per half-cycle (up or down)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## World-y at spawn time; bob oscillates relative to this.
var _base_y: float = 0.0

## Accumulated time within the bob cycle.
var _bob_timer: float = 0.0

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	_base_y = position.y

	# Collision shape — 20×24, centred on node origin.
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(BODY_W, BODY_H)
	cs.shape = rect
	add_child(cs)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_bob_timer += delta
	# Phase index: 0 = bob up, 1 = bob down, repeating.
	var phase: int = int(_bob_timer / BOB_PHASE_DURATION) % 2
	position.y = _base_y - (BOB_AMPLITUDE if phase == 0 else 0.0)


func _draw() -> void:
	# Body: #F2A227, centred on origin.
	draw_rect(
		Rect2(-BODY_W / 2.0, -BODY_H / 2.0, BODY_W, BODY_H),
		Color("#F2A227")
	)
	# Spike: #2A1A0A, centred horizontally, sitting on top of body.
	draw_rect(
		Rect2(-SPIKE_W / 2.0, -BODY_H / 2.0 - SPIKE_H, SPIKE_W, SPIKE_H),
		Color("#2A1A0A")
	)

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	if body is Player:
		picked_up.emit(points)
		_spawn_pickup_burst()
		queue_free()


## Spawns a 6-particle gold burst at the collectible's current world position
## as a sibling (so it outlives this freed collectible). No-op if no parent.
func _spawn_pickup_burst() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = position
	burst.count = 6
	burst.color = Color("#F2A227")
	burst.speed_min = 45.0
	burst.speed_max = 95.0
	burst.particle_size = 2.0
	burst.lifetime = 0.35
	burst.gravity_scale = 1.2
	burst.upward_bias = 0.6
	parent.add_child(burst)
