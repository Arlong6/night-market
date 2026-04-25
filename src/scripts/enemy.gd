## Horizontal patroller enemy for Night Market Runner.
## Node2D + Area2D child. Position is manipulated directly in _process (not
## CharacterBody2D) to prevent physical blocking of the Player's CharacterBody2D
## and to ensure Area2D body_entered fires correctly.
## Visual: #7A3A2A body (40×24) + #D94F2B hazard tint strip (40×2) on top edge.
class_name Enemy
extends Node2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a Player body enters the Area2D hit zone.
signal player_hit

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const BODY_W: float = 40.0
const BODY_H: float = 24.0
const HAZARD_STRIP_H: float = 2.0  ## height of the top-edge hazard tint band

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Horizontal movement speed in pixels per second.
@export var patrol_speed: float = 45.0

## Distance in pixels from origin_x to each boundary edge.
@export var patrol_range: float = 60.0

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## Patrol origin captured in _ready. Public so tests can read it directly.
var origin_x: float = 0.0

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Current movement direction: +1 = right, -1 = left.
var _direction: int = 1

## Accumulated time for the idle Y bob. Draw-only; physics y is unchanged.
var _bob_time: float = 0.0

## Period of the idle bob cycle in seconds.
const BOB_PERIOD: float = 0.45

# ---------------------------------------------------------------------------
# Built-in virtual methods
# ---------------------------------------------------------------------------

func _ready() -> void:
	origin_x = position.x

	var area: Area2D = Area2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(BODY_W, BODY_H)
	cs.shape = rect
	area.add_child(cs)
	add_child(area)

	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	var new_x: float = position.x + patrol_speed * float(_direction) * delta

	# Boundary check: clamp and flip direction when limit is crossed.
	if new_x > origin_x + patrol_range:
		new_x = origin_x + patrol_range
		_direction = -1
	elif new_x < origin_x - patrol_range:
		new_x = origin_x - patrol_range
		_direction = 1

	position.x = roundf(new_x)
	position.y = roundf(position.y)

	_bob_time += delta
	queue_redraw()


func _draw() -> void:
	# Idle bob: round(sin * amplitude) so we get crisp ±1px pixel-art motion,
	# not sub-pixel drift.
	var bob_phase: float = (_bob_time / BOB_PERIOD) * TAU
	var bob_y: float = roundf(sin(bob_phase))  # ∈ {-1, 0, 1}

	# Body: #7A3A2A, centred on origin.
	draw_rect(
		Rect2(-BODY_W / 2.0, -BODY_H / 2.0 + bob_y, BODY_W, BODY_H),
		Color("#7A3A2A")
	)
	# Hazard tint strip: #D94F2B, top edge of body.
	draw_rect(
		Rect2(-BODY_W / 2.0, -BODY_H / 2.0 + bob_y, BODY_W, HAZARD_STRIP_H),
		Color("#D94F2B")
	)

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_hit.emit()
