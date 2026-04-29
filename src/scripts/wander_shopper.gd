## Background "shopper" NPC for Night Market Shopping (v0.17).
##
## Pure atmosphere — walks horizontally along a fixed Y lane, wraps around
## when they reach the edge. No collision, no dialogue, no grid snap. Adds
## crowd life to the otherwise static market.
##
## Spawned by `ShilinMarket._spawn_shoppers()` with varied speed / colour /
## direction so the lanes don't look choreographed.
class_name WanderShopper
extends Node2D

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## How long each leg-alternation step takes. Combined with `speed` this gives
## the visible cadence of the walk cycle.
const STEP_PERIOD: float = 0.32

## Width of the silhouette in pixels.
const SHOPPER_W: int = 8

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Walking speed in px/sec along the lane.
@export var speed: float = 18.0

## Horizontal travel range. The shopper wraps when leaving this band so they
## reappear from the opposite edge.
@export var x_min: float = 16.0
@export var x_max: float = 384.0

## Y lane (world px). Shopper stays at this Y the whole time.
@export var lane_y: float = 100.0

## 1 = walking right, -1 = walking left.
@export var direction: int = 1

## Shirt / body colour. Each shopper picks a different value for variety.
@export var body_color: Color = Color("#5A8A5A")

## Hair / hat colour drawn as a 2px stripe at the top of the head.
@export var hat_color: Color = Color("#2A1A0A")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _x: float = 0.0
var _t: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_x = x_min if direction > 0 else x_max
	position = Vector2(roundf(_x), lane_y)


func _process(delta: float) -> void:
	# Test mode: freeze so unit tests aren't time-dependent.
	if Game.test_mode:
		return
	_x += speed * delta * float(direction)
	if direction > 0 and _x > x_max:
		_x = x_min
	elif direction < 0 and _x < x_min:
		_x = x_max
	_t += delta
	position = Vector2(roundf(_x), lane_y)
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing — small humanoid silhouette with a 2-step walk cycle
# ---------------------------------------------------------------------------

const COLOR_SKIN: Color = Color("#F2D6A8")

func _draw() -> void:
	# 2-step walk via a step phase in {0, 1}; alternates legs each step.
	var step_phase: int = int(_t / STEP_PERIOD * 2.0) % 2
	var bob_y: float = -1.0 if step_phase == 0 else 0.0

	# Head (6×4) + hair stripe (6×2)
	draw_rect(Rect2(-3, -6 + bob_y, 6, 4), COLOR_SKIN)
	draw_rect(Rect2(-3, -6 + bob_y, 6, 2), hat_color)
	# Body (6×4)
	draw_rect(Rect2(-3, -2 + bob_y, 6, 4), body_color)
	# Legs alternate width so it looks like one foot is forward
	var legs: Color = body_color.darkened(0.35)
	if step_phase == 0:
		draw_rect(Rect2(-2, 2 + bob_y, 2, 3), legs)
		draw_rect(Rect2(1, 2 + bob_y, 1, 3), legs)
	else:
		draw_rect(Rect2(-2, 2 + bob_y, 1, 3), legs)
		draw_rect(Rect2(0, 2 + bob_y, 2, 3), legs)
